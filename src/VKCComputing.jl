module VKCComputing

using CSV
using DataFrames
using JSON3
using Chain
using ThreadsX
using Airtable
using Preferences
using Dates
using ArgParse
using TimeZones
using Dictionaries
using TestItems

include("BioBakery/BioBakery.jl")
using .BioBakery

# airtable
include("airtable_interface.jl")
export  LocalBase,
        vkcairtable,
        localairtable,
        uids

# records
include("record_ops.jl")
export  resolve_links,
        biospecimens,
        seqpreps,
        subjects

# files
include("file_interface.jl")
export  get_analysis_files,
        audit_analysis_files,
        audit_tools,
        append_file!

# reporting
include("reporting.jl")
export  compare_remote_local,
        audit_report,
        report_problems,
        ptable2string

# sample handling
include("samples.jl")
export  ECHOVisitID,
        subjectid,
        timepointid,
        visitmetadata

# SRA
include("sra_interface.jl")
export  fasterq_dump

# AWS
include("aws.jl")
export  aws_ls

# include("preferences.jl")

@testitem "Placeholder" tags = [:tag1, :tag2] begin
    @test true
end

end # module VKCComputing