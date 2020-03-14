using OrdinaryDiffEq, Test, LinearAlgebra, Statistics

# create mass matrix problems
function make_mm_probs(mm_A, ::Val{iip}) where iip
  # iip
  function mm_f(du,u,p,t)
    update_coefficients(mm_A,u,p,t)
    mm_b = vec(sum(mm_A; dims=2))
    mul!(du,mm_A,u)
    du .+= t * mm_b
    nothing
  end
  mm_g(du,u,p,t) = (@. du = u + t; nothing)

  # oop
  mm_f(u,p,t) = mm_A * (u .+ t)
  mm_g(u,p,t) = u .+ t

  mm_analytic(u0, p, t) = @. 2 * u0 * exp(t) - t - 1

  u0 = ones(3)
  tspan = (0.0, 1.0)

  prob = ODEProblem(ODEFunction{iip,true}(mm_f, analytic=mm_analytic, mass_matrix=mm_A), u0, tspan)
  prob2 = ODEProblem(ODEFunction{iip,true}(mm_g, analytic=mm_analytic), u0, tspan)

  prob, prob2
end

function _norm_dsol(alg,prob,prob2,dt=1/10)
  sol = solve(prob,  alg,dt=dt,adaptive=false)
  sol2 = solve(prob2,alg,dt=dt,adaptive=false)
  norm(sol .- sol2)
end

function update_func1(A,u,p,t)
    A[1,1] = cos(t)
    A[2,1] = sin(t)*u[1]
    A[3,1] = t^2
    A[1,2] = cos(t)*sin(t)
    A[2,2] = cos(t)^2 + u[3]
    A[3,2] = sin(t)*u[2]
    A[1,3] = sin(t)
    A[2,3] = t^2
    A[3,3] = t*cos(t) + 1
end

function update_func2(A,u,p,t)
    A[1,1] = cos(t)
    A[2,1] = sin(t)
    A[3,1] = t^2
    A[1,2] = cos(t)*sin(t)
    A[2,2] = cos(t)^2
    A[3,2] = sin(t)
    A[1,3] = sin(t)
    A[2,3] = t^2
    A[3,3] = t*cos(t) + 1
end

almost_I = Matrix{Float64}(1.01I, 3, 3)
mm_A = Float64[-2 1 4; 4 -2 1; 2 1 3]
dependent_M1 = DiffEqArrayOperator(ones(3,3),update_func=update_func1)
dependent_M2 = DiffEqArrayOperator(ones(3,3),update_func=update_func2)

