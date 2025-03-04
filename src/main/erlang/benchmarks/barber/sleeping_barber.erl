-module(sleeping_barber).
-export([run/0, barber/1, waiting_room/5, customer_factory/3, customer/2, print_config/0]).
-define(N, 5). % num haircuts
-define(W, 1_000). % waiting room capacity
-define(APR, 1_000). % average production rate
-define(AHR, 1_000). % average haircut rate

run() ->
    InitialRandState = pseudo_random:new(),
    Main = self(),
    BarberPid = spawn(?MODULE, barber, [Main]),
    RoomPid = spawn(?MODULE, waiting_room, [?W, [], BarberPid, true, InitialRandState]),
    CustomerFactoryPid = spawn(?MODULE, customer_factory, [?N, RoomPid, InitialRandState]),
    CustomerFactoryPid ! start,
    receive
      done ->
        ok
    end.

waiting_room(Capacity, Queue, BarberPid, BarberAsleep, RandState) ->
    receive
        {enter, CustomerPid} ->
            case length(Queue) of
                Capacity -> 
                    CustomerPid ! full,
                     waiting_room(Capacity, Queue, BarberPid, BarberAsleep, RandState);
                _ ->
                    NewQueue = Queue ++ [CustomerPid],
                    case BarberAsleep of 
                        true -> 
                            self() ! {next, RandState}, 
                            waiting_room(Capacity, NewQueue, BarberPid, false, RandState);
                        false -> 
                            CustomerPid ! wait, 
                            waiting_room(Capacity, NewQueue, BarberPid, BarberAsleep, RandState)
                    end
            end;
        {next, NewRandState} ->
            case Queue of
                [NextCustomerPid | Rest] ->
                    BarberPid ! {enter, NextCustomerPid, self(), NewRandState},
                    waiting_room(Capacity, Rest, BarberPid, false, NewRandState);
                [] ->
                    BarberPid ! wait,
                    waiting_room(Capacity, [], BarberPid, true, NewRandState)
            end;
        exit ->
            BarberPid ! exit
    end.

barber(Main) ->
    receive
        {enter, CustomerPid, RoomPid, RandState} ->
            CustomerPid ! start,
            % io:format("Barber: Processing customer ~p~n", [CustomerPid]),
            {HaircutTime, NewRandState} = pseudo_random:next_int(?AHR, RandState),
            _ = busy_wait(HaircutTime + 10),  % Simulate haircut
            CustomerPid ! done,
            RoomPid ! {next, NewRandState},
            barber(Main);
        wait ->
            % io:format("Barber: No customers. Going to have a sleep~n"),
            barber(Main);
        exit ->
            Main ! done
    end.

customer_factory(NumCustomers, RoomPid, RandState) ->
    customer_factory(NumCustomers, RoomPid, RandState, 0).

customer_factory(0, RoomPid, _, Attempts) -> 
    io:format("Total attempts: ~p~n", [Attempts]),
    RoomPid ! exit;
customer_factory(NumHairCuts, RoomPid, RandState, Attempts) ->
    receive
        start ->
            {NewAttempts, NewState} = send_customer_to_room(NumHairCuts, Attempts, RoomPid, RandState, self()),
            customer_factory(NumHairCuts, RoomPid, NewState, NewAttempts);
        {returned, CustomerPid} ->
            NewAttempts = Attempts + 1,
            % io:format("Customer ~p returned attempts ~p~n", [CustomerPid, NewAttempts]),
            RoomPid ! {enter, CustomerPid},
            customer_factory(NumHairCuts, RoomPid, RandState, NewAttempts);
        done ->
                customer_factory(NumHairCuts - 1, RoomPid, RandState, Attempts)
    end.

send_customer_to_room(0, Attempts, _, RandState,_) ->
    {Attempts, RandState};
send_customer_to_room(NumHairCuts, Attempts, RoomPid, RandState, FactoryPid) ->
    {Delay, NewRandState} = pseudo_random:next_int(?APR, RandState),
    NewAttempts = Attempts + 1,
    CustomerPid = spawn(?MODULE, customer, [NewAttempts, FactoryPid]),
    RoomPid ! {enter, CustomerPid},
    _ = busy_wait(Delay + 10),
    send_customer_to_room(NumHairCuts - 1, NewAttempts, RoomPid, NewRandState, FactoryPid).

customer(Id, FactoryPid) ->
    receive
        full ->
            % io:format("Customer- ~p The waiting room is full. I am leaving.~n",[Id]),
            FactoryPid ! {returned, self()},
            customer(Id, FactoryPid);
        wait ->
            % io:format("Customer- ~p I will wait.~n", [Id]),
            customer(Id, FactoryPid);
        start ->
            % io:format("Customer- ~p I am now being served.~n", [Id]),
            customer(Id, FactoryPid);
        done -> 
            % io:format("Customer- ~p I have been served, exiting...~n", [Id]),
            FactoryPid ! done 
    end.

busy_wait(Limit) -> 
    busy_wait(Limit, 0).
busy_wait(0, Acc) -> Acc;
busy_wait(Limit, Acc) ->
    rand:uniform(),
    busy_wait(Limit - 1, Acc + 1).

print_config() ->
    io:format("    N (num haircuts) = ~p~n",[?N]),
    io:format("    W (waiting room size) = ~p~n",[?W]),
    io:format("    APR (production rate) = ~p~n",[?APR]),
    io:format("    AHR (haircut rate) = ~p~n",[?AHR]).

