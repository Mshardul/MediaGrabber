#!/usr/bin/env python3
"""A tiny fixture server for the release tests and the end-to-end run.

Serves one directory, answers HEAD and single-range requests, and can redirect
paths, so the release scripts can be exercised without the internet.

Usage: fixture-server.py --root DIR [--port N] [--redirect FROM=TO]...
Prints: listening http://127.0.0.1:<port>
"""

import argparse
import http.server
import os
import re
import socketserver
import sys

RANGE = re.compile(r"^bytes=(\d*)-(\d*)$")


class FixtureHandler(http.server.SimpleHTTPRequestHandler):
    server_version = "FixtureServer/1.0"

    def log_message(self, fmt, *args):
        return

    def _redirect_target(self):
        return self.server.redirects.get(self.path)

    def do_HEAD(self):
        target = self._redirect_target()
        if target:
            self.send_response(302)
            self.send_header("Location", target)
            self.end_headers()
            return
        path = self.translate_path(self.path)
        if not os.path.isfile(path):
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(os.path.getsize(path)))
        self.end_headers()

    def do_GET(self):
        target = self._redirect_target()
        if target:
            self.send_response(302)
            self.send_header("Location", target)
            self.end_headers()
            return
        path = self.translate_path(self.path)
        if not os.path.isfile(path):
            self.send_error(404)
            return
        size = os.path.getsize(path)
        header = self.headers.get("Range")
        match = RANGE.match(header) if header else None
        if not match:
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(size))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            with open(path, "rb") as handle:
                self.wfile.write(handle.read())
            return
        start_text, end_text = match.groups()
        start = int(start_text) if start_text else 0
        end = int(end_text) if end_text else size - 1
        end = min(end, size - 1)
        if start > end:
            self.send_error(416)
            return
        length = end - start + 1
        self.send_response(206)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(length))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Accept-Ranges", "bytes")
        self.end_headers()
        with open(path, "rb") as handle:
            handle.seek(start)
            self.wfile.write(handle.read(length))


class FixtureServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--redirect", action="append", default=[])
    args = parser.parse_args(argv)

    redirects = {}
    for entry in args.redirect:
        source, _, target = entry.partition("=")
        redirects[source] = target

    os.chdir(args.root)
    with FixtureServer(("127.0.0.1", args.port), FixtureHandler) as httpd:
        httpd.redirects = redirects
        port = httpd.server_address[1]
        print(f"listening http://127.0.0.1:{port}", flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
