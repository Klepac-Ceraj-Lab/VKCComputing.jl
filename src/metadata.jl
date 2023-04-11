
"""
    VKCAirTableTable(base, name, localpath)
"""
struct VKCAirtableTable
    base::AirBase
    name::String
    localpath::String
end



vkctable(name::String) = _gen_table(Symbol(replace(name, " "=>"_")))

_gen_table(name::Symbol) = _gen_table(Val(name))
_gen_table(name::Val) = error("No table method defined for $name")

_gen_table(name::Val{:Project}) = VKCAirtableTable(
    AirBase("appSWOVVdqAi5aT5u"),
    "Project",
    joinpath(@load_preference("airtable_dir"), "airtable_project.json")
)

_gen_table(name::Val{:Samples}) = VKCAirtableTable(
    AirBase("appSWOVVdqAi5aT5u"),
    "Samples",
    joinpath(@load_preference("airtable_dir"), "airtable_projects.json")
)

_gen_table(name::Val{:MGX_Batches}) = VKCAirtableTable(
    AirBase("appSWOVVdqAi5aT5u"),
    "MGX Batches",
    joinpath(@load_preference("airtable_dir"), "airtable_projects.json")
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


function update_airtable_metadata!(tab::VKCAirtableTable; force=false, interval = Month(1), metadata_dir = @load_preference("airtable_dir"))
    if _should_update(tab.localpath; force, interval)
        @info "Table $(tab.name) needs updating, writing to `$(tab.localpath)`"
        JSON3.write(tab.localpath, Airtable.query(tab))
    else
        @info "Table $(tab.name) does not need updating updating. Use `force` or shorten `interval` to override"
    end
end

function Airtable.query(key, tab::VKCAirtableTable)
    table = AirTable(tab.name, tab.base)
    Airtable.query(key, table)
end

Airtable.query(tab::VKCAirtableTable) = Airtable.query(Airtable.Credential(), tab)

function metadata_table()
end