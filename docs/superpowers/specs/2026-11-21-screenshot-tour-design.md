# Screenshot tour

## Intent

The developer needs a repeatable way to see every page and UI state of the app without reaching each by hand: to lock how the app should look, to debug UI, to check a release candidate, and to review the look after a change. `make screenshots` runs the real app on dummy data, walks a fixed list of scenes, and writes images for each scene in both themes. It is a local developer tool. It is never part of a shipped build and never runs in CI.

The app in the picture is the real app: the real window, views, app model, theme code and presentation logic. Only what sits behind them is dummy: the download engine, the system services and the stored data. A scene never draws a copy or a variant of a view.

## Goals

- One command produces images of every page and every UI state the app has, popovers included, in both themes.
- Each theme is captured with one palette: Aurora with Mint Iris, Tape Deck with its A palette.
- Dummy values are varied enough to stress the layout, in the downloads table and in Preferences.
- Two runs of an unchanged app give visually identical images.
- A run never reads or writes the developer's real queue, history, preferences, logs, browser data or clipboard, and never downloads anything.
- Adding a state means adding one scene entry, plus a view hook only when the state lives inside a view.

## Non-goals

- Visual-regression comparison, baselines, or CI use.
- Marketing-grade images (drop shadow, desktop backdrop, device frames).
- Driving the app with synthetic clicks.
- States that exist only while the pointer or keys are held: hover, press, drag in progress.
- Windows that macOS draws and the app does not style: open and save panels, the menu bar, system notifications, the system share sheet, debug alerts.

## Anti-goals

- A screenshot mode that ships in Release builds.
- Any change to how the app looks or behaves outside a screenshot run.
- Scenes that depend on network, real downloads or the developer's machine state.
- A dummy dependency that is left out and silently falls back to the real one.

## Constraints

- `make` is the only build path. `make screenshots` uses the normal install path, so exactly one `MediaGrabber.app` exists on the machine.
- A one-time macOS Screen Recording grant to the program that runs `make` is acceptable.
- Comments are one line and say why only. No ticket or spec references in source.

## Approaches considered

Where the tour lives:

1. An in-app tour in the real window, driven from a scene registry (chosen). The app has direct access to its own model, so setting up a state is a plain call.
2. An external script driving the app over a debug URL or socket. It needs a command protocol inside the app, and the registry would still live in the app.
3. Offscreen rendering of hosted views. It loses the real window, sheets and popovers, and the AppKit downloads table renders wrongly outside a live window.
4. XCUITest. Real clicks, but slow, flaky, needs Accessibility permission, and still needs the same dummy data.

Where the data comes from:

1. A dummy engine and dummy services behind the app's existing seams (chosen). Any state can be shown with exact values, the same on every run. The dummies have to keep up with the app's interfaces, which the compiler enforces for protocols.
2. The real engine loaded with saved dummy rows. Least new code, but saved rows can only be queued, paused, completed, failed or cancelled, so downloading, checking a link, cooldown and waiting for network cannot be shown, and a queued row starts a real download.
3. The real engine driven by a fake downloader script. It exercises the engine, but results depend on timing and cooldowns are hard to force.

## Design

**Launch.** Debug launch arguments put the app in tour mode: `-MGScreenshots <outputDir>`, optionally narrowed by `-MGScreenshotScene <name>` and `-MGScreenshotTheme <aurora|tapeDeck>`. The whole tour, dummies and view hooks sit behind `#if DEBUG`.

**Isolation.** The run sets `MG_HOME` to a new temporary directory, which moves files, logs, browser profile folders and the settings domain away from the real ones. The tour seeds that directory with dummy logs and browser profiles, and the run removes the directory and its settings domain when it ends, whether it passed or failed. Tour mode refuses to start without `MG_HOME`.

