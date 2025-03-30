-module(counting_benchmark).
-export([run/0, producer/2, counter/1, print_config/0]).

-define(N, 500_000_000).  % Number of messages to send

run() ->
    Self = self(),
    CounterPid = spawn(?MODULE, counter, [0]),
    ProducerPid = spawn(?MODULE, producer, [CounterPid, Self]),
    ProducerPid ! start,
    receive
        done ->
          ok 
    end.

producer(CounterPid, MainPid) ->
    receive
        start ->
            send_messages(CounterPid, ?N),
            CounterPid ! {retrieve, self()},
            producer(CounterPid, MainPid);
        {result, Count} ->
            if Count =:= ?N ->
                io:format("SUCCESS! received: ~p~n", [Count]);
               true ->
                io:format("ERROR: expected: ~p, found: ~p~n", [?N, Count])
            end,
            MainPid ! done
    end.

send_messages(_, 0) ->
     ok;
send_messages(CounterPid, N) ->
    CounterPid ! increment,
    send_messages(CounterPid, N - 1).

counter(Count) ->
    receive
        increment ->
            counter(Count + 1);
        {retrieve, ProducerPid} ->
            ProducerPid ! {result, Count}
    end.

print_config() ->
    io:format("    N (num messages) = ~p~n",[?N]).
