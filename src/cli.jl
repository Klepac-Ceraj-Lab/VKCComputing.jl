"""
    set_logs!([; log, verbose, quiet, debug])

The default log-level for scripts is `Warn`,
and has only printing to the console.
Use command-line arguments to set different behavior.

- `"debug"`: Bool - whether to set minimm log level to `Debug`.
- `"verbose"`: Bool - whether to set the minimum log level to `Info`.
- `"log"`: String - file path for writing log outputs
- `"quiet"`: Bool - disable logging to the console.
    Note that this is compatible with setting annother log level for writing to a file.
    For example, one can set `--verbose --quiet --log script.log` to write all `Info`+
    logs to a file, with no terminal output.
"""
function set_logs!(; log = nothing, verbose = false, quiet = false, debug = false)
    if debug
        term_logger = MiniLogger(minlevel=MiniLoggers.Debug)
    elseif verbose
        term_logger = MiniLogger(minlevel=MiniLoggers.Info)
    else
        term_logger = MiniLogger(minlevel=MiniLoggers.Warn)
    end

    if !isnothing(log)
        if quiet
            global_logger(MiniLogger(minlevel=term_logger.minlevel, io=log))
        else
            global_logger(TeeLogger(
                    term_logger,
                    MiniLogger(minlevel=term_logger.minlevel, io=log)
                    )
            )
        end
    else
        if quiet
            global_logger(MiniLogger(MiniLoggers.Error))
        else
            global_logger(term_logger)
        end
    end 
end