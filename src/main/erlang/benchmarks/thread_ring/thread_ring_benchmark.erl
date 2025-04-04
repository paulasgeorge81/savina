% -module(thread_ring_benchmark).
% -export([run/0, actor/2, print_config/0]).
% -define(N, 10_000). % number of actors
% -define(R, 1_000_000). % number of pings/no of rounds

% run() -> 
%     Main = self(),
%     % Pids = [spawn(?MODULE, actor, [undefined, Main]) || _ <- lists:seq(1, ?N)],
%     Pids = spawn_n(Main,?N, []),
%     setup_ring(Pids),
%     hd(Pids) ! {ping, ?R},
%     receive
%       done ->
%         ok
%     end.
% spawn_n(_Main, 0, Pids) ->
%     Pids;
% spawn_n(Main, N, Pids) ->
%     spawn_n(Main, N-1, [spawn(?MODULE, actor, [undefined, Main]) | Pids]).



% setup_ring([H | T]) ->
%     Last = lists:foldl(fun (Next, Prev) -> Prev ! {set_next, Next}, Next end, H, T),
%     Last ! {set_next, H}.  % Completing the ring by linking the last actor to the first

% actor(Next, Main) ->
%     receive
%         {set_next, NewNext} ->
%             actor(NewNext, Main);
%         {ping, PingsLeft} when PingsLeft > 0 ->
%             Next ! {ping, PingsLeft - 1},
%             actor(Next, Main);
%         {ping, 0} ->
%             Next ! {exit, self()},  %% Send exit message with the first actor's PID
%             actor(Next, Main);
%         {exit, Original} when self() =:= Original -> %% Terminate when exit message loops back
%             Main ! done;
%         {exit, Original} ->
%             Next ! {exit, Original},
%             ok
%     end.


% print_config() ->
%     io:format("    N (num actors) = ~p~n",[?N]),
%     io:format("    R (num rounds) = ~p~n",[?R]).



% -module(thread_ring_benchmark).
% -export([run/0, actor/2, print_config/0]).
% -define(N, 10_000).    % Number of actors
% -define(R, 1_000_000). % Number of rounds

% run() -> 
%     Main = self(),
%     {FirstPid, LastPid} = spawn_ring(?N, Main),
%     LastPid ! {set_next, FirstPid},  % Completing the ring by linking the last actor to the first
%     FirstPid ! {ping, ?R},

%     receive
%         done -> ok
%     end.

% spawn_ring(1, Main) ->
%     Pid = spawn(?MODULE, actor, [undefined, Main]),
%     {Pid, Pid}; % First and last are the same

% spawn_ring(N, Main) ->
%     Pid = spawn(?MODULE, actor, [undefined, Main]),
%     {FirstPid, LastPid} = spawn_ring(N - 1, Main),
%     Pid ! {set_next, FirstPid}, % link current actor to previous one
%     {Pid, LastPid}. % Pid becomes new first
    

% actor(Next, Main) ->
%     receive
%         {set_next, NewNext} ->
%             actor(NewNext, Main);
%         {ping, PingsLeft} when PingsLeft > 0 ->
%             Next ! {ping, PingsLeft - 1},
%             actor(Next, Main);
%         {ping, 0} ->
%             Next ! {exit, self()},  %% Send exit message with the first actor's PID
%             actor(Next, Main);
%         {exit, Original} when self() =:= Original -> %% Terminate when exit message loops back
%             Main ! done;
%         {exit, Original} ->
%             Next ! {exit, Original},
%             ok
%     end.

% print_config() ->
%     io:format("    N (num actors) = ~p~n", [?N]),
%     io:format("    R (num rounds) = ~p~n", [?R]).
% 
% -module(thread_ring_benchmark).
% -export([run/0, actor/2, print_config/0]).
% -define(N, 10_000).    % Number of actors
% -define(R, 1_000_000). % Number of rounds

% run() -> 
%     Main = self(),
%     {FirstPid, LastPid} = spawn_ring(?N, Main),
%     LastPid ! {set_next, FirstPid},  % Completing the ring by linking the last actor to the first
%     FirstPid ! {ping, ?R},
%     receive
%         done -> ok
%     end.

% % Spawns all actors in a ring and returns the first and last actor PIDs
% spawn_ring(1, Main) ->
%     Pid = spawn(?MODULE, actor, [Main, self()]),
%     {Pid, Pid}; % Return both first and last actor PIDs (same for base case)
% spawn_ring(N, Main) ->
%     {FirstPid, LastPid} = spawn_ring(N - 1, Main),
%     Pid = spawn(?MODULE, actor, [undefined, Main]),
%     LastPid ! {set_next, Pid},
%     {FirstPid, Pid}. % Return both first and last actor PIDs

% actor(Next, Main) ->
%     receive
%         {set_next, NewNext} ->
%             actor(NewNext, Main);
%         {ping, PingsLeft} when PingsLeft > 0 ->
%             Next ! {ping, PingsLeft - 1},
%             actor(Next, Main);
%         {ping, 0} ->
%             Next ! {exit, self()},  %% Send exit message with the first actor's PID
%             actor(Next, Main);
%         {exit, Original} when self() =:= Original -> %% Terminate when exit message loops back
%             Main ! done;
%         {exit, Original} ->
%             Next ! {exit, Original},
%             ok
%     end.

% print_config() ->
%     io:format("    N (num actors) = ~p~n", [?N]),
%     io:format("    R (num rounds) = ~p~n", [?R]). 
% 

-module(thread_ring_benchmark).
-export([run/0, actor/2, print_config/0]).
-define(N, 10_000).    % Number of actors
-define(R, 1_000_000). % Number of rounds

run() -> 
    Main = self(),
    {FirstPid, LastPid} = spawn_ring(?N, Main),
    LastPid ! {set_next, FirstPid},  % Completing the ring by linking the last actor to the first
    FirstPid ! {ping, ?R},
    receive
        done -> ok
    end.


spawn_ring(N, Main) ->
    spawn_ring(N, Main, undefined, undefined).

spawn_ring(1, Main, undefined, undefined) ->
    %% Only one actor in the ring
    Pid = spawn(?MODULE, actor, [undefined, Main]),
    {Pid, Pid};

spawn_ring(1, Main, Prev, First) ->
    %% Last actor
    Pid = spawn(?MODULE, actor, [undefined, Main]),
    Prev ! {set_next, Pid},
    {First, Pid};

spawn_ring(N, Main, undefined, undefined) ->
    %% First actor (initialize accumulator)
    FirstPid = spawn(?MODULE, actor, [undefined, Main]),
    spawn_ring(N - 1, Main, FirstPid, FirstPid);

spawn_ring(N, Main, Prev, First) ->
    %% General case
    Pid = spawn(?MODULE, actor, [undefined, Main]),
    Prev ! {set_next, Pid},
    spawn_ring(N - 1, Main, Pid, First).




actor(Next, Main) ->
    receive
        {set_next, NewNext} ->
            actor(NewNext, Main);
        {ping, PingsLeft} when PingsLeft > 0 ->
            Next ! {ping, PingsLeft - 1},
            actor(Next, Main);
        {ping, 0} ->
            Next ! {exit, self()},  %% Send exit message with the first actor's PID
            actor(Next, Main);
        {exit, Original} when self() =:= Original -> %% Terminate when exit message loops back
            Main ! done;
        {exit, Original} ->
            Next ! {exit, Original},
            ok
    end.

print_config() ->
    io:format("    N (num actors) = ~p~n", [?N]),
    io:format("    R (num rounds) = ~p~n", [?R]). 

