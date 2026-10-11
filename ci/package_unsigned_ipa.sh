#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || ! -d "$1" || "$1" != *.app || "$2" != *.ipa ]]; then
  echo 'Usage: bash ci/package_unsigned_ipa.sh path/to/App.app dist/App-unsigned.ipa' >&2
  exit 2
fi
script_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$(dirname "$2")"
ipa_path="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
stage="$(mktemp -d "${TMPDIR:-/tmp}/ipa-lab.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Payload"
app="$stage/Payload/$(basename "$1")"
/usr/bin/ditto "$1" "$app"

# Strip only the staging copy. The original build products stay intact.
while IFS= read -r -d '' bundle; do
  /usr/bin/codesign --remove-signature "$bundle" 2>/dev/null || true
done < <(find "$app" -depth -type d \( -name '*.framework' -o -name '*.appex' -o -name '*.app' \) -print0)
while IFS= read -r -d '' library; do
  /usr/bin/codesign --remove-signature "$library" 2>/dev/null || true
done < <(find "$app" -type f -name '*.dylib' -print0)
python3 - "$app" <<'PY'
from pathlib import Path
import shutil
import sys
root = Path(sys.argv[1]).resolve()
for path in root.rglob('*'):
    if path.suffix.lower() in {'.p12', '.pfx', '.mobileprovision', '.mobileconfig', '.pem', '.key'}:
        raise SystemExit('Refusing to package signing material')
for path in list(root.rglob('_CodeSignature')):
    if path.is_dir() and path.resolve().is_relative_to(root):
        shutil.rmtree(path)
PY
/usr/bin/ditto -c -k --keepParent "$stage/Payload" "$ipa_path"
python3 "$script_dir/verify_ipa.py" "$ipa_path" --report "${ipa_path%.ipa}.json"
(
  cd "$(dirname "$ipa_path")"
  shasum -a 256 "$(basename "$ipa_path")" > SHA256SUMS.txt
)
