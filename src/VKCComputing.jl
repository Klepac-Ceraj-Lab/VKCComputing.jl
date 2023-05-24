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
using TestItems


include("preferences.jl")
include("airtable_interface.jl")

@testitem "Placeholder" tags = [:tag1, :tag2] begin
    @test true
end

end # module