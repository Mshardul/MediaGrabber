# AI Agent Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One check script, short build output, a thin Makefile and shared written rules, so any AI agent writes code to the same standard.

**Architecture:** A standard-library Python package, `scripts/checks/`, holds every check and serves `make`, `pre-commit` and CI. A second package, `scripts/buildlog/`, runs build and test stages and shortens their output. Git and external tools sit behind small interfaces, so script tests never reach the real ones.

**Tech Stack:** Python (repo `.venv`, `unittest`), Bash, Make, SwiftFormat, SwiftLint, ShellCheck, shfmt, Ruff, Periphery, `pre-commit`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-26-ai-guardrails-design.md`. Read it with this plan.

## Global Constraints

- Run no git commands. `make fix`, `make check`, `make fix-all` and `make check-all` may be run. Move files with `mv`.
- Build and test only through `make`. At most one `MediaGrabber.app` exists on the machine. Never run a release target.
- Use `.venv/bin/python`, never system `python3`, except to create the venv. New Python uses the standard library only.
- Python is 3.15, pinned in `.python-version`.
- Tools run as their pinned copy: Swift and shell tools through `mise`, Ruff from `.venv`. A missing tool or pin fails, with no fallback.
- Every new or changed file passes the comment rule: one line at most, only to explain why, no stacked comments.
- `pre-commit` runs no build and no tests. Compiler warnings are checked nowhere.
- Script tests must not touch `/Applications`, real processes, Launch Services, git, `gh` or the network.
- No new dependency beyond ShellCheck, shfmt, Periphery and Ruff. Ask the user before adding another, a suppression, or a setting change this plan does not name.
- Fixed values: logs in `build/logs/`; at most 50 findings printed; `AGENTS.md` at most 6000 characters; a build stage is hung after 600 seconds without output, overridable with `MG_STAGE_IDLE_TIMEOUT`.
- Each task ends with its tests passing, then stops for the user's review.

## Review Focus

1. A changed set containing a deleted file, a renamed file or a path with spaces: only existing files are checked, and unrelated files never block. (Task 2)
2. A new file inside a new directory that nothing tracks yet: it is checked. (Task 2)
3. A tool that crashes or prints something unparsable: the run fails and shows the tool's last lines, never a pass. (Task 3)
4. A tool found on `PATH` but missing its pin: the run fails and names the tool. (Task 3)
5. A build or test interrupted with Ctrl-C: child processes stop and no built app remains. (Task 12)

## File Structure

| Path | Responsibility |
| --- | --- |
| `scripts/checks/__main__.py` | Command line, wiring, exit status |
| `scripts/checks/repo.py` | Everything read from git: file lists and added lines |
| `scripts/checks/files.py` | Languages, exclusions, per-tool file lists |
| `scripts/checks/tools.py` | External tools, fix order, parsing their findings |
| `scripts/checks/comments.py` | Comment check |
| `scripts/checks/rules.py` | Project rules and the `AGENTS.md` limit |
| `scripts/checks/report.py` | Suppression and settings report |
| `scripts/checks/output.py` | Short output, log file, CI summary |
| `scripts/buildlog/` | Stage runner, test counts, short build output |
| `scripts/make/` | Logic moved out of the Makefile |
| `scripts/tests/lib/sandbox.sh` | Closed environment for tests of risky scripts |
| `scripts/tests/checks/`, `scripts/tests/buildlog/` | `unittest` suites, each run by a `test_*.sh` wrapper |

---

### Task 1: Pin the tools and settle the unknowns

**Files:** Modify `.mise.toml`, `requirements.txt`, `.swiftformat`, `.swiftlint.yml`. Create `.editorconfig`.

**Interfaces:** Produces pinned `shellcheck`, `shfmt`, `periphery` (macOS only) and `ruff`; and a written answer to each question below, which later tasks rely on.

- [x] **Step 1:** Pin the current stable `shellcheck`, `shfmt` and `periphery` in `.mise.toml` with exact versions, and add `ruff==0.16.5` to `requirements.txt`. Run `mise install` and `make venv`. Verify each with `mise which <tool>` and `.venv/bin/ruff --version`.
- [x] **Step 2:** Create `.editorconfig` giving shell files, including `scripts/tests/stubs/gh`, `indent_style = space` and `indent_size = 4`. In a scratch directory, confirm shfmt applies it to a `.sh` file and an extensionless script when no format flag is passed.
- [x] **Step 3:** Add `--disable noForceUnwrapInTests` to `.swiftformat`. In a scratch directory, find the SwiftFormat and SwiftLint rules that disagree on the brace after a wrapped multi-line condition, and turn off the SwiftLint one in `.swiftlint.yml`.
- [x] **Step 4:** Answer each in a scratch directory and report the command and result:
  - What does Ruff do with no paths, and does `--force-exclude` exclude a file passed by name?
  - Which enabled SwiftLint rules need SourceKit, and does each still report with `SWIFTLINT_DISABLE_SOURCEKIT=1`?
  - Can `.mise.toml` limit `periphery` to macOS so Ubuntu installs still succeed?
  - What does `periphery scan` with its skip-build and index-store options write, and does it leave any `.app` or DerivedData folder? Use an index already in `build/`.
  - Which `xcrun xcresulttool` command returns executed test counts and failures with the pinned Xcode?
  - Can shfmt, Ruff and ShellCheck report their findings over the current repo? Record the counts.
- [x] **Step 5:** If an answer contradicts the spec, stop and bring it to the user.

**Gate:** `make lint` shows no `noForceUnwrapInTests` finding, and the user has the answers.

---

### Task 2: File selection

**Files:** Create `scripts/checks/__init__.py`, `repo.py`, `files.py`, `scripts/tests/checks/test_files.py`, `scripts/tests/test_checks.sh`.

**Interfaces — Produces:**

```python
class Scope(Enum): CHANGED, STAGED, ALL
class Language(Enum): SWIFT, SHELL, PYTHON, CONFIG, OTHER
AddedLine = NamedTuple("AddedLine", path=str, line=int, text=str)

