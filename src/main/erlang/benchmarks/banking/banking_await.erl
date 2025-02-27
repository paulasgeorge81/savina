-module(banking_await).
-export([run/0, teller/3, account/2, print_config/0]).

-define(A, 1000).    % Number of accounts
-define(N, 50000).   % Number of transactions
-define(INITIAL_BALANCE, (1.7976931348623157e+308 / (?A * ?N))).
-define(AMOUNT_LIMIT, 1000).

run() ->
    Master = spawn(?MODULE, teller, [?A, ?N, self()]),
    Master ! start,
    receive 
        done -> io:format("Benchmark completed.~n") 
    end.

teller(NumAccounts, NumTransactions, Parent) ->
    Accounts = maps:from_list([{I, spawn(?MODULE, account, [I, ?INITIAL_BALANCE])} || I <- lists:seq(1, NumAccounts)]),
    process_transactions(NumTransactions, Accounts, 0, pseudo_random:new(123456)),
    maps:foreach(fun(_, Acc) -> Acc ! stop end, Accounts),
    Parent ! done.

process_transactions(0, _Accounts, Completed, _RandState) ->
    io:format("Completed transactions: ~p~n", [Completed]);
process_transactions(Num, Accounts, Completed, RandState) ->
    {SrcId, RandState1} = pseudo_random:next_int((map_size(Accounts) div 10) * 8, RandState),
    {LoopIdRaw, RandState2} = pseudo_random:next_int(map_size(Accounts) - SrcId, RandState1),
    LoopId = max(1, LoopIdRaw),
    DestId = SrcId + LoopId,
    {Amount, RandState3} = pseudo_random:next_double(RandState2),
    ScaledAmount = Amount * ?AMOUNT_LIMIT,

    maps:get(SrcId, Accounts) ! {credit, ScaledAmount, maps:get(DestId, Accounts), self()},
    receive reply -> 
        process_transactions(Num - 1, Accounts, Completed + 1, RandState3) 
    end.

account(Id, Balance) ->
    receive
        {credit, Amount, DestAccount, Sender} ->
            DestAccount ! {debit, Amount, self()},
            receive reply -> Sender ! reply end,
            account(Id, Balance - Amount);
        {debit, Amount, Sender} ->
            Sender ! reply,
            account(Id, Balance + Amount);
        stop -> ok
    end.

print_config() ->
    io:format("    A (num accounts) = ~p~n", [?A]),
    io:format("    N (num transactions) = ~p~n", [?N]),
    io:format("    Initial Balance = ~p~n", [?INITIAL_BALANCE]).
