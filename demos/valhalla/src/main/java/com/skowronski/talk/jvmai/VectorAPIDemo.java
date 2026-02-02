package com.skowronski.talk.jvmai;

/*
 * Vector API Demo - Float32 SIMD Operations
 *
 * Requirements:
 * - JDK 21+ (Vector API in incubator)
 * - Incubator module: jdk.incubator.vector
 */

import jdk.incubator.vector.*;

public class VectorAPIDemo {

    // Preferred species for Float vectors (CPU-dependent: 128, 256, or 512 bit)
    private static final VectorSpecies<Float> SPECIES = FloatVector.SPECIES_PREFERRED;

    public static void main(String[] args) {
        System.out.println("=".repeat(70));
        System.out.println("Vector API Demo - Float32 SIMD (JDK 21+)");
        System.out.println("=".repeat(70));
        System.out.println("Vector Species: " + SPECIES);
        System.out.println("Vector length: " + SPECIES.length() + " floats");
        System.out.println("Vector size: " + (SPECIES.vectorBitSize() / 8) + " bytes");
        System.out.println();

        // Demo 1: Basic SIMD operations
        basicSIMDOperations();

        // Demo 2: Dot product (scalar vs SIMD)
        dotProductComparison();

        // Demo 3: Fused multiply-add
        fusedMultiplyAdd();
    }

    /**
     * Demo 1: Basic SIMD operations (add, mul, fma)
     */
    private static void basicSIMDOperations() {
        System.out.println("Demo 1: Basic SIMD Operations");
        System.out.println("-".repeat(70));

        int length = SPECIES.length();

        // Create input arrays
        float[] a = new float[length];
        float[] b = new float[length];
        float[] resultAdd = new float[length];
        float[] resultMul = new float[length];

        for (int i = 0; i < length; i++) {
            a[i] = 1.0f + i;
            b[i] = 2.0f + i * 0.5f;
        }

        // Load vectors and perform SIMD operations
        FloatVector va = FloatVector.fromArray(SPECIES, a, 0);
        FloatVector vb = FloatVector.fromArray(SPECIES, b, 0);

        // SIMD add: a + b
        FloatVector vResultAdd = va.add(vb);
        vResultAdd.intoArray(resultAdd, 0);

        // SIMD mul: a * b
        FloatVector vResultMul = va.mul(vb);
        vResultMul.intoArray(resultMul, 0);

        // Print results
        System.out.println("Input A: " + formatArray(a, 8));
        System.out.println("Input B: " + formatArray(b, 8));
        System.out.println("A + B:   " + formatArray(resultAdd, 8));
        System.out.println("A * B:   " + formatArray(resultMul, 8));
        System.out.println();
    }

    /**
     * Demo 2: Dot product comparison (scalar vs SIMD)
     */
    private static void dotProductComparison() {
        System.out.println("Demo 2: Dot Product (Scalar vs SIMD)");
        System.out.println("-".repeat(70));

        // Use a size that's a multiple of vector length
        int size = SPECIES.length() * 1000;
        float[] a = new float[size];
        float[] b = new float[size];

        // Initialize with random-ish values
        for (int i = 0; i < size; i++) {
            a[i] = (float) Math.sin(i * 0.01);
            b[i] = (float) Math.cos(i * 0.01);
        }

        // Warmup
        for (int i = 0; i < 100; i++) {
            dotProductScalar(a, b);
            dotProductSIMD(a, b);
        }

        // Benchmark scalar
        long startScalar = System.nanoTime();
        float resultScalar = 0;
        for (int i = 0; i < 100; i++) {
            resultScalar = dotProductScalar(a, b);
        }
        long timeScalar = System.nanoTime() - startScalar;

        // Benchmark SIMD
        long startSIMD = System.nanoTime();
        float resultSIMD = 0;
        for (int i = 0; i < 100; i++) {
            resultSIMD = dotProductSIMD(a, b);
        }
        long timeSIMD = System.nanoTime() - startSIMD;

        System.out.printf("Array size: %,d floats (%.1f KB)\n", size, size * 4.0 / 1024);
        System.out.printf("Scalar result: %.6f (time: %.3f ms)\n",
                resultScalar, timeScalar / 1_000_000.0);
        System.out.printf("SIMD result:   %.6f (time: %.3f ms)\n",
                resultSIMD, timeSIMD / 1_000_000.0);
        System.out.printf("Speedup: %.2fx\n", (double) timeScalar / timeSIMD);
        System.out.printf("Match: %s (diff: %.9f)\n",
                Math.abs(resultScalar - resultSIMD) < 0.0001f,
                Math.abs(resultScalar - resultSIMD));
        System.out.println();
    }

