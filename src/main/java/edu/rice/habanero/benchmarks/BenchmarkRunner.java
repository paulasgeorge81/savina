package edu.rice.habanero.benchmarks;

import edu.rice.habanero.actors.AkkaActorState;
import edu.rice.hj.runtime.config.HjSystemProperty;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.*;

/**
 * @author <a href="http://shams.web.rice.edu/">Shams Imam</a> (shams@rice.edu)
 */
public class BenchmarkRunner {

    public static final String statDataOutputFormat = "%20s %20s: %9.3f \n";
    public static final String execTimeOutputFormat = "%20s %20s: %9.3f ms \n";
    public static final String argOutputFormat = "%25s = %-10s \n";
    protected static final double tolerance = 0.20;

    protected static int iterations = 12;

    private static void parseArgs(final String[] args) throws Exception {

        final String numWorkers = HjSystemProperty.numWorkers.getPropertyValue();
        if (numWorkers != null) {
            System.setProperty("actors.corePoolSize", numWorkers);
            System.setProperty("actors.maxPoolSize", numWorkers);
        }

        final int argLimit = args.length - 1;
        for (int i = 0; i < argLimit; i++) {
            final String argName = args[i];
            final String argValue = args[i + 1];

            if (argName.equalsIgnoreCase("-iter")) {
                iterations = Integer.parseInt(argValue);
            }
        }
    }

