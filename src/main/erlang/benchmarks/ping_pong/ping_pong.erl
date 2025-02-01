-module(ping_pong).
-export([run/0, ping/3, pong/0, start_benchmark/0]).
-define(NUMMSG, 10).
-define(NUMITER, 1000).

run() ->
    PongPid = spawn(?MODULE, pong, []),
    PingPid = spawn(?MODULE, ping, [?NUMMSG, PongPid, self()]),
    PingPid ! start_ping,
    receive
        done -> ok
    end.

ping(0, PongPid, MainPid) ->
    PongPid ! stop,
    MainPid ! done;
ping(N, PongPid, MainPid) ->
    receive
        start_ping ->
            PongPid ! {ping, self()},
            ping(N, PongPid, MainPid);
        pong ->
            PongPid ! {ping, self()},
            ping(N - 1, PongPid, MainPid)
    end.

pong() ->
    receive
        {ping, PingPid} ->
            PingPid ! pong,
            pong();
        stop -> ok
    end.
start_benchmark() ->
    benchmark_runner:run(?MODULE, ?NUMITER).

% -module(ping_pong).
% -export([start_benchmark/1, run/1, ping/3, pong/0]).

% % Power metrics functions
% -export([start_power_metrics/0, trigger_power_sample/1, flush_power_data/1, stop_power_metrics/1]).
% -define(N, 40000).
% % Entry point for the benchmark
% start_benchmark(NumIterations) ->
%     % Start power metrics collection
%     PowerMetricsPid = start_power_metrics(),

%     % Open log file for writing power metrics
%     {ok, LogFile} = file:open("power_metrics.log", [write, raw]),

%     % Run the benchmark while triggering power samples
%     Times = [measure_time(fun() -> 
%         trigger_power_sample(PowerMetricsPid), % Take a power sample
%         run(10000),
%         flush_power_data(PowerMetricsPid) % Flush power data
%     end) || _ <- lists:seq(1, NumIterations)],

%     % Stop power metrics collection
%     stop_power_metrics(PowerMetricsPid),

%     % Close the log file
%     file:close(LogFile),

%     % Compute benchmark statistics
%     BestTime = lists:min(Times),
%     WorstTime = lists:max(Times),
%     AvgTime = lists:sum(Times) div NumIterations,
     
%     io:format("Benchmark Results (~p iterations):~n", [NumIterations]),
%     io:format("  Best Time: ~p microseconds~n", [BestTime]),
%     io:format("  Worst Time: ~p microseconds~n", [WorstTime]),
%     io:format("  Average Time: ~p microseconds~n", [AvgTime]).

% % Measure execution time of a function
% measure_time(Fun) ->
%     {Time, _Result} = timer:tc(Fun),
%     Time.

% % Start the ping-pong message passing
% run(NumMessages) ->
%     PongPid = spawn(?MODULE, pong, []),
%     PingPid = spawn(?MODULE, ping, [NumMessages, PongPid, self()]),
%     PingPid ! start_ping,
%     receive
%         done -> ok
%     end.

% % Ping process
% ping(0, PongPid, MainPid) ->
%     PongPid ! stop,
%     MainPid ! done;
% ping(N, PongPid, MainPid) ->
%     receive
%         start_ping ->
%             PongPid ! {ping, self()},
%             ping(N, PongPid, MainPid);
%         pong ->
%             PongPid ! {ping, self()},
%             ping(N - 1, PongPid, MainPid)
%     end.

% % Pong process
% pong() ->
%     receive
%         {ping, PingPid} ->
%             PingPid ! pong,
%             pong();
%         stop -> ok
%     end.

% %%%%%%%%%%%%%%%%%%%%% POWER METRICS FUNCTIONS %%%%%%%%%%%%%%%%%%%%%

% % Start powermetrics process and capture PID
% start_power_metrics() ->
%     PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 1 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info > power_metrics.log 2>&1 & echo $!",
%     PidStr = string:trim(os:cmd(PowerMetricsCmd)),  % Trim newline
%     Pid = list_to_integer(PidStr), % Convert to integer
%     io:format("PowerMetrics started with PID: ~p~n", [Pid]),
%     Pid.

% % Trigger an immediate power sample
% trigger_power_sample(Pid) ->
%     os:cmd("sudo kill -29 " ++ integer_to_list(Pid)).

% % Flush power data
% flush_power_data(Pid) ->
%     os:cmd("sudo kill -23 " ++ integer_to_list(Pid)).

% % Stop powermetrics
% stop_power_metrics(Pid) ->
%     os:cmd("sudo kill -2 " ++ integer_to_list(Pid)),
%     io:format("PowerMetrics stopped.~n").
