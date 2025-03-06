-module(benchmark_runner).
-export([run/2]).

% Power metrics functions
-export([start_power_metrics/1, log_idle_power/1,stop_power_metrics/0, generate_log_filename/1]).

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
        io:format("Config: ~n"),
        BenchmarkModule:print_config(),
        io:format("~n"),
        
        io:format("      O/S Version = ~s", [OS_Version]),
        io:format("         O/S Name = Mac OS X~n"),
        io:format("         O/S Arch = ~s~n", [OS_Arch]),

        % Log idle power consumption before benchmarking
        log_idle_power(BenchmarkModule),

        % Start power metrics collection
        start_power_metrics(BenchmarkModule),
        io:format("Execution - Iterations:~n"),
        RawExecTimes = [
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
        ExecTimes = sanitize(RawExecTimes, 0.20),
        BestTime = hd(ExecTimes),
        WorstTime = lists:last(ExecTimes),
        MedianTime = median(ExecTimes),
        ArithMean = arithmetic_mean(ExecTimes),
        GeoMean = geometric_mean(ExecTimes),
        HarmMean = harmonic_mean(ExecTimes),
        StdDev = standard_deviation(ExecTimes),
        ConfLow = confidence_low(ExecTimes),
        ConfHigh = confidence_high(ExecTimes),
        ErrorWindow = ConfHigh - ArithMean,
        ErrorPercent = 100 * ErrorWindow / ArithMean,
        CoeffVar = coefficient_of_variation(ExecTimes),
        Skew = skewness(ExecTimes),
        
        io:format("Execution - Summary: ~n"),
        io:format("   Total executions: ~p~n", [length(RawExecTimes)]),
        io:format("   Filtered executions: ~p~n", [length(ExecTimes)]),
        io:format("~s Best Time: ~.3f ms~n", [BenchmarkModule, BestTime]),
        io:format("~s Worst Time: ~.3f ms~n", [BenchmarkModule, WorstTime]),
        io:format("~s Median: ~.3f ms~n", [BenchmarkModule, MedianTime]),
        io:format("~s Arith. Mean Time: ~.3f ms~n", [BenchmarkModule, ArithMean]),
        io:format("~s Geo. Mean Time: ~.3f ms~n", [BenchmarkModule, GeoMean]),
        io:format("~s Harmonic Mean Time: ~.3f ms~n", [BenchmarkModule, HarmMean]),
        io:format("~s Std. Dev Time: ~.3f ms~n", [BenchmarkModule, StdDev]),
        io:format("~s Lower Confidence: ~.3f ms~n", [BenchmarkModule, ConfLow]),
        io:format("~s Higher Confidence: ~.3f ms~n", [BenchmarkModule, ConfHigh]),
        io:format("~s Error Window: ~.3f ms (~.3f percent)~n", [BenchmarkModule, ErrorWindow, ErrorPercent]),
        io:format("~s Coeff. of Variation: ~.3f~n", [BenchmarkModule, CoeffVar]),
        io:format("~s Skewness: ~.3f~n", [BenchmarkModule, Skew]).

log_idle_power(BenchmarkModule) ->
    IdleLogFile = generate_log_filename(atom_to_list(BenchmarkModule)++"_idle_power"),
    io:format("Idle sampling started, writing to ~p~n", [IdleLogFile]),
    PowerMetricsCmd = 
        "sudo powermetrics --samplers cpu_power,thermal,smc -n 5 -i 1000 -a 0 "
        "--hide-cpu-duty-cycle --show-extra-power-info | "
        "awk 'BEGIN {core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"; logfile=\"" ++ IdleLogFile ++ "\"; "
        "if (system(\"test -s \" logfile) != 0) print \"Timestamp,CPU Core Power(W),GT Power(W),DRAM Power(W),(CPUs+GT+SA) Power(W),Avg Num Cores Active,Cores Active(%),CPU Temp(C),Pressure Level\" > logfile} "
        "/\\*\\*\\* Sampled system activity/ {timestamp=$5 \" \" $6 \" \" $7 \" \" $8 \" \" $9 \" \" $10 \" \" $11 \" \" $12} "
        "/Intel energy model derived package power/ {cpu_gt_sa_power=$NF; gsub(/W/, \"\", cpu_gt_sa_power)} "
        "/Intel energy model derived CPU core power/ {core_power=$NF; gsub(/W/, \"\", core_power)} "
        "/Intel energy model derived GT power/ {gt_power=$NF; gsub(/W/, \"\", gt_power)} "
        "/Intel energy model derived DRAM power/ {dram_power=$NF; gsub(/W/, \"\", dram_power)} "
        "/Avg Num of Cores Active/ {avg_cores_active=$NF} "
        "/^(Cores Active:)/ {cores_active=$NF; gsub(/%/, \"\", cores_active)} "
        "/Current pressure level/ {pressure=$NF} "
        "/CPU die temperature/ {sub(/.*: /, \"\", $0); temp=$0; "
        "print timestamp \",\" core_power \",\" gt_power \",\" dram_power \",\" cpu_gt_sa_power \",\" avg_cores_active \",\" cores_active \",\" temp \",\" pressure >> logfile; "
        "core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"}'",
    os:cmd(PowerMetricsCmd),
    timer:sleep(6000),
    IdleLogFile.


