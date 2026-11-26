# Guardrails for AI agents writing code

## Intent

Several different AI agents write code in this repository. They need one shared set of rules that keeps the code clean and consistent over the life of the app. Written rules alone do not hold reliably, so mechanical rules are checked by tools and judgement rules stay written. Scripts do the mechanical work so agents spend few tokens on it.

## Goals

- Every agent reads the same rules from `AGENTS.md`.
- Mechanical rules are enforced on changed files while working and at commit, and on the whole repository in CI.
- A green CI check run means the whole repository passes the checks.
- `fix` commands edit files and `check` commands never do.
- Check, build and test output is short, with the full log on disk.
- The Makefile is a thin, self-describing list of commands.

## Non-goals

- Agent-specific gates, hooks or pointer files.
- A check of compiler warnings anywhere. They are reviewed by hand later, on the ticket board.
- A requirement to write new tests as part of these guardrails.
- A design-pattern list or approval step, a code map, a copy-paste detector, or custom size and complexity limits.

## Anti-goals

The work has failed if rules drift between the Makefile, `pre-commit` and CI, if agents must read long tool output to find one error, if short output hides a real failure or shows a false pass, or if a check can be silenced without anyone seeing it.

## Constraints

- Tool versions are pinned in one place each.
- `make` is the only way to build and test locally, and at most one `MediaGrabber.app` exists on the machine. The release workflow's direct `xcodebuild` call on its CI runner is an accepted exception.
- Everyday checks stay fast: `pre-commit` runs no build and no tests.
- Short build output always keeps compiler errors visible.
- Existing project rules stay in force unless this design states a new one, including the test that pins each cause-specific user message to its cause.

## Approaches

| Approach | Gain | Cost |
| --- | --- | --- |
| Own check script, called by `make`, `pre-commit` and CI | One place defines the checks, with full control of output | File selection and tool routing are ours to maintain |
| `pre-commit` as the runner | File routing by language is built in | Less control of output, and Swift tools need local hooks to reuse the `mise` pins |

Configuring `make`, `pre-commit` and CI separately was ruled out because their rules would drift apart. The chosen approach is the own check script: short output is a core requirement, and owning the runner keeps output and rules consistent as checks are added.

For CI, checking the whole repository was chosen over checking changed files. Comparing a push with the previous one can skip a bad file after a failed or cancelled run. Comparing against the last successful run or a fixed rollout commit would need extra state and history handling.

## Written rules

### Where they live

- `AGENTS.md` is short and holds the must-follow rules. It points to `docs/coding-standards.md` and says to read it before writing code and when reviewing it. The check script enforces a character limit on `AGENTS.md`.
- `docs/coding-standards.md` holds the detail, used both when writing and when reviewing code. It is kept short, without a numeric limit.
- `docs/planning.md` holds the planning, ticket and design-choice rules, because they are not coding standards. `AGENTS.md` links to it and says when to read it.
- `CLAUDE.md` imports `AGENTS.md` and keeps only what is specific to Claude.
- Project facts that any agent needs, such as release, toolchain and font notes, live in documents under `docs/` that `AGENTS.md` links to, so every agent finds them while `AGENTS.md` stays short.
- Each shared rule is written once: rules in `CLAUDE.md` that apply to any agent move to `AGENTS.md`, the coding standards or the planning rules.
- The shipped-phase history in `CLAUDE.md` moves to a document under `docs/`, with a short link left in its place.

### General rules

- **Design patterns:** the agent thinks about which pattern fits, judging from the requirements, task or ticket, so that a fitting one such as a singleton comes naturally. This is guidance, with no list or approval step.
- **KISS:** choose the simplest design that serves the finished app. A real requirement or ticket justifies each layer or abstraction.
- **DRY:** search for an existing helper before writing one, and reuse or move it to a shared place.
- **Code placement:** one main type per file, group by feature, keep logic out of views, and respect module boundaries. Split by responsibility, never only to get under a linter limit.
- **Comments:** one line at most, only when necessary, and only to explain why. This applies to every language, including tests and script headers. `///` is allowed only on public `GrabberKit` declarations, one line each. This is the whole comment rule, and the project docs are made to match it.
- **References:** code comments and UI copy carry no references to phases, tickets or spec sections.
- **Errors:** never fail silently. Handle, pass up or log every error. `try?` or `|| true` is allowed only where failure is clearly harmless.
- **Concurrency:** the known traps, including no `NSLock` locking in async code, stay written rules.
- **Dead code:** a change removes whatever it makes unused, including commented-out code.
- **Dependencies:** ask the user before adding a library or tool, and give the long-term case.
- **Suppressions and check settings:** ask the user before adding a suppression or changing a lint or format setting or the check script.
- **Tests:** never change a test just to make it pass. The code and the test must both do what they are meant to do: settle the intended behaviour, then fix whichever side is wrong. Longer timeouts, retries, skips, added delays or weaker checks that only hide a fault are not fixes. `AGENTS.md` states this as a must-follow rule, and the coding standards give the detail. Also give guidelines for writing and reviewing test code, including forced unwraps. These guardrails require no new tests; the cause-specific message test remains required. The script tests this design asks for apply to its own rollout.
- **Git:** run no git commands unless the user asks. `make fix`, `make check`, `make fix-all` and `make check-all` may be run, although their script reads file lists and diffs from git.

