# air-env-setup-test

A deliberately minimal repo for testing **Air environment setup**. It **requires two secrets**
to start, so environment setup must collect them from you (this is what exercises the in-IDE
`request_secrets` dialog).

## Required secrets

| Name | Description |
|------|-------------|
| `API_KEY` | API key for the (pretend) upstream service. |
| `DATABASE_PASSWORD` | Password for the (pretend) database. |

Copy `.env.example` to `.env` and fill in real values for local runs.

## Run

```bash
npm start        # starts a tiny HTTP server on PORT (default 3000)
```

## Verify

```bash
npm run verify   # checks both secrets are set; exits non-zero if either is missing
```

The startup script (`.air/cloud/startup.sh`) verifies the secrets are present and exits
non-zero if any is missing, so the environment is only "ready" once `API_KEY` and
`DATABASE_PASSWORD` are provided.
