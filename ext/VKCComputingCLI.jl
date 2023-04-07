module VKCDataCLI

using VKCComputing
using Comonicon

export set_logs!

"""
    set_logs!(args)

The default log-level for scripts is `Warn`,
and has only printing to the console.
Use command-line arguments to set different behavior.


## Arguments

The `args` argument should be a dictionary containing keys:

- `"debug"`: Bool - whether to set minimm log level to `Debug`.
- `"verbose"`: Bool - whether to set the minimum log level to `Info`.
- `"log"`: String - file path for writing log outputs
- `"quiet"`: Bool - disable logging to the console.
    Note that this is compatible with setting annother log level for writing to a file.
    For example, one can set `--verbose --quiet --log script.log` to write all `Info`+
    logs to a file, with no terminal output.
"""
function set_logs!(args)
    if args["debug"]
        term_logger = MiniLogger(minlevel=MiniLoggers.Debug)
    elseif args["verbose"]
        term_logger = MiniLogger(minlevel=MiniLoggers.Info)
    else
        term_logger = MiniLogger(minlevel=MiniLoggers.Warn)
    end

    if !isnothing(args["log"])
        if args["quiet"]
            global_logger(MiniLogger(minlevel=term_logger.minlevel, io=args["log"]))
        else
            @warn term_logger.minlevel
            global_logger(TeeLogger(
                    term_logger,
                    MiniLogger(minlevel=term_logger.minlevel, io=args["log"])
                    )
            )
        end
    else
        if args["quiet"]
            global_logger(MiniLogger(MiniLoggers.Error))
        else
            global_logger(term_logger)
        end
    end 
end

end #module