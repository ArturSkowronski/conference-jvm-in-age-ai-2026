#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/baseline"
SRC_DIR="$ROOT_DIR/src/baseline/java"

JAVA_BIN="${JAVA_HOME:-}/bin/java"
JAVAC_BIN="${JAVA_HOME:-}/bin/javac"
if [[ ! -x "$JAVAC_BIN" ]]; then
  JAVA_BIN="java"
  JAVAC_BIN="javac"
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

find "$SRC_DIR" -name "*.java" > "$BUILD_DIR/sources.txt"
"$JAVAC_BIN" -d "$BUILD_DIR" @"$BUILD_DIR/sources.txt"

exec "$JAVA_BIN" -cp "$BUILD_DIR" demo.baseline.VectorAddBaseline "$@"

