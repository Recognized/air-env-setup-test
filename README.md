# air-env-setup-test

A deliberately minimal repo for testing **Air environment setup**. It **requires two secrets**
to run, so environment setup must collect them from you (this is what exercises the in-IDE
`request_secrets` dialog).

The generated `start.sh` script loads `.env` when present and starts the app.
It also accepts secrets injected into the process environment by Air.

## Required secrets

| Name | Description |
|------|-------------|
| `API_KEY` | API key for the (pretend) upstream service. |
| `DATABASE_PASSWORD` | Password for the (pretend) database. |

Copy `.env.example` to `.env` and fill in real values for local runs.

## Run

Node.js 22.9 or newer is required for the startup script. There are no external
dependencies to install. Copy `.env.example` to `.env` and replace both placeholder
values before starting locally.

```bash
./start.sh       # loads .env and starts the server
```

When both secrets are already exported into the environment, you can also run:

```bash
npm start        # starts a tiny HTTP server on PORT (default 3000)
```

Check the running server with `curl --fail http://localhost:3000/`; it should return `ok`.

`app.js` exits with a non-zero code unless both `API_KEY` and `DATABASE_PASSWORD` are set, so
the app cannot start until the secrets are provided.
