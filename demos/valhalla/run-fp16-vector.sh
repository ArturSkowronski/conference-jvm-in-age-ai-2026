#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================================"
echo "FP16 Vector API Demo"
echo "============================================================"
echo

# Check JDK version
if ! command -v java &> /dev/null; then
    echo "Error: java not found in PATH"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
echo "Java version: $JAVA_VERSION"

if [ "$JAVA_VERSION" -lt 24 ]; then
    echo "Warning: This demo requires JDK 24+ for Float16 support"
    echo "Current version: $JAVA_VERSION"
    echo
    echo "To install JDK 25:"
    echo "  sdk list java | grep \"25\""
    echo "  sdk install java <version-identifier>"
    echo "  sdk use java <version-identifier>"
    exit 1
fi

echo

# Compile
echo "Compiling FP16VectorDemo.java..."
javac --add-modules jdk.incubator.vector FP16VectorDemo.java

# Run
echo
echo "Running FP16VectorDemo..."
echo
java --add-modules jdk.incubator.vector FP16VectorDemo

echo
echo "============================================================"
echo "Demo completed successfully!"
echo "============================================================"
