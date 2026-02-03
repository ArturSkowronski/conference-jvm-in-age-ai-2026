#!/bin/bash
# Babylon demo runner - RuntimeCheck + HAT MatMul
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HAT_DIR="$HOME/Github/babylon/hat"
BABYLON_JDK="$HOME/.sdkman/candidates/java/babylon-26-code-reflection"

echo "============================================================"
echo "Project Babylon Demo - Code Reflection API"
echo "============================================================"
echo ""

# Task 1: Run RuntimeCheck via Gradle
echo "1. RuntimeCheck - Code Reflection Detection"
echo "------------------------------------------------------------"
cd "$PROJECT_ROOT"
./gradlew :demos:babylon:runtimeCheck

# Task 2: Run HAT MatMul if HAT is available
if [ -d "$HAT_DIR" ] && [ -d "$BABYLON_JDK" ]; then
  echo ""
  echo "============================================================"
  echo "2. HAT MatMul - GPU Matrix Multiplication"
  echo "============================================================"
  echo ""
  cd "$HAT_DIR"
  "$BABYLON_JDK/bin/java" @hat/run ffi-opencl matmul 2DTILING
else
  echo ""
  echo "HAT MatMul skipped (HAT not found at $HAT_DIR)"
  echo "To run HAT examples:"
  echo "  cd ~/Github/babylon/hat"
  echo "  java @hat/run ffi-opencl matmul 2DTILING"
fi
