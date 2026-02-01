#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Setup SDKMAN environment to use Babylon with Code Reflection
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk use java babylon-26-code-reflection

echo "============================================================"
echo "Project Babylon Demo - Code Reflection API"
echo "============================================================"
echo ""

# Compile the Java source file with preview features enabled
echo "Compiling RuntimeCheck.java..."
javac -d . --enable-preview --add-modules jdk.incubator.code -source 26 RuntimeCheck.java

# Run the compiled Java class with preview features enabled
echo "Running RuntimeCheck..."
java --enable-preview --add-modules jdk.incubator.code demo.babylon.RuntimeCheck

echo ""
echo "============================================================"
echo "HAT MatMul Example - GPU Kernel in Java"
echo "============================================================"
echo ""

# Run HAT MatMul from Babylon repository
HAT_DIR="$HOME/Github/babylon/hat"
if [ -d "$HAT_DIR" ]; then
    cd "$HAT_DIR"

    # Build HAT if not already built
    if [ ! -d "build" ]; then
        echo "Building HAT..."
        java @hat/bld
    fi

    echo "Running HAT MatMul (2D tiling)..."
    echo ""
    java @hat/run ffi-opencl matmul 2DTILING
else
    echo "HAT directory not found at $HAT_DIR"
    echo "Please clone Babylon repository first:"
    echo "  git clone --branch code-reflection https://github.com/openjdk/babylon.git ~/Github/babylon"
fi
