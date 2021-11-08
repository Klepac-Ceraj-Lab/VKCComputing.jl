using ArgParse
using MiniLoggers
using LoggingExtras

using SeqAudit
using DataFrames

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "analysis_folder"
            help = "Folder containing analysis batches"
            required = true
        "--ids"
            help = """
                   File containing a list of sequence ids (one per line).
                   If not provided, script will attempt to check everything in airtable.
                   """
        "--metadata"
            help = "Table containing airtable_metadata"
        "--verbose", "-v"
            help = "Set logging level to INFO"
            action = :store_true
        "--quiet", "-q"
            help = "Silences logs sent to the terminal."
            action = :store_true
        "--debug"
            help = "Set logging level to DEBUG. Over-rides --verbose"
            action = :store_true
        "--log", "-l"
            help = "Log to file. May be used in combination with --quiet to log ONLY to file"
    end

    return parse_args(s)
end



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

function main()
    args = parse_commandline()
    set_logs!(args)
    
    if isnothing(get(args, "ids", nothing))
        meta = airtable_metadata()
        subset!(meta, :Mgx_batch=>ByRow(!ismissing))
        ids = meta.sample
    else
        ids = readlines(args["ids"])
    end

    @debug ids

    find_analysis_files(args["analysis_folder"], ids)
end

main()