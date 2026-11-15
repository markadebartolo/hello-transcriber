#!/usr/bin/env python3
"""Release gates fail closed on missing or mismatched observed evidence."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='hello-gates-') as temporary:
    directory = Path(temporary)
    manifest = {'source_commit': 'abc', 'app_cdhashes': {'arm64': 'a', 'x86_64': 'b'}, 'sha256': 'ziphash'}
    signed = {'source_commit': 'abc', 'app_cdhashes': manifest['app_cdhashes'],
              'tester': 'fixture', 'date': '2026-11-14', 'system': 'fixture',
              'checks': {name: {'result': 'passed', 'observation': 'fixture, not real device evidence'} for name in
                         ['identity','permissions','microphone','selection','focus','secure_field','cancellation',
                          'copy_clear','cleanup','service_failure','lifecycle','forms']}}
    (directory/'release-manifest.json').write_text(json.dumps(manifest))
    def check(evidence, stage, should_pass):
        (directory/f'{stage}-smoke.json').write_text(json.dumps(evidence))
        result = subprocess.run(['python3', str(root/'hello/scripts/verify-smoke.py'),str(directory),stage],capture_output=True)
        assert (result.returncode == 0) == should_pass
    check(signed,'signed',True)
    changed=copy.deepcopy(signed); changed['checks']['microphone']['result']='pending'; check(changed,'signed',False)
    changed=copy.deepcopy(signed); changed['checks']['secure_field']['observation']=''; check(changed,'signed',False)
    changed=copy.deepcopy(signed); changed['source_commit']='wrong-source'; check(changed,'signed',False)
    changed=copy.deepcopy(signed); changed['app_cdhashes']['arm64']='wrong-binary'; check(changed,'signed',False)
    changed=copy.deepcopy(signed); del changed['checks']['focus']; check(changed,'signed',False)
    changed=copy.deepcopy(signed); del changed['checks']['forms']; check(changed,'signed',False)
    downloaded={'source_commit':'abc','artifact_sha256':'ziphash','tester':'fixture','date':'2026-11-14','system':'fixture',
                'checks':{name:{'result':'passed','observation':'fixture'} for name in ['launch','microphone','insertion','cancellation']}}
    check(downloaded,'downloaded',True)
    changed=copy.deepcopy(downloaded); changed['artifact_sha256']='other-zip'; check(changed,'downloaded',False)
print('Release evidence gates: 9 acceptance/rejection cases passed (fixtures only)')