class Repo(Protocol):
    def paths(self, scope: Scope) -> list[str]: ...
    def added_lines(self, scope: Scope, base: str | None = None) -> list[AddedLine] | None: ...

class GitRepo(Repo):  # takes an injectable command runner
    ...

def language_of(path: str, first_line: str) -> Language
def select(paths: Iterable[str], root: Path) -> dict[Language, list[str]]
EXCLUDED: tuple[str, ...]
```

`CHANGED` is every difference from the last commit plus new files that are not ignored. `ALL` is every file that is not ignored. `added_lines` returns `None` when the base is unusable. `CONFIG` covers YAML, TOML and the Makefile. `EXCLUDED` holds `scripts/create-dmg`, `scripts/support/`, and the generated and fetched paths in `.gitignore`.

- [x] **Step 1:** Write failing tests, with a fake command runner for `GitRepo`:

```python
def test_deleted_path_is_dropped(self):        # listed but absent on disk -> in no list
def test_renamed_file_appears_once_under_new_name(self):
def test_path_with_spaces_survives(self):      # "Sources/A B.swift" -> one entry
def test_untracked_file_in_new_directory_is_selected(self):
def test_excluded_paths_are_dropped(self):     # "scripts/create-dmg", "scripts/support/x"
def test_extensionless_shell_by_shebang(self): # "#!/usr/bin/env bash" -> SHELL
def test_root_and_scripts_swift_are_swift(self):  # Project.swift, scripts/ed25519.swift
def test_empty_language_has_empty_list(self):
def test_unusable_base_returns_none(self):
```

- [x] **Step 2:** Run `scripts/tests/test_checks.sh`. Expected: FAIL, module not found.
- [x] **Step 3:** Implement. Read path lists NUL-separated.
- [x] **Step 4:** Run `scripts/tests/test_checks.sh`. Expected: PASS.

---

### Task 3: Tool runners and fix order

**Files:** Create `scripts/checks/tools.py`, `scripts/tests/checks/test_tools.py`. Modify `.gitignore`, `scripts/checks/files.py` and `scripts/tests/checks/test_files.py` so that `__pycache__/` is ignored by git and listed in `EXCLUDED`.

**Interfaces — Consumes:** `Language`, `select`. **Produces:**

```python
@dataclass(frozen=True)
class Finding: check: str; rule: str; path: str; line: int | None; message: str