@testset "Mass Matrix Accuracy Tests" for mm in (almost_I, mm_A)
  # test each method for exactness
  for iip in (false, true)
    prob, prob2 = make_mm_probs(mm, Val(iip))

    @test _norm_dsol(ImplicitEuler(),prob,prob2) ≈ 0 atol=1e-7
    @test _norm_dsol(RadauIIA5(),prob,prob2) ≈ 0 atol=1e-12
    @test _norm_dsol(ImplicitMidpoint(extrapolant = :constant),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(Rosenbrock23(),prob,prob2) ≈ 0 atol=1e-11
    @test _norm_dsol(Rosenbrock32(),prob,prob2) ≈ 0 atol=1e-11
    @test _norm_dsol(ROS3P(),prob,prob2) ≈ 0 atol=1e-11
    @test _norm_dsol(Rodas3(),prob,prob2) ≈ 0 atol=1e-11
    @test _norm_dsol(RosShamp4(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(Veldd4(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(Velds4(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(GRK4T(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(GRK4A(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(Ros4LStab(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(RosenbrockW6S4OS(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(ROS34PW1a(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(ROS34PW1b(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(ROS34PW2(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(ROS34PW3(),prob,prob2) ≈ 0 atol=1e-10
    @test _norm_dsol(Rodas4(),prob,prob2) ≈ 0 atol=1e-9
    @test _norm_dsol(Rodas42(),prob,prob2) ≈ 0 atol=1e-9
    @test _norm_dsol(Rodas4P(),prob,prob2) ≈ 0 atol=1e-9
    @test _norm_dsol(Rodas5(),prob,prob2) ≈ 0 atol=1e-7
  end

  # test functional iteration
  for iip in (false, true)
    prob, prob2 = make_mm_probs(mm, Val(iip))

    sol = solve(prob,ImplicitEuler(
                          nlsolve=NLFunctional()),dt=1/10,adaptive=false,reltol=1e-7,abstol=1e-10)
    sol2 = solve(prob2,ImplicitEuler(nlsolve=NLFunctional()),dt=1/10,adaptive=false,reltol=1e-7,abstol=1e-10)
    @test norm(sol .- sol2) ≈ 0 atol=1e-7

    sol = solve(prob, ImplicitMidpoint(extrapolant = :constant,
                          nlsolve=NLFunctional()),dt=1/10,reltol=1e-7,abstol=1e-10)
    sol2 = solve(prob2,ImplicitMidpoint(extrapolant = :constant, nlsolve=NLFunctional()),dt=1/10,reltol=1e-7,abstol=1e-10)
    @test norm(sol .- sol2) ≈ 0 atol=1e-7

    sol = solve(prob,ImplicitEuler(nlsolve=NLAnderson()),dt=1/10,adaptive=false)
    sol2 = solve(prob2,ImplicitEuler(nlsolve=NLAnderson()),dt=1/10,adaptive=false)
    @test norm(sol .- sol2) ≈ 0 atol=1e-7
    @test norm(sol[end] .- sol2[end]) ≈ 0 atol=1e-7

    sol = solve(prob, ImplicitMidpoint(extrapolant = :constant, nlsolve=NLAnderson()),dt=1/10,reltol=1e-7,abstol=1e-10)
    sol2 = solve(prob2,ImplicitMidpoint(extrapolant = :constant, nlsolve=NLAnderson()),dt=1/10,reltol=1e-7,abstol=1e-10)
    @test norm(sol .- sol2) ≈ 0 atol=1e-7
    @test norm(sol[end] .- sol2[end]) ≈ 0 atol=1e-7
  end
end

# Singular mass matrices

@testset "Mass Matrix Tests with Singular Mass Matrices" begin
  function f!(du, u, p, t)
      du[1] = u[2]
      du[2] = u[2] - 1.
      return
  end

  u0 = [0.,1.]
  tspan = (0.0, 1.0)

  M = fill(0., 2,2)
  M[1,1] = 1.

  m_ode_prob = ODEProblem(ODEFunction(f!;mass_matrix=M), u0, tspan)
  @test_nowarn sol = solve(m_ode_prob, Rosenbrock23())

  M = [0.637947  0.637947
       0.637947  0.637947]

  inv(M) # not caught as singular

  function f2!(du, u, p, t)
      du[1] = u[2]
      du[2] = u[1]
      return
  end
  u0 = zeros(2)

  m_ode_prob = ODEProblem(ODEFunction(f2!;mass_matrix=M), u0, tspan)
  sol1 = @test_nowarn solve(m_ode_prob, Rosenbrock23(), reltol=1e-10, abstol=1e-10)
  sol2 = @test_nowarn solve(m_ode_prob, RadauIIA5(), reltol=1e-10, abstol=1e-10)
  sol3 = @test_nowarn solve(m_ode_prob, Cash4(), reltol=1e-10, abstol=1e-10)
  @test sol1[end] ≈ sol2[end] atol=1e-9
  @test sol1[end] ≈ sol3[end] atol=1e-9
end

prob, prob2 = make_mm_probs(dependent_M1, Val(true))
_norm_dsol(ImplicitEuler(),prob,prob2,1/100000)
_norm_dsol(RadauIIA5(),prob,prob2,1/100000)
_norm_dsol(ImplicitMidpoint(extrapolant = :constant),prob,prob2,1/1000000)
_norm_dsol(Rosenbrock23(),prob,prob2,1/100000)
_norm_dsol(Rodas4(),prob,prob2,1/100000)
_norm_dsol(Rodas5(),prob,prob2,1/1000000)
_norm_dsol(ROS34PW1a(),prob,prob2,1/100000)
_norm_dsol(RosenbrockW6S4OS(),prob,prob2,1/10000)

prob, prob2 = make_mm_probs(dependent_M2, Val(true))
_norm_dsol(ImplicitEuler(),prob,prob2,1/100000)
_norm_dsol(RadauIIA5(),prob,prob2,1/100000)
_norm_dsol(ImplicitMidpoint(extrapolant = :constant),prob,prob2,1/1000000)
_norm_dsol(Rosenbrock23(),prob,prob2,1/100000)
_norm_dsol(Rodas4(),prob,prob2,1/100000)
_norm_dsol(Rodas5(),prob,prob2,1/1000000)
_norm_dsol(ROS34PW1a(),prob,prob2,1/100000)
_norm_dsol(RosenbrockW6S4OS(),prob,prob2,1/10000)
