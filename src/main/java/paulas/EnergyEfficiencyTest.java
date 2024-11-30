package paulas;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class EnergyEfficiencyTest {
    public static void main(String[] args) {
        try {
            ProcessBuilder processBuilder = new ProcessBuilder("sudo", "/usr/bin/powermetrics", "-i", "1000", "-s", "all", "-a", "10", "-n", "5");
            Process process = processBuilder.start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder output = new StringBuilder();
            String line;

            // Read output from powermetrics
            while ((line = reader.readLine()) != null) {
                output.append(getTimestamp()).append(" - ").append(line).append("\n");
            }

            // Wait for the process to complete
            process.waitFor();

            // Print power metrics output
            System.out.println("Power metrics output:\n" + output.toString());

            // Example computation (modify as needed)
            long sum = 0;
            for (long i = 0; i < 1000000000; i++) {
                sum += i;
            }
            System.out.println("The sum is: " + sum);
            System.out.println("Finished computation at: " + getTimestamp());
        } catch (IOException | InterruptedException e) {
            e.printStackTrace();
        }
    }

    private static String getTimestamp() {
        DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss");
        return dtf.format(LocalDateTime.now());
    }
}
