-module(simple_benchmark).
-export([run/0]).

% run() ->
%     %% Here you can call the powermetrics command similar to Java
%     %% and perform computations for benchmarking
%     {ok, Result} = os:cmd("sudo /usr/bin/powermetrics -i 1000 -s all -a 10 -n 5"),
%     io:format("Power metrics output:~n~s", [Result]),
%     %% Example computation
%     Sum = lists:sum(lists:seq(1, 1000000000)),
%     io:format("The sum is: ~p~n", [Sum]).



run() ->
    % Start the Savina benchmark
    savina:start_benchmark(),

    % Your benchmarking code goes here
    Result = perform_computation(),

    % End the Savina benchmark
    Duration = savina:end_benchmark(),

    % Log the results
    savina:log_results(Result, Duration).

perform_computation() ->
    % Example computation
    lists:sum(lists:seq(1, 1000000)).
