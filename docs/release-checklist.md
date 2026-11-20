# Release checklist

Run through this list before every release, in order.

1. Clean-account install: install the built disk image on a macOS user account that has never run MediaGrabber. On first launch macOS blocks the app — right-click and choose **Open Anyway**. Confirm About's **"Read licenses"** opens each license text, and that the **Privacy** pane shows the privacy statement.

2. YouTube link that needs the helper: paste a YouTube link and confirm the download starts (the bot-check shield runs on your Mac).

3. Uninstall from a read-only copy: copy the app to a read-only volume, run **Preferences → Advanced → Uninstall…**, confirm removal, and confirm no `MediaGrabber.app` remains.

4. `make e2e`: every check prints `ok`; afterwards no `MediaGrabber.app` remains under `build/`.

5. Release notes present: `release-notes/X.Y.Z.md` exists and describes the release in plain words.

6. After publishing: `scripts/release/check-feed.sh --version X.Y.Z` passes — the newest feed item carries the version and the disk image answers at the advertised size.

7. On major and minor releases: the `yt-dlp` pin in `scripts/tools.lock` is the latest yt-dlp release.

8. On the second real release: install the first release, then update in place to the second before announcing it to anyone.

9. Bad-release recovery: delete the newest release so the previous one becomes latest by commit date; keep the explicit latest flag; re-run the feed check.
