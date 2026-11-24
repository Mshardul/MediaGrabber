# MediaGrabber — agent notes

macOS app. Two targets: `GrabberKit` (headless SPM-style framework, no SwiftUI) and `MediaGrabber` (thin SwiftUI app over it). Tuist-generated project.

`docs/state-flow.md` — the job / `RateState` / `ShieldStatus` state machines, every transition with a trigger + `file:line`. Read it before touching the engine's scheduler, `recordExit`, `RatePolicy`, or the deferral seams.

`tickets.md` — the work board; its rules (ids, columns, status moves, the predefined type / component / epic lists) are in `ticket-setup.md`, beside it. `roadmap.md` — a short overview of releases and epics, written from the tickets. `future-ideas.md` — distant ideas with no ticket yet. `audit/report/` — pending audit reports; finished ones move to `audit/report/archived/`.

Specs: `docs/superpowers/specs/` — parent design `2026-08-28-youtube-downloader-mac-design.md` (living), current phase spec alongside it. Built phases' specs + plans move to `specs/archived/` and `plans/archived/`. Shipped: Phase 1 `core-download-pipeline.md`, Phase 2 `queue-foundation.md` (not archived — kept in `specs/`), Phase 3 `2026-08-31-media-grabber-phase-3.md`, Phase 4 `2026-09-01-media-grabber-phase-4.md`, Phase 5 `2026-09-02-media-grabber-phase-5.md`, Phase 6 `2026-09-04-media-grabber-phase-6.md`, Phase 7 `2026-09-07-media-grabber-phase-7.md`, Phase 8 `2026-09-08-media-grabber-phase-8.md`, Phase 9 `2026-09-10-media-grabber-phase-9.md`, Phase 10 `2026-09-11-media-grabber-phase-10-share-extension.md`, Phase 11 — Diagnostics, About, updates + Home manager chrome _(shipped)_ (design lives in the parent spec §5/§12, no dedicated phase-spec doc; plan: `docs/superpowers/plans/archived/2026-09-12-media-grabber-phase-11.md`), Phase 12 — Downloads table chrome _(shipped)_ — design + plan in `docs/superpowers/{specs,plans}/archived/2026-09-22-media-grabber-downloads-table-chrome*.md`, Phase 13 — Polish _(shipped)_ — design + plan in `docs/superpowers/{specs,plans}/archived/2026-09-23-media-grabber-phase-13-polish*.md`, Phase 14 — Engine maturity _(shipped)_ — design + plan in `docs/superpowers/{specs,plans}/archived/2026-10-04-media-grabber-phase-14-engine-maturity*.md`. Phase 15 — Table & Home finish _(shipped)_ — design + plan in `docs/superpowers/{specs,plans}/archived/2026-10-04-media-grabber-phase-15-table-home-finish*`. Phase 16 — Cookie independence _(shipped)_ — spec `docs/superpowers/specs/archived/2026-11-03-cookie-independence.md`, plan: `docs/superpowers/plans/archived/2026-11-03-media-grabber-cookie-independence.md`. Phase 17 — Site / identity maturity _(shipped)_ — spec `docs/superpowers/specs/archived/2026-11-05-media-grabber-phase-17-site-identity-design.md`, plan at `docs/superpowers/plans/archived/2026-11-05-media-grabber-phase-17-site-identity.md`. Phase 18 — Site identity closeout _(shipped)_ — the seven review decisions on `roadmap.md`. Phase 19 — Branding and release gate _(shipped)_, spec `docs/superpowers/specs/2026-11-04-media-grabber-release-distribution-design.md`. The name stays MediaGrabber with the Aurora orb icon. Install location, uninstall, Sparkle, bundled tools, the user-facing README and the signed appcast are in. Phase 20 — Repo split _(shipped)_, spec `docs/superpowers/specs/2026-11-17-media-grabber-phase-20-repo-split-design.md`. MediaGrabber lives in its own repository with its history, tags `vX.Y.Z`, the update feed as the latest release's `appcast.xml`, and a fresh signing key. Phase 21 — Release hardening _(shipped)_, spec `docs/superpowers/specs/archived/2026-11-17-media-grabber-phase-21-release-hardening-design.md`, plan `docs/superpowers/plans/archived/2026-11-19-media-grabber-phase-21-release-hardening.md`. Phase 22 — Code cleanup _(shipped)_, spec `docs/superpowers/specs/archived/2026-11-20-media-grabber-phase-22-code-cleanup-design.md`, plan `docs/superpowers/plans/archived/2026-11-22-media-grabber-phase-22-code-cleanup.md`. One `AppLocations` knows where the app keeps its files, `MG_HOME` runs the signed app against a fake home, and `HomeAccessGuardTests` keeps it that way. Phases 23 to 27 were replaced by tickets: the review fixes, sign-in policy, UI fidelity, product page and test-suite work are rows in `tickets.md`, grouped by epic and by Release.

