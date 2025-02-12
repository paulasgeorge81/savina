-module(benchmark_runner).
-export([run/2]).

% Power metrics functions
-export([start_power_metrics/0, log_idle_power/0,stop_power_metrics/0, generate_log_filename/1]).

% Statistics functions
-export([
    median/1, arithmetic_mean/1, geometric_mean/1, harmonic_mean/1,
    standard_deviation/1, confidence_low/1, confidence_high/1,
    coefficient_of_variation/1, skewness/1
]).

run(BenchmarkModule, NumIterations) ->
        % Get system information
        ErlangVersion = erlang:system_info(otp_release),
        EmulatorVersion = erlang:system_info(version),
        OS_Version = os:cmd("sw_vers -productVersion"),
        OS_Arch = os:cmd("uname -m"),

        % Print runtime and system information
        io:format("Runtime: Erlang/OTP:~s~n", [ErlangVersion]),
        io:format("Erlang Emulator Version: ~s~n", [EmulatorVersion]),
        io:format("Benchmark: ~p~n", [BenchmarkModule]),
        BenchmarkModule:print_config(),
        io:format("~n"),
        
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
        ExecTimes = [
            begin
                {ExecTime, _} = timer:tc(fun() -> BenchmarkModule:run() end),
                ExecTimeMs = ExecTime / 1000.0,  % Convert microseconds to milliseconds
                io:format("~p          Iteration-~p:   ~.3f ms~n", [BenchmarkModule, I, ExecTimeMs]),
                ExecTimeMs
            end || I <- lists:seq(1, NumIterations)
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
        
        io:format("Execution - Summary: ~n"),
        io:format("Benchmark Results (~p iterations):~n", [NumIterations]),
        io:format("Total executions: ~p~n", [length(RawExecTimes)]),
        io:format("Filtered executions: ~p~n", [length(FilteredExecTimes)]),
        io:format("~s Best Time: ~p~n", [BenchmarkModule, BestTime]),
        io:format("~s Worst Time: ~p~n", [BenchmarkModule, WorstTime]),
        io:format("~s Median: ~p~n", [BenchmarkModule, MedianTime]),
        io:format("~s Arith. Mean Time: ~p~n", [BenchmarkModule, ArithMean]),
        io:format("~s Geo. Mean Time: ~p~n", [BenchmarkModule, GeoMean]),
        io:format("~s Harmonic Mean Time: ~p~n", [BenchmarkModule, HarmMean]),
        io:format("~s Std. Dev Time: ~p~n", [BenchmarkModule, StdDev]),
        io:format("~s Lower Confidence: ~p~n", [BenchmarkModule, ConfLow]),
        io:format("~s Higher Confidence: ~p~n", [BenchmarkModule, ConfHigh]),
        io:format("~s Error Window: ~p (~4.3f percent)~n", [BenchmarkModule, ErrorWindow, ErrorPercent]),
        io:format("~s Coeff. of Variation: ~p~n", [BenchmarkModule, CoeffVar]),
        io:format("~s Skewness: ~p~n", [BenchmarkModule, Skew]).
 

log_idle_power() ->
    IdleLogFile = generate_log_filename("idle_power"),
    io:format("Taking idle samples and writing to ~p~n", [IdleLogFile]),
    %PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | grep -i \"Intel energy model derived CPU core power\" | while read line; do echo \"$(date '+%Y-%m-%d %H:%M:%S') $line\" >> " ++ IdleLogFile ++ "; done",
    %PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info > " ++ IdleLogFile ++ " 2>&1", 
    PowerMetricsCmd = 
        "sudo powermetrics --samplers cpu_power,thermal,smc -n 5 -i 1000 -a 0 "
        "--hide-cpu-duty-cycle --show-extra-power-info | "
        "awk 'BEGIN {power=\"N/A\"; util=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"; logfile=\"" ++ IdleLogFile ++ "\"; "
        "if (system(\"test -s \" logfile) != 0) print \"Timestamp,CPU Core Power(W),Cores Active,CPU Temp(C),Pressure Level\" > logfile} "
        "/\\*\\*\\* Sampled system activity/ {timestamp=$6 \" \" $7 \" \" $8 \" \" $9} "
        "/Intel energy model derived CPU core power/ {power=$NF} "
        "/Cores Active:/ {util=$NF} "
        "/Current pressure level/ {pressure=$NF} "
        "/CPU die temperature/ {temp=$(NF-1); "
        "print timestamp \",\" power \",\" util \",\" temp \",\" pressure >> logfile; "
        "power=\"N/A\"; util=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"}'",
    % io:format("Executing command: ~p~n", [PowerMetricsCmd]),
    os:cmd(PowerMetricsCmd),
    timer:sleep(6000),
    IdleLogFile.

