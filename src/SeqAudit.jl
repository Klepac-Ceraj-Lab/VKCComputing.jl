module SeqAudit

export rename_map,
       rename_files,
       airtable_metadata,
       find_raw,
       find_analysis_files

using CSV
using DataFrames
using Airtable
using FilePaths
using FilePathsBase: /

include("renaming.jl")
include("audit.jl")
include("metadata.jl")

end # module