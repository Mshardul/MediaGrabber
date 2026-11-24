# Review: remaining GrabberKit folders (`Diagnostics`, `Licenses`, `Link`, `RateLimiting`, `App`)

Source: `/code-review high`. Every item below was checked by reading the cited code. Item 4 was also checked against files on disk.

## Confirmed

1. `YtDlpUpdater.swift:119` and `:133`, a failed write, chmod or replace of the new binary returns `YtDlpUpdateCopy.offline` ("Couldn't download the update. Check your connection and try again."). The download had already succeeded, so the message is wrong for that cause.
2. `YtDlpUpdater.swift:170` and `:187`, no request checks the HTTP status. A GitHub API rate-limit or error reply without `tag_name` throws and shows the offline message while the user is online, and a 404 page for the binary is hashed and reported as "didn't download properly".
3. `Link/LinkExtractor.swift:41`, a URL ends only at whitespace, `<` or `>`, so trailing punctuation or a closing bracket from pasted text becomes part of the URL ("watch this: https://youtu.be/abc123." gives a URL ending in "."). Scheme matching is case-sensitive (`text.range(of: "https://")`), so `HTTPS://` is missed.
4. `App/AppFootprint.swift:8`, the footprint list has four directories and the preferences file. On this machine `~/Library/HTTPStorages/app.mediagrabber.mac`, `~/Library/Cookies/app.mediagrabber.mac.binarycookies` and the share extension's `~/Library/Containers/app.mediagrabber.mac.share` exist and are not in the list, while the uninstall copy says "Everything MediaGrabber saved is gone".
5. `Uninstall.swift:65`, the failed-removal state (same defect as the app-shell report, item 3): shutdown and `stopSaving()` run before `deleteFootprint()`, and nothing undoes them.
6. `Uninstall.swift:49`, `isActive` counts queued, paused, cooling-down and waiting-for-network jobs, and the dialog says "Still downloading: …", false for a paused or queued job.
7. `RateLimiting/RateLimiter.swift:100`, `recordStrike` sets `strikeLoweredCap = true` and the cap to 1 whatever the cap was before. When the preferences cap is 1, `concurrencyReducedToOne` becomes true after a strike though nothing was reduced, and the flag is cleared only when the cap rises above 1, which cannot happen.
8. `Link/ShareExtractor.swift:24`, `firstURL` returns any URL the provider loads, including `file://`, and returns at once, so the link in the shared text is never tried.
9. Comment rule: `///` comments at `Licenses/LicenseCatalog.swift` lines 3, 20-22 and 68, and a stacked `//` block at `Link/ShareExtractor.swift:4-5`.

## Unconfirmed

- `App/InstallLocation.swift:47`, `move` uses `moveItem`. From a read-only disk image, Foundation copies and then cannot remove the source. Whether it throws after leaving a full copy in Applications is Foundation behaviour I cannot see from the code. Test: open the app from the mounted disk image and accept the move prompt.
