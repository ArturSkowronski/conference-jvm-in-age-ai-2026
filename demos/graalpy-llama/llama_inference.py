#!/usr/bin/env python3
"""
GraalPy Llama inference demo.

Uses llama-cpp-python to run inference on a GGUF model.
This is the same model used by TornadoVM's GPULlama3 demo.

Usage:
    graalpy llama_inference.py --model /path/to/model.gguf --prompt "tell me a joke"
"""

import argparse
import os
import platform
import sys
import time
from pathlib import Path


def format_llama3_prompt(user_message: str) -> str:
    """Format the prompt using Llama 3.2 Instruct chat template."""
    return (
        "<|begin_of_text|>"
        "<|start_header_id|>system<|end_header_id|>\n\n"
        "You are a helpful assistant.<|eot_id|>"
        "<|start_header_id|>user<|end_header_id|>\n\n"
        f"{user_message}<|eot_id|>"
        "<|start_header_id|>assistant<|end_header_id|>\n\n"
    )


def print_system_info() -> None:
    """Print system and Python environment info."""
    print("=" * 60)
    print("GraalPy Llama Inference Demo")
    print("=" * 60)
    print(f"Python: {sys.version.splitlines()[0]}")
    print(f"Executable: {sys.executable}")
    print(f"Platform: {platform.platform()}")
    print("=" * 60)


def run_inference(model_path: str, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> None:
    """Run inference on the Llama model."""
    from llama_cpp import Llama

    n_threads = os.cpu_count() or 4
    print(f"\nLoading model: {model_path}")
    print(f"Using {n_threads} CPU threads")
    t0 = time.time()

    llm = Llama(
        model_path=model_path,
        n_ctx=2048,
        n_threads=n_threads,
        verbose=False,
    )

    load_time = time.time() - t0
    print(f"Model loaded in {load_time:.2f}s")

    # Format using Llama 3.2 Instruct chat template
    formatted_prompt = format_llama3_prompt(prompt)

    print(f"\nPrompt: {prompt}")
    print("-" * 40)
    print("Response:")

    t0 = time.time()

    output = llm(
        formatted_prompt,
        max_tokens=max_tokens,
        temperature=temperature,
        echo=False,
        stop=["<|eot_id|>", "<|end_of_text|>"],
    )

    inference_time = time.time() - t0

    response_text = output["choices"][0]["text"]
    print(response_text.strip())

    print("-" * 40)

    usage = output.get("usage", {})
    prompt_tokens = usage.get("prompt_tokens", 0)
    completion_tokens = usage.get("completion_tokens", 0)
    total_tokens = usage.get("total_tokens", 0)

    print(f"\nStats:")
    print(f"  Inference time: {inference_time:.2f}s")
    print(f"  Prompt tokens: {prompt_tokens}")
    print(f"  Completion tokens: {completion_tokens}")
    print(f"  Total tokens: {total_tokens}")
    if completion_tokens > 0 and inference_time > 0:
        tokens_per_sec = completion_tokens / inference_time
        print(f"  Tokens/sec: {tokens_per_sec:.2f}")


def main() -> None:
    parser = argparse.ArgumentParser(description="GraalPy Llama inference demo")
    parser.add_argument(
        "--model",
        type=str,
        default=str(Path.home() / ".tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf"),
        help="Path to the GGUF model file",
    )
    parser.add_argument(
        "--prompt",
        type=str,
        default="Tell me a short joke about programming.",
        help="Prompt for the model",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=256,
        help="Maximum number of tokens to generate",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.7,
        help="Temperature for sampling",
    )

    args = parser.parse_args()

    print_system_info()

    if not Path(args.model).exists():
        print(f"\nError: Model file not found: {args.model}")
        print("\nTo download the model:")
        print("  mkdir -p ~/.tornadovm/models")
        print('  curl -L -o ~/.tornadovm/models/Llama-3.2-1B-Instruct-f16.gguf \\')
        print('    "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-f16.gguf"')
        sys.exit(1)

    run_inference(args.model, args.prompt, args.max_tokens, args.temperature)


if __name__ == "__main__":
    main()
