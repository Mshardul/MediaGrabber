# Security review

Read-only review of helper, cookies, updater, logs, inbound links, uninstall. Each item checked in code; nothing run.

## Confirmed
- Helper port: `PotProviderProcess.swift:22` defaults to `AlwaysFreePortChecker`, and `DownloadEngineProtocol.swift:136` passes none, so the port is always 4416. Any 2xx from `/ping` there counts as the helper (`applyHealth`), with no check it is the app's own child.
- User-writable yt-dlp: `ManagedTools.swift:60` prefers `Application Support/.../bin/yt-dlp` when its version is higher, runs it with `--version`, and nothing records what the updater installed.
- Updater trust: `YtDlpUpdater.swift:165`, binary and checksum come from the same release, so authenticity is not proven.
- `sign-update.sh:20`: `find … | head -1` may pick a `sign_update` other than the pinned one.
- `release.yml:31`: checkout keeps credentials while `contents: write` and `npm ci` run in the same job.
- Inbound links: `mediagrabber://open?url=…`, Services and Share start a lookup at once (`IncomingLinkController.swift:33`). `PRIVACY.md` lists only paste and clipboard.
- yt-dlp URL has no `--` before it (`YtDlpArguments.swift:40`, `MetadataProbe.swift:145`). UI-origin links start with `http(s)://`; playlist entry URLs come from yt-dlp's JSON unchecked.

## No finding
- Cookies: only a `--cookies-from-browser` flag is built, logged as `<redacted>`, and the probe passes no cookies.
- Uninstall deletes a fixed path list. Sparkle feed is HTTPS with a public key.
- Log links in the clear are documented in `PRIVACY.md`.

## Not verified
- Helper server and plugin behaviour (third-party code), and what a listener on 4416 would receive.
