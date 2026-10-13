# Implementation decisions

Dated 2026-10-13. Each entry: decision → why. Deviations from the official Plutonium docs are marked **Deviation**.

## Platform
1. **Bootstrapped with the official new-app template** (`rails new … -m templates/plutonium.rb`). The template's own commits are kept; later work is left for review.
2. **SQLite everywhere, no Docker services.** Nothing in the domain needs another database; one-command setup.
3. **Ruby 3.4.11 via mise** (Plutonium 0.67 needs Ruby ≥ 3.3; the machine only had system Ruby 2.6).
4. **Minitest, not RSpec.** Plutonium's testing toolkit (`Plutonium::Testing`, `pu:test:*`) is Minitest.

## Auth & portals
5. **Two Rodauth account types**: `User` (requesters, public sign-up + verification) and `StaffMember` (no `create_account`/`verify_account`; created by admins and seeded `verified`). Separate auth surfaces and session isolation came from the generators.
6. **Two portals** (`requester_portal` at `/requester`, `staff_portal` at `/staff`) over shared main-app resources; per-portal policies hold the rules.
7. **Staff roles** as an enum on `StaffMember` (`admin: 0, agent: 1`; index 0 most privileged per Plutonium convention). Deactivation instead of deletion keeps history attributable; it is checked at Rodauth login and on every staff-portal request.
8. **Base `ResourcePolicy` denies by default** (the generated one allowed `create?`/`read?` for everyone). Safer failure mode for any resource someone forgets to lock down.

## Domain
9. **Model named `ServiceRequest`**, not `Request` — avoids collisions with `ActionDispatch::Request`, controller `#request`, and integration tests' `@request`.
10. **Reference (`FF-00042`) is derived from the id**, not stored — cannot drift or collide.
11. **Workflow as a transition table + validation**, not a state-machine gem. `transition_to!` locks the row (`with_lock`); a validation re-checks any status change on *every* save path, so plain `update(status:)` cannot bypass it. Failed transitions discard their unsaved changes.
12. **Priority/status as integer enums** so priority sorts by severity; DB `CHECK` constraints mirror the enum ranges.
13. **Comment/Activity authors as two nullable FKs (`user_id`, `staff_member_id`) + `CHECK` constraints** instead of a polymorphic association — Plutonium's docs do not cover polymorphic `belongs_to`, and FKs give real referential integrity.
14. **Activity log via model callbacks + `Current.actor`** so edits through generated CRUD forms are captured too; workflow methods pass the actor explicitly. `activities.internal` mirrors internal comments so staff-only events are filtered out for requesters with a plain SQL scope.
15. **Staff cannot create requests**; requests always originate from a requester account (keeps ownership unambiguous).
16. **Reopen requires a reason**, posted as a comment, atomically with the transition.

## Deviations / workarounds
17. **Deviation:** `pu:rodauth:account --extra-attributes` crashes in 0.67.0 (`uninitialized constant PlutoniumGenerators::ModelGeneratorBase`). Added `name`, `role`, `active` and timestamps with a separate migration (`AddProfileFieldsToAccounts`). Timestamps have DB defaults because Rodauth inserts via Sequel.
18. **Deviation:** the dashboard `link` macro documented online is absent in 0.67.0; the requester dashboard uses a `card` with a link instead.
19. **Deviation:** `Plutonium::Testing`'s default login/logout paths are derived from the portal name (`/requesters/login`). Overrode the documented `sign_in_for_tests` hook; tests switch users with `reset!` because `sign_out` has no hook.
20. **Deviation:** `Plutonium::Testing::ResourcePolicy` tests the base policy class by default; our tests override `policy_class_for` to test the portal policies where the rules live.
21. Generated dashboard placeholder controllers/views were removed after mounting dashboards at the portal root (as the dashboard skill instructs).

## Tooling
22. **Standard** (installed by the template) replaces rubocop-rails-omakase: `bin/rubocop` removed, `bin/ci` and GitHub Actions call `standardrb`. Rails-generated `db/*_schema.rb` dumps are excluded from linting.
23. **npm audit fixes:** removed the unused `@tailwindcss/cli` (CSS is built by PostCSS; the CLI pinned a vulnerable `braces`), and pinned `postcss-selector-parser` to `^7.1.6` via `resolutions` (`@tailwindcss/typography` pins a vulnerable 6.0.10). The built CSS was verified byte-identical before/after.
24. GitHub Actions: added Node/Yarn to the test job (`test:prepare` builds assets) and removed the empty system-test job. The workflow has not been run on GitHub yet.

