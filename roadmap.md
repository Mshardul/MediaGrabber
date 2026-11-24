# Roadmap

An overview written from `tickets.md`. It never holds a decision the table does not. Rules for rows, epics and releases are in `ticket-setup.md`.

## Releases

- **0.1.0** — the first release. Its rows are the ones with Release `0.1.0` in `tickets.md`. It is ready when every one of them is `completed` or `dropped`, and `docs/release-checklist.md` passes.

Rows with an empty Release are not tied to a version yet.

## Epics

- **code-health** — code, logs and docs say and do what they claim. Most of the pre-release review fixes are here.
- **visual-fidelity** — the app looks and reads as the design system and mockups specify.
- **sign-in-policy** — when a download uses a browser sign-in, and what the app says when it cannot. Rows are added when the design is written.
- **product-page** — the real `site/index.html`. Rows are added when it is planned.
- **test-suite** — what the unit, plugin and shell tests protect for the app as a whole. Spec: `docs/superpowers/specs/2026-11-17-media-grabber-phase-25-test-suite-review-design.md`.
- **grab-details** — what a grab will save, and opening the saved file.
- **profile** — who makes the app, and the other work shown there.

## History

Phases 1 to 22 shipped. Their specs and plans are in `docs/superpowers/specs/` and `docs/superpowers/plans/`, with finished ones in the `archived/` folders. Distant ideas with no ticket yet are in `future-ideas.md`.
