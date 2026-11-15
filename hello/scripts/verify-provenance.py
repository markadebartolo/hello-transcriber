#!/usr/bin/env python3
"""Verify the extraction's tracked modules against the reviewed revision manifest."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
original = json.loads((root / 'SOURCE_PROVENANCE.json').read_text())
current = json.loads((root / 'SOURCE_CHECKSUMS.json').read_text())
assert set(current) == {entry['path'] for entry in original['original_files']}
for path, checksum in current.items():
    assert hashlib.sha256((root / path).read_bytes()).hexdigest() == checksum, f'Update reviewed checksum and MODIFICATIONS.md for {path}'
print('Source provenance: six reviewed module checksums verified')
