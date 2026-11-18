# Product page

**Status:** proposed, awaiting review. Items belonging to this phase are added here as they arise; scope is settled when the phase starts planning.

**Scope:** `site/index.html`, the page that takes a visitor from "what is this" to "installed". Its reader is a person who wants to download the app. The page is plain and non-technical and has no "built with" section.

---

## Intent

The page is the app's public face and the first thing a visitor sees before the README. It shows the real app, links to the real release, says plainly what the app can and cannot do, and walks a first-time user through the one awkward step: the first launch of an app that Apple has not reviewed.

## 1. Screenshots

- **Hero.** Real captures of the built app, one for each theme (Aurora and Tape Deck). The page's theme switch swaps them.
- **Install.** Four real captures: the disk image window, and three for Open Anyway (the "can't check" message, Privacy & Security with Open Anyway, the final confirm). Captions say the screen may look a little different on another macOS version, and the steps stay true for macOS 14 or later.
- **Source of the captures.** The hero captures come from the script below. The Open Anyway captures are macOS windows; they are taken on the clean-account run in the release checklist and retaken when macOS changes.

## 2. Screenshot script

`make page-shots` launches the built app against a temporary home with a prepared queue (a few rows in fixed states, one in progress at a fixed percentage) and the fixture server from the release-hardening phase, sets each theme in turn, captures the window at a fixed size and writes to `site/assets/shots/` under fixed names. It fails when a capture is blank or the wrong size. The app does not honour a changed `HOME`, so this phase decides how the script runs the app against fixture data without touching a real home, for example by giving the app a single home-folder setting. The terminal needs Screen Recording permission once. The release checklist runs it every release, so the shots are always current and a changed shot shows up in the diff.

## 3. Links

- **Download** goes to the latest release. No version is fetched when the page loads, so "no tracking" stays true.
- **Privacy** goes to `PRIVACY.md`.
- **Source, licenses and problem report** link to the repository, the Licenses information and the issue form.

## 4. What it says about sites

A feature card, "Plenty of sites play along.": "YouTube and loads of other video sites work. If one wants you signed in first, MediaGrabber says so."

FAQ "Which sites work?": "YouTube and many other video sites. Some ask you to sign in first, and MediaGrabber tells you when. A few sites won't work."

FAQ "Is it okay to download anything?" answers that you should only download what you have the right to.

## 5. Page basics

A real title and description, a social preview image, icons, and the phone layout including the "Open this page on your Mac" button. The page stays at `mshardul.github.io/MediaGrabber`.

## 6. Copy and accessibility

Every sentence is checked against the shipped app. Contrast, keyboard use and reduced motion are checked in both themes.

## 7. Guard

`pages.yml` fails the deploy when the page contains a `#` placeholder link, the words "mockup" or "placeholder", a "Screenshot:" box, or a reference to an asset file that does not exist.

## 8. Dependencies

The first release has been published, so the download link and the captures are real. The fixture server from the release-hardening phase exists. The release checklist gains the `make page-shots` step.

## Deferred decisions

Hero layout, where the screenshot sits in the page, and the layout of the install section. They are decided in a mockup pass when the phase starts planning.
