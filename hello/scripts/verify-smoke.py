#!/usr/bin/env python3
"""Require recorded observations, never infer device testing from a build."""
import json
import sys
from pathlib import Path

root, stage = Path(sys.argv[1]), sys.argv[2]
manifest = json.loads((root / 'release-manifest.json').read_text())
evidence = json.loads((root / f'{stage}-smoke.json').read_text())
assert evidence['source_commit'] == manifest['source_commit']
assert evidence['tester'].strip() and evidence['date'].strip() and evidence['system'].strip()
required = ['identity', 'permissions', 'microphone', 'selection', 'focus', 'secure_field',
            'cancellation', 'copy_clear', 'cleanup', 'service_failure', 'lifecycle']
if stage == 'downloaded':
    assert evidence['artifact_sha256'] == manifest['sha256']
    required = ['launch', 'microphone', 'insertion', 'cancellation']
else:
    assert evidence['app_cdhashes'] == manifest['app_cdhashes']
for key in required:
    result = evidence['checks'][key]
    assert result['result'] == 'passed' and result['observation'].strip(), f'Missing observed pass: {key}'
print(f'{stage} smoke evidence checked ({len(required)} required cases)')