    public static void runBenchmark(final String[] args, final Benchmark benchmark) {
        try {
            parseArgs(args);
            benchmark.initialize(args);
        } catch (final Exception e) {
            e.printStackTrace(System.err);
            System.exit(1);
        }

        final String benchmarkName = benchmark.name();
        if (benchmarkName.contains("Akka")) {
            AkkaActorState.initialize();
        }

        System.out.println("Runtime: " + benchmark.runtimeInfo());
        System.out.println("Benchmark: " + benchmarkName);
        System.out.println("Args: ");
        benchmark.printArgInfo();
        System.out.println();
        System.out.printf(argOutputFormat, "Java Version", System.getProperty("java.version"));
        System.out.printf(argOutputFormat, "O/S Version", System.getProperty("os.version"));
        System.out.printf(argOutputFormat, "O/S Name", System.getProperty("os.name"));
        System.out.printf(argOutputFormat, "O/S Arch", System.getProperty("os.arch"));
        System.out.println();
        
        //Log idle power consumption before benchmarking
        String powerMetricsBenchmarkName = benchmarkName.replaceAll("([a-z])([A-Z])", "$1_$2").toLowerCase();
        logIdlePower(powerMetricsBenchmarkName);

        //Start power metrics collection
        startPowerMetrics(powerMetricsBenchmarkName);

        final List<Double> rawExecTimes = new ArrayList<>(iterations);

        {

            System.out.println("Execution - Iterations: ");
            for (int i = 0; i < iterations; i++) {
                final long startTime = System.nanoTime();
                benchmark.runIteration();
                final long endTime = System.nanoTime();

                final double execTimeMillis = (endTime - startTime) / 1e6;
                rawExecTimes.add(execTimeMillis);

                System.out.printf(execTimeOutputFormat, benchmark.name(), " Iteration-" + i, execTimeMillis);
                benchmark.cleanupIteration(i + 1 == iterations, execTimeMillis);
            }
            System.out.println();
            
        }
        System.out.println();

        //Stop power metrics collection
        stopPowerMetrics();

        final Map<String, List<Double>> customAttrs = benchmark.customAttrs;
        if (!customAttrs.isEmpty()) {
            System.out.println("Attributes - Summary: ");
            for (final Map.Entry<String, List<Double>> loopEntry : customAttrs.entrySet()) {
                final String attrName = loopEntry.getKey();
                final List<Double> attrValues = loopEntry.getValue();
                final List<Double> sanitizedAttrValue = sanitize(attrValues, 0.30);
                System.out.printf(statDataOutputFormat.trim(), benchmark.name(), " " + attrName, arithmeticMean(sanitizedAttrValue));
                System.out.printf(" [%3d of %3d values] \n", sanitizedAttrValue.size(), attrValues.size());
            }
        }

        Collections.sort(rawExecTimes);
        final List<Double> execTimes = sanitize(rawExecTimes, tolerance);

        System.out.println("Execution - Summary: ");
        System.out.printf(argOutputFormat, "Total executions", rawExecTimes.size());
        System.out.printf(argOutputFormat, "Filtered executions", execTimes.size());
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Best Time", execTimes.get(0));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Worst Time", execTimes.get(execTimes.size() - 1));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Median", median(execTimes));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Arith. Mean Time", arithmeticMean(execTimes));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Geo. Mean Time", geometricMean(execTimes));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Harmonic Mean Time", harmonicMean(execTimes));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Std. Dev Time", standardDeviation(execTimes));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Lower Confidence", confidenceLow(execTimes));
        System.out.printf(execTimeOutputFormat, benchmark.name(), " Higher Confidence", confidenceHigh(execTimes));
        System.out.printf(execTimeOutputFormat.trim() + " (%4.3f percent) \n", benchmark.name(), " Error Window",
                          confidenceHigh(execTimes) - arithmeticMean(execTimes),
                          100 * (confidenceHigh(execTimes) - arithmeticMean(execTimes)) / arithmeticMean(execTimes));
        System.out.printf(statDataOutputFormat, benchmark.name(), " Coeff. of Variation", coefficientOfVariation(execTimes));
        System.out.printf(statDataOutputFormat, benchmark.name(), " Skewness", skewness(execTimes));

        System.out.println();
    }


    private static String logIdlePower(String Benchmark) {
        String IdleLogFile = generateLogFilename(Benchmark+"_idle_power");
        System.out.println("Idle sampling started, writing to " + IdleLogFile);
        String PowerMetricsCmd = 
        "sudo powermetrics --samplers cpu_power,thermal,smc -n 10 -i 500 -a 0 "
        +"--hide-cpu-duty-cycle --show-extra-power-info | "
        +"awk 'BEGIN {core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"; logfile=\"" + IdleLogFile + "\"; "
        +"if (system(\"test -s \" logfile) != 0) print \"Timestamp,CPU Core Power(W),GT Power(W),DRAM Power(W),(CPUs+GT+SA) Power(W),Avg Num Cores Active,Cores Active(%),CPU Temp(C),Pressure Level\" > logfile} "
        +"/\\*\\*\\* Sampled system activity/ {timestamp=$5 \" \" $6 \" \" $7 \" \" $8 \" \" $9 \" \" $10 \" \" $11 \" \" $12} "
        +"/Intel energy model derived package power/ {cpu_gt_sa_power=$NF; gsub(/W/, \"\", cpu_gt_sa_power)} "
        +"/Intel energy model derived CPU core power/ {core_power=$NF; gsub(/W/, \"\", core_power)} "
        +"/Intel energy model derived GT power/ {gt_power=$NF; gsub(/W/, \"\", gt_power)} "
        +"/Intel energy model derived DRAM power/ {dram_power=$NF; gsub(/W/, \"\", dram_power)} "
        +"/Avg Num of Cores Active/ {avg_cores_active=$NF} "
        +"/^(Cores Active:)/ {cores_active=$NF; gsub(/%/, \"\", cores_active)} "
        +"/Current pressure level/ {pressure=$NF} "
        +"/CPU die temperature/ {sub(/.*: /, \"\", $0); temp=$0; "
        +"print timestamp \",\" core_power \",\" gt_power \",\" dram_power \",\" cpu_gt_sa_power \",\" avg_cores_active \",\" cores_active \",\" temp \",\" pressure >> logfile; "
        +"core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"}'";
        executeCommand(PowerMetricsCmd);
        try { Thread.sleep(6000); } catch (InterruptedException e) { e.printStackTrace(); }
        return IdleLogFile;
    }


    private static String startPowerMetrics(String Benchmark) {
        String BenchmarkLogFile = generateLogFilename(Benchmark+"_power_metrics");
        System.out.println("Benchmark sampling started, writing to " + BenchmarkLogFile+ "\n");
        String PowerMetricsCmd = 
        "sudo powermetrics --samplers cpu_power,thermal,smc -i 1000 -a 0 "
        +"--hide-cpu-duty-cycle --show-extra-power-info | "
        +"awk 'BEGIN {core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"; logfile=\"" + BenchmarkLogFile + "\"; "
        +"if (system(\"test -s \" logfile) != 0) print \"Timestamp,CPU Core Power(W),GT Power(W),DRAM Power(W),(CPUs+GT+SA) Power(W),Avg Num Cores Active,Cores Active(%),CPU Temp(C),Pressure Level\" > logfile} "
        +"/\\*\\*\\* Sampled system activity/ {timestamp=$5 \" \" $6 \" \" $7 \" \" $8 \" \" $9 \" \" $10 \" \" $11 \" \" $12} "
        +"/Intel energy model derived package power/ {cpu_gt_sa_power=$NF; gsub(/W/, \"\", cpu_gt_sa_power)} "
        +"/Intel energy model derived CPU core power/ {core_power=$NF; gsub(/W/, \"\", core_power)} "
        +"/Intel energy model derived GT power/ {gt_power=$NF; gsub(/W/, \"\", gt_power)} "
        +"/Intel energy model derived DRAM power/ {dram_power=$NF; gsub(/W/, \"\", dram_power)} "
        +"/Avg Num of Cores Active/ {avg_cores_active=$NF} "
        +"/^(Cores Active:)/ {cores_active=$NF; gsub(/%/, \"\", cores_active)} "
        +"/Current pressure level/ {pressure=$NF} "
        +"/CPU die temperature/ {sub(/.*: /, \"\", $0); temp=$0; "
        +"print timestamp \",\" core_power \",\" gt_power \",\" dram_power \",\" cpu_gt_sa_power \",\" avg_cores_active \",\" cores_active \",\" temp \",\" pressure >> logfile; "
        +"core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"}' &";
        executeCommand(PowerMetricsCmd);
        // try { Thread.sleep(1000); } catch (InterruptedException e) { e.printStackTrace(); }
        return BenchmarkLogFile;
    }
   

   
    private static void stopPowerMetrics() {
        executeCommand("sudo pkill -2 powermetrics");

        SimpleDateFormat sdf = new SimpleDateFormat("HH:mm:ss");
        String formattedTime = sdf.format(new Date());
        System.out.println();
        System.out.println("PowerMetrics stopped at " + formattedTime + ".");
        System.out.println();
    }

     private static void executeCommand(String command) {
        try {
            Process process = new ProcessBuilder("bash", "-c", command).start();
            process.waitFor();
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    private static String generateLogFilename(String baseName) {
        executeCommand("mkdir -p ./src/main/data");
        SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMddHHmmss");
        String timestamp = sdf.format(new Date());
        return "./src/main/data/" + timestamp + "_" + baseName + ".csv";
    }

    public static List<Double> sanitize(final List<Double> rawList, final double tolerance) {
        if (rawList.isEmpty()) {
            return new ArrayList<>(0);
        }

        Collections.sort(rawList);
        final int rawListSize = rawList.size();

        final List<Double> resultList = new ArrayList<>();
        final double median = rawList.get(rawListSize / 2);
        final double allowedMin = (1 - tolerance) * median;
        final double allowedMax = (1 + tolerance) * median;

        for (final double loopVal : rawList) {
            if (loopVal >= allowedMin && loopVal <= allowedMax) {
                resultList.add(loopVal);
            }
        }
        return resultList;
    }

    public static double arithmeticMean(final Collection<Double> execTimes) {

        double sum = 0;

        for (final double execTime : execTimes) {
            sum += execTime;
        }

        return (sum / execTimes.size());
    }

    public static double median(final List<Double> execTimes) {

        if (execTimes.isEmpty()) {
            return 0;
        }

        final int size = execTimes.size();
        final int middle = size / 2;
        if (size % 2 == 1) {
            return execTimes.get(middle);
        } else {
            return (execTimes.get(middle - 1) + execTimes.get(middle)) / 2.0;
        }
    }

    public static double geometricMean(final Collection<Double> execTimes) {
        double lgProd = 0;

        for (final double execTime : execTimes) {
            lgProd += Math.log10(execTime);
        }

        return Math.pow(10, lgProd / execTimes.size());
    }

    public static double harmonicMean(final Collection<Double> execTimes) {
        double denom = 0;

        for (final double execTime : execTimes) {
            denom += (1 / execTime);
        }

        return (execTimes.size() / denom);
    }

    public static double standardDeviation(final Collection<Double> execTimes) {

        final double mean = arithmeticMean(execTimes);

        double temp = 0;
        for (final double execTime : execTimes) {
            temp += ((mean - execTime) * (mean - execTime));
        }

        return Math.sqrt(temp / execTimes.size());
    }

    public static double coefficientOfVariation(final Collection<Double> execTimes) {
        final double mean = arithmeticMean(execTimes);
        final double sd = standardDeviation(execTimes);

        return (sd / mean);
    }

    public static double confidenceLow(final Collection<Double> execTimes) {
        final double mean = arithmeticMean(execTimes);
        final double sd = standardDeviation(execTimes);

        return mean - (1.96d * sd / Math.sqrt(execTimes.size()));
    }

    public static double confidenceHigh(final Collection<Double> execTimes) {
        final double mean = arithmeticMean(execTimes);
        final double sd = standardDeviation(execTimes);

        return mean + (1.96d * sd / Math.sqrt(execTimes.size()));
    }

    /**
     * Returns the sample Skewness measure of asymmetry of an array of numbers. Source:
     * http://socr.googlecode.com/svn/trunk/SOCR2.0/src/org/jfree/data/statistics/Statistics.java
     *
     * @return the sample Skewness measure of asymmetry of an array of numbers.
     */
    public static double skewness(final List<Double> execTimes) {
        final double mean = arithmeticMean(execTimes);
        final double sd = standardDeviation(execTimes);
        double sum = 0.0;
        int count = 0;
        if (execTimes.size() > 1) {
            for (final Double execTime : execTimes) {
                final double current = execTime;
                final double diff = current - mean;
                sum = sum + diff * diff * diff;
                count++;
            }
            return sum / ((count - 1) * sd * sd * sd);
        } else {
            return 0.0;
        }
    }
}
