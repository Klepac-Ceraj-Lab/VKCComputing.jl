
"""
    VKCAirTable(base, name, localpath)
"""
struct VKCAirtable
    base::AirBase
    name::String
    localpath::String
end

Base.show(io::IO, tab::VKCAirtable) = print(io, "Airtable with name \"$(tab.name)\", located at $(tab.localpath)")

vkctable(name::String) = _gen_table(Symbol(replace(name, " "=>"_")))

_gen_table(name::Symbol) = _gen_table(Val(name))
_gen_table(::Val{T}) where T = throw(ArgumentError("No table method defined for $(String(T))"))

_gen_table(::Val{:Project}) = VKCAirtable(
    AirBase("appSWOVVdqAi5aT5u"),
    "Project",
    joinpath(@load_preference("airtable_dir"), "airtable_project.json")
)

_gen_table(::Val{:Samples}) = VKCAirtable(
    AirBase("appSWOVVdqAi5aT5u"),
    "Samples",
    joinpath(@load_preference("airtable_dir"), "airtable_samples.json")
)

_gen_table(::Val{:MGX_Batches}) = VKCAirtable(
    AirBase("appSWOVVdqAi5aT5u"),
    "MGX Batches",
    joinpath(@load_preference("airtable_dir"), "airtable_mgxbatches.json")
)


"""
    airtable_metadata(key=ENV["AIRTABLE_KEY"])

Get fecal sample metadata table from airtable.
The API `key` comes from https://airtable.com/account.
This is unlikely to work if you're not in the VKC lab.
"""
function airtable_metadata(key=Airtable.Credential())
    samples      = airtable_table(key, "Samples")
    projects     = airtable_table(key, "Project")
    mgxbatches   = airtable_table(key, "MGX Batches")
    metabbatches = airtable_table(key, "Metabolomics Batches")

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

function _should_update(file; force = false, interval = Month(1))
    modtime = astimezone(ZonedDateTime(Dates.unix2datetime(mtime(file)), tz"UTC"), localzone())
    @debug "Expected file location: `$file`"
    @debug "Last modified: `$modtime`"
    if force
        @debug "Should update: `force`"
        return true
    elseif !isfile(file)
        @debug "Should update: missing file"
        return true
    elseif modtime + interval < now(localzone())
        @debug "Should update: last modified less than specified interval (*$interval*)"
        return true
    else
        @debug "No update needed for interval: $interval"
        return false
    end
end


function update_airtable_metadata!(tab::VKCAirtable; force=false, interval = Month(1))
    if _should_update(tab.localpath; force, interval)
        @info "Table $(tab.name) needs updating, writing to `$(tab.localpath)`"
        JSON3.write(tab.localpath, Airtable.query(tab))
    else
        @info "Table $(tab.name) does not need updating updating. Use `force` or shorten `interval` to override"
    end
end

function Airtable.query(key, tab::VKCAirtable)
    table = AirTable(tab.name, tab.base)
    Airtable.query(key, table)
end

Airtable.query(tab::VKCAirtable) = Airtable.query(Airtable.Credential(), tab)

function _flatten_airtable_records(records)
    DataFrame(map(records) do record
        fields = record.fields
        (; first(keys(fields)) => first(values(fields)),
            :airtable_id => record.id,
            :table_id => record.table.id,
            :base_id => record.table.base.id,
            fields...
        )
    end)
end

function tabular_metadata(tab::VKCAirtable; force=false, interval = Month(1))
    update_airtable_metadata!(tab; force, interval)
    return _tabular(tab)
end

_tabular(::Val{T}) where T = throw(ArgumentError("No tabular output for $(String(T)) defined"))
_tabular(tab::VKCAirtable) = _tabular(Val(Symbol(replace(tab.name, " "=>"_"))), tab.localpath)

function _tabular(::Val{:MGX_Batches}, localpath)
    records = _flatten_airtable_records(open(JSON3.read, localpath))
    records."Date Shipped" = Date.(records."Date Shipped")
    return records
end

function _tabular(::Val{:Project}, localpath)
    records = _flatten_airtable_records(open(JSON3.read, localpath))
    return records
end

function _tabular(::Val{:Samples}, localpath)
    records = _flatten_airtable_records(open(JSON3.read, localpath))

    return records
end