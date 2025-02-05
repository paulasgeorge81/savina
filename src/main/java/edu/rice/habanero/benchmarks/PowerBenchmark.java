//this is for experimenting with akka and power consumption. Created by: Paulas
package edu.rice.habanero.benchmarks;

// import java.io.BufferedReader;
// import java.io.InputStreamReader;
// import java.io.IOException;
// import java.util.stream.DoubleStream;
// import java.util.stream.IntStream;

// public class PowerBenchmark {

//     // Method to execute a command and get output
//     private static String runCommand(String command) throws IOException {
//         ProcessBuilder processBuilder = new ProcessBuilder("bash", "-c", command);
//         processBuilder.redirectErrorStream(true);
//         Process process = processBuilder.start();
        
//         try (BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()))) {
//             return reader.lines().reduce("", (acc, line) -> acc + line + "\n");
//         }
//     }

//     // Extracts CPU power from powermetrics output
//     private static double getSingleCpuPower() throws IOException {
//         String output = runCommand("sudo powermetrics -s cpu_power -n 1 -i 1ms -a 0 --hide-cpu-duty-cycle --show-extra-power-info");
//         String match = output.lines()
//                              .filter(line -> line.contains("Intel energy model derived CPU core power"))
//                              .findFirst()
//                              .map(line -> line.replaceAll("[^0-9.]", ""))
//                              .orElse("0.0");
//         return Double.parseDouble(match);
//     }

//     // Gets an average of multiple CPU power samples
//     private static double getAvgCpuPower(int samples) throws IOException {
//         return DoubleStream.generate(() -> {
//             try {
//                 return getSingleCpuPower();
//             } catch (IOException e) {
//                 return 0.0;
//             }
//         }).limit(samples).average().orElse(0.0);
//     }

//     // Measures power consumption over multiple iterations
//     public static void measurePower(Runnable task, int iterations) throws IOException {
//         double totalPower = 0.0;

//         for (int i = 1; i <= iterations; i++) {
//             double before = getAvgCpuPower(3); // Take 3 samples before execution
//             task.run(); // Execute the function/task
//             double after = getAvgCpuPower(3); // Take 3 samples after execution

//             double powerConsumed = Math.max(0.0, after - before); // Avoid negative values
//             totalPower += powerConsumed;

//             System.out.printf("Iteration %d: Before: %.2f W, After: %.2f W, Power Consumed: %.2f W%n",
//                               i, before, after, powerConsumed);
//         }

//         System.out.printf("Total power consumed across all iterations: %.2f W%n", totalPower);
//     }

//     // Main method to test power measurement
//     public static void main(String[] args) throws IOException {
//         measurePower(() -> {
//             try {
//                 Thread.sleep(1000); // Simulate workload
//             } catch (InterruptedException e) {
//                 Thread.currentThread().interrupt();
//             }
//         }, 5);
//     }
// }

// import akka.actor.*;
// import java.io.*;
// import java.nio.file.*;
// import java.time.LocalDateTime;
// import java.time.format.DateTimeFormatter;
// import java.util.concurrent.TimeUnit;

// public class PowerBenchmark {
//     public static void main(String[] args) {
//         final ActorSystem system = ActorSystem.create("PowerBenchmarkSystem");
//         final ActorRef benchmarkActor = system.actorOf(Props.create(BenchmarkActor.class), "benchmarkActor");
        
//         benchmarkActor.tell(new StartBenchmark(() -> {
//             // Simulate workload here
//             try { Thread.sleep(5000); } catch (InterruptedException e) { }
//         }, 5), ActorRef.noSender());
//     }

//     static class StartBenchmark {
//         Runnable function;
//         int iterations;
//         public StartBenchmark(Runnable function, int iterations) {
//             this.function = function;
//             this.iterations = iterations;
//         }
//     }
// }

// class BenchmarkActor extends UntypedActor {
//     private final ActorRef powerLogger = getContext().actorOf(Props.create(PowerLogger.class), "powerLogger");
//     private final ActorRef idlePowerLogger = getContext().actorOf(Props.create(IdlePowerLogger.class), "idlePowerLogger");

//     @Override
//     public void onReceive(Object msg) throws Exception {
//         if (msg instanceof PowerBenchmark.StartBenchmark) {
//             PowerBenchmark.StartBenchmark startBenchmarkMsg = (PowerBenchmark.StartBenchmark) msg;
//             idlePowerLogger.tell("start", getSelf());
//             Thread.sleep(5000); // Ensure idle power logging completes
//             for (int i = 0; i < startBenchmarkMsg.iterations; i++) {
//                 long start = System.currentTimeMillis();
//                 powerLogger.tell("start", getSelf());
//                 startBenchmarkMsg.function.run();
//                 powerLogger.tell("stop", getSelf());
//                 long end = System.currentTimeMillis();
//                 System.out.println("Iteration completed in " + (end - start) + " ms");
//             }
//         } else {
//             unhandled(msg);
//         }
//     }
// }