### Language rules

Swift, shell and Python each get a short section covering what tools cannot check, including known project traps. Style guidance is added only where tools and those points leave a gap. Tool settings are the source of truth for style.

### Definition of done

1. `make fix` passes.
2. `make test` passes, run after `make fix`. It may be skipped only when every changed file is a document that no test reads. `PRIVACY.md` is read by a test.
3. The agent has reviewed its changes against `docs/coding-standards.md`.
4. The report states every failure and every skipped step, including a check run that had nothing to verify.

## Checks

One script under `scripts/` holds one list of checks and serves every caller.

### What runs where

| Caller | Command | Files | Edits | Fails on |
| --- | --- | --- | --- | --- |
| Agent or user, while working | `make fix` | Changed | Yes | Whatever is left |
| Agent or user, to look only | `make check` | Changed | No | Everything, including auto-fixable issues |
| `pre-commit` | The script in staged mode | Staged | Yes, without staging | Leftovers, or any edit |
| CI | `make check-all` | All | No | Everything |
| User, periodically | `make check-all` | All | No | Everything |
| User, deliberately | `make fix-all` | All | Yes | Whatever is left |

- Changed files are those that differ from the last commit, plus new files that are not ignored.
- With no changed files, the command says "0 files checked, nothing verified".
- Locally and at commit, a changed file must pass as a whole, and only changed or staged files are checked or edited.
- When a lint or format setting, a pinned check tool or the check script is among those files, the run also prints one line asking for `make check-all`.
- `make check-all` replaces `make lint`, which is removed, and CI's separate Swift lint steps. The agent notes and the documents under `docs/` that name it are updated to match.
- A new rule or a tool upgrade must leave the whole repository passing, because CI checks all of it.

### Which files each tool gets

- Every tool gets an explicit list of files that exist and are not excluded, never a directory. This includes `check-all` and `fix-all`.
- Deleted files are dropped from the list, and a tool with an empty list is not run.
- Paths containing spaces work.
- Excluded files are named in one explicit list. It includes `scripts/create-dmg`, `scripts/support/`, and generated and fetched files.
- Excluded paths stay excluded when passed to a tool by name, using the tool's own option where it has one, such as SwiftLint's `--force-exclude`.
- Shell files are found by extension or by their first line, so extensionless scripts such as `scripts/tests/stubs/gh` are checked. Shell test fixtures are checked too.
- SwiftLint covers `Sources`, `Tests`, `Project.swift`, `Tuist.swift` and the Swift files under `scripts/`.
- Tests cover a deletion, a change to only excluded files, a run with no files of one language, and a bad file under `scripts/`.

### What each check does

| Check | Applies to | In a fix run | In a check run |
| --- | --- | --- | --- |
| SwiftFormat | Swift | Rewrites | Fails |
| shfmt | Shell | Rewrites | Fails |
| Ruff lint | Python | Applies safe fixes, fails on the rest | Fails |
| Ruff format | Python | Rewrites | Fails |
| SwiftLint strict | Swift | Fails, without `--fix` | Fails |
| ShellCheck, all severity levels | Shell | Fails | Fails |
| Comment check | Files with comments | Fails | Fails |
| Project rules | As listed below | Fails | Fails |
| `AGENTS.md` character limit | `AGENTS.md` | Fails | Fails |
| Suppression and settings report | See below | Lists | Lists |

A fix run applies linter fixes, then formatters, then verifies. After a successful fix run, a check run on the same files passes, and a script test shows it. Where SwiftFormat and SwiftLint disagree, such as on brace placement, the rule is turned off in one of them. SwiftFormat's `noForceUnwrapInTests` is turned off, so an automatic fix does not rewrite test code for it. Some other SwiftFormat rules rewrite code, so tests run after a fix run.

### Project rules

The check script runs these itself and does not use SwiftLint custom rules, because SwiftLint skips those when SourceKit is unavailable and can then report a pass.

