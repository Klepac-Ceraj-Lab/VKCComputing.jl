using VKCComputing
# using Preferences
using CSV
using DataFrames
using Airtable
using Chain

VKCComputing.set_default_preferences!()
VKCComputing.set_airtable_dir!("/brewster/guilherme/scratch")

# Grab the stuff from airtable ans save it to local JSON files (will update after a certain time)
base = LocalBase(; update = true)

analysis_files = sort(get_analysis_files(), :file)

transform!(analysis_files, AsTable(["file", "sample", "suffix"]) => ByRow(row-> begin
    if !ismissing(row.sample)
        return row
    else
        m = match(r"(SEQ\d+)_(.+)", row.file)
        isnothing(m) && error("$(row.file) doesn't match")
        return (; file = row.file, sample = m[1], suffix= m[2])
    end

end) => ["file", "sample", "suffix"])


@chain analysis_files begin
    groupby("sample")
    transform!("s_well"=> (s-> fill(s[findfirst(!ismissing, s)], length(s))) => "s_well")
end

for row in eachrow(analysis_files)
    contains(row.file, r"_S\d{1,2}_?") && continue
    oldpath = joinpath(row.dir, row.file)
    newpath = joinpath(row.dir, string(row.sample, "_", row.s_well, "_", row.suffix))
    @info "moving $oldpath to $newpath"
    mv(oldpath, newpath)
end

#-

notseq = subset(analysis_files, "sample"=> ByRow(s-> !startswith(s, "S")))
notseq.seqpreps = get.(base["Biospecimens"][notseq.sample], :seqprep, missing)

@assert count(s-> length(s) > 1, notseq.seqpreps) == 0

notseq.seqprep = get.(base[first.(notseq.seqpreps)], :uid, missing)

let havefiles = Set(analysis_files.file)
    transform!(notseq, AsTable(["file", "sample", "seqprep"]) => ByRow(row-> begin
        seqfile = replace(row.file, row.sample => row.seqprep)
        return seqfile ∈ havefiles   
    end) => "have_seqfile")

end

@assert count(.!notseq.have_seqfile) == 0
foreach(row-> rm(joinpath(row.dir, row.file)), eachrow(notseq))

#-

## Things should be better now

new_analysis_files = sort(get_analysis_files(), :file)
@assert size(new_analysis_files) == size(dropmissing(new_analysis_files))

@assert all(s-> startswith(s, "SEQ"), new_analysis_files.file)