@dataclass
class RunResult: findings: list[Finding]; edited: list[str]; broken: list[str]; log: str

class Exec(Protocol):
    def run(self, argv: list[str], cwd: Path) -> Completed: ...

def run_tools(selection, root: Path, fix: bool, exec: Exec) -> RunResult
```

`broken` names any tool that is missing, unpinned, crashed, or exited non-zero with nothing parsable, with its last 20 lines. `edited` comes from comparing file contents before and after.

- [x] **Step 1:** Write failing tests with a fake `Exec`:

```python
def test_tool_with_empty_list_is_not_run(self):
def test_tools_get_files_never_directories(self):
def test_swiftlint_gets_strict_and_force_exclude_never_fix(self):
def test_shfmt_gets_no_format_flags(self):
def test_check_run_passes_no_write_flag_to_any_tool(self):
def test_fix_order_is_linter_fixes_then_formatters_then_verify(self):
def test_ruff_never_gets_unsafe_fixes(self):
def test_shellcheck_runs_at_all_severities(self):  # no -S flag
def test_unparsable_failure_is_broken_not_clean(self):
def test_unpinned_tool_is_broken_even_if_on_path(self):
def test_edited_lists_only_files_whose_content_changed(self):
```

- [x] **Step 2:** Run `scripts/tests/test_checks.sh`. Expected: FAIL.
- [x] **Step 3:** Implement. Resolve Swift and shell tools with `mise which`; take Ruff from `.venv/bin/ruff`. Use each tool's machine-readable reporter where it has one.
- [x] **Step 4:** Add real-tool tests in a temporary directory. Each of SwiftFormat, SwiftLint, ShellCheck, shfmt, Ruff lint and Ruff format gets a bad example that a check run must report. After a fix run on fixable examples, a check run on the same files passes. Include a bad file under a `scripts/` folder and assert it is reported. `statement_position`, `unavailable_condition` and `void_function_in_ternary` need SourceKit, so each gets its own bad example, and the test asserts that rule is reported; without SourceKit the last two disappear with no warning.
- [x] **Step 5:** Run `scripts/tests/test_checks.sh`. Expected: PASS.

---

### Task 4: Comment check

**Files:** Create `scripts/checks/comments.py`, `scripts/tests/checks/test_comments.py`.

**Interfaces — Consumes:** `Finding`, `Language`. **Produces:** `check_comments(path: str, text: str, language: Language) -> list[Finding]`, with rules `stacked-comment`, `block-comment`, `docstring`, `doc-comment`; and `ALLOWED_DIRECTIVES`, covering `MARK:`, shebangs, `swiftlint:`, `swiftformat:`, `shellcheck`, `noqa`, `ruff:`, `type:`, `fmt:`, `yaml-language-server:` and `swift-tools-version`.

- [x] **Step 1:** Write failing tests. Each bad case yields exactly one finding with the named rule; each good case yields none.
  - Bad: two comment-only lines; two separated by a blank line; a multi-line `/* */`; a multi-line Python docstring; a two-line `///`; a `///` outside `Sources/GrabberKit/`; a one-line `/** */` outside `Sources/GrabberKit/`, which follows the `///` rules everywhere; either form outside `Sources/GrabberKit/` before or after code on the same line; stacked comments in YAML (including inside `run: |`), TOML and the Makefile.
  - Good: one comment; an end-of-line comment followed by a comment-only line; `// MARK:` beside a comment; a shebang followed by one comment; `//` lines inside Swift `"""` and `#"""#` strings; `#` lines inside quoted and unquoted heredocs, including `<<-`; a one-line `///` in `GrabberKit`; a one-line docstring; `#` lines inside a Python string.
- [x] **Step 2:** Run `scripts/tests/test_checks.sh`. Expected: FAIL.
- [x] **Step 3:** Implement. Python uses `tokenize` and `ast`. Swift and shell track only multi-line strings and heredocs. `CONFIG` files use the plain line rule.
- [x] **Step 4:** Run `scripts/tests/test_checks.sh`. Expected: PASS.

