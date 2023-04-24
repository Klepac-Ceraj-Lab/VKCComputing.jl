#!/usr/bin/env julia

using VKCComputing
using Comonicon
using DataFrames



"""
Audit raw sequencing files

# Args

- `sequence_folder`: Folder containing raw sequencing files

# Flags

- `-v, --verbose`: Set logging level to INFO
- `-q, --quiet`: Silences logs sent to the terminal.
- `--debug`: Set logging level to DEBUG. Over-rides --verbose

# Options

- `--ids`: File containing a list of sequence ids (one per line). If not provided, script will attempt to check everything in airtable.
- `-l, --log`: Log to file. May be used in combination with --quiet to log ONLY to file

"""
@main function audit_raw(sequence_folder; ids = nothing, log = nothing, verbose::Bool = false, quiet::Bool = false, debug::Bool = false)
    set_logs!(; log, verbose, quiet, debug)

    if isnothing(ids)
        meta = airtable_metadata()
        subset!(meta, :Mgx_batch=>ByRow(!ismissing))
        ids = meta.sample
    else
        ids = readlines(ids)
    end

    @debug ids

    find_raw(sequence_folder, ids)
end