- Under `Sources/`, `Process` is used only in `ProcessRunner` and `AppRelauncher`.
- `GrabberKit` does not import SwiftUI, including single-declaration imports from it.
- Code comments carry no phase or ticket references.
- Swift has no empty `catch` block. A block holding only comments is empty.

Every check has a bad example that it must fail on, on every system where that check runs. The plan also confirms that the SwiftLint rules in use are all enforced on the CI runner. SwiftLint can skip a rule that needs SourceKit and still report a pass, so each such rule has its own bad example, which must fail wherever checks run.

### Suppression and settings report

The report lists, from added lines and changed files:

- **New suppressions:** `swiftlint:disable`, `swiftformat:disable`, `# noqa`, `# ruff: noqa`, `# type: ignore`, `# fmt: off`, `# shellcheck disable` and `shellcheck source=/dev/null`, along with any other form a configured tool accepts for switching off a check or formatting.
- **New risky constructs:** `try?`, `|| true`, `|| :`, `@unchecked Sendable` and `nonisolated(unsafe)`.
- **Setting changes:** lint and format settings, including SwiftLint exclusions, `.editorconfig`, `pyproject.toml` and any Ruff or ShellCheck settings file; pinned tools, including `.python-version`; the check script and its exclusion list; `.pre-commit-config.yaml`; `ci.yml`; and check-related Makefile lines.

A moved line may be listed again. The report does not fail a run, and it is the one addition allowed to short check output. It is visible on a passing commit, so the hook shows its output even when it passes, and that output stays tiny. CI shows the report in the job summary, compared with the pull request or push base. The job fetches enough history for this. The comparison is for visibility only: when no usable base exists, the summary says so, and the pass or fail result is unaffected.

### Comment check

The check looks at comment-only lines and fails on:

- Stacked comment-only lines. A blank line between two of them does not break a stack.
- Multi-line block comments and multi-line Python docstrings.
- Multi-line `///`, and `///` outside `GrabberKit`. A `/** … */` comment follows the same rules as `///`. Outside `GrabberKit` both fail wherever they sit, including on a line that also holds code. Whether a documented declaration is public is left to review.

Comments at the end of a code line do not count towards a stack. It allows `// MARK:`, shebangs and a written list of tool directives. The only multi-line text it tracks and skips is Swift multi-line strings, including raw ones, and shell heredocs. Python uses the standard library's own parsing modules. YAML, TOML and the Makefile get the same line rule, including inside multi-line values, with no parsing of embedded languages. Whether a comment explains why, and commented-out code, are left to review.

It covers Swift, shell, Python, YAML, TOML and the Makefile.

### Pre-commit

- The hook fixes what the tools can in staged files and never stages the fixes. The commit stops if it edits anything or finds something it cannot fix, so the user can review and stage.
- `pre-commit` can roll back hook fixes that overlap unstaged changes. Whenever the hook edits files, its message says to run `make fix` if the fixes are rolled back.
- The hook runs the script as a single process, so copies do not run in parallel.
- It is tested with partly staged files, including the rollback case.
- Setup includes installing the hook, and the step is documented. The hook gives a clear error if `mise` or the venv is missing.

### Tool settings and setup

- shfmt indentation is four spaces, set in `.editorconfig`, and the script passes no format flags that would override it. The setting also covers extensionless shell scripts.
- ShellCheck runs with `--norc`, so no personal or repository settings file can silence a finding.
- ShellCheck, shfmt and Periphery are pinned through `mise`. Ruff is pinned in `requirements.txt` for the repository venv, and its pin in the `pre-commit` config is removed with its separate hooks.
- The script always runs the pinned copy of a tool. A missing tool or pin fails the run, with no fallback to another installed copy.
- Python is pinned to 3.15 in `.python-version`, matching Ruff's target. The pinned Ruff still marks 3.15 support as under development and warns about it; preview mode stays off. `make venv` and every CI job that runs the project's Python use it, so local runs and CI run the same version.
- The YAML and large-file hooks, and the Markdown hook and workflow, stay as they are.

### CI

CI does each piece of work once. A second run or an unused install costs time and adds no coverage.

