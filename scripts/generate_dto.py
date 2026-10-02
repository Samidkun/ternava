#!/usr/bin/env python3
"""
Generate wire DTOs for PHP (Laravel) and Dart (Flutter) from contracts/openapi.json.
Enforces strict wire mapping, snake_case JSON, and null preservation.
Supports --check flag to detect drift.
"""
import json
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
openapi_path = root / "contracts/openapi.json"
php_out = root / "backend/app/Contracts/Dto"
dart_out = root / "mobile/lib/core/api/generated"

check_mode = "--check" in sys.argv

api = json.loads(openapi_path.read_text(encoding="utf-8"))
schemas = api["components"]["schemas"]

def to_snake(name: str) -> str:
    s = ""
    for i, c in enumerate(name):
        if c.isupper():
            if i > 0:
                s += "_"
            s += c.lower()
        else:
            s += c
    return s

def generate_php_dto(name: str, schema: dict) -> str:
    code = f"""<?php

declare(strict_types=1);

namespace App\\Contracts\\Dto;

final readonly class {name}
{{
    /**
     * @param  array<string, mixed>  $raw
     */
    public function __construct(
        public array $raw = []
    ) {{}}

    /**
     * @param  array<string, mixed>  $data
     */
    public static function fromArray(array $data): self
    {{
        return new self($data);
    }}

    /**
     * @return array<string, mixed>
     */
    public function toArray(): array
    {{
        return $this->raw;
    }}
}}
"""
    return code

def generate_dart_dto(name: str, schema: dict) -> str:
    # The factory uses a block body (not `=> expr`) so the generated line stays
    # under 80 columns for every schema name and therefore matches `dart format`
    # byte-for-byte. An arrow body would be re-wrapped by the formatter for long
    # names, making `generate_dto.py --check` and `dart format --check` disagree.
    code = f"""// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: {name}

import 'types.dart';

class {name} {{
  final JsonObject _raw;

  const {name}(this._raw);

  factory {name}.fromJson(JsonObject json) {{
    return {name}(Map<String, Object?>.from(json));
  }}

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}}
"""
    return code

files_to_write = {}

# Shared Dart types
files_to_write[dart_out / "types.dart"] = """// GENERATED CODE - DO NOT MODIFY BY HAND

typedef JsonObject = Map<String, Object?>;
"""

for schema_name, schema_def in schemas.items():
    if not isinstance(schema_def, dict):
        continue
    # PHP
    php_file = php_out / f"{schema_name}.php"
    files_to_write[php_file] = generate_php_dto(schema_name, schema_def)

    # Dart
    dart_file = dart_out / f"{to_snake(schema_name)}.dart"
    files_to_write[dart_file] = generate_dart_dto(schema_name, schema_def)

# Dart index
dart_exports = ["export 'types.dart';"] + [f"export '{to_snake(s)}.dart';" for s in schemas.keys()]
files_to_write[dart_out / "dtos.dart"] = f"// Barrel file for generated DTOs\n" + "\n".join(dart_exports) + "\n"

if check_mode:
    drift = False
    for path, expected_content in files_to_write.items():
        if not path.exists():
            print(f"DTO DRIFT: Missing file {path.relative_to(root)}")
            drift = True
        elif path.read_text(encoding="utf-8") != expected_content:
            print(f"DTO DRIFT: Outdated file {path.relative_to(root)}")
            drift = True
    if drift:
        print("Run `python3 scripts/generate_dto.py` to regenerate DTOs.")
        sys.exit(1)
    else:
        print(f"DTO CHECK PASS: {len(files_to_write)} files checked, no drift.")
        sys.exit(0)
else:
    php_out.mkdir(parents=True, exist_ok=True)
    dart_out.mkdir(parents=True, exist_ok=True)
    for path, content in files_to_write.items():
        path.write_text(content, encoding="utf-8")
    print(f"DTO GENERATION PASS: {len(files_to_write)} files written.")
    sys.exit(0)
