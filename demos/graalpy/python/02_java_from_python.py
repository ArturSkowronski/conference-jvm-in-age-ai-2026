import sys


def main() -> None:
    print("Java interop demo (requires: graalpy --jvm ...)")
    print(f"python: {sys.version.splitlines()[0]}")

    from java.lang import System
    from java.util import ArrayList, HashMap

    System.out.println("Hello from java.lang.System.out")

    xs = ArrayList()
    xs.add("alpha")
    xs.add("beta")
    xs.add("gamma")
    print(f"ArrayList size: {xs.size()}")
    print(f"ArrayList[1]: {xs.get(1)}")

    m = HashMap()
    m.put("language", "python")
    m.put("vm", "graalvm")
    print(f"HashMap['vm']: {m.get('vm')}")


if __name__ == "__main__":
    main()
