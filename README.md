<div align="center">

# Abono

**An AI operating system for employer-funded salary advances in the Philippines.**

[![Build](https://github.com/lmagsino/abono/actions/workflows/build.yml/badge.svg)](https://github.com/lmagsino/abono/actions/workflows/build.yml)
[![Ruby](https://img.shields.io/badge/Ruby-3.3.11-CC342D?logo=ruby&logoColor=white)](.ruby-version)
[![Rails](https://img.shields.io/badge/Rails-8.1-D30001?logo=rubyonrails&logoColor=white)](abono-api/Gemfile)
[![Next.js](https://img.shields.io/badge/Next.js-16-000000?logo=nextdotjs&logoColor=white)](abono-web/package.json)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B%20%2B%20pgvector-4169E1?logo=postgresql&logoColor=white)](#database)

</div>

---

## What Abono is

Abono turns wages a worker has already earned into money they can reach before
payday — funded by their employer, repaid through the payroll deduction that
employer already runs. No lender. No credit check. No interest to the employee.

It is built as an operating system rather than a payments feature, because the
transfer is the easy part. The system that surrounds it does the real work:

- **An eligibility engine** that decides who can borrow how much, using
  deterministic rules — tenure, attendance, request frequency, outstanding
  balance — that a person can read, audit, and defend to a regulator.
- **A double-entry ledger** where every peso disbursed and repaid is recorded,
  and which reconciles against payroll cleanly at the end of every cycle.
- **Disbursement over InstaPay and PESONet**, so money lands in the worker's
  own bank or e-wallet within minutes of approval.
- **An AI layer** that explains decisions in plain language, answers employee
  questions, parses whatever CSV shape an HRIS exports, and lets an HR admin
  ask about their workforce in a sentence instead of a report builder.
- **Multi-tenancy from the first migration**, so each employer sees their own
  workforce and nothing else.

Two employers, two very different users: a worker on a mid-range Android phone
who needs an answer in seconds, and an HR administrator reconciling hundreds of
deductions against a payroll run.

> **Abono** — Filipino, from Spanish. To shoulder a cost on someone's behalf,
> with the understanding that it comes back. *"Abonohan mo muna ako."*

---

## How it works

From the worker's side, the whole thing is four steps and a payday.

```mermaid
flowchart LR
    A["<b>1 · Request</b><br/>Opens the app,<br/>asks for ₱3,000"]
    B["<b>2 · Decision</b><br/>Checked against<br/>their earned wages<br/><i>seconds</i>"]
    C["<b>3 · Money arrives</b><br/>Sent to their bank<br/>or e-wallet<br/><i>minutes</i>"]
    D["<b>4 · Payday</b><br/>₱3,000 deducted<br/>from payroll<br/><i>automatic</i>"]
    E["<b>Settled</b><br/>Nothing owed.<br/>No interest."]

    A --> B --> C --> D --> E

    classDef step fill:#eff6ff,stroke:#3b82f6,color:#1e3a8a
    classDef done fill:#dcfce7,stroke:#16a34a,color:#14532d
    class A,B,C,D step
    class E done
```

Nothing is borrowed from a lender. The money is the worker's own earned wages,
released early by the employer:

```mermaid
flowchart LR
    subgraph cycle["A single pay cycle"]
        direction LR
        emp["<b>Employer</b><br/>funds the float"]
        abono["<b>Abono</b><br/>checks eligibility,<br/>keeps the ledger"]
        worker["<b>Worker</b><br/>receives ₱3,000<br/>mid-cycle"]
        payroll["<b>Payroll</b><br/>deducts ₱3,000<br/>on payday"]
    end

    emp -->|"advance funded"| abono
    abono -->|"InstaPay / PESONet"| worker
    worker -->|"earns the rest<br/>of the cycle"| payroll
    payroll -->|"employer made whole"| emp

    classDef money fill:#fefce8,stroke:#ca8a04,color:#713f12
    classDef sys fill:#dcfce7,stroke:#16a34a,color:#14532d
    class emp,worker,payroll money
    class abono sys
```

The loop closes every cycle. The employer is repaid in full, the worker pays
nothing extra, and no third party takes a cut in between — which is the entire
point.

### What the employer sees

```mermaid
flowchart TB
    hr["<b>HR Administrator</b>"]

    hr --> setup["Set up the company<br/><i>rules, limits, float</i>"]
    hr --> roster["Upload the roster<br/><i>any HRIS export</i>"]
    hr --> monitor["Watch the float<br/><i>what is out, what is due</i>"]
    hr --> recon["Reconcile payday<br/><i>deductions matched<br/>to advances</i>"]

    classDef admin fill:#f5f3ff,stroke:#8b5cf6,color:#4c1d95
    class hr,setup,roster,monitor,recon admin
```

---

## Architecture

Two applications, one Postgres, no Redis.

```mermaid
flowchart TB
    subgraph clients["Clients"]
        emp["Employee<br/><i>mobile-first</i>"]
        hr["HR Admin<br/><i>dashboard</i>"]
    end

    subgraph web["abono-web · Next.js 16"]
        ui["React 19 · TypeScript · Tailwind 4"]
    end

    subgraph api["abono-api · Rails 8.1 API"]
        rest["REST endpoints"]
        engine["Eligibility engine"]
        ledger["Ledger &amp; reconciliation"]
        ai["AI layer"]
        jobs["Solid Queue workers"]
    end

    subgraph data["PostgreSQL + pgvector"]
        core[("Core tables")]
        solid[("Queue · Cache · Cable")]
    end

    subgraph external["External services"]
        rails_dis["Disbursement<br/>PayMongo / Xendit"]
        instapay["InstaPay / PESONet"]
        claude["Claude API"]
    end

    emp --> ui
    hr --> ui
    ui -->|HTTPS / JSON| rest
    rest --> engine
    rest --> ledger
    rest --> ai
    engine --> ledger
    ledger --> jobs
    engine --> core
    ledger --> core
    ai --> core
    jobs --> solid
    jobs --> rails_dis
    rails_dis --> instapay
    ai --> claude

    classDef built fill:#dcfce7,stroke:#16a34a,color:#14532d
    classDef planned fill:#f1f5f9,stroke:#94a3b8,color:#475569,stroke-dasharray: 4 3
    class ui,rest,core,solid,jobs built
    class engine,ledger,ai,rails_dis,instapay,claude planned
```

<sub>■ Green — scaffolded and running. ▢ Dashed — designed, not yet built.</sub>

### Why this stack

| Decision | Reasoning |
| --- | --- |
| **Rails 8.1, API-only** | Money movement needs transactional integrity and an auditable ledger far more than it needs a novel runtime. Active Record's transaction and locking semantics are the point. |
| **Postgres for everything** | Solid Queue, Solid Cache and Solid Cable put jobs, cache and websockets in Postgres. One database to back up, one to secure, one to reason about during an incident. **No Redis.** |
| **pgvector in from day one** | The AI layer needs embeddings. Adding the extension during scaffolding costs one migration; retrofitting it into a live financial database costs a maintenance window. |
| **Next.js 16, server-first** | Two audiences with opposite needs — a worker on a mid-range Android phone, an HR admin on a desktop. Server rendering keeps the mobile bundle small without splitting the codebase. |
| **Monorepo** | One person, two deployables, one atomic commit when an API contract changes. |

---

## The same flow, technically

**Designed, not yet implemented** — Phase 1 delivers the scaffolding it runs on.

```mermaid
sequenceDiagram
    autonumber
    actor E as Employee
    participant W as abono-web
    participant A as abono-api
    participant EE as Eligibility engine
    participant L as Ledger
    participant D as Disbursement
    participant P as Payroll

    E->>W: Request advance
    W->>A: POST /advances
    A->>EE: Evaluate request

    Note over EE: Deterministic rules —<br/>tenure, attendance,<br/>request frequency,<br/>outstanding balance

    alt Approved
        EE-->>A: Approved + limit
        A->>L: Record advance, adjust balance
        A->>D: Queue transfer
        D->>D: InstaPay / PESONet
        D-->>A: Webhook — settled
        A->>L: Mark disbursed
        A-->>W: Confirmed + repayment schedule
    else Declined
        EE-->>A: Declined + reason code
        A-->>W: Plain-language explanation
    end

    Note over P,L: Next payroll cycle
    P->>A: Deduction records
    A->>L: Reconcile against outstanding
    L-->>E: Balance cleared
```

Two things this diagram is quietly insisting on:

- **Eligibility is deterministic, never a model.** AI explains a decision after
  the fact; it never makes one.
- **A declined request returns a reason code.** "No" without a why is how
  workers lose trust in a system meant to be on their side.

---

## Repository layout

```
abono/
├── abono-api/                 Rails 8.1 · API-only
│   ├── app/
│   ├── config/
│   │   ├── database.yml       env-driven, sane local defaults
│   │   ├── cache.yml          Solid Cache
│   │   ├── queue.yml          Solid Queue
│   │   └── cable.yml          Solid Cable
│   ├── db/migrate/            includes pgvector enablement
│   └── bin/jobs               background worker
│
├── abono-web/                 Next.js 16 · TypeScript · Tailwind 4
│   └── src/app/
│       ├── page.tsx
│       └── health/            server-rendered API health check
│
├── .github/workflows/build.yml
└── phased-build-plan.md       full roadmap
```

---

## Getting started

### Requirements

| | Version | Notes |
| --- | --- | --- |
| Ruby | 3.3.11 | pinned in `.ruby-version` |
| Node.js | 22+ | |
| PostgreSQL | 15+ | with [pgvector](https://github.com/pgvector/pgvector) available |

### Database

pgvector must be built against the **same** `pg_config` as your running server.
If Postgres came from a version manager, the Homebrew formula will link against
the wrong installation and the extension will not load:

```sh
git clone --branch v0.8.1 --depth 1 https://github.com/pgvector/pgvector.git
cd pgvector
make PG_CONFIG=$(which pg_config)
make install PG_CONFIG=$(which pg_config)
```

Confirm it resolves:

```sh
psql -U postgres -c "SELECT '[1,2,3]'::vector <-> '[4,5,6]'::vector;"
#  ?column?
# -------------------
#  5.196152422706632
```

### Run it

```sh
git clone git@github.com:lmagsino/abono.git
cd abono
```

**API** — port 3000:

```sh
cd abono-api
bundle install
bin/rails db:prepare      # creates databases, enables pgvector
bin/rails server
```

**Web** — port 3001:

```sh
cd abono-web
npm install
npm run dev
```

### Confirm it works

| Check | Expected |
| --- | --- |
| <http://localhost:3000/up> | `200` — Rails booted cleanly |
| <http://localhost:3001/health> | Both services reported **up** |

`/health` server-renders a live fetch against the API's `/up`, which makes it
the fastest way to confirm the two are actually talking — not just that both
processes started.

---

## Configuration

Each app ships a `.env.example` documenting its variables:

```sh
cp abono-api/.env.example abono-api/.env
cp abono-web/.env.example abono-web/.env.local
```

Defaults assume a stock local Postgres (`postgres` role on `localhost:5432`), so
a fresh clone runs with no configuration at all.

> [!NOTE]
> **Rails does not load `.env` automatically** — no dotenv gem is installed.
> Export the variables or add `dotenv-rails`. Next.js does load `.env.local`.

> [!IMPORTANT]
> Only `.example` files are tracked; real `.env` files are gitignored.
> Production secrets belong in Rails encrypted credentials or a secrets
> manager — never in the repository.

### Background jobs

Solid Queue, Solid Cache and Solid Cable run at the Rails 8 defaults, all
Postgres-backed. Development uses an in-memory cache and an async cable adapter,
so nothing extra needs to be running locally.

```sh
cd abono-api && bin/jobs      # start the worker
```

---

## Continuous integration

`.github/workflows/build.yml` runs on every push and pull request to `main`:

```mermaid
flowchart LR
    push["push / PR → main"] --> api["<b>abono-api</b><br/>bundle install<br/>db:prepare vs pgvector<br/>zeitwerk:check"]
    push --> web["<b>abono-web</b><br/>npm ci<br/>next build"]
    api --> ok["✓"]
    web --> ok

    classDef job fill:#f8fafc,stroke:#64748b,color:#1e293b
    class api,web job
```

Build-only by design. The API job migrates against a real pgvector-enabled
Postgres, so a broken extension or migration fails CI rather than production.

There is no test suite yet — RSpec and Playwright arrive in Phase 8 and get
their own jobs then.

---

## Roadmap

| Phase | Scope | Status |
| :---: | --- | :---: |
| **1** | Project scaffolding, Postgres + pgvector, CI, health checks | ✅ Complete |
| **2** | Core data model — tenants, employees, advances, ledger, repayments | Planned |
| **3** | Business logic — eligibility engine, ledger, reconciliation | Planned |
| **4** | Disbursement via PayMongo / Xendit sandbox, InstaPay + webhooks | Planned |
| **5** | Employee app and HR dashboard | Planned |
| **6** | AI layer — decision explanations, chat assistant, CSV parsing | Planned |
| **7** | Deployment via Kamal 2, Sentry, OpenTelemetry | Planned |
| **8** | RSpec + Playwright suites, KYB, live credentials, security review | Planned |

Full detail in [`phased-build-plan.md`](phased-build-plan.md).

**Currently at Phase 1.** No live API keys, disbursement integrations or tests
exist yet, by design — multi-tenancy and the ledger are settled before any money
moves.

---

## Design principles

**Deterministic decisions, AI explanations.** Eligibility runs on auditable
rules. The AI layer translates outcomes into plain language and answers
questions — it never approves or declines.

**The ledger is the source of truth.** Every peso disbursed and repaid is a
double-entry record. Reconciliation is a first-class feature, not a monthly
spreadsheet.

**Tenant isolation from the first migration.** Employers see their own workforce
and nothing else. Row-level scoping lands in Phase 2, before any real data does.

**No employee ever pays interest.** Employers fund the float. The moment a
worker pays for access to wages they already earned, this becomes the thing it
was built to replace.

---

<sub>Leo Magsino Jr. · [github.com/lmagsino](https://github.com/lmagsino)</sub>
