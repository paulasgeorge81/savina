-module(temp).
-export([run/2]).

% Power metrics functions
-export([start_power_metrics/0, log_idle_power/0, stop_power_metrics/0, generate_log_filename/1]).

% Statistics functions
-export([
    median/1, arithmetic_mean/1, geometric_mean/1, harmonic_mean/1,
    standard_deviation/1, confidence_low/1, confidence_high/1,
    coefficient_of_variation/1, skewness/1
]).

run(BenchmarkModule, NumIterations) ->
    % Print runtime and system information
    io:format("Runtime: Java:21.0.4::Scala:2.11.12~n"),
    io:format("Benchmark: ~p~n", [BenchmarkModule]),
    io:format("Args:~n"),
    io:format("    N (num pings) = 100000~n"),
    io:format("            debug = true~n"),
    io:format("~n"),
    
    OS_Version = os:cmd("sw_vers -productVersion"),
    OS_Arch = os:cmd("uname -m"),
    io:format("     Java Version = 21.0.4~n"),
    io:format("      O/S Version = ~s", [OS_Version]),
    io:format("         O/S Name = Mac OS X~n"),
    io:format("         O/S Arch = ~s", [OS_Arch]),

    % Log idle power consumption before benchmarking
    IdlePowerLogFile = log_idle_power(),
    io:format("Idle Power Log File: ~s~n", [IdlePowerLogFile]),
    % Start power metrics collection
    BenchmarkLogFile = start_power_metrics(),
    io:format("Benchmark Power Log File: ~s~n", [BenchmarkLogFile]),
    
    io:format("Execution - Iterations:~n"),
    
    % Run the benchmark while triggering power samples
    ExecTimes = [
        begin
            Start = os:timestamp(),
            BenchmarkModule:run(),
            End = os:timestamp(),
            Time = timer:now_diff(End, Start) / 1000, % Convert to ms
            io:format("~p          Iteration-~p:   ~.3f ms~n", [BenchmarkModule, I, Time]),
            Time
        end || I <- lists:seq(0, NumIterations - 1)
    ],

    % Stop power metrics collection
    stop_power_metrics(),

    % Compute benchmark statistics
    RawExecTimes = ExecTimes,
    FilteredExecTimes = lists:sort(ExecTimes),
    BestTime = hd(FilteredExecTimes),
    WorstTime = lists:last(FilteredExecTimes),
    MedianTime = median(FilteredExecTimes),
    ArithMean = arithmetic_mean(FilteredExecTimes),
    GeoMean = geometric_mean(FilteredExecTimes),
    HarmMean = harmonic_mean(FilteredExecTimes),
    StdDev = standard_deviation(FilteredExecTimes),
    ConfLow = confidence_low(FilteredExecTimes),
    ConfHigh = confidence_high(FilteredExecTimes),
    ErrorWindow = ConfHigh - ArithMean,
    ErrorPercent = 100 * ErrorWindow / ArithMean,
    CoeffVar = coefficient_of_variation(FilteredExecTimes),
    Skew = skewness(FilteredExecTimes),

    io:format("Execution - Summary:~n"),
    io:format("Benchmark Results (~p iterations):~n", [NumIterations]),
    io:format("Total executions: ~p~n", [length(RawExecTimes)]),
    io:format("Filtered executions: ~p~n", [length(FilteredExecTimes)]),
    io:format("Best Time: ~p ms~n", [BestTime]),
    io:format("Worst Time: ~p ms~n", [WorstTime]),
    io:format("Median: ~p ms~n", [MedianTime]),
    io:format("Arith. Mean Time: ~p ms~n", [ArithMean]),
    io:format("Geo. Mean Time: ~p ms~n", [GeoMean]),
    io:format("Harmonic Mean Time: ~p ms~n", [HarmMean]),
    io:format("Std. Dev Time: ~p ms~n", [StdDev]),
    io:format("Lower Confidence: ~p ms~n", [ConfLow]),
    io:format("Higher Confidence: ~p ms~n", [ConfHigh]),
    io:format("Error Window: ~p ms (~4.3f percent)~n", [ErrorWindow, ErrorPercent]),
    io:format("Coeff. of Variation: ~p~n", [CoeffVar]),
    io:format("Skewness: ~p~n", [Skew]).

% Generate log filenames with timestamps
generate_log_filename(BaseName) ->
    {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:universal_time(),
    lists:flatten(io_lib:format("~s_~p_~p_~p_~p:~p:~p.log", 
                [BaseName, Year, Month, Day, Hour, Min, Sec])).

% Start logging idle power
log_idle_power() ->
    IdleLogFile = generate_log_filename("idle_power"),
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | "
                      "grep -i \"Intel energy model derived CPU core power\" | "
                      "while read line; do echo \"$(date '+%Y-%m-%d %H:%M:%S') $line\" >> " ++ IdleLogFile ++ "; done",
    os:cmd(PowerMetricsCmd),
    timer:sleep(6000),
    IdleLogFile.

% Start power metrics logging
start_power_metrics() ->
    BenchmarkLogFile = generate_log_filename("power_metrics"),
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -i 100 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | "
                      "grep -i \"Intel energy model derived CPU core power\" | "
                      "while read line; do echo \"$(date '+%Y-%m-%d %H:%M:%S') $line\" >> " ++ BenchmarkLogFile ++ "; done &",
    os:cmd(PowerMetricsCmd),
    BenchmarkLogFile.

% Stop power metrics logging
stop_power_metrics() ->
    os:cmd("sudo pkill -2 powermetrics"),
    {_Date, Time} = calendar:universal_time(),
    FormattedTimestamp = io_lib:format("~p:~p:~p", tuple_to_list(Time)),
    io:format("PowerMetrics stopped at ~p.~n", [lists:flatten(FormattedTimestamp)]).

% Statistic functions
median(List) -> 
    Sorted = lists:sort(List),
    Len = length(Sorted),
    case Len rem 2 of
        1 -> lists:nth((Len div 2) + 1, Sorted);
        0 ->
            A = lists:nth(Len div 2, Sorted),
            B = lists:nth((Len div 2) + 1, Sorted),
            (A + B) / 2
    end.

arithmetic_mean(List) -> lists:sum(List) / length(List).

geometric_mean(List) ->
    Product = lists:foldl(fun(X, Acc) -> Acc * X end, 1, List),
    math:pow(Product, 1 / length(List)).

harmonic_mean(List) -> length(List) / lists:sum([1 / X || X <- List]).

standard_deviation(List) ->
    Mean = arithmetic_mean(List),
    Variance = lists:sum([math:pow(X - Mean, 2) || X <- List]) / length(List),
    math:sqrt(Variance).

confidence_low(List) -> 
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    Mean - (1.96 * StdDev / math:sqrt(length(List))).

confidence_high(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    Mean + (1.96 * StdDev / math:sqrt(length(List))).

coefficient_of_variation(List) -> standard_deviation(List) / arithmetic_mean(List).

skewness(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    lists:sum([math:pow((X - Mean) / StdDev, 3) || X <- List]) / length(List).
