# Functions for querying network properties.

######### Accessors: #########

"""
    species(network)

Given an `ReactionSystem`, return a vector of species `Variable`s.
"""
function species(network)
    states(network)
end

"""
    params(network)

Given an `ReactionSystem`, return a vector of parameter `Variable`s.
"""
function params(network)
    parameters(network)
end

"""
    speciesmap(network)

Given an `ReactionSystem`, return a Dictionary mapping from species
`Variable`s to species indices. (Allocates)
"""
function speciesmap(network)
    Dict(S => i for (i,S) in enumerate(species(network)))
end

"""
    paramsmap(network)

Given an `ReactionSystem`, return a Dictionary mapping from parameter
`Variable`s to parameter indices. (Allocates)
"""
function paramsmap(network)
    Dict(p => i for (i,p) in enumerate(params(network)))
end

"""
    numspecies(network)

Return the number of species within the given `ReactionSystem`.
"""
function numspecies(network)
    length(species(network))
end

"""
    numreactions(network)

Return the number of reactions within the given `ReactionSystem`.
"""
function numreactions(network)
    length(equations(network))
end

"""
    numparams(network)

Return the number of parameters within the given `ReactionSystem`.
"""
function numparams(network)
    length(params(network))
end

"""
    rateexpr(network, rxidx)

Given a `ReactionSystem`, return the ModelingToolkit reaction rate
`Operation` for the reaction with index `rxidx`. Note, for a reaction
defined by

`k*X*Y, X+Z --> 2X + Y`

the expression that is returned will be `k*X*Y`, while the *rate law* used in
ODEs and SDEs would be `k*X^2*Y*Z`.
"""
function rateexpr(network, rxidx)
    equations(network)[rxidx].rate
end

"""
    oderatelawexpr(network, rxidx)

Given a `ReactionSystem`, return the ModelingToolkit reaction rate law
`Operation` used in generated ODEs for the reaction with index `rxidx`.
Note, for a reaction defined by

`k*X*Y, X+Z --> 2X + Y`

the expression that is returned will be `k*X^2*Y*Z`. For a reaction of
the form 

`k, 2X+3Y --> Z`

the `Operation` that is returned will be `k * (X(t)^2/2) * (Y(t)^3/6)`. 

Notes:
- Allocates
""" 
function oderatelawexpr(network, rxidx)
    ModelingToolkit.oderatelaw(equations(network)[rxidx])
end

"""
    ssaratelawexpr(network, rxidx)

Given a `ReactionSystem`, return the ModelingToolkit reaction rate law
`Operation` used in generated stochastic chemical kinetics model SSAs for the
reaction with index `rxidx`. Note, for a reaction defined by

`k*X*Y, X+Z --> 2X + Y`

the expression that is returned will be `:(k*X^2*Y*Z)`. For a reaction of
the form 

`k, 2X+3Y --> Z`

the `Operation` that is returned will be `:(k * binomial(X,2) *
binomial(Y,3))`.

Notes:
- Allocates
""" 
function ssaratelawexpr(network, rxidx)
    ModelingToolkit.jumpratelaw(equations(network)[rxidx])
end

"""
    ismassaction(network::ReactionSystem, rxidx; kwargs...)

Given a `ReactionSystem` and a reaction index, `rxidx`, return a boolean
indicating whether the given reaction is of mass action form. For example,
the reaction

`2*k, 2X + 3Y --> 5Z + W`

would return true, while reactions with state-dependent rates like

`k*X, X + Y --> Z`

would return false. `kwargs` can be any options given by
[`ModelingToolkit.ismassaction`](https://mtk.sciml.ai/stable/systems/ReactionSystem/#ModelingToolkit.ismassaction).

Notes:
- Allocates unless all `ModelingToolkit.ismassaction` `kwargs` are provided.
"""
function ismassaction(network::ReactionSystem, rxidx::Int; kwargs...)
    ModelingToolkit.ismassaction(equations(network)[rxidx], network; kwargs...)
end

"""
    dependents(network, rxidx)

Given a `ReactionSystem` and a reaction index, `rxidx`, return a vector of
`ModelingToolkit` `Operations`s corresponding to species the *reaction rate
law* depends on. i.e. for

`k*W, 2X + 3Y --> 5Z + W`

the returned vector would be `[W(t),X(t),Y(t)]`.

Notes:
- Allocates
"""
function dependents(network, rxidx)
    rx = equations(network)[rxidx]
    rvars = ModelingToolkit.get_variables(rx.rate, states(network))
    return union!(rvars, rx.substrates)
end

"""
    dependants(network, rxidx)

See documentation for [`dependents(network, rxidx)`](@ref).
"""
function dependants(network, rxidx)
    dependents(network, rxidx)
end

######################## reaction network operators #######################

"""
    ==(rn1::ModelingToolkit.Reaction, rn2::ModelingToolkit.Reaction)

Tests whether two `ModelingToolkit.Reaction`s are identical.

Notes:
- Ignores the order in which stoichiometry components are listed.
- *Does not* currently simplify rates, so a rate of `A^2+2*A+1` would be
considered different than `(A+1)^2`.
"""
function (==)(rn1::Reaction, rn2::Reaction)
    isequal(rn1.rate, rn2.rate) || return false
    opit = sv -> (s.op for s in sv)
    issetequal(zip(opit(rn1.substrates),rn1.substoich), zip(opit(rn2.substrates),rn2.substoich)) || return false
    issetequal(zip(opit(rn1.products),rn1.prodstoich), zip(opit(rn2.products),rn2.prodstoich)) || return false
    issetequal(rn1.netstoich, rn2.netstoich)
