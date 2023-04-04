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
using Preferences

include("preferences.jl")
include("renaming.jl")
include("audit.jl")
include("metadata.jl")

end # module