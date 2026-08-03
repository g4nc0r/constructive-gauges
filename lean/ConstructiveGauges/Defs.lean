/-
Shared definitions for the Lean formalisation of "Constructive Gauges".

The scoring function of §4.1 (eq. 2), the derived freshness averages of
Appendix A, and the mean-field revenue functionals that Theorems 1 and 2
compare. Every theorem file imports this one.

Scope note. The revenue functionals below are the *mean-field reduced* forms
of Appendix B, Steps 1 and 2: the pool-liquidity and total-score processes
have already been replaced by their expectations. That replacement is the
`O(N^{-1/2})` step, quantified separately in `Concentration.lean`
(Lemma 2). The theorems in `ExtractionBound.lean` and `YieldEquality.lean`
are therefore exact statements about the reduced quantities, carrying no error
term of their own.
-/
import Mathlib

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory

/-! ## Scoring function (§4.1, eq. 2) -/

/-- Per-position score of eq. (2),
`S_i(t) = L_i · c(w_i) · f(t - t_i) · 1[τ(t) ∈ [ℓ_i, u_i]]`.

`cw` is the already-evaluated concentration weight `c(w_i)`, `f` the freshness
weight, `t₀` the last-rebalance time, and `ind` the in-range indicator, a
`{0,1}`-valued function of time. -/
noncomputable def score (L cw : ℝ) (f : ℝ → ℝ) (t₀ : ℝ) (ind : ℝ → ℝ) (t : ℝ) : ℝ :=
  L * cw * f (t - t₀) * ind t

/-- The freshness ramp of assumption (M4), `f(x) = min (x / W) 1`. -/
noncomputable def ramp (W x : ℝ) : ℝ := min (x / W) 1

/-! ## Derived freshness averages (Appendix A) -/

/-- Time-averaged freshness `f̄(T) = (1/T) ∫₀ᵀ f(s) ds`. -/
noncomputable def fbar (f : ℝ → ℝ) (T : ℝ) : ℝ := (∫ s in (0 : ℝ)..T, f s) / T

/-- In-range-weighted freshness `f̃(T)`, eq. (9):
`f̃(T) = ∫₀ᵀ f(s) P(s) ds / ∫₀ᵀ P(s) ds`. -/
noncomputable def ftilde (f P : ℝ → ℝ) (T : ℝ) : ℝ :=
  (∫ s in (0 : ℝ)..T, f s * P s) / (∫ s in (0 : ℝ)..T, P s)

/-- Time-averaged in-range probability `P̄_in(T) = (1/T) ∫₀ᵀ P(s) ds`
(Lemma 1). -/
noncomputable def Pbar (P : ℝ → ℝ) (T : ℝ) : ℝ := (∫ s in (0 : ℝ)..T, P s) / T

/-! ## Mean-field revenue functionals (Appendix B, Steps 1 and 2) -/

/-- Expected standard-gauge revenue after the mean-field reduction,
`E[R^std] = (λ L / L̄_p) ∫₀ᵀ P(s) ds` (Appendix B, Step 1). -/
noncomputable def meanRevStd (lam L Lbar : ℝ) (P : ℝ → ℝ) (T : ℝ) : ℝ :=
  lam * L / Lbar * ∫ s in (0 : ℝ)..T, P s

/-- Expected corrective-gauge revenue after the mean-field reduction,
`E[R^corr] = (λ L c(w) / (L̄_p c_ref f_eq)) ∫₀ᵀ f(s) P(s) ds`
(Appendix B, Step 2). -/
noncomputable def meanRevCorr (lam L Lbar cw cref feq : ℝ) (f P : ℝ → ℝ) (T : ℝ) : ℝ :=
  lam * L * cw / (Lbar * cref * feq) * ∫ s in (0 : ℝ)..T, f s * P s

/-! ## Synthetix accumulator (Appendix C, Proposition 2) -/

/-- The per-position reward accumulator `A_i(t) = ∫₀ᵗ λ S_i(s) / S_total(s) ds`
of the continuous-accrual Synthetix form. -/
noncomputable def accrual (lam : ℝ) (S Stot : ℝ → ℝ) (t : ℝ) : ℝ :=
  ∫ s in (0 : ℝ)..t, lam * S s / Stot s

end ConstructiveGauges
