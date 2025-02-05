-module(power_benchmark).
-export([measure_power/2, power_logger/1, log_idle_power/0]).

% Measure power for a given number of iterations
measure_power(Fun, Iterations) ->
    % Log idle power consumption before benchmarking
    log_idle_power(),
    
    % Wait until idle power is captured before starting benchmark
    confirm_idle_logging(),

    % Using list comprehension to iterate over the specified number of iterations
    _ = [
        measure_time(fun() -> 
            run(Fun) % Call the function you want to benchmark
        end) || _ <- lists:seq(1, Iterations)].

% Function to measure time and log the result
measure_time(Fun) ->
    StartTime = erlang:monotonic_time(millisecond),
    Fun(),
    EndTime = erlang:monotonic_time(millisecond),
    io:format("Completed in ~p ms~n", [EndTime - StartTime]).

% Function that will run the benchmark function and log power data
run(Fun) ->
    % Start power logging process, pass the filename where powermetrics will log directly
    File = "power_benchmark.log",
    Pid = spawn(fun() -> power_logger(File) end),
    Pid ! start,

    % Execute the benchmark function directly (without spawning a new process)
    Start = erlang:monotonic_time(millisecond),
    Fun(),
    End = erlang:monotonic_time(millisecond),

    % Stop the power logger after function execution
    Pid ! stop,

    % Log the completion time for this iteration
    io:format("Iteration completed in ~p ms~n", [End - Start]).

% Continuously logs power usage using powermetrics until it receives 'stop'
power_logger(File) ->
    receive
        stop -> 
            io:format("Power logger stopping...\n"),
            ok;
        start -> 
            % Log power samples directly to the file using powermetrics
            log_power(File),
            timer:sleep(500),
            power_logger(File);
        _ -> power_logger(File)
    end.

% Logs idle power for 5 samples before starting benchmark
log_idle_power() ->
    IdleLogFile = "idle_power.log",
    PowerMetricsCmd = "sudo powermetrics -s cpu_power -n 5 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | grep -i \"Intel energy model derived CPU core power\" | while read line; do echo \"$(date '+%Y-%m-%d %H:%M:%S') $line\" >> " ++ IdleLogFile ++ "; done",
    os:cmd(PowerMetricsCmd),
    timer:sleep(5000),  % Give time to capture idle power samples
    IdleLogFile.

% Confirm that idle power logging has at least 5 samples before proceeding
confirm_idle_logging() ->
    IdleLogFile = "idle_power.log",
    {ok, Data} = file:read_file(IdleLogFile),
    Lines = length(string:split(binary_to_list(Data), "\n", all)),
    case Lines >= 5 of
        true -> ok;
        false ->
            io:format("Warning: Idle power samples may not be sufficient. Proceeding anyway.\n")
    end.

% Function to log power sample using powermetrics tool and append to the log file
log_power(File) ->
    Command = "sudo powermetrics -s cpu_power -n 1 -i 1000 -a 0 --hide-cpu-duty-cycle --show-extra-power-info | grep -i \"Intel energy model derived CPU core power\" | while read line; do echo \"$(date '+%Y-%m-%d %H:%M:%S') $line\" >> " ++ File ++ "; done",
    os:cmd(Command).


