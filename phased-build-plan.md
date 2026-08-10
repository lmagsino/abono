# Abono — phased build plan

One note before diving in: this plan puts all testing and live credentials in the last phase, as requested. Worth knowing the trade-off — writing tests alongside each phase instead of all at the end usually catches bugs earlier and is less painful than backfilling a whole test suite at once. Flagging it, not overriding the sequencing you asked for.

---

## Phase 1 — Project setup & GitHub setup

- Register **abono.ph** (verify availability via dot.ph or a registrar's WHOIS check first); consider grabbing abono.com defensively too
- Do a quick trademark search in the Philippines for "Abono" in financial services/software classes before fully committing to the name
- Create the GitHub repo (monorepo or two repos — `abono-api` and `abono-web` — pick one; monorepo is simpler solo)
- Set up branch protection on `main`, a `.gitignore`, and a README with setup instructions
- Initialize Rails 8.1 in API mode (`rails new abono-api --api`)
- Initialize Next.js 16 with TypeScript and Tailwind (`create-next-app`)
- Set up local Postgres 17 and connect Rails to it
- Add the pgvector extension to Postgres
- Set up Solid Queue, Solid Cache, Solid Cable (Rails 8 defaults)
- Create `.env.example` files for both apps (no real secrets committed)
- Set up a basic GitHub Actions workflow file (build-only for now — no tests yet, that's Phase 8)
- Add a health-check endpoint (`/up`) on the Rails side and confirm Next.js can reach it locally

## Phase 2 — Core data model

- Design and migrate: `tenants`, `employees`, `advances`, `ledger_entries`, `repayments`
- Add `tenant_id` scoping (row-level multi-tenancy) via `acts_as_tenant` or equivalent
- Seed script with fake tenant/employee data for local development

## Phase 3 — Rails API core (business logic)

- Eligibility engine: deterministic rules (tenure, attendance, request frequency, outstanding balance)
- Ledger logic: track disbursed amounts, running balances, repayment status
- Repayment reconciliation: match payroll deduction records against disbursed advances

## Phase 4 — Disbursement integration (sandbox)

- Register PayMongo and/or Xendit sandbox accounts, get test-mode API keys
- Build the disbursement service object (calls InstaPay/PESONet transfer endpoint)
- Build webhook handler for transfer status updates
- Wire disbursement calls to the eligibility engine's approval step

## Phase 5 — Frontend

- Next.js employee app: request advance, view available amount, repayment preview screen
- Next.js HR dashboard: tenant setup flow, employee roster, float visibility, approvals view
- Connect both to the Rails API

## Phase 6 — AI layer (Phase 1 AI features)

- Claude API integration in Rails for: plain-language decision explanations, employee chat assistant, payroll/HRIS CSV parsing, natural-language admin queries
- No trained models yet — this phase is LLM calls only, no historical data required

## Phase 7 — Deployment & observability

- Set up Kamal 2 for deployment (Docker-based)
- Configure Sentry for error tracking
- Configure OpenTelemetry for basic tracing
- Deploy a staging environment

## Phase 8 — Testing & credentials (live)

- Write the RSpec suite for the Rails core (eligibility, ledger, disbursement service)
- Write Playwright end-to-end tests for the employee and HR flows
- Complete real KYB verification on PayMongo/Xendit for the pilot employer's wallet
- Switch from sandbox to live API keys (store via Rails encrypted credentials or a secrets manager — never committed to the repo)
- Run a real InstaPay disbursement end-to-end with the pilot employer
- Security review pass before onboarding real employee data
