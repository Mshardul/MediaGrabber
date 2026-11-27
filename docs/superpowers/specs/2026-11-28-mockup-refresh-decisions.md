# Mockup refresh: decisions

Visual rules are also written into `docs/design-system.md` as each screen is settled. Base plan: `docs/superpowers/plans/2026-10-22-media-grabber-mockups-rebuild.md`; where the two differ, this file applies.

## Goal

- Mockups show the finished app, taking the best of current screenshots, tickets and old mockups.
- Gaps become tickets: bugs, improvements, features.

## Sources

- `docs/design-system.md` holds design decisions; mockups are its HTML form. On a mismatch the mockup is wrong.
- The old plan's decisions stand unless listed here or under Stale.
- Screenshots: `screenshots/1795813054/` (full run); newer onboarding in `screenshots/1795814142/`; newest run `screenshots/1795819906/` (alerts).

## Mockup build

- `docs/mockups/screens.html` is the front page: it links to every screen by name. Each screen appears only on its area page in `docs/mockups/screens/`, whose top menu links to the front page and the other areas.
- Jinja templates, shared styles and sample data.
- All styling comes from common CSS files: pages carry no style blocks, style attributes, or literal colours or sizes.
- Old mockup files are updated or rewritten, whichever is less work, and no old copies are kept.
- Build plan: `docs/superpowers/plans/2026-11-28-mockup-refresh-build.md`. It builds what is locked; unreviewed screens follow once decided (replaces "decide all first").
- Screen order: Home, playlist, table, chrome, dialogs, onboarding, preferences, about, column interactions.

## Stale in the old plan

- The `stale/` folder step.
- First-run Home and Aurora body face marked as undecided: both shipped.
- Homebrew onboarding states: tools ship inside the app (mg-199).
- Status column visible by default; separate Remark-era default columns.
- Banner and toast states; chrome rules built on a separate brand row and old chips.
- One icon sprite with the code's current icons: icons are per theme (design-system §3.4, mg-215).
- Developer page shows GitHub only.
- Old paths under `apps/media-grabber/`; phase references.

## App-wide

- Buttons: one size and style scale (mg-211).
- Icons replace text where meaning stays clear; playful in Tape Deck, restrained in Aurora (mg-215, mg-010).
- Popups: all restyled to match the app and each one checked, dropdowns first (mg-227).
- Popups: height capped, long lists scroll (mg-223).
- No bottom banner; health chips and their dialog replace it (see Chrome, mg-216).
- Alerts: bottom-right, slide in from the right, newest on top; timed or closed by hand (mg-217).
- Questions stay centred dialogs.
- Saved-file, playlist and screen-reader alert tickets apply to the new alerts (mg-072, mg-104).

## Home

- After a check: two cards. Field keeps link and title; second card holds choices and Grab (mg-228).
- Each choice has a small label, or an icon where clear; no dots (mg-228).
- Type and audio format are segmented controls (mg-037).
- Playlist link: item count and `Grab all N` (mg-207).
- Planned details are drawn and marked as planned: size, length, file name, picture (mg-085, mg-086, mg-088, mg-092).
- No YouTube check suggestion; the chip and the failed-check link offer setup (mg-208).
- Try again only when retrying could help (mg-229).
- Enter passcode uses an app button (mg-209).
- Settled from tickets: Grab sizing and picker popover (mg-021), no empty rail on first run (mg-008), Share tip wording (mg-076), drop highlight (mg-023).

## Playlist

- Picker opens only from `Grab all N`, after choices are set (mg-207).
- Picker rows: flat with hairlines, 560pt card (mg-014); size per video and total drawn as planned (mg-089).
- While filtering: `Select all shown`, `Select none shown`, footer adds count shown (mg-230).
- Group: spine, indent, three-state checkbox (mg-019); counts by state, zeros hidden (mg-146).
- `Restart failed` wording (mg-031); Restart on every failed video (mg-067).

## Table

- Three-dot menus: video rows list video-level actions, playlist headers list group-level actions; enabled or disabled by status (mg-213, mg-019).
- Quality: downloaded value only, dash until known; no arrow (mg-214).
- Actions menu opens a small toolbar of icon buttons with hover labels (mg-213).
- Status: a distinct icon per status; Status column hidden (mg-233).
- Default columns: Title, Progress, Speed, ETA, Quality, Size, menu; fit without scrolling (mg-083, mg-231).
- Picture beside the title, hideable (mg-087); Video or Audio as an icon by the title.
- Selection actions sit in the Columns button row; all shown, disabled when not offered (mg-234).
- Title filter is a search box (mg-070); failure reason on hover and focus.
- Settled from tickets: filter popovers with clear, live checkmarks, anchored and themed (mg-198, mg-205, mg-203, mg-204); header grip, dividers, resize and reorder (mg-017); status labels, progress bars, plain failure text, live countdown (mg-018, mg-063); Restart on every failed row (mg-067); Destination filter (mg-144); Esc clears selection (mg-069).
- Bugs filed: cut-off headings (mg-231), blank title (mg-232).