---

### Task 5: Project rules and the `AGENTS.md` limit

**Files:** Create `scripts/checks/rules.py`, `scripts/tests/checks/test_rules.py`. Modify `scripts/checks/comments.py` and `scripts/tests/checks/test_comments.py` so both checks share one comment and string reader.

**Interfaces — Produces:** `check_rules(path: str, text: str, language: Language) -> list[Finding]` with rules `process-use`, `swiftui-in-kit`, `work-reference`, `empty-catch`, `agents-size`.

- [x] **Step 1:** Write failing tests, one bad and one good case per rule:
  - `process-use`: `Process()` in `Sources/App/X.swift` fails; it passes in `ProcessRunner.swift`, `AppRelauncher.swift` and `scripts/make-app-icon.swift`; `ProcessLaunch(` passes.
  - `swiftui-in-kit`: `import SwiftUI` and `import struct SwiftUI.Color` under `Sources/GrabberKit/` fail.
  - `work-reference`: a comment containing `Phase 4` or `mg-032` fails; the same text in a string passes.
  - `empty-catch`: `catch {}` and a `catch` block with only blank lines or comments fail; one with a statement passes.
  - `agents-size`: 6001 characters in `AGENTS.md` fails, 6000 passes.
- [x] **Step 2:** Run `scripts/tests/test_checks.sh`. Expected: FAIL. Then implement, reusing the comment and string tracking from `comments.py`.
- [x] **Step 3:** Run `scripts/tests/test_checks.sh`. Expected: PASS.

---

### Task 6: Suppression and settings report

**Files:** Create `scripts/checks/report.py`, `scripts/tests/checks/test_report.py`.

**Interfaces — Consumes:** `AddedLine`. **Produces:** `build_report(added: list[AddedLine], paths: list[str]) -> list[ReportItem]` and `settings_changed(paths: list[str]) -> bool`.

The patterns and the setting files are those listed in the spec's report section. A Makefile line counts when it names a check target or the check script. `settings_changed` is true for lint and format settings, pinned tools and the check script.

- [x] **Step 1:** Write failing tests: each suppression and risky construct on an added line is listed with path and line; the same text on an unchanged line is not; each setting file is listed; an unrelated Makefile line is not; `settings_changed(["Sources/A.swift"])` is false and `settings_changed([".swiftlint.yml"])` is true.
- [x] **Step 2:** Run (FAIL), implement, run again (PASS) with `scripts/tests/test_checks.sh`.

---

### Task 7: Command line, short output, Make targets and the hook

**Files:** Create `scripts/checks/__main__.py`, `output.py`, `scripts/tests/checks/test_cli.py`, `.python-version`. Modify `scripts/checks/repo.py` and `scripts/tests/checks/test_files.py` so `Repo` can list the paths changed since a base, including deleted and renamed files; `Makefile`, `.pre-commit-config.yaml`, `docs/development.md`.

**Interfaces — Consumes:** everything above. **Produces:**

```text
.venv/bin/python scripts/checks <fix|check|fix-all|check-all|staged> [--summary-base REF] [--summary-file PATH]
render(result, report, mode, log_path, cap=50) -> tuple[str, int]
```

Targets: `make fix`, `check`, `fix-all`, `check-all`. `staged` fixes staged files, never stages, and exits non-zero on any edit or leftover.

- [x] **Step 1:** Write failing tests:

```python
def test_clean_run_prints_one_line_and_exits_0(self):
def test_no_files_says_nothing_verified(self):  # "0 files checked, nothing verified"
def test_edited_files_are_named_on_a_pass(self):
def test_long_output_is_capped_grouped_by_rule_with_omitted_count_and_log_path(self):
def test_broken_tool_exits_nonzero(self):
def test_report_alone_keeps_exit_0(self):
def test_settings_change_prints_one_check_all_reminder(self):
def test_check_modes_never_edit(self):
def test_staged_edit_exits_nonzero_and_mentions_make_fix(self):
def test_unusable_summary_base_is_stated_and_status_unchanged(self):
```

