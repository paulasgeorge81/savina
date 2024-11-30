-module(basic_actor).
-export([start/0, loop/0]).

start() ->
    % Spawn the actor process and get its PID
    Pid = spawn(?MODULE, loop, []),
    % Send a message to the process
    Pid ! {self(), "Hello, Erlang!"},
    % Wait for a short time to ensure message processing completes
    timer:sleep(100).

loop() ->
    receive
        {From, Message} ->
            io:format("Received message: ~p~n", [Message]),
            From ! {self(), ok}  % Optional: Send acknowledgment
    end.