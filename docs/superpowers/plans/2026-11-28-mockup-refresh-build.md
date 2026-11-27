# Mockup refresh: build plan

**Goal:** `docs/mockups/` shows every screen and state of the finished app, in both themes and all six palettes. `screens.html` links to every screen; the area pages in `screens/` draw them.

## Read first

- Decisions: `docs/superpowers/specs/2026-11-28-mockup-refresh-decisions.md` (the log). It wins over the old plan.
- Visual rules: `docs/design-system.md`. A mockup that differs from it is wrong.
- Row and group actions: `docs/job-status-and-actions.md`. Ticket details: `tickets.md`.
- Base plan: `docs/superpowers/plans/2026-10-22-media-grabber-mockups-rebuild.md` (build system, sample data, checker, screen inventory), minus the log's "Stale in the old plan".
- Prototypes in `docs/mockups/explore/`: `orb.html`, `titlebar.html`.

## Rules

- Draw only what is decided. For an undecided part, draw today's screenshot plus locked app-wide rules, with a one-line "design pending" note.
- Anything unclear or conflicting: ask the user, never invent.
- Planned (not yet built) items are drawn and marked with their ticket id. No other ticket or phase text in mockups.
- No git. Python is `.venv/bin/python`. Jinja is approved but not installed; pin it in `docs/mockups/requirements.txt`.
- No `stale/` folder. The new build replaces the old `screens.html`, `screens.css` and `screens/` files; an old area page and `screens/screens.css` stay until the new pages replace them. `explore/` is not touched.
- All styling comes from common CSS files: no style blocks, style attributes, or literal colours or sizes in any page or template.
- One task per session is fine. Tick a box only when the user accepts it.

## Tasks

- [ ] 1. Build system: Jinja sources, `build.py`, shared CSS and JS, sample data, checker; `screens.html` front page, area pages with a top menu, theme and palette switcher.
- [ ] 2. Shared window: title bar, logo ring, chips, issues dialog, alerts, buttons, popups. Log: App-wide, Chrome. DS §4.1, §4.4. Reference: `titlebar.html` layout A, logo 4 (not B, C or logos 1–3).
- [ ] 3. Orb component, both themes, five moods. Log: Empty states and the oracle orb. DS §4.2.5. Reuse `orb.html`.
- [ ] 4. Home, including first launch. Log: Home. DS §4.2.1–4.2.2.
- [ ] 5. Playlist picker and group. Log: Playlist. DS §4.2.4, §4.3.
- [ ] 6. Table and its empty states. Log: Table. DS §4.2.3, §4.2.5.
- [ ] 7. Chrome states: each chip, level and issue; alerts; drop highlight; setup and passcode panels.
- [ ] 8. Dialogs (design pending).
- [ ] 9. Onboarding (design pending; orb and no Homebrew are locked).
- [ ] 10. Preferences (design pending; log: Preferences is locked).
- [ ] 11. About and Developer (design pending; log: About and Developer is locked).
- [ ] 12. Column interactions (design pending; mg-017 is locked).
- [ ] 13. Check every page in both themes and six palettes for overflow and clipping; run the checker; user review.
- [ ] 14. After acceptance, update documents that point at the mockups, each with the user's approval.

## Not covered by the log

- Draw only the default window (980×720) unless a state needs another width; show 820 for the title bar, chips and table.
- Icons: placeholders from one swappable sprite per theme until the icon set lands (mg-010).
- Both prototypes are browser-only; native feasibility of the orb and title bar is untested and does not block mockups.