- CI runs for pushes to `main`, for pull requests and on a weekly schedule. A branch with a pull request is checked once, through the pull request. A branch without one is not checked, and a tag push starts only the release workflow. The Markdown workflow takes pushes from `main` only, for the same reason.
- The check job runs `make check-all`. It fails on errors and fixes nothing. The report is compared with the pull request base, or with the previous tip of `main`. A scheduled run has neither, so its summary says there is no usable base.
- The check script's own tests, with their bad examples, run in the check job, because that is where CI runs `make check-all`.
- Every other script test runs through `make scripts-test` in the macOS test job, which excludes the check script's tests by name. The runner still finds tests by name, so there is one list. Its summary names what it excluded, and an excluded name that matches no test fails the run. Only CI excludes a test: `make scripts-test` and `make test` run all of them locally. The plugin tests run in the macOS test job.
- No test may skip itself and report success.
- Each job sets up the Python environment it needs.
- Each job names the `mise` tools it installs, and `.mise.toml` alone holds their versions. The check job installs SwiftFormat, SwiftLint, ShellCheck and shfmt. The test and release jobs install Tuist. Automatic installation is off in both workflows, because `mise exec` would otherwise install every pinned tool. A step or test that needs a tool its job did not install fails.
- The `mise` action's cache is the only cache of these tools. Its key covers the platform, the pin file and the tool list. The release workflow has its own key prefix, so nothing saved by a CI run reaches the shipped build.
- `tuist test` generates the project itself, so the test job has no separate generate step.
- Adding tools to `.mise.toml` must not break any job's tool install, including the release workflow's. A release dry run confirms this.

## Output

### Check commands

- Print only remaining errors, or a one-line pass, plus the report and the reminder line when they apply.
- Cap long output, group it by rule, and show how many were left out and where the log is.
- Always name the files they edited, including on a pass.
- Save the full log to an ignored file.
- Preserve a failing exit status.

### Build and test

`make build` and `make test`, and so plain `make`, print a short result and save the full log to an ignored file. CI test output stays as it is. The exit status of each underlying command is preserved. Short output must:

- Show a count of executed tests for each stage that should run (plugin, script and Xcode tests). A stage that executes none fails, even if tests were skipped.
- Take Xcode test counts and failures from a result bundle created by this run. Any earlier bundle is removed first, and a missing new one fails the run.
- Show compiler errors and failed tests. Compiler warnings stay in the full log.
- For any other failure, name the stage that failed and print the end of the log, with no special handling for each kind of failure.
- Stop a hung step after a defined timeout, ending its child processes and still removing the built app.
- Print one progress line per stage, so long steps such as the first tool fetch are visibly running.
- Remove repeated errors, and say how many were left out if the output is capped.

Package installs happen in `make venv`, not during `make test`.

## Makefile and scripts

- Each recipe calls a script or runs one simple command. All logic, existing and new, lives in `scripts/`, including release, app replacement, built-app cleanup, the end-to-end run and version checks.
- Logic moves without changing behaviour. Retries, ignored failures and variables such as `CONFIG`, `ONLY`, `VERSION`, `PY` and `DERIVED` carry over explicitly.
- Cleanup of the built app still happens after a failure or an interrupt.
- `make help` lists every command and its options. The list is built from a one-line description on each target, and a script test fails if a target has none.
- Plain `make` builds and relaunches the app.
- `make scripts-test` finds and runs every `test_*.sh`. `make test` and CI both use it, so there is one list.
- New and moved scripts have tests, including their failure and cancel paths.

### Safety of script tests

Script tests must not touch `/Applications`, real processes, Launch Services, git, `gh` or the network. They run in temporary directories, and the destinations and external commands a script uses can be replaced, including those called by full path. A risky command that a test has not replaced makes the test fail. For the release script, the fakes cover tagging and pushing.

## Dead code

`make dead-code` runs Periphery over the Swift code. It builds the app and tests into `build/`, runs Periphery on that index without letting it build, and removes the built app. It is run on demand and is not part of the check commands, `pre-commit` or the definition of done. The plan confirms that Periphery writes nothing that breaks the one-app constraint.

## Rollout

The order is: add the checks, clean up, then switch CI to `make check-all`. Moving the Makefile logic is a separate step. The whole-repository `fix-all` waits until other work in progress is settled, and the tests run after it.

The repository passes `make check-all` before CI switches, so a one-time cleanup is part of this work. Known findings:

- Swift files failing SwiftFormat and existing SwiftLint violations, plus further SwiftLint violations in the Swift files under `scripts/`.
- ShellCheck findings at note level in the project's own shell scripts.
- Stacked comment lines in Swift, shell and Python files, including script headers.
- Phase references in comments.

shfmt, Ruff and new-rule findings are counted once those checks exist, and shfmt is expected to reformat scripts that use two-space indents. Fixes that need a suppression or a setting change need the user's approval. Some of this work overlaps rows already on the ticket board, which the plan reconciles. After rollout, the user runs `make check-all` periodically.

## Left to the builder

Script language and layout, how changed and staged files and added lines are read, log file names and location, the exact output format and caps, the `AGENTS.md` character limit, how tests are counted for each stage, the timeout and what it measures, how the comment check recognises the strings it skips and its test cases, the list of allowed directives, and the tool versions to pin.
