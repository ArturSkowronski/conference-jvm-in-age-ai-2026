package com.skowronski.talk.jvmai;

/*
 * FP16 Mixed Precision Demo
 *
 * Requirements:
 * - JDK 24+ (for Float16 value type)
 * - Incubator module: jdk.incubator.vector
 */

import jdk.incubator.vector.*;

public class FP16VectorDemo {

    private static final VectorSpecies<Float> FP32_SPECIES = FloatVector.SPECIES_PREFERRED;

    public static void main(String[] args) {
        System.out.println("=".repeat(70));
        System.out.println("Float16 Mixed Precision Demo (JDK 24+)");
        System.out.println("=".repeat(70));
        System.out.println("Float16 properties:");
        System.out.println("  Size: " + Float16.BYTES + " bytes (" + Float16.SIZE + " bits)");
        System.out.println("  Max value: " + Float16.MAX_VALUE.floatValue());
        System.out.println("  Min normal: " + Float16.MIN_NORMAL.floatValue());
        System.out.println("  Precision: " + Float16.PRECISION + " bits");
        System.out.println();
        System.out.println("FP32 Vector Species: " + FP32_SPECIES);
        System.out.println("FP32 Vector length: " + FP32_SPECIES.length());
        System.out.println();

        // Demo 1: Float16 scalar arithmetic
        float16ScalarOperations();

        // Demo 2: FP16 storage with FP32 vectorized computation
        fp16StorageFp32Compute();

        // Demo 3: Memory savings demonstration
        memorySavingsDemo();
    }

    /**
     * Demo 1: Float16 scalar arithmetic operations
     */
    private static void float16ScalarOperations() {
        System.out.println("Demo 1: Float16 Scalar Arithmetic");
        System.out.println("-".repeat(70));

        Float16 a = Float16.valueOf(3.5f);
        Float16 b = Float16.valueOf(2.0f);

        // Basic arithmetic
        Float16 sum = Float16.add(a, b);
        Float16 diff = Float16.subtract(a, b);
        Float16 product = Float16.multiply(a, b);
        Float16 quotient = Float16.divide(a, b);
        Float16 sqrtVal = Float16.sqrt(a);

        // Fused multiply-add: a * b + 1.0
        Float16 c = Float16.valueOf(1.0f);
        Float16 fmaResult = Float16.fma(a, b, c);

        System.out.printf("a = %.4f (FP16)\n", a.floatValue());
        System.out.printf("b = %.4f (FP16)\n", b.floatValue());
        System.out.printf("c = %.4f (FP16)\n", c.floatValue());
        System.out.println();
        System.out.printf("a + b = %.4f\n", sum.floatValue());
        System.out.printf("a - b = %.4f\n", diff.floatValue());
        System.out.printf("a * b = %.4f\n", product.floatValue());
        System.out.printf("a / b = %.4f\n", quotient.floatValue());
        System.out.printf("sqrt(a) = %.4f\n", sqrtVal.floatValue());
        System.out.printf("fma(a, b, c) = a * b + c = %.4f\n", fmaResult.floatValue());
        System.out.println();
    }

    /**
     * Demo 2: FP16 storage with FP32 vectorized computation (mixed precision)
     * Store data in FP16 -> load/widen to FP32 vectors -> compute -> store back as FP16
     */
    private static void fp16StorageFp32Compute() {
        System.out.println("Demo 2: FP16 Storage + FP32 Vectorized Computation");
        System.out.println("-".repeat(70));

        int vectorLength = FP32_SPECIES.length();
        int size = vectorLength * 4; // Process multiple vectors

        // Storage: FP16 arrays (half the memory of FP32)
        Float16[] inputA = new Float16[size];
        Float16[] inputB = new Float16[size];
        Float16[] result = new Float16[size];

        // Initialize with FP16 values
        for (int i = 0; i < size; i++) {
            inputA[i] = Float16.valueOf(1.0f + i * 0.1f);
            inputB[i] = Float16.valueOf(2.0f + i * 0.05f);
        }

        // Process using FP32 vectors for higher precision computation
        for (int i = 0; i < size; i += vectorLength) {
            // Load FP16 -> convert to FP32 arrays
            float[] aFp32 = new float[vectorLength];
            float[] bFp32 = new float[vectorLength];

            for (int j = 0; j < vectorLength && (i + j) < size; j++) {
                aFp32[j] = inputA[i + j].floatValue();
                bFp32[j] = inputB[i + j].floatValue();
            }

            // Vectorized FP32 computation: (a + b) * 1.5
            FloatVector va = FloatVector.fromArray(FP32_SPECIES, aFp32, 0);
            FloatVector vb = FloatVector.fromArray(FP32_SPECIES, bFp32, 0);
            FloatVector vresult = va.add(vb).mul(1.5f);

            // Store back as FP16
            float[] resultFp32 = new float[vectorLength];
            vresult.intoArray(resultFp32, 0);

            for (int j = 0; j < vectorLength && (i + j) < size; j++) {
                result[i + j] = Float16.valueOf(resultFp32[j]);
            }
        }

        // Print results
        System.out.println("Computation: (a + b) * 1.5");
        System.out.println("Storage format: FP16 (saves 50% memory)");
        System.out.println("Compute format: FP32 vectors (higher precision)");
        System.out.println();
        System.out.println("Sample results (first 8 elements):");
        for (int i = 0; i < Math.min(8, size); i++) {
            float a = inputA[i].floatValue();
            float b = inputB[i].floatValue();
            float res = result[i].floatValue();
            float expected = (a + b) * 1.5f;
            System.out.printf("  [%d] (%.2f + %.2f) * 1.5 = %.2f (got %.2f)\n",
                    i, a, b, expected, res);
        }
        System.out.println();
    }

    /**
     * Demo 3: Memory savings demonstration
     */
    private static void memorySavingsDemo() {
        System.out.println("Demo 3: Memory Savings with Float16");
        System.out.println("-".repeat(70));

        int size = 1_000_000; // 1 million elements

        long fp32Bytes = size * Float.BYTES; // 4 bytes per float
        long fp16Bytes = size * Float16.BYTES; // 2 bytes per Float16
        long savings = fp32Bytes - fp16Bytes;
        double savingsPercent = (double) savings / fp32Bytes * 100;

        System.out.printf("Array size: %,d elements\n", size);
        System.out.println();
        System.out.printf("FP32 memory: %,d bytes (%.2f MB)\n",
                fp32Bytes, fp32Bytes / 1024.0 / 1024.0);
        System.out.printf("FP16 memory: %,d bytes (%.2f MB)\n",
                fp16Bytes, fp16Bytes / 1024.0 / 1024.0);
        System.out.printf("Savings: %,d bytes (%.2f MB) - %.0f%% reduction\n",
                savings, savings / 1024.0 / 1024.0, savingsPercent);
        System.out.println();

        System.out.println("Use cases for FP16 storage:");
        System.out.println("  • AI/ML model weights and activations");
        System.out.println("  • Large-scale scientific datasets");
        System.out.println("  • Graphics and game engine data");
        System.out.println("  • Real-time data processing pipelines");
        System.out.println();

        System.out.println("Note: Float16Vector (vectorized operations) is coming in a future JDK");
        System.out.println("      (JDK-8370691 - currently under development)");
        System.out.println();
    }
}
