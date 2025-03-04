-module(fork_join_benchmark).
-export([run/0, worker/0, perform_computation/1, print_config/0]).
-define(N, 40_000).

run() ->
    Main = self(),
    Workers = [spawn_link(fun() -> worker() end) || _ <- lists:seq(1, ?N)],
    [Worker ! {start, Main} || Worker <- Workers],
    wait_for_workers(?N).

worker() ->
    receive
        {start, Main} ->
            perform_computation(37.2),
            Main ! done
    end.

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