**Dummy composition.** In tour mode the app is assembled with every outside dependency passed explicitly as a dummy: download engine, environment check, downloader updater, test-run and sign-in test checks, VPN detection, onboarding set-up, notifications, reveal and open-link actions, app updater, helper installer and diagnostic-bundle sharing. Incoming-link checks, and with them clipboard reading, do not run. No offer to move the app appears. Where a view builds a real service itself, the service moves behind a seam that the app model provides, with unchanged behaviour in a normal run.

**Dummy engine.** It implements the engine interface and publishes whatever queue snapshot a scene asks for: job states, progress, speed, remaining time, queue halt, site rate limits, network and helper status, playlist groups. It does no work of its own, so nothing moves between setting a scene and capturing it. It also answers link checks with fixed results: a video, an audio-capable video, a playlist, a failure, or a check that is still running.

**Real logic stays in charge.** Banners, health chips, row text, row actions, empty states and toasts come from the app's own logic reacting to dummy data. A scene sets text on a banner or chip directly only if no data can produce that state.

**View hooks.** Some state lives inside views: open popovers (pickers, columns menu, health chip, column filter), the Home download choices, the playlist picker's selection and filter, and pane results such as a finished diagnostics run. A debug-only hook sets the same state, or calls the same action, that a click would. A hook changes no layout or styling.

**Dummy values.** All come from literals in one fixture module.

- Table rows: every job state; each failure class that reads differently on screen; each integrity result; video and audio kinds at several qualities; several sites; short, very long, non-English and missing titles; tiny, very large and unknown sizes; short and many-hour durations; progress at the start, middle and nearly done; retried jobs; collapsed and expanded playlist groups; enough rows to scroll.
- Preferences: non-default values in every setting that has one, a long download folder path, a custom file name template, proxy and speed limit filled in, sign-in sites using different browsers and profiles.
- Logs and diagnostics: a mix of passing, warning and failing results.
- Dates and countdowns are set relative to the start of the run, so their labels read the same on every run.

**Scenes.** A scene has a name, dummy data and the steps that reach its state. Each scene starts from a clean state and runs once per theme. The registry covers:

- Onboarding: each step state the view can show, failures included.
- Home, first run: empty field, field with a link, checking a link, check failed, video result, audio result.
- Home with downloads: the full mixed table, each sidebar filter, no matching rows, columns filtered, optional columns shown, playlist group open and closed, several rows selected.
- Popovers: every picker on Home and in Preferences, columns menu, column filter, each health chip popover.
- Sheets and overlays: playlist picker, passcode, helper setup, each confirmation dialog, each warning banner, toasts.
- Preferences: every pane, plus each visibly different state of the sign-in and diagnostics panes.
- About: every tab.

Where the app has no such state yet, there is no scene for it. A planned state gets its scene with the work that builds it.

**Staying complete.** Tests fail when a Preferences pane, About tab, job state or confirmation dialog has no scene or fixture. They also fail when a fixture would let a run reach the network or the real home directory.

**Capture.** The app prepares a scene; the script run by `make` takes the picture with `screencapture`, so the image shows what macOS draws. The Screen Recording grant therefore goes to the program that runs `make`, not to the app, which is a new binary after each rebuild. A popover, sheet or overlay is shown over its page in one image. The app and script hand off through files in the output directory: after a scene settles the app writes `<scene>.ready` with the window ids and waits for `<scene>.done`. A scene that does not settle or capture in time fails the run. The window has a fixed size of 980 x 720, and animation is stopped or allowed to finish before capture.

**Output.** `screenshots/<theme>/<scene>.png`. The directory is ignored by git. A full run clears it first; a narrowed run replaces only its own images. A failed run exits nonzero and names the scene and the reason.

**Make target.** `make screenshots [SCENE=<name>] [THEME=<theme>]` builds and installs a Debug build, runs the tour, leaves no tour-mode app running even when interrupted, and opens the output folder. It is documented with the other `make` commands.

## Left to the builder

- How a scene is judged settled.
- How a popover or sheet is combined with its page in one image.
- The exact fixture values within the ranges above.
- How the dummy engine and the test suite's fake engine share code, if at all.
- Scene names.
