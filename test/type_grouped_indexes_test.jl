using SymbolicIndexingInterface
using SymbolicIndexingInterface: TypeGroupedIndexes, OOPSetter
using Test

# Two distinct index types, mimicking providers whose parameter indexes carry
# the storage location in their type (e.g. the portions of
# `ModelingToolkit.MTKParameters`). Such providers compute buffer eltype
# promotion in `remake_buffer` from `eltype(idxs)`, which requires the OOP
# setters to pass concretely typed index collections.
struct IndexKindA
    i::Int
end
struct IndexKindB
    i::Int
end

@testset "TypeGroupedIndexes partitioning" begin
    tgi = TypeGroupedIndexes(Any[IndexKindA(1), IndexKindB(1), IndexKindA(2)])
    @test length(tgi.groups) == 2
    (g1, p1), (g2, p2) = tgi.groups
    @test g1 isa Vector{IndexKindA}
    @test g1 == [IndexKindA(1), IndexKindA(2)]
    @test p1 == [1, 3]
    @test g2 isa Vector{IndexKindB}
    @test g2 == [IndexKindB(1)]
    @test p2 == [2]
end

struct TwoKindSys end
SymbolicIndexingInterface.is_variable(::TwoKindSys, sym) = false
SymbolicIndexingInterface.variable_index(::TwoKindSys, sym) = nothing
SymbolicIndexingInterface.is_parameter(::TwoKindSys, sym) = sym in (:a, :b, :c)
function SymbolicIndexingInterface.parameter_index(::TwoKindSys, sym)
    if sym === :a
        IndexKindA(1)
    elseif sym === :b
        IndexKindB(1)
    elseif sym === :c
        IndexKindB(2)
    else
        nothing
    end
end

struct TwoKindParams{TA, TB, TC}
    a::TA
    b::TB
    c::TC
end

struct TwoKindProb{P}
    u0::Vector{Float64}
    p::P
end
SymbolicIndexingInterface.state_values(prob::TwoKindProb) = prob.u0
SymbolicIndexingInterface.parameter_values(prob::TwoKindProb) = prob.p

function SymbolicIndexingInterface.remake_buffer(
        ::TwoKindSys, oldbuf::TwoKindParams, idxs, vals)
    # the contract under test: implementations must never receive an
    # abstractly typed index collection
    @test isconcretetype(eltype(idxs))
    buf = oldbuf
    for (idx, val) in zip(idxs, vals)
        if idx isa IndexKindA
            buf = TwoKindParams(val, buf.b, buf.c)
        elseif idx == IndexKindB(1)
            buf = TwoKindParams(buf.a, val, buf.c)
        else
            buf = TwoKindParams(buf.a, buf.b, val)
        end
    end
    return buf
end

@testset "setp_oop groups mixed index types" begin
    sys = TwoKindSys()
    prob = TwoKindProb(Float64[], TwoKindParams(0.0, 0.0, 0.0))

    set_mixed = setp_oop(sys, [:a, :b, :c])
    @test set_mixed.idxs isa TypeGroupedIndexes
    newps = set_mixed(prob, [1.0, 2.0, 3.0])
    @test newps.a == 1.0
    @test newps.b == 2.0
    @test newps.c == 3.0
    # value type changes flow through
    newps2 = set_mixed(prob, [1, 2, 3])
    @test newps2.a === 1
    @test newps2.b === 2
    @test newps2.c === 3

    # homogeneous index types stay a plain concrete vector
    set_homog = setp_oop(sys, [:b, :c])
    @test set_homog.idxs isa Vector{IndexKindB}
    newps3 = set_homog(prob, [5.0, 6.0])
    @test newps3.b == 5.0
    @test newps3.c == 6.0
end

@testset "setsym_oop groups mixed index types" begin
    sys = TwoKindSys()
    prob = TwoKindProb(Float64[], TwoKindParams(0.0, 0.0, 0.0))

    setter = setsym_oop(sys, [:a, :b])
    _, newps = setter(prob, [1.5, 2.5])
    @test newps.a == 1.5
    @test newps.b == 2.5
end

@testset "BatchedInterface setsym_oop groups mixed index types" begin
    sys = TwoKindSys()
    prob = TwoKindProb(Float64[], TwoKindParams(0.0, 0.0, 0.0))

    bi = BatchedInterface((sys, [:a, :b]))
    setter = setsym_oop(bi)
    _, newps = setter(prob, 1, [1.5, 2.5])
    @test newps.a == 1.5
    @test newps.b == 2.5
    ((_, newps2),) = setter(prob, [3.5, 4.5])
    @test newps2.a == 3.5
    @test newps2.b == 4.5
end
