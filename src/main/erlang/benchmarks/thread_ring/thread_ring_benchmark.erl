-module(thread_ring_benchmark).
-export([run/0, actor/2, print_config/0]).
-define(N, 50_000).    % Number of actors
-define(R, 1_000_000_000). % Number of rounds

run() -> 
    Main = self(),
    {FirstPid, LastPid} = spawn_ring(?N, Main),
    LastPid ! {set_next, FirstPid},  % Completing the ring by linking the last actor to the first
    FirstPid ! {ping, ?R},
    receive
        done -> ok
    end.

spawn_ring(N, Main) ->
    spawn_ring(N, Main, undefined, undefined).

spawn_ring(1, Main, undefined, undefined) ->
    %% Only one actor in the ring
    Pid = spawn(?MODULE, actor, [undefined, Main]),
    {Pid, Pid};

spawn_ring(1, Main, Prev, First) ->
    %% Last actor
    Pid = spawn(?MODULE, actor, [undefined, Main]),
    Prev ! {set_next, Pid},
    {First, Pid};

spawn_ring(N, Main, undefined, undefined) ->
    %% First actor (initialize accumulator)
    FirstPid = spawn(?MODULE, actor, [undefined, Main]),
    spawn_ring(N - 1, Main, FirstPid, FirstPid);

spawn_ring(N, Main, Prev, First) ->
    %% General case
    Pid = spawn(?MODULE, actor, [undefined, Main]),
    Prev ! {set_next, Pid},
    spawn_ring(N - 1, Main, Pid, First).

actor(Next, Main) ->
    receive
        {set_next, NewNext} ->
            actor(NewNext, Main);
        {ping, PingsLeft} when PingsLeft > 0 ->
            Next ! {ping, PingsLeft - 1},
            actor(Next, Main);
        {ping, 0} ->
            Next ! {exit, self()},  %% Send exit message with the first actor's PID
            actor(Next, Main);
        {exit, Original} when self() =:= Original -> %% Terminate when exit message loops back
            Main ! done;
        {exit, Original} ->
            Next ! {exit, Original},
            ok
    end.

print_config() ->
    io:format("    N (num actors) = ~p~n", [?N]),
    io:format("    R (num rounds) = ~p~n", [?R]). 

