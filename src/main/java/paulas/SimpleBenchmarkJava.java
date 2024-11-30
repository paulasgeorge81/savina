package paulas;

import edu.rice.habanero.benchmarks.Benchmark;

public class SimpleBenchmarkJava extends Benchmark {

    @Override
    public void initialize(String[] args) {
        // Initialization logic (if any)
        System.out.println("Initializing the benchmark...");
    }

    @Override
    public void runIteration() {
        // Start timing the benchmark
        long startTime = System.nanoTime();

        // Calculate the sum of integers from 1 to 1,000,000
        int sum = 0;
        for (int i = 1; i <= 1_000_000; i++) {
            sum += i;
        }

        // End timing the benchmark
        long endTime = System.nanoTime();
        double timeTaken = (endTime - startTime) / 1e6; // Convert to milliseconds

        // Output the results
        System.out.println("The sum is: " + sum);
        System.out.println("Time taken: " + timeTaken + " ms");
    }

    @Override
    public void cleanupIteration(boolean lastIteration, double execTimeMillis) {
        // Cleanup logic after the iteration (if any)
    }

    @Override
    public void printArgInfo() {
        System.out.println("No specific arguments for this benchmark.");
    }

    public static void main(String[] args) {
        SimpleBenchmarkJava benchmark = new SimpleBenchmarkJava();
        benchmark.initialize(args);
        benchmark.runIteration();
        benchmark.cleanupIteration(false, 0); // Pass appropriate parameters as needed
    }
}
