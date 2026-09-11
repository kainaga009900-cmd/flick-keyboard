#!/usr/bin/env bash
# azooKey の辞書（Apache-2.0）を、エンジン v0.11.2 と同じコミットで Vendor/ に取ってくる。
set -euo pipefail
SHA=832fbb0d3039dfaa4b2183956f3d96f6b07eec4d
DEST=Vendor/azooKey_dictionary_storage
if [ -d "$DEST/Dictionary" ]; then
  echo "辞書はもうあります: $DEST"
  exit 0
fi
rm -rf "$DEST"
mkdir -p "$DEST"
git -C "$DEST" init -q
git -C "$DEST" remote add origin https://github.com/azooKey/azooKey_dictionary_storage
git -C "$DEST" fetch -q --depth 1 origin "$SHA"
git -C "$DEST" checkout -q FETCH_HEAD
test -d "$DEST/Dictionary"
echo "辞書を取ってきました: $DEST"
