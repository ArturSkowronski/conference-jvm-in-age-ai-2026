import platform
import sys
import time


def main() -> None:
    print("hello from GraalPy")
    print(f"python: {sys.version.splitlines()[0]}")
    print(f"executable: {sys.executable}")
    print(f"platform: {platform.platform()}")

    n = 2_000_000
    t0 = time.time()
    s = sum(range(n))
    t1 = time.time()
    print(f"sum(0..{n-1}) = {s} (took {(t1 - t0):.3f}s)")


if __name__ == "__main__":
    main()
