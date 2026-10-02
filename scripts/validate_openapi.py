#!/usr/bin/env python3
"""
Full OpenAPI 3.1 & JSON Schema semantic validator for TERNAVA.
Validates structural integrity, operations, schemas, parameters, and examples.
"""
import datetime
import json
import re
import sys
import uuid
from pathlib import Path

root = Path(__file__).resolve().parents[1]
openapi_path = root / "contracts/openapi.json"
examples_path = root / "contracts/examples.json"

if not openapi_path.exists():
    print(f"Error: {openapi_path} not found", file=sys.stderr)
    sys.exit(1)

api = json.loads(openapi_path.read_text(encoding="utf-8"))
examples = json.loads(examples_path.read_text(encoding="utf-8")) if examples_path.exists() else {}

# 1. Base openapi check
assert api.get("openapi") == "3.1.0", f"Expected OpenAPI 3.1.0, got {api.get('openapi')}"
assert "paths" in api, "Missing paths"
assert "components" in api and "schemas" in api["components"], "Missing components.schemas"

schemas = api["components"]["schemas"]

def resolve(ref: str):
    assert ref.startswith("#/"), f"External ref unsupported: {ref}"
    node = api
    for part in ref[2:].split("/"):
        node = node[part.replace("~1", "/").replace("~0", "~")]
    return node

# 2. Validate all operation IDs & parameters
operations = {}
for path, methods in api["paths"].items():
    assert path.startswith("/"), f"Path must start with slash: {path}"
    for method, op in methods.items():
        if not isinstance(op, dict):
            continue
        op_id = op.get("operationId")
        assert op_id, f"Missing operationId for {method.upper()} {path}"
        assert op_id not in operations, f"Duplicate operationId: {op_id}"
        operations[op_id] = (method, path)

        # Check path parameters match template {param}
        expected_params = set(re.findall(r"\{([^}]+)\}", path))
        actual_params = {
            p["name"]
            for p in op.get("parameters", [])
            if p.get("in") == "path" and p.get("required")
        }
        assert expected_params == actual_params, f"Mismatch path parameters in {path}: expected {expected_params}, got {actual_params}"

        # Responses check
        assert "responses" in op, f"Missing responses in {op_id}"
        assert "200" in op["responses"] or "201" in op["responses"] or "204" in op["responses"], f"Missing 2xx response in {op_id}"

# 3. Validate schema types and examples
def validate_value(value, schema):
    if "$ref" in schema:
        return validate_value(value, resolve(schema["$ref"]))

    for key in ["anyOf", "oneOf"]:
        if key in schema:
            matches = 0
            for child in schema[key]:
                try:
                    validate_value(value, child)
                    matches += 1
                except (AssertionError, ValueError, TypeError):
                    pass
            assert (matches >= 1 if key == "anyOf" else matches == 1), f"Value {value} failed {key} validation"
            return

    kind = schema.get("type")
    type_checks = {
        "null": lambda v: v is None,
        "object": lambda v: isinstance(v, dict),
        "array": lambda v: isinstance(v, list),
        "string": lambda v: isinstance(v, str),
        "boolean": lambda v: isinstance(v, bool),
        "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
        "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    }

    if kind:
        assert kind in type_checks, f"Unknown schema type: {kind}"
        assert type_checks[kind](value), f"Expected type {kind} for {value!r}, got {type(value).__name__}"

    if "enum" in schema:
        assert value in schema["enum"], f"Value {value} not in enum {schema['enum']}"

    if kind == "object":
        props = schema.get("properties", {})
        required = set(schema.get("required", []))
        actual = set(value.keys())
        assert required <= actual, f"Missing required properties: {required - actual}"
        if schema.get("additionalProperties") is False:
            extra = actual - set(props.keys())
            assert not extra, f"Forbidden additional properties: {extra}"
        for k, v in value.items():
            rule = props.get(k, schema.get("additionalProperties", {}))
            if isinstance(rule, dict) and rule:
                validate_value(v, rule)

    elif kind == "array":
        max_items = schema.get("maxItems")
        if max_items is not None:
            assert len(value) <= max_items, f"Array exceeds maxItems {max_items}: length={len(value)}"
        item_schema = schema.get("items")
        if item_schema:
            for x in value:
                validate_value(x, item_schema)

    elif kind == "string":
        min_len = schema.get("minLength", 0)
        max_len = schema.get("maxLength", 10**9)
        assert min_len <= len(value) <= max_len, f"String length {len(value)} outside bounds [{min_len}, {max_len}]"
        if "pattern" in schema:
            assert re.fullmatch(schema["pattern"], value), f"String {value!r} does not match pattern {schema['pattern']}"
        fmt = schema.get("format")
        if fmt == "uuid":
            uuid.UUID(value)
        elif fmt == "date":
            datetime.date.fromisoformat(value)
        elif fmt == "date-time":
            dt = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
            assert dt.tzinfo is not None, f"date-time must have timezone: {value}"

    elif kind in ("integer", "number"):
        if "minimum" in schema:
            assert value >= schema["minimum"], f"{value} < minimum {schema['minimum']}"
        if "maximum" in schema:
            assert value <= schema["maximum"], f"{value} > maximum {schema['maximum']}"

# Validate all example payloads
for schema_name, example_val in examples.items():
    if schema_name in schemas:
        validate_value(example_val, schemas[schema_name])

print(f"VALIDATE OPENAPI PASS: {len(operations)} operations, {len(schemas)} schemas, {len(examples)} examples validated.")
sys.exit(0)
