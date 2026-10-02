#!/usr/bin/env python3
"""Offline structural checks; not a full OpenAPI semantic validator."""
import datetime,json,re,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1]
api=json.loads((root/'contracts/openapi.json').read_text())
model=json.loads((root/'contracts/schema.json').read_text())
criteria=json.loads((root/'contracts/criteria.json').read_text())
inventory=json.loads((root/'preview/manifest.json').read_text())
ids={x['id'] for x in inventory};acs={x['id'] for x in criteria};schemas=api['components']['schemas']
def resolve(reference):
    assert reference.startswith('#/'),f'External ref unsupported: {reference}'
    node=api
    for part in reference[2:].split('/'): node=node[part.replace('~1','/').replace('~0','~')]
    return node
def visit(value):
    if isinstance(value,dict):
        if '$ref' in value: resolve(value['$ref'])
        for x in value.values(): visit(x)
    elif isinstance(value,list):
        for x in value: visit(x)
visit(api)
operations=[];screens=set();mapped=set()
for path,methods in api['paths'].items():
    for method,op in methods.items():
        operations.append(op['operationId']);screens.update(op['x-screen-ids']);mapped.update(op['x-ac-ids'])
        assert set(op['x-screen-ids'])<=ids and set(op['x-ac-ids'])<=acs
        expected=set(re.findall(r'\{([^}]+)\}',path))
        actual={p['name'] for p in op['parameters'] if p['in']=='path' and p.get('required')}
        assert expected==actual,(path,expected,actual)
        assert '401' in op['responses'] and '422' in op['responses']
        if op['x-idempotency']: assert any(p['name']=='Idempotency-Key' and p.get('required') for p in op['parameters'])
assert len(set(operations))==len(operations)
assert screens==ids,ids-screens
assert {f'AC-{i:02}' for i in range(1,25)}<=mapped
assert {f'AC-{i:02}' for i in range(1,48)}==acs
for row in criteria:
    assert row['requirement'].startswith(('WHEN ','WHILE ','IF ','WHERE '))
    assert ' SHALL ' in row['requirement'] and row['verify']
for table,data in model['tables'].items():
    assert set(data['primary_key'])<=set(data['fields'])
    for cols in data['unique']+data['indexes']: assert set(cols)<=set(data['fields'])
    for index in data.get('partial_unique',[]):
        assert set(index['columns'])<=set(data['fields']) and index['predicate']
    for field,info in data['fields'].items():
        if 'references' in info:
            target,column=info['references'].split('.')
            assert target in model['tables'] and column in model['tables'][target]['fields']
def validate(value,schema):
    if '$ref' in schema: return validate(value,resolve(schema['$ref']))
    for key in ['anyOf','oneOf']:
        if key in schema:
            matches=0
            for child in schema[key]:
                try: validate(value,child);matches+=1
                except (AssertionError,ValueError,TypeError): pass
            assert (matches>=1 if key=='anyOf' else matches==1)
            return
    kind=schema.get('type')
    assert {'null':lambda:value is None,'object':lambda:isinstance(value,dict),'array':lambda:isinstance(value,list),
     'string':lambda:isinstance(value,str),'boolean':lambda:isinstance(value,bool),
     'integer':lambda:isinstance(value,int) and not isinstance(value,bool)}[kind]()
    if 'enum' in schema: assert value in schema['enum']
    if kind=='object':
        props=schema.get('properties',{})
        assert set(schema.get('required',[]))<=set(value)
        if schema.get('additionalProperties') is False: assert set(value)<=set(props)
        for key,item in value.items():
            rule=props.get(key,schema.get('additionalProperties',{}))
            if isinstance(rule,dict) and rule: validate(item,rule)
    if kind=='array':
        assert len(value)<=schema.get('maxItems',10**9)
        for x in value: validate(x,schema['items'])
    if kind=='string':
        assert schema.get('minLength',0)<=len(value)<=schema.get('maxLength',10**9)
        if 'pattern' in schema: assert re.fullmatch(schema['pattern'],value)
        fmt=schema.get('format')
        if fmt=='uuid': uuid.UUID(value)
        if fmt=='date': datetime.date.fromisoformat(value)
        if fmt=='date-time': assert datetime.datetime.fromisoformat(value.replace('Z','+00:00')).tzinfo
    if kind=='integer': assert schema.get('minimum',-10**20)<=value<=schema.get('maximum',10**20)
examples=json.loads((root/'contracts/examples.json').read_text())
for name,value in examples.items(): validate(value,schemas[name])
daily=examples['DailyInput']
bad=[{**daily,'feed_kg':270.0},{k:v for k,v in daily.items() if k!='eggs_count'},
 {**daily,'uncontracted_field':True},{**daily,'mortality_count':-1},{**daily,'condition':'healthy'}]
for value in bad:
    try: validate(value,schemas['DailyInput'])
    except (AssertionError,ValueError,TypeError): pass
    else: raise AssertionError('Invalid fixture accepted')
spec=(root/'docs/superpowers/specs/2026-10-01-ternava-design.md').read_text()
assert set(re.findall(r'^### (AC-\d+) ',spec,re.M))==acs
assert len(re.findall(r'^Verify:',spec,re.M))==len(acs)
for row in criteria:
    assert row['requirement'] in spec and 'Verify: '+row['verify'] in spec, row['id']+' source/spec drift'
assert not re.search(r'\b(?:TBD|TODO)\b',spec)
print(json.dumps({'operations':len(operations),'schemas':len(schemas),'tables':len(model['tables']),
 'screens':len(ids),'ears_criteria':len(acs),'valid_examples':len(examples),'rejected_invalid_examples':len(bad),
 'scope':'Local references/schema-subset/traceability; no full OpenAPI validation, live API or native tests'},indent=2))