start_power_metrics() ->
    BenchmarkLogFile = generate_log_filename("power_metrics"),
    % PowerMetricsCmd = "sudo powermetrics -s cpu_power -i 100 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | "
    %                     "grep -i \"Intel energy model derived CPU core power\" | "
    %                     "while read line; do echo \"$(date '+%Y-%m-%d %H:%M:%S') $line\" >> " ++ BenchmarkLogFile ++ "; done &",
    % PowerMetricsCmd = 
    % "sudo powermetrics --samplers cpu_power,thermal,smc  -i 100 -a 0 "
    % "--hide-cpu-duty-cycle --show-extra-power-info | "
    % "awk 'BEGIN {power=\"N/A\"; util=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"} "
    % "/\\*\\*\\* Sampled system activity/ {timestamp=$6 \" \" $7 \" \" $8 \" \" $9} "
    % "/Intel energy model derived CPU core power/ {power=$NF} "
    % "/Cores Active:/ {util=$NF} "
    % "/Current pressure level/ {pressure=$NF} "
    % "/CPU die temperature/ {temp=$(NF-1); "
    % "print timestamp, power, util, temp, pressure >> \"" ++ BenchmarkLogFile ++ "\"; "
    % "power=\"N/A\"; util=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"}' &",

    PowerMetricsCmd = 
        "sudo powermetrics --samplers cpu_power,thermal,smc -i 100 -a 0 "
        "--hide-cpu-duty-cycle --show-extra-power-info | "
        "awk 'BEGIN {power=\"N/A\"; util=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"; logfile=\"" ++ BenchmarkLogFile ++ "\"; "
        "if (system(\"test -s \" logfile) != 0) print \"Timestamp,CPU Core Power(W),Cores Active,CPU Temp(C),Pressure Level\" > logfile} "
        "/\\*\\*\\* Sampled system activity/ {timestamp=$6 \" \" $7 \" \" $8 \" \" $9} "
        "/Intel energy model derived CPU core power/ {power=$NF} "
        "/Cores Active:/ {util=$NF} "
        "/Current pressure level/ {pressure=$NF} "
        "/CPU die temperature/ {temp=$(NF-1); "
        "print timestamp \",\" power \",\" util \",\" temp \",\" pressure >> logfile; "
        "power=\"N/A\"; util=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"}' &",
                
    os:cmd(PowerMetricsCmd),
    % timer:sleep(2000),  
    BenchmarkLogFile.
    

stop_power_metrics() ->
    os:cmd("sudo pkill -2 powermetrics"),
    {_Date, Time} = calendar:universal_time(),
    FormattedTimestamp = io_lib:format("~p:~p:~p", tuple_to_list(Time)),
    io:format("PowerMetrics stopped at ~p.~n", [lists:flatten(FormattedTimestamp)]),
    io:format("~n").



generate_log_filename(BaseName) ->
    % BaseName ++ ".log".
    {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:universal_time(),
    lists:flatten(io_lib:format("~s_~p_~p_~p_~p:~p:~p.csv", 
                [BaseName, Year, Month, Day, Hour, Min, Sec])).

%% Calculate the median of a sorted list
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

%% Calculate the arithmetic mean
arithmetic_mean(List) ->
    lists:sum(List) / length(List).

%% Calculate the geometric mean
geometric_mean(List) ->
    Product = lists:foldl(fun(X, Acc) -> Acc * X end, 1, List),
    math:pow(Product, 1 / length(List)).

%% Calculate the harmonic mean
harmonic_mean(List) ->
    length(List) / lists:sum([1 / X || X <- List]).

%% Calculate standard deviation
standard_deviation(List) ->
    Mean = arithmetic_mean(List),
    Variance = lists:sum([math:pow(X - Mean, 2) || X <- List]) / length(List),
    math:sqrt(Variance).

%% Confidence interval calculations (assuming 95% confidence level)
confidence_low(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    Mean - (1.96 * StdDev / math:sqrt(length(List))).

confidence_high(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    Mean + (1.96 * StdDev / math:sqrt(length(List))).

%% Calculate coefficient of variation (CV = StdDev / Mean)
coefficient_of_variation(List) ->
    standard_deviation(List) / arithmetic_mean(List).

%% Calculate skewness
skewness(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    N = length(List),
    lists:sum([math:pow((X - Mean) / StdDev, 3) || X <- List]) / N.
