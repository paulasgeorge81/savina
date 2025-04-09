%Map implementation 1
% -module(philosopher_benchmark).
% -export([run/0, print_config/0, philosopher/6, arbitrator/4]).

% -define(N, 50).      % Number of philosophers
% -define(M, 10_000).  % Number of eating rounds

% run() ->
%     Main = self(),
%     Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, #{}, 0]),    
%     PhilosopherPids = [spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator, Id, ((Id + 1) rem ?N)]) || Id <- lists:seq(0, ?N - 1)],
%     % PhilosopherPids = spawn_philosophers(0, ?N - 1, Arbitrator, []),
%     % Send initial message to philosophers
%     [Pid ! start || Pid <- PhilosopherPids],

%     receive
%         {done, TotalRetries} ->
%             % io:format("Dining Philosophers benchmark completed.~n"),
%             io:format("Total retries: ~p~n", [TotalRetries])
%     end.

% % spawn_philosophers(Id, Max, Arbitrator, Acc) when Id =< Max ->
% %     LeftFork = Id,
% %     RightFork = (Id + 1) rem ?N,
% %     Pid = spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator, LeftFork, RightFork]),
% %     spawn_philosophers(Id + 1, Max, Arbitrator, [Pid | Acc]);
% % spawn_philosophers(_, _, _, Acc) ->
% %     lists:reverse(Acc).

% philosopher(Id, Retries, 0, Arbitrator, _LeftFork, _RightFork) ->
%     % io:format("Philosopher ~p has finished eating.~n", [Id]),
%     Arbitrator ! {exit, Id, Retries};
% philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork) ->
%     receive
%         start ->
%             % io:format("Philosopher ~p is hungry.~n", [Id]),
%             Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
%             philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork);
%         denied ->
%             % io:format("Philosopher ~p was denied.~n", [Id]),
%             Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
%             philosopher(Id, Retries + 1, Rounds, Arbitrator, LeftFork, RightFork);
%         eat ->
%             % io:format("Philosopher ~p is eating.~n", [Id]),
%             Arbitrator ! {done, Id, LeftFork, RightFork},
%             self() ! start,
%             philosopher(Id, Retries, Rounds - 1, Arbitrator, LeftFork, RightFork)
%     end.

% arbitrator(Main, 0, _Forks, TotalRetries) -> 
%     Main ! {done, TotalRetries};

% arbitrator(Main, N, Forks, TotalRetries) ->
%     receive
%         {hungry, Philosopher, _Id, LeftFork, RightFork} ->
%             case {maps:get(LeftFork, Forks, false), maps:get(RightFork, Forks, false)} of
%                 {false, false} -> 
%                     % io:format("Philosopher ~p can eat.~n", [Id]),
%                     NewForks = Forks#{LeftFork => true, RightFork => true},
%                     Philosopher ! eat,
%                     arbitrator(Main, N, NewForks, TotalRetries);
%                 _ ->  
%                     % io:format("Philosopher ~p is denied forks.~n", [Id]),
%                     Philosopher ! denied,
%                     arbitrator(Main, N, Forks, TotalRetries)
%             end;
%         {done, _Id, LeftFork, RightFork} ->
%             % io:format("Philosopher ~p has finished eating and released forks.~n", [Id]),
%             arbitrator(Main, N, Forks#{LeftFork => false, RightFork => false}, TotalRetries);
%         {exit, _Id, LocalRetries} ->
%             % io:format("Philosopher ~p exits with ~p retries.~n", [Id, LocalRetries]),
%             arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
%     end.

% print_config() ->
%     io:format("    N (num philosophers) = ~p~n", [?N]),
%     io:format("    M (num eating rounds) = ~p~n", [?M]).


% Map implementation 2
% -module(philosopher_benchmark).
% -export([run/0, print_config/0, philosopher/6,arbitrator/4]).

% -define(N, 1_000).      % Number of philosophers
% -define(M, 100_000).  % Number of eating rounds

% run() ->
%     Main = self(),
%     InitialForks = maps:from_list([{I, false} || I <- lists:seq(0, ?N - 1)]),
%     Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, InitialForks, 0]),    
%     PhilosopherPids = [spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator, Id, (Id + 1) rem ?N ]) || Id <- lists:seq(0, ?N - 1)],

