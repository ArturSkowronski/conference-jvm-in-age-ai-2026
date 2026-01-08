package demo;

import java.util.List;
import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.Value;

public final class GraalPyFromJava {
  public static void main(String[] args) {
    try (Context context =
        Context.newBuilder("python").allowAllAccess(true).build()) {

      context.eval(
          "python",
          ""
              + "def greet(name):\n"
              + "    return f'hello, {name} (from python)'\n"
              + "\n"
              + "def scale(xs, k):\n"
              + "    return [x * k for x in xs]\n");

      Value bindings = context.getBindings("python");
      Value greet = bindings.getMember("greet");
      Value scale = bindings.getMember("scale");

      System.out.println(greet.execute("JVM").asString());

      List<Integer> input = List.of(1, 2, 3, 4);
      Value out = scale.execute(input, 10);
      System.out.println("scale([1,2,3,4], 10) -> " + out.toString());
    }
  }
}
