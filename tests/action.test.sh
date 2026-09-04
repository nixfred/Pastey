#!/bin/bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/state/omarchy" "$test_dir/bin"
printf '[{"type":"text","text":"restored clipboard text"}]\n' \
  >"$test_dir/state/omarchy/clipboard-history.json"

printf '#!/bin/bash\ncat >"$TEST_CAPTURE"\n' >"$test_dir/bin/wl-copy"
chmod +x "$test_dir/bin/wl-copy"

export XDG_STATE_HOME="$test_dir/state"
export TEST_CAPTURE="$test_dir/captured"
PATH="$test_dir/bin:$PATH" "$repo_dir/pastey-action" 0

[[ $(<"$TEST_CAPTURE") == "restored clipboard text" ]]
! rg -q 'wtype|shift.*insert|sleep' "$repo_dir/pastey-action"

echo "Pastey clipboard restore test passed"
