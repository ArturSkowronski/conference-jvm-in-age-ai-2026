#!/bin/bash
set -e

# Setup SDKMAN environment to use the local babylon-27 JDK
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk use java babylon-27

# Compile the Java source file with preview features enabled
echo "Compiling RuntimeCheck.java..."
javac -d . --enable-preview -source 27 RuntimeCheck.java

# Run the compiled Java class with preview features enabled
echo "Running RuntimeCheck..."
java --enable-preview demo.babylon.RuntimeCheck