## Planning — tickets only

Phases 1 to 22 are history and stay closed. From here every item raised is a ticket in `tickets.md`, with an epic and, when it must ship in a given version, a Release. The rules are in `ticket-setup.md`.

1. **In scope → build it to final-app form.** No stubs to swap later, no "minimum that passes this ticket," no shape a later ticket must replace. If the confirmation dialog is in scope, it gets its real skinned UI + design-system entry now.
2. **Deferred → a ticket, never orphaned.** Don't silently drop an item and don't leave a floating "follow-ups" list. A review note, a chat, or a ledger line is not a home. The turn that defers an item writes its row before the turn ends, and a decision lives in a row or in the spec its epic links to. Product-level **never** belongs in parent §13.
3. **Finished work is closed.** No blame, no rework to match a later rule, no framing current work as fixing past mistakes. If current work must touch completed code, do it as a plain change in the current ticket. Present and future only.
4. **A release is a Release value.** It is ready when every row with that version is `completed` or `dropped`. `roadmap.md` is the short overview and never holds a decision the table does not.

## Design decisions

- **User-facing copy is true, plain, and actionable.** Every error, warning, and hint must be correct for the cause that actually fired it — never the most common guess — and must not mislead even slightly. Users are not technical: no commands, tool names, or jargon in the UI. Say what is wrong, and where a fix exists give one clear action (button or link), reachable later and not only in a one-time flow. Never surface raw tool/terminal output (installer logs, stderr): map stages to plain messages and keep the raw text behind a collapsed "Details" for support. A cause-specific message needs a test pinning cause → copy.

- **Every code change is made for the app's end state, not the current ticket.** The target is the app as envisioned when finished (all features: multi-concurrent scheduler, per-host rate limiting, circuit breaker, adaptive concurrency, playlist queues of thousands, retry/backoff, cookies, POT rotation, diagnostics). Pick the structure that serves that. Do NOT build the minimum that passes this ticket and plan to replace it later — rewriting/ removing working code is wasted effort and is treated as a failure of the design pass, not normal iteration. Shell-and-fill (build the full structure now, a later ticket adds cases/wiring without relayout) is the pattern; rip- and-replace is not.
- Decide architecture on what the app / subsystem should be at its end state. The tickets and `roadmap.md` are an output — they get rewritten to match a decision, not treated as fixed scope. Never argue a design choice from "a later ticket needs it"; argue from the app-level need, pick the fit, then update the tickets and say so.
- When weighing an option, walk the concrete future features that would stress it (playlists → thousand-row queues, higher concurrency cap, larger history) and check the option holds. "Sub-millisecond at current scale" is not the test; "still the right shape when the headline feature lands" is.
- Brainstorming forks: plain-chat prose — the fork, the real tradeoff, a recommendation. Not the AskUserQuestion box. One position at a time; revise on merit, don't pitch-then-collapse.

## Build & test

- **Use `make` only — never run `xcodebuild` directly.** A direct run writes a second `MediaGrabber.app` into `~/Library/Developer/Xcode/DerivedData`, and macOS then lists two apps. At most one copy may exist on the machine. `make` (build + relaunch), `make test` (`ONLY=Target/Suite` to narrow), `make lint`.
- `mise exec -- tuist generate --no-open` after adding/removing files.
- Test: `make test`. Single suite: `make test ONLY=GrabberKitTests/<SuiteName>` (or `AppUnitTests/<SuiteName>`).
- Do NOT use `tuist test` when debugging — its output filtering hides compiler errors. `tuist test` is fine in CI where a pass/fail is all that matters.
- Lint: `make lint` (swiftformat + swiftlint --strict).
- The `MediaGrabber` scheme only exists because `AppUnitTests` depends on it; the workspace-wide scheme is `MediaGrabber-Workspace`.
- `MediaGrabber-Workspace` is defined explicitly in `Project.swift` (not auto-generated) so it can carry code coverage for `GrabberKit` + `MediaGrabber`.

