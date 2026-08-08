using SymbolicIndexingInterface
using SciMLTesting
using Test

# ExplicitImports only sees an extension module once its trigger package is loaded, so
# load every weakdep here to bring the extensions into the QA scan.
using PrettyTables

# ExplicitImports silently skips an extension that fails to load, so assert the
# extension modules actually exist rather than trusting a green run_qa.
@testset "Extensions loaded" begin
    @test Base.get_extension(SymbolicIndexingInterface, :SymbolicIndexingInterfacePrettyTablesExt) !== nothing
end

# Julia 1.10 cannot express unexported `public` bindings, so it cannot observe the
# declarations that current RuntimeGeneratedFunctions and ArrayInterface releases make.
const QUALIFIED_PUBLIC_IGNORE = VERSION < v"1.11" ? (:init, :ismutable) : ()

run_qa(
    SymbolicIndexingInterface;
    ei_kwargs = (;
        all_qualified_accesses_are_public = (; ignore = QUALIFIED_PUBLIC_IGNORE),
        # `similar_type` is a documented StaticArraysCore extension point, but its
        # owning package does not yet export or declare it public.
        all_explicit_imports_are_public = (; ignore = (:similar_type,)),
    ),
)