end


"""
    ==(rn1::ReactionSystem, rn2::ReactionSystem)

Tests whether the underlying species `Variables`s, parameter `Variables`s and reactions
are the same in the two networks. Ignores order network components were defined.

Notes:
- *Does not* currently simplify rates, so a rate of `A^2+2*A+1` would be considered
different than `(A+1)^2`.
"""
function (==)(rn1::ReactionSystem, rn2::ReactionSystem)
    issetequal(species(rn1), species(rn2)) || return false
    issetequal(params(rn1), params(rn2)) || return false
    isequal(rn1.iv, rn2.iv) || return false
    (numreactions(rn1) == numreactions(rn2)) || return false

    # the following fails for some reason, so need to use issubset
    #issetequal(equations(rn1), equations(rn2)) || return false
    (issubset(equations(rn1),equations(rn2)) && issubset(equations(rn2),equations(rn1))) || return false

    #issetequal(rn1.systems, rn2.systems) || return false
    sys1 = rn1.systems; sys2 = rn2.systems
    (issubset(sys1,sys2) && issubset(sys2,sys1)) || return false
    true
end


######################## functions to extend a network ####################

"""
    make_empty_network(; iv=Variable(:t))

Construct an empty `ReactionSystem`. `iv` is the independent variable, usually time.
"""
function make_empty_network(; iv=Variable(:t))
    ReactionSystem(Reaction[], iv, Operation[], Operation[], gensym(:ReactionSystem), ReactionSystem[])
end

"""
    addspecies!(network::ReactionSystem, s::Variable)

Given a `ReactionSystem`, add the species corresponding to the variable `s`
to the network (if it is not already defined). Returns the integer id
of the species within the system.
"""
function addspecies!(network::ReactionSystem, s::Variable)
    curidx = findfirst(S -> isequal(S, s), species(network))
    if curidx === nothing
        push!(network.states, s)
        return length(species(network))
    else
        return curidx
    end
end

"""
    addspecies!(network::ReactionSystem, s::Operation)

Given a `ReactionSystem`, add the species corresponding to the variable `s`
to the network (if it is not already defined). Returns the integer id
of the species within the system.
"""
function addspecies!(network::ReactionSystem, s::Operation)
    !(s.op isa Variable) && error("If the passed in species is an Operation, it must correspond to an underlying Variable.")
    addspecies!(network, convert(Variable,s))
end

"""
    addparam!(network::ReactionSystem, p::Variable)

Given a `ReactionSystem`, add the parameter corresponding to the variable `p`
to the network (if it is not already defined). Returns the integer id
of the parameter within the system.
"""
function addparam!(network::ReactionSystem, p::Variable)
    curidx = findfirst(S -> isequal(S, p), params(network))
    if curidx === nothing
        push!(network.ps, p)
        return length(params(network))
    else
        return curidx
    end
end

"""
    addparam!(network::ReactionSystem, p::Operation)

Given a `ReactionSystem`, add the parameter corresponding to the variable `p`
to the network (if it is not already defined). Returns the integer id
of the parameter within the system.
"""
function addparam!(network::ReactionSystem, p::Operation)
    !(p.op isa Variable) && error("If the passed in parameter is an Operation, it must correspond to an underlying Variable.")
    addparam!(network, convert(Variable,p))
end

"""
    addreaction!(network::ReactionSystem, rx::Reaction)

Add the passed in reaction to the `ReactionSystem`. Returns the integer
id of `rx` in the list of `Reaction`s within `network`.

Notes:
- Any new species or parameters used in `rx` should be separately added
to `network` using [`addspecies!`](@ref) and [`addparams!`](@ref).
"""
function addreaction!(network::ReactionSystem, rx::Reaction)
    push!(network.eqs, rx)
    length(equations(network))
end


"""
    merge!(network1::ReactionSystem, network2::ReactionSystem)

Merge `network2` into `network1`.

Notes:
- Duplicate reactions between the two networks are not filtered out.
- `Reaction`s are not deepcopied to minimize allocations, so both networks will share underlying data arrays.
- Returns `network1`
"""
function merge!(network1::ReactionSystem, network2::ReactionSystem)
    isequal(network1.iv, network2.iv) || error("Reaction networks must have the same independent variable to be mergable.")
    specs = species(network1)
    foreach(spec -> !(spec in specs) && push!(specs, spec), species(network2))
    ps = params(network1)
    foreach(p -> !(p in ps) && push!(ps, p), params(network2))
    append!(network1.eqs, network2.eqs)
    append!(network1.systems, network2.systems)
    network1
end

"""
    merge(network1::ReactionSystem, network2::ReactionSystem)

Create a new network merging `network1` and `network2`.

Notes:
- Duplicate reactions between the two networks are not filtered out.
- `Reaction`s are not deepcopied to minimize allocations, so the new network will share underlying data arrays.
- Returns the merged network.
"""
function merge(network1::ReactionSystem, network2::ReactionSystem)
    network = make_empty_network()
    merge!(network, network1)
    merge!(network, network2)
    network
end

