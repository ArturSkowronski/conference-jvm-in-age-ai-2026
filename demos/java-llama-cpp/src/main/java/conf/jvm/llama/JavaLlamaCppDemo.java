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
        System.getProperty("user.home") + "/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf";
    String prompt = args.length > 1 ? args[1] : "Tell me a short joke about programming.";

    printHeader();
    run(modelPath, prompt);
  }

  private static void printHeader() {
    System.out.println("============================================================");
    System.out.println("java-llama.cpp Inference Demo");
    System.out.println("============================================================");
    System.out.println("Java: " + System.getProperty("java.version"));
    System.out.println("VM: " + System.getProperty("java.vm.name"));
    System.out.println("OS: " + System.getProperty("os.name") + " " + System.getProperty("os.arch"));
    System.out.println("============================================================");
    System.out.println();
  }

  public static void run(String modelPath, String prompt) {
    File modelFile = new File(modelPath);
    if (!modelFile.exists()) {
      System.err.println("Model file not found: " + modelPath);
      System.err.println();
      System.err.println("Download the model with:");
      System.err.println("  mkdir -p ~/.tornadovm/models");
      System.err.println("  curl -L -o ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf \\");
      System.err.println("    \"https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf\"");
      System.exit(1);
    }

    System.out.println("Loading model: " + modelPath);
    long loadStart = System.currentTimeMillis();

    // Configure model parameters
    ModelParameters modelParams = new ModelParameters()
        .setModel(modelPath);

    try (LlamaModel model = new LlamaModel(modelParams)) {
      long loadTime = System.currentTimeMillis() - loadStart;
      System.out.printf("Model loaded in %.2fs%n%n", loadTime / 1000.0);

      // Format prompt using Llama 3.2 Instruct chat template
      String formattedPrompt = formatLlama3Prompt(prompt);

      System.out.println("Prompt: " + prompt);
      System.out.println("----------------------------------------");
      System.out.println("Response:");

      // Configure inference parameters
      InferenceParameters inferParams = new InferenceParameters(formattedPrompt)
          .setTemperature(0.7f);

      long inferStart = System.currentTimeMillis();
      int tokenCount = 0;
      StringBuilder response = new StringBuilder();

      // Stream the response
      for (LlamaOutput output : model.generate(inferParams)) {
        String text = output.toString();
        System.out.print(text);
        response.append(text);
        tokenCount++;
      }

      long inferTime = System.currentTimeMillis() - inferStart;
      double tokensPerSec = tokenCount / (inferTime / 1000.0);

      System.out.println();
      System.out.println("----------------------------------------");
      System.out.println();
      System.out.println("Stats:");
      System.out.printf("  Model load time: %.2fs%n", loadTime / 1000.0);
      System.out.printf("  Inference time: %.2fs%n", inferTime / 1000.0);
      System.out.printf("  Tokens generated: %d%n", tokenCount);
      System.out.printf("  Tokens/sec: %.2f%n", tokensPerSec);

    } catch (Exception e) {
      System.err.println("Error during inference: " + e.getMessage());
      e.printStackTrace();
      System.exit(1);
    }
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
