
struct EllipticCurve
    a::BigInt
    b::BigInt
    n::BigInt
end


struct EllipticPoint
    x::BigInt
    y::BigInt
end


function isInfinityPoint(P::EllipticPoint)
    return P.x == -1 && P.y == -1
end


function double(P::EllipticPoint, E::EllipticCurve)::EllipticPoint
    if isInfinityPoint(P)
        return P
    end

    g::BigInt, inv::BigInt, _ = gcdx(2 * P.y, E.n)
    # if g != 1
    #     return g
    # elseif g == E.n
    #     return InfinityPoint()
    # end

    lambda::BigInt = mod((3 * P.x^2 + E.a) * inv, E.n)
    new_x::BigInt = mod(lambda^2 - 2 * P.x, E.n)
    new_y::BigInt = mod(lambda * (P.x - new_x) - P.y, E.n)

    return EllipticPoint(new_x, new_y)
end


function add(P::EllipticPoint, Q::EllipticPoint, E::EllipticCurve)::EllipticPoint
    if isInfinityPoint(P)
        return Q
    elseif isInfinityPoint(Q)
        return P
    end

    if P.x == Q.x && P.y == Q.y
        return double(P, E)
    end

    @time delta_x = mod(Q.x - P.x, E.n)
    @time g::BigInt, inv::BigInt, _ = gcdx(delta_x, E.n)
    # if 1 < g < E.n
    #     return g
    # elseif g == E.n
    #     return InfinityPoint()
    # end

    @time delta_y = mod(Q.y - P.y, E.n)
    @time lambda = mod(delta_y * inv, E.n)
    @time new_x = mod(lambda^2 - P.x - Q.x, E.n)
    @time new_y = mod(lambda * (P.x - new_x) - P.y, E.n)

    return EllipticPoint(new_x, new_y)
end



function InfinityPoint()
    return EllipticPoint(-1, -1)
end


function multiply(k::BigInt, P::EllipticPoint, E::EllipticCurve)::EllipticPoint
    Q = InfinityPoint()

    @inbounds for b in string(k, base = 2)
        Q = double(Q, E)
        # if typeof(Q) != EllipticPoint
        #     return Q
        # end
        if b == '1'
            Q = add(Q, P, E)
            # if typeof(Q) != EllipticPoint
            #     return Q
            # end
        end
    end
    return Q
end


function test_add()

    p = big"115792089210356248762697446949407573530086143415290314195533631308867097853951"
    a = big"-3"
    b = big"41058363725152142129326129780047268409114441015993725554835256314039467401291"
    E = EllipticCurve(a, b, p)

    gx = big"48439561293906451759052585252797914202762949526041747995844080717082404635286"
    gy = big"36134250956749795798585127919587881956611106672985015071877198253568414405109"
    P = EllipticPoint(gx, gy)

    P = add(P, P, E)
    P = add(P, P, E)
    P = add(P, P, E)
    # for i=1:100000
    #     P = add(P, P, E)
    # end
end


function test_mult()

    p = big"115792089210356248762697446949407573530086143415290314195533631308867097853951"
    a = big"-3"
    b = big"41058363725152142129326129780047268409114441015993725554835256314039467401291"
    E = EllipticCurve(a, b, p)

    gx = big"48439561293906451759052585252797914202762949526041747995844080717082404635286"
    gy = big"36134250956749795798585127919587881956611106672985015071877198253568414405109"
    P = EllipticPoint(gx, gy)

    for i=1:100000
        P = multiply(big"123456", P, E)
    end
end

# initial
# 1.211539 seconds (5.45 M allocations: 153.242 MiB, 11.24% gc time)
# 21.950572 seconds (112.61 M allocations: 2.961 GiB, 12.85% gc time)

@time test_add()
# @time test_mult()