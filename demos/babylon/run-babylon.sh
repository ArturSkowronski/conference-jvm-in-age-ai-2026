#!/bin/bash
# Simplified Babylon demo runner - now uses Gradle
# For HAT MatMul examples, see: ~/Github/babylon/hat/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "============================================================"
echo "Project Babylon Demo - Code Reflection API"
echo "============================================================"
echo ""

# Run RuntimeCheck via Gradle (uses Babylon JDK from .sdkmanrc)
cd "$PROJECT_ROOT"
./gradlew :demos:babylon:run

echo ""
echo "For HAT MatMul GPU examples, run directly from HAT repository:"
echo "  cd ~/Github/babylon/hat"
echo "  java @hat/run ffi-opencl matmul 2DTILING"
