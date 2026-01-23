package demo;

import org.graalvm.polyglot.Context;
import org.graalvm.polyglot.PolyglotException;
import org.graalvm.polyglot.Source;
import org.graalvm.polyglot.Value;
import org.graalvm.polyglot.io.IOAccess;

import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;

public final class GraalPyLlama {
    public static void main(String[] args) {
        // We are running in demos/graalpy/java-host
        // Need to go up 3 levels to root: ../../../
        File currentDir = new File(System.getProperty("user.dir"));
        File projectRootDir = currentDir.getParentFile().getParentFile().getParentFile();
        
        String projectRoot = projectRootDir.getAbsolutePath();
        String venvSitePackages = Paths.get(projectRoot, "demos", "graalpy-llama", ".venv", "lib", "python3.12", "site-packages").toString();
        String scriptPath = Paths.get(projectRoot, "demos", "graalpy-llama", "llama_inference.py").toString();
        String modelPath = Paths.get(System.getProperty("user.home"), ".llama", "models", "Llama-3.2-1B-Instruct-f16.gguf").toString();

        System.out.println("[GraalPy] ============================================================");
        System.out.println("[GraalPy] GraalPy Llama Inference Host");
        System.out.println("[GraalPy] ============================================================");
        System.out.println("[GraalPy] Model: " + modelPath);
        System.out.println("[GraalPy] Script: " + scriptPath);
        System.out.println("[GraalPy] Venv:   " + venvSitePackages);
        System.out.println("[GraalPy] ============================================================");

        if (!new File(modelPath).exists()) {
            System.err.println("[GraalPy] Error: Model file not found.");
            System.exit(1);
        }

        try (Context ctx = Context.newBuilder("python")
                .allowIO(IOAccess.ALL) // Allow file access
                .allowNativeAccess(true) // Allow C extensions (llama.cpp)
                .option("python.PythonPath", venvSitePackages) // Add venv to path
                .build()) {

            System.out.println("[GraalPy] Context initialized. Importing llama_inference...");
            
            // Add the script directory to python path so we can import it
            ctx.eval("python", "import sys; sys.path.append('" + Paths.get(projectRoot, "demos", "graalpy-llama").toString() + "')");
            
            // Import the module
            Value llamaModule = ctx.eval("python", "import llama_inference; llama_inference");
            
            System.out.println("[GraalPy] Module imported. Running inference...");
            
            // Call the run_inference function
            // run_inference(model_path, prompt, max_tokens, temperature)
            Value runInference = llamaModule.getMember("run_inference");
            runInference.execute(modelPath, "Tell me a short joke about Java.", 64, 0.7);

        } catch (PolyglotException e) {
            System.err.println("[GraalPy] Polyglot Exception: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
