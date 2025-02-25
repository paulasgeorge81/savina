-module(fibonacci).
-export([run/0, fibonacci/3, print_config/0]).

-define(N, 30).

run() ->
    Parent = self(),
    RootPid = spawn(?MODULE, fibonacci, [Parent, 0, 0]),
    RootPid ! {request, Parent, ?N},
    receive
        {response, Result} ->
            io:format("   Result = ~p~n", [Result])
    end.

fibonacci(Parent, Value, Count) ->
    receive
        {request, Sender, N} ->
            if
                 N =< 2 ->
                    Sender ! {response, 1};
                true ->
                    Self = self(),
                    Pid1 = spawn(?MODULE, fibonacci, [Self, 0, 0]),
                    Pid2 = spawn(?MODULE, fibonacci, [Self, 0, 0]),
                    Pid1 ! {request, Self, N - 1},
                    Pid2 ! {request, Self, N - 2}
            end,
            fibonacci(Parent, Value, Count);
          {response, NewValue} ->
            NewCount = Count + 1,
            NewSum = Value + NewValue,
            if 
                NewCount =:= 2 -> 
                Parent ! {response, NewSum};
              true ->
                fibonacci(Parent, NewSum, NewCount)
            end
    end.

print_config() ->
    io:format("    N (index) = ~p~n",[?N]).



% -module(fibonacci).
% -export([run/0, fibonacci/0, print_config/0]).

% -define(N, 30).

% run() ->
%     RootPid = spawn(?MODULE, fibonacci, []),
%     RootPid ! {request, self(), ?N},
%     receive
%         {response, Result} ->
%             io:format("  Result = ~p~n", [Result])
%     end.


% fibonacci() ->
%     receive
%         {request, Parent, N} ->
%             if
%                 N =< 2 ->
%                     Parent ! {response, 1};
%                 true ->
%                     Pid1 = spawn(?MODULE, fibonacci, []),
%                     Pid2 = spawn(?MODULE, fibonacci, []),

%                     Pid1 ! {request, self(), N - 1},
%                     Pid2 ! {request, self(), N - 2},

%                     receive
%                         {response, Value1} ->
%                             receive
%                                 {response, Value2} ->
%                                     Parent ! {response, Value1 + Value2}
%                             end
%                     end
%             end
%     end.

% print_config() ->
%     io:format("    N (index) = ~p~n",[?N]).