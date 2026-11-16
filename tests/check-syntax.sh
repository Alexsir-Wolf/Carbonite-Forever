#!/usr/bin/env bash
# Compiles every addon Lua file with luac 5.1 (the WoW dialect) without running it.
# The client accepts a UTF-8 BOM at the start of a file and luac does not, so it is stripped.
# Usage: tests/check-syntax.sh [luac]   (default: luac5.1, falling back to luac)
set -euo pipefail
LUAC="${1:-$(command -v luac5.1 || command -v luac)}"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
status=0
count=0
while IFS= read -r -d '' file; do
    count=$((count + 1))
    src="$file"
    if [ "$(head -c 3 "$file" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
        tail -c +4 "$file" > "$tmp"
        src="$tmp"
    fi
    if ! out="$("$LUAC" -p "$src" 2>&1)"; then
        echo "$file: ${out#*:}"
        status=1
    fi
done < <(find . -name '*.lua' -not -path './.git/*' -print0)
[ "$status" -eq 0 ] && echo "syntax ok ($count files)"
exit "$status"
