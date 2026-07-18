# Git workflow

```
main                 # runnable releases
  └── develop        # integration
        └── feature/* / fix/*
```

## Rules

1. Land work through PRs into `develop`; promote to `main` when demo-ready.
2. One concern per branch; prefer several small commits over one dump.
3. Never commit `.env` — only `.env.example`.
4. Protect `main` on GitHub (PR required, no force-push).

## Commit messages

Write what a teammate would write:

```
add postgres migrations for users and events
hmac webhook ingest with idempotency
worker claim loop and retries
flutter auth gate and secure storage
```

Avoid noise: `Update files`, `Enhance architecture`, empty `Initial commit` spam.

## Review checklist

- [ ] Tests for the changed path pass locally
- [ ] No secrets or personal notes in the tree
- [ ] README / architecture still match behavior
