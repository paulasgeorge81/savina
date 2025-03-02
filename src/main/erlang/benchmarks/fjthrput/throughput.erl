-module(throughput).
-export([run/0, worker/2, perform_computation/1, print_config/0]).

-define(N, 10_000).   % Messages per actor
-define(A, 60).      % Number of actors

run() ->
    Self = self(),
    Actors = [spawn_link(fun() -> worker(Self, ?N) end) || _ <- lists:seq(1, ?A)],
    [[Actor ! message || _ <- lists:seq(1, ?N)] || Actor <- Actors],

    wait_for_actors(?A).

worker(Parent, 0) ->
    Parent ! done,
    ok;
worker(Parent, MessagesLeft) ->
    receive
        message ->
            perform_computation(37.2),
            worker(Parent, MessagesLeft - 1)
    end.

perform_computation(Theta) ->
    Sint = math:sin(Theta),
    Res = Sint * Sint,
    case Res =< 0 of
        true -> erlang:error("Benchmark exited with unrealistic res value");
        false -> ok
    end.

wait_for_actors(0) -> ok;
wait_for_actors(Remaining) ->
    receive
        done -> wait_for_actors(Remaining - 1)
    end.

print_config() ->
    io:format("    N (messages per actor) = ~p~n", [?N]),
    io:format("    A (num actors) = ~p~n", [?A]).
