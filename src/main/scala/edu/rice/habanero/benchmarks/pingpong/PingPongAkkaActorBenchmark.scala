package edu.rice.habanero.benchmarks.pingpong

import akka.actor.{ActorRef, Props}
import edu.rice.habanero.actors.{AkkaActor, AkkaActorState}
import edu.rice.habanero.benchmarks.pingpong.PingPongConfig.{Message, PingMessage, StartMessage, StopMessage}
import edu.rice.habanero.benchmarks.{Benchmark, BenchmarkRunner}
import java.io.{BufferedWriter, FileWriter}
import scala.sys.process.{Process, ProcessLogger}


/**
 *
 * @author <a href="http://shams.web.rice.edu/">Shams Imam</a> (shams@rice.edu)
 */
object PingPongAkkaActorBenchmark {

  def main(args: Array[String]) {

    // Start powermetrics before running the benchmark
    val powerMetricsProcess = startPowerMetrics()
    BenchmarkRunner.runBenchmark(args, new PingPongAkkaActorBenchmark)

    // Stop powermetrics after the benchmark
    stopPowerMetrics(powerMetricsProcess)
    println("Powermetrics captured. Review power_metrics.log for details.")
  }

  /**
   * Start the powermetrics process and log the output.
   * @return The process instance for later termination.
   */

   // Start powermetrics and write to a log file
  def startPowerMetrics(): Process = {
    // val powerMetricsCmd = Seq("sudo", "/usr/bin/powermetrics", "--show-all", "-i", "1000", "-n", "10")
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
      val process = Process(powerMetricsCmd).run(processLogger)
      println("Powermetrics started...")
      process
    } catch {
      case e: Exception => 
        println(s"Error executing powermetrics: ${e.getMessage}")
        null
    }
  }


  /**
   * Stop the powermetrics process and log the termination.
   * @param process The running process instance.
   */
   def stopPowerMetrics(process: Process): Unit = {
    if (process != null) {
      process.destroy()
      println("Powermetrics stopped.")
    }
  }

  private final class PingPongAkkaActorBenchmark extends Benchmark {
    def initialize(args: Array[String]) {
      PingPongConfig.parseArgs(args)
    }

    def printArgInfo() {
      PingPongConfig.printArgs()
    }

    def runIteration() {

      val system = AkkaActorState.newActorSystem("PingPong")

      val pong = system.actorOf(Props(new PongActor()))
      val ping = system.actorOf(Props(new PingActor(PingPongConfig.N, pong)))

      AkkaActorState.startActor(ping)
      AkkaActorState.startActor(pong)

      ping ! StartMessage.ONLY

      AkkaActorState.awaitTermination(system)
    }

    def cleanupIteration(lastIteration: Boolean, execTimeMillis: Double) {
    }
  }

  private class PingActor(count: Int, pong: ActorRef) extends AkkaActor[Message] {

    private var pingsLeft: Int = count

    override def process(msg: PingPongConfig.Message) {
      msg match {
        case _: PingPongConfig.StartMessage =>
          pong ! new PingPongConfig.SendPingMessage(self)
          pingsLeft = pingsLeft - 1
        case _: PingPongConfig.PingMessage =>
          pong ! new PingPongConfig.SendPingMessage(self)
          pingsLeft = pingsLeft - 1
        case _: PingPongConfig.SendPongMessage =>
          if (pingsLeft > 0) {
            self ! PingMessage.ONLY
          } else {
            pong ! StopMessage.ONLY
            exit()
          }
        case message =>
          val ex = new IllegalArgumentException("Unsupported message: " + message)
          ex.printStackTrace(System.err)
      }
    }
  }

  private class PongActor extends AkkaActor[Message] {
    private var pongCount: Int = 0

    override def process(msg: PingPongConfig.Message) {
      msg match {
        case message: PingPongConfig.SendPingMessage =>
          val sender = message.sender.asInstanceOf[ActorRef]
          sender ! new PingPongConfig.SendPongMessage(self)
          pongCount = pongCount + 1
        case _: PingPongConfig.StopMessage =>
          exit()
        case message =>
          val ex = new IllegalArgumentException("Unsupported message: " + message)
          ex.printStackTrace(System.err)
      }
    }
  }

}