%     % Send initial message to philosophers
%     [Pid ! start || Pid <- PhilosopherPids],

%     receive
%         {done, TotalRetries} ->
%             % io:format("Dining Philosophers benchmark completed.~n"),
%             io:format("Total retries: ~p~n", [TotalRetries])
%     end.

% philosopher(Id, Retries, 0, Arbitrator, _LeftFork, _RightFork) ->
%     % io:format("Philosopher ~p has finished eating.~n", [Id]),
%     Arbitrator ! {exit, Id, Retries};
% philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork) ->
%     receive
%         start ->
%             % io:format("Philosopher ~p is hungry.~n", [Id]),
%             Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
%             philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork);
%         denied ->
%             % io:format("Philosopher ~p was denied.~n", [Id]),
%             Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
%             philosopher(Id, Retries + 1, Rounds, Arbitrator, LeftFork, RightFork);
%         eat ->
%             % io:format("Philosopher ~p is eating.~n", [Id]),
%             Arbitrator ! {done, Id, LeftFork, RightFork},
%             self() ! start,
%             philosopher(Id, Retries, Rounds - 1, Arbitrator, LeftFork, RightFork)
%     end.

% arbitrator(Main, 0, _Forks, TotalRetries) -> 
%     Main ! {done, TotalRetries};

% arbitrator(Main, N, Forks, TotalRetries) ->
%     receive
%         {hungry, Philosopher, _Id, LeftFork, RightFork} ->
%             case Forks of
%                 #{LeftFork := false, RightFork := false} -> 
%                     % io:format("Philosopher ~p can eat.~n", [Id]),
%                     NewForks = Forks#{LeftFork => true, RightFork => true},
%                     Philosopher ! eat,
%                     arbitrator(Main, N, NewForks, TotalRetries);
%                 _ ->  
%                     % io:format("Philosopher ~p is denied forks.~n", [Id]),
%                     Philosopher ! denied,
%                     arbitrator(Main, N, Forks, TotalRetries)
%             end;
%         {done, _Id, LeftFork, RightFork} ->
%             % io:format("Philosopher ~p has finished eating and released forks.~n", [Id]),
%             arbitrator(Main, N, Forks#{LeftFork => false, RightFork => false}, TotalRetries);
%         {exit, _Id, LocalRetries} ->
%             % io:format("Philosopher ~p exits with ~p retries.~n", [Id, LocalRetries]),
%             arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
%     end.

% print_config() ->
%     io:format("    N (num philosophers) = ~p~n", [?N]),
%     io:format("    M (num eating rounds) = ~p~n", [?M]).



% Using arrays
% -module(philosopher_benchmark).
% -export([run/0, print_config/0, philosopher/6, arbitrator/4]).

% -define(N, 1_000).    % Number of philosophers
% -define(M, 100_000).  % Number of eating rounds

% run() ->
%     Main = self(),
%     InitialForks = array:new(?N, {default, false}),
%     Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, InitialForks, 0]),
%     PhilosopherPids = [spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator, Id, (Id + 1) rem ?N]) || Id <- lists:seq(0, ?N - 1)],
    
%     [Pid ! start || Pid <- PhilosopherPids],

%     receive
%         {done, TotalRetries} ->
%             io:format("Total retries: ~p~n", [TotalRetries])
%     end.

% philosopher(Id, Retries, 0, Arbitrator, _LeftFork, _RightFork) ->
%     Arbitrator ! {exit, Id, Retries};
% philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork) ->
%     receive
%         start ->
%             Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
%             philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork);
%         denied ->
%             Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
%             philosopher(Id, Retries + 1, Rounds, Arbitrator, LeftFork, RightFork);
%         eat ->
%             Arbitrator ! {done, Id, LeftFork, RightFork},
%             self() ! start,
%             philosopher(Id, Retries, Rounds - 1, Arbitrator, LeftFork, RightFork)
%     end.

% arbitrator(Main, 0, _Forks, TotalRetries) -> 
%     Main ! {done, TotalRetries};

