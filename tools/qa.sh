#!/usr/bin/env bash
# QA pass: full test suite plus a check that no ERROR lines appear in the scenario logs.
set -uo pipefail
cd "$(dirname "$0")/.."
log="$(mktemp)"
tools/run_tests.sh 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
# The only tolerated ERROR text is from the deliberately corrupt save in test_bad_save_returns_empty (none expected now).
if grep -E "^(SCRIPT )?ERROR" "$log"; then
	echo "QA: ERROR lines found in log"
	exit 1
fi
exit "$status"
