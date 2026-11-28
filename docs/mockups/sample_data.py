"""Sample data every screen draws from, so one download looks the same everywhere."""

from dataclasses import dataclass, replace

AREAS = (
    ("home", "Home"),
    ("playlist", "Playlist"),
    ("table", "Table"),
    ("chrome", "Chrome"),
    ("orb", "Orb"),
    ("icons", "Icons"),
    ("dialog", "Dialogs"),
    ("onboarding", "Onboarding"),
    ("preferences", "Preferences"),
    ("about", "About"),
    ("column-interactions", "Column interactions"),
)

# Large areas are split into topic pages, one source folder each; the first keeps the area's file.
SUBPAGES = {
    "home": (
        ("1-grab", "Grab view"),
        ("2-checked", "After a check"),
        ("3-problems", "Problems"),
    ),
    "table": (
        ("1-rows", "Rows"),
        ("2-actions", "Actions and reasons"),
        ("3-sort", "Sort and filter"),
        ("4-empty", "Empty views"),
    ),
}

THEMES = (
    (
        "aurora",
        "Aurora",
        (("mint", "Mint & Iris"), ("lime", "Lime & Forest"), ("magenta", "Magenta & Violet")),
    ),
    (
        "tapedeck",
        "Tape Deck",
        (("teal", "Teal & Rust"), ("plum", "Plum & Blush"), ("navy", "Navy & Aqua")),
    ),
)
DEFAULT_THEME, DEFAULT_PALETTE = "aurora", "mint"

STATE_LABELS = {
    "queued": "Queued",
    "probing": "Probing",
    "running": "Downloading",
    "paused": "Paused",
    "waitingForNetwork": "Waiting for network",
    "cooldown": "Cooling down",
    "completed": "Saved",
    "cancelled": "Cancelled",
    "failed": "Failed",
}

FAILURE_SENTENCES = {
    "rateLimited": "The site is limiting how fast we can download right now.",
    "botCheck": "YouTube didn't accept this request. Try again later, or turn off your VPN.",
    "sabrGated": "YouTube isn't offering a downloadable video for this link.",
    "formatsMissing": "The quality you picked isn't available for this video.",
    "cookieReadFailed": "Couldn't read your browser's sign-in.",
    "geoBlocked": "This video isn't available in your region.",
    "private": "This video is private.",
    "unavailable": "This video is no longer available.",
    "ageRestricted": "This video is age-restricted and needs you to be signed in.",
    "networkDown": "No internet connection.",
    "diskFull": "The disk is full.",
    "permissionDenied": "The download folder isn't writable.",
    "incomplete": "The download kept ending early.",
    "depMissing": "The downloader needs reinstalling.",
    "potProviderDown": "The YouTube check is offline.",
    "passcodeRequired": "This recording needs a passcode.",
    "passcodeRejected": "That passcode didn't work.",
    "unknown": "This download failed.",
}

FIRST_RUN_STEPS = (
    ("Paste a link", "Any video page URL."),
    ("Pick a format", "Video quality or audio only."),
    ("Press Grab", "It saves to your folder."),
)


@dataclass(frozen=True)
class Download:
    title: str
    site: str
    state: str
    kind: str = "Video"
    quality: str | None = None
    size: str | None = None
    duration: str | None = None
    added: str = "28 Nov, 09:14"
    progress: int | None = None
    speed: str | None = None
    eta: str | None = None
    remark: str = ""
    failure: str | None = None
    link: str = ""


def _failed(title, site, failure, **fields):
    return Download(
        title, site, "failed", failure=failure, remark=FAILURE_SENTENCES[failure], **fields
    )