    /**
     * Scalar dot product: sum(a[i] * b[i])
     */
    private static float dotProductScalar(float[] a, float[] b) {
        float sum = 0.0f;
        for (int i = 0; i < a.length; i++) {
            sum += a[i] * b[i];
        }
        return sum;
    }

    /**
     * SIMD dot product using Vector API
     */
    private static float dotProductSIMD(float[] a, float[] b) {
        float sum = 0.0f;
        int length = SPECIES.length();
        int i = 0;

        // Process full vectors
        FloatVector vsum = FloatVector.zero(SPECIES);
        for (; i < SPECIES.loopBound(a.length); i += length) {
            FloatVector va = FloatVector.fromArray(SPECIES, a, i);
            FloatVector vb = FloatVector.fromArray(SPECIES, b, i);
            vsum = va.fma(vb, vsum);  // fused multiply-add: vsum += va * vb
        }

        // Reduce vector to scalar
        sum = vsum.reduceLanes(VectorOperators.ADD);

        // Handle remaining elements (tail)
        for (; i < a.length; i++) {
            sum += a[i] * b[i];
        }

        return sum;
    }

    /**
     * Demo 3: Fused multiply-add (FMA)
     */
    private static void fusedMultiplyAdd() {
        System.out.println("Demo 3: Fused Multiply-Add (FMA)");
        System.out.println("-".repeat(70));

        int length = SPECIES.length();
        float[] a = new float[length];
        float[] b = new float[length];
        float[] c = new float[length];
        float[] result = new float[length];

        for (int i = 0; i < length; i++) {
            a[i] = 2.0f;
            b[i] = 3.0f + i;
            c[i] = 1.0f;
        }

        // Load vectors
        FloatVector va = FloatVector.fromArray(SPECIES, a, 0);
        FloatVector vb = FloatVector.fromArray(SPECIES, b, 0);
        FloatVector vc = FloatVector.fromArray(SPECIES, c, 0);

        // FMA: a * b + c
        FloatVector vResult = va.fma(vb, vc);
        vResult.intoArray(result, 0);

        System.out.println("Operation: a * b + c");
        System.out.println("a = " + formatArray(a, 8));
        System.out.println("b = " + formatArray(b, 8));
        System.out.println("c = " + formatArray(c, 8));
        System.out.println();
        System.out.println("Result: " + formatArray(result, 8));
        System.out.println();

        // Verify first few values
        System.out.println("Verification:");
        for (int i = 0; i < Math.min(4, length); i++) {
            float expected = a[i] * b[i] + c[i];
            System.out.printf("  [%d] %.1f * %.1f + %.1f = %.1f (got %.1f)\n",
                    i, a[i], b[i], c[i], expected, result[i]);
        }
        System.out.println();
    }

    /**
     * Format array for display
     */
    private static String formatArray(float[] array, int maxElements) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < Math.min(maxElements, array.length); i++) {
            if (i > 0) sb.append(", ");
            sb.append(String.format("%.2f", array[i]));
        }
        if (array.length > maxElements) {
            sb.append(", ...");
        }
        sb.append("]");
        return sb.toString();
    }
}
