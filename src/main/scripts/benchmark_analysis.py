import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

def remove_outliers(df, columns):
    """
    Removes outliers from the specified columns using the IQR method.
    """
    df_clean = df.copy()
    
    for column in columns:
        Q1 = df_clean[column].quantile(0.25)
        Q3 = df_clean[column].quantile(0.75)
        IQR = Q3 - Q1
        
        lower_bound = Q1 - 1.5 * IQR
        upper_bound = Q3 + 1.5 * IQR
        
        df_clean = df_clean[(df_clean[column] >= lower_bound) & (df_clean[column] <= upper_bound)]
    
    return df_clean

def plot_graphs(idle_df, bench_df, title):
    """
    Plots graphs for power usage in idle vs. benchmark states.
    """
    columns_to_plot = [
        "CPU Core Power(W)", "GT Power(W)", "DRAM Power(W)", 
        "(CPUs+GT+SA) Power(W)", "Avg Num Cores Active", "CPU Temp(C)"
    ]
    
    plt.figure(figsize=(12, 8))
    
    for column in columns_to_plot:
        plt.plot(idle_df["Timestamp"], idle_df[column], label=f"Idle - {column}", linestyle='dashed')
        plt.plot(bench_df["Timestamp"], bench_df[column], label=f"Benchmark - {column}")

    plt.xlabel("Time")
    plt.ylabel("Power / Temperature / Activity")
    plt.title(title)
    plt.legend()
    plt.xticks(rotation=45)
    plt.grid(True)
    plt.show()

def calculate_net_energy(bench_df, idle_df, time_column, power_columns):
    """
    Calculates the net energy consumption by subtracting idle power from benchmark power.
    """
    avg_idle_power = idle_df[power_columns].mean()  # Compute average idle power per column
    time_elapsed = bench_df[time_column].diff().fillna(0) / 1000  # Convert ms to seconds

    net_energy = {}
    for column in power_columns:
        energy = ((bench_df[column] - avg_idle_power[column]) * time_elapsed).sum()
        net_energy[column] = energy

    return net_energy

# Load Scala benchmark data
scala_idle_data = pd.read_csv('../data/20250307090345_thread_ring_akka_actor_benchmark_idle_power.csv')
scala_bench_data = pd.read_csv('../data/20250307090356_thread_ring_akka_actor_benchmark_power_metrics.csv')

# Load Erlang benchmark data
erlang_idle_data = pd.read_csv('../data/20250307090440_thread_ring_benchmark_idle_power.csv')
erlang_bench_data = pd.read_csv('../data/20250307090451_thread_ring_benchmark_power_metrics.csv')

# Columns for outlier removal
columns_of_interest = [
    "CPU Core Power(W)", "GT Power(W)", "DRAM Power(W)", 
    "(CPUs+GT+SA) Power(W)", "Avg Num Cores Active", "CPU Temp(C)"
]

# Clean data
scala_idle_clean = remove_outliers(scala_idle_data, columns_of_interest)
scala_bench_clean = remove_outliers(scala_bench_data, columns_of_interest)
erlang_idle_clean = remove_outliers(erlang_idle_data, columns_of_interest)
erlang_bench_clean = remove_outliers(erlang_bench_data, columns_of_interest)

# Plot graphs
plot_graphs(scala_idle_clean, scala_bench_clean, "Scala Benchmark - Idle vs Active Power")
plot_graphs(erlang_idle_clean, erlang_bench_clean, "Erlang Benchmark - Idle vs Active Power")

# Compute net energy consumption
power_columns = ["CPU Core Power(W)", "GT Power(W)", "DRAM Power(W)", "(CPUs+GT+SA) Power(W)"]

scala_energy = calculate_net_energy(scala_bench_clean, scala_idle_clean, "Time Elapsed (ms)", power_columns)
erlang_energy = calculate_net_energy(erlang_bench_clean, erlang_idle_clean, "Time Elapsed (ms)", power_columns)

# Compute energy difference
energy_difference = {key: scala_energy[key] - erlang_energy[key] for key in scala_energy}

# Print results
print("\nNet Energy Consumption (Joules) Comparison:")
print("Scala Benchmark:", scala_energy)
print("Erlang Benchmark:", erlang_energy)
print("Energy Difference (Scala - Erlang):", energy_difference)
