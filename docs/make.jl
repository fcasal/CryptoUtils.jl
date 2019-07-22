using Documenter, CryptoUtils

makedocs(modules = [CryptoUtils], sitename = "CryptoUtils.jl")

deploydocs(
    repo = "github.com/fcasal/CryptoUtils.jl.git",
)