## Empty states and the oracle orb

- Rules, moods and where each shows: design-system §4.2.5 (mg-020, mg-236, mg-237).
- Concept: an oracle's orb that holds everything, "whatever you need". Professional in Aurora, funky in Tape Deck; no cassette or other Tape Deck object.
- On empty tables, first launch and onboarding. All five moods kept.
- Many different media symbols float inside; true 3D movement with the pointer over the whole surrounding area.
- Prototype (the visual reference): `docs/mockups/explore/orb.html`. `empty-states.html` (option 4 chosen) and `tape-deck-empty.html` (rejected) are history.

## Logo

- Open for discussion: today's logo is styled for Aurora. It should match both themes, with 2D and 3D forms and the shapes and sizes each use needs (mg-238). Replaces the earlier rule of one identical logo in every theme once decided.

## Chrome

- Four always-visible chips: Connection, YouTube & sign-in, Tools, Storage (mg-244).
- Levels: Blocked, Problem, Warning, Healthy, each its own shape and colour (mg-210). Issue list: design-system §4.1.
- Alerts only for Blocked and Problem, and again when fixed (mg-216).
- New detection: app update available (mg-245); full disk or unusable folder early (mg-246).
- Title bar: logo and navigation in the macOS title bar, window buttons kept, chips on the row below (mg-029).
- Logo: progress ring in the chosen theme and palette gradient, never an issue colour; no ring when idle; click goes Home, triple-click opens the orb view (mg-247, mg-239). Mockup: `docs/mockups/explore/titlebar.html`.
- A chip opens a centred dialog: all its issues and warnings, right-aligned actions, by severity then newest first (mg-243).
- A cleared problem raises a new alert; earlier alerts are not edited (mg-216).
- Every alert sits 16pt from the right edge, whatever its length (mg-242).
- Cooldown and site wording is plain and true (mg-240, mg-241).
- A healthy chip's dialog says everything there is working (mg-243).
- Popups restyled include the passcode and setup panels (mg-227).

## Preferences

- One row layout: consistent labels, fixed control column, shared control sizes (mg-212).
- Toggle off state readable in Aurora (mg-218).
- Privacy is a formatted page (mg-219).
- Steppers show the value once (mg-224).

## About and Developer

- About: redesigned visual page (mg-220).
- Developer: visual page with profile links, `https://mshardul.github.io`, the repository's GitHub Pages project page and a growable app list (mg-093).

## Onboarding

- App tour after fresh install or update: low priority, not designed yet (mg-235).

## Hidden orb view

- Triple-click on the top-left logo (or a similar gesture) opens a trippy rotating-orb view, in-app or full screen; low priority, not designed yet (mg-239).

## Outside the app

- Rewrite the README (mg-221) and redesign the product page on GitHub Pages (mg-222).

## Screenshot tool

- Run folder: start time, then theme, `flow-` and `scene-` parts for options passed (mg-225).
- No theme subfolders; every image name ends with its theme, e.g. `home-video-aurora.png` (mg-225).
- `.DS_Store` is ignored (mg-226).

## How we review

- All of one screen's questions in one message. Question ids continue; never reused.
- Each question: id, question, description, options, recommendation.
- Clickable references first (files alphabetical, browser links for mockup pages); each question names its screenshot or mockup.
- Each decision is checked against tickets.

## Unconfirmed calls (proposed, not explicitly approved)

- Orb: rings and orbiting lights; mood priority drag, Searching, Clouded, then Waiting or Resting.
- Orb question 33 (do both styles feel right?) never answered outright; changes were asked for instead.
- Logo ring: hidden when idle; combined progress of all downloads (unknown sizes undefined). The orb still spins while downloading.
- Ring looks thin beside the Tape Deck logo outline.
- mg-029 points: 2 today, suggested 5.
- Priority and points on rows filed 2026-11-28 are suggestions.

## Still open

- Not yet reviewed: dialogs, onboarding, preferences, about and developer, column interactions. Next question id: 52.
- Logo design itself (mg-238).
- Prototype URL-input fix applied; its hostile-link browser test is unconfirmed.

- Remove `.DS_Store` files git already tracks (user's git command).
- Wording of the saving-failed dialog for each cause (from the old plan).
- Design-system entries for decisions on screens not yet reviewed.
