#!/usr/bin/env bash
#
# Run all benchmarks for the JVM in the Age of AI demos
#
# Usage:
#   ./scripts/run-all-benchmarks.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}${BOLD}  $1${NC}"
  echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
  echo ""
}

print_section() {
  echo ""
  echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│ ${BOLD}$1${NC}"
  echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
}

print_result() {
  local name="$1"
  local result="$2"
  local status="$3"

  if [[ "$status" == "ok" ]]; then
    printf "  ${GREEN}✓${NC} %-35s %s\n" "$name" "$result"
  elif [[ "$status" == "fail" ]]; then
    printf "  ${RED}✗${NC} %-35s %s\n" "$name" "$result"
  else
    printf "  ${YELLOW}○${NC} %-35s %s\n" "$name" "$result"
  fi
}

# JDK paths
JDK_21="${JDK_21:-$HOME/.sdkman/candidates/java/21.0.2-graalce}"
JDK_25_TEM="${JDK_25_TEM:-$HOME/.sdkman/candidates/java/25-tem}"
JDK_25_GRAAL="${JDK_25_GRAAL:-$HOME/.sdkman/candidates/java/25.1.0-graalvm-dev}"
TORNADOVM_HOME="${TORNADOVM_HOME:-$PROJECT_DIR/demos/tornadovm/build/tornadovm-sdk/tornadovm-2.2.0-opencl}"

# Model path
MODEL_PATH="${MODEL_PATH:-$HOME/.llama/models/Llama-3.2-1B-Instruct-f16.gguf}"

print_header "JVM in the Age of AI - Benchmark Suite"

echo -e "Project: ${BOLD}$PROJECT_DIR${NC}"
echo -e "Model:   ${BOLD}$MODEL_PATH${NC}"
echo ""

# Check model exists
if [[ ! -f "$MODEL_PATH" ]]; then
  echo -e "${RED}Error: Model not found at $MODEL_PATH${NC}"
  echo "Run: ./scripts/download-models.sh --fp16"
  exit 1
fi

# ============================================================================
# LLM INFERENCE BENCHMARKS
# ============================================================================

print_header "LLM Inference Benchmarks"

# --- Llama3.java (Pure Java) ---
print_section "Llama3.java - Pure Java LLM (Vector API)"

# JDK 21
if [[ -d "$JDK_21" ]]; then
  echo -e "  Running with JDK 21..."
  RESULT=$(JAVA_HOME="$JDK_21" ./demos/llama3-java/scripts/run-llama3.sh --max-tokens 32 2>&1 | grep "generation:" | sed 's/.*generation: \([0-9.]*\) tokens.*/\1 tokens\/s/')
  print_result "JDK 21 (GraalVM CE)" "$RESULT" "ok"
else
  print_result "JDK 21 (GraalVM CE)" "Not installed" "fail"
fi

# JDK 25 Temurin
if [[ -d "$JDK_25_TEM" ]]; then
  echo -e "  Running with JDK 25 Temurin..."
  RESULT=$(JAVA_HOME="$JDK_25_TEM" ./demos/llama3-java/scripts/run-llama3.sh --max-tokens 32 2>&1 | grep "generation:" | sed 's/.*generation: \([0-9.]*\) tokens.*/\1 tokens\/s/')
  print_result "JDK 25 (Temurin)" "$RESULT" "ok"
else
  print_result "JDK 25 (Temurin)" "Not installed" "fail"
fi

# GraalVM 25
if [[ -d "$JDK_25_GRAAL" ]]; then
  echo -e "  Running with GraalVM 25..."
  RESULT=$(JAVA_HOME="$JDK_25_GRAAL" ./demos/llama3-java/scripts/run-llama3.sh --max-tokens 32 2>&1 | grep "generation:" | sed 's/.*generation: \([0-9.]*\) tokens.*/\1 tokens\/s/')
  print_result "GraalVM 25 CE" "$RESULT" "ok"
