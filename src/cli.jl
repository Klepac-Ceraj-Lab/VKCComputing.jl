"""
    set_logs!([; log, verbose, quiet, debug])

The default log-level for scripts is `Warn`,
and has only printing to the console.
Use command-line arguments to set different behavior.

- `"debug"`: Bool - whether to set minimm log level to `Debug`.
- `"verbose"`: Bool - whether to set the minimum log level to `Info`.
- `"log"`: String - file path for writing log outputs
- `"quiet"`: Bool - disable logging to the console.
    Note that this is compatible with setting annother log level for writing to a file.
    For example, one can set `--verbose --quiet --log script.log` to write all `Info`+
    logs to a file, with no terminal output.
"""
function set_logs!(; log = nothing, verbose = false, quiet = false, debug = false, message_mode=:markdown, kwargs...)
    if debug
        term_logger = MiniLogger(; minlevel=MiniLoggers.Debug, message_mode, kwargs...)
    elseif verbose
        term_logger = MiniLogger(; minlevel=MiniLoggers.Info, message_mode, kwargs...)
    else
        term_logger = MiniLogger(; minlevel=MiniLoggers.Warn, message_mode, kwargs...)
    end

    if !isnothing(log)
        if quiet
            global_logger(MiniLogger(; minlevel=term_logger.minlevel, io=log, message_mode, kwargs...))
        else
            global_logger(TeeLogger(
                    term_logger,
                    MiniLogger(; minlevel=term_logger.minlevel, io=log, message_mode, kwargs...)
                    )
            )
        end
    else
        if quiet
            global_logger(MiniLogger(; minlevel = MiniLoggers.Error, message_mode, kwargs...))
        else
            global_logger(term_logger)
        end
    end 
end

_bool_menu(message) =  quickmenu((_, i) -> getindex([true, false], i), RadioMenu, ["yes", "no"]; message)

_pref_check(pref) = _bool_menu("'$pref' is currently set to '$(@load_preference(pref))'. Is that correct?")

_pref_set!(pref) = _bool_menu("Do you want to set the value of '$pref'") && _pref_set!(pref, filepicker("./"))

function _pref_set!(pref, value)
    if _bool_menu("Set '$pref' to '$value'?")
        @set_preferences!(pref=> value)
        return true
    else
        if _pref_set(pref)
            resp = filepicker()
            return _pref_set!(pref, resp)
        else
            return false
        end
    end
end

function update_preferences!()
    prefs2check = (
        "airtable_dir",
        "mgx_analysis_dir",
        "mgx_raw_dir"
    )

    for pref in prefs2check
        (@has_preference(pref) && _pref_check(pref)) || _pref_set!(pref)
    end 
end