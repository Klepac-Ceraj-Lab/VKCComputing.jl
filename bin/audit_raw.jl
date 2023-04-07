using ArgParse
using MiniLoggers
using LoggingExtras

using VKCComputing
using VKCComputingCLI
using DataFrames

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "sequence_folder"
            help = "Folder containing raw sequencing files"
            required = true
        "--ids"
            help = """
                   File containing a list of sequence ids (one per line).
                   If not provided, script will attempt to check everything in airtable.
                   """

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

    find_raw(args["sequence_folder"], ids)
end

main()