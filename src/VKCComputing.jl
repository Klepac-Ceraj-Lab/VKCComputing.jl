module VKCComputing

# airtable
export LocalBase,
       vkcairtable,
       localairtable,
       uids

# records
export resolve_links,
       biospecimens,
       seqpreps,
       subjects

# files
export get_analysis_files,
       audit_analysis_files,
       compare_remote_local,
       audit_report

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
using TestItems


include("preferences.jl")
include("airtable_interface.jl")
include("record_ops.jl")
include("file_interface.jl")

@testitem "Placeholder" tags = [:tag1, :tag2] begin
    @test true
end

end # module