-module(pseudo_random).
-export([new/0, new/1, next_long/1, next_int/1, next_double/1, next_int/2]).

% Initialize with a default seed
new() -> new(74755).

new(Value) when is_integer(Value) -> {pseudo_random, Value}.

% Generate the next random long (0-65535)
next_long({pseudo_random, Value}) ->
    NewValue = ((Value * 1309) + 13849) band 65535,
    {NewValue, {pseudo_random, NewValue}}.

% Generate a random integer (0-65535)
next_int(State) ->
    {Value, NewState} = next_long(State),
    {Value, NewState}.

% Generate a random double (0.0 - 1.0)
next_double(State) ->
    {Value, NewState} = next_long(State),
    {1.0 / (Value + 1), NewState}.

% Generate a random integer in range [0, ExclusiveMax)
next_int(ExclusiveMax, State) when ExclusiveMax > 0 ->
    {Value, NewState} = next_int(State),
    {Value rem ExclusiveMax, NewState}.
