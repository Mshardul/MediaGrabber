# Planning and tickets

## Tickets only

Every item raised is a ticket in [tickets.md](../tickets.md), with an epic and, when it must ship in a given version, a Release. The rules are in [ticket-setup.md](../ticket-setup.md).

1. **In scope → build it to final-app form.** No stubs to swap later, no "minimum that passes this ticket," no shape a later ticket must replace. If the confirmation dialog is in scope, it gets its real skinned UI + design-system entry now.
2. **Deferred → approved, and in a ticket.** Do as much as possible now. Work that a future ticket covers may be deferred to it, but every deferral needs the user's approval. Once deferring, make sure a ticket covers the item, and add one if none does. Don't silently drop an item and don't leave a floating "follow-ups" list. A review note, a chat, or a ledger line is not a home. The turn that defers an item writes its row before the turn ends, and a decision lives in a row or in the spec its epic links to. Product-level **never** belongs in §13 of the [parent design](superpowers/specs/2026-08-28-youtube-downloader-mac-design.md).
3. **Finished work is closed.** No blame, no rework to match a later rule, no framing current work as fixing past mistakes. If current work must touch completed code, do it as a plain change in the current ticket. Present and future only.
4. **A release is a Release value.** It is ready when every row with that version is `completed` or `dropped`. `roadmap.md` is the short overview and never holds a decision the table does not.

## Raising a design choice

When brainstorming a design fork, write it as plain-chat prose: the fork, the real tradeoff, a recommendation. One position at a time; revise on merit, don't pitch-then-collapse.
