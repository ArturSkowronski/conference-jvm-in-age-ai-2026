package com.skowronski.talk.jvmai;

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
        File currentDir = new File(System.getProperty("user.dir"));
        File projectRootDir = currentDir.getParentFile().getParentFile();

        String projectRoot = projectRootDir.getAbsolutePath();
        String venvSitePackages = Paths
                .get(projectRoot, "demos", "graalpy", ".venv", "lib", "python3.12", "site-packages").toString();
        String scriptPath = Paths.get(projectRoot, "demos", "graalpy", "llama_inference.py").toString();
        String modelPath = Paths
                .get(System.getProperty("user.home"), ".llama", "models", "Llama-3.2-1B-Instruct-f16.gguf").toString();

        System.out.println("[GraalPy] ============================================================");
        System.out.println("[GraalPy] GraalPy Llama Inference Host");
        System.out.println("[GraalPy] ============================================================");
        System.out.println("[GraalPy] Model: " + modelPath);
        System.out.println("[GraalPy] Script: " + scriptPath);
        System.out.println("[GraalPy] Venv:   " + venvSitePackages);
        System.out.println("[GraalPy] ============================================================");

        try (Context ctx = Context.newBuilder("python")
                .allowIO(IOAccess.ALL) // Allow file access
                .allowNativeAccess(true) // Allow C extensions (llama.cpp)
                .option("python.PythonPath", venvSitePackages) // Add venv to path
                .build()) {

            System.out.println("[GraalPy] Context initialized. Importing llama_inference...");

            ctx.eval("python", "import sys; sys.path.append('" +
                    Paths.get(projectRoot, "demos", "graalpy").toString() + "')");

            Value llamaModule = ctx.eval("python", "import llama_inference; llama_inference");

            System.out.println("[GraalPy] Module imported. Running inference...");
            Value runInference = llamaModule.getMember("run_inference");
            runInference.execute(modelPath, "Tell me a short joke about Java.", 64, 0.7);

        } catch (PolyglotException e) {
            System.err.println("[GraalPy] Polyglot Exception: " + e.getMessage());
            e.printStackTrace();
            System.err.println("\n[GraalPy] ============================================================");
            System.err.println("[GraalPy] Demo failed as expected - GraalPy cannot run llama-cpp-python");
            System.err.println("[GraalPy] Reason: NumPy/ctypes C extension incompatibility");
            System.err.println("[GraalPy] ============================================================");
            System.exit(1); // Fail the task to indicate expected failure
        }
    }
}
