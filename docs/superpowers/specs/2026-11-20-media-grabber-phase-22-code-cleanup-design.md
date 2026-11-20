# Code cleanup

**Status:** proposed, awaiting review. Items belonging to this phase are added here as they arise; scope is settled when the phase starts planning.

**Scope:** structure that has to be right before the app is released and tested as a whole. The first item is where the app keeps its files.

---

## Intent

The app's files (logs, job logs, queue store, Application Support, the default Downloads folder, settings) are located by about a dozen separate pieces of code. Some take an injected `home:` that defaults to the real home. The rest ask the system directly. Several of them spell out the same folder layout, for example `Library/Logs/MediaGrabber`, including the uninstall list. A change to one copy can silently leave another behind, and there is no way to run the whole app against a fake home, because the system ignores a changed `HOME`.

The end state is one place that knows the layout, with every component handed exactly the location it needs.

## 1. App locations

One `AppLocations` value in `GrabberKit`, created once at launch. It is the only code that reads the real home or the optional `MG_HOME` environment variable. It derives the logs folder, the job-logs folder, the queue store, Application Support and the default Downloads folder.

Components receive the narrow location they need, not a home. The log writer gets a logs folder, persistence gets a store location, the cookie reader gets the browser-profile root. None of them knows what `Library/Logs/MediaGrabber` is. The `home:` parameters that default to the real home lose their defaults, so a missed place fails to compile instead of quietly touching the real home.

The uninstall list is derived from the same value, so it cannot drift from where files are written.

When `MG_HOME` is unset, every location is exactly where it is today. The variable is honoured in release builds, because the signed artifact is what gets tested.

## 2. Settings

Settings use `UserDefaults.standard`, which macOS stores in the real `~/Library/Preferences` regardless of `HOME`. When `MG_HOME` is set, `AppLocations` supplies a separate named settings store, so a run against a fake home never reads or writes the real settings.

## 3. Guard

A test fails when source code outside `AppLocations` reads `homeDirectoryForCurrentUser`, `NSHomeDirectory` or `urls(for:)` for a user folder.

## 4. End-to-end run

The end-to-end script sets `MG_HOME` to its temporary home when it starts the app, and checks that `app.launched` appears in the log under that home, in addition to the app staying alive.

## 5. Dependencies

The release-hardening phase's end-to-end script exists. The product page's screenshot script and the test review use the home setting.
