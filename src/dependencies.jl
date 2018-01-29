
import Base.Matrix

# represents the algebraic number in the field Q[theta] given by c0 + c_1 theta + ...
struct AlgebraicNumber
    theta::Sym
    coeffs::Array{Sym, 1}
end

function polyrepr(x, coeffs)
   return sum([c*x^(i-1) for (i, c) in enumerate(coeffs)]) 
end

function poly(a::AlgebraicNumber)
    return polyrepr(a.theta, a.coeffs)
 end

function Base.show(io::IO, a::AlgebraicNumber)
    print(io, "[$(a.theta), $(a.coeffs)] $(expand(polyrepr(a.theta, a.coeffs)))")
end

function common_number_field(extensions::Array{Sym, 1})
    nonrat = filter(ext -> (is_rational(ext) == false), extensions)
    if isempty(nonrat)
        theta = 1
    else
        minpoly, coeffs = primitive_element(Sym(PyCall.array2py(nonrat)))
        theta = dot(nonrat, coeffs)
    end
    # return [AlgebraicNumber(sqrt(Sym(5)),[1/Sym(2),1/Sym(2)]), AlgebraicNumber(sqrt(Sym(5)),[1/Sym(2),-1/Sym(2)])]
    return [AlgebraicNumber(theta, field_isomorphism(ext, theta)) for ext in extensions]
end

function z_nullspace(matrix::Matrix{Int})
    h, t = hnf_with_transform(matrix)
    t = t * -1
    println("HNF: $(h) | $(t)")

    # kernel is generated by the rows of t that correspond to zero rows in h
    zvec = zeros(size(h, 2))

    # TODO: find better way to filter zero vectors
    res = Matrix{Int}(0, ncols(t))
    for i in 1:nrows(t)
        if iszero(h[i,:])
            res = vcat(res, transpose(t[i,:]))
        end
    end
    return res
    # return [t[i,:] for i in 1:size(h, 1) if h[i,:] == zvec]
end

function z_module_intersect(base1::Matrix{Int}, base2::Matrix{Int})
    if isempty(base1) || isempty(base2)
        return []
    end

    sol = z_nullspace(vcat(base1, base2))

    if isempty(sol)
        return []
    end

    m1 = transpose(base1)
    m2 = transpose(sol[:, 1:nrows(base1)])
    return lll(transpose(m1 * m2))
end

function minimal_polynomial(a::AlgebraicNumber, x::Sym)
    return SymPy.minimal_polynomial(poly(a), x)
end

function masser_bound(roots::Array{AlgebraicNumber, 1})
    k = length(roots)
    # assume all roots belong to the same number field
    @syms x
    p = Poly(SymPy.minimal_polynomial(roots[1].theta, x), x)
    d = SymPy.degree(p) #TODO: degree of field extension

    # h = maximum height of the a[i]. The height of an algebraic number is the 
    # sum of the degree and the binary length of all coefficients in the 
    # defining equation over Q
    h = 0
    for root in roots
        p = Poly(minimal_polynomial(root, x), x)
        h0 = ceil(SymPy.degree(p) + sum([SymPy.log(abs(ex)) for ex in coeffs(p)]))
        println("h0: ", h0)
        if h0 > h
            h = h0
        end
    end
    println("d: ", d)
    println("h: ", h)
    println("k: ", k)

    return ceil(d^2 * (4*h*k*d* (SymPy.log(2+d)/SymPy.log(SymPy.log(2+d)))^3)^(k-1) + 1)
end

# workaround since findin(...) does not work for Sym(0) for some reason
function findzeros(a::Array{Sym,1})
    zeros = []
    for i in eachindex(a)
        if a[i] == Sym(0)
            zeros = [zeros; i]
        end
    end
    return zeros
end

