using SeqAudit
using Airtable
using DataFrames
using CSV
using Random

base = AirBase("appSWOVVdqAi5aT5u")
stab = AirTable("Samples", base)
ptab = AirTable("Project", base)
mgxtab = AirTable("MGX Batches", base)
bioprojecttab = AirTable("NCBI Bioproject", base)
biosampletab = AirTable("NCBI Biosample", base)
sratab = AirTable("SRA Accession", base)
metabtab = AirTable("Metabolomics Batches", base)

recs = Airtable.query(stab; filterByFormula="{Project} = 'ECHO'")
batches = DataFrame(Airtable.fields(rec) for rec in Airtable.query(mgxtab))
sort!(batches, "Name")


samples = DataFrame()
for rec in recs
    append!(samples, DataFrame([(; id = Airtable.id(rec), Airtable.fields(rec)...)]); cols=:union)
end

rename!(samples, "sid_old" => "sample_name")

sramgx = CSV.read("sra/metadata-8908067-processed-ok.tsv", DataFrame)   
select!(sramgx, ["accession", "study", "bioproject_accession", "biosample_accession", "sample_name"])
sraampl = CSV.read("sra/metadata-9353778-processed-ok.tsv", DataFrame)
sraampl.sample_name .= map(f-> match(r"([CM]\d+_\d+[EF]_\d[A-Z]).+", f).captures[1], sraampl.filename)
select!(sraampl, ["accession", "study", "bioproject_accession", "biosample_accession", "sample_name"])

sraampl = leftjoin(sraampl, 
        unique(select(
            subset(samples, "sample_name" => ByRow(!ismissing)),
                ["sample", "sample_name", "id"]),
            :sample),
        on="sample_name"
)

#-

bioproject = first(Airtable.query(bioprojecttab))
@assert bioproject[:Name] == "PRJNA695570"

current_biosamples = DataFrame(id=String[], Name=String[])
for rec in Airtable.query(biosampletab)
    append!(current_biosamples, DataFrame([(; id = Airtable.id(rec), Airtable.fields(rec)...)]); cols=:union)
end

#- 

sample_topost = NamedTuple[]

for row in eachrow(sraampl)
    biosample = row.biosample_accession
    idx = findfirst(==(biosample), current_biosamples.Name)
    if isnothing(idx)
        sidx = findfirst(sn-> !ismissing(sn) && sn == row.sample_name, samples.sample_name)
        if isnothing(sidx)
            @warn "Didn't find `$(row.sample_name)` in `sid_old`"
            continue
        end
    end
    push!(sample_topost, NamedTuple([:Name=>biosample, :Samples=>[samples[sidx, :id]], Symbol("NCBI Bioproject")=> [Airtable.id(bioproject)]]))
end

recs = Airtable.post!(biosampletab, sample_topost)
append!(current_biosamples, DataFrame([(; id=Airtable.id(rec), Airtable.fields(rec)...) for rec in recs]), cols=:union)

#- 

current_sraacc = DataFrame(id=String[], accession=String[], kind=String[])
for rec in Airtable.query(sratab)
    append!(current_sraacc, DataFrame([(; id = Airtable.id(rec), Airtable.fields(rec)...)]); cols=:union)
end

#-

acc_topost = NamedTuple[]

for row in eachrow(sraampl)
    accession = row.accession
    biosample = row.biosample_accession
    idx = findfirst(==(biosample), current_biosamples.Name)
    if !isnothing(idx)
        sidx = findfirst(bsn-> !ismissing(bsn) && row.biosample_accession == bsn, current_biosamples.Name)
        if isnothing(sidx)
            @warn "Didn't find `$(row.biosample_accession)` in `current_biosamples`"
            continue
        end
        push!(acc_topost, NamedTuple([:accession=>accession, Symbol("NCBI Biosample")=> [current_biosamples[sidx, :id]], :Kind=>"AMPLICON"]))
    end
end

recs = Airtable.post!(sratab, acc_topost)
append!(current_sraacc, DataFrame([(; id=Airtable.id(rec), Airtable.fields(rec)...) for rec in recs]), cols=:union)

#-

acc_topost = NamedTuple[]

for row in eachrow(sramgx)
    accession = row.accession
    biosample = row.biosample_accession
    idx = findfirst(==(biosample), current_biosamples.Name)
    if !isnothing(idx)
        sidx = findfirst(bsn-> !ismissing(bsn) && row.biosample_accession == bsn, current_biosamples.Name)
        if isnothing(sidx)
            @warn "Didn't find `$(row.biosample_accession)` in `current_biosamples`"
            continue
        end
        push!(acc_topost, NamedTuple([:accession=>accession, Symbol("NCBI Biosample")=> [current_biosamples[sidx, :id]], :Kind=>"WGS"]))
    end
end

recs = Airtable.post!(sratab, acc_topost)
append!(current_sraacc, DataFrame([(; id=Airtable.id(rec), Airtable.fields(rec)...) for rec in recs]), cols=:union)
