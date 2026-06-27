# Contributing

Community infra tooling — PRs welcome.

- **Never commit secrets**: iDRAC creds, internal IPs, service tags, subscription IDs.
  Real specs live in `specs/*.local.yaml` (gitignored); commit only `specs/example.yaml`.
- Keep scripts POSIX-ish and idempotent; read creds from the environment.
- New gotchas are gold — add them to `RUNBOOK.md`'s catalog with the symptom + fix.
- `main` is protected: open a PR; one approval merges.
