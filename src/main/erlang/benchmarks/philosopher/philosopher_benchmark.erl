-module(philosopher_benchmark).
-export([run/0, print_config/0]).

-define(N, 20).      % Number of philosophers
-define(M, 10_000).  % Number of eating rounds

run() ->
    Main = self(),
    Arbitrator = spawn(fun() -> arbitrator(Main, ?N, #{}, 0) end),
    PhilosopherPids = [spawn(fun() -> philosopher(Id, 0, ?M, Arbitrator) end) || Id <- lists:seq(0, ?N - 1)],

    % Send initial message to philosophers
    [Pid ! start || Pid <- PhilosopherPids],

    receive
        {done, TotalRetries} ->
            % io:format("Dining Philosophers benchmark completed.~n"),
            io:format("Total retries: ~p~n", [TotalRetries])
    end.

philosopher(Id, Retries, 0, Arbitrator) ->
    % io:format("Philosopher ~p has finished eating.~n", [Id]),
    Arbitrator ! {exit, Id, Retries};
philosopher(Id, Retries, Rounds, Arbitrator) ->
    receive
        start ->
            % io:format("Philosopher ~p is hungry.~n", [Id]),
            Arbitrator ! {hungry, self(), Id},
            philosopher(Id, Retries, Rounds, Arbitrator);
        denied ->
            % io:format("Philosopher ~p was denied.~n", [Id]),
            Arbitrator ! {hungry, self(), Id},
            philosopher(Id, Retries + 1, Rounds, Arbitrator);
        eat ->
            % io:format("Philosopher ~p is eating.~n", [Id]),
            Arbitrator ! {done, Id},
            self() ! start,
            philosopher(Id, Retries, Rounds - 1, Arbitrator)
    end.

arbitrator(Main, 0, _Forks, TotalRetries) -> 
    Main ! {done, TotalRetries};

arbitrator(Main, N, Forks, TotalRetries) ->
    receive
        {hungry, Philosopher, Id} ->
            LeftFork = Id,
            RightFork = (Id + 1) rem ?N,
            case {maps:get(LeftFork, Forks, false), maps:get(RightFork, Forks, false)} of
                {false, false} -> 
                    % io:format("Philosopher ~p can eat.~n", [Id]),
                    NewForks = Forks#{LeftFork => true, RightFork => true},
                    Philosopher ! eat,
                    arbitrator(Main, N, NewForks, TotalRetries);
                _ ->  
                    % io:format("Philosopher ~p is denied forks.~n", [Id]),
                    Philosopher ! denied,
                    arbitrator(Main, N, Forks, TotalRetries)
            end;
        {done, Id} ->
            LeftFork = Id,
            RightFork = (Id + 1) rem ?N,
            % io:format("Philosopher ~p has finished eating and released forks.~n", [Id]),
            arbitrator(Main, N, Forks#{LeftFork => false, RightFork => false}, TotalRetries);
        {exit, _Id, LocalRetries} ->
            % io:format("Philosopher ~p exits with ~p retries.~n", [Id, LocalRetries]),
            arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
    end.

print_config() ->
    io:format("    N (num philosophers) = ~p~n", [?N]),
    io:format("    M (num eating rounds) = ~p~n", [?M]).
