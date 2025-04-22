-module(fork_join_benchmark).
-export([run/0, worker/0, perform_computation/1, print_config/0]).
-define(N, 40_000_000).

run() ->
    Main = self(),
    % Workers = [spawn(?MODULE, worker, []) || _ <- lists:seq(1, ?N)],
    Workers = spawn_workers(?N),
    % [Worker ! {start, Main} || Worker <- Workers],
    send_start_messages(Workers, Main),

    wait_for_workers(?N).

spawn_workers(N) ->
    spawn_workers(N, []).

spawn_workers(0, Acc) ->
    Acc;
    % lists:reverse(Acc);
spawn_workers(N, Acc) ->
    Pid = spawn(?MODULE, worker, []),
    spawn_workers(N - 1, [Pid | Acc]).

send_start_messages([], _Main) ->
    ok;
send_start_messages([Pid | Rest], Main) ->
    Pid ! {start, Main},
    send_start_messages(Rest, Main).

worker() ->
    receive
        {start, Main} ->
            identity(37.2),
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

identity(Val)->
    Val.


print_config() ->
    io:format("    N (num workers) = ~p~n", [?N]).

