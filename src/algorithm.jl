abstract type AbstractTrafficAssigAlgorithm end

@kwdef struct FrankWolfe <: AbstractTrafficAssigAlgorithm
    search_method::AbstractOptimizer = GoldenSection()
    tol::Float64 = 1e-4
    max_iter = 1_000
    trace::Bool = true
end

@kwdef struct ConjugateFrankWolfe <: AbstractTrafficAssigAlgorithm
    search_method::AbstractOptimizer = GoldenSection()
    δ::Float64 = 1e-6
    tol::Float64 = 1e-4
    max_iter = 1_000
    trace::Bool = true
end

@kwdef struct BiconjugateFrankWolfe <: AbstractTrafficAssigAlgorithm
    search_method::AbstractOptimizer = GoldenSection()
    δ::Float64 = 1e-6
    tol::Float64 = 1e-4
    max_iter = 1_000
    trace::Bool = true
end

abstract type AbstractTrafficAssigLogs end

@kwdef mutable struct TrafficAssigLogs <: AbstractTrafficAssigLogs
    best_lower_bound::Float64 = -Inf64
    upper_bound::Float64 = 0.0
    objective::Vector{Float64} = Float64[]
    relative_gap::Vector{Float64} = Float64[]

    exec_time_start::Float64 = time()
    exec_time::Vector{Float64} = Float64[]
end



# One dimensional search
function one_dimensional_search(
    link_performance::AbstractLinkPerformanceImpl,
    flow::Vector{Float64},
    Δflow::Vector{Float64};
    search_method::AbstractOptimizer=GoldenSection()
)
    f(τ) = link_performance_objective(link_performance, @. flow + τ * Δflow)

    one_dimensional_search(
        f,
        search_method=search_method
    )
end

function one_dimensional_search(
    f::Function;
    search_method::AbstractOptimizer=GoldenSection()
)
    opt = optimize(
        f, 0.0, 1.0,
        method=search_method
    )

    τ = opt.minimizer
    obj = opt.minimum

    return τ, obj
end



# Update and trace logs
function start_logs()
    @printf "Start Execution\n"
end

function update_best_lower_bound!(
    logs::AbstractTrafficAssigLogs,
    traffic::TrafficImpl,
    flow::Vector{Float64},
    flow_end::Vector{Float64}
)
    link_performance = traffic.link_performance

    cost = link_performance(
        flow,
        no_thru=false
    )

    lower_bound = link_performance_objective(link_performance, flow) + cost' * (flow_end - flow)
    logs.best_lower_bound = max(logs.best_lower_bound, lower_bound)

    return logs
end

function update_objective!(logs::AbstractTrafficAssigLogs)
    push!(logs.objective, logs.upper_bound)

    return logs
end

function update_relative_gap!(logs::AbstractTrafficAssigLogs)
    best_lower_bound = logs.best_lower_bound

    gap = logs.upper_bound - best_lower_bound

    relative_gap = gap / abs(best_lower_bound)

    push!(logs.relative_gap, relative_gap)

    return logs
end

function update_exec_time!(logs::AbstractTrafficAssigLogs)
    push!(logs.exec_time, time() - logs.exec_time_start)

    return logs
end

function trace_logs(
    iter::Int,
    logs::AbstractTrafficAssigLogs
)
    obj = last(logs.objective)
    relative_gap = last(logs.relative_gap)
    exec_time = last(logs.exec_time)
    @printf "Iteration: %7d, Objective: %13f, Relative-Gap: %7f, Execution-Time: %13.3f\n" iter obj relative_gap exec_time
end
