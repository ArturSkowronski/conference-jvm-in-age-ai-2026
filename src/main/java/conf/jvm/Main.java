package conf.jvm;

import conf.jvm.jcuda.JCudaInfoDemo;

public final class Main {
  public static void main(String[] args) {
    if (args.length > 0) {
      switch (args[0]) {
        case "help", "--help", "-h" -> {
          printUsage();
          return;
        }
        case "jcuda", "jcuda-info" -> {
          JCudaInfoDemo.run();
          return;
        }
        default -> {
          System.err.println("Unknown command: " + args[0]);
          System.err.println();
          printUsage();
          System.exit(1);
          return;
        }
      }
    }

    System.out.println("Hello from Java!");
    System.out.println("java.version=" + System.getProperty("java.version"));
    System.out.println("java.vendor=" + System.getProperty("java.vendor"));
    System.out.println("java.vm.name=" + System.getProperty("java.vm.name"));
  }

  private static void printUsage() {
    System.out.println("Usage:");
    System.out.println("  gradle run");
    System.out.println("  gradle run --args='jcuda-info'");
  }
}
