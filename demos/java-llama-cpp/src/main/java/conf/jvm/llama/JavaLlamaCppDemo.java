package conf.jvm.llama;

import de.kherud.llama.InferenceParameters;
import de.kherud.llama.LlamaModel;
import de.kherud.llama.LlamaOutput;
import de.kherud.llama.ModelParameters;

import java.io.File;

/**
 * Demo: Llama inference using java-llama.cpp (JNI bindings for llama.cpp).
 *
 * This uses the same GGUF model as the TornadoVM GPULlama3 and GraalPy Llama demos,
 * demonstrating pure Java LLM inference via JNI bindings.
 *
 * @see <a href="https://github.com/kherud/java-llama.cpp">java-llama.cpp on GitHub</a>
 */
public final class JavaLlamaCppDemo {

  private JavaLlamaCppDemo() {}

  public static void main(String[] args) {
    String modelPath = args.length > 0 ? args[0] :
        System.getProperty("user.home") + "/.llama/models/Llama-3.2-1B-Instruct-f16.gguf";
    String prompt = args.length > 1 ? args[1] : "Tell me a short joke about programming.";

    printHeader();
    run(modelPath, prompt);
  }

  private static void printHeader() {
    System.out.println("[java-llama.cpp] ============================================================");
    System.out.println("[java-llama.cpp] java-llama.cpp Inference Demo");
    System.out.println("[java-llama.cpp] ============================================================");
    System.out.println("[java-llama.cpp] Java: " + System.getProperty("java.version"));
    System.out.println("[java-llama.cpp] VM: " + System.getProperty("java.vm.name"));
    System.out.println("[java-llama.cpp] OS: " + System.getProperty("os.name") + " " + System.getProperty("os.arch"));
    System.out.println("[java-llama.cpp] ============================================================");
    System.out.println();
  }

  public static void run(String modelPath, String prompt) {
    System.out.println("[java-llama.cpp] Checking model file...");
    File modelFile = new File(modelPath);
    if (!modelFile.exists()) {
      System.err.println("[java-llama.cpp] ERROR: Model file not found: " + modelPath);
      System.err.println("[java-llama.cpp] Download the model with:");
      System.err.println("[java-llama.cpp]   ./scripts/download-models.sh --fp16");
      System.exit(1);
    }
    System.out.println("[java-llama.cpp] Model file exists: " + modelPath);
    System.out.println("[java-llama.cpp] Model size: " + (modelFile.length() / 1024 / 1024) + " MB");

    System.out.println("[java-llama.cpp] Loading model...");
    long loadStart = System.currentTimeMillis();

    // Configure model parameters
    System.out.println("[java-llama.cpp] Configuring model parameters...");
    ModelParameters modelParams = new ModelParameters()
        .setModel(modelPath);

    try (LlamaModel model = new LlamaModel(modelParams)) {
      long loadTime = System.currentTimeMillis() - loadStart;
      System.out.printf("[java-llama.cpp] Model loaded in %.2fs%n", loadTime / 1000.0);
      System.out.println();

      // Format prompt using Llama 3.2 Instruct chat template
      System.out.println("[java-llama.cpp] Formatting prompt with Llama 3.2 chat template...");
      String formattedPrompt = formatLlama3Prompt(prompt);

      System.out.println("[java-llama.cpp] Prompt: " + prompt);
      System.out.println("[java-llama.cpp] ----------------------------------------");
      System.out.println("[java-llama.cpp] Response:");

      // Configure inference parameters
      System.out.println("[java-llama.cpp] Configuring inference parameters (temp=0.7)...");
      InferenceParameters inferParams = new InferenceParameters(formattedPrompt)
          .setTemperature(0.7f);

      System.out.println("[java-llama.cpp] Starting inference...");
      long inferStart = System.currentTimeMillis();
      int tokenCount = 0;
      StringBuilder response = new StringBuilder();

      // Stream the response
      for (LlamaOutput output : model.generate(inferParams)) {
        String text = output.toString();
        System.out.print(text);
        System.out.flush();
        response.append(text);
        tokenCount++;
      }

      long inferTime = System.currentTimeMillis() - inferStart;
      double tokensPerSec = tokenCount / (inferTime / 1000.0);

      System.out.println();
      System.out.println("[java-llama.cpp] ----------------------------------------");
      System.out.println();
      System.out.println("[java-llama.cpp] Stats:");
      System.out.printf("[java-llama.cpp]   Model load time: %.2fs%n", loadTime / 1000.0);
      System.out.printf("[java-llama.cpp]   Inference time: %.2fs%n", inferTime / 1000.0);
      System.out.printf("[java-llama.cpp]   Tokens generated: %d%n", tokenCount);
      System.out.printf("[java-llama.cpp]   Tokens/sec: %.2f%n", tokensPerSec);
      System.out.println();
      System.out.println("[java-llama.cpp] Demo completed successfully!");

    } catch (Exception e) {
      System.err.println("[java-llama.cpp] ERROR during inference: " + e.getMessage());
      e.printStackTrace();
      System.exit(1);
    }

    // Force exit - JNI native threads from llama.cpp don't terminate cleanly
    System.exit(0);
  }

  /**
   * Format a user prompt using Llama 3.2 Instruct chat template.
   */
  private static String formatLlama3Prompt(String userMessage) {
    return "<|begin_of_text|>" +
        "<|start_header_id|>system<|end_header_id|>\n\n" +
        "You are a helpful assistant.<|eot_id|>" +
        "<|start_header_id|>user<|end_header_id|>\n\n" +
        userMessage + "<|eot_id|>" +
        "<|start_header_id|>assistant<|end_header_id|>\n\n";
  }
}
