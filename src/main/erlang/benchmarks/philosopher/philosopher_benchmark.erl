-module(philosopher_benchmark).
-export([run/0, print_config/0, philosopher/6, arbitrator/4]).

-define(N, 1_000).      % Number of philosophers
-define(M, 500_000).  % Number of eating rounds

run() ->
    Main = self(),
    Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, #{}, 0]),    
    PhilosopherPids = spawn_philosophers(?N, ?M, Arbitrator),
    send_start(PhilosopherPids),

    receive
        {done, TotalRetries} ->
            % io:format("Dining Philosophers benchmark completed.~n"),
            io:format("Total retries: ~p~n", [TotalRetries])
    end.

send_start([])
    -> ok;
send_start([Pid | Pids]) ->
    Pid ! start,
    send_start(Pids).

spawn_philosophers(N, M, Arbitrator) ->
    spawn_philosophers(0, N, M, Arbitrator, []).

spawn_philosophers(Id, N, _M, _Arbitrator, Acc) when Id >= N ->
    Acc;
    % lists:reverse(Acc);

spawn_philosophers(Id, N, M, Arbitrator, Acc) ->
    LeftFork = Id,
    RightFork = (Id + 1) rem ?N,
    Pid = spawn(?MODULE, philosopher, [Id, 0, M, Arbitrator, LeftFork, RightFork]),
    spawn_philosophers(Id + 1, N, M, Arbitrator, [Pid | Acc]).



philosopher(Id, Retries, 0, Arbitrator, _LeftFork, _RightFork) ->
    % io:format("Philosopher ~p has finished eating.~n", [Id]),
    Arbitrator ! {exit, Id, Retries};
philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork) ->
    receive
        start ->
            % io:format("Philosopher ~p is hungry.~n", [Id]),
            Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
            philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork);
        denied ->
            % io:format("Philosopher ~p was denied.~n", [Id]),
            Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
            philosopher(Id, Retries + 1, Rounds, Arbitrator, LeftFork, RightFork);
        eat ->
            % io:format("Philosopher ~p is eating.~n", [Id]),
            Arbitrator ! {done, Id, LeftFork, RightFork},
            self() ! start,
            philosopher(Id, Retries, Rounds - 1, Arbitrator, LeftFork, RightFork)
    end.

arbitrator(Main, 0, _Forks, TotalRetries) -> 
    Main ! {done, TotalRetries};

arbitrator(Main, N, Forks, TotalRetries) ->
    receive
        {hungry, Philosopher, _Id, LeftFork, RightFork} ->
            case {maps:get(LeftFork, Forks, free), maps:get(RightFork, Forks, free)} of
                {free, free} -> 
                    % io:format("Philosopher ~p can eat.~n", [Id]),
                    NewForks = Forks#{LeftFork => taken, RightFork => taken},
                    Philosopher ! eat,
                    arbitrator(Main, N, NewForks, TotalRetries);
                _ ->  
                    % io:format("Philosopher ~p is denied forks.~n", [Id]),
                    Philosopher ! denied,
                    arbitrator(Main, N, Forks, TotalRetries)
            end;
        {done, _Id, LeftFork, RightFork} ->
            % io:format("Philosopher ~p has finished eating and released forks.~n", [Id]),
            arbitrator(Main, N, Forks#{LeftFork => free, RightFork => free}, TotalRetries);
        {exit, _Id, LocalRetries} ->
            % io:format("Philosopher ~p exits with ~p retries.~n", [Id, LocalRetries]),
            arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
    end.

print_config() ->
    io:format("    N (num philosophers) = ~p~n", [?N]),
    io:format("    M (num eating rounds) = ~p~n", [?M]).