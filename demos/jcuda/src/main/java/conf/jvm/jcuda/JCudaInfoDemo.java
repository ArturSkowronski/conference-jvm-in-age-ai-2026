package conf.jvm.jcuda;

import java.nio.charset.StandardCharsets;
import jcuda.driver.CUdevice;
import jcuda.driver.JCudaDriver;

import static jcuda.driver.JCudaDriver.cuDeviceComputeCapability;
import static jcuda.driver.JCudaDriver.cuDeviceGet;
import static jcuda.driver.JCudaDriver.cuDeviceGetCount;
import static jcuda.driver.JCudaDriver.cuDeviceGetName;
import static jcuda.driver.JCudaDriver.cuDriverGetVersion;
import static jcuda.driver.JCudaDriver.cuInit;

public final class JCudaInfoDemo {
  private JCudaInfoDemo() {}

  public static void main(String[] args) {
    run();
  }

  public static void run() {
    System.out.println("[JCuda] ============================================================");
    System.out.println("[JCuda] JCuda Device Info Demo");
    System.out.println("[JCuda] ============================================================");
    System.out.println("[JCuda] os.name=" + System.getProperty("os.name"));
    System.out.println("[JCuda] os.arch=" + System.getProperty("os.arch"));
    System.out.println("[JCuda] java.version=" + System.getProperty("java.version"));
    System.out.println("[JCuda] java.vm.name=" + System.getProperty("java.vm.name"));
    System.out.println("[JCuda] ============================================================");
    System.out.println();

    try {
      System.out.println("[JCuda] Enabling JCuda exceptions...");
      JCudaDriver.setExceptionsEnabled(true);

      System.out.println("[JCuda] Initializing CUDA driver (cuInit)...");
      long startTime = System.currentTimeMillis();
      cuInit(0);
      System.out.println("[JCuda] CUDA driver initialized in " + (System.currentTimeMillis() - startTime) + "ms");

      System.out.println("[JCuda] Getting driver version...");
      int[] driverVersion = {0};
      cuDriverGetVersion(driverVersion);
      System.out.println("[JCuda] cuda.driverVersion=" + driverVersion[0]);

      System.out.println("[JCuda] Counting CUDA devices...");
      int[] deviceCountArr = {0};
      cuDeviceGetCount(deviceCountArr);
      int deviceCount = deviceCountArr[0];
      System.out.println("[JCuda] cuda.deviceCount=" + deviceCount);

      for (int i = 0; i < deviceCount; i++) {
        System.out.println("[JCuda] Querying device " + i + "...");
        CUdevice device = new CUdevice();
        cuDeviceGet(device, i);

        byte[] nameBytes = new byte[1024];
        cuDeviceGetName(nameBytes, nameBytes.length, device);
        String name = cString(nameBytes);

        int[] major = {0};
        int[] minor = {0};
        cuDeviceComputeCapability(major, minor, device);

        System.out.println("[JCuda] cuda.device[" + i + "].name=" + name);
        System.out.println("[JCuda] cuda.device[" + i + "].computeCapability=" + major[0] + "." + minor[0]);
      }

      System.out.println();
      System.out.println("[JCuda] Demo completed successfully!");

    } catch (Throwable t) {
      Throwable root = rootCause(t);
      System.err.println("[JCuda] ERROR: " + root.getClass().getName() + ": " + root.getMessage());
      System.err.println();
      System.err.println("[JCuda] Requirements:");
      System.err.println("[JCuda] - NVIDIA CUDA driver installed (nvidia-smi should work)");
      System.err.println("[JCuda] - Matching native JCuda binaries for your OS/arch");
      throw new RuntimeException("JCuda initialization failed", t);
    }
  }

  private static Throwable rootCause(Throwable t) {
    Throwable current = t;
    while (current.getCause() != null && current.getCause() != current) {
      current = current.getCause();
    }
    return current;
  }

  private static String cString(byte[] bytes) {
    int len = 0;
    while (len < bytes.length && bytes[len] != 0) {
      len++;
    }
    return new String(bytes, 0, len, StandardCharsets.UTF_8);
  }
}
