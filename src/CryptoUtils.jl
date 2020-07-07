module CryptoUtils

import Primes: isprime, primes

export legendre, jacobi, sqrt_mod_prime, find_quadratic_non_residue, is_quadratic_residue,
       convergents, continued_fraction, surd

export n2b, b2n

export random_prime, safe_prime, tower_two_prime, get_first_primes, twin_primes,
       is_generator, get_safe_prime_generator

export factor_with_ed, wiener


################################################################
##                   Number theory utilities                  ##
################################################################

"""
    legendre(a::Integer, p::Integer)

Return the Legendre symbol of `(a, p)`.

`p` should be an odd prime number.
"""
function legendre(a::Integer, p::Integer)
    if p % 2 == 0 && !isprime(p)
        throw("Argument p should be an odd prime.")
    end

    b = div(p - 1, 2)
    return powermod(a, b, p)
end



"""
    jacobi(n::Integer, k::Integer)

Return the Jacobi symbol of `n, k`.

`k` should be an odd number.
"""
function jacobi(n::Integer, k::Integer)
    rem(k, 2) != zero(k) || throw("Argument k=$k should be odd.")

    n = mod(n, k)
    t = 1
    while n != zero(n)
        while rem(n, 2) == 0
            n = div(n, 2)
            r = k % 8
            if r == 3 || r == 5
                t = -t
            end
        end
        n, k = k, n
        if n % 4 == 3 && k % 4 == 3
            t = -t
        end
        n = mod(n, k)
    end
    if k == oneunit(k)
        return t
    else
        return 0
    end
end



"""
    find_quadratic_non_residue(p::Integer)

Return a random number `R` which has no square root mod `p`,
i.e., `x^2 == R mod p` has no solutions.
"""
function find_quadratic_non_residue(p::Integer)
    two = big"2"
    qnr = rand(two:p - 1)

    while jacobi(qnr, p) != -1
        qnr = rand(two:p)
    end

    return qnr
end



"""
    tonelli_shanks(a::Integer, p::Integer)

Implements the Tonelli Shanks algorithm for computing
square roots modulo a prime number.

It assumes such square roots exist.
"""
function tonelli_shanks(a::Integer, p::Integer)
    b = find_quadratic_non_residue(p)
    t = p - 1
    s = 0
    while t % 2 == 0
        t = div(t, 2)
        s += 1
    end

    M = s
    Q = t
    c = powermod(b, t, p)
    t = powermod(a, t, p)
    r = powermod(a, div(Q + 1, 2), p)

    while t != 1
        i = 1
        tpow = powermod(t, 2, p)
        while tpow != 1
            tpow = mod(tpow * tpow, p)
            i += 1
        end
        po = M - i - 1
        b = powermod(c, big"2"^po, p)
        M = i
        c = powermod(b, 2, p)
        t = mod(t * powermod(b, 2, p), p)
        r = mod(r * b, p)
    end
    return r
end



"""
    hoc_sqrt(a::Integer, p::Integer)

Algorithm from Handbook of cryptography, Koblitz pp 48-49.
Finds a solution to `x^2 == a mod p`.

It assumes such solution exists.

Running time highly depends on |alpha|, assuming
`p-1 = 2^alpha * s`, for an odd `s`.
"""
function hoc_sqrt(a::Integer, p::Integer)
    n = find_quadratic_non_residue(p)
    s = p - 1
    alpha = 0
    while s % 2 == 0
        s = div(s, 2)
        alpha += 1
    end

    inv_a = invmod(a, p)
    b = powermod(n, s, p)
    r = powermod(a, div(s + 1, 2), p)
    r_sqr = powermod(r, 2, p)
    two = BigInt(2)
    expon = two^(alpha - 1)
    for i in 1:alpha - 1
        expon = div(expon, two)
        d = powermod(inv_a * r_sqr, expon, p)
        if d == p - 1
            r = mod(r * b, p)
            r_sqr = powermod(r, two, p)
        end
        b = powermod(b, two, p)
    end
    return r
end



"""
    is_quadratic_residue(a::Integer, p::Integer) -> Bool

Return true or false depending on wheter `a` is a quadratic residue mod `p`.

That is, it checks if `x^2 == a mod p` has solutions.
"""
function is_quadratic_residue(a::Integer, p::Integer)
    if p == oftype(p, 2)
        return true
    end
    return jacobi(a, p) == 1
end



"""
    sqrt_mod_prime(a::Integer, p::Integer) -> Integer

Solves `x^2 == a mod p` and returns one of the square roots `r`.
The other root is `p - r`.
If there are no solutions, throws an exception.

```julia
julia> sqrt_mod_prime(33^2, 73)
33
```
"""
function sqrt_mod_prime(a::Integer, p::Integer)
    a = mod(a, p)
    is_quadratic_residue(a, p) || throw("$a is not a quadratic residue mod $p.")

    if p % 2 == 0
        return a

    elseif p % 4 == 3
        return powermod(a, div(p + 1, 4), p)

    elseif p % 8 == 5
        d = powermod(a, div(p - 1, 4), p)

        if d == 1
            r = powermod(a, div(p + 3, 8), p)
        elseif d == p - 1
            r = mod(2 * a * powermod(4 * a, div(p - 5, 8), p), p)
        end

        return r

    # If p-1 is of the form 2^k*s for large k, use tonelli-shanks.
    # Here k is large if k > 100
    elseif mod(p - 1, 1267650600228229401496703205376) == 0
        return tonelli_shanks(a, p)

    # depends on size of k
    else
        return hoc_sqrt(a, p)
    end
