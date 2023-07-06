using VKCComputing
using Chain
using DataFrames
using Airtable
using Preferences
using ThreadsX

key = Airtable.Credential(load_preference(VKCComputing, "readwrite_pat"))
remote = AirBase("appmYwoXIHlen5s0q")
base = LocalBase(; update=true)

#- 

aws_processed = aws_ls()
transform!(groupby(aws_processed, "seqprep"), 
    "seqprep" => identity=> "sample",
    "seqprep" => (seq -> begin
        ismissing(seq)
    end)
)

#-

local_processed = get_local_processed()

local_problems = subset(local_processed, "suffix" => ByRow(s-> ismissing(s) || s ∉ VKCComputing._good_suffices))
aws_problems = subset(aws_processed, "suffix" => ByRow(s-> ismissing(s) || s ∉ VKCComputing._good_suffices))



remote_seq, local_seq, good_files, problem_files = audit_analysis_files(local_processed; base)

jointdf = leftjoin(
    subset(select(remote_seq, 
            "uid"=>"seqprep", "S_well", "kneaddata"=>"kneaddata_AT", "metaphlan"=>"metaphlan_AT", "humann"=>"humann_AT"),
        AsTable(["seqprep", "S_well"]) => ByRow(row-> !any(ismissing, values(row)))),
    subset(select(local_seq,
            "sample"=>"seqprep", "S_well", "kneaddata_complete"=>"kneaddata_LOC", "metaphlan_complete"=>"metaphlan_LOC", "humann_complete"=>"humann_LOC"),
        AsTable(["seqprep", "S_well"]) => ByRow(row-> !any(ismissing, values(row))));
    on=["seqprep", "S_well"]
)

leftjoin!(jointdf,
    subset(select(audit_tools(subset(aws_processed, "suffix"=> ByRow(!ismissing))), 
            "seqprep", "S_well", "kneaddata_complete"=>"kneaddata_AWS", "metaphlan_complete"=>"metaphlan_AWS", "humann_complete"=>"humann_AWS"),
        AsTable(["seqprep", "S_well"]) => ByRow(row-> !any(ismissing, values(row))));
    on=["seqprep", "S_well"]
)

@info ptable2string(
    subset(combine(jointdf, "seqprep"=> identity => "seqprep",
                    AsTable(r"kneaddata|metaphlan|humann") => ByRow(row-> begin
                        kd = [row.kneaddata_AT, row.kneaddata_LOC, row.kneaddata_AWS]
                        mp = [row.metaphlan_AT, row.metaphlan_LOC, row.metaphlan_AWS]
                        hm = [row.humann_AT, row.humann_LOC, row.humann_AWS]
                        check_kneaddata = !(!any(kd) || all(kd))
                        check_metaphlan = !(!any(mp) || all(mp))
                        check_humann    = !(!any(hm) || all(hm))
                    return (; check_kneaddata, check_metaphlan, check_humann)
                end) => ["check_kneaddata", "check_metaphlan", "check_humann"]),
            AsTable(r"check") => ByRow(any)
    ); show_subheader = false
)
#-


transform!(local_processed, AsTable(["sample", "file"]) => ByRow(row -> begin
    misrec = (;seqid = missing, remote_s = missing)
    s = row.sample
    ismissing(s) && return misrec
    bsp = get(base["Biospecimens"], s, get(base["Biospecimens"], replace(s, "_"=>"-", "-"=>"_"), missing))
    ismissing(bsp) && return misrec
    !haskey(bsp, :seqprep) && return misrec

    seqprep = base[bsp[:seqprep]]
    filter!(s-> haskey(s, :S_well) && contains(row.file, string("_", s[:S_well], "_")), seqprep)
    if length(seqprep) != 1
        return misrec
    else
        seqid = first(seqprep)[:uid]
        remote_s = first(seqprep)[:S_well]
    end
    return (; seqid, remote_s)
end)=> ["seqid", "remote_s"])

existing = Set(skipmissing(local_processed.file))

#-

for row in eachrow(subset(local_processed, "seqid" => ByRow(!ismissing)))
    newfile = replace(row.file, row.sample => row.seqid)

    oldpath = joinpath("s3://vkc-sequencing", row.dir, row.file)
    newpath = joinpath("s3://vkc-sequencing", row.dir, replace(row.file, row.sample => row.seqid))

    if newfile ∈ existing
        @info "removing `$oldpath`"
        cmd = Cmd(["aws", "s3", "rm", oldpath])
        run(cmd)
    else
        @info "`$oldpath` => `$newpath`"
        # cmd = Cmd(["aws", "s3", "mv", oldpath, newpath])
    end
    
end

