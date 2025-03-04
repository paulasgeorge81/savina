-module(thread_ring).
-export([start/2, loop/2,run/0, print_config/0]).
-define(N, 100000). % number of actors
-define(R, 100_000). % number of pings/no of rounds

run() ->
    register(main, self()),
    start(?N, ?R),
    receive
      done ->
        ok
    end.
start(N, R) -> 
    Pids = [spawn(?MODULE, loop, [self(), undefined]) || _ <- lists:seq(1, N)],
    setup_ring(Pids),
    hd(Pids) ! {ping, R}.

setup_ring([H | T]) ->
    setup_ring(H, T ++ [H]).

setup_ring(_, []) ->
    ok;
setup_ring(Current, [Next | Rest]) ->
    Current ! {set_next, Next},
    setup_ring(Next, Rest).

loop(Self, Next) ->
    receive
        {set_next, NewNext} ->
            loop(Self, NewNext);
        {ping, PingsLeft} when PingsLeft > 0 ->
            Next ! {ping, PingsLeft - 1},
            loop(Self, Next);
        {ping, 0} ->
            Next ! {exit, Self},  %% Send exit message with the first actor's PID
            loop(Self, Next);
        {exit, Original} when Self =:= Original -> %% Terminate when exit message loops back
            main ! done;
        {exit, Original} ->
            Next ! {exit, Original},
            ok
    end.
    

print_config() ->
    io:format("    N (num actors) = ~p~n",[?N]),
    io:format("    R (num rounds) = ~p~n",[?R]).
