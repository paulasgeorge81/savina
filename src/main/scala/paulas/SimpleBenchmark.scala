package paulas
import edu.rice.habanero.benchmarks.Benchmark

object SimpleBenchmark extends Benchmark {
  
  override def cleanupIteration(lastIteration: Boolean, execTimeMillis: Double): Unit = {
    println(s"Iteration completed. Time taken: $execTimeMillis ms")
  }

  override def initialize(args: Array[String]): Unit = {
    println("Initializing benchmark...")
  }

  override def printArgInfo(): Unit = {
    println("No specific arguments for this benchmark.")
  }

  override def runIteration(): Unit = {
    val sum = (1 to 1000000).sum
    println(s"The sum is: $sum")
  }

//   override def getName: String = "Simple Benchmark"
}
