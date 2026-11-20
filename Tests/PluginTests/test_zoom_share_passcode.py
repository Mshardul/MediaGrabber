import calendar
import importlib.util
import json
import os
import socket
import tempfile
import unittest
from unittest import mock

from yt_dlp import YoutubeDL
from yt_dlp.extractor.common import InfoExtractor
from yt_dlp.extractor.zoom import ZoomIE as BaseZoomIE
from yt_dlp.utils import ExtractorError

PLUGIN_PATH = os.path.join(
    os.path.dirname(__file__),
    "..",
    "..",
    "Resources",
    "YtDlpPlugins",
    "zoomfix",
    "yt_dlp_plugins",
    "extractor",
    "zoom_share_passcode.py",
)

SHARE_URL = "https://example.zoom.us/rec/share/TOKEN.ABC"
BASE = "https://example.zoom.us/"


def setUpModule():
    def refuse(*args, **kwargs):
        raise AssertionError("plugin tests must never open a network connection")

    patcher = mock.patch.object(socket.socket, "connect", refuse)
    patcher.start()
    unittest.addModuleCleanup(patcher.stop)


def load_plugin():
    spec = importlib.util.spec_from_file_location("zoom_share_passcode_under_test", PLUGIN_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PacingTests(unittest.TestCase):
    def setUp(self):
        self.plugin = load_plugin()
        self.state = tempfile.NamedTemporaryFile(delete=False)
        self.state.close()
        self.addCleanup(os.unlink, self.state.name)
        self.sleeps = []
        self.clock = [1000.0]

    def pace(self):
        self.plugin._pace(
            now=lambda: self.clock[0],
            sleep=lambda seconds: (self.sleeps.append(seconds), self._advance(seconds)),
            path=self.state.name,
            gap=5.0,
        )

    def _advance(self, seconds):
        self.clock[0] += seconds

    def test_second_request_with_no_gap_sleeps_five_seconds(self):
        self.pace()
        self.pace()
        self.assertEqual(self.sleeps, [5.0])

    def test_request_after_the_gap_does_not_sleep(self):
        self.pace()
        self.clock[0] += 6.0
        self.pace()
        self.assertEqual(self.sleeps, [])

    def test_recorded_time_in_the_future_sleeps_at_most_the_gap(self):
        with open(self.state.name, "w") as handle:
            handle.write(repr(self.clock[0] + 3600))
        self.pace()
        self.assertEqual(self.sleeps, [5.0])

    def test_unreadable_state_counts_as_never(self):
        with open(self.state.name, "w") as handle:
            handle.write("not a number")
        self.pace()
        self.assertEqual(self.sleeps, [])

    def test_real_clock_calls_are_never_closer_than_the_gap(self):
        stamps = []
        import time as real_time

        for _ in range(3):
            self.plugin._pace(path=self.state.name, gap=0.2)
            stamps.append(real_time.time())
        gaps = [later - earlier for earlier, later in zip(stamps, stamps[1:])]
        self.assertTrue(all(gap >= 0.19 for gap in gaps), gaps)

    def test_every_extractor_request_is_paced_before_it_is_sent(self):
        order = []
        for extractor in (self.plugin.ZoomIE, self.plugin.ZoomClipsIE):
            with (
                mock.patch.object(self.plugin, "_pace", lambda: order.append("pace")),
                mock.patch.object(
                    InfoExtractor, "_request_webpage", lambda *args, **kwargs: order.append("send")
                ),
            ):
                extractor(YoutubeDL({"quiet": True}))._request_webpage(
                    "https://example.zoom.us/x", "id"
                )
        self.assertEqual(order, ["pace", "send", "pace", "send"])


UNIFIED_PAGE = (
    "<html><script>window.__zm_unified_player__ = {\n"
    "enableUseCommonZak: false,\n"
    'apiDomain: "https://us06web.zoom.us",\n'
    'playInfoApi: "\\/nws\\/recording\\/2.0\\/share\\/UUID-1?pageType=web&startTime=5",\n'
    'featureConfigApi: "\\/nws\\/recording\\/2.0\\/share\\/UUID-1\\/feature-config?pageType=web"\n'
    "};</script></html>"
)
PLAY_URL = "https://ssrweb.zoom.us/replay02/2026/11/14/UUID-1/GMT20261114-121249_Recording_1920x1080.mp4"
LOCKED = {"status": True, "result": {"middlePageInfo": {"pageType": "verifyPasscode"}}}
UNLOCKED = {
    "status": True,
    "result": {
        "mediaInfo": {
            "mediaTopic": "Business Valuation",
            "mediaDuration": 14804,
            "createdTime": 1794658367000,
            "ownerName": "EMBA Office",
            "playUrl": PLAY_URL + "?sig=1",
        }
    },
}


class FakeZoom:
    def __init__(self, plugin, passcode="secret", responses=None, verify=None, share_page=UNIFIED_PAGE):
        self.calls = []
        self.verify_body = None
        self.verify_headers = None
        self.responses = list(responses if responses is not None else [LOCKED, UNLOCKED])
        self.verify = {"status": True} if verify is None else verify
        self.share_page = share_page
        params = {"quiet": True, "no_warnings": True}
        if passcode is not None:
            params["videopassword"] = passcode
        self.ie = plugin.ZoomIE(YoutubeDL(params))
        self.ie._download_webpage = self.download_webpage
        self.ie._download_json = self.download_json

    def download_webpage(self, request, video_id, note=None, headers=None, **kwargs):
        url = getattr(request, "url", request)
        self.calls.append(url)
        if url == SHARE_URL:
            return self.share_page
        if "csrf_js" in url:
            return "ZOOM-CSRFTOKEN:TOKEN-1234"
        raise AssertionError(f"unexpected webpage request {url}")

    def download_json(self, url, video_id, note=None, data=None, headers=None, **kwargs):
        self.calls.append(url)
        if "verify-passcode" in url:
            self.verify_body = json.loads(data)
            self.verify_headers = headers
            return self.verify
        if "/nws/recording/2.0/share/UUID-1?" in url:
            return self.responses.pop(0)
        raise AssertionError(f"unexpected json request {url}")

    def count(self, fragment):
        return sum(1 for call in self.calls if fragment in call)


class ShareFlowTests(unittest.TestCase):
    def setUp(self):
        self.plugin = load_plugin()

    def test_passcode_flow_reads_the_recording_from_the_play_info(self):
        fake = FakeZoom(self.plugin)
        info = fake.ie._real_extract(SHARE_URL)
        self.assertEqual(info["id"], "TOKEN.ABC")
        self.assertEqual(info["title"], "GMT20261114-121249_Recording_1920x1080")
        self.assertEqual(info["duration"], 14804)
        self.assertEqual(info["timestamp"], calendar.timegm((2026, 11, 14, 12, 12, 49)))
        self.assertEqual([fmt["url"] for fmt in info["formats"]], [PLAY_URL + "?sig=1"])
        self.assertEqual(info["http_headers"], {"Referer": BASE})
        self.assertEqual((info["formats"][0]["width"], info["formats"][0]["height"]), (1920, 1080))

    def test_requests_go_to_the_api_domain_in_order(self):
        fake = FakeZoom(self.plugin)
        fake.ie._real_extract(SHARE_URL)
        api = "https://us06web.zoom.us/nws/recording/2.0/share/UUID-1"
        self.assertEqual(
            fake.calls,
            [
                SHARE_URL,
                f"{api}?pageType=web&startTime=5",
                f"{BASE}csrf_js?t_x_zm_rid=1",
                f"{api}/verify-passcode?pageType=web&startTime=5",
                f"{api}?pageType=web&startTime=5",
            ],
        )

    def test_passcode_is_sent_as_json_with_the_csrf_token(self):
        fake = FakeZoom(self.plugin, passcode="-ab c+")
        fake.ie._real_extract(SHARE_URL)
        self.assertEqual(fake.verify_body, {"passwd": "-ab c+"})
        self.assertEqual(fake.verify_headers["zoom-csrftoken"], "TOKEN-1234")

    def test_missing_passcode_raises_the_stock_sentence_without_verifying(self):
        fake = FakeZoom(self.plugin, passcode=None)
        with self.assertRaisesRegex(ExtractorError, "protected by a passcode"):
            fake.ie._real_extract(SHARE_URL)
        self.assertEqual(fake.count("verify-passcode"), 0)

    def test_rejected_passcode_raises_once_and_sends_one_attempt(self):
        fake = FakeZoom(self.plugin, verify={"status": False, "errorCode": 3302, "errorMessage": "Wrong passcode", "result": None})
        with self.assertRaisesRegex(ExtractorError, "Zoom rejected the passcode"):
            fake.ie._real_extract(SHARE_URL)
        self.assertEqual(fake.count("verify-passcode"), 1)

    def test_recording_without_a_passcode_skips_csrf_and_verify(self):
        fake = FakeZoom(self.plugin, passcode=None, responses=[UNLOCKED])
        info = fake.ie._real_extract(SHARE_URL)
        self.assertEqual(info["title"], "GMT20261114-121249_Recording_1920x1080")
        self.assertEqual(fake.count("csrf_js"), 0)
        self.assertEqual(fake.count("verify-passcode"), 0)

    def test_expired_recording_says_no_longer_available(self):
        gone = {"status": False, "errorMessage": "This recording has expired.", "result": {}}
        fake = FakeZoom(self.plugin, passcode=None, responses=[gone])
        with self.assertRaisesRegex(ExtractorError, "This Zoom recording is no longer available"):
            fake.ie._real_extract(SHARE_URL)

    def test_play_info_with_no_recording_and_no_message_says_zoom_changed(self):
        fake = FakeZoom(self.plugin, passcode=None, responses=[{"status": True, "result": {}}])
        with self.assertRaisesRegex(ExtractorError, "Zoom changed how its recordings work"):
            fake.ie._real_extract(SHARE_URL)

    def test_a_topic_title_is_kept_when_the_file_name_has_no_zoom_pattern(self):
        media = {"mediaTopic": "Business Valuation", "playUrl": "https://ssrweb.zoom.us/x/video.mp4?s=1"}
        fake = FakeZoom(
            self.plugin, passcode=None, responses=[{"status": True, "result": {"mediaInfo": media}}]
        )
        self.assertEqual(fake.ie._real_extract(SHARE_URL)["title"], "Business Valuation")

    def test_title_and_timestamp_come_from_the_zoom_file_name_of_a_play_link(self):
        fake = FakeZoom(self.plugin)
        formats = [{"url": f"https://ssrweb.zoom.us/cmr/{name}.mp4?s=2", "preference": rank} for rank, name in enumerate(
            ["GMT20261031-105457_Recording_1760x900", "GMT20261031-105457_Recording_gallery_1920x1080"]
        )]
        stock_info = {"id": "file-id", "title": "Product & Brand Management", "formats": formats}
        with mock.patch.object(BaseZoomIE, "_real_extract", return_value=stock_info):
            info = fake.ie._real_extract("https://example.zoom.us/rec/play/ABC")
        self.assertEqual(info["title"], "GMT20261031-105457_Recording_gallery_1920x1080")
        self.assertEqual(info["timestamp"], calendar.timegm((2026, 10, 31, 10, 54, 57)))
        self.assertEqual(fake.calls, [])

    def test_zoom_error_page_for_a_missing_recording_says_no_longer_available(self):
        error_page = (
            '<html><div class="error-container"><span class="error-message">'
            " This recording does not exist. (3,301) </span></div></html>"
        )
        fake = FakeZoom(self.plugin, share_page=error_page)
        with self.assertRaisesRegex(ExtractorError, "This Zoom recording is no longer available"):
            fake.ie._real_extract(SHARE_URL)

    def test_page_with_no_player_and_no_error_message_says_zoom_changed(self):
        fake = FakeZoom(self.plugin, share_page="<html><body>nothing useful</body></html>")
        with self.assertRaisesRegex(ExtractorError, "Zoom changed how its recordings work"):
            fake.ie._real_extract(SHARE_URL)


if __name__ == "__main__":
    unittest.main()
