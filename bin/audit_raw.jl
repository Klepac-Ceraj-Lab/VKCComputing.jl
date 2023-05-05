#!/usr/bin/env julia

using VKCComputing
using Comonicon
using DataFrames



"""
Audit raw sequencing files

# Args

- `sequence_folder`: Folder containing raw sequencing files
- `project`: Airtable-based project (eg 'Khula' or 'ECHO') that you are auditing

# Flags

- `-v, --verbose`: Set logging level to INFO
- `-q, --quiet`: Silences logs sent to the terminal.
- `--debug`: Set logging level to DEBUG. Over-rides --verbose
- `-f, --force-update`: Ensure updating of relevant databases

# Options

- `--ids`: File containing a list of sequence ids (one per line). If not provided, script will attempt to check everything in airtable.
- `-l, --log`: Log to file. May be used in combination with --quiet to log ONLY to file

"""
@main function audit_raw(sequence_folder, project; ids = nothing, log = nothing, verbose::Bool = false, quiet::Bool = false, debug::Bool = false, force_update=false)
    set_logs!(; log, verbose, quiet, debug)

    proj_samples = VKCComputing.load(Metadata(), project)
    if isnothing(ids)
        filter!(proj_samples) do s
            fs = s.fields
            haskey(fs, Symbol("MGX Batches"))
        end
    else
        ids = Set(readlines(ids))
        filter!(proj_samples) do s
            fs = s.fields
            fs[:sample] in ids
        end
        found_ids = Set(s.fields[:sample] for s in proj_samples)

        if !isempty(setdiff(ids, found_ids))
            @warn "Mismatch between provided samples and airtable metadata ($(length(ids)) ids provided, $(length(found_ids)) found)."
            @info "Provided IDs with missing samples in airtable: $(setdiff(ids, found_ids))"
        end
    end

    results = find_raw(sequence_folder, Iterators.map(s-> s.fields[:sample], proj_samples))
    @info string(results)
end
