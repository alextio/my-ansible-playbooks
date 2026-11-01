---
name: bws-upsert-secret
description: Create or update a secret in Bitwarden Secrets Manager and get the UUID to use as an ExternalSecret remoteRef.key. Use when adding or rotating a secret for an ExternalSecret, generating a random password/key, or storing a bcrypt password hash.
---

# bws-upsert-secret

Wraps `bws` to create a secret in Bitwarden Secrets Manager and print its UUID,
which is what an `ExternalSecret`'s `remoteRef.key` needs. The script is
`bws_upsert_secret.sh`, next to this file. Run it from the repo root:

```bash
.claude/skills/bws-upsert-secret/bws_upsert_secret.sh [-p project-id|name] [-n note] [-b|--bcrypt] [--format alnum|base64|hex] [--input-password] KEY
```

Needs `bws`, `openssl` and `BWS_ACCESS_TOKEN` in the environment (`htpasswd`
for `--bcrypt`).

## Cases

- **Random value** (default): refuses to overwrite an existing secret, because
  that would rotate it. `--format` picks the shape: `alnum` (32 chars,
  default), `base64` (`openssl rand -base64 32`), `hex` (`openssl rand -hex 32`).
  Use `base64`/`hex` when the consumer needs real key bytes.
- **Your own value**: `--input-password` reads stdin, or prompts (hidden,
  twice) on a terminal. Updates an existing secret in place.
- **Password hash**: `-b`/`--bcrypt` stores the bcrypt hash. For a generated
  password the plaintext is kept as `KEY-plaintext` so someone can log in; the
  hash entry's note says so. The printed `remoteRef.key` is the hash's UUID.

Always pass `-p <project>` when not on a terminal (the menu needs one).

## After running

Put the printed `remoteRef.key` UUID into the `ExternalSecret`. In this repo
every new `ExternalSecret` sets `spec.refreshPolicy: CreatedOnce` (see
CLAUDE.md).

Never paste generated or supplied secret values into files, commits or chat.
The value reaches `bws` as an argument, so it is briefly visible in the process
list.
