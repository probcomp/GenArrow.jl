using Documenter, GenArrow

makedocs(modules=[GenArrow],
         sitename="GenArrow",
         authors="McCoy R. Becker and MIT ProbComp",
         pages=["API Documentation" => "index.md"])

deploydocs(repo = "github.com/probcomp/GenArrow.jl.git")
