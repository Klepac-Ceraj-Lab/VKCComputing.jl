module VKCComputing

# Airtable interfase
export VCKAirtable,
       vkctable,
       nested_metadata,
       tabular_metadata,
       update_airtable_metadata!
       

export rename_map,
       rename_files,
       airtable_metadata,
       find_raw,
       find_analysis_files,
       set_logs!

using CSV
using DataFrames
using JSON3
using Chain
using ThreadsX
using Airtable
using Preferences
using Dates
using TimeZones

using ProgressLogging
using MiniLoggers
using LoggingExtras


include("cli.jl")
include("preferences.jl")
include("renaming.jl")
include("audit.jl")
include("metadata.jl")

end # module