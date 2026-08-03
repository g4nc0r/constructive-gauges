/-
Lemma 2: total-score concentration.

The paper states that for `N` independent LPs with per-LP scores satisfying
`E[S_j] ≥ m` and `Var(S_j) ≤ V`, the total score concentrates around its
expectation with relative fluctuation `O(1/√N)`. The proof is variance
additivity followed by Chebyshev.

`total_score_concentration` below is the explicit finite-`N` form of that
statement, which is what the asymptotic notation abbreviates: for any relative
tolerance `ε`,

  `P(|S_total - E[S_total]| ≥ ε N m)  ≤  V / (N m² ε²)`.

The right-hand side is `O(1/N)` in the probability, hence `O(1/√N)` in the
relative fluctuation, and the bound is uniform in the tolerance. This is the
one place in the formalisation where the `O(N^{-1/2})` error terms carried
through Theorems 1 and 2 are quantified; the theorem files themselves work
with the mean-field reduced functionals of `Defs.lean`.

The positive-dependence variant of the remark following Lemma 2 (finite
dependence range `d_max`, giving `Var ≤ N V d_max`) is not formalised; the
paper defers the weak-dependence treatment to future work.
-/
import Mathlib
import ConstructiveGauges.Defs

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory ProbabilityTheory

variable {Ω ι : Type*} [MeasurableSpace Ω] {P : Measure Ω}

/-- Variance additivity for the total score, under pairwise independence. -/
theorem variance_total_score {S : ι → Ω → ℝ} {s : Finset ι}
    (hmem : ∀ i ∈ s, MemLp (S i) 2 P)
    (hindep : Set.Pairwise (↑s : Set ι) fun i j ↦ IndepFun (S i) (S j) P) {V : ℝ}
    (hV : ∀ i ∈ s, variance (S i) P ≤ V) :
    variance (∑ i ∈ s, S i) P ≤ s.card * V := by
  rw [IndepFun.variance_sum hmem hindep]
  calc ∑ i ∈ s, variance (S i) P ≤ ∑ _i ∈ s, V := Finset.sum_le_sum hV
    _ = s.card * V := by rw [Finset.sum_const, nsmul_eq_mul]

/-- **Lemma 2 (total-score concentration), explicit form.** For pairwise
independent per-LP scores with variance at most `V` and mean at least `m > 0`,
the total score deviates from its mean by more than a relative tolerance `ε`
with probability at most `V / (N m² ε²)`.

The paper's `O(1/√N)` relative fluctuation is this bound read at fixed
confidence: the deviation scale that keeps the right-hand side constant is
`ε ∝ N^{-1/2}`. -/
theorem total_score_concentration [IsFiniteMeasure P] {S : ι → Ω → ℝ} {s : Finset ι}
    (hmem : ∀ i ∈ s, MemLp (S i) 2 P)
    (hindep : Set.Pairwise (↑s : Set ι) fun i j ↦ IndepFun (S i) (S j) P)
    {m V ε : ℝ} (hm : 0 < m) (hε : 0 < ε) (hcard : 0 < s.card)
    (hV : ∀ i ∈ s, variance (S i) P ≤ V)
    (hmemSum : MemLp (∑ i ∈ s, S i) 2 P) :
    P {ω | ε * (s.card * m) ≤ |(∑ i ∈ s, S i) ω - P[∑ i ∈ s, S i]|}
      ≤ ENNReal.ofReal (V / (s.card * m ^ 2 * ε ^ 2)) := by
  have hN : (0 : ℝ) < (s.card : ℝ) := by exact_mod_cast hcard
  have hc : 0 < ε * (s.card * m) := by positivity
  have hcheb := meas_ge_le_variance_div_sq (μ := P) hmemSum hc
  refine hcheb.trans (ENNReal.ofReal_le_ofReal ?_)
  have hvar : variance (∑ i ∈ s, S i) P ≤ s.card * V := variance_total_score hmem hindep hV
  have hden : (0 : ℝ) < (ε * (s.card * m)) ^ 2 := by positivity
  rw [div_le_div_iff₀ hden (by positivity)]
  have hexp : (ε * ((s.card : ℝ) * m)) ^ 2 = (s.card : ℝ) * (s.card * m ^ 2 * ε ^ 2) := by
    ring
  calc variance (∑ i ∈ s, S i) P * ((s.card : ℝ) * m ^ 2 * ε ^ 2)
      ≤ ((s.card : ℝ) * V) * ((s.card : ℝ) * m ^ 2 * ε ^ 2) := by
        exact mul_le_mul_of_nonneg_right hvar (by positivity)
    _ = V * (ε * ((s.card : ℝ) * m)) ^ 2 := by rw [hexp]; ring

end ConstructiveGauges
