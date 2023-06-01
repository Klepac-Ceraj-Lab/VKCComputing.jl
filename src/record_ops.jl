function flatten!(df::DataFrame, records, base::LocalBase)
    for record in records
        dfinner = DataFrame()
        fs = record.fields 
    end
end

function flatten(records, base::LocalBase)
    df = DataFrame()
    flatten!(df, records, base)
    return df
end



