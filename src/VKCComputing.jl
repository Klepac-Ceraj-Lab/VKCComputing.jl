module VKCComputing

# Airtable interfase
export VCKAirtable,
       vkctable,
       nested_metadata,
       tabular_metadata,
       update_airtable_metadata!
       

export rename_map,
       rename_files,
       filepicker,
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

using REPL
using ProgressLogging
using MiniLoggers
using LoggingExtras


include("preferences.jl")
include("metadata.jl")
include("dataAPI.jl")

include("files.jl")

include("cli.jl")
include("audit.jl")
include("renaming.jl")

end # module