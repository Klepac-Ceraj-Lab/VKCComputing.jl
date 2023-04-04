function load_raw_humann(; kind="genefamilies", overwrite=false, names=false, stratified=false, sample_filter=nothing)
    fname = joinpath(scratchfiles("genefunctions"), "$kind.arrow")
    @debug "writing to $fname"
    (!isfile(fname) || overwrite) && write_gfs_arrow(; kind, names, stratified, sample_filter)
    read_gfs_arrow(; kind)
end

function write_gfs_arrow(; kind="genefamilies", names=false, stratified=false, sample_filter=nothing)
    root = analysisfiles("humann", names ? "rename" : 
                                    kind == "genefamilies" ? "main" : "regroup"
    )
    stripper = "_$kind" * (names ? "_rename.tsv" : ".tsv")
    filt = Regex(string(raw"FG\d+_S\d+_", kind))
    df = DataFrame(file = filter(f-> contains(f, filt), readdir(root, join=true)))
    df.sample = map(s-> replace(s, stripper => ""), basename.(df.file))
    isnothing(sample_filter) || subset!(df, "sample"=> ByRow(s-> s in sample_filter))
    df.sample_base = map(s-> replace(stripper, r"_S\d+"=>""), df.sample)
    @debug "Found $(nrow(df)) files"

    knead = load(ReadCounts())
    leftjoin!(df, select(knead, "sample_uid"=>"sample", 
                                AsTable(["final pair1", "final pair2"])=> ByRow(row-> row[1]+row[2]) =>"read_depth");
                            on="sample"
    )
    
    @info "getting features"
    features = mapreduce(union, eachrow(df)) do row
        fs = CSV.read(row.file, DataFrame; header=["feature", "value"], skipto=2, select=[1])[!,1]
        stratified || filter!(f->!contains(f, '|'), fs) # skip stratified features
        Set(fs)
    end
    featuremap = Dict(f=> i for (i,f) in enumerate(features))
    
    scratch = scratchfiles("genefunctions")
    isdir(scratch) || mkpath(scratch)

    @info "writing arrow file"
    open(joinpath(scratch, "$kind.arrow"), "w") do io
        tbls = Tables.partitioner(eachrow(df)) do row
            @debug "writing $(row.sample)"

            sdf = CSV.read(row.file, DataFrame; header=["feature", "value"], skipto=2)
            stratified || subset!(sdf, "feature"=> ByRow(f-> !contains(f, '|'))) # skip stratified features
            sdf.sample .= row.sample
            sdf.sidx .= rownumber(row)
            sdf.fidx = ThreadsX.map(f-> featuremap[f], sdf.feature)

            sdf
        end

        Arrow.write(io, tbls; metadata=("features" => join(features, '\n'), 
                                        "samples"  => join(df.sample, '\n'),
                                        "files"    => join(df.file, '\n'),
                                        "reads"    => join(df.read_depth, '\n')
                                        )
        )                                
    end


    return nothing
end

function read_gfs_arrow(; kind="genefamilies")
    @info "reading table"
    tbl = Arrow.Table(scratchfiles("genefunctions", "$kind.arrow"))
    @info "building sparse mat"
    mat = sparse(tbl.fidx, tbl.sidx, tbl.value)
    mdt =  Arrow.getmetadata(tbl)

    @info "getting features"
    fs = [genefunction(line) for line in eachline(IOBuffer(mdt["features"]))]
    @info "getting samples"
    mdt = DataFrame(
        sample = [MicrobiomeSample(line) for line in eachline(IOBuffer(mdt["samples"]))],
        read_depth = map(l-> l=="missing" ? missing : parse(Float64, l), eachline(IOBuffer(mdt["reads"]))),
        file = readlines(IOBuffer(mdt["files"]))
    )
    mdt.sample_base = replace.(name.(mdt.sample), r"_S\d+" => "")
    comm = CommunityProfile(mat, fs, mdt.sample)
    set!(comm, mdt)
    return comm
end

