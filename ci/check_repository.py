"""Refuse tracked credentials/private signing assets before an upload or build."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
paths = subprocess.check_output(
    ['git', 'ls-files', '-z'], cwd=root
).decode('utf-8').split('\0')
blocked = []
for relative in filter(None, paths):
    path = root / relative
    name = path.name.lower()
    if (path.suffix.lower() in {'.p12', '.pfx', '.mobileprovision',
                               '.mobileconfig', '.pem', '.key', '.ipa'}
            or 'password' in name or name == '.env' or name.startswith('.env.')
            or relative.split('/')[0] in {'evidence', '.tools', '.local', 'artifacts'}):
        blocked.append(relative)
        continue
    if path.is_file() and path.stat().st_size < 2_000_000:
        content = path.read_bytes()
        if (re.search(rb'-----BEGIN (?:RSA |EC |ENCRYPTED )?PRIVATE KEY-----', content)
                or re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}', content)):
            blocked.append(relative)
if blocked:
    print('Blocked tracked files (content is not printed):', file=sys.stderr)
    print('\n'.join(blocked), file=sys.stderr)
    sys.exit(1)
print(f'Repository check passed: {len(list(filter(None, paths)))} tracked files.')
