using SeqAudit
using Airtable
using DataFrames

base = AirBase("appSWOVVdqAi5aT5u")
stab = AirTable("Samples", base)
ptab = AirTable("Project", base)
mgxtab = AirTable("MGX Batches", base)


recs = Airtable.query(stab; filterByFormula="{Project} = 'ECHO'")

sids = [rec[:sample] for rec in recs if haskey(rec, Symbol("MGX Batches")) && first(rec[Symbol("MGX Batches")]) != "reco4VTTv6UsCRida"]
#-

filedf = DataFrame(find_analysis_files("/lovelace/sequncing/processed/mgx", sids))

inc = subset(filedf, :status=> ByRow(!=(:complete)))
sort!(inc, :sample)

transform!(inc, :metaphlan=>ByRow(length)=>:metaphlan_count, :humann=> ByRow(length)=>:humann_count, :kneaddata=>ByRow(length)=> :kneaddata_count)

mis = subset(inc, :status=> ByRow(==(:notfound)))