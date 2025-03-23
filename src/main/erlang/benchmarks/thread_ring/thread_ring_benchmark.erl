-module(thread_ring_benchmark).
-export([run/0, actor/2, print_config/0]).
-define(N, 10_000). % number of actors
-define(R, 1_000_000). % number of pings/no of rounds

run() -> 
    Main = self(),
    Pids = [spawn(?MODULE, actor, [undefined, Main]) || _ <- lists:seq(1, ?N)],
    setup_ring(Pids),
    hd(Pids) ! {ping, ?R},
    receive
      done ->
        ok
    end.

setup_ring([H | T]) ->
    Last = lists:foldl(fun (Next, Prev) -> Prev ! {set_next, Next}, Next end, H, T),
    Last ! {set_next, H}.  % Completing the ring by linking the last actor to the first

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
    io:format("    N (num actors) = ~p~n",[?N]),
    io:format("    R (num rounds) = ~p~n",[?R]).
