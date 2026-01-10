package conf.jvm.tensorflow;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.Locale;
import java.util.Optional;
import java.util.stream.Stream;

final class TensorFlowNative {
  private TensorFlowNative() {}

  static Path resolveHome() {
    String home = System.getProperty("tensorflow.home");
    if (home == null || home.isBlank()) {
      home = System.getenv("TENSORFLOW_HOME");
    }
    if (home == null || home.isBlank()) {
      throw new IllegalStateException(
        "TensorFlow native library not configured. Set -Dtensorflow.home=/path/to/unpacked/libtensorflow (or TENSORFLOW_HOME).");
    }
    return Path.of(home).toAbsolutePath().normalize();
  }

  static Libraries resolveLibraries(Path tensorflowHome) {
    Path libDir = Files.isDirectory(tensorflowHome.resolve("lib"))
      ? tensorflowHome.resolve("lib")
      : tensorflowHome;

    String os = System.getProperty("os.name").toLowerCase(Locale.ROOT);
    String marker = os.contains("win") ? ".dll" : (os.contains("mac") || os.contains("darwin")) ? ".dylib" : ".so";

    Path framework = findBestMatch(libDir, "tensorflow_framework", marker).orElse(null);
    Path tensorflow = findBestMatch(libDir, "tensorflow", marker)
      .filter(p -> !p.getFileName().toString().toLowerCase(Locale.ROOT).contains("framework"))
      .orElseThrow(() -> new IllegalStateException("Could not find libtensorflow (" + marker + "*) under " + libDir));

    return new Libraries(framework, tensorflow);
  }

  private static Optional<Path> findBestMatch(Path libDir, String contains, String marker) {
    try (Stream<Path> paths = Files.list(libDir)) {
      return paths
        .filter(Files::isRegularFile)
        .filter(p -> {
          String name = p.getFileName().toString().toLowerCase(Locale.ROOT);
          return name.contains(contains) && name.contains(marker);
        })
        .max(Comparator.comparing(p -> p.getFileName().toString()));
    } catch (IOException e) {
      throw new IllegalStateException("Failed to scan " + libDir + " for TensorFlow libraries", e);
    }
  }

  record Libraries(Path framework, Path tensorflow) {}
}
