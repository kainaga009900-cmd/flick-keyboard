#!/usr/bin/env bash
# 使い方: bash scripts/ci-wait.sh core-tests.yml
# いまの HEAD で動いたワークフローを見つけて、終わるまで待つ。失敗したらログの最後を表示して exit 1。
set -euo pipefail
WF="$1"
SHA=$(git rev-parse HEAD)
ID=""
for _ in $(seq 1 60); do
  ID=$(gh run list --workflow "$WF" --commit "$SHA" --limit 1 --json databaseId --jq '.[0].databaseId // empty')
  [ -n "$ID" ] && break
done
if [ -z "$ID" ]; then
  echo "ワークフロー $WF がまだ始まっていません。少し待ってからもう一度実行してください。"
  exit 2
fi
if gh run watch "$ID" --exit-status --interval 10 > /dev/null; then
  echo "PASS: $WF ($ID)"
else
  gh run view "$ID" --log-failed | tail -80
  echo "FAIL: $WF ($ID)"
  exit 1
fi
