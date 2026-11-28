"""Sample data every screen draws from, so one download looks the same everywhere."""

from dataclasses import dataclass

AREAS = (
    ("home", "Home"),
    ("playlist", "Playlist"),
    ("table", "Table"),
    ("chrome", "Chrome"),
    ("orb", "Orb"),
    ("dialog", "Dialogs"),
    ("onboarding", "Onboarding"),
    ("preferences", "Preferences"),
    ("about", "About"),
    ("column-interactions", "Column interactions"),
)

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
    "resting": (
        "Nothing is downloading",
        "3 are saved and 1 needs a look.",
        ("View saved", "View inactive"),
    ),
    "clouded": (
        "No downloads match",
        "Your filter is Quality: 720p. 4 downloads are hidden by it.",
        ("Clear filters",),
    ),
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
PLAYLIST_RESULT = Result(f'"{PLAYLIST_NAME}" · {len(PLAYLIST_ITEMS)} items', picture=False)
ZOOM_LINK = "https://zoom.us/rec/share/Wq3v8kT1"

LINK_HINT = "You can also drag a link in, or share it from another app."
