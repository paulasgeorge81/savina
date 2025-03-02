-module(fork_join).
-export([run/0, worker/1, perform_computation/1, print_config/0]).
-define(N, 40000).

run() ->
    Main = self(),
    [spawn_link(fun() -> worker(Main) end) || _ <- lists:seq(1, ?N)],
    wait_for_workers(?N).

worker(Main) ->
    perform_computation(37.2),
    Main ! done.

wait_for_workers(0) -> ok;
wait_for_workers(N) ->
    receive
        done -> wait_for_workers(N - 1)
    end.

perform_computation(Theta) ->
    Sint = math:sin(Theta),
    Res = Sint * Sint,
    case Res =< 0 of
        true -> erlang:error("Benchmark exited with unrealistic res value");
        false -> ok
    end.

print_config() ->
    io:format("    N (num workers) = ~p~n", [?N]).

