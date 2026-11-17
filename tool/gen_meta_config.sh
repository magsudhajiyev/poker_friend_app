#!/bin/sh
# Generates ios/Flutter/Meta.xcconfig from META_CLIENT_TOKEN in the repo-root
# .env (gitignored). Reads ONLY that one line and never prints the value.
# Called from ios/Podfile, so every `pod install` regenerates it.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/ios/Flutter/Meta.xcconfig"
# Fallback: a META_CLIENT_TOKEN already in the environment (CI).
TOKEN="${META_CLIENT_TOKEN:-}"
if [ -f "$ROOT/.env" ]; then
  FROM_ENV_FILE="$(grep -E '^META_CLIENT_TOKEN=' "$ROOT/.env" | head -n1 | cut -d= -f2- | tr -d '"'"'"' \r' || true)"
  [ -n "$FROM_ENV_FILE" ] && TOKEN="$FROM_ENV_FILE"
fi
printf 'META_CLIENT_TOKEN = %s\n' "$TOKEN" > "$OUT"
if [ -z "$TOKEN" ]; then
  echo "warning: META_CLIENT_TOKEN missing in .env; Meta.xcconfig is empty (Xcode build will fail)." >&2
fi
