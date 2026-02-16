module BioBakery

include("types.jl")
export  RawSequenceInputs,
        KneadDataConfig,
        PrefetchConfig
        has_pair,
        has_orphan,
        canonical_prefix,
        single_prefix

include("detect.jl")
export  detect_raw_inputs

include("run_kneaddata.jl")
export  run_kneaddata

include("cat_kneads.jl")
export  cat_kneads

include("run_metaphlan.jl")
export  run_metaphlan

include("run_humann_main.jl")
export  run_humann_main

include("run_humann_regroup_rename.jl")
export  run_humann_regroup_rename

end # module BioBakery