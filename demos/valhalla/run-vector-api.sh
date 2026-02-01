#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================================"
echo "Vector API Demo (Float32)"
echo "============================================================"
echo

# Check JDK version
if ! command -v java &> /dev/null; then
    echo "Error: java not found in PATH"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
echo "Java version: $JAVA_VERSION"

if [ "$JAVA_VERSION" -lt 21 ]; then
    echo "Warning: This demo requires JDK 21+ for Vector API"
    echo "Current version: $JAVA_VERSION"
    exit 1
fi

echo

# Compile
echo "Compiling VectorAPIDemo.java..."
javac --add-modules jdk.incubator.vector VectorAPIDemo.java

# Run
echo
echo "Running VectorAPIDemo..."
echo
java --add-modules jdk.incubator.vector VectorAPIDemo

echo
echo "============================================================"
echo "Demo completed successfully!"
echo "============================================================"
