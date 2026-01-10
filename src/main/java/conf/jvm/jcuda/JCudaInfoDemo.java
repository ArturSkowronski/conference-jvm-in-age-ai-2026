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

  public static void run() {
    System.out.println("== JCuda device info ==");
    System.out.println("os.name=" + System.getProperty("os.name"));
    System.out.println("os.arch=" + System.getProperty("os.arch"));
    System.out.println("java.version=" + System.getProperty("java.version"));

    try {
      JCudaDriver.setExceptionsEnabled(true);
      cuInit(0);

      int[] driverVersion = {0};
      cuDriverGetVersion(driverVersion);
      System.out.println("cuda.driverVersion=" + driverVersion[0]);

      int[] deviceCountArr = {0};
      cuDeviceGetCount(deviceCountArr);
      int deviceCount = deviceCountArr[0];
      System.out.println("cuda.deviceCount=" + deviceCount);

      for (int i = 0; i < deviceCount; i++) {
        CUdevice device = new CUdevice();
        cuDeviceGet(device, i);

        byte[] nameBytes = new byte[1024];
        cuDeviceGetName(nameBytes, nameBytes.length, device);
        String name = cString(nameBytes);

        int[] major = {0};
        int[] minor = {0};
        cuDeviceComputeCapability(major, minor, device);

        System.out.println("cuda.device[" + i + "].name=" + name);
        System.out.println("cuda.device[" + i + "].cc=" + major[0] + "." + minor[0]);
      }
    } catch (Throwable t) {
      Throwable root = rootCause(t);
      System.err.println("JCuda unavailable: " + root.getClass().getName() + ": " + root.getMessage());
      System.err.println();
      System.err.println("Requirements:");
      System.err.println("- NVIDIA CUDA driver installed and accessible (nvidia-smi should work on Linux/Windows)");
      System.err.println("- Matching native JCuda binaries on the classpath for your OS/arch");
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
