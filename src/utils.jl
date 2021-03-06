
function symset(v::String, j::Int64)
    return Sym[Sym("$v$i") for i in 1:j]
end

unique_var_count = 0

function uniquevar(v="v")
    global unique_var_count += 1
    return sympify(Symbol("$v$unique_var_count"))
end


function replace(a::Array{T}, d::Dict{T,T}) where T
    b = copy(a)
    replace!(b, d...)
    return b
end

function symfunctions(expr::Sym)
    return Sym.(collect(expr.atoms(AppliedUndef)))
end

# override show for SymPy.SymFunction
# function Base.show(io::IO, f::SymPy.SymFunction)
#     return show(io, Sym(f.x))
# end

function coeff_rem(expr::Sym, t::Sym)
    c = coeff(expr, t)
    return c, expr - c*t
end

function summands(expr::Sym)
    expr = expand(expr)
    if funcname(expr) == "Add"
        return expr.args
    end
    expr
end

function clear_denom(expr::Sym)
    ls = summands(expr)
    ds = denom.(ls)
    val = lcm2(ds...)
    expr *= val
    simplify(expr)
end

function lcm2(n::Sym, rest::Sym...)
    SymPy.lcm(n, lcm2(rest...))
end

function lcm2()
    1
end