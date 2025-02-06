-module(benchmark_runner).
-export([run/1]).

run(ExecTimes) ->
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
    io:format("Total executions: ~p~n", [length(RawExecTimes)]),
    io:format("Filtered executions: ~p~n", [length(FilteredExecTimes)]),
    io:format("~s Best Time: ~p~n", [?MODULE, BestTime]),
    io:format("~s Worst Time: ~p~n", [?MODULE, WorstTime]),
    io:format("~s Median: ~p~n", [?MODULE, MedianTime]),
    io:format("~s Arith. Mean Time: ~p~n", [?MODULE, ArithMean]),
    io:format("~s Geo. Mean Time: ~p~n", [?MODULE, GeoMean]),
    io:format("~s Harmonic Mean Time: ~p~n", [?MODULE, HarmMean]),
    io:format("~s Std. Dev Time: ~p~n", [?MODULE, StdDev]),
    io:format("~s Lower Confidence: ~p~n", [?MODULE, ConfLow]),
    io:format("~s Higher Confidence: ~p~n", [?MODULE, ConfHigh]),
    io:format("~s Error Window: ~p (~4.3f percent)~n", [?MODULE, ErrorWindow, ErrorPercent]),
    io:format("~s Coeff. of Variation: ~p~n", [?MODULE, CoeffVar]),
    io:format("~s Skewness: ~p~n", [?MODULE, Skew]).

 


