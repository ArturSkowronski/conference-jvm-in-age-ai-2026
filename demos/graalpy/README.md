# GraalPy demo

This folder contains a minimal, talk-friendly demo of:
- running Python on GraalVM (`graalpy`)
- using Java classes from Python (JVM mode)
- embedding Python in a Java app (Polyglot API)

## Prereqs

- GraalVM (JDK 21 recommended)
- GraalPy installed:

```bash
gu install graalpy
```

Optional (for the JS interop demo):

```bash
gu install js
```

Verify:

```bash
graalpy --version
```

## 1) Plain GraalPy

```bash
graalpy python/01_hello.py
```

## 2) Java from Python (JVM mode)

GraalPy can run in JVM mode to enable Java interop.

```bash
graalpy --jvm python/02_java_from_python.py
```

## 3) Polyglot from Python (call JS)

```bash
graalpy python/03_polyglot_api.py
```

## 4) Embed GraalPy in Java (Polyglot API)

Build + run using Gradle (will download compile-time dependencies):

```bash
./gradlew :demos:graalpy-java-host:run
```

Notes:
- Run the JVM (`java`) from GraalVM, so the Python engine is available at runtime.
- If you see `No language and polyglot implementation was found on the classpath`, you are likely running with a non-GraalVM JDK.
