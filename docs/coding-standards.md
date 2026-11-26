# Coding standards

Use this when writing code and when reviewing it. The must-follow rules are in [AGENTS.md](../AGENTS.md); this page adds the detail and does not repeat them. Tool settings (`.swiftformat`, `.swiftlint.yml`, `.editorconfig`, `pyproject.toml`) are the source of truth for style.

## Design

- **Every code change is made for the app's end state, not the current ticket.** The target is the app as envisioned when finished (all features: multi-concurrent scheduler, per-host rate limiting, circuit breaker, adaptive concurrency, playlist queues of thousands, retry/backoff, cookies, POT rotation, diagnostics). Pick the structure that serves that. Do NOT build the minimum that passes this ticket and plan to replace it later — rewriting/ removing working code is wasted effort and is treated as a failure of the design pass, not normal iteration. Shell-and-fill (build the full structure now, a later ticket adds cases/wiring without relayout) is the pattern; rip- and-replace is not.
- Decide architecture on what the app / subsystem should be at its end state. The tickets and `roadmap.md` are an output — they get rewritten to match a decision, not treated as fixed scope. Never argue a design choice from "a later ticket needs it"; argue from the app-level need, pick the fit, then update the tickets and say so.
- Before writing a helper, look in `GrabberKit`, in the app's shared code such as `Sources/App/Controls` and `Sources/App/Theme`, and in `Tests/TestSupport`.
- Module boundaries: `GrabberKit` is headless and never imports SwiftUI; `MediaGrabber` is a thin SwiftUI app over it. The check script enforces the import rule.
- When weighing an option, walk the concrete future features that would stress it (playlists → thousand-row queues, higher concurrency cap, larger history) and check the option holds. "Sub-millisecond at current scale" is not the test; "still the right shape when the headline feature lands" is.

## Comments

- The rule covers tests and script headers too. Comment-only lines are never stacked, even with a blank line between them. If the why needs more than one line, restructure the code instead.
- `///` is allowed only on public `GrabberKit` declarations, one line each. A `/** … */` comment counts as `///`.
- `// MARK:` is fine (navigation, not a comment). Shebangs and the tool directives the check script lists are also allowed.
- The check cannot tell whether a comment explains why, whether a documented declaration is public, or whether a comment is commented-out code. Review these.

## References and dead code

- The check catches phase numbers and ticket ids in code comments. Spec-section references, and anything in UI copy, are left to review.
- The check commands do not find unused code, so search for remaining uses of whatever the change touched.

## Errors, suppressions and dependencies

- `try?`, `|| true` and `|| :` are allowed only where failure is clearly harmless.
- A Swift `catch` block is never empty; one that holds only comments is empty, and the check fails on it.
- The check run lists new suppressions, new risky constructs and setting changes. Listing them does not fail the run and is not approval: account for each one.
- An approved library or tool is pinned to an exact version, in one place.

## User-facing copy

- **User-facing copy is true, plain, and actionable.** Every error, warning, and hint must be correct for the cause that actually fired it — never the most common guess — and must not mislead even slightly. Users are not technical: no commands, tool names, or jargon in the UI. Say what is wrong, and where a fix exists give one clear action (button or link), reachable later and not only in a one-time flow. Never surface raw tool/terminal output (installer logs, stderr): map stages to plain messages and keep the raw text behind a collapsed "Details" for support. A cause-specific message needs a test pinning cause → copy.

## Tests

### When a test fails

1. Settle the intended behaviour from something other than the failing pair: the request or ticket, the spec, [state-flow.md](state-flow.md), or what the app tells the user. If these do not settle it, ask the user.
2. Reproduce the failure and find its cause. Run an intermittent test repeatedly; one pass proves nothing.
3. If the code differs from the intended behaviour, fix the code.
4. If the test asserts something the intended behaviour does not require, or depends on timing, order or the state of the machine, fix the test so it can still catch the fault it guards.
5. Say in the report which side was wrong and why.

### Writing and reviewing tests

