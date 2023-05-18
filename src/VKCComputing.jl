module VKCComputing

# airtable
export LocalBase,
       vkcairtable,
       localairtable,
       uids

using CSV
using DataFrames
using JSON3
using Chain
using ThreadsX
using Airtable
using Preferences
using Dates
using TimeZones
using Dictionaries


include("preferences.jl")
include("airtable_interface.jl")


end # module