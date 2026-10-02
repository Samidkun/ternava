#!/usr/bin/env python3
"""Tree scan always runs; history scan is explicitly unavailable without Git."""
import importlib.util
from pathlib import Path
import shutil,subprocess,sys
root=Path(__file__).resolve().parents[1]
git_repo=subprocess.run(['git','rev-parse','--is-inside-work-tree'],cwd=root,capture_output=True).returncode==0
def execute(args,label):
    result=subprocess.run(args,cwd=root,capture_output=True,text=True)
    # Scanner snippets are never echoed; only redact-safe status is exposed.
    if result.returncode:
        print(f'{label}: BLOCKED (finding or scanner failure); inspect a redacted local report.')
        raise SystemExit(1)
    print(f'{label}: PASS')
if shutil.which('gitleaks'):
    execute(['gitleaks','dir','.', '--redact','--no-banner'],'Working tree gitleaks')
    if git_repo: execute(['gitleaks','git','.', '--redact','--no-banner'],'Git history gitleaks')
else:
    spec=importlib.util.spec_from_file_location('fallback',root/'.githooks/scan_secrets.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    findings=[];examined=0
    for file in root.rglob('*'):
        if not file.is_file() or '.git' in file.relative_to(root).parts: continue
        examined+=1
        for line,label,_ in module.scan(str(file)): findings.append((str(file.relative_to(root)),line,label))
    if findings:
        for file,line,label in findings: print(f'{file}:{line}: {label} (value withheld)')
        raise SystemExit(1)
    print(f'Bundled tree scanner PASS; visited {examined} files (pattern/large-line limits apply).')
    if git_repo: execute(['python3','.githooks/secret_gate.py','--history'],'Git history bundled scanner')
if not git_repo: print('Git history UNAVAILABLE: project repository not initialized; not a history pass.')