- A test protects behaviour that a user would notice or that would break a release, and its name says what that is.
- It must be able to fail: breaking the behaviour it protects makes it fail. Do not replace the very thing under test with a fake.
- Assert the outcome, not how the code reaches it.
- Wait for the state you need, with a time limit. A fixed sleep is not a way to wait.
- When reviewing a changed test, check that it still catches everything it caught before, or that the report says what it no longer catches and why.
- **Forced unwraps:** for a value that comes from the code under test, a fixture or the system, use `try XCTUnwrap(…)`, so a missing value fails that one test with its location instead of crashing the test run. A `!` is fine where only an error in the test's own constant could make it fail, such as `URL(string:)` on a literal. SwiftFormat is set not to rewrite forced unwraps in tests.

### Fixtures and network

- No network in tests. Real-network tests gated behind `MG_LIVE_TESTS=1`, off in CI.
- Capture fixtures from `commons.wikimedia.org` / `archive.org` (Creative Commons). **YouTube is bot-blocked without a POT provider.**
- Network-failure stderr on macOS says "Failed to resolve … nodename nor servname provided", not "getaddrinfo". `ProgressParser`'s signature list covers both — keep macOS phrasing in it.

## Review checklist

- Is this the simplest design that still holds in the finished app?
- Was there an existing helper to reuse? Is each type in the right file, feature and module?
- Is every error handled, passed up or logged?
- Is each comment needed, one line, and about why? No phase, ticket or spec-section reference in comments or UI copy?
- Is each user-facing message true for its cause, with a test for a cause-specific one?
- Is anything now unused, or commented out?
- Do changed tests still protect the intended behaviour?
- Is every new suppression, setting change or dependency approved by the user?
- Do the traps below apply to the change?

## Swift

- Only `AppLocations` reads the real home or `MG_HOME`; components receive the narrow location they need (`HomeAccessGuardTests` enforces it).

### Concurrency traps (hit these already — will recur)

- **`NSLock.lock()` / `.unlock()` are banned in async contexts.** `Synchronization.Mutex` needs macOS 15; deployment target is 14. Use the `os_unfair_lock`-backed `LockedBox` in `Tests/TestSupport/LockedBox.swift` (or an equivalent) for any shared mutable state touched from `async` code.
- **Actors are reentrant across `await`.** An actor method that suspends (awaiting a child process, a stream, the network) does NOT hold the actor between suspensions — a second call runs concurrently. To truly serialize, chain an internal `Task` (see `MetadataProbe.tail`). Actor isolation alone is not a queue.
- **`XCTestCase` is not `Sendable`.** A `Task { }` inside a test can't call an instance helper method. Build the value (`ProcessLaunch`, etc.) before the `Task` and capture only `Sendable` locals.
- **`DownloadJob` is a plain class that only `DownloadEngine`-isolated code may touch** (`@unchecked Sendable` by convention). The UI binds to `JobSnapshot`. `submit` returns as soon as the job is queued, so a test waits for the state it needs (see `EventCollector.waitForState`) instead of reading it straight away.

### Lint traps

- `swiftformat` and `swiftlint` disagree on where the opening `{` goes for a wrapped multi-line `if` condition, so SwiftLint's `opening_brace` is off. Prefer extracting a multi-line `||` / `,` condition into a named predicate function over inlining it.
- `swiftformat` promotes a `//` comment directly above a declaration to `///` unless `docComments` is disabled (it is — keep it that way).
- `.swiftformat` has `--disable docComments` and `--disable noForceUnwrapInTests`; `.swiftlint.yml` has `disabled_rules: [todo, opening_brace]`. Both exclude `Derived/`.

### Process / child-process rules

- `ProcessRunner` is the ONLY place `Foundation.Process` is touched, with one exception: the relaunch waiter in `AppRelauncher`, a detached shell that must outlive the app and opens it again only after this process has exited. `DownloadEngine` is the ONLY component that spawns download processes.
- `ProcessRunner` drains each pipe on its own blocking-`read` thread + a 2-count latch to finish the stream. `readabilityHandler` + a `terminationHandler` drain was tried and dropped lines under concurrent tests — don't reintroduce it.

## Shell

- Shell fixture scripts that must die on SIGTERM use `exec` (e.g. `exec sleep 60`) so the signal reaches the real process, not an orphaned child.
- Script tests must not touch `/Applications`, real processes, Launch Services, git, `gh` or the network. They run in temporary directories, with the destinations and external commands a script uses replaced.

## Python

- If you need Python for a bulk text edit or script, use the repo venv: `.venv/bin/python`, created once by `make venv`. Never system `python3`.
