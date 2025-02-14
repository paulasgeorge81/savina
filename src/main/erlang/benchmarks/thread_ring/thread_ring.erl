-module(thread_ring).
-export([start/2, actor_loop/2,run/0, print_config/0]).
-define(N, 100). % number of actors
-define(R, 100_000). % number of pings

run() ->
    start(?N, ?R).
start(N, R) -> 
    Self = self(),
    Pids = lists:map(fun(_) -> spawn(?MODULE, actor_loop, [Self, undefined]) end, lists:seq(1, N)),
    setup_ring(Pids),
    hd(Pids) ! {ping, R}.

setup_ring([H | T]) ->
    setup_ring(H, T ++ [H]).

setup_ring(_, []) ->
    ok;
setup_ring(Prev, [H | T]) ->
    Prev ! {set_next, H},
    setup_ring(H, T).

actor_loop(Parent, Next) ->
    receive
        {set_next, NewNext} ->
            actor_loop(Parent, NewNext);
        {ping, PingsLeft} when PingsLeft > 0 ->
            Next ! {ping, PingsLeft - 1},
            actor_loop(Parent, Next);
        {ping, 0} ->
            Next ! {exit, Parent},
            actor_loop(Parent, Next);
        {exit, Original} when Next =:= Original ->
            exit(normal);
        {exit, Original} ->
            Next ! {exit, Original},
            exit(normal)
    end.

print_config() ->
    io:format("    N (num actors) = ~p~n",[?N]),
    io:format("    R (num rounds) = ~p~n",[?R]).
