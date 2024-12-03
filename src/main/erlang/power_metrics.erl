-module(power_metrics).
-export([run_power_metrics/0]).

run_power_metrics() ->
    % Command setup to run powermetrics
    Cmd = "sudo /usr/bin/powermetrics -i 1000 -s all -a 10 -n 5",

    % Open a log file to capture output
    case file:open("power_metrics.log", [write]) of
        {ok, LogFile} ->
            % Run the command and capture output
            Output = os:cmd(Cmd),

            % Write the output to the log file
            file:write(LogFile, Output),
            file:close(LogFile),
            io:format("Power metrics collected successfully~n");
        {error, Reason} ->
            io:format("Failed to open log file: ~p~n", [Reason])
    end.
