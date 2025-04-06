-module(throughput_benchmark).
-export([run/0, worker/2, perform_computation/1, print_config/0]).

-define(N, 100_000). % Messages per actor
-define(A, 500).    % Number of actors

run() ->
    Main = self(),
    Actors = spawn_actors(?A, Main, []),
    send_messages(Actors, ?N),
    await_completion(?A).

await_completion(0) 
    -> ok;
await_completion(Remaining) ->
    receive
        done -> await_completion(Remaining - 1)
    end.

spawn_actors(0, _Parent, Acc) ->
    Acc;
spawn_actors(N, Parent, Acc) ->
    Pid = spawn(?MODULE, worker, [Parent, ?N]),
    spawn_actors(N - 1, Parent, [Pid | Acc]).
    
send_messages(_, 0) -> ok;
send_messages(Actors, N) ->
    send_all(Actors),
    send_messages(Actors, N - 1).

send_all([]) -> ok;
send_all([A | Rest]) ->
    A ! message,
    send_all(Rest).

worker(Parent, 0) ->
    Parent ! done,
    ok;
worker(Parent, MessagesLeft) ->
    receive
        message ->
            identity(37.2),  % replace with perform_computation(37.2) for CPU load
            worker(Parent, MessagesLeft - 1)
    end.

identity(Val) -> Val.

perform_computation(Theta) ->
    Sint = math:sin(Theta),
    Res = Sint * Sint,
    case Res =< 0 of
        true -> erlang:error("Benchmark exited with unrealistic res value");
        false -> ok
    end.

print_config() ->
    io:format("    N (messages per actor) = ~p~n", [?N]),
    io:format("    A (num actors) = ~p~n", [?A]).
