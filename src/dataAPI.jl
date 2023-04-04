abstract type AbstractDataset end

struct Metadata <: AbstractDataset end
struct ReadCounts <: AbstractDataset end
struct TaxonomicProfiles <: AbstractDataset end
struct FunctionalProfiles <: AbstractDataset end

load(ds::Dataset; kwargs...) = throw(MethodError("load has not been implemented for $(typeof(ds))"))

