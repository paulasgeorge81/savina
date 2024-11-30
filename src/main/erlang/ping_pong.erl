-module(ping_pong).
-export([run/1, ping/3, pong/0, start_benchmark/0]).

start_benchmark() ->
    % {Time, _Result} = timer:tc(?MODULE, run, [10000]),
    % io:format("Benchmark completed in ~p microseconds.~n", [Time]).

    Times = [ timer:tc(?MODULE, run, [10000]) || _ <- lists:seq(1, 5) ],
        AvgTime = lists:sum([Time || {Time, _} <- Times]) div length(Times),
        io:format("Average Benchmark time: ~p microseconds.~n", [AvgTime]).

run(NumMessages) ->
    PongPid = spawn(?MODULE, pong, []),
    PingPid = spawn(?MODULE, ping, [NumMessages, PongPid, self()]),
    PingPid ! {start_ping},
    receive
        done -> ok
            % io:format("Benchmark completed~n")
    end.


ping(0, PongPid, MainPid) ->
    % io:format("Ping process finished.~n"),
    PongPid ! {stop},
    MainPid ! done;  
ping(N, PongPid, MainPid) ->
    receive
        {start_ping} ->
            % io:format("Ping received start_ping.~n"),
            PongPid ! {ping, self()},
            ping(N, PongPid, MainPid);
        {pong} ->
            % io:format("Ping received pong ~p~n", [N]),
            PongPid ! {ping, self()},
            ping(N - 1, PongPid, MainPid)
    end.

pong() ->
    receive
        {ping, PingPid} ->
            % io:format("Pong received ping~n"),
            PingPid ! {pong},
            pong();
        {stop} -> ok
            % io:format("Pong process finished.~n")
    end.

