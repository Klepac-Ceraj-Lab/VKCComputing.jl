abstract type AbstractDataset end

struct Metadata <: AbstractDataset end
struct ReadCounts <: AbstractDataset end
struct TaxonomicProfiles <: AbstractDataset end
struct FunctionalProfiles <: AbstractDataset end

load(ds::AbstractDataset, args...; kwargs...) = throw(MethodError("load has not been implemented for $(typeof(ds))"))

_get_samples(p::String; kwargs...) = _get_samples(Val(Symbol(p)); kwargs...)

function _get_samples(p::Val{T}; force=false, interval=Month(1)) where T
    pmd = nested_metadata("Project"; force, interval)
    return pmd[findfirst(t-> t.fields[:Name] == String(T), pmd)].fields[:Samples]
end

function load(::Metadata, project; force=false, interval=Month(1))
    samples = Set(_get_samples(project; force, interval))
    smd = nested_metadata("Samples"; force, interval)
    return smd[findall(s-> s.id in samples, smd)]
end