end



"""
    continued_fraction(a::T, b::T) where T <: Integer

Return the continued fraction of the rational `a/b`.

# Example
```julia
julia> continued_fraction(31, 73)
6-element Array{Int64,1}:
 0
 2
 2
 1
 4
 2
```
"""
function continued_fraction(a::T, b::T) where T <: Integer
    r = a // b
    p = Integer(floor(r))
    fraction = typeof(a)[]
    push!(fraction, p)
    f = r - p
    while f != 0
        r = 1 // f
        p = Integer(floor(r))
        push!(fraction, p)
        f = r - p
    end
    return fraction
end



"""
    convergents(a::T, b::T) where T <: Integer

Return the convergents of a rational `a/b`.

# Example
```julia
julia> convergents(31, 73)
6-element Array{Rational,1}:
  0//1
  1//2
  2//5
  3//7
 14//33
 31//73
```
"""
function convergents(a::T, b::T) where T <: Integer
    fraction = continued_fraction(a, b)

    return convergents(fraction)
end



"""
    convergents(cont_fraction::Array)

Return the convergents given the continued fraction of a rational.
"""
function convergents(cont_fraction::Array)

    nums = BigInt[0, 1]
    dens = BigInt[1, 0]

    converg = Rational[]
    for a in cont_fraction
        next_num = a * nums[end] + nums[end - 1]
        next_den = a * dens[end] + dens[end - 1]

        push!(converg, next_num // next_den)
        push!(nums, next_num)
        push!(dens, next_den)
    end
    return converg
end



"""
    solve_quadratic(a::Integer, b::Integer, c::Integer)

Return solutions to the equation `a*x^2 + b*x + c`.

Assumes the solutions are integer.
"""
function solve_quadratic(a::Integer, b::Integer, c::Integer)
    d = isqrt(b^2 - 4 * a * c)
    return div(-b + d, 2 * a), div(-b - d, 2 * a)
end



"""
    surd(n::BigInt, k::Int64)

Return largest integer smaller or equal than the `k`-th root of `n`.
"""
function surd(n::BigInt, k::Int64)
    if k == 1
        return n
    elseif k == 0
        return big"1"
    end

    low = 1
    high = n
    mid = div(low + high, 2)
    while abs(mid^k - n) >= 0.49
        if mid^k < n
            low = mid
        elseif mid^k > n
            high = mid
        end
        mid = div(low + high, 2)
        if high - low == 1
            return low
        end
    end
    return floor(mid)
end


"""
    is_generator(g::Integer, q::Integer, factors::Array) -> Bool

Returns true if `g` is a generator of `Z_q` where `q` is prime and
`factors` is the prime factorization of `q - 1 = p1^e1 * p2^e2 ... * pk^ek`.

```
q = 2^7 * 5 + 1
is_generator(2, q, [2, 5]) -> false
is_generator(3, q, [2, 5]) -> true
```
"""
function is_generator(g::Integer, q::Integer, factors::Array)::Bool
    if q % 2 == 0 && !isprime(q)
        throw("Argument q should be an odd prime.")
    end
    n = q - 1
    for factor in factors
        if powermod(g, div(n,factor), q) == 1
            return false
        end
    end
    return true
end


"""
    get_safe_prime_generator(q::BigInt) -> BigInt

Returns a generator of `Z_q`, where `q = 2 * p + 1` with `q, p` primes.
"""
function get_safe_prime_generator(q::BigInt)::BigInt
    if q % 2 == 0 && !isprime(q)
        throw("Argument q should be an odd prime.")
    end

    p = div(q - 1, 2)
    factors = [2, p]

    @label sample_generator
    g = rand(1 : q - 1)

    if !is_generator(g, q, factors)
        @goto sample_generator
    end

    return g
end



################################################################
##                   Prime number utilities                   ##
################################################################

"""
    random_prime(bitsize::Integer) -> BigInt

Return a random prime with `bitsize` bits.

```
julia> random_prime(42)
2458636110727
```
"""
function random_prime(bitsize::Integer)::BigInt
    n = oneunit(BigInt)
    two = BigInt(2)
    lo = two^(bitsize - 1)
    hi = two^bitsize
    while !isprime(n)
        n = rand(lo:hi)
    end
    return n
end



"""
    tower_two_prime(bitsize::Integer, tower_len::Integer) -> BigInt

Return a random prime of the form `2^towerlen * q + 1`
with `bitsize` bits and where `q` is also a prime.

```
julia> tower_two_prime(22, 6)
2362433
```
"""
function tower_two_prime(bitsize::Integer, tower_len::Integer)::BigInt
    n = oneunit(BigInt)
    tower = big"2"^tower_len
    lo = big"2"^(bitsize - tower_len - 1)
    hi = big"2"^(bitsize - tower_len)
    while !isprime(n)
        n = tower * random_prime(bitsize - tower_len) + 1
    end
    return n
end



"""
    safe_prime(bitsize::Integer) -> BigInt

Return a random safe-prime `q` of the form `q = 2 * p + 1`
where `p` is also a prime number.
The returning prime number has `bitsize` bits.

```
julia> safe_prime(10)
1439
```
"""
function safe_prime(bitsize::Integer)::BigInt
    n = oneunit(BigInt)
    two = BigInt(2)
    while !isprime(n)
        p = random_prime(bitsize - 1)
        n = two * p + 1
    end
    return n
end



"""
    get_first_primes(k::Integer) -> Collection


Output the first `k` prime numbers.

```julia
julia> get_first_primes(10)
10-element Array{Int64,1}:
2
3
5
7
11
13
17
19
23
29
```
"""
function get_first_primes(k::Integer)
    if k <= zero(k)
        return []
    end
    l = log(k + 1)
    hi = max(2, Int(ceil((k + 1) * (l + log(l)))))
    res = primes(hi)
    res = res[1:min(length(res), k)]
    return res
end



"""
    twin_primes(bitsize::Integer)

Return a pair of prime numbers `p, p + 2`
with `bitsize` bits.

This might take a while to run.
"""
function twin_primes(bitsize::Integer)
    q = 1
    p = 1
    while !isprime(q)
        p = random_prime(bitsize)
        q = p + 2
    end
    return p, q
end




################################################################
##                   Conversion utilities                     ##
################################################################

"""
    n2b(n::Integer) -> String

Converts a number to its bytes representation,
effectively writing the number in base 256, and returning
the corresponding bytes.

```julia
julia> n2b(22405534230753963835153736737)
"Hello world!"
```
"""
function n2b(n::Integer)::String
    res::String = ""
    while n != zero(n)
        n, r = divrem(n, 256)
        res = Char(r) * res
    end
    return res
end



"""
    b2n(str::String) -> BigInt

Converts a byte-string to a number,
converting the string from base 256 to base 10.


```julia
julia> b2n("Hello world!")
22405534230753963835153736737
```
"""
function b2n(str::String)::BigInt
    res::BigInt = 0
    for (i, char) in enumerate(reverse(str))
        res += big"256"^(i - 1) * Int(char)
    end
    return res
end




################################################################
##                   Cryptography utilities                   ##
################################################################

"""
    factor_with_ed(n::Integer, e::Integer, d::Integer) -> (Integer, Integer)

Factors `n = p*q` given `(e, d)` such that `e*d = 1 mod phi(n)`
Stinson page 204 - algorithm 5.10
"""
function factor_with_ed(n::Integer, e::Integer, d::Integer)
    k = e * d - 1
    s = 0
    r = k
    while r % 2 == 0
        s += 1
        r = div(r, 2)
    end

    while true
        w = rand(2:n - 1)
        x = gcd(w, n)
        if 1 < x < n
            return x, div(n, x)
        end

        v = powermod(w, r, n)
        v0 = v

        while v != 1
            v0 = v
            v = powermod(v, 2, n)
        end

        if v0 == n - 1
            continue
        end

        x = gcd(v0 + 1, n)
        if 1 < x < n
            return x, div(n, x)
        end
    end
end



"""
    wiener(n::Integer, e::Integer, dujella_bound=20)

Factors the semiprime `n`, assuming Wiener's attack holds:
`d < n^(1/4)`, where `d*e = 1 mod phi(n)`.

Uses Dujella extension attack. Increasing the `dujella_bound` argument
slows the running time but increases chances of finding the correct `d`
in case `d ~ n^(1/4)`.
"""
function wiener(n::Integer, e::Integer, dujella_bound = 20)
    # usual aproximation of k/d
    # convergs = convergents(e, n)

    # better aproximation of k/d
    convergs = convergents(e, n + 1 - 2 * isqrt(n))

    # ignore first convergent 0/1
    deleteat!(convergs, 1)

    old_d = 1

    # ciphertext to test decryption exponent
    test_cipher = powermod(2, e, n)

    # build (r, s) pairs
    # with 1 < s < r < dujella_bound
    # and gcd(r, s) = 1
    # https://bib.irb.hr/datoteka/383127.dujececc.pdf
    pairs_rs = Pair[]
    for r in 1:dujella_bound
        for s in 1:r
            if gcd(r, s) == 1
                push!(pairs_rs, r => s)
            end
        end
    end

    for fraction in convergs
        k = numerator(fraction)
        d = denominator(fraction)

        # regular Wiener attack
        if powermod(test_cipher, d, n) == 2
            phi = div(e * d - 1, k)
            p, q = solve_quadratic(1, phi - n - 1, n)
            @assert p * q == n
            return p, q
        end

        # Dujella extension
        for p in pairs_rs
            dujella = p.first * d + p.second * old_d
            if powermod(test_cipher, dujella, n) == 2
                return factor_with_ed(n, e, dujella)
            end
        end

        old_d = d
    end
end



end # module
