-module(prod_cons_bounded_buffer).
-export([run/0, manager/7, producer/2, consumer/1, process_item/2,print_config/0]).

-define(BUFFER_SIZE, 50).
-define(NUM_PRODUCERS, 40).
-define(NUM_CONSUMERS, 40).
-define(NUM_ITEMS_PER_PRODUCER, 1000).
-define(PROD_COST, 25).
-define(CONS_COST, 25).

run() ->
    Parent = self(),
    AdjustedBufferSize = ?BUFFER_SIZE - ?NUM_PRODUCERS,
    ManagerPid = spawn(?MODULE, manager, [Parent, [], [], 0, ?NUM_PRODUCERS, [], AdjustedBufferSize]),

    % Spawn consumers
    [spawn(?MODULE, consumer, [ManagerPid]) || _ <- lists:seq(1, ?NUM_CONSUMERS)],

    % Spawn producers
    [spawn(?MODULE, producer, [ManagerPid, ?NUM_ITEMS_PER_PRODUCER]) || _ <- lists:seq(1, ?NUM_PRODUCERS)],

    % Wait for termination message
    receive 
        done -> io:format("Benchmark completed.~n") 
    end.

manager(Parent, AvailableProducers, AvailableConsumers, NumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize) ->
    receive
        {data, Data, ProducerPid} ->
            case AvailableConsumers of
                [] -> 
                    NewPendingData = [{Data, ProducerPid} | PendingData],
                    if 
                        length(NewPendingData) >= AdjustedBufferSize ->
                            manager(Parent, [ProducerPid | AvailableProducers], AvailableConsumers, NumTerminatedProducers, NumProducers, NewPendingData, AdjustedBufferSize);
                        true -> 
                            ProducerPid ! produce,
                            manager(Parent, AvailableProducers, AvailableConsumers, NumTerminatedProducers, NumProducers, NewPendingData, AdjustedBufferSize)
                    end;
                
                [ConsumerPid | RestConsumers] ->
                    ConsumerPid ! {consume, Data},
                    if length(PendingData) >= AdjustedBufferSize ->
                        manager(Parent, [ProducerPid | AvailableProducers], RestConsumers, NumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize);
                    true ->
                        ProducerPid ! produce,
                        manager(Parent, AvailableProducers, RestConsumers, NumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize)
                    end
            end;

    
        {consumer_available, ConsumerPid} ->
            case PendingData of
                [] -> 
                    % Consumer waits if no data is available
                    % NewAvailableConsumers = [ConsumerPid | AvailableConsumers],
                    % if 
                    %     NumTerminatedProducers == NumProducers andalso length(NewAvailableConsumers) == ?NUM_CONSUMERS ->
                    %         [Pid ! stop || Pid <- AvailableConsumers],
                    %         Parent ! done,
                    %         exit(normal);
                    %     true -> 
                    %         manager(Parent, AvailableProducers, [ConsumerPid | AvailableConsumers], NumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize)
                    % end;
                    % Consumer waits if no data is available
                    NewAvailableConsumers = [ConsumerPid | AvailableConsumers],
                    try_exit(Parent, AvailableProducers, NewAvailableConsumers, NumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize);


                [{Data, _ProducerPid} | RestPendingData] ->
                    ConsumerPid ! {consume, Data},
                    case AvailableProducers of
                        [P | RestProducers] ->
                            P ! produce,
                            manager(Parent, RestProducers, AvailableConsumers, NumTerminatedProducers, NumProducers, RestPendingData, AdjustedBufferSize);
                        [] ->
                            manager(Parent, AvailableProducers, AvailableConsumers, NumTerminatedProducers, NumProducers, RestPendingData, AdjustedBufferSize)
                    end
                    
            end;

        {producer_exit, _ProducerId} ->
            NewNumTerminatedProducers = NumTerminatedProducers + 1,
            try_exit(Parent, AvailableProducers, AvailableConsumers, NewNumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize)

            % NewNumTerminatedProducers = NumTerminatedProducers + 1,
            % if 
            %     NewNumTerminatedProducers == NumProducers andalso length(AvailableConsumers) == ?NUM_CONSUMERS ->
            %         [Pid ! stop || Pid <- AvailableConsumers],
            %         Parent ! done,
            %         exit(normal);
            %     true -> 
            %         manager(Parent, AvailableProducers, AvailableConsumers, NewNumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize)
            % end

    end.

try_exit(Parent, AvailableProducers, AvailableConsumers, NumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize) ->
        if 
            NumTerminatedProducers == NumProducers andalso length(AvailableConsumers) == ?NUM_CONSUMERS ->
                [Pid ! stop || Pid <- AvailableConsumers],
                Parent ! done,
                exit(normal);
            true ->
                manager(Parent, AvailableProducers, AvailableConsumers, NumTerminatedProducers, NumProducers, PendingData, AdjustedBufferSize)
        end.

producer(ManagerPid, 0) ->
    ManagerPid ! {producer_exit, self()};
producer(ManagerPid, RemainingItems) ->
    Data = process_item(0.0, ?PROD_COST),
    ManagerPid ! {data, Data, self()},
    receive 
        produce -> 
            producer(ManagerPid, RemainingItems - 1) 
    end.


consumer(ManagerPid) ->
    ManagerPid ! {consumer_available, self()},
    receive
        {consume, Data} -> 
            process_item(Data, ?CONS_COST),
            consumer(ManagerPid);
        stop -> 
            exit(normal)
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