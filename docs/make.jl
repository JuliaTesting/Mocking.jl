using Documenter
using Mocking: Mocking

DocMeta.setdocmeta!(Mocking, :DocTestSetup, :(using Mocking); recursive=true)

makedocs(;
    modules=[Mocking],
    authors="Curtis Vogt and contributors",
    sitename="Mocking.jl",
    format=Documenter.HTML(;
        canonical="https://juliatesting.github.io/Mocking.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaTesting/Mocking.jl",
    devbranch="main",
)
