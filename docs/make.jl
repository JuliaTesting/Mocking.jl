using Documenter
using Mocking: Mocking

doc_test_setup = quote
    using Mocking: @mock, @patch, activate, apply
    activate()
end

DocMeta.setdocmeta!(Mocking, :DocTestSetup, doc_test_setup; recursive=true)

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
        # "Home" => "index.md",
        "FAQ" => "faq.md",
        "API" => "api.md",
    ],
    warnonly=[:missing_docs]
)

deploydocs(; repo="github.com/JuliaTesting/Mocking.jl", devbranch="main")