DOWNLOADS = (
    Download(
        "How a tape deck works",
        "YouTube",
        "running",
        quality="1080p",
        size="412 MB",
        duration="18:42",
        progress=62,
        speed="6.4 MB/s",
        eta="0:24",
    ),
    Download("Northern lights over Tromsø, 4K", "Vimeo", "queued", duration="7:05", remark="#1"),
    Download("Field recording: monsoon on a tin roof", "SoundCloud", "probing", kind="Audio"),
    Download(
        "The history of the compact cassette",
        "Internet Archive",
        "paused",
        quality="720p",
        size="268 MB",
        duration="31:10",
        progress=35,
    ),
    Download(
        "Weekly design review",
        "Zoom",
        "waitingForNetwork",
        quality="720p",
        size="190 MB",
        duration="52:18",
        progress=48,
        remark="No connection",
    ),
    Download(
        "Analog synth patching for beginners",
        "YouTube",
        "cooldown",
        duration="24:51",
        remark="Try again in 1:00",
    ),
    Download(
        "Slow-baked sourdough, start to finish",
        "YouTube",
        "completed",
        quality="1080p",
        size="356 MB",
        duration="14:03",
    ),
    Download(
        "Evening raga, live session",
        "SoundCloud",
        "completed",
        kind="Audio",
        quality="m4a",
        size="11 MB",
        duration="12:27",
    ),
    Download("Timelapse of a city waking up", "Web", "cancelled", duration="3:48"),
    _failed("Restoring a 1970s receiver", "YouTube", "rateLimited"),
    _failed("Street food walk in Pune", "YouTube", "botCheck"),
    _failed("Unlisted rehearsal take", "YouTube", "sabrGated"),
    _failed("Deep sea footage in 8K", "Vimeo", "formatsMissing"),
    _failed("Members-only studio tour", "YouTube", "cookieReadFailed"),
    _failed("Regional cup final highlights", "YouTube", "geoBlocked"),
    _failed("Family reunion video", "Vimeo", "private"),
    _failed("Deleted interview", "YouTube", "unavailable"),
    _failed("Late night documentary", "YouTube", "ageRestricted"),
    _failed("Commute podcast, episode 41", "SoundCloud", "networkDown", kind="Audio"),
    _failed("Full conference keynote", "Internet Archive", "diskFull"),
    _failed("Lecture 7: signal and noise", "Web", "permissionDenied"),
    _failed("Three hour ambient mix", "SoundCloud", "incomplete", kind="Audio"),
    _failed("Pottery wheel basics", "Vimeo", "depMissing"),
    _failed("How vinyl is pressed", "YouTube", "potProviderDown"),
    _failed("Client call, 21 November", "Zoom", "passcodeRequired"),
    _failed("Onboarding session recording", "Zoom", "passcodeRejected"),
    _failed("Archive reel 12", "Web", "unknown"),
)

_COOLING = replace(DOWNLOADS[5], quality="1080p", size="305 MB", progress=20)
_UNTITLED = Download("", "Web", "probing", link="https://vimeo.com/884213507")
_QUEUED_AGAIN = Download(
    "Cassette head cleaning, three ways",
    "YouTube",
    "queued",
    quality="720p",
    size="142 MB",
    progress=20,
    remark="#2",
)

# One row for each job state, plus a row with no title yet and a queued row that had started.
TABLE_ALL = (*DOWNLOADS[:3], _UNTITLED, *DOWNLOADS[3:5], _COOLING, _QUEUED_AGAIN, *DOWNLOADS[6:10])
IN_PROGRESS = ("queued", "probing", "running", "paused", "waitingForNetwork", "cooldown")
TABLE_DOWNLOADING = tuple(row for row in TABLE_ALL if row.state in IN_PROGRESS)
TABLE_DONE = tuple(row for row in TABLE_ALL if row.state == "completed")
TABLE_INACTIVE = tuple(row for row in DOWNLOADS if row.state in ("cancelled", "failed"))


def _megabytes(row):
    return int(row.size.split()[0])


# Rows with no known size stay last whichever way the column is sorted.
TABLE_BY_SIZE = tuple(sorted((r for r in TABLE_ALL if r.size), key=_megabytes)) + tuple(
    r for r in TABLE_ALL if not r.size
)
QUALITY_CHOICES = ("1080p", "720p", "m4a")
QUALITY_CHECKED = ("720p", "m4a")
TABLE_BY_QUALITY = tuple(row for row in TABLE_ALL if row.quality in QUALITY_CHECKED)
TITLE_QUERY = "cassette"
TABLE_BY_TITLE = tuple(row for row in TABLE_ALL if TITLE_QUERY in row.title.lower())

# View: heading, message, button.
EMPTY_VIEWS = {
    "All": ("No downloads yet", "Everything you grab is listed here.", "Grab a link"),
    "Downloading": ("Nothing is downloading", "Downloads in progress show up here.", "Grab a link"),
    "Done": ("Nothing saved yet", "Finished downloads show up here.", "Grab a link"),
    "Inactive": (
        "Nothing needs attention",
        "Failed and cancelled downloads show up here.",
        "Grab a link",
    ),
    "Filtered": (
        "No downloads match",
        "Your column filters hide every download here.",
        "Clear filters",
    ),
}

PLAYLIST_NAME = "Restoring old hi-fi, the full series"
PLAYLIST_SITE = "YouTube"
PLAYLIST_UPLOADER = "Workbench Audio"

