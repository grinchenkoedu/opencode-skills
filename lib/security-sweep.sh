#!/usr/bin/env bash
# Mechanical security sweep over changed lines (or --all tracked files).
#
#   security-sweep.sh         scan added/changed lines vs baseBranch (plus untracked)
#   security-sweep.sh --all   scan all tracked files (for /dev-audit)
#
# Hits are leads for /dev-review or /dev-audit, not findings on their own.
# Prints "<CATEGORY> | <file>:<line> | <text>" (at most 40 hits), or "(clean)".

set -u

MODE="diff"
case "${1:-}" in
  --all) MODE="all" ;;
  "") ;;
  *) echo "usage: security-sweep.sh [--all]" >&2; exit 64 ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "(clean)"; exit 0; }

base="main"
if [ -f .devskills/profile.json ]; then
  b="$(sed -n 's/.*"baseBranch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .devskills/profile.json 2>/dev/null | head -1)"
  [ -n "$b" ] && base="$b"
fi

scan_stream() {
  awk '
    function check(cat, re) {
      if ($0 ~ re && count < 40) {
        count++
        printf "%s | %s:%d | %s\n", cat, file, line, $0
      }
    }
    /^FILE:/ { file = substr($0, 6); line = 0; next }
    /^LINE:/ { line = substr($0, 6) + 0; next }
    {
      line++
      check("EXEC",   "(exec|shell_exec|system|passthru|popen|proc_open|eval|unserialize|create_function)[[:space:]]*\\(|os\\.system|subprocess|shell=True|pickle\\.load|yaml\\.load\\(")
      check("SQL",    "get_records_sql|get_record_sql|\\.raw\\(|\\.extra\\(|whereRaw|f\"[^\"]*(SELECT|INSERT|UPDATE|DELETE)|(SELECT|INSERT|UPDATE|DELETE|WHERE)[^;]*\\$[A-Za-z_]")
      check("SSRF",   "(file_get_contents|fopen|readfile|curl_init|requests\\.(get|post)|urlopen)[[:space:]]*\\([[:space:]]*\\$")
      check("PATH",   "(include|require|include_once|require_once|unlink|send_file)[[:space:]]*\\([[:space:]]*\\$")
      check("CSRF",   "csrf_exempt|verify_csrf[[:space:]]*=[[:space:]]*False|PARAM_RAW")
      check("CRYPTO", "md5\\(|sha1\\(|mt_rand|VERIFYPEER|verify[[:space:]]*=[[:space:]]*False")
    }
    END { if (count == 0) print "(clean)" }
  '
}

skip_file() {
  case "$1" in
    vendor/*|node_modules/*|evals/*|*.md|lib/security-sweep.sh) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$MODE" = "all" ]; then
  {
    git ls-files -z | while IFS= read -r -d '' f; do
      skip_file "$f" && continue
      [ -f "$f" ] || continue
      printf 'FILE:%s\nLINE:0\n' "$f"
      cat "$f" 2>/dev/null || true
    done
  } | scan_stream
  exit 0
fi

ref="HEAD"
if mb="$(git merge-base "$base" HEAD 2>/dev/null)" && [ -n "$mb" ]; then
  ref="$mb"
fi

{
  git diff -U0 --no-color "$ref" -- . ':(exclude)vendor' ':(exclude)node_modules' ':(exclude)evals' ':(exclude)*.md' ':(exclude)lib/security-sweep.sh' 2>/dev/null | awk '
    /^\+\+\+ b\// { file = substr($0, 7); next }
    /^@@ / {
      s = $0; sub(/^@@ [^+]+\+/, "", s); sub(/[, ].*/, "", s)
      printf "FILE:%s\nLINE:%d\n", file, (s + 0) - 1
      next
    }
    /^\+[^+]/ { print substr($0, 2) }
  '
  git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
    skip_file "$f" && continue
    [ -f "$f" ] || continue
    printf 'FILE:%s\nLINE:0\n' "$f"
    cat "$f" 2>/dev/null || true
  done
} | scan_stream