// class PowerLogger extends UntypedActor {
//     private Process process;
//     private static final String LOG_FILE = "power_benchmark.log";
    
//     @Override
//     public void onReceive(Object msg) throws Exception {
//         if (msg.equals("start")) {
//             ProcessBuilder builder = new ProcessBuilder("bash", "-c",
//                 "sudo powermetrics -s cpu_power -n 1 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | " +
//                 "grep -i 'Intel energy model derived CPU core power' >> " + LOG_FILE);
//             process = builder.start();
//         } else if (msg.equals("stop")) {
//             if (process != null) {
//                 process.destroy();
//                 process.waitFor(2, TimeUnit.SECONDS);
//             }
//         } else {
//             unhandled(msg);
//         }
//     }
// }

// class IdlePowerLogger extends UntypedActor {
//     private static final String IDLE_LOG_FILE = "idle_power.log";

//     @Override
//     public void onReceive(Object msg) throws Exception {
//         if (msg.equals("start")) {
//             ProcessBuilder builder = new ProcessBuilder("bash", "-c",
//                 "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | " +
//                 "grep -i 'Intel energy model derived CPU core power' >> " + IDLE_LOG_FILE);
//             Process process = builder.start();
//             process.waitFor();
//         } else {
//             unhandled(msg);
//         }
//     }
// }

// 
import akka.actor.*;
import java.io.*;
import java.util.concurrent.TimeUnit;

public class PowerBenchmark {
    public static void main(String[] args) {
        final ActorSystem system = ActorSystem.create("PowerBenchmarkSystem");
        final ActorRef benchmarkActor = system.actorOf(Props.create(BenchmarkActor.class), "benchmarkActor");

        benchmarkActor.tell(new StartBenchmark(() -> {
            try { Thread.sleep(5000); } catch (InterruptedException e) { }
        }, 5), ActorRef.noSender());
    }

    static class StartBenchmark {
        Runnable function;
        int iterations;
        public StartBenchmark(Runnable function, int iterations) {
            this.function = function;
            this.iterations = iterations;
        }
    }
}

class BenchmarkActor extends UntypedActor {
    private final ActorRef powerLogger = getContext().actorOf(Props.create(PowerLogger.class), "powerLogger");
    private final ActorRef idlePowerLogger = getContext().actorOf(Props.create(IdlePowerLogger.class), "idlePowerLogger");

    @Override
    public void onReceive(Object msg) throws Exception {
        if (msg instanceof PowerBenchmark.StartBenchmark) {
            PowerBenchmark.StartBenchmark startBenchmarkMsg = (PowerBenchmark.StartBenchmark) msg;
            
            // Log idle power before benchmarking
            idlePowerLogger.tell("start", getSelf());
            Thread.sleep(5000); // Ensure idle power logging completes

            for (int i = 0; i < startBenchmarkMsg.iterations; i++) {
                long start = System.currentTimeMillis();

                // Start power logging
                powerLogger.tell("start", getSelf());

                // Execute benchmark function
                startBenchmarkMsg.function.run();

                // Stop power logging
                powerLogger.tell("stop", getSelf());

                long end = System.currentTimeMillis();
                System.out.println("Iteration " + (i + 1) + " completed in " + (end - start) + " ms");
            }

            // Shutdown Akka system after completion
            getContext().system().terminate();
        } else {
            unhandled(msg);
        }
    }
}

class PowerLogger extends UntypedActor {
    private Process process;
    private static final String LOG_FILE = "power_benchmark.log";

    @Override
    public void onReceive(Object msg) throws Exception {
        if (msg.equals("start")) {
            ProcessBuilder builder = new ProcessBuilder("bash", "-c",
                "sudo powermetrics -s cpu_power -n 1 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | " +
                "grep -i 'Intel energy model derived CPU core power' >> " + LOG_FILE);
            process = builder.start();
            process.waitFor(2, TimeUnit.SECONDS);  // Ensure it doesn't run indefinitely
        } else if (msg.equals("stop")) {
            if (process != null) {
                process.destroy();
                process.waitFor(2, TimeUnit.SECONDS);
                process = null;
            }
        } else {
            unhandled(msg);
        }
    }
}

class IdlePowerLogger extends UntypedActor {
    private static final String IDLE_LOG_FILE = "idle_power.log";

    @Override
    public void onReceive(Object msg) throws Exception {
        if (msg.equals("start")) {
            ProcessBuilder builder = new ProcessBuilder("bash", "-c",
                "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | " +
                "grep -i 'Intel energy model derived CPU core power' >> " + IDLE_LOG_FILE);
            Process process = builder.start();
            process.waitFor(); // Ensures it completes before moving forward
        } else {
            unhandled(msg);
        }
    }
}
