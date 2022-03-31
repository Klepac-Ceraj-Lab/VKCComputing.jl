const keep_meta = [
    :sample,
    :subject,
    :timepoint,
    :ECHOTPCoded,
    :Mother_Child,
    :MaternalID,
    :DOC,
]


"""
    airtable_metadata(key=ENV["AIRTABLE_KEY"])
Get fecal sample metadata table from airtable.
The API `key` comes from https://airtable.com/account.
This is unlikely to work if you're not in the VKC lab,
but published sample metadata is available from OSF.io
using `datadep"sample metadata"`.
"""
function airtable_metadata(key=Airtable.Credential())
    base = AirBase("appSWOVVdqAi5aT5u")
    stab = AirTable("Samples", base)
    ptab = AirTable("Project", base)
    mgxtab = AirTable("MGX Batches", base)
    metabtab = AirTable("Metabolomics Batches", base)

    samples = Airtable.query(stab)
    projects = Airtable.query(ptab)
    mgxbatches = Airtable.query(mgxtab)
    metabbatches = Airtable.query(metabtab)

    df = DataFrame()
    for sample in samples
        mgx = get(sample, Symbol("MGX Batches"), [])
        metab = get(sample, Symbol("Metabolomics Batches"), [])

        record = Pair{Symbol, Any}[k => get(sample, k, missing) for k in keep_meta]
        
        push!(record, :Mgx_batch => isempty(mgx) ? missing :
            mgxbatches[findfirst(==(first(mgx)), Airtable.id.(mgxbatches))][:Name]
        )

        push!(record, :Metabolomics_batch => isempty(metab) ? missing :
            metabbatches[findfirst(==(first(metab)), Airtable.id.(metabbatches))][:Name]
        )

        push!(df, NamedTuple(record), cols=:union)
    end
    return df
end