package demo.tornadovm;

import uk.ac.manchester.tornado.api.ImmutableTaskGraph;
import uk.ac.manchester.tornado.api.TaskGraph;
import uk.ac.manchester.tornado.api.TornadoExecutionPlan;
import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.enums.DataTransferMode;
import uk.ac.manchester.tornado.api.exceptions.TornadoExecutionPlanException;
import uk.ac.manchester.tornado.api.types.arrays.IntArray;

public final class VectorAddTornado {

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

    public static void add(IntArray a, IntArray b, IntArray c) {
        for (@Parallel int i = 0; i < c.getSize(); i++) {
            c.set(i, a.get(i) + b.get(i));
        }
    }

    public static void main(String[] args) throws TornadoExecutionPlanException {
        Args parsed = parseArgs(args);

        IntArray a = new IntArray(parsed.size);
        IntArray b = new IntArray(parsed.size);
        IntArray c = new IntArray(parsed.size);

        a.init(1);
        b.init(2);
        c.init(0);

        TaskGraph taskGraph = new TaskGraph("s0") //
                .transferToDevice(DataTransferMode.FIRST_EXECUTION, a, b) //
                .task("t0", VectorAddTornado::add, a, b, c) //
                .transferToHost(DataTransferMode.EVERY_EXECUTION, c);

        ImmutableTaskGraph immutableTaskGraph = taskGraph.snapshot();

        try (TornadoExecutionPlan executor = new TornadoExecutionPlan(immutableTaskGraph)) {
            for (int i = 0; i < parsed.warmup; i++) {
                executor.execute();
            }

            long bestNanos = Long.MAX_VALUE;
            for (int i = 0; i < parsed.iters; i++) {
                long t0 = System.nanoTime();
                executor.execute();
                long t1 = System.nanoTime();
                bestNanos = Math.min(bestNanos, t1 - t0);
            }

            double bestMs = bestNanos / 1_000_000.0;
            double bytesTouched = (double) parsed.size * Integer.BYTES * 3; // a+b+c
            double gbPerSec = (bytesTouched / (1024.0 * 1024.0 * 1024.0)) / (bestNanos / 1e9);

            System.out.printf("TornadoVM: size=%d, best=%.3f ms, throughput=%.2f GB/s%n", parsed.size, bestMs, gbPerSec);
        } catch (TornadoExecutionPlanException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }

        if (parsed.verify) {
            int[] heapC = c.toHeapArray();
            for (int i = 0; i < heapC.length; i++) {
                if (heapC[i] != 3) {
                    throw new AssertionError("Błąd wyniku na i=" + i + " c=" + heapC[i]);
                }
            }
            System.out.println("Verify: OK");
        }
    }
}

