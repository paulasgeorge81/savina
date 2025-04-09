% -module(philosopher_benchmark).
% -export([run/0, print_config/0, philosopher/4, arbitrator/4]).

% -define(N, 50).      % Number of philosophers
% -define(M, 10_000).  % Number of eating rounds

% run() ->
%     Main = self(),
%     % Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, #{}, 0]),
%     InitialForks = maps:from_list([{I, false} || I <- lists:seq(0, ?N - 1)]),
%     Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, InitialForks, 0]),    
%     PhilosopherPids = [spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator]) || Id <- lists:seq(0, ?N - 1)],

%     % Send initial message to philosophers
%     [Pid ! start || Pid <- PhilosopherPids],

%     receive
%         {done, TotalRetries} ->
%             % io:format("Dining Philosophers benchmark completed.~n"),
%             io:format("Total retries: ~p~n", [TotalRetries])
%     end.

% philosopher(Id, Retries, 0, Arbitrator) ->
%     % io:format("Philosopher ~p has finished eating.~n", [Id]),
%     Arbitrator ! {exit, Id, Retries};
% philosopher(Id, Retries, Rounds, Arbitrator) ->
%     receive
%         start ->
%             % io:format("Philosopher ~p is hungry.~n", [Id]),
%             Arbitrator ! {hungry, self(), Id},
%             philosopher(Id, Retries, Rounds, Arbitrator);
%         denied ->
%             % io:format("Philosopher ~p was denied.~n", [Id]),
%             Arbitrator ! {hungry, self(), Id},
%             philosopher(Id, Retries + 1, Rounds, Arbitrator);
%         eat ->
%             % io:format("Philosopher ~p is eating.~n", [Id]),
%             Arbitrator ! {done, Id},
%             self() ! start,
%             philosopher(Id, Retries, Rounds - 1, Arbitrator)
%     end.

% arbitrator(Main, 0, _Forks, TotalRetries) -> 
%     Main ! {done, TotalRetries};

