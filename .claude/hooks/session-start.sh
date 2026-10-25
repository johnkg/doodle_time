#!/bin/bash
# Installs the Flutter SDK in Claude Code cloud sessions so analyze/test/build work.
# Mirrors CI: current stable SDK, platform folders from `flutter create .`, pub get.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_HOME="$HOME/flutter"
BASE_URL="https://storage.googleapis.com/flutter_infra_release/releases"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  archive=$(curl -fsSL "$BASE_URL/releases_linux.json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
h = d["current_release"]["stable"]
print(next(r["archive"] for r in d["releases"] if r["hash"] == h))')
  echo "Installing Flutter from $archive" >&2
  tmp=$(mktemp -d)
  curl -fsSL "$BASE_URL/$archive" -o "$tmp/flutter.tar.xz"
  tar -xJf "$tmp/flutter.tar.xz" -C "$HOME"
  rm -rf "$tmp"
fi

# The SDK archive is owned by another uid; git refuses it without this.
git config --global --get-all safe.directory | grep -qx "$FLUTTER_HOME" \
  || git config --global --add safe.directory "$FLUTTER_HOME"

export PATH="$FLUTTER_HOME/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

flutter config --no-analytics >/dev/null
flutter --disable-analytics >/dev/null 2>&1 || true

cd "$CLAUDE_PROJECT_DIR"
# Platform folders, analysis_options.yaml and pubspec.lock are gitignored; regenerate like CI.
if [ ! -d web ] || [ ! -f analysis_options.yaml ]; then
  flutter create . --platforms=web --project-name doodle_time >/dev/null
fi
flutter pub get
