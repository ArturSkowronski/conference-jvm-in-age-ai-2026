# Babylon Runtime Check

This directory contains a simple script to verify the local `babylon-27` JDK environment.

**Note:** The current local build of `babylon-27` (`27-internal-adhoc.askowronski.babylon`) **does not** appear to contain the Code Reflection API (`jdk.incubator.code` or `java.lang.reflect.code`).

## Missing Modules
The following modules required for [Babylon HAT demos](https://openjdk.org/projects/babylon/articles/hat-matmul/hat-matmul) are missing from this build:
- `jdk.incubator.code`
- `java.lang.reflect.code`

## Usage
Run the check script:
```bash
./run-babylon.sh
```