% arbitrator(Main, N, Forks, TotalRetries) ->
%     receive
%         {hungry, Philosopher, Id} ->
%             LeftFork = Id,
%             RightFork = (Id + 1) rem ?N,
           
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
%         {done, Id} ->
%             LeftFork = Id,
%             RightFork = (Id + 1) rem ?N,
%             % io:format("Philosopher ~p has finished eating and released forks.~n", [Id]),
%             arbitrator(Main, N, Forks#{LeftFork => false, RightFork => false}, TotalRetries);
%         {exit, _Id, LocalRetries} ->
%             % io:format("Philosopher ~p exits with ~p retries.~n", [Id, LocalRetries]),
%             arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
%     end.

% print_config() ->
%     io:format("    N (num philosophers) = ~p~n", [?N]),
%     io:format("    M (num eating rounds) = ~p~n", [?M]).

% -module(philosopher_benchmark).
% -export([run/0, print_config/0]).

% -define(N, 50).      % Number of philosophers
% -define(M, 10_000).        % Number of eating rounds

% run() ->
%     Main = self(),
%     Forks = array:new(?N, {default, false}),
%     Arbitrator = spawn(fun() -> arbitrator(Main, ?N, Forks, 0) end),
%     PhilosopherPids = [spawn(fun() -> philosopher(Id, 0, ?M, Arbitrator) end) || Id <- lists:seq(0, ?N - 1)],

%     % Send initial message to philosophers
%     [Pid ! start || Pid <- PhilosopherPids],

%     receive
%         {done, TotalRetries} ->
%             io:format("Total retries: ~p~n", [TotalRetries])
%     end.

% philosopher(Id, Retries, 0, Arbitrator) ->
%     Arbitrator ! {exit, Id, Retries};
% philosopher(Id, Retries, Rounds, Arbitrator) ->
%     receive
%         start ->
%             Arbitrator ! {hungry, self(), Id},
%             philosopher(Id, Retries, Rounds, Arbitrator);
%         denied ->
%             Arbitrator ! {hungry, self(), Id},
%             philosopher(Id, Retries + 1, Rounds, Arbitrator);
%         eat ->
%             Arbitrator ! {done, Id},
%             self() ! start,
%             philosopher(Id, Retries, Rounds - 1, Arbitrator)
%     end.

% arbitrator(Main, 0, _Forks, TotalRetries) -> 
%     Main ! {done, TotalRetries};

% arbitrator(Main, N, Forks, TotalRetries) ->
%     receive
%         {hungry, Philosopher, Id} ->
%             LeftFork = Id,
%             RightFork = (Id + 1) rem ?N,
%             case {array:get(LeftFork, Forks), array:get(RightFork, Forks)} of
%                 {false, false} -> 
%                     NewForks = array:set(RightFork, true, array:set(LeftFork, true, Forks)),
%                     Philosopher ! eat,
%                     arbitrator(Main, N, NewForks, TotalRetries);
%                 _ ->  
%                     Philosopher ! denied,
%                     arbitrator(Main, N, Forks, TotalRetries)
%             end;
%         {done, Id} ->
%             LeftFork = Id,
%             RightFork = (Id + 1) rem ?N,
%             NewForks = array:set(RightFork, false, array:set(LeftFork, false, Forks)),
%             arbitrator(Main, N, NewForks, TotalRetries);
%         {exit, _Id, LocalRetries} ->
%             arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
%     end.

% print_config() ->
%     io:format("    N (num philosophers) = ~p~n", [?N]),
%     io:format("    M (num eating rounds) = ~p~n", [?M]).

% -module(philosopher_benchmark).
% -export([run/0, print_config/0]).

% -define(N, 10_000).      % Number of philosophers
% -define(M, 1000).        % Number of eating rounds

% run() ->
%     Main = self(),
%     %% Create fork table as a tuple of size ?N, all initially false.
%     Forks = erlang:make_tuple(?N, false),
%     Arbitrator = spawn(fun() -> arbitrator(Main, ?N, Forks, 0) end),
%     PhilosopherPids = [spawn(fun() -> philosopher(Id, 0, ?M, Arbitrator) end) 
%                            || Id <- lists:seq(0, ?N - 1)],

%     %% Send initial message to each philosopher.
%     [Pid ! start || Pid <- PhilosopherPids],

%     receive
%         {done, TotalRetries} ->
%             io:format("Total retries: ~p~n", [TotalRetries])
%     end.

% %% Philosopher process.
% philosopher(Id, Retries, 0, Arbitrator) ->
%     %% Philosopher finished eating; inform arbitrator.
%     Arbitrator ! {exit, Id, Retries};
% philosopher(Id, Retries, Rounds, Arbitrator) ->
%     receive
%         start ->
%             %% Philosopher is hungry.
%             Arbitrator ! {hungry, self(), Id},
%             philosopher(Id, Retries, Rounds, Arbitrator);
%         denied ->
%             %% Denied forks; increment retry count.
%             Arbitrator ! {hungry, self(), Id},
%             philosopher(Id, Retries + 1, Rounds, Arbitrator);
%         eat ->
%             %% Philosopher is eating; notify arbitrator and ask to start again.
%             Arbitrator ! {done, Id},
%             self() ! start,
%             philosopher(Id, Retries, Rounds - 1, Arbitrator)
%     end.

% %% Arbitrator process using a tuple for fork tracking.
% arbitrator(Main, 0, _Forks, TotalRetries) ->
%     Main ! {done, TotalRetries};
% arbitrator(Main, N, Forks, TotalRetries) ->
%     receive
%         {hungry, Philosopher, Id} ->
%             %% Calculate tuple indices (1-indexed).
%             LeftIndex = Id + 1,
%             RightIndex = ((Id + 1) rem ?N) + 1,
%             %% Check if both forks are free.
%             case {element(LeftIndex, Forks), element(RightIndex, Forks)} of
%                 {false, false} ->
%                     %% Mark both forks as in use.
%                     Forks1 = setelement(LeftIndex, Forks, true),
%                     NewForks = setelement(RightIndex, Forks1, true),
%                     Philosopher ! eat,
%                     arbitrator(Main, N, NewForks, TotalRetries);
%                 _ ->
%                     Philosopher ! denied,
%                     arbitrator(Main, N, Forks, TotalRetries)
%             end;
%         {done, Id} ->
%             %% Release forks: compute indices.
%             LeftIndex = Id + 1,
%             RightIndex = ((Id + 1) rem ?N) + 1,
%             Forks1 = setelement(LeftIndex, Forks, false),
%             NewForks = setelement(RightIndex, Forks1, false),
%             arbitrator(Main, N, NewForks, TotalRetries);
%         {exit, _Id, LocalRetries} ->
%             arbitrator(Main, N - 1, Forks, TotalRetries + LocalRetries)
%     end.

% print_config() ->
%     io:format("    N (num philosophers) = ~p~n", [?N]),
%     io:format("    M (num eating rounds) = ~p~n", [?M]).

-module(philosopher_benchmark).
-export([run/0, print_config/0, philosopher/6, arbitrator/4]).

-define(N, 50).  % Number of philosophers
-define(M, 10_000).    % Number of eating rounds

run() ->
    Main = self(),
    EmptyForks = erlang:make_tuple(?N, false),  % Initialize all forks to false
    Arbitrator = spawn(?MODULE, arbitrator, [Main, ?N, EmptyForks, 0]),    
    PhilosopherPids = [spawn(?MODULE, philosopher, [Id, 0, ?M, Arbitrator, Id + 1, ((Id + 1) rem ?N) + 1]) || Id <- lists:seq(0, ?N - 1)],
    
    [Pid ! start || Pid <- PhilosopherPids],

    receive
        {done, TotalRetries} ->
            io:format("Total retries: ~p~n", [TotalRetries])
    end.

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