## Release

- Versions are manual SemVer, pre-1.0. `make release-patch` / `release-minor` / `release-major` computes the next version from the latest `vN.N.N` tag, runs the dry run via `gh workflow run release.yml`, prints `docs/release-checklist.md`, requires a literal `yes`, then confirms, tags and pushes. Bare `make release` errors. `make release-dry-run VERSION=X.Y.Z` builds and signs without publishing. `make release-overwrite VERSION=X.Y.Z` replaces an already published release after a confirmation. `make site-deploy` redeploys the product page. `make e2e` builds Release, signs, and runs `scripts/e2e/run.sh` end-to-end.
- Release scripts live in `scripts/release/` (`derive-version`, `verify-app`, `package-dmg`, `verify-dmg`, `sign-update`, `check-signature`, `publish-release`, `check-feed`, `release-assets`) plus `scripts/e2e/run.sh`; `release-notes/X.Y.Z.md` is required before a version is accepted; `docs/release-checklist.md` is the pre-release checklist.
- The **tag** is `vX.Y.Z`; every derived string (`MARKETING_VERSION`, DMG name, `bump-version.sh` I/O) is the bare `X.Y.Z`.
- The build reads the version from `TUIST_MG_VERSION` (unset → `0.0.0`); the release workflow exports it before `tuist generate`.
- A tag push runs `.github/workflows/release.yml`: each step calls a script in `scripts/release/` — `derive-version`, main-ancestor check, `fetch-tools`, build, `sign-app`, `verify-app`, `scripts/e2e/run.sh` with `MG_E2E_LAUNCH=1`, `package-dmg`, `verify-dmg`, `sign-update`, `check-signature`, then `publish-release` (which ends with `check-feed`). The update feed is the latest release's `appcast.xml` at `https://github.com/Mshardul/MediaGrabber/releases/latest/download/appcast.xml`. `.github/workflows/ci.yml` runs lint and tests; `.github/workflows/pages.yml` deploys `site/`, the product page, and nothing else. The public EdDSA key is the repo variable `MG_SPARKLE_PUBLIC_KEY` (`TUIST_SPARKLE_PUBLIC_KEY` at generate time). The private key is the secret `SPARKLE_EDDSA_PRIVATE_KEY` and is never committed. Generate the pair once with Sparkle's `generate_keys`; a publish without the secret fails, a dry run skips signing.
- To test the release path without publishing: `make release-dry-run VERSION=X.Y.Z`, or Actions tab → release → Run workflow → set `version`, tick `dry_run`.
- Xcode is pinned in `.xcode-version` (single source of truth): the test and release jobs read it into a step output for `setup-xcode`, and `xcodes` reads it locally. Lint stays on Ubuntu (`swiftformat` / `swiftlint` only) so it does not wait on a macOS runner. A bump edits that one file. A weekly scheduled CI run tests against Xcode `latest` so a retired pin surfaces out of band.
- Notarization, real Developer ID signing, and hardened runtime are not wired — the release workflow's sign step marks where they slot in.
- `scripts/create-dmg` is vendored (andreyvit) at a pinned SHA with one local patch (support-dir path); see `scripts/support/PROVENANCE`.

## Toolchain

- `mise` pins tuist / swiftformat / swiftlint to exact versions in `.mise.toml`. Don't run `mise use <tool>@latest` — it rewrites the pin.
- Xcode is pinned in `.xcode-version` (currently `26.3`, the newest on the macos-15 CI image). tuist 4.205.0's `ProjectDescription` is built for the Swift 6.2 SDK — Xcode < 26 fails `tuist generate` with a compiler/SDK mismatch. Any local Xcode 26.x works; `xcodes select "$(cat .xcode-version)"` to match CI exactly.
- `.swiftformat` has `--disable docComments`; `.swiftlint.yml` has `disabled_rules: [todo]`. Both exclude `Derived/`.

## Fonts