## Security follow-ups
25. **Requester-portal `UserPolicy` / `StaffMemberPolicy` with an empty `relation_scope`.** Plutonium's typeahead endpoint (`/<resource>/typeahead/input/:name`) accepts any association on the resource and scopes the target through the portal's policy for that class; with no requester-portal policy it fell back to the base policy's unscoped default and listed every account. Written by hand rather than with `pu:res:conn`, which would also register the resources as requester routes.
26. **Account emails are normalized to lowercase and validated unique** (among open accounts, mirroring the partial unique index). Rodauth's `case_insensitive_login` downcases submitted logins and assumes stored ones are lowercase, so admin-typed mixed-case staff emails could never sign in; duplicates previously surfaced as a 500. `DowncaseAccountEmails` migrates existing rows and refuses to run if two open accounts differ only by case.
27. **"Remember me" autologin wired to the real portals.** The generator's `load_memory` calls targeted placeholder paths (`/staff_member_dashboard`, `/user_dashboard`), so the cookie was set but never used. `RodauthApp` now autologins on `/staff` and `/requester` only. Autologin skips `before_login`, so a `before_load_memory` hook refuses deactivated staff and deletes their remember key. `session_isolation` keeps the two portals' remembered logins from evicting each other (covered by `test/integration/remember_me_test.rb`).
28. **Brute-force protection: Rodauth `lockout` plus Rails `rate_limit`.** Lockout (10 failures, 1-hour deadline, unlock by email) stops guessing one account's password; it is per account, so `RodauthController` also rate limits per IP: 20 login POSTs/minute and 5/10 minutes for routes that send email. rodauth-rails runs controller callbacks with `action_name` set to the Rodauth route, so Rails 8's built-in `rate_limit` works without Rack::Attack. Staff set `unlock_account_autologin? false`, because unlock autologin would skip the deactivated-staff `before_login` check. Counters live in `Rails.cache`. Production currently uses a per-instance `:memory_store` (Vercel, see `config/environments/production.rb`), so each instance counts separately and resets on cold start; the per-IP limit is only as strong as the instance count is low. A shared cache store would make it exact. Lockout is unaffected, since it is stored in the database.

## Deployment (Vercel)
28. **Vercel Container Runtime + Neon Postgres** (user's choice of host). Containers are stateless, so SQLite files cannot persist and hosted SQLite (libSQL) adapters are too immature (and Rodauth's Sequel bridge has no libSQL support). Development and tests stay on SQLite; the full suite also passes on Postgres 17.
29. **No worker process on Vercel:** production uses `:inline` jobs, `:memory_store` cache and the `async` cable adapter. `cache.yml` must not reference a `cache` database because Solid Cache's model is still eager-loaded.
30. **Migrations at boot** via `bin/docker-entrypoint` over `DATABASE_URL_UNPOOLED` (advisory locks don't work through Neon's transaction pooler); runtime uses the pooled URL with `prepared_statements: false`. Seeds skip production instead of aborting, because `db:prepare` seeds a freshly created database.
31. **First admin via `fixflow:bootstrap_admin`** from `ADMIN_EMAIL`/`ADMIN_PASSWORD` at boot, because Vercel offers no shell and does not expose secret env values to the CLI. It only creates an admin while none exists.
32. `Dockerfile.vercel` runs Puma on `$PORT` (8080) as the non-root user instead of Thruster on port 80.

## Known limitations
- No SMTP configured on the live deployment yet, so verification/reset emails are not sent (requesters can still sign in during Rodauth's verification grace period). Locally, email opens via letter_opener.
- Vercel: Container Runtime is beta; cold starts take ~10 s; the deployment-protected `*-obogyah.vercel.app` aliases require a Vercel login, the public URL is `fixflow-eosin-kappa.vercel.app`.
- No file attachments, notifications, SLAs or optimistic locking on edit forms (concurrent edits are last-write-wins; workflow moves are row-locked).
- UI is Plutonium's responsive, accessible default; it was verified through rendered HTML and HTTP checks, not in a browser.
- phlex-rails prints `helpers` deprecation warnings from inside the gem during tests; not from app code.