% arbitrator(Main, N, Forks, TotalRetries) ->
%     receive
%         {hungry, Philosopher, _Id, LeftFork, RightFork} ->
%             case {array:get(LeftFork, Forks), array:get(RightFork, Forks)} of
%                 {false, false} ->
%                     NewForks = array:set(LeftFork, true, Forks),
%                     NewerForks = array:set(RightFork, true, NewForks),
%                     Philosopher ! eat,
%                     arbitrator(Main, N, NewerForks, TotalRetries);
%                 _ ->
%                     Philosopher ! denied,
%                     arbitrator(Main, N, Forks, TotalRetries)
%             end;
%         {done, _Id, LeftFork, RightFork} ->
%             Forks1 = array:set(LeftFork, false, Forks),
%             Forks2 = array:set(RightFork, false, Forks1),
%             arbitrator(Main, N, Forks2, TotalRetries);
%         {exit, _Id, LocalRetries} ->
%             arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
%     end.

% print_config() ->
%     io:format("    N (num philosophers) = ~p~n", [?N]),
%     io:format("    M (num eating rounds) = ~p~n", [?M]).


% Using tuple

-module(philosopher_benchmark).
-export([run/0, print_config/0, philosopher/6, arbitrator/4]).

-define(N, 1_000).    % Number of philosophers
-define(M, 100_000).  % Number of eating rounds

run() ->
    Main = self(),
    EmptyForks = erlang:make_tuple(?N, false),  % Initialize all forks to false
    Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, EmptyForks, 0]),    
    PhilosopherPids = [spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator, Id + 1, ((Id + 1) rem ?N) + 1]) || Id <- lists:seq(0, ?N - 1)],
    % PhilosopherPids = spawn_philosophers(0, ?N - 1, Arbitrator, []),
    
    [Pid ! start || Pid <- PhilosopherPids],

    receive
        {done, TotalRetries} ->
            io:format("Total retries: ~p~n", [TotalRetries])
    end.

% spawn_philosophers(Id, Max, Arbitrator, Acc) when Id =< Max ->
%     LeftFork = Id + 1,
%     RightFork = ((Id + 1) rem ?N) + 1,
%     Pid = spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator, LeftFork, RightFork]),
%     spawn_philosophers(Id + 1, Max, Arbitrator, [Pid | Acc]);
% spawn_philosophers(_, _, _, Acc) ->
%     lists:reverse(Acc).

    

philosopher(Id, Retries, 0, Arbitrator, _LeftFork, _RightFork) ->
    Arbitrator ! {exit, Id, Retries};
philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork) ->
    receive
        start ->
            Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
            philosopher(Id, Retries, Rounds, Arbitrator, LeftFork, RightFork);
        denied ->
            Arbitrator ! {hungry, self(), Id, LeftFork, RightFork},
            philosopher(Id, Retries + 1, Rounds, Arbitrator, LeftFork, RightFork);
        eat ->
            Arbitrator ! {done, Id, LeftFork, RightFork},
            self() ! start,
            philosopher(Id, Retries, Rounds - 1, Arbitrator, LeftFork, RightFork)
    end.

arbitrator(Main, 0, _Forks, TotalRetries) -> 
    Main ! {done, TotalRetries};

arbitrator(Main, N, Forks, TotalRetries) ->
    receive
        {hungry, Philosopher, _Id, LeftFork, RightFork} ->
            case {element(LeftFork, Forks), element(RightFork, Forks)} of
                {false, false} ->
                    Forks1 = setelement(LeftFork, Forks, true),
                    Forks2 = setelement(RightFork, Forks1, true),
                    Philosopher ! eat,
                    arbitrator(Main, N, Forks2, TotalRetries);
                _ ->
                    Philosopher ! denied,
                    arbitrator(Main, N, Forks, TotalRetries)
            end;
        {done, _Id, LeftFork, RightFork} ->
            Forks1 = setelement(LeftFork, Forks, false),
            Forks2 = setelement(RightFork, Forks1, false),
            arbitrator(Main, N, Forks2, TotalRetries);
        {exit, _Id, LocalRetries} ->
            arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
    end.

print_config() ->
    io:format("    N (num philosophers) = ~p~n", [?N]),
    io:format("    M (num eating rounds) = ~p~n", [?M]).
