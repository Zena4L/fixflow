# FixFlow

A lightweight request / issue tracker. **Requesters** raise requests and follow them; **staff** triage, assign, work and resolve them. Built with Ruby on Rails 8.1 and [Plutonium Core](https://radioactive-labs.github.io/plutonium-core/) 0.67.

## Features

- **Two portals, two account types** (Rodauth): requesters at `/requester` (public sign-up, email verification), staff at `/staff` (no self-sign-up; admins add staff).
- **Requests** with priority (Low / Medium / High / Urgent) and a server-enforced workflow:

  ```
  Submitted → Open → In progress → Resolved → Closed
                ↑                      │         │
                └────── Reopen ────────┴─────────┘
  ```

  Requesters can reopen *resolved* requests; staff can reopen resolved or *closed* ones. Resolving requires a resolution note. Work cannot start without an assignee (starting auto-assigns you).
- **Assignment** to active staff, **comments** (staff can post internal notes that requesters never see), and an append-only **activity log** of every change and who made it.
- **Staff queue**: search (title, description, or reference such as `FF-00042`), filters (status, priority, assignee, requester, created date), quick scopes (Active, Submitted, Unassigned, Mine, Urgent), sortable columns and pagination. Overview dashboard with queue metrics and charts.
- **Editing / deletion rules**: requesters edit or delete their own request only while it is *Submitted*; staff edit anything not closed; only admins delete. Closed requests are read-only. Comments and activity entries are immutable.
- Staff roles: **admin** (manages staff, deletes requests) and **agent**. Deactivated staff are signed out on their next request and cannot sign back in, including through a "Remember me" cookie.
- **Brute-force protection**: an account locks for an hour after 10 wrong passwords (or until unlocked from the emailed link), and sign-in and email-sending forms are rate limited per IP.

All rules are enforced on the server (policies, model validations and database constraints), not just hidden in the UI.

## Requirements

- Ruby **3.4.11** (pinned in `.ruby-version` / `mise.toml`), Node **26** (`.node-version`), Yarn 1.x, SQLite 3.
- macOS example using [mise](https://mise.jdx.dev):

  ```bash
  brew install mise libyaml
  mise install            # installs the pinned Ruby
  npm install -g yarn     # if yarn is not already installed
  ```

No other services (Redis, Postgres, Docker) are needed for development or tests.

## Setup & run

```bash
mise x -- bin/setup --skip-server   # installs gems + JS packages, creates & seeds the DB
mise x -- bin/dev                   # Rails server + JS/CSS watchers on http://localhost:3000
```

(If mise is activated in your shell — `eval "$(mise activate zsh)"` — drop the `mise x --` prefix.)

Open <http://localhost:3000>. Demo accounts (password **`password123`**, development only):

| Role | Email | Portal |
|---|---|---|
| Staff admin | `admin@fixflow.test` | `/staff` |
| Staff agent | `agent@fixflow.test` | `/staff` |
| Requester | `riley@fixflow.test`, `sam@fixflow.test` | `/requester` |

Emails (verification, password reset) open in the browser via `letter_opener` in development.
Reset the database at any time with `bin/rails db:reset`.

## Common commands

| Task | Command |
|---|---|
| Run the app | `bin/dev` |
| Full local CI (style, audits, Brakeman, tests, seeds) | `bin/ci` |
| Tests | `bin/rails test` (single file: `bin/rails test test/models/service_request_test.rb`) |
| Lint / autofix | `bundle exec standardrb` / `bundle exec standardrb --fix` |
| Security scan | `bin/brakeman --no-pager` |
| Dependency audits | `bin/bundler-audit`, `yarn audit` |
| Console | `bin/rails console` |
| Routes | `bin/rails routes` |

## Architecture

FixFlow follows Plutonium's resource architecture: each resource is a **model** (data + domain rules), a **definition** (how it renders: fields, search, filters, scopes, actions), a **policy** (who may do what, which attributes), and a thin **controller**; **interactions** are the buttons in front of domain operations. Resources live in the main app and are exposed through two **portal packages** (Rails engines) with their own auth.

```
app/
  models/            ServiceRequest (workflow), Comment, Activity, User, StaffMember, Current
  models/concerns/   ActivityTracking (writes the audit log)
  definitions/       shared UI definitions
  policies/          base policies — deny everything (see ResourcePolicy)
  interactions/service_requests/   Triage, Assign, Start, Resolve, Close, Reopen
  rodauth/           Rodauth configs for :user and :staff_member
packages/
  requester_portal/  /requester — policies scope everything to the signed-in requester
  staff_portal/      /staff     — queue definition, staff/requester admin, dashboard
db/migrate/          schema incl. CHECK constraints and FKs
test/                models, policies, interactions, integration (HTTP) tests
```

Where each rule lives:

| Rule | Enforced by |
|---|---|
| Legal status moves | `ServiceRequest::TRANSITIONS` + validation (any save path) and DB check on range |
| Who may trigger a move | portal policy predicates (`triage?`, `close?`, …) |
| Who sees which records | portal policy `relation_scope` (requester ⇒ own requests, no internal notes) |
| Which fields can be submitted | `permitted_attributes_for_*` (status/requester/assignee never mass-assignable) |
| Authorship / requester | controller `resource_params` hook, from the session |
| Single author, staff-only internal notes, enum ranges | model validations **and** SQLite `CHECK` constraints |

More detail and the reasoning behind choices: [`docs/decisions.md`](docs/decisions.md). Contributor/agent conventions: [`AGENTS.md`](AGENTS.md).

## Testing

`bin/rails test` runs 115 tests (Minitest, using `Plutonium::Testing`):

- `test/models` — every legal and illegal transition, validations, DB constraints, activity log.
- `test/policies` — permission matrices per portal × role × status.
- `test/interactions` — workflow interactions (success and failure).
- `test/integration` — Plutonium-generated CRUD/policy/definition suites per portal, the full submit→resolve→close→reopen journey over HTTP, access-control and forged-parameter attacks, error states, and a page-rendering smoke test.

## Configuration

- `.env` (git-ignored) holds non-secret defaults such as `RAILS_DEFAULT_URL`; `bin/setup` creates it from `.env.template` if missing. Put secrets in `.env.local` (also git-ignored).
- Production runs on PostgreSQL (`DATABASE_URL`), with inline jobs and an in-memory cache. See **Deployment**.

## Deployment (Vercel + Neon Postgres)

FixFlow runs on Vercel's Container Runtime (beta) from `Dockerfile.vercel`, with a Neon Postgres database. Vercel containers are stateless (no disk, no worker processes), which is why production uses Postgres and runs jobs inline.

Live: <https://fixflow-eosin-kappa.vercel.app>

One-time setup (already done for this project):

1. `npm i -g vercel && vercel login`, then `vercel link --project fixflow`.
2. Vercel dashboard → project → **Storage → Create Database → Neon** (Free), connected to Production and Preview. This adds `DATABASE_URL` and `DATABASE_URL_UNPOOLED`.
3. Environment variables (Production, and Preview where noted):

   | Variable | Value |
   |---|---|
   | `RAILS_MASTER_KEY` | contents of `config/master.key` (sensitive; Production + Preview) |
   | `PORT` | `8080` (Production + Preview) |
   | `RAILS_DEFAULT_URL` | the public URL, e.g. `https://fixflow-eosin-kappa.vercel.app` |
   | `ADMIN_EMAIL`, `ADMIN_PASSWORD` | first staff admin, created at boot only if no admin exists (sensitive; remove after first sign-in) |
   | `MAIL_FROM`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | optional SMTP for verification/reset emails |

4. Deploy: `vercel deploy --prod` (or connect the GitHub repo with `vercel git connect` to deploy on every push).

On every cold start `bin/docker-entrypoint` runs `db:prepare` (through `DATABASE_URL_UNPOOLED`) and `fixflow:bootstrap_admin`. Expect a ~10 s first request after 5 idle minutes. `.vercelignore` keeps `master.key` and `.env*` out of uploads.
