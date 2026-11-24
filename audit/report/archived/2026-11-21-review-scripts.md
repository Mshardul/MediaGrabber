# Review: `scripts/`

Source: `/code-review high`. Every item below was checked by reading the script. Items 1, 3, 4 and 6 were also reproduced by running the script locally; nothing was published or fetched.

## Confirmed

1. `release/derive-version.sh:5`, only the `release` event is handled. `release.yml` runs on a tag push, so `EVENT_NAME` is `push`: `EVENT_NAME=push REF_NAME=v0.1.0 scripts/release/derive-version.sh` prints `invalid version:` and exits 1. Only the manual dry run, which passes `INPUT_VERSION`, gets a version. `scripts/tests/test_derive_version.sh` covers the `release` event and not `push`.
2. `release/sign-update.sh:34`, `gh release view … >/dev/null 2>&1` failing for any reason is treated as "no earlier release". The workflow sets `GH_TOKEN` only on the publish step (`release.yml:139`), not the sign step, so on a runner `gh` cannot authenticate and every release after the first writes an appcast holding only the new item.
3. `release/publish-release.sh:27`, `gh release list --json databaseId` fails (`Unknown JSON field: "databaseId"`, reproduced) and `|| true` hides it, so a stale draft for the same tag is never removed.
4. `release-assets.sh:16`, `${base#*.}` strips only to the first dot. Reproduced: `release-assets.sh allowed 0.1.0` lists `ffmpeg-7.1.1.1.1.tar.xz`, `lame-3.100.100.tar.gz` and `shield-source-2.0.2.0.2.tar.gz`, and those are the public asset names.
5. `e2e/run.sh:1`, a stray `[ -n "$fixture_pid" ] && kill …` line sits above the shebang (the real cleanup is at line 19). The file runs through the caller's shell, and the stray line runs before `fixture_pid` is set.
6. `release/check-signature.sh:23`, under `set -euo pipefail` a `grep` with no match aborts at the assignment. Reproduced with an appcast item that has a version and no signature: exit 1 with no message.
7. `fetch-tools.sh:107`, the Shield server is rebuilt only when `main.js` or `node_modules/express` is missing, and the ffmpeg stamp covers only the ffmpeg checksum, so bumping `shield-source` or `lame` in `tools.lock` keeps the old build. Affects a developer's `Resources/`, not a fresh CI checkout.
8. Comment rule: stacked `#` headers in `release/check-feed.sh`, `publish-release.sh`, `check-signature.sh`, `package-dmg.sh`, `sign-update.sh`, `verify-app.sh`, `verify-dmg.sh`, `release-assets.sh`, and a multi-line docstring in `e2e/fixture-server.py`.

## Not findings

- `privacy-text.py:15`, the link rule runs before the image rule, so `![alt](url)` would become `!alt`. `PRIVACY.md` has no images, so nothing is affected today.
- `sign-app.sh:45`, the Share Extension is not re-signed. The app has no entitlements file (only the extension does), and the sign step is marked in the project notes as where a real Developer ID will slot in, so nothing is wrong with an ad hoc build.