start_power_metrics(BenchmarkModule) ->
    BenchmarkLogFile = generate_log_filename(atom_to_list(BenchmarkModule)++"_power_metrics"),
    io:format("Benchmark sampling started, writing to ~p~n~n", [BenchmarkLogFile]),
    PowerMetricsCmd = 
        "sudo powermetrics --samplers cpu_power,thermal,smc -i 100 -a 0 "
        "--hide-cpu-duty-cycle --show-extra-power-info | "
        "awk 'BEGIN {core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"; logfile=\"" ++ BenchmarkLogFile ++ "\"; "
        "if (system(\"test -s \" logfile) != 0) print \"Timestamp,CPU Core Power(W),GT Power(W),DRAM Power(W),(CPUs+GT+SA) Power(W),Avg Num Cores Active,Cores Active(%),CPU Temp(C),Pressure Level\" > logfile} "
        "/\\*\\*\\* Sampled system activity/ {timestamp=$5 \" \" $6 \" \" $7 \" \" $8 \" \" $9 \" \" $10 \" \" $11 \" \" $12} "
        "/Intel energy model derived package power/ {cpu_gt_sa_power=$NF; gsub(/W/, \"\", cpu_gt_sa_power)} "
        "/Intel energy model derived CPU core power/ {core_power=$NF; gsub(/W/, \"\", core_power)} "
        "/Intel energy model derived GT power/ {gt_power=$NF; gsub(/W/, \"\", gt_power)} "
        "/Intel energy model derived DRAM power/ {dram_power=$NF; gsub(/W/, \"\", dram_power)} "
        "/Avg Num of Cores Active/ {avg_cores_active=$NF} "
        "/^(Cores Active:)/ {cores_active=$NF; gsub(/%/, \"\", cores_active)} "
        "/Current pressure level/ {pressure=$NF} "
        "/CPU die temperature/ {sub(/.*: /, \"\", $0); temp=$0; "
        "print timestamp \",\" core_power \",\" gt_power \",\" dram_power \",\" cpu_gt_sa_power \",\" avg_cores_active \",\" cores_active \",\" temp \",\" pressure >> logfile; "
        "core_power=\"N/A\"; gt_power=\"N/A\"; dram_power=\"N/A\"; cpu_gt_sa_power=\"N/A\"; cores_active=\"N/A\"; avg_cores_active=\"N/A\"; temp=\"N/A\"; timestamp=\"N/A\"; pressure=\"N/A\"}' &",
                
    os:cmd(PowerMetricsCmd),
    % timer:sleep(2000),  
    BenchmarkLogFile.
    

stop_power_metrics() ->
    os:cmd("sudo pkill -2 powermetrics"),
    {_Date, Time} = calendar:universal_time(),
    FormattedTimestamp = io_lib:format("~p:~p:~p", tuple_to_list(Time)),
     io:format("~n"),
    io:format("PowerMetrics stopped at ~p.~n", [lists:flatten(FormattedTimestamp)]),
    io:format("~n").



generate_log_filename(BaseName) ->
    {{Year, Month, Day}, {Hour, Min, Sec}} = calendar:universal_time(),
    lists:flatten(io_lib:format("~s_~p_~p_~p_~p:~p:~p.csv", 
                [BaseName, Year, Month, Day, Hour, Min, Sec])).

%% Sanitize function (removes % outliers from both ends)
sanitize(RawList, Tolerance) when is_list(RawList), RawList =/= [] ->
    Sorted = lists:sort(RawList),
    RawListSize = length(Sorted),
    Median = lists:nth(RawListSize div 2 + 1, Sorted),
    AllowedMin = (1 - Tolerance) * Median,
    AllowedMax = (1 + Tolerance) * Median,
    [X || X <- Sorted, X >= AllowedMin, X =< AllowedMax];

sanitize([], _Tolerance) ->
    [].

arithmetic_mean(List) ->
    lists:sum(List) / length(List).

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

geometric_mean(List) when is_list(List), length(List) > 0 ->
    LogSum = lists:sum([math:log10(X) || X <- List]),
    math:pow(10, LogSum / length(List)).

harmonic_mean(List) ->
    length(List) / lists:sum([1 / X || X <- List]).

standard_deviation(List) ->
    Mean = arithmetic_mean(List),
    Variance = lists:sum([math:pow(X - Mean, 2) || X <- List]) / length(List),
    math:sqrt(Variance).

coefficient_of_variation(List) ->
    standard_deviation(List) / arithmetic_mean(List).

confidence_low(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    Mean - (1.96 * StdDev / math:sqrt(length(List))).

confidence_high(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    Mean + (1.96 * StdDev / math:sqrt(length(List))).

skewness(List) ->
    Mean = arithmetic_mean(List),
    StdDev = standard_deviation(List),
    N = length(List),
    if
        N > 1 -> lists:sum([math:pow(X - Mean, 3) || X <- List]) / ((N - 1) * math:pow(StdDev, 3));
        true -> 0.0
    end.
