abstract type AbstractVisitID end

subjectid(vid::AbstractVisitID) = vid.subject
timepointid(vid::AbstractVisitID) = vid.timepoint
visitmetadata(vid::AbstractVisitID) = vid.metadata

struct ECHOVisitID <: AbstractVisitID
    subject::Int
    timepoint::Int
    metadata::NamedTuple
end

function ECHOVisitID(s::AbstractString)
    m = match(r"^(SDM?)(\d+)([A-Z])$", s)
    isnothing(m) && throw(ArgumentError("Expected 'SD{subject}{timepoint}' ID, got $s"))
    # mother or child sample
    mc = m[1] == "SD" ? "C" : "M"
    # subject ID
    sid = parse(Int, m[2])
    # convert letter to number
    tp = findfirst(==(first(m[3])), "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    
    return ECHOVisitID(sid, tp, (; mother_child=mc))
end


