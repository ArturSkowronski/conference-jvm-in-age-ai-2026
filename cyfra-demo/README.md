# Demo: Cyfra (Scala 3 → Vulkan GPU LLM Inference)

Cyfra is a Scala 3 library for GPU computation via Vulkan/SPIR-V. GPU programs are written as a Scala DSL, compiled to SPIR-V at build time, and executed on any Vulkan-capable GPU.

The `llm.scala` branch includes a full Llama inference pipeline — tokenizer, GGUF loader, and GPU-accelerated transformer — written entirely in Scala.

- Repository: https://github.com/ComputeNode/cyfra
- Branch: `llm.scala`

## Requirements

- **JDK 17+** (Scala 3.6.4)
- **sbt** (Scala Build Tool) — https://www.scala-sbt.org/download
- **Vulkan drivers** for your GPU:
  - NVIDIA: included with standard drivers
  - AMD: Mesa or AMDVLK
  - Intel: Mesa ANV
  - macOS: MoltenVK (via Vulkan SDK — https://vulkan.lunarg.com/sdk/home)
- **~4 GB RAM** for sbt compilation

### macOS (MoltenVK) Setup

Install the Vulkan SDK, then set `VULKAN_SDK`:

```bash
export VULKAN_SDK="$HOME/VulkanSDK/<version>/macOS"
```

The run script automatically passes the necessary JVM flags for MoltenVK.

## Model Setup

Uses the same model as other demos (Llama 3.2 1B, FP16):

```bash
mkdir -p ~/.llama/models
curl -L -o ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"
```

## Running

### Single prompt

```bash
./scripts/run-cyfra-llama.sh \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Hello, how are you?"
```

### Benchmark mode (warmup + measured runs)

```bash
./scripts/run-cyfra-llama.sh \
  --model ~/.llama/models/Llama-3.2-1B-Instruct-f16.gguf \
  --prompt "Hello" --measure
```

### Extra runner options

Any additional arguments are forwarded to the Cyfra Runner:

- `--warmup N` — warmup runs (default: 3)
- `--runs N` — benchmark runs (default: 5)
- `--temperature FLOAT` — sampling temperature
- `--max-tokens N` — max tokens to generate

## What This Demo Shows

- GPU computation from pure Scala (no JNI, no native bindings, no CUDA)
- Scala DSL compiled to SPIR-V → executed on Vulkan
- Cross-platform GPU support (NVIDIA, AMD, Intel, Apple via MoltenVK)
- Competitive LLM inference performance with a JVM language

## Performance

Reported results on RTX 4080 Super with Llama-3.2-1B-Instruct-f16.gguf: **~70 tok/s**.

| GPU | tok/s | Notes |
|-----|-------|-------|
| RTX 4080 Super | ~70 | Vulkan backend |
| Tesla T4 | TBD | GCP benchmark pending |

## How It Works

1. **GGUF Loader** — Reads model weights from GGUF format
2. **Tokenizer** — BPE tokenization/detokenization
3. **GPU Programs** — Matmul, GeLU, softmax, RMSNorm written in Cyfra's Scala DSL
4. **SPIR-V Compiler** — DSL → SPIR-V bytecode at build time
5. **Vulkan Backend** — SPIR-V dispatched to GPU via LWJGL Vulkan bindings
