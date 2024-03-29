using VKCComputing
using Documenter

DocMeta.setdocmeta!(VKCComputing, :DocTestSetup, :(using VKCComputing); recursive=true)

makedocs(;
    modules = [VKCComputing],
    authors = "Kevin Bonham, PhD <kbonham@wellesley.edu> and contributors",
    repo = "https://github.com/Klepac-Ceraj-Lab/VKCComputing.jl/blob/{commit}{path}#{line}",
    sitename = "VKCComputing",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://Klepac-Ceraj-Lab.github.io/VKCComputing.jl",
        edit_link = "main",
        assets = String[],
    ),
    pages = [
        "Home" => "index.md",
        "Examples" => [
            "Renaming"=> "examples/renaming_files.md"
        ]
    ]
)

deploydocs(;
    repo = "github.com/Klepac-Ceraj-Lab/VKCComputing.jl",
    push_preview = true,
    devbranch = "main",
)
