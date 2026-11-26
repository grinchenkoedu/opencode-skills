---
name: dev-audit
description: Audit a whole repository for security flaws, data-safety gaps, dependency advisories, and agent-readiness — outputs a branch-sized .tasks/audit-<repo>.md plan for /dev-implement.
---

# Audit the whole repository

No production code is written here. Inspect the repository as a whole and write a grounded remediation plan in `<root>/.tasks/audit-<repo>.md`.

## Step 1 — Check readiness and secrets

1. **Agent readiness:** check `AGENTS.md` (offer `/dev-init` if missing), `.gitignore` (`.devskills/`, `.tasks/`), and `profile.sh` (`test` / `lint` detected).
2. **Tracked secrets:** run `git ls-files '.env' '*.pem' 'id_rsa*'` and `git grep -n '-----BEGIN .*PRIVATE KEY'`. Any hit is a **BLOCKER**.

## Step 2 — Security & quality sweep

1. Review every hit from `security-sweep.sh --all` below (`EXEC`, `SQL`, `SSRF`, `PATH`, `CSRF`, `CRYPTO`). Open each file (`sed -n '<l-10>,<l+10>p'`) and drop false positives; keep only proven findings with `path:line`.
2. Check database/bulk scripts for dry-run defaults, bounded scope, and idempotency; check entry points for auth/authz/CSRF.
3. Run dependency audit if a lock file exists (`composer audit`, `npm audit --omit=dev`, `pip-audit`).

## Step 3 — Ask what blocks a fix

If findings depend on a policy choice (which licence, whether a copyleft dependency stays, or whether a legacy endpoint can be removed), ask once in chat with a recommendation per question.

## Step 4 — Write the audit plan

Group findings into branch-sized steps (max 3–5 files per step) in `<root>/.tasks/audit-<repo>.md` using `/dev-plan` format (`N. [ ] <title>` with `Create:`, `Modify:`, `Test:`, `Red:`, `Check:`, `Budget:` lines) and Acceptance criteria (`- [ ]`).

Validate:
```bash
bash ${DEV_SKILLS_LIB:-$HOME/.config/opencode/dev-lib}/plan-check.sh .tasks/audit-<repo>.md
bash ${DEV_SKILLS_LIB:-$HOME/.config/opencode/dev-lib}/step-budget.sh .tasks/audit-<repo>.md 1
```

## Step 5 — Report

Print summary counts (BLOCKER / WARNING / NIT), the path to `.tasks/audit-<repo>.md`, and `Next: /dev-implement .tasks/audit-<repo>.md`.

## Rules

- No production code. Absolute paths under root (never `~`). English.

---

## This repository

Root:

!`pwd`

Profile:

!`bash ${DEV_SKILLS_LIB:-$HOME/.config/opencode/dev-lib}/profile.sh`

Security sweep (all tracked files — leads to verify):

!`bash ${DEV_SKILLS_LIB:-$HOME/.config/opencode/dev-lib}/security-sweep.sh --all`
