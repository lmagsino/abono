# Abono

An AI operating system for employer-funded salary advances in the Philippines.

This is a monorepo with two applications:

| Directory   | Stack                                    | Local port |
| ----------- | ---------------------------------------- | ---------- |
| `abono-api` | Rails 8.1 (API mode), PostgreSQL, Solid\* | 3000       |
| `abono-web` | Next.js 16, TypeScript, Tailwind CSS 4   | 3001       |

## Requirements

- Ruby 3.3.11 (pinned in `.ruby-version`)
- Node.js 22+
- PostgreSQL 15+ with the [pgvector](https://github.com/pgvector/pgvector) extension available

The build plan targets PostgreSQL 17; local development currently runs on 15.17,
which pgvector and everything else here support.

### Installing pgvector

If your Postgres was installed through a version manager, the Homebrew formula
will link against the wrong installation. Build it against your own `pg_config`:

```sh
git clone --branch v0.8.1 --depth 1 https://github.com/pgvector/pgvector.git
cd pgvector
make PG_CONFIG=$(which pg_config)
make install PG_CONFIG=$(which pg_config)
```

Confirm it is available:

```sh
psql -U postgres -c "SELECT '[1,2,3]'::vector <-> '[4,5,6]'::vector;"
```

## Setup

```sh
git clone git@github.com:lmagsino/abono.git
cd abono
```

### API

```sh
cd abono-api
bundle install
bin/rails db:prepare      # creates development + test databases, enables pgvector
bin/rails server          # http://localhost:3000
```

Health check: <http://localhost:3000/up> — returns 200 when the app boots cleanly.

### Web

```sh
cd abono-web
npm install
npm run dev               # http://localhost:3001
```

Health check: <http://localhost:3001/health> — server-renders the status of both
the web app and the API, and is the quickest way to confirm the two are talking
to each other.

## Configuration

Each app ships a `.env.example` documenting its variables. Copy what you need:

```sh
cp abono-api/.env.example abono-api/.env
cp abono-web/.env.example abono-web/.env.local
```

The defaults assume a stock local Postgres (`postgres` role on
`localhost:5432`), so a fresh clone runs without setting anything.

Two things worth knowing:

- **Rails does not load `.env` automatically.** No dotenv gem is installed yet,
  so export the variables in your shell or add `dotenv-rails` if you want file
  loading. Next.js does load `.env.local` on its own.
- **Never commit real credentials.** `.env` files are gitignored; only the
  `.example` files are tracked. Production secrets belong in Rails encrypted
  credentials or a secrets manager.

## Background jobs, cache and cable

Solid Queue, Solid Cache and Solid Cable are installed at the Rails 8 defaults —
all Postgres-backed, no Redis anywhere. They are wired up for production; in
development Rails uses an in-memory cache and an async cable adapter, so there
is nothing extra to run locally.

To run the job worker:

```sh
cd abono-api && bin/jobs
```

## CI

`.github/workflows/build.yml` runs on pushes and pull requests to `main`. It is
**build-only**: the API installs gems, migrates against a pgvector-enabled
Postgres and verifies eager loading; the web app installs and builds.

There is no test suite yet — RSpec and Playwright arrive in Phase 8, and get
their own CI jobs then.

## Project status

Phase 1 (project scaffolding) is complete. See `phased-build-plan.md` for the
full roadmap. No live API keys, disbursement integrations or tests exist yet —
those belong to later phases.
