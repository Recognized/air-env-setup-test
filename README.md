# air-env-setup-test

A deliberately minimal repo for testing **Air environment setup**. It **requires two secrets**
to run, so environment setup must collect them from you (this is what exercises the in-IDE
`request_secrets` dialog).

There is intentionally **no setup/startup script** in this repo — Air environment setup is
expected to generate it.

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

`app.js` exits with a non-zero code unless both `API_KEY` and `DATABASE_PASSWORD` are set, so
the app cannot start until the secrets are provided.
