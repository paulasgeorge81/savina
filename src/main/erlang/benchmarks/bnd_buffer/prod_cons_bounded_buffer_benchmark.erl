-module(prod_cons_bounded_buffer_benchmark).
-export([run/0, manager/9, producer/1, consumer/0,print_config/0]).

-define(BUFFER_SIZE, 1_200_000).
-define(NUM_PRODUCERS,1_000_000).
-define(NUM_CONSUMERS, 1_000_000).
-define(NUM_ITEMS_PER_PRODUCER, 1_000).
-define(PROD_COST, 25).
-define(CONS_COST, 25).

run() ->
    Parent = self(),
    AdjustedBufferSize = ?BUFFER_SIZE - ?NUM_PRODUCERS,

    % Spawn consumers
    AvailableConsumers = spawn_consumers(?NUM_CONSUMERS, queue:new()),
    
    %spawn and register a manager
    register(manager, spawn(?MODULE, manager, [Parent, queue:new(), AvailableConsumers, ?NUM_CONSUMERS, 0, ?NUM_PRODUCERS, queue:new(), 0, AdjustedBufferSize])),


    % Spawn producers
    % ProducerPids = [spawn(?MODULE, producer, [?NUM_ITEMS_PER_PRODUCER]) || _ <- lists:seq(1, ?NUM_PRODUCERS)],
    ProducerPids = spawn_producers(?NUM_PRODUCERS, []),
    
    % Send initial production messages
    % [Pid ! produce || Pid <- ProducerPids],
    send_produce_messages(ProducerPids, manager),

    % Wait for termination message
    receive 
        done ->
            ok
    end.

send_produce_messages([], _) -> ok;
send_produce_messages([Pid | Rest], ManagerPid) ->
    Pid ! produce,
    send_produce_messages(Rest, ManagerPid).


spawn_consumers(0, Queue) ->
    Queue;  
spawn_consumers(N, Queue) when N > 0 ->
    ConsumerPid = spawn(?MODULE, consumer, []),
    spawn_consumers(N - 1, queue:in(ConsumerPid, Queue)).

spawn_producers(N, Acc) when N > 0 ->
    Pid = spawn(?MODULE, producer, [?NUM_ITEMS_PER_PRODUCER]),
    spawn_producers(N - 1, [Pid | Acc]);

spawn_producers(0, Acc) ->
    lists:reverse(Acc).
    

manager(Parent, AvailableProducers, AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers, NumProducers, PendingData, PendingDataSize, AdjustedBufferSize) ->
    receive
        {data, Data, ProducerPid} ->
            case queue:out(AvailableConsumers) of
                {empty, _} ->
                    NewPendingData = queue:in({Data, ProducerPid}, PendingData),
                    NewPendingDataSize = PendingDataSize + 1,
                    case NewPendingDataSize >= AdjustedBufferSize of
                        true ->
                            manager(Parent, queue:in(ProducerPid, AvailableProducers), AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers, NumProducers, NewPendingData, NewPendingDataSize, AdjustedBufferSize);
                        false ->
                            ProducerPid ! produce,
                            manager(Parent, AvailableProducers, AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers, NumProducers, NewPendingData, NewPendingDataSize, AdjustedBufferSize)
                    end;

                {{value, ConsumerPid}, RestConsumers} ->
                    ConsumerPid ! {consume, Data},
                    NewAvailableConsumersSize = AvailableConsumersSize - 1,
                    case PendingDataSize >= AdjustedBufferSize of
                        true ->
                            manager(Parent, queue:in(ProducerPid, AvailableProducers), RestConsumers, NewAvailableConsumersSize, NumTerminatedProducers, NumProducers, PendingData, PendingDataSize, AdjustedBufferSize);
                        false ->
                            ProducerPid ! produce,
                            manager(Parent, AvailableProducers, RestConsumers, NewAvailableConsumersSize, NumTerminatedProducers, NumProducers, PendingData, PendingDataSize, AdjustedBufferSize)
                    end
            end;

        {consumer_available, ConsumerPid} ->
            case queue:out(PendingData) of
                {empty, _} ->
                    try_exit(Parent, AvailableProducers, queue:in(ConsumerPid, AvailableConsumers), AvailableConsumersSize + 1, NumTerminatedProducers, NumProducers, PendingData, PendingDataSize, AdjustedBufferSize);

                {{value, {Data, _ProducerPid}}, RestPendingData} ->
                    ConsumerPid ! {consume, Data},
                    case queue:out(AvailableProducers) of
                        {empty, _} ->
                            manager(Parent, AvailableProducers, AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers, NumProducers, RestPendingData, PendingDataSize - 1, AdjustedBufferSize);
                        {{value, ProdPid}, RestProducers} ->
                            ProdPid ! produce,
                            manager(Parent, RestProducers, AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers, NumProducers, RestPendingData, PendingDataSize - 1, AdjustedBufferSize)
                    end
            end;

        {producer_exit, _ProducerId} ->
            try_exit(Parent, AvailableProducers, AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers + 1, NumProducers, PendingData, PendingDataSize, AdjustedBufferSize);

        UnsupportedMsg ->
            io:format("Unsupported message: ~p~n", [UnsupportedMsg])
    end.

