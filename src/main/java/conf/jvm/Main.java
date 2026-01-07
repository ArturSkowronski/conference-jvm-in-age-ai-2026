package conf.jvm;

public final class Main {
  public static void main(String[] args) {
    System.out.println("Hello from Java!");
    System.out.println("java.version=" + System.getProperty("java.version"));
    System.out.println("java.vendor=" + System.getProperty("java.vendor"));
    System.out.println("java.vm.name=" + System.getProperty("java.vm.name"));
  }
}
