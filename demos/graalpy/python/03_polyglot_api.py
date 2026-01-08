def main() -> None:
    import polyglot

    js = polyglot.eval(
        language="js",
        string="""
        (function () {
          const xs = [1, 2, 3, 4];
          return xs.map(x => x * 10).join(",");
        })()
        """,
    )
    print(f"JS result: {js}")


if __name__ == "__main__":
    main()
