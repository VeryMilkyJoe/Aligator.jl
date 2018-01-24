
abstract type Loop end

const LoopBody = Array{<:Recurrence,1}

type EmptyLoop <: Loop end

struct SingleLoop <: Loop
    body::LoopBody
    # cond::Expr # not used for now
    # init
end

struct MultiLoop <: Loop
    branches::Array{SingleLoop}
    # cond::Expr
    # init
end

Base.length(ideal::Singular.sideal) = ngens(ideal)
Base.start(ideal::Singular.sideal) = 1
Base.next(ideal::Singular.sideal, state) = (ideal[state], state+1)
Base.done(ideal::Singular.sideal, state) = state > ngens(ideal)
Base.eltype(::Singular.sideal) = Singular.spoly

function invariants(loop::MultiLoop)
    error("Multi-path loops are not implemented yet")
end

function invariants(loop::SingleLoop)
    closedforms = [closedform(rec) for rec in loop.body]
    exp = collect(Set(Iterators.flatten([exponentials(cf) for cf in closedforms])))
    println("exp: ", exp)
    # expvars = [uniquevar() for _ in exponentials]
    expv = symset("v", length(exp))
    dict = Dict(zip(exp, expv))
    println(dict)    
    println("Closed forms: ", closedforms)
    for cf in closedforms
        expvars!(cf, dict)
        println(cf)
    end
    # TODO: handle factorials
    ideal = [Sym(string(Sym(cf.f.x))) - init_variables(polynomial(cf), cf.f)[1] for cf in closedforms]
    vars = union(variables(ideal), string.(expv))
    println("Variables: ", vars)
    # init_variables(ideal, closedforms[1].f)
    # println(polynomial(closedforms[1]))
    # cforms, varmap = Ideal(ideal)
    algdep = dependencies(exp, variables = expv)

    # println("Closed forms: ", cforms)
    println("Algebraic dependencies: ", algdep)
    println(collect(algdep))
    gen_algdep = collect(algdep)
    # cgens = Singular.gens(base_ring(cforms))
    # agens = Singular.gens(base_ring(algdep))
    # gens = union(cgens, agens)
    # sexpv = string.(expv)
    vars = filter(x -> !in(x, expv), variables(ideal))
    fvars = [expv; vars]
    R, pvars = PolynomialRing(QQ, string.(fvars))
    varmap = Dict(zip(expv, pvars))
    # basis = sym2spoly(ideal, varmap)
    # println("Basis: ", basis)
    ideal = Singular.Ideal(R, gen_algdep...)
    println("Ideal: ", ideal)
    println("Varmap: ", varmap)
    # println("Algdep in bigger ring: ", ideal)
    elimvars = [varmap[v] for v in expv]
    # println("GROEBNER: ", Singular.eliminate(ideal, prod(elimvars)))
    # println("Dependencies: ", algdep)
end

function init_variables(expr::Sym, f::SymFunction)
    w0   = Wild("w0")
    fns  = Sym.(collect(atoms(expr, AppliedUndef)))
    args = [match(f(w0), fn)[w0] for fn in fns]
    ffns = [f(x) for x in args]
    vars = [Sym("$(string(Sym(f.x)))_$(x)") for x in args]
    dict = Dict(zip(ffns, vars))
    return subs(expr, dict), vars
end

# h = SymFunction("h")
# g = SymFunction("g")

# r1 = CFiniteRecurrence([Sym(-2),Sym(1)], h, n)
# r2 = CFiniteRecurrence([1/Sym(-2),Sym(1)], g, n)