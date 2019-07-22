using Documenter, CryptoUtils

makedocs(;
    modules=[CryptoUtils],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/fcasal/CryptoUtils.jl/blob/{commit}{path}#L{line}",
    sitename="CryptoUtils.jl",
    authors="fcasal",
    assets=String[],
)
