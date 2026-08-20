@setup_workload begin
    indp = SymbolCache([:x, :y], [:a, :b], :t)
    valp = ProblemState(; u = [1.0, 2.0], p = [3.0, 4.0], t = 0.5)
    state_getter = getsym(indp, [:x, :y])
    parameter_getter = getp(indp, [:a, :b])
    state_setter = setsym(indp, [:x, :y])
    parameter_setter = setp(indp, [:a, :b])

    @compile_workload begin
        SymbolCache([:x, :y], [:a, :b], :t)
        ProblemState(; u = [1.0, 2.0], p = [3.0, 4.0], t = 0.5)
        getsym(indp, :x)(valp)
        state_getter(valp)
        parameter_getter(valp)
        state_buffer = zeros(2)
        state_getter(state_buffer, valp)
        state_setter(valp, [5.0, 6.0])
        parameter_setter(valp, [7.0, 8.0])
    end
end