- [x] **Step 2:** Run (FAIL), implement, run again (PASS) with `scripts/tests/test_checks.sh`.
- [x] **Step 3:** Add the four targets. In `.pre-commit-config.yaml`, remove the two Ruff hooks and add one local hook with `require_serial: true`, `verbose: true`, `pass_filenames: false`, calling `staged` mode. A thin wrapper gives a plain error when `mise` or `.venv` is missing. Document `pre-commit install` in `docs/development.md`.
- [x] **Step 4:** Ask the user to test the hook, since it needs a commit: one fully staged badly formatted file, one partly staged file whose fix does not overlap the unstaged change, and one whose fix does. Expected in turn: fixed and unstaged with the commit stopped; the same; rolled back with the `make fix` message shown. Pre-commit hides a passing hook unless `verbose` works, so also confirm a passing commit shows the report.
- [x] **Step 5:** Write `3.15` to `.python-version`. `make venv` creates the venv with that version and fails with a plain error when it is not installed or an existing `.venv` has another version. Ask the user before replacing an existing `.venv`, then run `make venv` and `scripts/tests/test_checks.sh`. Expected: PASS.
- [x] **Step 6:** Run `make check`. Expected: every file changed so far passes.

---

### Task 8: One script-test list

**Files:** Create `scripts/run-script-tests.sh`, `scripts/tests/test_run_script_tests.sh`. Modify `Makefile`, `scripts/tests/test_appcast.sh`.

**Interfaces — Produces:** `make scripts-test`; `scripts/run-script-tests.sh [--exclude NAME]... [DIR]` runs every `test_*.sh` not excluded by name and prints `script tests: N run, M failed`, followed by the count and names of any excluded.

- [x] **Step 1:** Write the failing test against a temporary directory: two passing scripts and one failing give a non-zero exit and `3 run, 1 failed`; an empty directory fails.
- [x] **Step 2:** Implement. Replace `tools-test`, `appcast-test`, `release-assets-test` and `release-scripts-test` with `scripts-test`. Make `test_appcast.sh` default to `.venv/bin/python`. Move the plugin requirements install from `plugin-test` into `venv`.
- [x] **Step 3:** Run `make scripts-test`. Expected: PASS. Fix any test that fails; no test may skip itself and exit 0.

---

### Task 9: Written rules

**Files:** Create `AGENTS.md`, `docs/coding-standards.md`, `docs/project-history.md`, and any topic document under `docs/` that a moved project fact needs. Modify `CLAUDE.md`, `docs/development.md`.

- [x] **Step 1:** Write `AGENTS.md` (at most 6000 characters): the must-follow rules from the spec's general rules, including that a test is never changed just to make it pass, the definition of done, the git rule, the commands, when to read `docs/coding-standards.md`, and links to the project-fact documents. Markdown is not hard-wrapped.
- [x] **Step 2:** Write `docs/coding-standards.md`: detail for each general rule, test writing and review guidance including forced unwraps and how to tell whether a failing test or the code is wrong, a review checklist, and short Swift, shell and Python sections. Move the Swift concurrency, lint, process, fixture and network traps from `CLAUDE.md` into them.
- [x] **Step 3:** In `CLAUDE.md`, import `AGENTS.md` with `@AGENTS.md` and keep only what is specific to Claude. Move every rule that applies to any agent into the shared files, replacing the old comment and `///` rules. Move the project facts any agent needs, including the project overview, document map, build, release, toolchain and font notes, into `docs/development.md` or topic documents under `docs/`. Move the shipped-phase history to `docs/project-history.md`. Ask the user before dropping anything instead of moving it.
- [x] **Step 4:** Verify: `make check` passes, including `agents-size`; each rule or fact removed from `CLAUDE.md` is found once at its destination; each project-fact document is reachable from `AGENTS.md`. List the moves for the user.

---

### Task 10: Cleanup

**Files:** Every file `make check-all` reports.

