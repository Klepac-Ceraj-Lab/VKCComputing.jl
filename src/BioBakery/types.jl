struct RawSequenceInputs
    paired_r1::Union{Nothing,String}
    paired_r2::Union{Nothing,String}
    unpaired::Union{Nothing,String}
end

struct KneadDataOutputs
    prun_paired_r1::Union{Nothing,String}
    prun_paired_r2::Union{Nothing,String}
    prun_unpaired_r1::Union{Nothing,String}
    prun_unpaired_r2::Union{Nothing,String}
    srun_unpaired::Union{Nothing,String}
end

Base.@kwdef struct PrefetchConfig
    fasterq_dump_execline::Cmd = `docker run -it --user=1015 -v /Processing:/Processing -v /Databases:/Databases -v /vassar:/vassar -v /murray:/murray --rm ghcr.io/klepac-ceraj-lab/bzip2:latest fasterq-dump`
    n_threads::Int = 10
    split_strat::String = "--split-3"
end

Base.@kwdef struct KneadDataConfig
    kd_execline::Cmd = `docker run -it --user=1015 -v /Processing:/Processing -v /Databases:/Databases -v /vassar:/vassar -v /murray:/murray --rm ghcr.io/klepac-ceraj-lab/kneaddata-012:latest kneaddata`
    hg_db_dir::String = "/Databases/kneaddata/hg37dec_v0.1"
    n_threads::Int = 10
    n_processes::Int = 2
    trimmomatic_path::String = "/opt/conda/bin"
end

has_pair(x::RawSequenceInputs) = (x.paired_r1 !== nothing) && (x.paired_r2 !== nothing)
has_orphan(x::RawSequenceInputs) = (x.unpaired !== nothing)

canonical_prefix(sample::AbstractString) = "$(sample)_kneaddata"
single_prefix(sample::AbstractString)    = "$(sample)_kneaddata_single"