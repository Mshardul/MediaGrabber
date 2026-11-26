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
    update_url_query,
    url_basename,
    urlencode_postdata,
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
    # The video download follows at once and does not pass through the extractor, so wait before handing it over.
    def _ready_to_download(self, info):
        if not (self.get_param("simulate") or self.get_param("skip_download")):
            _pace()
        return _named_after_zoom_file(info)

    def _csrf_token(self, base_url, video_id):
        body = self._download_webpage(
            Request(f"{base_url}csrf_js?t_x_zm_rid=1", data=b"", headers={"FETCH-CSRF-TOKEN": "1"}),
            video_id,
            note="Downloading CSRF token",
        )
        return self._search_regex(r"ZOOM-CSRFTOKEN:([\w-]+)", body, "CSRF token")

    def _share_info(self, api_url, base_url, video_id, note):
        return self._download_json(api_url, video_id, note=note, headers={"Referer": base_url})

    def _required_passcode(self):
        passcode = self.get_param("videopassword")
        if not passcode:
            raise ExtractorError(
                "This video is protected by a passcode, use the --video-password option",
                expected=True,
            )
        return passcode

    def _verify_passcode(self, verify_url, base_url, video_id):
        passcode = self._required_passcode()
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

    def _data_page_share_info(self, base_url, meeting_id, video_id):
        domain = base_url.split("//", 1)[1].strip("/")
        payload = self._download_json(
            f"{base_url}nws/recording/1.0/play/share-info/{meeting_id}"
            f"?originDomain={domain}&accessLevel=meeting",
            video_id,
            note="Downloading share info JSON",
            headers={"X-Requested-With": "XMLHttpRequest"},
        )
        result = traverse_obj(payload, ("result", {dict}))
        if not (result and result.get("redirectUrl")):
            raise _zoom_error(payload.get("errorMessage"))
        return result

    def _redirect_target(self, base_url, result, origin_url=None):
        redirect = urljoin(base_url, result["redirectUrl"])
        if "?" in redirect:
            return redirect
        query = {
            key: value
            for key, value in result.items()
            if isinstance(value, str) and key != "redirectUrl"
        }
        if origin_url:
            query["originRequestUrl"] = origin_url
        return update_url_query(redirect, query) if query else redirect

    # One attempt per run: a lockout from repeated guesses cannot be undone.
    def _unlock_data_page(self, base_url, share_url, result, video_id):
        passcode = self._required_passcode()
        component_url = self._redirect_target(base_url, result, origin_url=share_url)
        component = self._download_webpage(
            component_url, video_id, note="Downloading passcode page", headers={"Referer": share_url}
        )
        data = self._get_page_data(component, video_id)
        if data.get("needRecaptcha") in (True, "true"):
            raise ExtractorError(
                "Zoom is asking to confirm you're not a bot. "
                "Open the link in your browser once, then try again.",
                expected=True,
            )
        headers = {
            "zoom-csrftoken": self._csrf_token(base_url, video_id),
            "X-Requested-With": "XMLHttpRequest",
            "Referer": component_url,
        }
        self._download_json(
            f"{base_url}nws/recording/1.0/validate-context",
            video_id,
            note="Validating context",
            data=urlencode_postdata(
                {
                    "meetingId": data["meeting_id"],
                    "fileId": data["fileId"],
                    "useWhichPasswd": data["useWhichPasswd"],
                    "sharelevel": data["sharelevel"],
                    "iet": "",
                }
            ),
            headers=headers,
        )
        validation = self._download_json(
            f"{base_url}nws/recording/1.0/validate-meeting-passwd",
            video_id,
            note="Validating passcode",
            data=urlencode_postdata(
                {
                    "id": data["meeting_id"],
                    "passwd": passcode,
                    "action": data["action"],
                    "recaptcha": "",
                }
            ),
            headers=headers,
        )
        if not validation.get("status"):
            raise ExtractorError("Zoom rejected the passcode", expected=True)
        return data["meeting_id"]

    def _extract_data_page(self, share_url, webpage, base_url, video_id):
        meeting_id = self._get_page_data(webpage, video_id).get("meetingId")
        if not meeting_id:
            raise _zoom_error(_error_message(webpage))
        result = self._data_page_share_info(base_url, meeting_id, video_id)
        if result.get("componentName") == "need-password":
            meeting_id = self._unlock_data_page(base_url, share_url, result, video_id)
            result = self._data_page_share_info(base_url, meeting_id, video_id)
        play_url = self._redirect_target(base_url, result)
        if "/rec/play/" not in play_url:
            self.write_debug(f"share info component: {result.get('componentName')}")
            raise _zoom_error(None)
        info = super()._real_extract(play_url)
        info["id"] = video_id
        return info

    def _real_extract(self, url):
        base_url, url_type, video_id = self._match_valid_url(url).group("base_url", "type", "id")
        if url_type != "share":
            return self._ready_to_download(super()._real_extract(url))

        webpage = self._download_webpage(url, video_id, note="Downloading share webpage")
        api_domain = _player_field(webpage, "apiDomain")
        play_path = _player_field(webpage, "playInfoApi")
        if not (api_domain and play_path):
            if "window.__data__" in webpage:
                return self._ready_to_download(
                    self._extract_data_page(url, webpage, base_url, video_id)
                )
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
        return self._ready_to_download(
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
