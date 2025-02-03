-module(benchmark_runner).
-export([run/2]).
% Power metrics functions
-export([start_power_metrics/0, log_idle_power/0, trigger_power_sample/1, flush_power_data/1, stop_power_metrics/1, generate_log_filename/1, calculate_total_power/2]).

run(BenchmarkModule, NumIterations) ->
    % Log idle power consumption before benchmarking
    IdlePowerLogFile = log_idle_power(),

    % Start power metrics collection
    {PowerMetricsPid, BenchmarkLogFile} = start_power_metrics(),

    % Run the benchmark while triggering power samples
    IterationLogFiles = [log_iteration_power(PowerMetricsPid, BenchmarkModule, N) || N <- lists:seq(1, NumIterations)],

    % Stop power metrics collection
    stop_power_metrics(PowerMetricsPid),

    % Compute benchmark statistics
    TotalPowerConsumption = calculate_total_power(IterationLogFiles, IdlePowerLogFile),
    io:format("Total Power Consumption (minus idle): ~p mW~n", [TotalPowerConsumption]),
    
    io:format("Benchmark Power Log Files: ~p~n", [IterationLogFiles]).

measure_time(Fun) ->
    {Time, _Result} = timer:tc(Fun),
    Time.

log_idle_power() ->
    IdleLogFile = generate_log_filename("idle_power"),
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info > " ++ IdleLogFile ++ " 2>&1", 
    os:cmd(PowerMetricsCmd),
    timer:sleep(6000),  % Give time to capture idle power samples
    os:cmd("sudo pkill -2 powermetrics"),
    IdleLogFile.

start_power_metrics() ->
    BenchmarkLogFile = generate_log_filename("power_metrics"),
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info > " 
                      ++ BenchmarkLogFile ++ " 2>&1 & echo $!",
    PidStr = string:trim(os:cmd(PowerMetricsCmd)),  % Trim newline
    case catch list_to_integer(PidStr) of
        Pid when is_integer(Pid) -> 
            io:format("PowerMetrics started with PID: ~p~nLogging to file: ~s~n", [Pid, BenchmarkLogFile]),
            {Pid, BenchmarkLogFile};
        _ ->
            io:format("Failed to start PowerMetrics. Output: ~s~n", [PidStr]),
            exit(start_power_metrics_failed)
    end.

log_iteration_power(Pid, BenchmarkModule, Iteration) ->
    IterationLogFile = generate_log_filename("iteration_" ++ integer_to_list(Iteration)),
    trigger_power_sample(Pid), % Take a power sample
    TimeTaken = measure_time(fun() -> BenchmarkModule:run() end),
    flush_power_data(Pid), % Flush power data
    {Iteration, IterationLogFile, TimeTaken}.

trigger_power_sample(Pid) ->
    os:cmd("sudo kill -29 " ++ integer_to_list(Pid)).

flush_power_data(Pid) ->
    os:cmd("sudo kill -23 " ++ integer_to_list(Pid)).

stop_power_metrics(Pid) ->
    os:cmd("sudo kill -15 " ++ integer_to_list(Pid)),
    {_Date, Time} = calendar:universal_time(),
    FormattedTimestamp = io_lib:format("~p:~p:~p", tuple_to_list(Time)),
    io:format("PowerMetrics stopped at ~p.~n", [lists:flatten(FormattedTimestamp)]).

calculate_total_power(IterationLogFiles, IdlePowerLogFile) ->
    % Dummy function to calculate total power minus idle
    % You will need to implement log parsing here
    io:format("Calculating total power consumption...~n"),
    0.

generate_log_filename(BaseName) ->
    {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:universal_time(),
    lists:flatten(io_lib:format("~s_~p_~p_~p_~p:~p:~p.log", 
                [BaseName, Year, Month, Day, Hour, Min, Sec])).
