module VKCComputing

export rename_map,
       rename_files,
       airtable_metadata,
       find_raw,
       find_analysis_files,
       set_logs!

using CSV
using DataFrames
using Chain
using Airtable
using Preferences

using ProgressLogging
using MiniLoggers
using LoggingExtras


include("cli.jl")
include("preferences.jl")
include("renaming.jl")
include("audit.jl")
include("metadata.jl")

end # module