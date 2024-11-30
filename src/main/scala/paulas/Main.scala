package paulas

object Main {
  def main(args: Array[String]): Unit = {
    // Initialize the benchmark
    SimpleBenchmark.initialize(args)

    // Run the benchmark
    SimpleBenchmark.runIteration()  // Call the runIteration method directly

    // Cleanup after running the benchmark
    SimpleBenchmark.cleanupIteration(lastIteration = true, execTimeMillis = 0.0)
  }
}
