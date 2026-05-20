using VKCComputing
using CSV
using DataFrames
using Airtable

base = LocalBase(; update=true)

biosp = CSV.read("/home/kevin/Downloads/Khula_ME_200_DNA_19April2024.csv", DataFrame)
transform!(biosp, "QR code: Subject ID" => ByRow(s-> "khula-$s")=> "subject")
khulahash = base["Projects", "khula"].id

biosp.subject_hash = map(biosp.subject) do subject
    subject == "khula-missing" && return missing
    rec = get(base["Subjects"], subject, nothing)
    isnothing(rec) && (rec = Airtable.post!(AirTable("Subjects", VKCComputing.newbase), (; subject_id= replace(subject, "khula-"=>""), project=[khulahash])))
    rec.id
end

biosp.biospecimen_hash = map(eachrow(biosp)) do row
    ismissing(row.subject_hash) && return missing
    bsp = row.BARCODE
    rec = get(base["Biospecimens"], bsp, nothing)
    isnothing(rec) && (rec = Airtable.post!(AirTable("Biospecimens", VKCComputing.newbase),
        (; uid=bsp, subject=[row.subject_hash], )
    ))
    rec.id
end


biosp_list = String.(biosp[:, "BARCODE"])
filter!(!startswith("D"), biosp_list)
append!(biosp_list, ["Z3mo-95171", "Z3mo-95875", "Z6mo-44967"])

bprecs = base["Biospecimens"][biosp_list]
seqrecs = Airtable.post!(AirTable("SequencingPrep", VKCComputing.newbase), [(; biospecimen = [rec.id]) for rec in bprecs])

let
    n = 1
    r = 1
    c = 1
    bplate = DataFrame("row" => collect("ABCDEFGH"), ("col_$i"=> fill("", 8) for i in 1:12)...)
    splate = DataFrame("row" => collect("ABCDEFGH"), ("col_$i"=> fill("", 8) for i in 1:12)...)

    for (i, (bsp, seq)) in enumerate(zip(bprecs, seqrecs))
        bplate[r,"col_$c"] = bsp.fields[:uid]
        splate[r,"col_$c"] = seq.fields[:uid]
        if r == 8
            if c == 12
                CSV.write("/home/kevin/Downloads/mgx030_biospecimens_$n.csv", bplate)
                CSV.write("/home/kevin/Downloads/mgx030_seqids_$n.csv", splate)
                r = c = 1
                n += 1
                foreach(c-> fill!(bplate[!, "col_$c"], ""), 1:12)
                foreach(c-> fill!(splate[!, "col_$c"], ""), 1:12)
            else
                r = 1
                c += 1
            end
        else
            r += 1
        end
    end

    CSV.write("/home/kevin/Downloads/mgx034_biospecimens_$n.csv", bplate)
    CSV.write("/home/kevin/Downloads/mgx034_seqids_$n.csv", splate)
end

batch = Airtable.post!(AirTable("SequencingBatches", VKCComputing.newbase), (; sequencing_prep_ids=[sreq.id for sreq in seqrecs], type="mgx", facility="IMR"))
