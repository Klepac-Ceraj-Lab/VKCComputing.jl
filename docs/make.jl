using SeqAudit
using Documenter

DocMeta.setdocmeta!(SeqAudit, :DocTestSetup, :(using SeqAudit); recursive=true)

makedocs(;
    modules = [SeqAudit],
    authors = "Kevin Bonham, PhD <kbonham@wellesley.edu> and contributors",
    repo = "https://github.com/Klepac-Ceraj-Lab/SeqAudit/blob/{commit}{path}#{line}",
    sitename = "SeqAudit",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://Klepac-Ceraj-Lab.github.io/SeqAudit",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
    ]
)

deploydocs(;
    repo = "github.com/Klepac-Ceraj-Lab/SeqAudit",
    push_preview = true,
    devbranch = "main",
)
