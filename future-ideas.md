# Future ideas

Features and ideas for the distant future. None of these is scheduled, none has a phase, and each has only a limited view of what it would be. They are written down so they are not lost. Each one gets discussed, scoped and given a phase when planning reaches it.

An entry here is not a commitment. Work that already has an owner lives in `roadmap.md` or `tickets.md`.

## v2

### Failure-code explainer page

A page that explains every failure reason the app can show (the codes behind a failed row), and where a fix exists, offers plain "how to" steps for it.

Today a failed row shows its reason in plain words and offers Restart, so the user can act and try again. The page would go further: what the reason means, why it happens, and the steps to fix it.

Related today: the reason on the row (mg-018) and Restart on every failed row (mg-067).

## Declined for Phase 17

Subtitles and embed, a menu-bar extra, schedules, stats, bandwidth graphs, a light and dark variant of each skin, and a compact breakpoint. Looked at while scoping site and identity work, and left unscheduled.

### A permissively licensed replacement for the sign-in helper

The bundled YouTube sign-in helper (bgutil-ytdlp-pot-provider) is GPL-3.0, so the app ships it as a separate program with its licence text and source, and that is the only copyleft piece in the app. Its token generation is the MIT library `bgutils-js` (https://github.com/LuanRT/BgUtils) plus `youtubei.js` (MIT). A small server and a yt-dlp plugin written on those two would be MIT and keep the app free of copyleft, at the cost of owning the upkeep when YouTube changes its checks. `yt-dlp-getpot-wpc` (MIT) is not a fit because it needs a visible browser. Decide when the app is sold or distributed more widely.

## Distribution

### Developer ID signing and notarization

The app is signed ad hoc, so the first launch needs Open Anyway in System Settings, Privacy & Security. Developer ID signing and notarization remove that step. They need an Apple Developer Program membership, which is not planned. The release workflow's sign step marks where they slot in, and the install steps in the README and on the product page are the user-facing text that changes.

### Weekly live-network check

A scheduled workflow that runs the built app against the real network once a week: the setup check, a download from a Creative Commons source, m4a and mp3 extraction, and a token request from the sign-in helper. It would report through GitHub's failure email and never block a release. The downloader updater is what keeps downloads working when a site changes, so this only adds an early warning.
