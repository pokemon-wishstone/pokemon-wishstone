#!/usr/bin/env bash
# Downloads the pinned Poryscript release binary into tools/poryscript/.
# The binary is gitignored; command_config.json and font_config.json are tracked
# in the repo and are NOT overwritten by this script.
#
# Usage (from the repo root):  tools/poryscript/install.sh
set -euo pipefail

VERSION="3.6.1"
DEST="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
    Darwin) PLATFORM="mac" ;;
    Linux)  PLATFORM="linux" ;;   # also WSL
    *)
        echo "Unsupported OS '$(uname -s)'. Download poryscript manually from" >&2
        echo "https://github.com/huderlem/poryscript/releases/tag/$VERSION into $DEST" >&2
        exit 1 ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/huderlem/poryscript/releases/download/$VERSION/poryscript-$PLATFORM.zip"
echo "Downloading $URL"
curl -fsSL "$URL" -o "$TMP/poryscript.zip"
unzip -q -j "$TMP/poryscript.zip" "poryscript-$PLATFORM/poryscript" -d "$TMP"
install -m 755 "$TMP/poryscript" "$DEST/poryscript"

echo "Installed poryscript $("$DEST/poryscript" -v) to $DEST/poryscript"
