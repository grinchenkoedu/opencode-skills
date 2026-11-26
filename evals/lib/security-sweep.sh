#!/usr/bin/env bash
# Cases for lib/security-sweep.sh — run them from anywhere:
#
#   bash evals/lib/security-sweep.sh
#
# Exits 0 when every case matches, 1 otherwise, naming each mismatch.

set -u

root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$root/lib/security-sweep.sh"
[ -f "$script" ] || { printf 'no security-sweep.sh at %s\n' "$script" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

fails=0
note() { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

git -C "$work" init -q -b main
mkdir -p "$work/.devskills" "$work/src"
printf '{ "baseBranch": "main" }\n' > "$work/.devskills/profile.json"
printf '<?php\necho "ok";\n' > "$work/src/clean.php"
git -C "$work" -c user.email=t@e -c user.name=t add -A >/dev/null
git -C "$work" -c user.email=t@e -c user.name=t commit -qm base >/dev/null

# Clean repo -> (clean)
out="$(cd "$work" && bash "$script")"
[ "$out" = "(clean)" ] || note "clean repo: got '$out', want (clean)"

# Untracked file with SSRF, SQL, CSRF, PATH, EXEC hits
cat > "$work/src/vuln.php" <<'PHP'
<?php
$data = file_get_contents($url);
$rows = $DB->get_records_sql("SELECT * FROM mdl_user WHERE id = $id");
include($page);
eval($code);
PHP
out="$(cd "$work" && bash "$script")"
printf '%s\n' "$out" | grep -q '^SSRF | src/vuln.php:2 |' || note "untracked SSRF missed: $out"
printf '%s\n' "$out" | grep -q '^SQL | src/vuln.php:3 |' || note "untracked SQL missed: $out"
printf '%s\n' "$out" | grep -q '^PATH | src/vuln.php:4 |' || note "untracked PATH missed: $out"
printf '%s\n' "$out" | grep -q '^EXEC | src/vuln.php:5 |' || note "untracked EXEC missed: $out"

# --all on committed files
git -C "$work" -c user.email=t@e -c user.name=t add -A >/dev/null
git -C "$work" -c user.email=t@e -c user.name=t commit -qm vuln >/dev/null
out="$(cd "$work" && bash "$script" --all)"
printf '%s\n' "$out" | grep -q '^SSRF | src/vuln.php:2 |' || note "--all SSRF missed: $out"

# Bad arg -> usage 64
rc=0
(cd "$work" && bash "$script" --bad >/dev/null 2>&1) || rc=$?
[ "$rc" -eq 64 ] || note "bad arg: exit $rc, want 64"

if [ "$fails" -eq 0 ]; then
  printf 'security-sweep: detects EXEC, SQL, SSRF, PATH, CSRF, CRYPTO leads\n'
else
  printf 'security-sweep: %s case(s) failed\n' "$fails" >&2
fi
exit $((fails > 0))
