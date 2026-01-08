#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/tornado"
SRC_DIR="$ROOT_DIR/src/tornado/java"

if [[ -n "${TORNADO_SDK:-}" ]]; then
  JAVA_BIN="$TORNADO_SDK/bin/java"
  JAVAC_BIN="$TORNADO_SDK/bin/javac"
else
  JAVA_BIN="${JAVA_HOME:-}/bin/java"
  JAVAC_BIN="${JAVA_HOME:-}/bin/javac"
fi

if [[ ! -x "$JAVAC_BIN" || ! -x "$JAVA_BIN" ]]; then
  echo "Nie znaleziono TornadoVM JDK. Ustaw TORNADO_SDK (np. ~/sdkman/candidates/java/<tornadovm>/) albo JAVA_HOME na TornadoVM." >&2
  exit 2
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/mods"

find "$SRC_DIR" -name "*.java" > "$BUILD_DIR/sources.txt"

set +e
"$JAVAC_BIN" -d "$BUILD_DIR/mods/demo.tornadovm" @"$BUILD_DIR/sources.txt"
STATUS=$?
set -e

if [[ $STATUS -ne 0 ]]; then
  echo "" >&2
  echo "Kompilacja nie powiodła się. Najczęstsza przyczyna: uruchamiasz zwykły JDK zamiast TornadoVM (brak modułu tornado.api)." >&2
  exit $STATUS
fi

exec "$JAVA_BIN" --module-path "$BUILD_DIR/mods" -m demo.tornadovm/demo.tornadovm.VectorAddTornado "$@"

