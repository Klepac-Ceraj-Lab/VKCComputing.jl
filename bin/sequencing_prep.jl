using ArgParse
using DataFrames
using CSV
using QuickMenus
using VKCComputing
using Airtable

function parse_commandline(args)
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--input", "-i"
            help = "File with biospecimen IDs to be included."
            default = "./biospecimens.txt"
        "--directory", "-d"
            help = "Directory for output files"
            default = "./"
        "--prefix"
            help = "Prefix to add to output files. Default is to use 'prep' and 'submission'"
            default = ""
        "--sequencing-type"
            help = "One of 'mgx' (default) or 'amplicon'"
            default = "mgx"
        "--facility"
            help = "One of 'IMR' (default) or 'SeqCenter'"
            default = "IMR"
        "--update-airtable"
            action=:store_true
        "--batch", "-b"
            help = "If sequencing batch already exists, upate it rather than making a new one"
            default=""
        # "--flag1"
        #     help = "an option without argument, i.e. a flag"
        #     action = :store_true
        # "arg1"
        #     help = "a positional argument"
        #     required = true
    end

    return parse_args(args, s)
end



function main(args)
    args = parse_commandline(args)
    base = LocalBase(; update=args["update-airtable"])
    biosp = readlines(args["input"])
    resp1 = qm(["yes", "no"]; message="Build submission for $(args["sequencing-type"]) at $(args["facility"])?")
    if resp1 == "no"
        @warn "Use the '--sequencing-type' or '--facility' arguments to get the correct values"
        @errok "Aborting!"
        return 1
    end
    @info "File contains $(length(biosp)) samples, eg $(first(biosp, min(5, length(biosp))))"
    resp2 = qm(["yes", "no"]; message="Process $(length(biosp)) samples?")
    if resp2 == "no"
        @warn "Inocorrect number of samples (user input)"
        @error "Aborting!"
        return 1
    end

    biosp_records = [get(base["Biospecimens"], b, missing) for b in biosp] 
    missing_biosp = findall(ismissing, biosp_records)
    if length(missing_biosp) > 0
        @error """
        Some biospecimens ($(length(missing_biosp))) do not exist in airtable.
        If you think this is wrong, try running with `--update-airtable`
        to update your local copy of the database.

        See: $(biosp[missing_biosp])
        """
        return 1
    end

    if isempty(args["batch"])
        resp3 = qm(["yes", "no"]; message="Really create new sequencing batch (airtable will be updated)?")
        if resp3 == "no"
            @warn "Use the '--batch' argument to specify an existing batch"
            @error "Aborting!"
            return 1
        end
        @info "Updating airtable"
        
        A 

    
end


main()
