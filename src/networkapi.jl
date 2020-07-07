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


### Macros for using DSL notation to modify an already created network. ###

# # Creates a new network by making addition to an already existing one.
# macro add_reactions(network, ex::Expr, parameters...)
#     #To be written
# end

# # modifies an already existing reaction network by adding new reactions.
# macro add_reactions!(network, ex::Expr, parameters...)
#     #To be written
# end


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
    issetequal(zip(rn1.substrates,rn1.substoich), zip(rn2.substrates,rn2.substoich)) || return false
    issetequal(zip(rn1.products,rn1.prodstoich), zip(rn2.products,rn2.prodstoich)) || return false
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
    issetequal(equations(rn1), equations(rn2))
    for sys1 in rn1.systems, sys2 in rn2.systems
        (sy1 == sys2) || return false
    end
end

######################## functions to extend a network ####################

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
    addspecies!(network::ReactionSystem, speciesop::Operation)

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
id of `rx` in list of `Reaction`s within `network`.

Notes: 
- Any new species or parameters used in `rx` should be separately added
to `network` using [`addspecies!`](@ref) and [`addparams!`](@ref).
"""
function addreaction!(network::ReactionSystem, rx::Reaction)    
    push!(network.equations, rx)
    length(equations(network))
end

