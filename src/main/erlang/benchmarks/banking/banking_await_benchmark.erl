-module(banking_await_benchmark).
-export([run/0, teller/5, account/2, print_config/0]).

-define(A, 1000).    % Number of accounts
-define(N, 50_000).   % Number of transactions
-define(INITIAL_BALANCE, (1.7976931348623157e+308 / (?A * ?N))).

run() ->
    Main = self(),
    Master = spawn(?MODULE, teller, [?A, ?N, 0, pseudo_random:new(123456), Main]),
    Master ! start,
    receive 
        done -> 
            ok
    end.

teller(NumAccounts, NumTransactions, CompletedTransactions, RandState, Main) ->
    Accounts = maps:from_list([{I, spawn(?MODULE, account, [I, ?INITIAL_BALANCE])} || I <- lists:seq(0, NumAccounts - 1)]),
    receive
      start ->
        generate_work(RandState, NumTransactions, Accounts, self()),
        loop(NumTransactions, CompletedTransactions, Accounts, Main)
    end.

loop(NumTransactions, CompletedTransactions, Accounts, Main) ->
    receive
        reply ->
            NewCompletedTransactions = CompletedTransactions + 1,
            case NewCompletedTransactions =:= NumTransactions of
                true ->
                    maps:foreach(fun(_, Acc) -> Acc ! stop end, Accounts),
                    Main ! done;
                false ->
                    loop(NumTransactions, NewCompletedTransactions, Accounts, Main)
            end
    end.


generate_work(_, 0, _, _) ->
    ok;
generate_work(RandState, NumTransactions, Accounts, Teller) ->
    {SrcAccId, RandState1} = pseudo_random:next_int((maps:size(Accounts) div 10) * 8, RandState),
    {LoopIdRaw, RandState2} = pseudo_random:next_int(map_size(Accounts) - SrcAccId, RandState1),
    LoopId = max(1, LoopIdRaw),
    DestId = SrcAccId + LoopId,
   
    {SrcAcc, DestAcc}  = {maps:get(SrcAccId, Accounts), maps:get(DestId, Accounts)},
    {Amount, RandState3} = pseudo_random:next_double(RandState2),
    ScaledAmount = abs(Amount) * 1000,
    SrcAcc ! {credit, ScaledAmount, DestAcc, Teller},
    generate_work(RandState3, NumTransactions - 1, Accounts, Teller).


account(Id, Balance) ->
    receive
        {credit, Amount, DestAccount, Sender} ->
            DestAccount ! {debit, Amount, self()},
            receive 
                reply -> 
                    Sender ! reply 
            end,
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
