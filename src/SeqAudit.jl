module SeqAudit

export rename_map,
       rename_files,
       airtable_metadata,
       find_raw,
       find_analysis_files

using CSV
using DataFrames
using Chain
using Airtable
using FilePaths
using FilePathsBase: /
using Preferences
using Term
using Term.progress

include("preferences.jl")
include("renaming.jl")
include("audit.jl")
include("metadata.jl")

end # module