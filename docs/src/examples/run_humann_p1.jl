using VKCComputing
# using Preferences
using CSV
using DataFrames
using Airtable
using Chain
using BiobakeryUtils
using Dates

# Grab the stuff from airtable ans save it to local JSON files (will update after a certain time)
base = LocalBase()

analysis_files = sort(get_analysis_files(), :file)

## Things should be better now

@assert size(analysis_files) == size(dropmissing(analysis_files))

@assert all(s-> startswith(s, "SEQ"), analysis_files.file)

#-
sample_groups = groupby(analysis_files, "sample")

completion = combine(sample_groups,
    "s_well"=> (s-> first(s)) => "s_well",
    "suffix"=> (suffix-> "kneaddata.log" in suffix)     => "has_kneaddata",
    "suffix"=> (suffix-> "profile.tsv" in suffix)       => "has_taxprofile",
    "suffix"=> (suffix-> "bowtie2.tsv" in suffix)       => "has_bowtie2",
    "suffix"=> (suffix-> ".sam.bz2" in suffix)          => "has_sam",
    "suffix"=> (suffix-> "genefamilies.tsv" in suffix)  => "has_genefamilies",
    "suffix"=> (suffix-> "pathabundance.tsv" in suffix) => "has_pathabundance",
    "suffix"=> (suffix-> "pathcoverage.tsv" in suffix)  => "has_pathcoverage",
    "suffix"=> (suffix-> "ecs.tsv" in suffix)           => "has_ecs",
    "suffix"=> (suffix-> "kos.tsv" in suffix)           => "has_kos",
    "suffix"=> (suffix-> "pfams.tsv" in suffix)         => "has_pfams",
    "suffix"=> (suffix-> "ecs_rename.tsv" in suffix)    => "has_ecs_rename",
    "suffix"=> (suffix-> "kos_rename.tsv" in suffix)    => "has_kos_rename",
    "suffix"=> (suffix-> "pfams_rename.tsv" in suffix)  => "has_pfams_rename",
)

transform!(completion,
    AsTable([
        "has_taxprofile",
        "has_bowtie2",
        "has_sam",
]) => ByRow(all) => "metaphlan_complete")

transform!(completion,
    AsTable([
        "has_genefamilies", 
        "has_pathabundance", 
        "has_pathcoverage", 
    ]) => ByRow(all) => "humann_basic_complete"
)

transform!(completion, 
    AsTable([
        "has_ecs", 
        "has_kos", 
        "has_pfams", 
        "has_ecs_rename", 
        "has_kos_rename", 
        "has_pfams_rename"
    ]) => ByRow(all) => "humann_grprn_complete"
)

needshumann = subset(completion, AsTable(["has_taxprofile", "has_kneaddata", "humann_basic_complete"]) => ByRow(!all))
needshumann.khula = map(needshumann.sample) do seq
    srecord = base["SequencingPrep"][seq]
    proj = get(srecord, :project, missing)
    return ismissing(proj) ? false : get(first(base[proj]), :uid, "") == "khula"
end

subset!(needshumann, "khula"=> identity)
subset!(needshumann, "has_kneaddata"=> identity)
subset!(needshumann, "sample"=> ByRow(s-> begin
    rec = base["SequencingPrep"][s]
    get(rec, :keep, 1) == 1
end))

open("need_humann.txt", "w") do io
    for s in needshumann.sample
        println(io, s)
    end
end

glist = Set(readlines("manifest_missing_samples.dat"))

# file path = /brewster/kevin/khula_data/

newprep = VKCComputing.get_analysis_files("/brewster/kevin/khula_data")

transform!(groupby(newprep, "sample"), AsTable(["sample", "suffix"]) => (nt-> begin
    has_mp = "profile.tsv" ∈ nt.suffix
    has_kd = count(f-> !ismissing(f) && contains(f, r"kneaddata.+\.fastq\.gz$"), nt.suffix) == 4
    fill(all([has_mp, has_kd]), length(nt.sample))
end) => "ready")

scratchdir = "/brewster/guilherme/scratch/humann_outs"
isdir(scratchdir) || mkdir(scratchdir)

@show count(combine(groupby(subset(newprep, "ready"=> identity, "sample"=> ByRow(s-> s ∈ glist)), "sample"), "ready"=> all).ready_all)
# humann --input $catkneads --taxonomic-profile $profile --output ./ \
#     --threads ${task.cpus} --remove-temp-output --search-mode uniref90 \
#     --output-basename $sample

for sample in groupby(subset(newprep, "ready"=> identity, "sample"=> ByRow(s-> s ∈ glist)), "sample")[1:50]
    seq = first(sample.sample)
    s_well = first(sample.s_well)
    seqname = string(seq, "_", s_well)
    
    mpidx = findfirst(p-> contains(p, "profile"), sample.file)
    kdidx = findall(f-> contains(f, "kneaddata"), sample.file)
    mp_path = joinpath(sample[mpidx, "dir"], sample[mpidx, "file"])
    kd_paths = joinpath.(sample[kdidx, "dir"], sample[kdidx, "file"])

    @info "Running sample $(seqname) start time: Dates.now()" 

    cat_path = joinpath(scratchdir, "$(seqname)_catkneads.fastq.gz")

    if !isfile(cat_path)
        run(pipeline(`cat $kd_paths`; stdout = cat_path))
    end

    if !isfile(joinpath(scratchdir, "$(seqname)_genefamilies.tsv"))
        humann(cat_path, scratchdir; 
            taxonomic_profile=mp_path, 
            threads=28,
            remove_temp_output=true,
            search_mode="uniref90",
            output_basename = seqname
        )
    end

end