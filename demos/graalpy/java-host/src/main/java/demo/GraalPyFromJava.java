package demo;

import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.PolyglotException;
import org.graalvm.polyglot.Value;

public final class GraalPyFromJava {
  public static void main(String[] args) {
    try (Context ctx = Context.newBuilder("python").build()) {
      Value version = ctx.eval("python", "import sys; sys.version");
      System.out.println("python.version=" + version.asString());

      Value result = ctx.eval("python", "1.5 + 2.25");
      System.out.println("1.5 + 2.25 = " + result.asDouble());
    } catch (PolyglotException e) {
      System.err.println("GraalPy not available at runtime.");
      System.err.println("Make sure you're running with a GraalVM JDK that has GraalPy installed (gu install graalpy).");
      System.err.println();
      throw e;
    }
  }
}