function findrelations(roots::Array{Sym,1})
    # first treat zeros in the root list
    zeros = find(x -> x == 0, roots)
    if length(zeros) == length(roots)
        return []
    end
    if !isempty(zeros)
        B = findrelations(dropzeros(roots))
        # TODO: insert new dimensions
        return B
    end

    # TODO: common number field does not work as expected
    an = common_number_field(roots) # TODO: does nothing if the roots belong to the same field
    println("Algebraic numbers: ", an)
    a = poly.(an)

    println("Algebraic numbers (poly): ", a)
    relog = [SymPy.real(SymPy.log(Sym(x))) for x in a]
    imlog = [SymPy.imag(SymPy.log(Sym(x))) for x in a]
    imlog = [imlog; Sym(2)*SymPy.pi]

    println(relog)
    println(imlog)

    # replace implicit zeros by explicit ones
    for i in 1:length(a)
        z = a[i]

        # abs(z) == 1
        if abs(N(abs(z)) - 1) < 0.1 && simplify(abs(z)) == 1
            relog[i] = 0
        end

        # z is real and z >= 0
        if is_real(z) && is_real(sqrt(z))
            imlog[i] = 0
        else
            # TODO: try harder: If[ Element[RootReduce[z], Reals] && Element[Sqrt[RootReduce[z]], Reals], imLog[[i]] = 0 ];
        end
    end

    # comute a bound for the coefficients of the generators
    bound = Int(masser_bound(an))
    println("Masser bound: ", bound)

    m = eye(Int, length(a)) # identity matrix

    # successively refine the approximation until only valid generators are returned
    level = Int(ceil(N(log2(bound)) + 1))
    while prod(Bool[check_relation(a, m[i,:]) for i in 1:size(m)[1]]) == 0
        println("--- level: $(level), bound: $(bound)")
        println("--- Relog: ", relog)
        m1 = getbasis(relog, level, bound)
        println("--- getbasis1: ", m1)
        println("--- Imlog: ", imlog)
        m2 = getbasis(imlog, level, bound)
        println("--- getbasis2: ", m2[:,1:end-1])        
        m = z_module_intersect(m1, m2[:,1:end-1])
        level = level + 1
        println("--- matrix: ", m)
    end

    return m
end

function check_relation(a::Array{Sym, 1}, e::Array{<:Integer, 1})
    println("Check relation: {$(a)} {$(e)}")
    return simplify(prod([ax^ex for (ax, ex) in zip(a,e)])) == 1
    # println("Check relation:
    # return res == 1
end

function convergent(x, n)
    # TODO: is precision of 60 enough>
    cf = ContinuedFraction(N(x, 60))
    co = convergents(cf)
    res = next(co, n)[1]
    return next(co, n)[1]
end

nrows(a::Matrix{<:Any}) = size(a)[1]
ncols(a::Matrix{<:Any}) = size(a)[2]

