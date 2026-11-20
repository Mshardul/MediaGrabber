import calendar
import fcntl
import json
import os
import re
import tempfile
import time
from datetime import datetime

from yt_dlp.extractor.zoom import ZoomClipsIE as BaseZoomClipsIE
from yt_dlp.extractor.zoom import ZoomIE as BaseZoomIE
from yt_dlp.networking import Request
from yt_dlp.utils import (
    ExtractorError,
    int_or_none,
    parse_resolution,
    url_basename,
    urljoin,
)
from yt_dlp.utils.traversal import traverse_obj

PACING_SECONDS = 5.0
_PACING_STATE = os.path.join(tempfile.gettempdir(), "mediagrabber-zoom-pacing")


def _pace(now=time.time, sleep=time.sleep, path=_PACING_STATE, gap=PACING_SECONDS):
    with open(path, "a+") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0)
        try:
            last = float(handle.read() or 0)
        except ValueError:
            last = 0.0
        wait = min(gap, last + gap - now())
        if wait > 0:
            sleep(wait)
        handle.seek(0)
        handle.truncate()
        handle.write(repr(now()))
        handle.flush()


_GONE_PHRASES = ("does not exist", "expired", "deleted", "removed")


def _error_message(html):
    match = re.search(r'class="error-message"[^>]*>\s*([^<]*?)\s*</span>', html)
    if not match:
        return None
    return re.sub(r"\s*\(\d+(?:,\d+)*\)\s*$", "", match.group(1)).strip()


def _zoom_error(message):
    if message is None:
        return ExtractorError(
            "Zoom changed how its recordings work, so this link can't be read. "
            "MediaGrabber needs an update.",
            expected=True,
        )
    if any(phrase in message.lower() for phrase in _GONE_PHRASES):
        return ExtractorError("This Zoom recording is no longer available.", expected=True)
    return ExtractorError(f"Zoom could not show this recording: {message}", expected=True)


def _player_field(html, key):
    match = re.search(rf'window\.__zm_unified_player__\s*=\s*\{{.*?\b{key}:\s*"([^"]+)"', html, re.S)
    return match.group(1).replace("\\/", "/") if match else None


_ZOOM_FILE_NAME = re.compile(r"^(GMT(\d{8})-(\d{6})_[^/?#]+)\.mp4$")


# Every session of a course shares one meeting topic, so Zoom's own file name
# (unique per recording) names the file.
def _named_after_zoom_file(info):
    best = None
    for fmt in info.get("formats") or []:
        match = _ZOOM_FILE_NAME.match(url_basename(fmt.get("url") or ""))
        if match and (
            best is None or (fmt.get("preference") or 0) > (best[0].get("preference") or 0)
        ):
            best = (fmt, match)
    if best is None:
        return info
    info["title"] = best[1].group(1)
    try:
        started = datetime.strptime(best[1].group(2) + best[1].group(3), "%Y%m%d%H%M%S")
        info["timestamp"] = calendar.timegm(started.timetuple())
    except ValueError:
        pass
    return info


class _PacedMixin:
    def _request_webpage(self, *args, **kwargs):
        _pace()
        return super()._request_webpage(*args, **kwargs)


class ZoomClipsIE(_PacedMixin, BaseZoomClipsIE):
    pass


# Stock yt-dlp's zoom extractor still follows the retired share page, so share links are handled here.
class ZoomIE(_PacedMixin, BaseZoomIE):
    def _csrf_token(self, base_url, video_id):
        body = self._download_webpage(
            Request(f"{base_url}csrf_js?t_x_zm_rid=1", data=b"", headers={"FETCH-CSRF-TOKEN": "1"}),
            video_id,
            note="Downloading CSRF token",
        )
        return self._search_regex(r"ZOOM-CSRFTOKEN:([\w-]+)", body, "CSRF token")

    def _share_info(self, api_url, base_url, video_id, note):
        return self._download_json(api_url, video_id, note=note, headers={"Referer": base_url})

    def _verify_passcode(self, verify_url, base_url, video_id):
        passcode = self.get_param("videopassword")
        if not passcode:
            raise ExtractorError(
                "This video is protected by a passcode, use the --video-password option",
                expected=True,
            )
        validation = self._download_json(
            verify_url,
            video_id,
            note="Validating passcode",
            data=json.dumps({"passwd": passcode}).encode(),
            headers={
                "Referer": base_url,
                "Content-Type": "application/json",
                "zoom-csrftoken": self._csrf_token(base_url, video_id),
            },
        )
        if not validation.get("status"):
            raise ExtractorError("Zoom rejected the passcode", expected=True)

    def _real_extract(self, url):
        base_url, url_type, video_id = self._match_valid_url(url).group("base_url", "type", "id")
        if url_type != "share":
            return _named_after_zoom_file(super()._real_extract(url))

        webpage = self._download_webpage(url, video_id, note="Downloading share webpage")
        api_domain = _player_field(webpage, "apiDomain")
        play_path = _player_field(webpage, "playInfoApi")
        if not (api_domain and play_path):
            raise _zoom_error(_error_message(webpage))

        api_url = urljoin(api_domain, play_path)
        payload = self._share_info(api_url, base_url, video_id, "Downloading share info JSON")
        if traverse_obj(payload, ("result", "middlePageInfo", "pageType")) == "verifyPasscode":
            verify_url = urljoin(api_domain, play_path.replace("?", "/verify-passcode?", 1))
            self._verify_passcode(verify_url, base_url, video_id)
            payload = self._share_info(api_url, base_url, video_id, "Downloading recording JSON")
        media = traverse_obj(payload, ("result", "mediaInfo"), default={})
        if not media.get("playUrl"):
            raise _zoom_error(payload.get("errorMessage"))
        return _named_after_zoom_file(
            {
                "id": video_id,
                "title": media.get("mediaTopic") or video_id,
                "formats": [
                    {
                        "url": media["playUrl"],
                        "ext": "mp4",
                        **parse_resolution(url_basename(media["playUrl"])),
                    }
                ],
                "duration": int_or_none(media.get("mediaDuration")),
                "timestamp": int_or_none(media.get("createdTime"), scale=1000),
                "uploader": media.get("ownerName"),
                "http_headers": {"Referer": base_url},
            }
        )