# Title, duration, approximate size, picker note.
PLAYLIST_ITEMS = (
    ("Opening the case safely", "8:12", "94 MB", ""),
    ("Cleaning the controls", "11:47", "135 MB", "Already saved"),
    ("Replacing the belts", "15:03", "172 MB", "In queue"),
    ("Recapping the power supply", "22:36", "258 MB", ""),
    ("Aligning the tape heads", "17:20", "198 MB", ""),
    ("Final listening test", "6:55", "79 MB", ""),
)


def clock(seconds):
    hours, rest = divmod(seconds, 3600)
    minutes, seconds = divmod(rest, 60)
    head = f"{hours}:{minutes:02}" if hours else str(minutes)
    return f"{head}:{seconds:02}"


def _seconds(duration):
    total = 0
    for part in duration.split(":"):
        total = total * 60 + int(part)
    return total


def _total(megabytes):
    return f"{megabytes / 1000:.1f} GB" if megabytes >= 1000 else f"{megabytes} MB"


@dataclass(frozen=True)
class PickerRow:
    title: str
    duration: str
    size: str
    note: str = ""
    checked: bool = True


@dataclass(frozen=True)
class Picker:
    rows: tuple[PickerRow, ...]
    query: str = ""
    queued: bool = False

    @property
    def shown(self):
        return tuple(row for row in self.rows if self.query.lower() in row.title.lower())

    @property
    def selected(self):
        return sum(row.checked for row in self.rows)

    @property
    def subtitle(self):
        return (
            f"{PLAYLIST_NAME} · {PLAYLIST_SITE} · by {PLAYLIST_UPLOADER} · {len(self.rows)} items"
        )

    @property
    def summary(self):
        chosen = [row for row in self.rows if row.checked]
        parts = [f"{len(chosen)} of {len(self.rows)} selected"]
        if queued := sum(row.note == "In queue" for row in chosen):
            parts.append(f"{queued} already in queue")
        if chosen:
            parts.append(f"≈ {clock(sum(_seconds(row.duration) for row in chosen))}")
            parts.append(f"≈ {_total(sum(int(row.size.split()[0]) for row in chosen))}")
        if self.query:
            parts.append(f"{len(self.shown)} shown")
        return " · ".join(parts)


_FRESH = tuple(PickerRow(title, length, size) for title, length, size, _ in PLAYLIST_ITEMS)
_LONG_EXTRA = (
    (
        "Choosing replacement capacitors without losing the original sound of the deck",
        "19:44",
        "226 MB",
    ),
    ("Lubricating the transport", "9:31", "108 MB"),
    ("Fixing a noisy motor", "13:58", "160 MB"),
    ("Repairing the meter lamps", "7:26", "85 MB"),
    ("Restoring the wooden case", "24:10", "276 MB"),
    ("Setting the bias", "10:49", "124 MB"),
)
PICKER_FRESH = Picker(_FRESH)
PICKER_QUEUED = Picker(
    tuple(
        PickerRow(title, length, size, note, checked=not note or note == "In queue")
        for title, length, size, note in PLAYLIST_ITEMS
    ),
    queued=True,
)
PICKER_FILTERED = Picker(_FRESH, query="ap")
PICKER_NONE = Picker(tuple(PickerRow(r.title, r.duration, r.size, checked=False) for r in _FRESH))
PICKER_LONG = Picker(_FRESH + tuple(PickerRow(*item) for item in _LONG_EXTRA))


def _child(index, state, **fields):
    title, duration, size, _ = PLAYLIST_ITEMS[index]
    if state in ("completed", "running"):
        fields = {"quality": "1080p", "size": size, **fields}
    return Download(title, PLAYLIST_SITE, state, duration=duration, **fields)


_RUNNING = {"progress": 62, "speed": "6.4 MB/s", "eta": "0:24"}
GROUP_ACTIVE = (
    _child(0, "completed"),
    _child(1, "completed"),
    _child(2, "running", **_RUNNING),
    _child(3, "queued"),
    _child(4, "queued"),
    _child(5, "queued"),
)
GROUP_MIXED = (
    _child(0, "completed"),
    _child(1, "completed"),
    _child(2, "failed", failure="botCheck"),
    _child(3, "cancelled"),
    _child(4, "running", **_RUNNING),
    _child(5, "queued"),
)

# Job states each action applies to.
CANCELLABLE = ("queued", "probing", "running", "paused", "waitingForNetwork", "cooldown")
GROUP_ACTIONS = (
    ("pause", "Pause all", ("running",)),
    ("restart", "Restart failed", ("failed", "cancelled")),
    ("close", "Cancel all", CANCELLABLE),
)


