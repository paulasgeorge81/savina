-module(conc_dict_benchmark).
-export([run/0, master/4, worker/4, dictionary/1, print_config/0]).

-define(NUM_ENTITIES, 20).
-define(NUM_MSGS_PER_WORKER, 10000).
-define(WRITE_PERCENTAGE, 10).
-define(DATA_LIMIT, 524287).

run() ->
    Parent = self(),
    Master = spawn(?MODULE, master, [Parent,?NUM_ENTITIES, ?NUM_MSGS_PER_WORKER, 0]),
    Master ! do_work,
    receive
      done -> ok
    end.

master(Parent, NumWorkers, NumMessagesPerWorker, NumWorkersTerminated) ->
    Master = self(),
    Map = lists:foldl(fun(K, Acc) -> maps:put(K, K, Acc) end, #{}, lists:seq(0, ?DATA_LIMIT - 1)),
    Dictionary = spawn(?MODULE, dictionary, [Map]),
    Workers = [spawn(?MODULE, worker, [Master, Dictionary, Id, NumMessagesPerWorker])
               || Id <- lists:seq(1, NumWorkers)],
   
    [Worker ! do_work || Worker <- Workers],
    
    receive
        end_work ->
            NewNumWorkersTerminated = NumWorkersTerminated + 1,
            case NumWorkersTerminated =:= NumWorkers of
                true ->
                    Dictionary ! {end_work, Parent};
                false ->
                    master(Parent, NumWorkers, NumMessagesPerWorker, NewNumWorkersTerminated)
            end
    end.

worker(Master, _Dictionary, _Id, 0) ->
    Master ! end_work;
worker(Master, Dictionary, Id, NumMessagesPerWorker) ->
    rand:seed(exsplus, {Id * 37, NumMessagesPerWorker * 53, ?WRITE_PERCENTAGE * 17}),
    receive
        _ -> 
            RandInt = rand:uniform(100),
            Key = rand:uniform(?DATA_LIMIT) rem ?DATA_LIMIT,
            Value = rand:uniform(?DATA_LIMIT),
            if
                RandInt =< ?WRITE_PERCENTAGE ->
                    Dictionary ! {write_msg, self(), Key, Value};
                true ->
                    Dictionary ! {read_msg, self(), Key}
            end,
            worker(Master, Dictionary, Id, NumMessagesPerWorker - 1)
    end.

dictionary(DataMap) ->
    receive
        {write_msg, Sender, Key, Value} ->
            NewMap = maps:put(Key, Value, DataMap),
            Sender ! {result_msg, self(), Value},
            dictionary(NewMap);
        
        {read_msg, Sender, Key} ->
            Value = maps:get(Key, DataMap, undefined),
            Sender ! {result_msg, self(), Value},
            dictionary(DataMap);

        {end_work, Parent} ->
            Parent ! done,
            io:format("Dictionary size = ~p~n", [maps:size(DataMap)])
    end.

print_config() ->
    io:format("    Num Entities = ~p~n",[?NUM_ENTITIES]),
    io:format("    Message/Worker = ~p~n",[?NUM_MSGS_PER_WORKER]),
    io:format("    Write Percent = ~p~n",[?WRITE_PERCENTAGE]).
