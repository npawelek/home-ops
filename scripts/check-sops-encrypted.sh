#!/usr/bin/env bash
# Fail the commit if a staged file that .sops.yaml says must be encrypted is not.
# The path_regex list in .sops.yaml is the source of truth, so new rules are covered
# automatically. `sops filestatus` only reads metadata; it never decrypts.
set -euo pipefail

patterns=()
while IFS= read -r rx; do patterns+=("$rx"); done < <(yq '.creation_rules[].path_regex' .sops.yaml)

failed=0
for file in "$@"; do
    for rx in "${patterns[@]}"; do
        [[ $file =~ $rx ]] || continue
        if ! sops filestatus "$file" | grep -q '"encrypted":true'; then
            echo "✗ $file matches '$rx' in .sops.yaml but is not encrypted" >&2
            failed=1
        fi
        break
    done
done
exit $failed