try_exit(Parent, AvailableProducers, AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers, NumProducers, PendingData, PendingDataSize, AdjustedBufferSize) ->
    case NumTerminatedProducers == NumProducers andalso AvailableConsumersSize == ?NUM_CONSUMERS of
        true ->
            [Pid ! stop || Pid <- queue:to_list(AvailableConsumers)],
            Parent ! done,
            ok;
        false ->
            manager(Parent, AvailableProducers, AvailableConsumers, AvailableConsumersSize, NumTerminatedProducers, NumProducers, PendingData, PendingDataSize, AdjustedBufferSize)
    end.
producer(RemainingItems) ->
    receive
        produce when RemainingItems > 0 ->
            % Data = process_item(0.0, ?PROD_COST),
            Data = identity(0.0, ?PROD_COST),
            manager ! {data, Data, self()},
            producer(RemainingItems - 1);
        produce ->
            manager ! {producer_exit, self()}
    end.

consumer() ->
    receive
        {consume, Data} -> 
            % process_item(Data, ?CONS_COST),
            identity(Data, ?CONS_COST),
            manager ! {consumer_available, self()},
            consumer();
        stop -> 
            ok
    end. 

identity(CurTerm, _Cost) ->
    CurTerm.

% process_item(CurTerm, Cost) ->
%     RandState = pseudo_random:new(Cost),
%     outer_loop(Cost, RandState, CurTerm).

% outer_loop(0, RandState, Res) ->
%     {RandVal, _NewRandState} = pseudo_random:next_double(RandState),
%     Res + math:log(abs(RandVal) + 0.01);

% outer_loop(Cost, RandState, Res) when Cost > 0 ->
%     {NewRes, NewRandState} = inner_loop(Res, 100, RandState),
%     outer_loop(Cost - 1, NewRandState, NewRes).

% inner_loop(Res, 0, RandState) ->
%     {Res, RandState};

% inner_loop(Res, Count, RandState) when Count > 0 ->
%     {RandVal, NewRandState} = pseudo_random:next_double(RandState),
%     % io:format("Erlang RandVal: ~p~n", [RandVal]),
%     % io:format("Erlang Res: ~p~n", [Res]),
%     inner_loop(Res + math:log(abs(RandVal) + 0.01), Count - 1, NewRandState).


print_config() ->
    io:format("    Buffer size = ~p~n",[?BUFFER_SIZE]),
    io:format("    num producers = ~p~n",[?NUM_PRODUCERS]),
    io:format("    num consumers = ~p~n",[?NUM_CONSUMERS]),
    io:format("    prod cost = ~p~n",[?PROD_COST]),
    io:format("    cons cost = ~p~n",[?CONS_COST]),
    io:format("    items per producer = ~p~n",[?NUM_ITEMS_PER_PRODUCER]).