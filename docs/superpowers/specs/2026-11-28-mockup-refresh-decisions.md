# Mockup refresh: decisions

Visual rules are also written into `docs/design-system.md` as each screen is settled. Base plan: `docs/superpowers/plans/2026-10-22-media-grabber-mockups-rebuild.md`; where the two differ, this file applies.

## Goal

- Mockups show the finished app, taking the best of current screenshots, tickets and old mockups.
- Gaps become tickets: bugs, improvements, features.

## Sources

- `docs/design-system.md` holds design decisions; mockups are its HTML form. On a mismatch the mockup is wrong.
- The old plan's decisions stand unless listed here or under Stale.
- Screenshots: `screenshots/1795823477/` (full run, both themes). Earlier runs were deleted.

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

- Buttons: one size and style scale (mg-211). Confirmed on the mockups (design-system §3.5): heights 44 (a screen's main action), 34 (standard) and 28 (rows, toolbars, alerts); styles main, standard, destructive and text-only; icon-only buttons square.
- Buttons and pickers are 184pt wide and never follow the label.
- Alerts are 360pt wide, with any action under the text.
- Alerts start with the health level mark; a cleared problem and a saved download use the Healthy check.
- Icons replace text where meaning stays clear; playful in Tape Deck, restrained in Aurora (mg-215, mg-010).
- Popups: all restyled to match the app and each one checked, dropdowns first (mg-227).
- Popups: height capped, long lists scroll (mg-223).
- No bottom banner; health chips and their dialog replace it (see Chrome, mg-216).
- Alerts: bottom-right, slide in from the right, newest on top; timed or closed by hand (mg-217).
- Questions stay centred dialogs.
- Saved-file, playlist and screen-reader alert tickets apply to the new alerts (mg-072, mg-104).

## Home

- Home rail: Grab above a divider, then All, Downloading, Done, Inactive; shown from first launch. Home opens on Grab.
- Grab view: one centred column of orb, headline, field and, on first run only, the steps; no kicker line. The headline is the orb's message.
- After Grab, stay on the Grab view with the field cleared.
- Share, Services and app links open Grab. A detected copied link never switches views; away from Grab it raises an alert with an open button. Its wording, mark and timing are open.
- Tickets: Grab view (mg-277), table views without the field (mg-278), opening Grab for pasted or dragged links (mg-279).
- Table views have no paste field. ⌘V outside a text field, or a dragged link, opens Grab and checks it; no add button.
- Passcode: the dialog opens by itself; after Cancel the reason and Enter passcode remain.
- After a check the orb is hidden (for now).
- The choices card is never more than one row.
- After a check: two cards. Field keeps link and title; second card holds choices and Grab (mg-228).
- Each choice has an icon inside its control; no dots (mg-228).
- Choices card is one row: Type a narrow icon dropdown; Format, Language and Save to equal shares; Grab 120pt. At narrow widths those three drop their icons and Grab is 104pt. File name, size and length sit in the top card under the title.
- Type is a dropdown; audio format is a segmented control (mg-037).
- Playlist link: item count and `Grab all N` (mg-207).
- Planned details are drawn and marked as planned: size, length, file name, picture (mg-085, mg-086, mg-088, mg-092).
- No YouTube check suggestion or setup link (mg-208, mg-257).
- Try again only when retrying could help (mg-229).
- Enter passcode uses an app button (mg-209).
- Settled from tickets: Grab sizing and picker popover (mg-021), Share tip wording (mg-076), drop highlight (mg-023).

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
- The orb follows the chosen palette; the logo keeps its fixed colours.
- Many different media symbols float inside; true 3D movement with the pointer over the whole surrounding area.
- Prototype (the visual reference): `docs/mockups/explore/orb.html`. `empty-states.html` (option 4 chosen) and `tape-deck-empty.html` (rejected) are history.

## Logo

- Until then the mockups draw logo 4. Open for discussion: today's logo is styled for Aurora. It should match both themes, with 2D and 3D forms and the shapes and sizes each use needs (mg-238). Replaces the earlier rule of one identical logo in every theme once decided.

## Chrome

- Four always-visible chips: Connection, YouTube & sign-in, Tools, Storage (mg-244).
- Levels: Blocked, Problem, Warning, Healthy, each its own shape and colour (mg-210). Issue list: design-system §4.1.
- Alerts only for Blocked and Problem, and again when fixed (mg-216).
- New detection: app update available (mg-245); full disk or unusable folder early (mg-246).
- Title bar: logo and navigation in the macOS title bar, window buttons kept, chips on the row below (mg-029).
- Logo: the prototype's logo 4, 24pt, with a finish per theme; provisional until mg-238.
- Aurora title bar background: tinted with `--panel` over the body colour.
- Logo: progress ring in the chosen theme and palette gradient, never an issue colour; no ring when idle; click goes Home, triple-click opens the orb view (mg-247, mg-239). Mockup: `docs/mockups/explore/titlebar.html`.
- A chip opens a centred dialog: all its issues and warnings, right-aligned actions, by severity then newest first (mg-243).
- A cleared problem raises a new alert; earlier alerts are not edited (mg-216).
- Every alert sits 16pt from the right edge, whatever its length (mg-242).
- Cooldown and site wording is plain and true (mg-240, mg-241).
- A healthy chip's dialog says everything there is working (mg-243).
- Popups restyled include the passcode panel (mg-227).

## Dialogs

- One card for confirmation, notice, passcode and health chip dialogs (mg-227).
- Every dialog: type icon beside the title. Error = destructive, warning = something failed, info = the rest (mg-015).
- Health chip dialogs use the shared card with their most severe level mark as the icon; each action sits under its issue's text.
- Message is one line; wording shortened to fit (mg-015, mg-250).
- Title asks; message gives only the consequence (mg-250).
- Quit: one true line, no per-state sentences (mg-250).
- Cancel dialogs: `Keep downloading` / `Cancel downloads` (mg-250).
- Return presses the filled button, destructive included; Esc cancels. Replaces first focus on Cancel.
- Uninstall: count of unfinished downloads, no title list (mg-112).
- Remove: shows the count; says saved files stay (mg-251).
- Don't ask again: checkbox; single-row remove and cancel dialogs only; bulk remove always asks; Reset settings restores (mg-015, mg-252).
- Unreadable list: untimed alert; Storage problem if no copy was made (mg-255).
- No saving-failed dialog: Storage problem, alert, `Try again`; wording names the right place (mg-256). Replaces the old plan's notice.
- No missing-downloader dialog: onboarding and Tools chip; job-status document updated.
- App updates: own themed window (mg-253). macOS file pickers stay standard. Replaces "every popup" for system pickers only.
- Wording table: design-system §4.9.

## Preferences

- One row layout: consistent labels, fixed control column, shared control sizes (mg-212).
- Toggle off state readable in Aurora (mg-218).
- Privacy is a formatted page (mg-219).
- Steppers show the value once (mg-224).
- Downloader updates automatically, with a switch, after signed checking (mg-260, mg-157); privacy text corrected meanwhile (mg-261).
- Versions and update buttons move to the Updates pane; About shows only the app version (mg-262, mg-127).
- YouTube sidebar group removed; `Network & sign-in` group holds Network and Sign-in; General keeps Downloads and Appearance (mg-263).
- Automatic-update switch replaces the outdated-warning switch once it ships; outdated always warns. Warning switch stays until then (mg-260, mg-061).
- Logs merged into Diagnostics (mg-264).
- Speed limit: switch and typed number (mg-265).
- Proxy: format check, inline error, keep last valid (mg-266).
- Custom filename: insert buttons, example, reject invalid (mg-267).
- Diagnostics: technical rows under closed `Technical details`, included in copied report (mg-057).
- Player settings: Downloads, `After downloading` group (mg-090).
- Diagnostics bugs: stray lines and last-run time (mg-268), silent Update and Copy report (mg-269); retries helper untrue (mg-270).

## About and Developer

- About: short in-app product page, visually appealing (mg-220).
- `Included tools` and `Diagnostics` rows replaced by a Licenses link; `Report a problem` opens Diagnostics, which gets a report-form button (mg-271).
- `What's new` links to online release notes (mg-220).
- Menu `About MediaGrabber` opens the About page (mg-272).
- Developer: the developer's photo, supplied by them, bundled (mg-093).
- `Report a problem` on About; `Source code` and `License` stay on Developer.
- Profile links: GitHub, LinkedIn, portfolio, email. Project page link on About (mg-093, mg-220).
- Support and donation links later, once the accounts exist (mg-274).
- About has only blocks 1 (banner), 8 (open source, Licenses) and 10 (project page, report) (mg-220). Mockup: `docs/mockups/explore/about.html`.
- Usage information moves out of About to a separate page, and to other places where it matters (mg-275).
- Help: fourth top-bar item, also opened by the Mac Help menu; named `Help` (mg-275).
- Help content: how it works, what it can do, ways to add links, common questions, troubleshooting to Diagnostics and `Report a problem`; no status reference (mg-275).
- Also: privacy summary above the full statement (mg-219); first-launch hint on adding links (mg-276).
- Developer layout: centred (mg-093).
- Help: one page per sidebar item, not one scrolling page (mg-275).
- Help: ways to add a link merged into step 1 of How it works; four sidebar items (mg-275).
- Help: troubleshooting restyled as three numbered cards with standard buttons (mg-275).
- Help locked as drawn in `docs/mockups/explore/help.html`: layout, wording, top-bar order Home, Preferences, Help, About.
- No other apps for now; list filed for later, hidden while empty (mg-273).

## Onboarding

- YouTube check setup removed everywhere: step, panel, `Set up` actions; setup installs nothing (mg-257). mg-100 and mg-254 dropped.
- Missing check files = damaged copy; `Restart` stays for a stopped check.
- Shown on every fresh install while the test runs (mg-258).
- Centred orb, headline, one status line, buttons; no checklist (mg-258).
- `Continue` disabled while testing; after failure `Try again` and `Continue anyway` (mg-258).
- Damaged copy: `Download again` (download page) and `Check again`; points to the page; shows the version installed before the current one, if any (mg-129).
- Returning users get their own repair wording (mg-258, mg-129).
- Test run shows no progress today (mg-259).
- Orb approved in both themes with rings and lights; mood order: drag, Searching, Clouded, Waiting or Resting.
- App tour after fresh install or update: low priority, not designed yet (mg-235).

## Orb with downloads

- Exploring both: a checking animation and a Grab animation. With the large orb on the Grab view, revisit what each should be. No ticket until the design is agreed.

## Hidden orb view

- Triple-click on the top-left logo (or a similar gesture) opens a trippy rotating-orb view, in-app or full screen; low priority, not designed yet (mg-239).

## Outside the app

- Rewrite the README (mg-221) and redesign the product page on GitHub Pages (mg-222).

## Screenshot tool

- Run folder: start time, then theme, `flow-` and `scene-` parts for options passed (mg-225).
- No theme subfolders; every image name ends with its theme, e.g. `home-video-aurora.png` (mg-225).
- `.DS_Store` is ignored (mg-226).

## How we review

- Plans, tickets and the design system are open to discussion: recommend what is best for the app in the long run.
- All of one screen's questions in one message. Question ids continue; never reused.
- Each question: id, question, description, options, recommendation.
- Clickable references first (files alphabetical, browser links for mockup pages); each question names its screenshot or mockup.
- Each decision is checked against tickets.

## Unconfirmed calls (proposed, not explicitly approved)

- Preferences wording and details drafted, not approved: retries helper `Attempts before a download is marked failed.`; invalid custom filename rules.
- Priority and points on mg-260 to mg-270 are suggestions.
- Priority and points on mg-271 to mg-273 are suggestions; filing mg-273 for later was not asked for.
- About mockup copy, layouts and sample figures are drafts; priority and points on mg-274 are suggestions.
- mg-275: component `about`, priority and points are suggestions.
- First-launch hint text: draft. Priority and points on mg-276 are suggestions.
- Logo ring: hidden when idle; combined progress of all downloads (unknown sizes undefined). The orb still spins while downloading.
- Ring looks thin beside the Tape Deck logo outline.
- mg-029 points: 2 today, suggested 5.
- Priority and points on rows filed 2026-11-28 are suggestions (includes mg-250 to mg-259).
- Missing check files: Warning level with `Download again` in the YouTube & sign-in chip.
- Damaged copy offers no way into Home; onboarding headline and status wording not drafted.
- Dialog wording in design-system §4.9: drafted to fit one line, not read line by line by the user.
- Quit wording says downloads stay in the list (paused ones stay paused), and drops the pause reason.

## Still open

- Column interactions: questions 114-121 asked, not yet answered. Next question id: 123.
- Developer photo, link addresses and public email to come from the user.
- Dialog review used ids 50-64; the mockup build also used some of these for other questions (title bar background is its 54).
- Update window states and layout: not designed (mg-253).
- Logo design itself (mg-238).
- Prototype URL-input fix applied; its hostile-link browser test is unconfirmed.

- Remove `.DS_Store` files git already tracks (user's git command).
- Parent design spec still describes Homebrew steps (mg-199).
