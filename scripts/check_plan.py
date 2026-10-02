#!/usr/bin/env python3
"""Check planning traceability; this does not test application behavior."""
import json, pathlib, re
r=pathlib.Path(__file__).resolve().parents[1]
plan=json.loads((r/'contracts/plan.json').read_text()); tasks=plan['tasks']
ids=[t['id'] for t in tasks]; assert len(ids)==len(set(ids))
criteria={c['id'] for c in json.loads((r/'contracts/criteria.json').read_text())}
coverage={c for t in tasks for c in t['ac']}; assert coverage==criteria,(criteria-coverage,coverage-criteria)
api=json.loads((r/'contracts/openapi.json').read_text())
ops={v['operationId'] for row in api['paths'].values() for v in row.values() if isinstance(v,dict) and 'operationId' in v}
mapped={op for t in tasks for op in t['operations']}; assert ops==mapped,(ops-mapped,mapped-ops)
manifest=json.loads((r/'preview/manifest.json').read_text())
screens={s['id'] for s in manifest}
mapped_screens={s for t in tasks for s in t['screens']}; assert screens==mapped_screens,(screens-mapped_screens,mapped_screens-screens)
seen=set()
for task in tasks:
    assert set(task['deps'])<=seen,(task['id'],task['deps'])
    assert len(task['files'])<=5,(task['id'],len(task['files']))
    assert task['ac'] and task['verify'] and task['consumes'] and task['produces']
    for p in task['files']: assert not p.startswith('/') and '..' not in pathlib.PurePosixPath(p).parts
    seen.add(task['id'])
text=(r/'docs/superpowers/plans/2026-10-01-ternava-mvp.md').read_text()
spec=(r/plan['source_spec']).read_text()
scope=spec.split('## Scope dan aturan normatif\n\n')[1].split('\n## Desain dan interface')[0]
assert scope in text
assert not re.search(r'\b(?:TO'+'DO|T'+'BD)\b',text)
assert all(f"### {t['id']} —" in text for t in tasks)
assert text.count('- [ ] **1.')==len(tasks)
assert text.count('- [ ] **5.')==len(tasks)
assert plan['status']=='planning_only'
print(f"PLAN PASS: {len(tasks)} tasks / {len(criteria)} AC / {len(screens)} screens / {len(ops)} operations; DAG and verbatim scope checked. App tests NOT RUN.")
