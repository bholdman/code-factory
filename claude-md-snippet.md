## Commands the factory runs

<!-- /factory:setup fills these in after running each one. Factory agents run exactly these. -->
- Install: `...`
- Seed or test data: `...`
- Unit tests: `...` (full suite ~N min; single file: `...`)
- Lint and type check: `...`
- Pre-commit checks: `...`
- Start the app for browser checks: `...` (URL: http://localhost:3000)
- Test login for browser checks: `...` (a test account, never a real one)
- Services: `...` (what must be running, and how to start it in a cloud session)
- Known failures before any change: None

## Factory settings

<!-- All optional. Delete any line to use the default. -->
- Factory base branch: main
- Factory branch: factory/{number}-{slug}
- Factory plan dir: plans
- Factory plan file: {number}-{slug}.md
- Factory reviewers: @teammate-github-handle
- MAX_INLINE: 15
- APP_GLOBS: `app/ lib/`
- TEST_GLOBS: `spec/`
- MIGRATION_GLOBS: `db/migrate/`
- FRONTEND_GLOBS: `app/views/ app/javascript/ app/components/`