- Aurora uses Sora, IBM Plex Sans (Regular, Medium, SemiBold), and JetBrains Mono. Tape Deck uses Bricolage Grotesque (Regular, Bold, ExtraBold), DM Sans (Regular, Medium, Bold), and DM Mono (Regular, Medium). Inter stays vendored. All live under `Resources/Fonts/<Family>/` and are registered via `ATSApplicationFontsPath` in `Project.swift`'s `infoPlist`. Each family's OFL license is alongside its font file (`<Family>/<Family>-OFL.txt`) — filenames are family-prefixed because Tuist flattens `resources:` globs into one `Contents/Resources/` directory, so bare `OFL.txt` files would collide.
- `ATSApplicationFontsPath` is `"."` (the bundle's `Resources/` root), not a `Fonts` subdirectory — the same flattening means the font files land directly in `Resources/`, not `Resources/Fonts/`.
- `Resources/Tools` and `Resources/Shield` are `.folderReference`s, not globs: `ManagedTools` resolves `Tools/yt-dlp` and `Shield/server/build/main.js`, and the Shield server needs its tree intact.

## Code style

- Only `AppLocations` reads the real home or `MG_HOME`; components receive the narrow location they need (`HomeAccessGuardTests` enforces it).
- Comments: single-line only, only to explain _why_, only when the type/function names don't already carry it. No `///` doc comments. No stacked `//` blocks. If the "why" needs more than one line, restructure the code instead.
- `// MARK:` is fine (navigation, not a comment).

## Swift 6 / concurrency traps (hit these already — will recur)

- **`NSLock.lock()` / `.unlock()` are banned in async contexts.** `Synchronization.Mutex` needs macOS 15; deployment target is 14. Use the `os_unfair_lock`-backed `LockedBox` in `Tests/TestSupport/LockedBox.swift` (or an equivalent) for any shared mutable state touched from `async` code.
- **Actors are reentrant across `await`.** An actor method that suspends (awaiting a child process, a stream, the network) does NOT hold the actor between suspensions — a second call runs concurrently. To truly serialize, chain an internal `Task` (see `MetadataProbe.tail`). Actor isolation alone is not a queue.
- **`XCTestCase` is not `Sendable`.** A `Task { }` inside a test can't call an instance helper method. Build the value (`ProcessLaunch`, etc.) before the `Task` and capture only `Sendable` locals.
- **`DownloadJob` is `@MainActor @Observable`.** The engine hops `await MainActor.run { … }` for every job mutation. Tests that read `job.state` / `job.progress` must be `@MainActor` and poll until the job reaches a terminal state (`submit` returns instantly at `.queued`).

## Lint traps

- `swiftformat` and `swiftlint` disagree on where the opening `{` goes for a wrapped multi-line `if` condition. Fix: extract the condition into a named predicate function, don't inline a multi-line `||` / `,` condition.
- `swiftformat` promotes a `//` comment directly above a declaration to `///` unless `docComments` is disabled (it is — keep it that way).

## Process / child-process rules

- `ProcessRunner` is the ONLY place `Foundation.Process` is touched, with one exception: the relaunch waiter in `AppRelauncher`, a detached shell that must outlive the app and opens it again only after this process has exited. `DownloadEngine` is the ONLY component that spawns download processes.
- `ProcessRunner` drains each pipe on its own blocking-`read` thread + a 2-count latch to finish the stream. `readabilityHandler` + a `terminationHandler` drain was tried and dropped lines under concurrent tests — don't reintroduce it.
- Shell fixture scripts that must die on SIGTERM use `exec` (e.g. `exec sleep 60`) so the signal reaches the real process, not an orphaned child.

## Fixtures / network

- No network in tests. Real-network tests gated behind `MG_LIVE_TESTS=1`, off in CI.
- Capture fixtures from `commons.wikimedia.org` / `archive.org` (Creative Commons). **YouTube is bot-blocked without a POT provider** — out of Phase 1.
- Network-failure stderr on macOS says "Failed to resolve … nodename nor servname provided", not "getaddrinfo". `ProgressParser`'s signature list covers both — keep macOS phrasing in it.

## Known Phase 1 gaps (parked in later phases — not bugs)

- No queue / persistence / resume — a quit mid-download loses the job. _(closed by Phase 2.)_
- Onboarding's `testRun` canary was auto-pass. _(closed by Phase 11 — real `CanaryProbe` run, shared with Diagnostics' Run check.)_

## Python

- If you need Python for a bulk text edit or script, use the repo venv: `.venv/bin/python`, created once by `make venv`. Never system `python3`.