function getbasis(l::Array{Sym, 1}, level::Int, bound::Int)
    n = length(l)

    # first treat zero elements in l as special case
    # zeros = find(x -> x == 0, l)
    zpos = findzeros(l)
    if length(zpos) == length(l)
        return eye(Int, n)
    end

    if length(zpos) > 0
        ll = deleteat!(copy(l), zpos)
        b = getbasis(ll, level, bound) # basis for nonzero numbers
        zvec = zeros(nrows(b), 1)
        # insert new dimensions
        for pos in zpos
            b = hcat(b[:,1:pos-1], zvec, b[:,pos:end])
        end
        # add unit vectors at the zero positions
        b = vcat(b, eye(n)[zpos,:])
        return Matrix{Int}(b)
    end

    println("========== Now for nonzero: $(l) | $(level) | $(bound)")

    # now we assume that l is a list of nonzero real numbers
    c1 = [convergent(x, level) for x in l]
    c2 = [convergent(x, level+1) for x in l]

    println("c1: ", c1)
    println("c2: ", c2)

    e = [1//denominator(x1*x2) for (x1, x2) in zip(c1, c2)]
    # cfrac theorem says: | log[i] - c1[i] | <= e[i]

    # refine the approximation such that all errors are smaller than the smallest
    # element of l in absolute value *)

    lev = level + 1
    while length(filter(x -> maximum(e) >= abs(x), c1)) > 0 && lev < level + 5
        ex = findin(e, maximum(e)) # indices with greates error

        lev++
        for i in 1:length(ex)
            j = ex[i]
            c1[j] = c2[j]
            c2[j] = convergent(l[j], lev)
            e[j] = c1[j] == l[j] ? 0 : 1/denominator(c1[j]*c2[j])
        end
    end

    # now: max e[i] < min |c1[i]|

    # this bound guarantees that generators whose norm is at most bound will
    # appear in the LLL-reduced basis
    minc1 = minimum([abs(c) for c in c1])
    maxe = maximum([abs(c) for c in e])
    println("min: ", minc1)
    println("max: ", maxe)
    d = BigInt(ceil(N(2^((length(c1) - 1)/2)*bound/(minc1 - maxe))))
    println("Integer d: ", d)
    identity = eye(Int, n)
    row = c1 * d
    b = hcat(identity, row)
    b = lll(b)
    # Vectors whose right hand side is greater than the errors permit can be 
    #   discarded; they cannot correspond to integer relations.
    # b = vcat([b[i,:] for i in 1:nrows(b) ])
    # TODO: find better way to filter rows
    res = Matrix{Rational{Int}}(0,n+1)
    for i in 1:nrows(b)
        if (abs(b[i,:][end]) <= d*abs(dot(b[i,1:n],e)))
            res = vcat(res, transpose(b[i,:]))
        end
    end
    # b = filter(x -> ))

    # all remaining vectors are returned as candidates
    # TODO: result should be integer matrix?
    return Matrix{Int}(res[:,1:end-1])
end

function clear_denom(a::Matrix{Rational{BigInt}})
    d = lcm(denominator.(a))
    return a*d, d
end

function lll(a::Matrix{Rational{BigInt}})
    m, d = clear_denom(a)
    m = numerator.(m)
    println(typeof(m))
    m = Matrix{BigInt}(Nemo.lll(matrix(FlintZZ, m)))
    return m // d
end

lll(m::Matrix{Int}) = Matrix{BigInt}(Nemo.lll(matrix(FlintZZ, m)))

hnf_with_transform(m::Matrix{Int}) = Matrix{Int}.(Nemo.hnf_with_trafo(matrix(FlintZZ, m)))

function lattice_divide(l::Matrix{Int}, d::Int)
    n = ncols(l)
    return z_module_intersect(l, d*eye(Int, n)) / d
end

################################################################################

function ideal(m::Matrix{BigInt}, x::Array{Sym,1})
    if isempty(m)
        return []
    end

    y = symset("y", length(x))
    base = Sym[]
    for i in 1:nrows(m)
        r = 1
        for j in 1:ncols(m)
            exp = m[i,j]
            v = exp > 0 ? x[j] : y[j]
            r *= v^abs(exp)
        end
        base = [base; r - 1]
    end

    inv = [xi*yi - 1 for (xi,yi) in zip(x,y)]
    base = [base; inv]
    
    return eliminate(base, y)
end

function dependencies(roots::Array{Sym,1}; variables=Sym[])
    println("Computing dependencies between ", roots)
    if length(roots) < 2
        return nothing
    end
    lattice = findrelations(roots)
    if isempty(variables)
        variables = symset("v", length(lattice))
    elseif length(variables) != ncols(lattice)
        throw("Number of variables does not match number of columms. Got $(length(variables)), need $(ncols(lattice))")
    end
    return ideal(lattice, variables)
end

# function seq2poly()

# z1 = Sym((1+sqrt(Sym(5)))/2)
# z2 = Sym((1-sqrt(Sym(5)))/2)
# z3 = Sym(-1)

# e1 = Sym(2)
# e2 = Sym(1/Sym(2))
# e3 = Sym(1)

# result = findrelations([e1,e2,e3])
# println("Relations: ")
# println(result)