def rollup(children):
    """The header's counts, with zeros hidden."""
    counts = (
        ("done", ("completed",)),
        ("failed", ("failed",)),
        ("cancelled", ("cancelled",)),
        ("in progress", CANCELLABLE),
    )
    parts = [f"{len(children)} items"]
    for label, states in counts:
        if found := sum(child.state in states for child in children):
            parts.append(f"{found} {label}")
    return " · ".join(parts)


def rollup_tenths(children):
    """Overall progress, rounded to the nearest ten percent."""
    total = sum(100 if c.state == "completed" else c.progress or 0 for c in children)
    return round(total / len(children) / 10) * 10


# Every video-level action, with the states that offer it.
VIDEO_ACTIONS = (
    ("pause", "Pause", ("running",)),
    ("resume", "Resume", ("paused",)),
    ("close", "Cancel", CANCELLABLE),
    ("force-start", "Force start", ("cooldown",)),
    ("restart", "Restart", ("failed", "cancelled")),
    ("sign-in", "Restart with sign-in", ()),
    ("folder", "Reveal", ("completed",)),
    ("trash", "Remove", tuple(STATE_LABELS)),
    ("open", "Open", tuple(STATE_LABELS)),
    ("log", "Log", tuple(s for s in STATE_LABELS if s not in ("queued", "probing"))),
)

SIGN_IN_FAILURES = ("ageRestricted", "private", "botCheck")


def offers(download, label, states):
    """Whether a row's state offers an action; the sign-in restart also depends on the failure."""
    if label == "Restart with sign-in":
        return download.failure in SIGN_IN_FAILURES
    return download.state in states


def table_rail(inactive):
    return (*HOME_RAIL[:-1], ("Inactive", inactive))


PAGES = ("Home", "Preferences", "Help", "About")
# A row without a name is the divider between adding links and filtering downloads.
_FILTERS = ("All", "Downloading", "Done")
HOME_RAIL = (("Grab", 0), (None, 0), *((name, 0) for name in _FILTERS), ("Inactive", 2))
FIRST_RAIL = (("Grab", 0), (None, 0), *((name, 0) for name in _FILTERS), ("Inactive", 0))

LEVELS = {"blocked": "Blocked", "problem": "Problem", "warning": "Warning", "healthy": "Healthy"}
_SEVERITY = ("blocked", "problem", "warning", "healthy")

CATEGORIES = (
    ("connection", "Connection"),
    ("signin", "YouTube & sign-in"),
    ("tools", "Tools"),
    ("storage", "Storage"),
)


@dataclass(frozen=True)
class Issue:
    category: str
    level: str
    minutes_ago: int
    title: str
    detail: str
    action: str | None = None


_CHECK_STOPPED = Issue(
    "signin",
    "problem",
    3,
    "YouTube check stopped",
    "Some YouTube downloads may fail or be lower quality.",
    "Restart",
)

HEALTH_SAMPLES = {
    "healthy": (),
    "one": (_CHECK_STOPPED,),
    "several": (
        Issue(
            "connection",
            "warning",
            1,
            "YouTube is cooling down",
            "Downloads from YouTube resume in 4:29.",
        ),
        Issue(
            "connection",
            "blocked",
            12,
            "Vimeo is paused",
            "Vimeo keeps limiting requests. Try again later, or turn off your VPN.",
            "Retry now",
        ),
        Issue(
            "connection",
            "warning",
            8,
            "YouTube downloads run one at a time",
            "This helps avoid more limits.",
        ),
        _CHECK_STOPPED,
        Issue(
            "tools",
            "warning",
            40,
            "Downloader is out of date",
            "A newer version is ready.",
            "Update",
        ),
        Issue(
            "storage",
            "blocked",
            2,
            "Disk is full",
            "Free some space so downloads can continue.",
            "Show folder",
        ),
    ),
}


def sorted_issues(sample, category):
    found = [issue for issue in HEALTH_SAMPLES[sample] if issue.category == category]
    return sorted(found, key=lambda issue: (_SEVERITY.index(issue.level), issue.minutes_ago))


def worst_level(sample, category):
    issues = sorted_issues(sample, category)
    return issues[0].level if issues else "healthy"


BUTTON_SIZES = (("large", "44 main action"), ("standard", "34 standard"), ("compact", "28 compact"))

QUALITY_ROWS = (
    ("2160p", ""),
    ("1440p", ""),
    ("1080p", ""),
    ("720p", ""),
    ("480p", ""),
    ("Best available", ""),
)

