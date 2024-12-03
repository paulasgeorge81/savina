package paulas
import scala.sys.process._
import java.io.{BufferedWriter, FileWriter}

object PowerMetricsExample {
  def runPowerMetrics(): Unit = {
    // Command setup (matching your Java ProcessBuilder)
    val powerMetricsCmd = Seq("sudo", "/usr/bin/powermetrics", "-i", "1000", "-s", "all", "-a", "10", "-n", "5")
    
    // Log file to capture output
    val logFile = new BufferedWriter(new FileWriter("power_metrics.log"))
    
    // Process execution and logging
    val processLogger = ProcessLogger(
      (stdout: String) => {
        logFile.write(stdout + "\n")
        logFile.flush()  // Ensure data is written immediately
      },
      (stderr: String) => {
        logFile.write(stderr + "\n")
        logFile.flush()
      }
    )
    
    // Run the command and handle any errors
    try {
      val exitCode = powerMetricsCmd.run(processLogger).exitValue()
      println(s"Process finished with exit code: $exitCode")
    } catch {
      case e: Exception => println(s"Error executing powermetrics: ${e.getMessage}")
    } finally {
      logFile.close()
    }
  }

  def main(args: Array[String]): Unit = {
    runPowerMetrics()
  }
}
