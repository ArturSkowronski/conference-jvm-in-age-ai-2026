# Babylon Demo - Code Reflection API

Demonstrates Project Babylon's Code Reflection capabilities for runtime code introspection.

## Quick Start

```bash
./gradlew :demos:babylon:run
```

**Expected output (with Babylon JDK):**
```
=== JDK Runtime Information ===
Java Version:    26-internal
Java Vendor:     Oracle Corporation
Runtime Name:    OpenJDK Runtime Environment
Code Reflection Module Present: true
✅ Babylon Code Reflection API available
```

**Expected output (without Babylon JDK - standard JDK 25):**
```
=== JDK Runtime Information ===
Java Version:    25.0.2
Java Vendor:     Eclipse Adoptium
Code Reflection Module Present: false
⚠️  Babylon Code Reflection API not available
This is expected with standard JDK builds
```

## What This Demo Shows

- **Runtime JDK detection** - Shows which JDK is running
- **Module introspection** - Checks for Babylon-specific modules
- **Code Reflection availability** - Detects if `jdk.incubator.code` is present
- **Graceful degradation** - Works with any JDK 25+

## Requirements

**For full Babylon features:**
- Custom Babylon JDK build from https://jdk.java.net/babylon/
- Code Reflection module included

**For basic demo:**
- Any JDK 25+ (shows Code Reflection is not available)

## Running

```bash
# Check runtime environment
./gradlew :demos:babylon:run

# Smoke test (same)
./gradlew :demos:babylon:runSmoke
```

## Results

**With Babylon JDK:**
- ✅ Code Reflection: Available
- Shows `jdk.incubator.code` module
- Can introspect code at runtime

**With Standard JDK:**
- ⚠️ Code Reflection: Not available
- Expected behavior
- Demo still runs (just shows it's missing)

## Code Structure

```
demos/babylon/
├── src/main/java/com/skowronski/talk/jvmai/
│   └── RuntimeCheck.java        # Module detection (compiles)
├── HatMatMul.java               # HAT example (reference only, requires Babylon JDK)
├── build.gradle.kts             # Gradle build
├── .sdkmanrc                    # Notes about Babylon JDK
├── README.md                    # This file
└── Findings.md                  # Babylon/HAT analysis
```

**Note:** HatMatMul.java is a reference example from the Babylon project. It requires the full Babylon JDK with HAT framework and cannot be compiled with standard JDK. See [docs/Babylon workflow.md](../../docs/Babylon%20workflow.md) for details.

## Installing Babylon JDK

To test with actual Babylon features:

```bash
# Download Babylon JDK
curl -O https://download.java.net/java/early_access/babylon/latest/openjdk-<version>_bin.tar.gz

# Extract and set JAVA_HOME
tar -xzf openjdk-*.tar.gz
export JAVA_HOME=$PWD/jdk-<version>

# Run demo
$JAVA_HOME/bin/java --enable-preview --add-modules=jdk.incubator.code \
  -cp build/classes/java/main com.skowronski.talk.jvmai.RuntimeCheck
```

## See Also

- **[Findings.md](Findings.md)** - Babylon and HAT technical analysis
- **[docs/Babylon workflow.md](../../docs/Babylon%20workflow.md)** - HAT MatMul GPU example
- **`demos/valhalla/`** - Related research (Vector API)
