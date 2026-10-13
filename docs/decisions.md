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

## Known limitations
- No production deployment or SMTP configuration; email works locally through letter_opener only.
- No file attachments, notifications, SLAs or optimistic locking on edit forms (concurrent edits are last-write-wins; workflow moves are row-locked).
- UI is Plutonium's responsive, accessible default; it was verified through rendered HTML and HTTP checks, not in a browser.
- phlex-rails prints `helpers` deprecation warnings from inside the gem during tests; not from app code.
