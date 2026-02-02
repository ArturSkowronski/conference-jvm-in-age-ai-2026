package com.skowronski.talk.jvmai;

import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.PolyglotException;
import org.graalvm.polyglot.Value;

public final class GraalPyFromJava {
  public static void main(String[] args) {
    System.out.println("[GraalPy] ============================================================");
    System.out.println("[GraalPy] GraalPy Java Host Demo");
    System.out.println("[GraalPy] ============================================================");
    System.out.println("[GraalPy] Java: " + System.getProperty("java.version"));
    System.out.println("[GraalPy] VM: " + System.getProperty("java.vm.name"));
    System.out.println("[GraalPy] OS: " + System.getProperty("os.name") + " " + System.getProperty("os.arch"));
    System.out.println("[GraalPy] ============================================================");
    System.out.println();

    System.out.println("[GraalPy] Creating GraalPy context...");
    long startTime = System.currentTimeMillis();

    try (Context ctx = Context.newBuilder("python").build()) {
      long contextTime = System.currentTimeMillis() - startTime;
      System.out.println("[GraalPy] Context created in " + contextTime + "ms");

      System.out.println("[GraalPy] Evaluating: import sys; sys.version");
      Value version = ctx.eval("python", "import sys; sys.version");
      System.out.println("[GraalPy] python.version=" + version.asString());

      System.out.println("[GraalPy] Evaluating: 1.5 + 2.25");
      Value result = ctx.eval("python", "1.5 + 2.25");
      System.out.println("[GraalPy] Result: 1.5 + 2.25 = " + result.asDouble());

      long totalTime = System.currentTimeMillis() - startTime;
      System.out.println();
      System.out.println("[GraalPy] Demo completed successfully in " + totalTime + "ms");
    } catch (PolyglotException e) {
      System.err.println("[GraalPy] ERROR: GraalPy not available at runtime.");
      System.err.println("[GraalPy] Make sure you're running with a GraalVM JDK that has GraalPy installed.");
      System.err.println("[GraalPy] Install with: gu install graalpy");
      System.err.println();
      throw e;
    }
  }
}