else
  print_result "GraalVM 25 CE" "Not installed" "fail"
fi

# --- java-llama.cpp ---
print_section "java-llama.cpp - JNI Bindings to llama.cpp"

echo -e "  Running java-llama.cpp..."
RESULT=$(./gradlew :demos:java-llama-cpp:run 2>&1 | grep "Tokens/sec:" | sed 's/.*Tokens\/sec: \([0-9.]*\)/\1 tokens\/s/')
if [[ -n "$RESULT" ]]; then
  print_result "java-llama.cpp (JNI + Metal)" "$RESULT" "ok"
else
  print_result "java-llama.cpp (JNI + Metal)" "Failed" "fail"
fi

# --- TornadoVM GPULlama3 ---
print_section "TornadoVM GPULlama3 - GPU Accelerated LLM"

if [[ -d "$TORNADOVM_HOME" ]]; then
  echo -e "  Running GPULlama3..."
  export TORNADOVM_HOME
  export JVMCI_CONFIG_CHECK=ignore
  RESULT=$(./demos/tornadovm/scripts/run-gpullama3.sh --model "$MODEL_PATH" --prompt "Hello" 2>&1 | grep "tok/s" | sed 's/.*tok\/s: \([0-9]*\.[0-9]*\).*/\1 tokens\/s/')
  if [[ -n "$RESULT" ]]; then
    print_result "TornadoVM GPULlama3 (OpenCL)" "$RESULT" "ok"
  else
    print_result "TornadoVM GPULlama3 (OpenCL)" "Failed" "fail"
  fi
else
  print_result "TornadoVM GPULlama3 (OpenCL)" "TornadoVM not installed" "fail"
fi

# --- Cyfra (Scala/Vulkan GPU) ---
print_section "Cyfra - Scala/Vulkan GPU LLM (SPIR-V)"

if command -v sbt &>/dev/null; then
  echo -e "  Running Cyfra LLM..."
  CYFRA_OUTPUT=$("$PROJECT_DIR/cyfra-demo/scripts/run-cyfra-llama.sh" --model "$MODEL_PATH" --prompt "Hello" --measure 2>&1)
  # Extract "Average: X.X tok/s" or fall back to last "X.X tok/s" match
  RESULT=$(echo "$CYFRA_OUTPUT" | grep "Average:" | grep -oE "[0-9]+\.[0-9]+" || echo "$CYFRA_OUTPUT" | grep -oE "([0-9]+\.?[0-9]*) tok/s" | tail -1 | grep -oE "[0-9]+\.[0-9]+" || echo "")
  if [[ -n "$RESULT" ]]; then
    print_result "Cyfra (Vulkan GPU)" "$RESULT tokens/s" "ok"
  else
    print_result "Cyfra (Vulkan GPU)" "Failed (check Vulkan drivers)" "fail"
  fi
else
  print_result "Cyfra (Vulkan GPU)" "sbt not installed" "fail"
fi

# ============================================================================
# DRY RUN DEMOS (Non-LLM)
# ============================================================================

print_header "Dry Run Demos (Non-LLM)"

# --- TensorFlow FFM ---
print_section "TensorFlow FFM - Foreign Function & Memory API"

echo -e "  Running TensorFlow FFM..."
OUTPUT=$(./gradlew :demos:tensorflow-ffm:runTensorFlow 2>&1)
TF_VERSION=$(echo "$OUTPUT" | grep "TF_Version" | sed 's/.*TF_Version=//')
TF_RESULT=$(echo "$OUTPUT" | grep "Result:" | sed 's/.*Result: //')
if [[ -n "$TF_VERSION" ]]; then
  print_result "TensorFlow FFM" "TF $TF_VERSION, $TF_RESULT" "ok"
else
  print_result "TensorFlow FFM" "Failed" "fail"
fi

# --- Babylon ---
print_section "Project Babylon - Code Reflection"

