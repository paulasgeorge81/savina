-module(ping_pong).
-export([start_benchmark/1, run/1, ping/3, pong/0]).

% Entry point for the benchmark
start_benchmark(NumIterations) ->
     % Start power metrics collection before the benchmark
     PowerMetricsPid = start_power_metrics(),

     % run the benchmark
    Times = [measure_time(fun() -> run(10000) end) || _ <- lists:seq(1, NumIterations)],
    BestTime = lists:min(Times),
    WorstTime = lists:max(Times),
    AvgTime = lists:sum(Times) div NumIterations,
    
    io:format("Benchmark Results (~p iterations):~n", [NumIterations]),
    io:format("  Best Time: ~p microseconds~n", [BestTime]),
    io:format("  Worst Time: ~p microseconds~n", [WorstTime]),
    io:format("  Average Time: ~p microseconds~n", [AvgTime]),
    
     % Stop power metrics collection after the benchmark
     stop_power_metrics(PowerMetricsPid).

% Measure execution time of a function
measure_time(Fun) ->
    {Time, _Result} = timer:tc(Fun),
    Time.

% Start the ping-pong message passing
run(NumMessages) ->
    PongPid = spawn(?MODULE, pong, []),
    PingPid = spawn(?MODULE, ping, [NumMessages, PongPid, self()]),
    PingPid ! start_ping,
    receive
        done -> ok
    end.

% Ping process
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

% Pong process
pong() ->
    receive
        {ping, PingPid} ->
            PingPid ! pong,
            pong();
        stop -> ok
    end.


% Start powermetrics process to log power consumption
start_power_metrics() ->
    % PowerMetricsCmd = "sudo /usr/bin/powermetrics --show-all -i 1000 -n 10",
    PowerMetricsCmd = "sudo /usr/bin/powermetrics -i 1000 -s all -a 10 -n 5",
    
    % {ok, LogFile} = file:open("power_metrics.log", [write, raw]),
    {Pid, _Ref} = spawn_monitor(fun() -> run_power_metrics(PowerMetricsCmd) end),
    Pid.

% Run the powermetrics command and log the output
run_power_metrics(Cmd) ->
    {ok, LogFile} = file:open("power_metrics.log", [write, raw]),
    process_flag(trap_exit, true),
    Port = open_port({spawn, Cmd}, [stream, exit_status]),
    collect_output(Port, LogFile).

% Collect output from powermetrics and write to the log file
collect_output(Port, LogFile) ->
    receive
        {Port, {data, Data}} ->
            % io:format("Data ~p", [Data]),
            % io:format(LogFile, "~p", [Data]),
            
            file:write(LogFile, Data),
            % file:close(LogFile),
            collect_output(Port, LogFile);
        {Port, {exit_status, _Status}} ->
            % io:format(LogFile, "Process exited with status: ~p~n", [Status]),
            file:close(LogFile)
    end.


% Stop the powermetrics process
stop_power_metrics(Pid) ->
    exit(Pid, normal).