- [x] **Step 1:** Ask the user to confirm that other work in progress is settled. Wait.
- [x] **Step 2:** Run `make check-all` and give the user the count per check. List each finding that needs a suppression or setting change, and get approval before making one.
- [x] **Step 3:** Run `make fix-all`, then `make test`. Expected: PASS. Review the diffs of rewritten Swift and shell files.
- [x] **Step 4:** Fix the rest by hand: comments (including script headers and multi-line `///`), phase references, ShellCheck notes, SwiftLint findings under `scripts/`.
- [x] **Step 5:** Run `make check-all` and `make test`. Expected: both PASS.

---

### Task 11: CI

**Files:** Modify `.github/workflows/ci.yml`, `Makefile`, `CLAUDE.md`, `docs/development.md`.

- [x] **Step 1:** In the Linux check job: check out with full history, set up Python from `.python-version`, run `make venv` and `scripts/tests/test_checks.sh`, then `make check-all` with `--summary-base` set to the pull request base or the previous push commit, and `--summary-file` set to the job summary. Remove the two Swift lint steps.
- [x] **Step 2:** Remove the `scripts-test` job. In the macOS test job, set up Python from `.python-version`, run `make venv`, `make plugin-test` and `make scripts-test`, excluding the check script's tests, which the check job runs. A scheduled run uses the same steps.
- [x] **Step 3:** Remove `make lint` and update its mentions in `CLAUDE.md`, `AGENTS.md` and the documents under `docs/`, leaving archived ones as they are.
- [ ] **Step 4:** Ask the user to push, then to run a release dry run so the release job's tool install is proved. Both must pass.

---

### Task 12: Short build and test output

**Files:** Create `scripts/buildlog/__main__.py`, `runner.py`, `xcresult.py`, `summary.py`, `scripts/tests/buildlog/test_runner.py`, `test_summary.py`, `scripts/tests/test_buildlog.sh`. Modify `Makefile`, `scripts/run-script-tests.sh`.

**Interfaces — Produces:**

```python
@dataclass(frozen=True)
class Stage: name: str; argv: list[str]; counts_tests: bool

def run_stages(stages: list[Stage], log_dir: Path, idle_timeout: float, cleanup: Callable[[], None]) -> int
def read_xcresult(bundle: Path, exec: Exec) -> TestCounts  # executed, skipped, failures
```

- [ ] **Step 1:** Write failing tests with short fake stage commands:

```python
def test_prints_one_progress_line_per_stage(self):
def test_stage_exit_status_is_preserved(self):
def test_test_stage_with_zero_executed_fails_even_with_skips(self):
def test_old_result_bundle_is_removed_before_run(self):
def test_missing_new_bundle_fails(self):
def test_compiler_errors_and_failed_tests_are_shown_once_with_repeat_count(self):
def test_warnings_stay_out_of_short_output_and_in_the_log(self):
def test_unknown_failure_shows_stage_name_and_log_tail(self):
def test_idle_timeout_kills_the_process_group_and_runs_cleanup(self):
def test_interrupt_kills_children_and_runs_cleanup(self):
```

- [ ] **Step 2:** Run `scripts/tests/test_buildlog.sh` (FAIL), implement using the `xcresulttool` command from Task 1, run again (PASS). The plugin stage counts `unittest` tests; the script stage counts scripts run. Use `xcrun xcresulttool get test-results summary --path <bundle>`; its `totalTestCount` includes skips, so executed is that minus `skippedTests`. The command is proven on local Xcode 27.1, not on the pinned 26.3, so the reader fails and names any expected field that is missing.
- [ ] **Step 3:** Route `make build` and `make test` through it, with `cleanup` removing the built app.
- [ ] **Step 4:** Run `make test` (PASS, three non-zero counts), `make test ONLY=GrabberKitTests/NoSuchSuite` (FAIL, zero Xcode tests), and plain `make` (app relaunches, one copy). Interrupt one `make test` with Ctrl-C and confirm no `.app` remains under `build/`.

---

### Task 13: Safe test setup and a thin Makefile

**Files:** Create `scripts/tests/lib/sandbox.sh`, `scripts/make/replace-installed.sh`, `drop-build-app.sh`, `e2e.sh`, `help.sh`, and `scripts/tests/test_sandbox.sh`, `test_replace_installed.sh`, `test_drop_build_app.sh`, `test_e2e.sh`, `test_remove_app_copies.sh`, `test_make_help.sh`. Modify `Makefile`, `scripts/remove-app-copies.sh`.

