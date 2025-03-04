-module(thread_ring_benchmark).
-export([run/0, actor/3, print_config/0]).
-define(N, 100). % number of actors
-define(R, 100_000). % number of pings/no of rounds

run() -> 
    Main = self(),
    Pids = [spawn(?MODULE, actor, [self(), undefined, Main]) || _ <- lists:seq(1, ?N)],
    setup_ring(Pids),
    hd(Pids) ! {ping, ?R},
    receive
      done ->
        ok
    end.

setup_ring([H | T]) ->
    setup_ring(H, T ++ [H]).

setup_ring(_, []) ->
    ok;
setup_ring(Current, [Next | Rest]) ->
    Current ! {set_next, Next},
    setup_ring(Next, Rest).

actor(Self, Next, Main) ->
    receive
        {set_next, NewNext} ->
            actor(Self, NewNext, Main);
        {ping, PingsLeft} when PingsLeft > 0 ->
            Next ! {ping, PingsLeft - 1},
            actor(Self, Next, Main);
        {ping, 0} ->
            Next ! {exit, Self},  %% Send exit message with the first actor's PID
            actor(Self, Next, Main);
        {exit, Original} when Self =:= Original -> %% Terminate when exit message loops back
            Main ! done;
        {exit, Original} ->
            Next ! {exit, Original},
            ok
    end.
    

print_config() ->
    io:format("    N (num actors) = ~p~n",[?N]),
    io:format("    R (num rounds) = ~p~n",[?R]).
