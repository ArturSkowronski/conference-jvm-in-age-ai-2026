package demo.baseline;

import java.util.Arrays;

public final class VectorAddBaseline {

    private static final class Args {
        int size = 10_000_000;
        int iters = 10;
        int warmup = 2;
        boolean verify = true;
    }

    private static Args parseArgs(String[] args) {
        Args parsed = new Args();
        for (int i = 0; i < args.length; i++) {
            String arg = args[i];
            switch (arg) {
                case "--size" -> parsed.size = Integer.parseInt(args[++i]);
                case "--iters" -> parsed.iters = Integer.parseInt(args[++i]);
                case "--warmup" -> parsed.warmup = Integer.parseInt(args[++i]);
                case "--no-verify" -> parsed.verify = false;
                default -> throw new IllegalArgumentException("Nieznany argument: " + arg);
            }
        }
        return parsed;
    }

    private static void add(int[] a, int[] b, int[] c) {
        for (int i = 0; i < c.length; i++) {
            c[i] = a[i] + b[i];
        }
    }

    public static void main(String[] args) {
        Args parsed = parseArgs(args);

        int[] a = new int[parsed.size];
        int[] b = new int[parsed.size];
        int[] c = new int[parsed.size];

        Arrays.fill(a, 1);
        Arrays.fill(b, 2);

        for (int i = 0; i < parsed.warmup; i++) {
            add(a, b, c);
        }

        long bestNanos = Long.MAX_VALUE;
        for (int i = 0; i < parsed.iters; i++) {
            long t0 = System.nanoTime();
            add(a, b, c);
            long t1 = System.nanoTime();
            bestNanos = Math.min(bestNanos, t1 - t0);
        }

        double bestMs = bestNanos / 1_000_000.0;
        double bytesTouched = (double) parsed.size * Integer.BYTES * 3; // a+b+c
        double gbPerSec = (bytesTouched / (1024.0 * 1024.0 * 1024.0)) / (bestNanos / 1e9);

        System.out.printf("Baseline: size=%d, best=%.3f ms, throughput=%.2f GB/s%n", parsed.size, bestMs, gbPerSec);

        if (parsed.verify) {
            for (int i = 0; i < parsed.size; i++) {
                if (c[i] != 3) {
                    throw new AssertionError("Błąd wyniku na i=" + i + " c=" + c[i]);
                }
            }
            System.out.println("Verify: OK");
        }
    }
}

