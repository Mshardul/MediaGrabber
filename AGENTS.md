# MediaGrabber — rules for AI agents

Read [docs/coding-standards.md](docs/coding-standards.md) before writing code and when reviewing it. It holds the detail behind these rules.

## Must follow

- **Design patterns:** think about which pattern fits, judging from the requirements, task or ticket, so that a fitting one such as a singleton comes naturally. This is guidance, with no list or approval step.
- **KISS:** choose the simplest design that serves the finished app. A real requirement or ticket justifies each layer or abstraction.
- **DRY:** search for an existing helper before writing one, and reuse it or move it to a shared place.
- **Code placement:** one main type per file, group by feature, keep logic out of views, and respect module boundaries. Split by responsibility, never only to get under a linter limit.
- **Comments:** in every language, one line at most, only when necessary, and only to explain why.
- **References:** no phases, tickets or spec sections in code comments or UI copy.
- **Errors:** never fail silently. Handle, pass up or log every error.
- **Concurrency:** follow the written traps, including no `NSLock` locking in async code.
- **Dead code:** a change removes whatever it makes unused, including commented-out code.
- **Tests:** never change a test just to make it pass. The code and the test must both do what they are meant to do: settle the intended behaviour, then fix whichever side is wrong. Longer timeouts, retries, skips, added delays or weaker checks that only hide a fault are not fixes.
- **Dependencies:** ask the user before adding a library or tool, and give the long-term case.
- **Suppressions and check settings:** ask the user before adding a suppression or changing a lint or format setting or the check script.
- **Git:** run no git commands unless the user asks. `make fix`, `make check`, `make fix-all` and `make check-all` may be run, although their script reads file lists and diffs from git.
- **Planning:** read [docs/planning.md](docs/planning.md) before planning, designing, deferring or closing work.

## Definition of done

1. `make fix` passes.
2. `make test` passes, run after `make fix`. It may be skipped only when every changed file is a document that no test reads. `PRIVACY.md` is read by a test.
3. You have reviewed your changes against [docs/coding-standards.md](docs/coding-standards.md).
4. Your report states every failure and every skipped step, including a check run that had nothing to verify.

## Commands

**Use `make` only — never run `xcodebuild` directly.** A direct run writes a second `MediaGrabber.app` into `~/Library/Developer/Xcode/DerivedData`, and macOS then lists two apps. At most one copy may exist on the machine.

| Command | Does |
| --- | --- |
| `make` | Builds, replaces the app in `/Applications` and relaunches it |
| `make test` | Plugin tests, script tests, then unit tests; `ONLY=Target/Suite` narrows the unit tests |
| `make fix` / `make check` | Checks the changed files; `fix` edits them, `check` does not |
| `make fix-all` / `make check-all` | The same over the whole repository |

Setup, other targets and toolchain traps are in [docs/development.md](docs/development.md).

## Project documents

- [docs/development.md](docs/development.md): project overview, document map, setup, build, test, toolchain, fonts and release.
- [docs/architecture.md](docs/architecture.md): how the pieces fit.
- [docs/state-flow.md](docs/state-flow.md): the job, `RateState` and `ShieldStatus` state machines, every transition with a trigger and `file:line`. Read it before touching the engine's scheduler, `recordExit`, `RatePolicy` or the deferral seams.
- [docs/design-system.md](docs/design-system.md): visual design; it wins over the mockups.
- [docs/job-status-and-actions.md](docs/job-status-and-actions.md): the intended job status, filters and row actions.
- [docs/copy-audit.md](docs/copy-audit.md): checked user-facing sentences.
- [docs/release-checklist.md](docs/release-checklist.md): checks before a release.
- [PRIVACY.md](PRIVACY.md): what the app saves and sends.
- [docs/project-history.md](docs/project-history.md): what shipped earlier, with its specs and plans.