**Interfaces — Produces:** `sandbox_init` (temporary `HOME` and apps folder; a `PATH` of failing stubs for `git`, `gh`, `curl`, `pkill`, `killall`, `osascript`, `open`, `mdfind`, `ditto`) and `sandbox_fake NAME BODY`. Scripts take overrides `MG_APPLICATIONS_DIR`, `MG_LSREGISTER`, `MG_DERIVED` and `MG_PGREP`, with today's values as defaults. In the sandbox, `MG_LSREGISTER` points at a failing stub. Built-ins that signal processes, such as `kill`, are overridden by a failing function.

- [ ] **Step 1:** Write `test_sandbox.sh` first: each unfaked risky command fails, including `kill` and the launch-services path; `HOME` and the apps folder are temporary.
- [ ] **Step 2:** For each script, write a failing test from today's recipe before moving it: the order of calls; a missing build product removes nothing; a failed removal exits non-zero; `--keep` is honoured; `e2e` removes the built app after a failure and after an interrupt.
- [ ] **Step 3:** Move each recipe without changing behaviour, passing `CONFIG`, `ONLY`, `VERSION`, `PY` and `DERIVED` explicitly.
- [ ] **Step 4:** Give each public target a trailing `## description` that names its options. `make help` lists them. `test_make_help.sh` fails if a public target lacks one. Plain `make` still builds and relaunches.
- [ ] **Step 5:** Run `make scripts-test`, `make help`, `make e2e` and plain `make`. Expected: all pass with one app on the machine. Ask the user before running `make reinstall` or `make remove-copies`, which delete app copies.

---

### Task 14: Move the release logic

**Files:** Create `scripts/make/release.sh`, `release-dispatch.sh`, `scripts/tests/test_release_make.sh`. Modify `Makefile`.

**Interfaces — Consumes:** `sandbox_init`, `sandbox_fake`. **Produces:** `release.sh <patch|minor|major>`; `release-dispatch.sh <dry-run|overwrite> <VERSION>`.

- [ ] **Step 1:** Write failing tests with fake `git` and `gh` that record every call: no bump, a dirty tree, the wrong branch and a diverged branch each stop before any `gh` call; the dry-run poll retries after a failed or empty lookup and stops after 30 tries; a failed dry run stops; any answer but `yes`, then any but `y`, creates and pushes no tag; the success path records tag then push, with `vX.Y.Z`; a bad or missing `VERSION` calls nothing; declining an overwrite calls nothing.
- [ ] **Step 2:** Move the logic, keeping retries and ignored failures as they are today. Run `make scripts-test`. Expected: PASS.
- [ ] **Step 3:** Ask the user to run `make release-dry-run` with a valid version. Expected: the workflow starts and passes. Do not run it yourself.

---

### Task 15: Dead-code command

**Files:** Create `scripts/make/dead-code.sh`, `scripts/tests/test_dead_code.sh`. Modify `Makefile`, `docs/development.md`.

- [ ] **Step 1:** Write a failing sandbox test: the app and tests are built into `build/`, Periphery gets the skip-build, index-store and `--skip-schemes-validation` options, and the built app is removed after success and after failure. Without the last option, Periphery reports that the `MediaGrabber-Workspace` scheme does not exist.
- [ ] **Step 2:** Implement `make dead-code` using the invocation proved in Task 1.
- [ ] **Step 3:** Run `make dead-code`. Expected: a result list, no `.app` under `build/`, and no new DerivedData folder. Report the findings to the user; fixing them is not part of this plan, so file a ticket for them if there are any.

---

## Tickets this plan overlaps

| Row                    | Covered by     |
| ---------------------- | -------------- |
| mg-032, mg-065, mg-141 | Task 10        |
| mg-142                 | Tasks 8 and 11 |
| mg-178                 | Task 10        |

mg-177, an intermittent test, can fail the `make test` gates in this plan until it is fixed.
