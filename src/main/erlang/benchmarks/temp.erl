-module(benchmark_runner).
-export([run/2]).
% Power metrics functions
-export([start_power_metrics/0, log_idle_power/0, trigger_power_sample/1, flush_power_data/1, stop_power_metrics/1]).

run(BenchmarkModule, NumIterations) ->
    % Log idle power before benchmarking
    IdlePowerLogFile = log_idle_power(),
    
    % Start power metrics collection for the benchmark
    {PowerMetricsPid, BenchmarkLogFile} = start_power_metrics(),

    % Run the benchmark while logging power samples
    Times = [measure_time(fun() -> 
        trigger_power_sample(PowerMetricsPid),
        BenchmarkModule:run(),
        flush_power_data(PowerMetricsPid)
    end) || _ <- lists:seq(1, NumIterations)],

    % Stop power metrics collection
    stop_power_metrics(PowerMetricsPid),

    % Compute benchmark statistics
    BestTime = lists:min(Times),
    WorstTime = lists:max(Times),
    AvgTime = lists:sum(Times) div NumIterations,
    
    io:format("Benchmark Results (~p iterations):~n", [NumIterations]),
    io:format("  Best Time: ~p microseconds~n", [BestTime]),
    io:format("  Worst Time: ~p microseconds~n", [WorstTime]),
    io:format("  Average Time: ~p microseconds~n", [AvgTime]),
    io:format("  Idle Power Log File: ~s~n", [IdlePowerLogFile]),
    io:format("  Benchmark Power Log File: ~s~n", [BenchmarkLogFile]).

measure_time(Fun) ->
    {Time, _Result} = timer:tc(Fun),
    Time.

log_idle_power() ->
    IdleLogFile = generate_log_filename("idle_power"),
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info > " 
                      ++ IdleLogFile ++ " 2>&1 & echo $!",
    os:cmd(PowerMetricsCmd),
    timer:sleep(6000),  % Give time for 5 samples
    os:cmd("sudo pkill -2 powermetrics"),
    io:format("Idle power logged in: ~s~n", [IdleLogFile]),
    IdleLogFile.

start_power_metrics() ->
    BenchmarkLogFile = generate_log_filename("power_metrics"),
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info > " 
                      ++ BenchmarkLogFile ++ " 2>&1 & echo $!",
    PidStr = string:trim(os:cmd(PowerMetricsCmd)),
    case catch list_to_integer(PidStr) of
        Pid when is_integer(Pid) -> 
            io:format("PowerMetrics started with PID: ~p~nLogging to file: ~s~n", [Pid, BenchmarkLogFile]),
            {Pid, BenchmarkLogFile};
        _ ->
            io:format("Failed to start PowerMetrics. Output: ~s~n", [PidStr]),
            exit(start_power_metrics_failed)
    end.

trigger_power_sample(Pid) ->
    os:cmd("sudo kill -29 " ++ integer_to_list(Pid)).

flush_power_data(Pid) ->
    os:cmd("sudo kill -23 " ++ integer_to_list(Pid)).

stop_power_metrics(Pid) ->
    os:cmd("sudo kill -15 " ++ integer_to_list(Pid)),
    io:format("PowerMetrics stopped.~n").

generate_log_filename(BaseName) ->
    {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:universal_time(),
    lists:flatten(io_lib:format("~s_~p-~p-~p_~p-~p-~p.log", 
                [BaseName, Year, Month, Day, Hour, Min, Sec])).
