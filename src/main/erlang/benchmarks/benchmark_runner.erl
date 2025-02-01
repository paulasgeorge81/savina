-module(benchmark_runner).
-export([run/2]).
% Power metrics functions
-export([start_power_metrics/0, trigger_power_sample/1, flush_power_data/1, stop_power_metrics/1]).

run(BenchmarkModule, NumIterations) ->
        % Start power metrics collection
        PowerMetricsPid = start_power_metrics(),

        % Open log file for writing power metrics
        {ok, LogFile} = file:open("power_metrics.log", [write, raw]),
    
        % Run the benchmark while triggering power samples
        Times = [measure_time(fun() -> 
            trigger_power_sample(PowerMetricsPid), % Take a power sample
            BenchmarkModule:run(),
            flush_power_data(PowerMetricsPid) % Flush power data
        end) || _ <- lists:seq(1, NumIterations)],
    
        % Stop power metrics collection
        stop_power_metrics(PowerMetricsPid),
    
        % Close the log file
        file:close(LogFile),
    
        % Compute benchmark statistics
        BestTime = lists:min(Times),
        WorstTime = lists:max(Times),
        AvgTime = lists:sum(Times) div NumIterations,
         
        io:format("Benchmark Results (~p iterations):~n", [NumIterations]),
        io:format("  Best Time: ~p microseconds~n", [BestTime]),
        io:format("  Worst Time: ~p microseconds~n", [WorstTime]),
        io:format("  Average Time: ~p microseconds~n", [AvgTime]).


measure_time(Fun) ->
    {Time, _Result} = timer:tc(Fun),
    Time.

start_power_metrics() ->
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 1 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info > power_metrics.log 2>&1 & echo $!",
    PidStr = string:trim(os:cmd(PowerMetricsCmd)),  % Trim newline
    Pid = list_to_integer(PidStr), % Convert to integer
    io:format("PowerMetrics started with PID: ~p~n", [Pid]),
    Pid.



% Trigger an immediate power sample
trigger_power_sample(Pid) ->
    os:cmd("sudo kill -29 " ++ integer_to_list(Pid)).

% Flush power data
flush_power_data(Pid) ->
    os:cmd("sudo kill -23 " ++ integer_to_list(Pid)).

% Stop powermetrics
stop_power_metrics(Pid) ->
    os:cmd("sudo kill -2 " ++ integer_to_list(Pid)),
    io:format("PowerMetrics stopped.~n").
