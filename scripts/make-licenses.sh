#!/usr/bin/env bash
# アプリに組み込む部品のライセンス全文を App/Licenses.txt にまとめる。
# 部品: 変換エンジン、辞書、エンジンが使う Apple / 外部のライブラリ（絵文字辞書は組み込まない）
set -euo pipefail
OUT=App/Licenses.txt
{
  echo "このアプリは次のオープンソースソフトウェアを使っています。"
  echo
} > "$OUT"
for spec in \
  "AzooKeyKanaKanjiConverter|azooKey/AzooKeyKanaKanjiConverter" \
  "azooKey_dictionary_storage|azooKey/azooKey_dictionary_storage" \
  "swift-algorithms|apple/swift-algorithms" \
  "swift-collections|apple/swift-collections" \
  "swift-numerics|apple/swift-numerics" \
  "swift-tokenizers|ensan-hcl/swift-tokenizers" \
  "Jinja|johnmai-dev/Jinja"; do
  name=${spec%%|*}
  repo=${spec##*|}
  {
    echo "=================================================="
    echo "$name  https://github.com/$repo"
    echo "=================================================="
    gh api "repos/$repo/license" --jq '.content' | base64 -d
    echo
  } >> "$OUT"
done
echo "作りました: $OUT"
