using BioServices.EUtils
using CSV
using DataFrames
using EzXML
using VKCComputing

accessions = readlines("SraAccList.txt")

doc = EzXML.readxml("sra_bioproject.xml")
experiment = root(doc)

df = DataFrame(map(findall("//SAMPLE/IDENTIFIERS", experiment)) do ids
    els = elements(ids) 
    (; accession = els[1].content, biosample = els[2].content, biospecimen= els[3].content)
end)

df = hcat(df, DataFrame(
    seq_accession = [node.content for node in findall("//RUN/IDENTIFIERS/PRIMARY_ID", el)],
    sample_type = [last(split(node.content, "-")) for node in findall("//RUN/EXPERIMENT_REF/IDENTIFIERS/SUBMITTER_ID", el)],
    filename = [node.content for node in findall("//RUN/IDENTIFIERS/SUBMITTER_ID", el)],
))

subset!(df, "sample_type"=> ByRow(==("mgx")))


base = LocalBase()

transform!(df,
    "biospecimen" => ByRow(biospecimen-> begin
        rec = get(base["Biospecimens"], biospecimen, nothing)
        if isnothing(rec)
            rec = get(base["Aliases"], biospecimen, get(base["Aliases"], replace(biospecimen, "_"=> "-"), nothing))
            isnothing(rec) && error("$biospecimen doesn't exist in the database")
            biospecimen = filter(b-> haskey(b, :seqprep), base[rec[:biospecimens]])
            length(biospecimen) > 1 && @warn rec
            biospecimen = only(biospecimen)[:uid]
            rec = base["Biospecimens", biospecimen]
        end
        seqprep = [r[:uid] for r in base[rec[:seqprep]]]
        (;biospecimen, seqprep)
    end)=> ["biospecimen", "seqprep"],
    "filename" => ByRow(file -> begin
        m = match(r"_(S\d+)_", file)
        s_well = isnothing(m) ? missing : m[1]
        m = match(r"([MC]\d+[_\-]\d+[FE][_\-]\d+[A-Z])", file)
        alias = isnothing(m) ? missing : replace(m[1], "-"=>"_")
        (; s_well, alias)
    end) => ["s_well", "alias"]
)

transform!(df, ["seqprep", "s_well", "alias"]=> ByRow((seqprep, s_well, alias) -> begin
    if length(seqprep) == 1
        return only(seqprep)
    end

    seqprep = filter(seqprep) do seqid
        rec = base["SequencingPrep", seqid]
        if !ismissing(s_well)
            return s_well == rec[:S_well]
        elseif !ismissing(alias)
            rec = only(base[rec[:aliases]])
            return alias == rec[:uid]
        end
    end
    return only(seqprep)
end) => "canonical_seqprep")
