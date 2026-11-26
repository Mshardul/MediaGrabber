#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$(pwd)"
out="${MG_TOOLS_OUT:-$root}"
lock="${MG_TOOLS_LOCK:-$root/scripts/tools.lock}"
cache="$("$root/scripts/tool-cache.sh" dir)"
ffmpeg_archive="$("$root/scripts/tool-cache.sh" file ffmpeg)"
lame_archive="$("$root/scripts/tool-cache.sh" file lame)"
shield_archive="$("$root/scripts/tool-cache.sh" file shield-source)"
tools="$out/Resources/Tools"
shield="$out/Resources/Shield"
licenses="$out/Resources/Licenses"
mkdir -p "$cache" "$tools" "$shield" "$licenses"

field() {
    awk -v name="$1" '$1 == name { print $2 }' "$lock"
}
url_of() {
    awk -v name="$1" '$1 == name { print $3 }' "$lock"
}
sha_of() {
    awk -v name="$1" '$1 == name { print $4 }' "$lock"
}
has() {
    [ -n "$(field "$1")" ]
}

fetch() {
    local name="$1" dest="$2"
    local url sha
    url="$(url_of "$name")"
    sha="$(sha_of "$name")"
    if [ ! -f "$dest" ] || ! printf '%s  %s\n' "$sha" "$dest" | shasum -a 256 -c - >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$dest.partial" "$url"
        mv "$dest.partial" "$dest"
    fi
    printf '%s  %s\n' "$sha" "$dest" | shasum -a 256 -c -
}

# Writes one member of a pinned archive to a license text, without unpacking the whole archive.
license_from_archive() {
    local archive="$1" pattern="$2" dest="$3" member
    member="$(tar -tf "$archive" | grep -E "$pattern\$" | head -1)"
    [ -n "$member" ] || return 1
    tar -xOf "$archive" "$member" >"$dest"
}

if has yt-dlp; then
    fetch yt-dlp "$cache/yt-dlp_macos"
    cp "$cache/yt-dlp_macos" "$tools/yt-dlp"
    chmod 755 "$tools/yt-dlp"
fi

if has node; then
    fetch node "$cache/node.tar.gz"
    if [ ! -x "$tools/node" ] || [ "$cache/node.tar.gz" -nt "$tools/node" ]; then
        rm -rf "$cache/node"
        mkdir -p "$cache/node"
        tar -xzf "$cache/node.tar.gz" -C "$cache/node" --strip-components=1
        cp "$cache/node/bin/node" "$tools/node"
        chmod 755 "$tools/node"
    fi
fi

if has shield-plugin; then
    fetch shield-plugin "$shield/plugin.zip"
fi

if has ffmpeg && has lame; then
    stamp="$tools/.ffmpeg-source"
    ffmpeg_sha="$(sha_of ffmpeg)"
    if [ ! -x "$tools/ffmpeg" ] || [ ! -x "$tools/ffprobe" ] || [ "$(cat "$stamp" 2>/dev/null || true)" != "$ffmpeg_sha" ]; then
        fetch lame "$lame_archive"
        fetch ffmpeg "$ffmpeg_archive"
        rm -rf "$cache/lame-src" "$cache/ffmpeg-src" "$cache/lame-prefix"
        mkdir -p "$cache/lame-src" "$cache/ffmpeg-src" "$cache/lame-prefix"
        tar -xzf "$lame_archive" -C "$cache/lame-src" --strip-components=1
        tar -xJf "$ffmpeg_archive" -C "$cache/ffmpeg-src" --strip-components=1
        (
            cd "$cache/lame-src"
            ./configure --disable-shared --enable-static --prefix="$cache/lame-prefix"
            make -j"$(sysctl -n hw.ncpu)"
            make install
        )
        (
            cd "$cache/ffmpeg-src"
            ./configure \
                --disable-gpl \
                --disable-nonfree \
                --disable-shared \
                --enable-static \
                --disable-x86asm \
                --enable-libmp3lame \
                --pkg-config-flags=--static \
                --extra-cflags="-I$cache/lame-prefix/include" \
                --extra-ldflags="-L$cache/lame-prefix/lib" \
                --prefix="$cache/ffmpeg-prefix"
            make -j"$(sysctl -n hw.ncpu)"
        )
        cp "$cache/ffmpeg-src/ffmpeg" "$tools/ffmpeg"
        cp "$cache/ffmpeg-src/ffprobe" "$tools/ffprobe"
        chmod 755 "$tools/ffmpeg" "$tools/ffprobe"
        printf '%s\n' "$ffmpeg_sha" >"$stamp"
    fi
fi

if has shield-source; then
    fetch shield-source "$shield_archive"
    if [ ! -f "$shield/server/build/main.js" ] || [ ! -d "$shield/server/node_modules/express" ]; then
        rm -rf "$cache/shield-src"
        mkdir -p "$cache/shield-src"
        tar -xzf "$shield_archive" -C "$cache/shield-src" --strip-components=1
        export PATH="$cache/node/bin:$PATH"
        (
            cd "$cache/shield-src/server"
            npm ci
            npx tsc
            npm prune --omit=dev
            # canvas is optional for jsdom and tokens work without it; it drags in dozens of native libraries
            rm -rf node_modules/canvas
        )
        rm -rf "$shield/server"
        mkdir -p "$shield/server"
        cp -R "$cache/shield-src/server/build" "$shield/server/build"
        cp -R "$cache/shield-src/server/node_modules" "$shield/server/node_modules"
        cp "$cache/shield-src/server/package.json" "$shield/server/package.json"
    fi
fi

# License texts come from the pinned sources, so a shipped text always matches the shipped version.
if has yt-dlp-license; then
    fetch yt-dlp-license "$cache/yt-dlp-license"
    cp -f "$cache/yt-dlp-license" "$licenses/yt-dlp.txt"
fi
if has node; then
    license_from_archive "$cache/node.tar.gz" '/LICENSE$' "$licenses/node.txt"
fi
if has ffmpeg; then
    license_from_archive "$ffmpeg_archive" '/COPYING.LGPLv2.1$' "$licenses/ffmpeg.txt"
fi
if has lame; then
    license_from_archive "$lame_archive" '/COPYING$' "$licenses/lame.txt"
fi
if has shield-source; then
    license_from_archive "$shield_archive" '/LICENSE$' "$licenses/shield.txt"
fi
if has sparkle-license; then
    fetch sparkle-license "$cache/sparkle-license"
    cp -f "$cache/sparkle-license" "$licenses/sparkle.txt"
fi

for id in yt-dlp ffmpeg lame node shield sparkle; do
    case "$id" in
    yt-dlp) source="yt-dlp-license" ;;
    ffmpeg) source="ffmpeg" ;;
    lame) source="lame" ;;
    node) source="node" ;;
    shield) source="shield-source" ;;
    sparkle) source="sparkle-license" ;;
    esac
    if has "$source" && [ ! -s "$licenses/$id.txt" ]; then
        echo "missing license text: $id.txt" >&2
        exit 1
    fi
done
chmod 644 "$licenses"/*.txt