LANGUAGE_ROWS = tuple(
    (name, "Original" if name == "English" else "")
    for name in (
        "Arabic",
        "Bengali",
        "Dutch",
        "English",
        "French",
        "German",
        "Gujarati",
        "Hindi",
        "Indonesian",
        "Italian",
        "Japanese",
        "Korean",
        "Marathi",
        "Polish",
        "Portuguese",
        "Spanish",
        "Tamil",
        "Turkish",
        "Ukrainian",
        "Vietnamese",
    )
)

# Mood: heading, message, actions.
ORB_MESSAGES = {
    "waiting": ("Whatever you need", "Paste a link above and MediaGrabber fetches it for you.", ()),
    "resting": (*EMPTY_VIEWS["Downloading"][:2], (EMPTY_VIEWS["Downloading"][2],)),
    "clouded": (*EMPTY_VIEWS["Filtered"][:2], (EMPTY_VIEWS["Filtered"][2],)),
    "searching": ("Looking for it…", "Checking your link.", ()),
    "drag": ("Drop it in", "Let go and MediaGrabber checks the link.", ()),
}

TYPE_ROWS = (("Video", ""), ("Audio", ""))
FOLDER_ROWS = (("Downloads", "~/Downloads"), ("Talks", "~/Movies/Talks"), ("Choose…", ""))


@dataclass(frozen=True)
class Choice:
    kind: str
    format: str
    language: str
    folder: str


VIDEO_CHOICE = Choice("Video", "1080p", "English", "Downloads")
AUDIO_CHOICE = Choice("Audio", "M4A", "English", "Downloads")


@dataclass(frozen=True)
class Result:
    title: str
    file: str = ""
    length: str = ""
    size: str = ""
    picture: bool = True
    exists: bool = False


VIDEO_LINK = "https://www.youtube.com/watch?v=a8Fh2kQz9Lm"
VIDEO_RESULT = Result("How a tape deck works", "How a tape deck works.mp4", "18:42", "412 MB")
EXISTING_RESULT = Result(
    "How a tape deck works", "How a tape deck works.mp4", "18:42", "412 MB", exists=True
)
AUDIO_RESULT = Result("How a tape deck works", "How a tape deck works.m4a", "18:42", "17 MB")
LONG_RESULT = Result(
    "Deep sea documentary with several narrators and a very long title that cannot fit",
    "Deep sea documentary with several narrators and a very long title that cannot fit.mp4",
    "1:12:08",
    "1.6 GB",
)
LONG_CHOICE = Choice("Video", "Best available", "Portuguese (Brazil)", "Conference recordings")
PLAYLIST_LINK = "https://www.youtube.com/playlist?list=PL9h3kq2"


def playlist_result(count):
    return Result(f'"{PLAYLIST_NAME}" · {count} items', picture=False)


ZOOM_LINK = "https://zoom.us/rec/share/Wq3v8kT1"

LINK_HINT = "You can also drag a link in."

# About and Developer
ABOUT_RAIL = (("The Product", 0), ("The Person", 0))
APP_VERSION = "1.0.0"
APP_PROMISE = "Paste a link. Keep the video, or just the sound."
DEVELOPER_NAME = "Shardul Lingwal"
# The only text that differs by theme: theme, headline, "About me" paragraphs
DEVELOPER_VOICES = (
    (
        "aurora",
        "Distributed systems by profession. Useful tools by choice.",
        (
            "My work has spanned marketing platforms, payments and AI video checks, taking me from "
            "building features to leading teams. Today I’m a backend engineering lead with 7+ "
            "years’ experience. I hold an M.Tech from IIIT Bangalore and I’m pursuing an Executive "
            "MBA at IIM Kashipur.",
            "Alongside work, I build web and Mac projects, including MediaGrabber. "
            "Chess and sudoku "
            "give me something to think through, while badminton gets me moving. I "
            "enjoy mountains, "
            "travel and scooter rides. When I slow down, I read across genres, including poetry.",
        ),
    ),
    (
        "tapedeck",
        "Backend by trade, tinkerer by habit.",
        (
            "Hi there, Shardul here! I’m a backend engineering lead with 7+ years of professional "
            "experience. I’ve built some software and led a few teams along the way. I’ve got an "
            "M.Tech from IIIT Bangalore, and I’m back in student mode for an Executive MBA at IIM "
            "Kashipur.",
            "A good weekend? A scooter ride, perhaps some mountains, and a book. Add chess, sudoku "
            "or badminton, and I’m set. Travel and poetry are always welcome. I also build web and "
            "Mac projects, MediaGrabber included. "
            "If something here sounds like you, come say hello.",
        ),
    ),
)
# Name and icon
DEVELOPER_LINKS = (
    ("GitHub", "github"),
    ("LinkedIn", "linkedin"),
    ("Portfolio", "portfolio"),
    ("Email", "mail"),
)
