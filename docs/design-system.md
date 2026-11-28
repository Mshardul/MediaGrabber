# MediaGrabber — Design System

**Status:** draft, tracks §5 of the design spec **Date:** 2026-08-28 **Working name:** MediaGrabber (final name — Phase 13 / spec §14)

This is the source of truth for visual design. Mockups in `mockups/` mirror these values; if they disagree, this file wins.

---

- [1. Concepts](#1-concepts)
- [2. Themes](#2-themes)
  - [2.1 Tape Deck](#21-tape-deck)
  - [2.2 Aurora](#22-aurora)
- [3. Shared structure (theme-independent)](#3-shared-structure-theme-independent)
  - [3.1 Spacing scale (4pt)](#31-spacing-scale-4pt)
  - [3.2 Type scale](#32-type-scale)
  - [3.3 Motion](#33-motion)
  - [3.4 Iconography](#34-iconography)
- [4. Components](#4-components)
  - [4.1 App chrome](#41-app-chrome)
  - [4.2 Home](#42-home)
    - [4.2.1 States](#421-states)
    - [4.2.2 Paste field + runway](#422-paste-field--runway--the-hero)
    - [4.2.3 Downloads table](#423-downloads-table)
    - [4.2.4 Playlist group in the table](#424-playlist-group-in-the-table)
  - [4.3 Playlist picker (modal)](#43-playlist-picker-modal)
  - [4.4 Alerts](#44-alerts)
  - [4.5 Onboarding](#45-onboarding)
  - [4.6 Preferences](#46-preferences)
  - [4.7 Diagnostics](#47-diagnostics)
  - [4.8 About](#48-about)
  - [4.9 Dialogs](#49-dialogs)
  - [4.10 SkinnedSegment](#410-skinnedsegment)
  - [4.11 SkinnedPicker](#411-skinnedpicker)
  - [4.12 Help](#412-help)
- [5. Palette token sets](#5-palette-token-sets)
  - [5.1 Token list](#51-token-list)
  - [5.2 Tape Deck palettes (light)](#52-tape-deck-palettes-light)
  - [5.3 Aurora palettes (dark)](#53-aurora-palettes-dark)
- [6. Implementation notes](#6-implementation-notes)

---

## 1. Concepts

| Term | Meaning |
| --- | --- |
| **Theme** | Visual identity: **Tape Deck** or **Aurora**. Sets type, shape language, elevation style and the logo's finish. |
| **Palette** | A colour variant _within_ a theme. Three per theme. Swaps colour tokens only — type, radii, spacing and the logo are unchanged by palette. |

User picks a theme, then a palette. Default: **Aurora / Mint & Iris**.

Light/dark orientation is fixed per theme: **Tape Deck is light**, **Aurora is dark**. Every palette declares a complete token set on `:root[data-theme=…][data-palette=…]`.

---

## 2. Themes

### 2.1 Tape Deck

Warm, tactile, nostalgic hi-fi. Light-first.

| Axis | Value |
| --- | --- |
| Display face | **Bricolage Grotesque** 700 / 800 — headlines, wordmark, Go button |
| Body face | **DM Sans** 400 / 500 / 700 — UI text, table cells, field labels |
| Utility face | **DM Mono** 400 / 500 — chips, status pills, table headers, data, kicker |
| Border | 2px solid `--ink` on structural edges; 1.5px on chips / pills / small controls |
| Radius | window 14 · card 12 · control 8 · pill 20 · chip 6 (px) |
| Elevation | **hard offset shadow** — `8px 8px 0 rgba(0,0,0,.35)` on the window; controls get none |
| Header ground | `--brand` (the palette's deep hue), text in `--surface` |

### 2.2 Aurora

Luminous, calm, premium. Dark-first.

| Axis | Value |
| --- | --- |
| Display face | **Sora** 600 / 700 — headlines, wordmark, Go button, section headings |
| Body face | **IBM Plex Sans** 400 / 500 / 600 — UI text, table cells |
| Utility face | **JetBrains Mono** 400 / 500 — chips, status pills, table headers, data, kicker |
| Border | hairline — `1px solid --stroke` (a low-alpha white) on structural edges; `--hair` for table row rules |
| Radius | window 18 · card 14 · control 9 · pill 20 · chip 7 (px) |
| Elevation | **glow** — `0 0 0 1px --glow-a, 0 0 32px --glow-b` on the paste console; window uses a deep soft shadow `0 24px 60px rgba(0,0,0,.6)` |
| Header ground | title bar tinted with `--panel` over the body colour, plus the divider |

---

## 3. Shared structure (theme-independent)

Layout, spacing, iconography, copy voice, and component anatomy do **not** change between themes — only their surface styling does.

### 3.1 Spacing scale (4pt)

`4 · 8 · 12 · 16 · 22 · 30 · 44` px — tokens `--sp-1 … --sp-8`.

### 3.2 Type scale

| Role | Size / line-height | Notes |
| --- | --- | --- |
| Hero headline | 32 / 1.04, letter-spacing −.03em | display face, max ~18ch |
| Section heading (Preferences, Diagnostics) | 18 / 1.3 | display face |
| Onboarding headline | 26 / 1.05 | display face |
| Body | 13 / 1.6 | body face |
| Small / helper | 12 / 1.5 | body face, `--dim` |
| Kicker / eyebrow | 11, letter-spacing .16em, uppercase | utility face, `--accent` |
| Table header | 10, letter-spacing .08em, uppercase | utility face, `--dim` |
| Status pill / chip / data | 10–11 | utility face |

### 3.3 Motion

`--ease: cubic-bezier(.2,.7,.2,1)` · `--dur: 160ms` for state transitions. Spin animations are linear. **All animation is disabled under `prefers-reduced-motion: reduce`.**

### 3.4 Iconography

Icons replace text wherever the meaning stays clear: playful in Tape Deck, restrained in Aurora. An icon-only control keeps a spoken label and a hover label.

Icons are **bundled SVGs, one library per theme** — the only axis where the two themes draw from different sources:

- **Tape Deck → Phosphor Bold** (`@phosphor-icons/core`, MIT). Heavy filled-outline weight; matches the 2px borders.
- **Aurora → Lucide** (`lucide`, ISC). Clean 2px stroke; matches the hairline borders.

Within a theme every glyph comes from that one library — never mixed. Only the ~26 glyphs actually used are bundled (≈ 48 SVGs total across both themes), as an asset catalog. A `NOTICE` file credits both libraries.

**Rendering.** Each glyph is a template image tinted with the current context colour (`--text`, `--dim`, `--accent`, `--danger`, …). An `Icon` SwiftUI view takes a semantic case (`Icon(.pause)`), reads the active theme from `ThemeEnvironment`, and resolves the right asset. Nominal size 16px in dense spots (row actions, table headers, chips), 15px in nav, up to 20–22px in onboarding.

**Glyph set** (semantic name → Phosphor Bold / Lucide):

| Semantic             | Phosphor Bold        | Lucide             |
| -------------------- | -------------------- | ------------------ |
| pause                | `pause`              | `pause`            |
| resume               | `play`               | `play`             |
| cancel               | `x`                  | `x`                |
| force-start          | `arrow-line-up`      | `arrow-up-to-line` |
| retry                | `arrow-clockwise`    | `rotate-cw`        |
| retry-with-cookies   | `key`                | `key-round`        |
| reveal-in-Finder     | `folder-open`        | `folder-open`      |
| open-in-browser      | `globe`              | `globe`            |
| remove               | `trash`              | `trash-2`          |
| show-log             | `file-text`          | `file-text`        |
| sort-neutral         | `caret-up-down`      | `chevrons-up-down` |
| sort-asc             | `caret-up`           | `chevron-up`       |
| sort-desc            | `caret-down`         | `chevron-down`     |
| filter               | `funnel`             | `funnel`           |
| chip-refresh         | `arrows-clockwise`   | `refresh-cw`       |
| columns-menu         | `columns-plus-right` | `columns-3`        |
| disclosure-collapsed | `caret-right`        | `chevron-right`    |
| disclosure-expanded  | `caret-down`         | `chevron-down`     |
| copy                 | `copy`               | `copy`             |
| open-terminal        | `terminal-window`    | `square-terminal`  |
| step-done            | `check`              | `check`            |
| shield               | `shield-check`       | `shield-check`     |
| warning              | `warning`            | `triangle-alert`   |
| nav-home             | `house`              | `house`            |
| nav-preferences      | `gear`               | `settings`         |
| nav-diagnostics      | `stethoscope`        | `stethoscope`      |

A logo design for both themes, in 2D and 3D forms, is still open; until it is decided, the following applies. The logo is **not** in this set — it is `MotifView`, a drawn SwiftUI shape: one conic-gradient orb (`#5EF2C8, #8B7BFF, #FF7A6B, #5EF2C8`), with the same colours under every theme and palette and a finish per theme. Aurora: a soft glassy highlight, shaded edge and soft outer glow in the logo's own colours, the same on the title bar and on rows. Tape Deck: a thick ink outline, hard shadow and flat highlight. 24px in the title bar (6s spin while a download runs, inside the progress ring of §4.1), 14px on actively-downloading rows (2s spin).

The `warning` glyph is reused for the Preferences concurrency note (§4.6) — no new glyph is introduced for it.

### 3.5 Buttons

- **Heights** — 44pt for a screen's main action, 34pt standard (matching pickers and segments), 28pt for rows, toolbars, dialogs' lists and alerts.
- **Styles** — main (`--go-fill`), standard (`--panel` with a `--stroke` border), destructive (`--danger`) and text-only.
- **Width** — every text button and picker is 184pt wide, never sized to its label. Exceptions: the Home choices row (§4.2.2) and the Developer links (§4.8). Icon-only buttons are square at the same heights.

### 3.6 Centred pages

Every page laid out as one centred column (the Grab view, About, Developer, Help and later pages of the same kind) uses the same width: 760pt at most with 30pt padding each side, so 700pt of content in the default window. It narrows with the window. Cards in dialogs and the playlist picker keep their own widths.

---

## 4. Components

**Popups** (dropdowns first, then menus, filter lists, dialogs and panels) match the app in both themes. Popovers have a height limit and long lists scroll.

### 4.1 App chrome

- **Title bar** — the app extends into the macOS title bar and keeps the system's close, minimise and zoom buttons; the system title is hidden. It holds the wordmark (logo + name) on the left and, on the right, the nav (`Home · Preferences · Help · About`) as in-app page links; the active page gets a filled background (Aurora: `--panel-hi`, on the tinted bar; Tape Deck: `--panel`). Diagnostics is not a nav item — it is a Preferences pane (§4.6); Help (§4.12) and About (§4.8) are also top-level destinations. The health strip sits on the row below. The title bar is the only chrome that stays fixed regardless of page. Dragging and double-clicking its empty areas behave as in any macOS window, and it dims when the window is inactive.
- **Logo** — while anything is downloading, a ring around it shows overall progress, drawn in the chosen theme and palette gradient and never in an issue colour (Aurora: `--accent` to `--accent-2`; Tape Deck: `--go` to `--accent`, since its title bar is `--accent-2`). Only unfinished downloads count. Each gets an equal share of the ring; one whose progress is unknown counts as zero. No ring when nothing is downloading. One click goes Home; a triple-click opens the hidden orb view.
- **Left rail** — one persistent rail, same visual shell, sits below the health strip on every page; its _content_ changes with the active page while the rail's position, width, and row styling stay identical everywhere:
  - **Home** — **Grab** first, then a divider, then the status filters (§4.2.3: All · Downloading · Done · Inactive). Shown from first launch. **Grab** opens the Grab view (§4.2.1); each filter opens the table.
  - **Preferences** — the pane rail (§4.6).
  - **Help** — a section rail (§4.12); each row opens its own page.
  - **About** — the tab rail (§4.8: The Product / The Person). Selecting a rail row updates the app's current page state directly (e.g. `.preferences(.diagnostics)`), so the rail's own selection and the page's content can never drift apart.
- **Health strip** — below the brand row. One small utility-face chip per **issue category**. Every category chip is always visible, healthy or not, and its dot shows the most severe thing it holds.
  - **Issues dialog** — clicking a chip opens a centred dialog listing everything in that category, warnings included. Each entry says in plain words what is wrong and has its action buttons under that text, aligned right. Order: severity first, then newest first.
  - **Healthy** — a healthy chip's dialog says everything in that category is working. Cooldown and site wording is plain, true for any mix of paused and cooling sites, and free of technical terms.
  - **Actions** live in the dialog (restart the YouTube check, update the downloader, retry a paused site, and so on). While an action runs, its button and the chip show a busy state and cannot be pressed again (static under `prefers-reduced-motion`). A failed action raises an alert with the reason and the issue stays listed.
- **Problems** — there is no banner. A new **Blocked** or **Problem** issue raises one untimed alert (§4.4); when it clears, a new alert says so and the earlier one is not changed. Warnings raise no alert.
- **What counts as an issue** — all three: it affects the app or could affect several downloads; it lasts until something changes; the app can detect it. One failed download stays on its row; a one-off event is an alert; a decision is a dialog; advice (such as turning off a VPN) sits inside its issue.

| Level | Meaning | Mark |
| --- | --- | --- |
| Blocked | Affected downloads stop, and waiting on a known timer is not enough | Red stop sign |
| Problem | Something is broken; some downloads may fail or work less well | Orange triangle |
| Warning | Nothing is broken, or the app is already recovering | Yellow information circle |
| Healthy | Nothing to report | Green check |

Each level differs in shape and colour. Its colours are their own tokens, apart from the palette accent. A chip shows its most severe level; the dialog lists each affected site separately.

| Chip | Issue | Level | Action |
| --- | --- | --- | --- |
| Connection | Offline | Blocked | Check again |
| Connection | A site paused after repeated limits | Blocked | Retry now |
| Connection | A site cooling down | Warning | none; countdown |
| Connection | A site's downloads running one at a time | Warning | none |
| YouTube & sign-in | YouTube check stopped | Problem | Restart |
| YouTube & sign-in | Browser needs permission | Problem | Open System Settings |
| YouTube & sign-in | Chosen browser has no usable profile | Problem | Choose browser |
| YouTube & sign-in | YouTube check missing from this copy | Problem | Download again |
| YouTube & sign-in | YouTube check restarting | Warning | none |
| Tools | Downloader or main media tool missing | Blocked | Fix setup |
| Tools | Tool that checks finished files missing | Problem | Open Diagnostics |
| Tools | Downloader outdated | Warning | Update |
| Tools | App cannot update from its current folder | Warning | Move to Applications |
| Tools | App update available | Warning | View update |
| Storage | Disk full | Blocked | Show folder |
| Storage | Download folder missing or not writable | Blocked | Choose folder |
| Storage | List, history or column layout cannot be saved | Problem | Try again |

### 4.2 Home

Behavioural contract in spec §5.3. Home has two views, chosen on the rail: the **Grab view**, where links are added, and the **table views**, one per status filter (the Downloads table and the playlist group). Home opens on the Grab view.

#### 4.2.1 States

- **Grab view** — one centred column beside the rail: the orb (§4.2.5), the headline “One link in. One file out.” as its message, and the paste field. There is no line above the headline. While a link is checked the orb searches. After a successful check the orb is hidden and the runway appears under the field. After **Grab** the view stays, with the field cleared for the next link.
- **First run, no download ever made:** the Grab view also shows a **horizontal numbered strip** (“Paste a link · Pick a format · Press Grab”) at the bottom of the column.
- **First-run hint:** “You can also drag a link in.” Sharing from other apps is left to the Share tip.
- **After the first Grab:** the strip is gone permanently.
- **Table views** — the Downloads table with its toolbar, using the full height. There is no paste field or runway.
- **Adding from a table view** — ⌘V outside a text field, or dragging a link onto the window, opens the Grab view and checks the link. There is no separate add button.
- **Other incoming links** — a link sent on purpose (Share, the Services menu or an app link) opens the Grab view and checks it, from any page. A detected copied link never changes the view: away from the Grab view it raises an alert with a button that opens it.
- **Table emptied later** (user removed every row): the empty-table state of §4.2.5. The strip does **not** return; it is first-run-only.

#### 4.2.5 The oracle orb: empty and welcome states

The orb holds everything: "whatever you need". A large animated 3D orb appears on empty tables, first launch and onboarding, each with a message and, where useful, actions.

- **Colours** — the orb follows the chosen palette; highlights and cloud greys stay neutral.
- **Styles** — Aurora: glass, slow inner light, glowing rim. Tape Deck: thick ink outline, flat colour, dot shading, hard shadow, sparkles, motion stepped at 12 frames per second.
- **Contents** — many different media symbols floating at different depths inside, behind the glass; two rings and small lights circle it.
- **Pointer** — it turns and leans towards the pointer in true 3D, tracked across the whole surrounding area.
- **Quiet** — still under Reduce Motion; hidden from VoiceOver, which reads the message; animation stops while the window is not visible.
- **Table headings** show only when column filters cause the empty result.
- **Empty rail views** share one layout: orb, heading, message and one button, with no paste field or Columns button row. **Grab a link** opens the Grab view. A view emptied by column filters keeps the table headings and offers **Clear filters** instead.

| View | Heading | Message | Button |
| --- | --- | --- | --- |
| All | No downloads yet | Everything you grab is listed here. | Grab a link |
| Downloading | Nothing is downloading | Downloads in progress show up here. | Grab a link |
| Done | Nothing saved yet | Finished downloads show up here. | Grab a link |
| Inactive | Nothing needs attention | Failed and cancelled downloads show up here. | Grab a link |
| Filtered | No downloads match | Your column filters hide every download here. | Clear filters |

| Mood | Meaning | Shown on |
| --- | --- | --- |
| Waiting | Give me a link | The Grab view, onboarding, no downloads at all |
| Resting | Nothing here right now | Empty Downloading, Done and Inactive views |
| Clouded | Something is in the way | Filters matching nothing; a failed link check, failed or damaged-copy onboarding or being offline while the large orb is visible |
| Searching | Working on it | Checking a link in the Grab view; the onboarding test run. The inside, symbols and rings speed up and a bright point sweeps the rings |
| Link dragged over | Ready to catch it | Any screen with the large orb, during the drag |

When more than one applies: Link dragged over, then Searching, then Clouded, then Waiting or Resting.

#### 4.2.2 Paste field + runway _(the hero)_

The "resolve link & arm Grab" pattern.

- **Field** — full-width card (`--panel`). Rounded on all corners. Holds the pasted URL, which stays visible after a check, with a clear button at its right end. After a successful check, a second line shows the page picture, `✓ <title>` (or `✓ "<playlist>" · N items`) and, under the title, the file details. On a failed check: `--danger` text with the reason, inside the same card below the input, with **Try again** only when retrying could help.
- **Passcode** — when a check needs one, the passcode dialog (§4.9) opens by itself. **Cancel** leaves the reason in the field card, with **Enter passcode**, an app button aligned with that text, to open it again.
- **Dragging a link** over the window shows a drop highlight in the accent colour at the card radius.
- **Share tip** — says "from any app" and may wrap to two lines.
- **No YouTube check prompt** — Home shows no separate suggestion, and a failed check offers no setup action. The YouTube check ships with the app and has no setup anywhere; the health chip reports a problem with it (§4.1).
- **Details before Grab** — the page picture beside the title; the file name this grab will write, saying when it is already in the folder; and the approximate size and length for the current choice.
- **Runway** — **hidden until a pasted link resolves.** When shown, it is a **separate full-width card** (`--panel-hi`) below the field, with `--sp-3` gap between the two — not a shared border. Rounded on all corners. **Always one row.** Each choice carries an icon inside its control. Type is a narrow fixed-width dropdown showing only its icon; Format, Language and Save to take equal shares of the remaining width, whatever their text, and show a cut-off value in full on hover; Grab is 120pt wide. At narrow widths Format, Language and Save to drop their icons and Grab narrows to 104pt. These widths are the exception to §3.5. The choices:
  - `Type` — `SkinnedPicker` (§4.11) — Video / Audio; seeded from last-used or Preferences
  - `Format` — contextual: `SkinnedPicker` (§4.11) quality rungs this probe actually offers (video), or `SkinnedSegment` `M4A` / `MP3` (audio); seeded from last-used or Preferences
  - `Language` — `SkinnedPicker` of this probe's audio tracks; always filled (last pick if offered, else Preferences YouTube-default / Original policy, else YouTube's default track). Shown for Video and Audio.
  - `Save to` — `SkinnedPicker`: default folder, last-used (if distinct), "Choose…" for a new folder. Always seeded — never renders unfilled.
  - _(playlist only)_ no extra slot — item selection happens in the picker modal (§4.3)
  - The slots use `SkinnedSegment` / `SkinnedPicker`, not the native `Menu`.
- **Grab button** — at the end of the runway, past a divider. Type, Format, Language, and Save-to are always pre-filled; the user may change any of them before Grab. Label: `Grab` (single item) / `Grab all N` / `Add N` (after picker). Theme fill: Tape Deck `--go` solid; Aurora `--go-fill` gradient.

#### 4.2.3 Downloads table

One table, newest at top. One **row per video** (a playlist contributes N rows, grouped — §4.2.4). Product contract for status / rail / actions: `docs/job-status-and-actions.md`.

**Layout:** the shared **left rail** (§4.1) + table body (not top filter chips), with no paste field above it.

- **Rail** — `All · Downloading · Done · Inactive`. Inactive shows a count badge when > 0 (failed + cancelled). Mapping: Downloading = probing, running, queued, paused, waitingForNetwork, cooldown; Done = completed; Inactive = failed, cancelled.
- **`⊞ Columns` button** — opens a list of columns in the current order, each with a checkbox. Rows can be reordered there by dragging or by keyboard. **Reset columns** sits at the bottom (Preferences → Advanced keeps its own reset).
- **Hidden rows** — while any column filter is active, the Columns-button row shows how many rows are shown (such as "2 of 40 shown") and **Clear filters**, beside any selection actions.

**Columns:** one active sort at a time. Clicking a column's name cycles ascending → descending → off; there is no separate sort button. Only the sorted column shows an arrow (sort-asc or sort-desc, §3.4) beside a brighter name; any other sortable name shows a faint arrow on hover. The normal order is newest first (by **Added at**, hidden or not), and turning a sort off returns to it. **Status** kept but **hidden by default** (rail is the everyday filter); labels are the nine `JobState`s 1:1 (plain aliases). Detail → Remark.

| Column | Default | Hideable | Reorderable | Sort | Filter |
| --- | --- | --- | --- | --- | --- |
| Title | ✓ visible | no | yes | yes | yes (text) |
| Status | hidden | yes | yes | yes | yes (checklist) |
| Progress | ✓ visible | yes | yes | yes | — |
| Speed | ✓ visible | yes | yes | yes | — |
| ETA | ✓ visible | yes | yes | yes | — |
| Type | hidden | yes | yes | yes | yes (checklist — Audio / Video) |
| Quality | ✓ visible | yes | yes | yes | yes (checklist — 1080p / 720p / … / m4a / mp3) |
| Size | ✓ visible | yes | yes | yes | — |
| Site | hidden | yes | yes | yes | yes (checklist) |
| Remark | hidden | yes | yes | yes | — |
| Added at | hidden | yes | yes | yes | — |
| Finished at | hidden | yes | yes | yes | — |
| Duration | hidden | yes | yes | yes | — |
| Destination | hidden | yes | yes | yes | yes (checklist) |
| Attempt | hidden | yes | yes | yes | — |
| Client used | hidden | yes | yes | yes | yes (checklist) |
| **Actions** | ✓ visible | **no** | **no (pinned last)** | — | — |

- **Column headers are draggable** to reorder (except Actions, pinned last).
- **Fixed while scrolling sideways:** the checkbox and Title at the left and Actions at the right; the other columns scroll between them. In a narrow window Title keeps a minimum width (260pt), so the table scrolls sideways instead of squeezing it.
- **Hiding a column** clears its filter and any sort chosen on it. The default Added at order is not cleared.
- **Dragging rows** changes only the view, until the app closes; it does not change download order. It asks to clear sorting only when a sort has been chosen.
- Quality sorts by resolution, not as text.
- Column order, visibility, **widths**, and the active sort column + direction **persist** as a `ColumnConfig`; filters are cleared when the app reopens. They are held in `columns.json` (separate from `Preferences`; see spec §4). Checkbox column is not a `ColumnID` — fixed width, not in `columnWidths`.
- A column whose data source is not yet populated (`Attempt`, `Client used`) shows an em-dash and still sorts; a checklist filter with only a "(none)" option is allowed.
- Nil values always sort **last**, regardless of direction.
- There is **no "Playlist" column** — a playlist's membership is shown by the group header + indented child rows + spine (§4.2.4), not a column.
- No per-row expansion. No detail view. The Actions column remains the primary per-row interaction model and stays visible while a multi-select is active.
- **Default columns fit** the default window without sideways scrolling, with full headings and values.
- **Selection column** (leading, fixed width, not a `ColumnID`) + ⌘-click / Shift-click over visible child order; header checkbox selects all currently visible children.
- **Selection actions** use the Columns-button row, so table rows never move: `N selected`, every video-level action as an icon (enabled when any selected row offers it, per `job-status-and-actions.md` §8), and Clear. Shown only while rows are selected. Not a floating footer.
- **Grid substrate:** AppKit draws headers and body cells with shared palette / type / spacing tokens (`DownloadsGridTokens`). SwiftUI owns shell outside the grid (rail, batch bar, Columns menu). Do not default to `NSHostingView` per cell.

**Headers and filters:** header cells show a drag grip, a filter button and resize dividers. A column with an active filter has the same bright name as a sorted one and its filter button filled with `--accent`; the two states differ only in which icon is on (sort arrow, filled filter button), and a column can show both. A filter popover opens against its own header, uses the theme, updates its checkmarks while open and has a clear action for that column, labelled **Clear filter**. The Title filter is a search box. The Destination filter matches the folder name it lists. Esc clears the selection. **Restart** is offered on every failed row.

**Status and progress:** status labels and progress bars use the state colours; failure text is a plain sentence with a next step, shown on hover and keyboard focus, with the downloader's raw text only in the row's Log action; countdowns tick.

**Cell treatments:**

- _Title_ — in order: status icon, page picture (on by default, hideable from Columns), title, and a Video or Audio icon. The status icon differs in shape and colour per status, names it on hover and to VoiceOver, and is the motif spinner on an actively-downloading row; a row with no title yet shows its link; playlist children indented with the spine connector (§4.2.4); full title as hover tooltip when truncated.
- _Remark_ (optional column / hover+focus) — queue `#N`, backoff / host rate, failure reason sentence — never invents a second status vocabulary.
- _Status_ (optional column) — plain 1:1 label only; never free text.
- _Progress_ — thin bar on every unfinished row that has made progress and can continue: `--bar-fill` while downloading, grey when not moving (paused, waiting for network, cooling down, queued again). Blank otherwise, failed and cancelled rows included.
- _Speed_, _ETA_ — utility face, `--dim`; blank on non-running rows.
- _Type_ — `Audio` / `Video`. _Quality_ — what was actually downloaded (`1080p` … or `m4a` / `mp3`), never the requested value or an arrow; a dash until it is known. Both `--dim`.
- _Size_ — known total; `--dim`; em-dash until known.
- _Site_ — utility face, `--dim`.
- _Actions_ — one three-dot button per row, opening a small toolbar of icon buttons (glyphs per §3.4), each with a hover label. It holds every video-level action in `job-status-and-actions.md`; those not offered in the current state are disabled.

#### 4.2.4 Playlist group in the table

- **Group header row** — spans the table above the playlist's videos. Contains, in order: a three-state checkbox in the table's checkbox column, a disclosure caret (collapses/expands the whole group), the playlist name, a rollup (item count, counts of done, failed, cancelled and in progress with zeros hidden, and a mini progress bar), and a three-dot menu that opens a dropdown list, each action with an icon and its name, holding the group-level actions (Pause all · Restart failed · Cancel all — see `job-status-and-actions.md` §3b), each enabled or disabled by what the group's videos allow. Video rows inside the group keep their own menu of video-level actions. Background `--accent-2` at low alpha. Show the group when any child matches the selected rail.
- **Child rows** — the playlist's videos, indented. A single **continuous vertical spine** runs down the left at the indent position. Each child has a short horizontal connector from the spine to its content.
- **Row divider lines between children start _after_ the spine** (indented to align with content) — they never cross it, so the spine reads as one unbroken line.
- **Collapsed** — children hidden; the header row remains, showing the rollup only.
- This is a grouping row, not a detail view. Nothing expands per video.

### 4.3 Playlist picker (modal)

Opens from **Grab all N**, after the choices on Home are set, and **before** any rows are added. It never opens on its own.

- **Header** — "Choose videos to download" + `<playlist> · <site> · by <uploader> · N items`.
- **Banner** (when this playlist is already in the queue) — "This playlist is already in your queue."
- **Tools row** — `Select all` / `Select none` buttons; a filter-in-playlist text field (right). While a filter is active they read `Select all shown` / `Select none shown` and change only the shown videos.
- **List** — scrollable, one row per video: checkbox · thumbnail · title (truncates) · duration · approximate size when known · optional **In queue** / **Already saved**. Whole row toggles.
- **Card** — 560pt wide; rows are flat, separated by hairlines.
- **Defaults** — all checked except warned rows (those start unchecked). Select all can still check them. Checks are not remembered the next open.
- **Footer** — the count line takes the full width, with `Cancel` · `Add M` right-aligned on the row below. The line is live: `M of N selected · K already in queue · ≈ H:MM:SS` (sum of known durations among checked; omit K when 0), plus the total approximate size of checked videos when known, and `S shown` while filtering. `Add M` is primary and disabled at 0. Never an invented size.
- Only checked videos become table rows (as the group in §4.2.4). Unchecked are not added and not remembered.

### 4.4 Alerts

- **Bottom-right**, sliding in from the right and stacked, **newest on top**. 360pt wide: one line of text, with an optional action under it; every alert can be closed by hand.
- **Level mark** — each alert starts with the mark of §4.1: the issue's level, or the Healthy check for a cleared problem and a saved download.
- **Timed** alerts hide themselves after about 4s. **Untimed** alerts stay until closed by hand.
- Every alert sits 16pt from the window's right edge, whatever its length.
- A playlist raises one summary alert and one summary notification, not one per video. VoiceOver announces each new alert once.
- **Unreadable download list** — its alert is untimed, with **Show copy** or **Show file**. When no copy could be made, Storage also lists a Problem while changes go unsaved.
- **Failed saves** — a Storage Problem with **Try again** and its alert; there is no separate dialog. The wording names the true cause and place: the list, history and column layout are kept in the app's data, not the download folder.
- **Questions are not alerts** — anything that needs an answer stays a centred dialog (§4.9).
- Fire for: **download successes** (`<title> saved` + `Reveal`, timed), **a failed fix from a chip's issues dialog** (the reason), and **a new Blocked or Problem issue, and again when it clears** (untimed; §4.1). Warnings raise none.
- **Per-job download failures raise no alert.** They surface via row treatment + the Inactive rail badge.
- While the app is **backgrounded**, a failure fires a **native macOS notification** (not an alert).

### 4.5 Onboarding

A full-window takeover with no navigation, health chips or rail. The downloader, media tools and YouTube check ship inside the app, so there is nothing to install.

**Layout:** the large oracle orb (§4.2.5) centred, then a headline, one status line and the buttons. There is no step list.

**When it appears:** on every fresh install, and again whenever a required tool is missing. The test run (a check of a known video) starts by itself.

| State | Orb | Content |
| --- | --- | --- |
| Testing | Searching | Status says the app is being checked. **Continue** is disabled. |
| Passed | Waiting | Status says everything works. **Continue**. |
| Test failed | Clouded | Plain reason. **Try again** and **Continue anyway**. A retry returns to Testing. |
| Damaged copy | Clouded | Says this copy of the app is damaged and points to the download page. Shows the version installed before the current one, if there was one. **Download again** and **Check again**. First-time users have no way into Home. |

**Returning users** (a required tool went missing after onboarding was finished) see repair wording, with no first-run label. With a damaged copy they can also open Home, where their list and history stay available, downloading is blocked and the Tools chip (§4.1) shows why.

| State | Headline | Status line |
| --- | --- | --- |
| Testing | Welcome to MediaGrabber | Checking that the app works… |
| Passed | You're all set | MediaGrabber is ready. |
| Test failed | The check didn't pass | _the plain reason_ |
| Damaged copy, first time | This copy is damaged | Download a fresh copy from the download page. |
| Damaged copy, returning | MediaGrabber needs repair | Download a fresh copy. Your list is safe. |

When an earlier version is known, a second line reads “You had version _X_ before this one.” The returning user's button into Home reads **Open Home**.

Wording is plain: no tool names, commands or terminal output.

---

### 4.6 Preferences

- In-app page (nav item). Not a separate macOS Settings window.
- **Fixed window height.** The left rail (the app chrome's shared rail, §4.1) never scrolls (the window is tall enough for every rail item). The right pane scrolls independently — the pane's title, sub, and rule stay fixed above that scroll region; only the rows below them scroll, with their own bottom padding so the last row never sits flush against the window edge.
- **Left rail content** — group captions, each item highlighted when selected. There is no YouTube group.
  - **General:** Downloads · Appearance
  - **Network & sign-in:** Network · Sign-in & cookies
  - **System:** Updates · Privacy · Licenses · Advanced · Diagnostics
- **Right pane** — the selected pane. Two-column rows: `label` (13, `--text`, semibold) + optional `helper` (11.5, `--dim`) stacked on the left; control right-aligned; a `--hair` divider between rows. A row with no helper renders label-only. Pane title 20 / heavy in `--headline` with a rule under it, a one-line `--dim` sub above the rule.
- **One row layout** on every pane: consistent labels, a fixed control column and shared control sizes, with width limited to about 760pt and long folder paths truncated.
- The toggle's off state is readable in every palette. A stepper shows its value once. The Privacy pane is a formatted page with headings and lists.
- Diagnostics is a rail item here, not a top-level nav destination (§4.1) — it is a status/support tool a small share of users open, not a page most users need regularly.

Rows per pane (control → backing field on `Preferences`, unless noted):

**Downloads** — sub _"Defaults for new downloads. Change any of these per download on the Home screen."_

| Label | Helper | Control | Backs |
| --- | --- | --- | --- |
| Downloads folder | — | folder button `~/Downloads`, no chevron → `NSOpenPanel` | `defaultDownloadFolder` |
| Simultaneous downloads | Automatically reduced if a site rate-limits you. | stepper 1–6 | `maxConcurrentDownloads` |
| Automatic retries | Most times to retry a failed download. Some failures aren’t retried. | stepper 1–5 | `maxAutoRetries` |
| Media type | — | `SkinnedSegment` — Video / Audio | `defaultMediaType` |
| Video quality | Highest available if the exact height isn't offered. | `SkinnedPicker` — 2160p / 1440p / 1080p / 720p / 480p / Best available | `defaultVideoHeight` (`Int.max` = Best) |
| Audio language | Used when this video has that kind of track. | `SkinnedSegment` — YouTube default / Original | `defaultAudioLanguagePolicy` |
| Audio format | — | `SkinnedSegment` — M4A / MP3 | `defaultAudioFormat` |
| Filename format | — | `SkinnedPicker` — Title / Title – channel / Date – title / Custom… | `filenameTemplate` |
| Clipboard detection | Offer to grab links you copy. | toggle | `detectClipboardLinks` |

An **After downloading** group follows (planned): a double-click switch, off by default, and a video player and an audio player, each starting as the Mac's default app.

**Filename format → Custom…** has buttons that insert title, channel and date, and shows an example filename. An invalid format shows an error and the last valid one is kept. A format is valid only if every field in it can be previewed accurately, it has the title or the video ID, it ends in `.%(ext)s`, and it has no leading `/` and no `..`. Subfolders are allowed. The example matches the name the file is saved with.

The **concurrency note** renders in the "Simultaneous downloads" row's right column, under the stepper, when the new value is below the live running count: the warn glyph (§3.4) tinted `--warn` + a `--dim` line `"<count> still running — the new limit applies as they finish."` It clears when the running count drops to `≤` the new value, or on relaunch.

**Appearance** — sub _"Pick a look. Theme sets the personality; palette sets the colours."_

| Label | Helper | Control | Backs |
| --- | --- | --- | --- |
| Theme | Aurora is dark and luminous. Tape Deck is warm and light. | `SkinnedSegment` — Aurora / Tape Deck | `theme` |
| Palette | — | 3 split-fill swatches (56×38pt, name below; selected has a 2pt `--accent` outline at 2pt offset) for the selected theme | `palette` |

Changing Theme resets `palette` to that theme's default. Both controls apply live.

**Network** — sub _"Applied to new downloads."_

| Label | Helper | Control | Backs |
| --- | --- | --- | --- |
| Proxy server | `http://host:port` — blank for none. | text field; an invalid address shows an inline error and the last valid one is kept | `proxyURL` |
| Force IPv4 | Can help when connections stall. | toggle | `forceIPv4` |
| Speed limit | Applies to each download separately. | on/off switch + typed number field (KB/s) | `speedLimitKBps` |

**Sign-in & cookies** — sub _"Sign in to reach private or age-restricted videos on sites that need it."_ "A browser is chosen" below means **Browser** is not None.

| Label | Helper | Control | Backs |
| --- | --- | --- | --- |
| Browser | Use your browser's sign-in for videos that need an account. | `SkinnedPicker` — None / Safari / Chrome / Brave / Microsoft Edge / Firefox | `cookiesFromBrowser` |
| Use sign-in for | — | `SkinnedSegment` — All sites / Only these sites. Shown when a browser is chosen. | `signInScope` |
| Firefox profile | — | `SkinnedPicker`, caption "Profile". Shown for Firefox with two or more profiles. With no profile, the row shows _"No Firefox profiles found."_ instead of the picker; with exactly one, there is no row. | `cookiesFromBrowser` |
| _browser name_ | — | warn glyph (§3.4) + _"<browser> isn't installed, so there's no sign-in to use."_ Shown when Chrome, Brave or Microsoft Edge is chosen and not found. | — |
| Full Disk Access | When denied: MediaGrabber needs Full Disk Access to read Safari's sign-in. | Shown for Safari when its data container exists. Granted: `--accent` dot + _"Full Disk Access granted."_, no helper. Denied: warn glyph + skinned button **Open System Settings**. | — |
| Test sign-in | Checks that MediaGrabber can read your browser's sign-in. | skinned button **Test sign-in**, reading **Testing…** and disabled while it runs; the result line sits under it, `--accent` check on success, `--warn` triangle on failure. Shown when a browser is chosen. | — |
| Cookie access for _browser name_ | — | skinned button **Learn more ↗**. Shown when a browser is chosen. | — |

With **Only these sites** selected, the listed sites appear under the segment, each with a skinned **Remove** button (`signInSites`). An empty list shows _"Cookies go nowhere until you add a site."_

When a download is waiting for a sign-in retry, a warn glyph + _"Pick a browser to retry "<title>" with your sign-in."_ sits above the rows; "this download" stands in for a missing title.

When a browser is chosen, a `--dim` tip sits under the rows: _"For the most reliable results, use a browser profile that's signed in to the site and keep it closed while downloading."_

**Updates** — sub _"Check for new versions of the app and the downloader."_ The one place for versions and update actions.

| Label | Control | Notes |
| --- | --- | --- |
| MediaGrabber | version text; nothing, **Check for updates** or **Update** | button-verb rule below |
| Downloader | version text; **Update** when one is available | never **Check for updates** |
| Media tools | version text | read-only |
| Check for app updates automatically | toggle (`autoCheckAppUpdates`) | helper: looks for a newer release once a day |
| Update the downloader automatically | toggle | planned; needs signed update checking first. An outdated downloader always warns |
| Notify when the downloader is outdated | toggle (`autoCheckYtDlpUpdates`) | only until automatic updates ship, then the switch above replaces it |

**Button-verb rule** — each version row's action tracks how certain the app is that an update exists:

- **Nothing shown** — current.
- **Check for updates** — MediaGrabber only, before its release check has resolved this session.
- **Update** — an update is confirmed. For the app it starts the app update (§4.9); for the downloader it updates in place, shows a busy state, then the new version or the reason it failed. The Tools chip (§4.1) and Diagnostics (§4.7) offer the same action.

**Privacy** — sub _"What MediaGrabber collects and why."_

| Label | Helper | Control | Action |
| --- | --- | --- | --- |
| Summary | — | a few plain lines above the statement | — |
| Privacy statement | — | scrollable, selectable text | shows `Resources/Privacy.txt` |

**Licenses** — sub _"What MediaGrabber is made of."_

| Label | Helper | Control | Action |
| --- | --- | --- | --- |
| MediaGrabber | MIT-licensed; each tool keeps its own license | button "Read" | opens the app's own license, bundled |
| yt-dlp | Unlicense | button "Read" | opens `yt-dlp.txt` |
| FFmpeg | LGPL 2.1 or later | button "Read" | opens `ffmpeg.txt` |
| LAME | LGPL 2.1 or later | button "Read" | opens `lame.txt` |
| Node | MIT | button "Read" | opens `node.txt` |
| YouTube check helper | GPL 3.0 only | button "Read" | opens `shield.txt` |
| Sparkle | MIT | button "Read" | opens `sparkle.txt` |

**Advanced** — sub _"Reset options. These don't touch your downloaded files."_

| Label | Helper | Control | Action |
| --- | --- | --- | --- |
| App data | — | button "Show in Finder" | reveal `~/Library/Application Support/MediaGrabber` |
| Reset columns | Table layout back to default. | button "Reset" | `columnConfig = .default` |
| Reset settings | All preferences back to default. Downloads are untouched. | button "Reset…" (`--danger`), confirmation dialog | `Preferences.resetToDefaults()` |

New `Preferences` fields this section introduces: `detectClipboardLinks: Bool` (default true), `proxyURL: String?`, `forceIPv4: Bool` (default false), `speedLimitKBps: Int` (default 0, clamped 0…100000), `lastVideoHeight: Int?`, `lastMediaType: MediaType?`, `lastAudioFormat: AudioFormat?`.

### 4.7 Diagnostics

- A Preferences pane (§4.6, System group), not a top-level page.
- Holds the log rows: **Log files** with **Show in Finder** (`~/Library/Logs/MediaGrabber`), and the **Verbose logging** toggle (`verboseLogging`, helper "More detail for troubleshooting.").
- Plain health rows are always shown. Technical rows (such as the helper's port and the connection order) sit under a closed **Technical details** section and are always included in the copied report.
- A button opens the online report form.
- **Copy report** confirms the copy, and a failed downloader update shows its reason. The last-run time reads in plain words.
- Opens pre-populated from state the engine/session already have — the shield, cooldown, and network chips are live in `HealthController` regardless of this pane, so the report card shows their current values on open; the canary row and the version rescans read "not yet run this session" until **Run check** — laid out beside the pane's title, not below it — refreshes everything.
- The **report card** — rows of `key : value`, values coloured by verdict (`--accent` ok, `--warn` attention, `--danger` bad): canary result + time, yt-dlp version + drift against the app's declared minimum, ffmpeg version, bot-check shield health + port, cookie source + readability, detected client, **player_client rotation order** (read-only), active cooldown, network + VPN status. A yt-dlp row behind the declared minimum shows an inline **↻ Update** button that re-runs the pinned reinstall — the same action as the Tools chip (§4.1) and the Updates pane (§4.6).
- **Copy report** — puts a redacted plain-text block on the clipboard (redaction per spec §8.5).
- **Share diagnostic bundle** — hands the `DiagnosticBundle` zip (app-log tail + the most-recent job's log + this report) to the system share sheet (`NSSharingServicePicker`) — Mail, AirDrop, Save to Files, and so on. This is the only place either action lives (not in Preferences → Updates or About). The two buttons carry equal visual weight — one produces clipboard text, the other hands off a file; neither is more primary than the other.

---

### 4.8 About

A top-level nav destination (§4.1), still named **About**. A two-tab page, **The Product** (the About page below) and **The Person** (the Developer page below), selected via the app chrome's shared left rail (§4.1) over a scrolling pane — same shell as Preferences (§4.6). The health strip stays global chrome — present here exactly as on Home and Preferences. **About MediaGrabber** in the menu bar opens this page. How to use the app is explained in Help (§4.12).

**About** is a short in-app product page that must look good and read well for non-technical users. It has three blocks, in this order:

1. **Banner** — the large orb, the app's name, a one-line promise, the version and a **What's new** link to the online release notes.
2. **Free and open source** — one line with a **Licenses** link.
3. **Links** — **Project page** and **Report a problem**, which opens Diagnostics with its button to the online report form (§4.7).

There are no Included tools or Diagnostics rows. Versions and update actions live in Preferences → Updates (§4.6).

**The Person** (the Developer page) is the developer's showcase: a visitor should leave knowing that this person builds good things. It is one centred column, in this order, and fits the default window without scrolling:

1. **Identity** — the developer's photo (included in the app) in a circle, circled by the oracle orb's rings and lights (§4.2.5) as the page's signature feature: the far half passes behind the photo, the near half in front, and they lean towards the pointer. Then the name and a headline that differs by theme. Aurora: “Distributed systems by profession. Useful tools by choice.” Tape Deck: “Backend by trade, tinkerer by habit.” The headline and **About me** are the only text in the app that differs by theme. The rings are still under Reduce Motion. The near half may cross the lower part of the photo.
2. **About me** — two paragraphs of up to about 60 words, neither mentioning availability. The first introduces the developer through work and education; the second covers MediaGrabber, other projects and interests. Aurora is professional, Tape Deck friendly and playful. The final text is in the mockup.
3. **Links** — one row with no heading of four standard-height (34pt) buttons (§3.5), each only as wide as its icon and name, tinted with a faint wash and coloured icons (Aurora: `--accent`, with a border of the same tone; Tape Deck: `--accent-2`, with its usual ink border): GitHub (`https://github.com/Mshardul`), LinkedIn (`https://linkedin.com/in/mshardul`), Portfolio (`https://mshardul.github.io`) and Email (`shardullingwal94@gmail.com`).

There is no work-with-me block, and no **Source code** or **License** rows. All content is bundled with the app and changes with a release. **Report a problem** is on About. Support or donation links come later, once the accounts exist.

About is locked, and both pages are drawn in `docs/mockups/screens/about.html`.

---

### 4.9 Dialogs

#### One card

Confirmation, notice, passcode and health chip dialogs (§4.1) share one card: same width, title row, spacing and button placement. A field, progress, an issue list or a **Details** disclosure sits between the message and the buttons.

- **Scrim** — the whole window dims behind a `--ground` fill at ~60% alpha; clicks on the scrim do nothing (the choice is explicit).
- **Card** — centred, max width ~420pt, `--panel-solid` fill, theme border, `cardRadius` and elevation shadow. Padding `s5` all round.
- **Title row** — type icon at 19×19 beside the title, never above it. A health chip dialog shows the mark of its most severe level there instead (§4.1), the Healthy check when nothing is wrong. Title is `displayFont` 15 semibold, `--headline`.
- **Message** — `bodyFont` 13, `--dim`, one line. Wording is written to fit; the ellipsis is a safety limit. A link as the message is shortened in the middle.
- Optional **Don't ask again** checkbox (not a switch).
- **Buttons** — right-aligned, `s2` gap, sentence case, sized by §3.5. Cancel is plain `--panel` and is left out of a notice. The confirm button is filled: `--danger` when destructive, else `--accent` (the `--go` gradient on Aurora), with an `--onAccent` label.
- **Motion** — the card scales and fades in over `--dur` / `--ease`; it appears at once under Reduce Motion.
- **Keyboard** — Return presses the filled button, destructive ones included; Esc cancels or closes a notice.
- **VoiceOver** — a modal alert (`.isModal`) with focus kept inside; the icon type, title and message are read when it appears.

#### Icon types

| Type    | Icon                      | Used for              |
| ------- | ------------------------- | --------------------- |
| Error   | circled `x`, `--danger`   | Destructive actions   |
| Warning | triangle alert, `--warn`  | Something that failed |
| Info    | circled `i`, `--accent-2` | Everything else       |

#### Wording

In a question, the title asks and the message gives only the consequence. A message never repeats the question.

| Dialog | Type | Title | Message | Buttons (filled last) |
| --- | --- | --- | --- | --- |
| Passcode | info | Enter passcode | Enter the passcode the owner gave you. | Cancel · Continue |
| Download again | info | Download again? | You've already downloaded this. | Cancel · Download again |
| Already listed | info | Already in your list | This link hasn't finished downloading. | Download again · **Cancel** |
| Try again | info | Try this one again? | It's in your list but didn't finish. | Cancel · Restart |
| Incoming link | info | Grab this link? | _the link_ | Not now · Grab |
| Force start | info | Start this now? | The oldest active download goes back to the queue. | Cancel · Start now |
| Sign-in site | info | Use sign-in for this site? | MediaGrabber will use your browser sign-in for _site_. | Not now · Use sign-in |
| Clear sorting | info | Clear sorting? | Moving rows turns off sorting. | Cancel · Move rows |
| Move the app | info | Move MediaGrabber to Applications? | It can't update itself from where it is now. | Not now · Move |
| Remove | error | Remove this download? / Remove _N_ downloads? | Saved files stay. Partial files and logs are deleted. | Cancel · Remove |
| Cancel playlist | error | Cancel this playlist? | Unfinished videos stop. Saved files stay. | Keep downloading · Cancel downloads |
| Cancel selected | error | Cancel selected downloads? | Unfinished downloads stop. Saved files stay. | Keep downloading · Cancel downloads |
| Reset settings | error | Reset settings? | Preferences reset. Downloads and columns stay. | Cancel · Reset |
| Quit | error | Quit MediaGrabber? | Unfinished downloads stay in your list for next time. | Cancel · Quit anyway |
| Uninstall | error | Remove MediaGrabber? | App data is deleted; downloads stay. _N_ unfinished stop. | Cancel · Remove |
| File moved | warning | File moved | The file is no longer at that location. | OK |
| Log unavailable | warning | Log unavailable | This download's log is no longer available. | OK |
| Bad incoming link | warning | Couldn't open that link | The link was missing or not a web address. | OK |
| Already in Applications | warning | Already in Applications | Quit this copy and open the one in Applications. | OK |
| Move failed | warning | Couldn't move MediaGrabber | Drag it into your Applications folder. | OK |
| Uninstall failed | warning | Couldn't remove MediaGrabber | Its data couldn't be deleted, so it's still installed. | OK |
| Uninstall incomplete | warning | One step left | App data is gone. Move the app to the Trash. | OK |

The uninstall message drops its last sentence when nothing is unfinished.

- **Already listed** (the match is active, waiting or paused) inverts the fill: **Cancel** is filled and rightmost, so Return does not download twice.
- **Try again** replaces it when the match is failed or cancelled; **Restart** restarts that row, adding no second one.
- **Don't ask again** appears on removing a single row and on both cancel dialogs. Removing several rows always asks. **Reset settings** brings every suppressed question back.

#### Windows the app does not draw

The macOS file and folder pickers keep the system design. A missing downloader has no dialog of its own: onboarding (§4.5) and the Tools chip (§4.1) report it. App updates use the app's own themed window, not the update library's standard one; its states are not designed yet.

---

### 4.10 SkinnedSegment

A skinned segmented control, `import SwiftUI` only, generic over the option type.

```swift
struct SkinnedSegment<Option: Hashable>: View {
    init(_ options: [Option], selection: Binding<Option>, label: @escaping (Option) -> String)
}
```

- 2–3 options, all rendered as segments in a `--panel` track with a `--stroke` border; the selected segment gets a `--panel-solid` fill. Radius is the theme's `chipRadius`.
- **Equal-width segments** within one control (each sized to the widest label). The control as a whole **hugs its content** and sits flush to the row's right edge. Different controls in one pane may have different total widths; all are right-aligned.
- One tap selects. No popover. Left / Right arrow moves selection when focused; VoiceOver exposes it as a segmented control with the option labels, the selected segment carrying `.isSelected`.

**Used by:** Theme (Appearance), Media type (Downloads + runway), Audio format (Downloads + runway).

### 4.11 SkinnedPicker

A skinned dropdown. **It is a popover, not a modal** — picking one value from a short list is a lightweight, anchored interaction.

```swift
struct SkinnedPickerRow<Option: Hashable>: Identifiable {
    var id: Option
    var title: String
    var subtitle: String?   // nil -> single-line row
}

struct SkinnedPicker<Option: Hashable>: View {
    init(caption: String,
         rows: [SkinnedPickerRow<Option>],
         selection: Binding<Option>,
         triggerLabel: String? = nil)   // defaults to the selected row's title
}
```

- **Trigger** — a button showing the current selection's label + a chevron, `--panel` fill, `--stroke` border, theme `controlRadius`. The fixed button width of §3.5, never the label's.
- **Popover** — opens below the trigger (flips above if no room). `--panel-solid` fill, theme border + `cardRadius` + elevation matching the confirmation-dialog card (glow on Aurora, hard offset shadow on Tape Deck).
  - **Width** — sized to the picker's widest row (caption / label / subtitle), clamped `[trigger width … 340pt]`. No single global width.
  - **Caption header** — a `--faint` uppercase label naming what is being chosen, with a hairline `--hair` rule under it.
  - **Rows** — label; optional second-line **subtitle** in `--dim` (`nil` → single-line row); a checkmark (`--accent`) on the selected row; hover / arrow-key highlight uses a translucent accent wash. **No row icons.**
- Keyboard: Return / Space opens; Up / Down move the highlight; Return selects; Esc closes without changing. VoiceOver: a pop-up button; the selected row is announced.

**Used by:** Video quality (Downloads + runway), Filename format (Downloads), Save to (runway).

### 4.12 Help

A top-level destination (§4.1) that explains using the app in plain words. The Mac's **Help** menu opens it. Each section is its own page, chosen from the left rail, with the same shell as Preferences (§4.6). Pages, in order:

1. **How it works** — add a link, choose, grab. The first step holds every way to add a link: paste, drag, copy (with clipboard detection), Share and Services.
2. **What it can do** — video or audio, quality, audio language, playlists, pause and resume.
3. **Common questions** — which sites work, sign-in, where files go, what you may download.
4. **Something not working?** — three numbered steps to try in order, each its own card: the health checks (with a sample showing one that needs attention), **Open Diagnostics**, and **Report a problem**. The actions are standard buttons (§3.5), not text links.

Download statuses are not explained here. The top-bar order is Home, Preferences, Help, About. Layout and wording are locked as drawn in `docs/mockups/explore/help.html`.

---

## 5. Palette token sets

Every palette defines the full set. Names are stable across palettes; only values change. `--on-accent` is the text colour that sits on a solid `--accent` or `--go` fill.

### 5.1 Token list

```
--ground        app window backdrop (behind the card)
--panel-solid   main body / card fill
--panel         raised small surfaces (chips, selects, inputs) — may be translucent
--panel-hi      slightly stronger raised surface
--stroke        structural border
--hair          table row rule / faint divider
--text          primary text
--dim           secondary text
--faint         tertiary / placeholder — reaches 4.5:1 contrast on every surface
--headline      headline text (often = --text or a touch brighter)
--on-accent     text on a solid accent or --go fill
--accent        primary accent / "downloading" / kicker
--accent-2      secondary accent / "queued" / links / playlist group / selected-row wash at 10%
--warn          cooldown / attention
--danger        failure / error
--go            Go button fill (Tape Deck: solid; Aurora: use --go-fill)
--go-fill       Go button gradient (Aurora)
--bar-fill      progress bar fill
--glow-a        glow inner colour (Aurora elevation)
--glow-b        glow outer colour (Aurora elevation)
```

### 5.2 Tape Deck palettes (light)

Shared: `--ground` is a warm off-white a shade darker than `--surface` (`--panel-solid`). `--on-accent` = `--ink`. Elevation = hard shadow, no glow tokens used.

`--warn` is a dark amber (`#9C5A00` / `#9A6410` / `#8E6318`) chosen to hit WCAG AA for normal text on each palette's `--panel-solid` — it is used as text and as the glyph tint (concurrency note §4.6, cooldown copy). `--go` keeps its lighter amber (it is only ever a fill behind `--on-accent`). Aurora `--warn` is unchanged.

**Tape Deck / Teal & Rust** _(default for this theme)_

| token | value |
| --- | --- |
| --ground | `#F3E9D8` |
| --panel-solid (surface) | `#FBF4E6` |
| --panel | `#F3E9D8` |
| --stroke / --ink | `#2B2118` |
| --hair | `rgba(43,33,24,.18)` |
| --text | `#2B2118` |
| --dim | `#8A7A60` |
| --brand (header) | `#0E5C57` |
| --accent | `#D2601A` |
| --accent-2 | `#0E5C57` |
| --warn | `#9C5A00` |
| --danger | `#B4472A` |
| --go | `#E4A11B` |
| --bar-fill | `#D2601A` |
| status: downloading / saved / fail / cooldown / queued | `#CFE3E1` / `#D9E8C8` / `#F3D2C3` / `#F6E2B8` / `#FBF4E6` |

**Tape Deck / Plum & Blush**

| token | value |
| --- | --- |
| --ground | `#EFE9E9` |
| --panel-solid (surface) | `#FBF5F5` |
| --panel | `#EFE9E9` |
| --stroke / --ink | `#281E26` |
| --hair | `rgba(40,30,38,.18)` |
| --text | `#281E26` |
| --dim | `#8B8088` |
| --brand (header) | `#5A2E52` |
| --accent | `#E98C89` |
| --accent-2 | `#5A2E52` |
| --warn | `#9A6410` |
| --danger | `#C25B57` |
| --go | `#E8B24A` |
| --bar-fill | `#E98C89` |
| status: downloading / saved / fail / cooldown / queued | `#E1DCEC` / `#D8E6D0` / `#F4D6D6` / `#F3E3C0` / `#FBF5F5` |

_Note: with Blush as `--accent`, warning/cooldown reads softer. Confirmed acceptable in review._

**Tape Deck / Navy & Aqua**

| token | value |
| --- | --- |
| --ground | `#E7E9E7` |
| --panel-solid (surface) | `#F5F6F3` |
| --panel | `#E7E9E7` |
| --stroke / --ink | `#1B222A` |
| --hair | `rgba(27,34,42,.18)` |
| --text | `#1B222A` |
| --dim | `#7C838A` |
| --brand (header) | `#1F3350` |
| --accent | `#2FA69A` |
| --accent-2 | `#1F3350` |
| --warn | `#8E6318` |
| --danger | `#D9694C` |
| --go | `#F2B12E` |
| --bar-fill | `#2FA69A` |
| status: downloading / saved / fail / cooldown / queued | `#D6E6E3` / `#D8E6D0` / `#F3D8CC` / `#F6E6B6` / `#F5F6F3` |

### 5.3 Aurora palettes (dark)

Shared: `--panel` = `rgba(255,255,255,.05)`, `--panel-hi` = `rgba(255,255,255,.08)`, `--hair` = `rgba(255,255,255,.06)`, `--on-accent` = `#07080B`. Elevation = glow.

**Aurora / Mint & Iris** _(app default)_

| token               | value                                            |
| ------------------- | ------------------------------------------------ |
| --ground            | `#0C1013`                                        |
| --panel-solid       | `#0E1117`                                        |
| --stroke            | `rgba(255,255,255,.12)`                          |
| --text              | `#EDF0F5`                                        |
| --dim               | `#9AA3B2`                                        |
| --faint             | `#6B7480`                                        |
| --headline          | `#F4F6FA`                                        |
| --accent            | `#5EF2C8`                                        |
| --accent-2          | `#8B7BFF`                                        |
| --warn              | `#FFC24B`                                        |
| --danger            | `#FF7A6B`                                        |
| --go-fill           | `linear-gradient(135deg,#5EF2C8,#8B7BFF)`        |
| --bar-fill          | `linear-gradient(90deg,#5EF2C8,#8B7BFF)`         |
| --glow-a / --glow-b | `rgba(94,242,200,.14)` / `rgba(139,123,255,.16)` |

**Aurora / Lime & Forest**

| token               | value                                           |
| ------------------- | ----------------------------------------------- |
| --ground            | `#0A0F0C`                                       |
| --panel-solid       | `#0C1210`                                       |
| --stroke            | `rgba(190,255,210,.13)`                         |
| --text              | `#E9F2EC`                                       |
| --dim               | `#93A99C`                                       |
| --faint             | `#5F7268`                                       |
| --headline          | `#F2F8F3`                                       |
| --accent            | `#B6F04A`                                       |
| --accent-2          | `#4ED6A0`                                       |
| --warn              | `#F2C14E`                                       |
| --danger            | `#FF6F6F`                                       |
| --go-fill           | `linear-gradient(135deg,#B6F04A,#4ED6A0)`       |
| --bar-fill          | `linear-gradient(90deg,#B6F04A,#4ED6A0)`        |
| --glow-a / --glow-b | `rgba(182,240,74,.16)` / `rgba(78,214,160,.14)` |

**Aurora / Magenta & Violet**

| token               | value                                            |
| ------------------- | ------------------------------------------------ |
| --ground            | `#100C14`                                        |
| --panel-solid       | `#120E16`                                        |
| --stroke            | `rgba(230,190,255,.14)`                          |
| --text              | `#F1EAF5`                                        |
| --dim               | `#A996B5`                                        |
| --faint             | `#7A6B85`                                        |
| --headline          | `#F7F2FA`                                        |
| --accent            | `#F25C9E`                                        |
| --accent-2          | `#9B6BFF`                                        |
| --warn              | `#FFC24B`                                        |
| --danger            | `#FF6B6B`                                        |
| --go-fill           | `linear-gradient(135deg,#F25C9E,#9B6BFF)`        |
| --bar-fill          | `linear-gradient(90deg,#F25C9E,#9B6BFF)`         |
| --glow-a / --glow-b | `rgba(242,92,158,.16)` / `rgba(155,107,255,.16)` |

---

## 6. Implementation notes

- SwiftUI: express palettes as a `Palette` struct of `Color`s selected by `@AppStorage` theme + palette keys; themes differ in more than colour (fonts, corner radii, elevation modifier) so model a `Theme` protocol/enum with those as properties, not just a colour set.
- The logo (the orb) is one small reusable view driven by an `isActive` flag; honour `accessibilityReduceMotion`.
- Quality floor: full keyboard navigation, visible focus rings, VoiceOver labels on every icon button, `prefers-reduced-motion` respected, window usable down to a narrow width (table scrolls horizontally inside its own container; the page never scrolls sideways).
- Column state (order, visibility, widths, sort) persists as `ColumnConfig` in `columns.json` via `Persistence` (the same mechanism as queue/history), keyed independently of both `Preferences` and window state.
