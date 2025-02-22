-module(philosopher).
-export([run/0, print_config/0]).

-define(N, 20).      % Number of philosophers
-define(M, 10_000).   % Number of eating rounds

run() ->
    Main = self(),
    Arbitrator = spawn(fun() -> arbitrator(Main, ?N, #{}, 0) end),
    [spawn(fun() -> philosopher(Id, 0, ?M, Arbitrator) end) || Id <- lists:seq(0, ?N - 1)],

    receive
      {done, TotalRetries} ->
        io:format("Dining Philosophers benchmark completed.~n"),
        io:format("Total Retries: ~p~n", [TotalRetries])
    end.

    
philosopher(_Id, Retries, 0, Arbitrator) ->
    Arbitrator ! {exit, Retries};

philosopher(Id, Retries, RoundsLeft, Arbitrator) ->
    Arbitrator ! {hungry, self(), Id},
    receive
        eat ->
            Arbitrator ! {done, Id},
            philosopher(Id, Retries, RoundsLeft - 1, Arbitrator);
        denied ->
            philosopher(Id, Retries + 1, RoundsLeft, Arbitrator)
    end.


arbitrator(Main, 0, _Forks, TotalRetries) -> 
    Main ! {done, TotalRetries};

arbitrator(Main, N, Forks, TotalRetries) ->
    receive
        {hungry, Philosopher, Id} ->
            Left = Id,
            Right = (Id + 1) rem ?N,
            case {maps:get(Left, Forks, false), maps:get(Right, Forks, false)} of
                {false, false} -> 
                    NewForks = Forks#{Left => true, Right => true},
                    Philosopher ! eat,
                    arbitrator(Main, N, NewForks, TotalRetries);
                _ ->  
                    Philosopher ! denied,
                    arbitrator(Main, N, Forks, TotalRetries)
            end;

        {done, Id} ->
            Left = Id,
            Right = (Id + 1) rem ?N,
            arbitrator(Main, N, Forks#{Left => false, Right => false}, TotalRetries);

        {exit, LocalRetries} ->
            arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
    end.

print_config() ->
    io:format("    N (num philosophers) = ~p~n",[?N]),
    io:format("    M (num eating rounds) = ~p~n",[?M]).
