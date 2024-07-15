using Documenter
using Mocking: Mocking

setup = quote
    using Mocking: @mock, @patch, activate, apply
    activate()
end

DocMeta.setdocmeta!(Mocking, :DocTestSetup, setup; recursive=true)

makedocs(;
    modules=[Mocking],
    authors="Curtis Vogt and contributors",
    sitename="Mocking.jl",
    format=Documenter.HTML(;
        canonical="https://juliatesting.github.io/Mocking.jl",
        edit_link="main",
        assets=String[],
        prettyurls=get(ENV, "CI", nothing) == "true",  # Fix links in local builds
    ),
    pages=[
        "Home" => "index.md",
        "FAQ" => "faq.md",
        "API" => "api.md",
        # format trick: using this comment to force use of multiple lines
    ],
    warnonly=[:missing_docs],
)

deploydocs(; repo="github.com/JuliaTesting/Mocking.jl", devbranch="main")
