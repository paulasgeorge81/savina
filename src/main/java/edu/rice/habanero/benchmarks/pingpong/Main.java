package edu.rice.habanero.benchmarks.pingpong;

import edu.rice.habanero.benchmarks.BenchmarkRunner;

public class Main {
    public static void main(String[] args) {
        // PingPongBenchmark benchmark = new PingPongBenchmark();
        // try {
        //     benchmark.initialize(args);
        //     benchmark.printArgInfo();
        //     benchmark.runIteration();
        //     benchmark.cleanupIteration(true, 0);
        // } catch (Exception e) {
        //     e.printStackTrace();
        BenchmarkRunner.runBenchmark(args, new PingPongBenchmark());
    }
}
