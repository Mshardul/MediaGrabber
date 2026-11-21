# Screenshot tour

## Intent

The developer needs a repeatable way to see every page of the app without opening each by hand: for debugging UI, checking a release candidate, and reviewing the look after a change. `make screenshots` launches the app, walks a fixed list of scenes, and writes one PNG per scene. It is a local developer tool. It is never part of a shipped build and never runs in CI.

## Goals

- One command produces a PNG for every registered page, in both themes.
- Output is deterministic: same fixture data, same window size, same settle rules, so two runs of an unchanged app give visually identical images.
- Real window, real chrome, real sheets and popovers: the capture is of the actual running app, not a re-created view tree.
- Adding a page later means adding one scene entry, nothing else.
- Running it never touches the developer's real queue, history or preferences.

## Non-goals

- Visual-regression comparison, baselines, or CI use.
- Marketing-grade images (drop shadow, desktop backdrop, device frames).
- Driving the app with synthetic clicks. Navigation goes through the app's own model.

## Anti-goals

- A screenshot mode that ships in Release builds.
- Scenes that depend on network, real downloads, or machine state.
- A tour that can wipe or rewrite the developer's real app state.

## Constraints

- `make` is the only build path. `make screenshots` depends on the normal install path, so exactly one `MediaGrabber.app` exists on the machine.
- Local only. A one-time macOS permission grant (Screen Recording) is acceptable and used.
- Comments single-line, why-only. No phase or ticket references in source.
- User-facing copy rules do not apply: nothing here is visible to users.

## Approaches considered

1. In-app tour in the real window, driven from a scene registry (chosen). The app has direct access to its model, so seeding and navigation are plain calls. Debug-only.
2. External script driving the app over a debug URL or socket. Closer to Playwright's shape, but it needs a command protocol inside the app and the registry would still live in the app.
3. Offscreen render of hosted views, no real window. Avoids a visible window, but loses real chrome and real sheets and popovers, and AppKit-backed views such as the Downloads table render wrongly outside a live window.
4. XCUITest. Real clicks, but slow, flaky, needs Accessibility permission, and still needs the same seed layer.

## Design

**Launch contract.** A debug launch argument `-MGScreenshots <outputDir>` (parsed in `DebugFlags`) puts the app in tour mode. Optional `-MGScreenshotScene <name>` and `-MGScreenshotTheme <aurora|tapeDeck>` narrow the run. The whole tour sits behind `#if DEBUG`; Release builds contain none of it.

**Isolated state.** Tour mode points persistence and preferences at a throwaway directory under the output dir's parent, never the real location. It forces onboarding off, the window to a fixed size, and the animation-free path where the app has one.

**Scene registry.** A scene is: a name, a theme, a seed (fixture state loaded into the model), a navigation step (select a Preferences pane, open About, present the confirmation dialog, show Onboarding, and so on), and a settle condition (the page reports ready, with a short fixed timeout as backstop). Registered scenes, first cut:

- onboarding
- home: empty, first run, with a queue
- queue rows on Home: paused with progress, finished, failed, cancelled, playlist group (never queued rows: the live engine would start them)
- each Preferences pane (downloads, appearance, network, cookies, updates, logs, privacy, licenses, advanced, diagnostics)
- about, developer
- confirmation dialog, playlist picker, warning banner

Each scene runs once per theme.

**Fixtures.** One shared fixture module builds jobs, history rows and preference values from literals. No network, no clock: dates are fixed, progress is frozen. The same fixtures are usable by tests later.

**Capture.** The app only prepares each scene; a script run by `make` takes the picture with `screencapture -l <windowID>`, so the image is the real window with its real shadow, and a sheet or popover is captured as the window it is. The grant goes to the terminal that runs `make`, once. It is not given to the app: a rebuilt Debug app is a new binary each time and would lose the grant. The app and the script hand off through the output directory: after a scene settles the app writes `<scene>.ready` containing the window ids, then waits for `<scene>.done` before moving on. A scene that never reports ready within its timeout fails the run.

**Output.** `screenshots/<theme>/<scene>.png`, directory gitignored, wiped at the start of a full run. The app exits when the tour finishes; a nonzero exit means a scene failed to settle or write, and the failing scene name is printed.

**Make target.** `make screenshots [SCENE=<name>] [THEME=<theme>]` builds and installs through the existing path (Debug), launches the installed app with the flags, waits for exit, prints the output path, and opens the folder in Finder.

## Left to the builder

- Exact settle mechanism per page type.
- How sheets and popovers are located and composited.
- Whether Preferences is reached as a window or an in-window pane, matching how the app presents it today.
- Fixture contents beyond the list above.
- Tests: scene registry has unique names, every `PreferencesPane` case has a scene, flag parsing, output path building.

## Tracking

A single backlog ticket on the board.
