package edu.rice.habanero.benchmarks.pingpong;
import akka.actor.ActorRef;
import akka.actor.ActorSystem;
import akka.actor.Props;
import akka.actor.UntypedActor;
import edu.rice.habanero.benchmarks.Benchmark;
import java.io.IOException;
import java.util.concurrent.TimeUnit;

public class PingPongBenchmark extends Benchmark {

    private ActorSystem system;

    @Override
    public void initialize(String[] args) throws IOException {
        PingPongConfig.parseArgs(args);  // Parse configuration arguments
    }

    @Override
    public void printArgInfo() {
        PingPongConfig.printArgs();  // Prints configured arguments
    }

    @Override
    public void runIteration() {
        system = ActorSystem.create("PingPongSystem");

        // Create the Ponger and Pinger actors
        final ActorRef ponger = system.actorOf(Ponger.props(), "ponger");
        final ActorRef pinger = system.actorOf(Pinger.props(ponger), "pinger");

        // Start the ping-pong interaction
        pinger.tell(PingPongConfig.StartMessage.ONLY, ActorRef.noSender());

        // Wait for system termination (no exception handling needed here)
        system.awaitTermination(scala.concurrent.duration.Duration.create(30, TimeUnit.SECONDS)); // Set a timeout to exit after a period

        // system.awaitTermination(30, TimeUnit.SECONDS);  // This will block until the system is terminated or timeout occurs
    }

    @Override
    public void cleanupIteration(boolean lastIteration, double execTimeMillis) {
        if (system != null) {
            system.terminate();  // Clean up and terminate the Actor system
        }
    }

    // Pinger Actor Definition
    static class Pinger extends UntypedActor {
        private final ActorRef ponger;
        private int remainingPings;

        // Constructor for Pinger with Ponger actor reference
        static Props props(ActorRef ponger) {
            return Props.create(Pinger.class, () -> new Pinger(ponger));
        }

        Pinger(ActorRef ponger) {
            this.ponger = ponger;
            this.remainingPings = PingPongConfig.N;  // Number of ping-pong iterations
        }

        @Override
        public void onReceive(Object message) throws Exception {
            if (message instanceof String) {
                System.out.println("Pinger received: " + message);
                if (remainingPings > 0) {
                    remainingPings--;
                    ponger.tell("Ping", getSelf());  // Send "Ping" to Ponger
                } else {
                    // Stop both the Pinger and Ponger actors after the last ping
                    getContext().stop(ponger);
                    getContext().stop(getSelf());  // Stop the Pinger actor
                }
            } else {
                unhandled(message);  // Handle unrecognized messages
            }
        }
    }

    // Ponger Actor Definition
    static class Ponger extends UntypedActor {

        // Constructor for Ponger actor
        static Props props() {
            return Props.create(Ponger.class, Ponger::new);
        }

        @Override
        public void onReceive(Object message) throws Exception {
            if (message instanceof String) {
                System.out.println("Ponger received: " + message);
                getSender().tell("Pong", getSelf());  // Send "Pong" back to the Pinger
            } else {
                unhandled(message);  // Handle unrecognized messages
            }
        }
    }


    public static void main(String[] args) throws Exception {
        // Initialize and configure PingPongBenchmark
        PingPongBenchmark benchmark = new PingPongBenchmark();
        benchmark.initialize(args);

        // Print configuration info
        benchmark.printArgInfo();

        // Run the benchmark iteration
        benchmark.runIteration();

        // Optionally, you can cleanup after the benchmark runs
        benchmark.cleanupIteration(true, 0);  // Example with dummy execTimeMillis (you can modify this)
    }
}
