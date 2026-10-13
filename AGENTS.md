# AGENTS.md — working on FixFlow

Instructions for AI agents and contributors. Read before changing code.

## Stack
- Ruby 3.4.11 (via mise), Rails 8.1.4, Plutonium 0.67.0, SQLite, Rodauth (rodauth-rails), Phlex, Tailwind 4, esbuild.
- Run commands through `mise x -- <cmd>` unless mise is activated in the shell.
- Before finishing any change: `bin/ci` must pass (Standard, bundler-audit, yarn audit, Brakeman, tests, seeds).

## Plutonium conventions (verified against the 0.67 docs and gem source)
- **Generate, then edit.** Use `pu:*` generators for resources (`pu:res:scaffold … --dest=main_app`), portal wiring (`pu:res:conn X --dest=staff_portal --policy [--definition]`), dashboards (`pu:dashboard`) and tests (`pu:test:scaffold X --portals requester staff` — portals are **space**-separated). Always pass `--dest`, and `--auth` for portals, so generators don't prompt.
- **Layers:** model = data + domain rules; definition = *how* fields render; policy = *whether* they appear and who may act; interaction = the button; controller = hooks only.
- **Policies deny by default** (`app/policies/resource_policy.rb`). Base resource policies grant nothing; each portal subclass (`packages/<portal>/app/policies/<portal>/…`) grants access. Never authorize with a definition `condition:` — it only hides UI.
- On collection routes `record` is the **class**: guard instance checks (`record.is_a?(Class) || …`) and keep `permitted_attributes_for_index` record-independent.
- Custom `relation_scope` must start from `default_relation_scope(relation)`.
- Domain operations belong on the model (`ServiceRequest#transition_to!`, `#assign_to!`); interactions only present them and translate errors.
- Set server-owned attributes in the portal controller's `resource_params` (`super.merge(...)`), never via permitted attributes.
- A `permitted_associations` entry requires the child resource to be registered in *that* portal's routes.

## FixFlow rules (don't break these)
- Workflow lives in `ServiceRequest::TRANSITIONS`; policy predicates must mirror it (`test/policies/staff_portal_policies_test.rb` asserts this).
- `status`, `requester`, `assignee` are never mass-assignable.
- Comments and activities are immutable (`readonly?`). Internal notes/activities must never reach the requester portal (scopes + policy + DB check).
- Activity entries are written by model callbacks using `actor` → `Current.actor` (set by each portal's controller concern).
- Name the domain model `ServiceRequest`, never `Request` (collides with `ActionDispatch` / controller `request`, and with `@request` in integration tests).
- Demo password `password123` is for dev/test seeds only; seeds refuse to run in production.

## Testing
- Minitest + `Plutonium::Testing`. Factories are in `test/support/factory_helpers.rb` (`create_requester!`, `create_staff!`, `create_request!(status:)`), which walk the real workflow.
- `test/support/plutonium_testing.rb` overrides `sign_in_for_tests` because portal names ≠ account tables. Switch users in integration tests with `reset!`, not `sign_out` (its path is derived from the portal name and is wrong here).
- Add a test for every new rule: model (any save path), policy (portal × role × status), and an HTTP test for attacks/forged params.

## Known gem-version caveats (0.67.0)
- `pu:rodauth:account --extra-attributes` raises `NameError`; add columns with a normal migration.
- Dashboard `link`/`filter` macros in the online docs are not in 0.67.0; use `card`.
- The synced skills in `.claude/skills/` may describe features newer than the installed gem — check the gem source (`bundle show plutonium`) when in doubt.

## References
- Plutonium: https://radioactive-labs.github.io/plutonium-core/ · AI guide: https://radioactive-labs.github.io/plutonium-core/ai · Skills: `.claude/skills/` (refresh with `bin/rails g pu:skills:sync`)
- Rails Guides: https://guides.rubyonrails.org/ · API: https://api.rubyonrails.org/
- Rodauth: https://rodauth.jeremyevans.net/ · rodauth-rails: https://github.com/janko/rodauth-rails
- ActionPolicy: https://actionpolicy.evilmartians.io/ · Brakeman: https://brakemanscanner.org/docs/ · Standard: https://github.com/standardrb/standard
