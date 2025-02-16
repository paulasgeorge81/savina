-module(prod_cons_bounded_buffer).
-export([run/0, manager/6, producer/2, consumer/1, process_item/2,print_config/0]).

-define(BUFFER_SIZE, 50).
-define(NUM_PRODUCERS, 40).
-define(NUM_CONSUMERS, 40).
-define(NUM_ITEMS_PER_PRODUCER, 1000).
-define(PROD_COST, 25).
-define(CONS_COST, 25).

run() ->
    ManagerPid = spawn(?MODULE, manager, [self(), [], [], 0, ?NUM_PRODUCERS, []]),
    % Spawn producers
    [spawn(?MODULE, producer, [ManagerPid, ?NUM_ITEMS_PER_PRODUCER]) || _ <- lists:seq(1, ?NUM_PRODUCERS)],


    % Spawn consumers
    [spawn(?MODULE, consumer, [ManagerPid]) || _ <- lists:seq(1, ?NUM_CONSUMERS)],

    % Wait for termination message
    receive done -> io:format("Benchmark completed.~n") end.

manager(Parent, Producers, Consumers, TerminatedProducers, TotalProducers, Buffer) ->
    receive
        {produce, ProducerPid, Item} ->
            if length(Buffer) >= ?BUFFER_SIZE ->  % Buffer full, store producer
                   manager(Parent, [ProducerPid | Producers], Consumers, TerminatedProducers, TotalProducers, Buffer);
               true ->
                   case Consumers of
                       [] -> manager(Parent, Producers, Consumers, TerminatedProducers, TotalProducers, [{ProducerPid, Item} | Buffer]);
                       [ConsumerPid | RestConsumers] ->
                           ConsumerPid ! {consume, Item},
                           ProducerPid ! produce_more,
                           manager(Parent, Producers, RestConsumers, TerminatedProducers, TotalProducers, Buffer)
                   end
            end;
        
        {consume_ready, ConsumerPid} ->
            case Buffer of
                [] -> manager(Parent, Producers, [ConsumerPid | Consumers], TerminatedProducers, TotalProducers, Buffer);
                [{ProducerPid, Item} | RestBuffer] ->
                    ConsumerPid ! {consume, Item},
                    ProducerPid ! produce_more,
                    manager(Parent, Producers, Consumers, TerminatedProducers, TotalProducers, RestBuffer)
            end;

        {producer_done, _ProducerPid} ->
            NewTerminatedProducers = TerminatedProducers + 1,
            if NewTerminatedProducers == TotalProducers, length(Consumers) == ?NUM_CONSUMERS ->
                   Parent ! done,
                   io:format("All producers and consumers are done. Exiting manager.~n");
               true -> manager(Parent, Producers, Consumers, NewTerminatedProducers, TotalProducers, Buffer)
            end
    end.

producer(ManagerPid, 0) ->
    ManagerPid ! {producer_done, self()};
producer(ManagerPid, RemainingItems) ->
    Data = process_item(0.0, ?PROD_COST),
    ManagerPid ! {produce, self(), Data},
    receive 
        produce_more -> 
            producer(ManagerPid, RemainingItems - 1) 
    end.

consumer(ManagerPid) ->
    ManagerPid ! {consume_ready, self()},
    receive
        {consume, Item} ->
            process_item(Item, ?CONS_COST),
            consumer(ManagerPid);
        stop -> ok
    end.

process_item(CurTerm, Cost) ->
    RandState = pseudo_random:new(Cost),
    outer_loop(CurTerm, Cost, RandState, 0).

outer_loop(_, 0, RandState, Res) ->
    {RandVal, _} = pseudo_random:next_double(RandState),
    Res + math:log(abs(RandVal) + 0.01);

outer_loop(CurTerm, Cost, RandState, Res) when Cost > 0 ->
    outer_loop(CurTerm, Cost - 1, RandState, inner_loop(Res, 100, RandState)).

inner_loop(Res, 0, _RandState) ->
    Res;

inner_loop(Res, Count, RandState) when Count > 0 ->
    {RandVal, NewRandState} = pseudo_random:next_double(RandState),
    inner_loop(Res + math:log(abs(RandVal) + 0.01), Count - 1, NewRandState).

 

print_config() ->
    io:format("    Buffer size = ~p~n",[?BUFFER_SIZE]),
    io:format("    num producers = ~p~n",[?NUM_PRODUCERS]),
    io:format("    num consumers = ~p~n",[?NUM_CONSUMERS]),
    io:format("    prod cost = ~p~n",[?PROD_COST]),
    io:format("    cons cost = ~p~n",[?CONS_COST]),
    io:format("    items per producer = ~p~n",[?NUM_ITEMS_PER_PRODUCER]).