echo -e "  Running Babylon RuntimeCheck..."
OUTPUT=$(cd demos/babylon && ./run-babylon.sh 2>&1)
if echo "$OUTPUT" | grep -q "Java Version"; then
  JAVA_VER=$(echo "$OUTPUT" | grep "Java Version:" | sed 's/.*Java Version: *//')
  CODE_REFLECT=$(echo "$OUTPUT" | grep "Code Reflection Module Present:" | sed 's/.*: //')
  print_result "Babylon RuntimeCheck" "Java $JAVA_VER, CodeReflect=$CODE_REFLECT" "ok"
else
  print_result "Babylon RuntimeCheck" "Failed" "fail"
fi

# --- GraalPy Java Host ---
print_section "GraalPy Java Host - Polyglot API"

echo -e "  Running GraalPy Java Host..."
OUTPUT=$(./gradlew :demos:graalpy:run 2>&1)
PY_VERSION=$(echo "$OUTPUT" | grep "python.version" | sed 's/.*python.version=//' | cut -d' ' -f1)
PY_RESULT=$(echo "$OUTPUT" | grep "Result:" | sed 's/.*Result: //')
if [[ -n "$PY_VERSION" ]]; then
  print_result "GraalPy Java Host" "Python $PY_VERSION, $PY_RESULT" "ok"
else
  print_result "GraalPy Java Host" "Failed" "fail"
fi

# ============================================================================
# KNOWN FAILING DEMOS
# ============================================================================

print_header "Known Failing Demos"

# --- GraalPy Llama ---
print_section "GraalPy Llama - Python LLM (llama-cpp-python)"

echo -e "  Running GraalPy Llama (expected to fail)..."
OUTPUT=$(cd demos/graalpy && ./scripts/run-llama.sh --max-tokens 32 2>&1 || true)
if echo "$OUTPUT" | grep -q "ctypes"; then
  ERROR=$(echo "$OUTPUT" | grep "SystemError" | head -1)
  print_result "GraalPy Llama" "ctypes struct return not supported" "fail"
  echo ""
  echo -e "  ${YELLOW}Error:${NC} $ERROR"
  echo -e "  ${YELLOW}Note:${NC} GraalPy's Truffle NFI does not support struct return types"
else
  print_result "GraalPy Llama" "Unexpected result" "fail"
fi

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Summary"

echo -e "${BOLD}LLM Performance Ranking:${NC}"
echo ""
printf "  %-5s %-40s %s\n" "Rank" "Approach" "Speed"
printf "  %-5s %-40s %s\n" "────" "────────────────────────────────────────" "──────────────"
printf "  ${GREEN}1${NC}     java-llama.cpp (JNI + Metal/CUDA)       ~56 tokens/s\n"
printf "  ${GREEN}2${NC}     Cyfra (Scala/Vulkan GPU)                ~31 tokens/s\n"
printf "  ${GREEN}3${NC}     Llama3.java (JDK 25)                    ~15 tokens/s\n"
printf "  ${GREEN}4${NC}     TornadoVM GPULlama3 (OpenCL)            ~8 tokens/s\n"
printf "  ${RED}5${NC}     Llama3.java (JDK 21)                    ~0.4 tokens/s\n"
echo ""

echo -e "${BOLD}JDK Version Impact (Llama3.java):${NC}"
echo ""
echo -e "  JDK 21 → JDK 25: ${GREEN}~40x speedup${NC} (Vector API improvements)"
echo -e "  Temurin 25 ≈ GraalVM 25 CE (memory-bandwidth bound)"
echo ""

echo -e "${BOLD}Demo Status:${NC}"
echo ""
echo -e "  ${GREEN}Working:${NC} llama3-java, java-llama-cpp, GPULlama3, cyfra, tensorflow-ffm, babylon, graalpy"
echo -e "  ${RED}Failing:${NC} graalpy (CPython mode) (ctypes limitation)"
echo ""
