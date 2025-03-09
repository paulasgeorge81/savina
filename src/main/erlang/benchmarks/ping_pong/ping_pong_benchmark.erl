-module(ping_pong_benchmark).
-export([run/0, ping/3, pong/0,print_config/0]).
-define(NUMMSG, 1_000_000).

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

print_config() ->
    io:format("    N (num pings) = ~p~n",[?NUMMSG]).
