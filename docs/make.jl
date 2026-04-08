using GZip
using Documenter

DocMeta.setdocmeta!(GZip, :DocTestSetup, :(using GZip); recursive=true)

makedocs(
    sitename = "GZip.jl",
    modules = [GZip],
    authors = "JuliaIO and contributors",
    format = Documenter.HTML(; assets = String[]),
    pages = [
        "GZip" => "index.md",
        "Reference" => "reference.md",
    ],
    warnonly = [:missing_docs],
)

deploydocs(repo = "github.com/JuliaIO/GZip.jl", devbranch = "master")
