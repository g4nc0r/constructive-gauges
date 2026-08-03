/-
Lemma 1: the in-range probability under the Brownian price model.

Under (M1) the log-price is a driftless Brownian motion, so `X(s) ∼ N(0, σ²s)`
and for a static position of half-width `a` ticks centred at `τ(0)`,

  `P_in(s) = P(|X(s)| < a η) = 2 Φ(a η / (σ √s)) - 1`,

with `η = log 1.0001` and `Φ` the standard normal CDF. The time average
`P̄_in(δt)` of eq. (4) is that pointwise law integrated over the cycle, which
is `Pbar` in `Defs.lean`; the Fubini step the paper cites is the definition of
the time average, so the content of the lemma is the pointwise identity,
proved here as `gaussian_two_sided` and specialised in `Pin_eq`.

Also proved: `Pin_antitoneOn`, the shape condition on `P_in` that Theorem 1's
Chebyshev step requires, that the in-range probability is non-increasing.

Mathlib has a cumulative distribution function for an arbitrary real measure,
`ProbabilityTheory.cdf`, but no Gaussian instance of it. `Phi` below is that
generic CDF at `gaussianReal 0 1`, which inherits monotonicity and the two
tail limits from mathlib; the Gaussian-specific facts this file needs, namely
the reflection `Phi (-x) = 1 - Phi x` and the scaling of a general centred
Gaussian onto the standard one, are proved here.
-/
import Mathlib
import ConstructiveGauges.Defs

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory ProbabilityTheory Set

/-! ## The standard normal CDF -/

/-- The standard normal cumulative distribution function, as mathlib's generic
`cdf` instantiated at the standard Gaussian. -/
noncomputable def Phi (x : ℝ) : ℝ := cdf (gaussianReal 0 1) x

/-- `Phi` in measure form. -/
theorem Phi_eq_measureReal (x : ℝ) : Phi x = (gaussianReal 0 1).real (Iic x) :=
  cdf_eq_real _ x

theorem Phi_monotone : Monotone Phi := monotone_cdf _

theorem Phi_nonneg (x : ℝ) : 0 ≤ Phi x := cdf_nonneg _ x

theorem Phi_le_one (x : ℝ) : Phi x ≤ 1 := cdf_le_one _ x

/-- A centred Gaussian of positive variance puts no mass on a point. -/
theorem gaussian_singleton {v : NNReal} (hv : v ≠ 0) (x : ℝ) :
    (gaussianReal 0 v) {x} = 0 :=
  (nullSingletonClass_gaussianReal hv).measure_singleton x

/-- Left-closed and left-open lower sets carry the same Gaussian mass. -/
theorem gaussian_Iic_eq_Iio {v : NNReal} (hv : v ≠ 0) (x : ℝ) :
    (gaussianReal 0 v) (Iic x) = (gaussianReal 0 v) (Iio x) := by
  refine le_antisymm ?_ (measure_mono Iio_subset_Iic_self)
  calc (gaussianReal 0 v) (Iic x) = (gaussianReal 0 v) (Iio x ∪ {x}) := by
        rw [Iio_union_right]
    _ ≤ (gaussianReal 0 v) (Iio x) + (gaussianReal 0 v) {x} := measure_union_le _ _
    _ = (gaussianReal 0 v) (Iio x) := by rw [gaussian_singleton hv, add_zero]

/-- Half-open and open intervals carry the same Gaussian mass. -/
theorem gaussian_Ioo_eq_Ioc {v : NNReal} (hv : v ≠ 0) (a b : ℝ) :
    (gaussianReal 0 v) (Ioo a b) = (gaussianReal 0 v) (Ioc a b) := by
  refine le_antisymm (measure_mono Ioo_subset_Ioc_self) ?_
  have hsub : Ioc a b ⊆ Ioo a b ∪ {b} := by
    intro y hy
    rcases eq_or_lt_of_le hy.2 with h | h
    · exact Or.inr h
    · exact Or.inl ⟨hy.1, h⟩
  calc (gaussianReal 0 v) (Ioc a b) ≤ (gaussianReal 0 v) (Ioo a b ∪ {b}) :=
        measure_mono hsub
    _ ≤ (gaussianReal 0 v) (Ioo a b) + (gaussianReal 0 v) {b} := measure_union_le _ _
    _ = (gaussianReal 0 v) (Ioo a b) := by rw [gaussian_singleton hv, add_zero]

/-- **Symmetry of the standard normal CDF**, `Φ(-x) = 1 - Φ(x)`. -/
theorem Phi_neg (x : ℝ) : Phi (-x) = 1 - Phi x := by
  have hmap : (gaussianReal 0 1).map (fun y : ℝ ↦ -y) = gaussianReal 0 1 := by
    rw [gaussianReal_map_neg, neg_zero]
  have h1 : (gaussianReal 0 1) (Iic (-x)) = (gaussianReal 0 1) (Ioi x) := by
    rw [gaussian_Iic_eq_Iio one_ne_zero]
    conv_lhs => rw [← hmap]
    rw [Measure.map_apply measurable_neg measurableSet_Iio]
    congr 1
    ext y
    simp only [mem_preimage, mem_Iio, mem_Ioi, neg_lt_neg_iff]
  have h2 : (gaussianReal 0 1) (Ioi x) = 1 - (gaussianReal 0 1) (Iic x) := by
    rw [← compl_Iic, measure_compl measurableSet_Iic (measure_ne_top _ _), measure_univ]
  have hle : (gaussianReal 0 1) (Iic x) ≤ 1 := prob_le_one
  rw [Phi_eq_measureReal, Phi_eq_measureReal, measureReal_def, measureReal_def, h1, h2,
    ENNReal.toReal_sub_of_le hle ENNReal.one_ne_top, ENNReal.toReal_one]

/-! ## Scaling to unit variance -/

/-- The CDF of `N(0, v)` in terms of the standard normal CDF. -/
theorem gaussian_cdf_scale {v : NNReal} (hv : v ≠ 0) (x : ℝ) :
    (gaussianReal 0 v).real (Iic x) = Phi (x / Real.sqrt v) := by
  have hvpos : (0 : ℝ) < (v : ℝ) := NNReal.coe_pos.2 (pos_iff_ne_zero.mpr hv)
  have hs : 0 < Real.sqrt (v : ℝ) := Real.sqrt_pos.2 hvpos
  have hmap : (gaussianReal 0 1).map (fun y : ℝ ↦ Real.sqrt (v : ℝ) * y) = gaussianReal 0 v := by
    rw [gaussianReal_map_const_mul]
    congr 1
    · rw [mul_zero]
    · rw [mul_one]
      exact NNReal.coe_injective (by simp [Real.sq_sqrt hvpos.le])
  have hpre : (fun y : ℝ ↦ Real.sqrt (v : ℝ) * y) ⁻¹' (Iic x) = Iic (x / Real.sqrt (v : ℝ)) := by
    ext y
    simp only [mem_preimage, mem_Iic, le_div_iff₀ hs]
    constructor
    · intro h; linarith [h, mul_comm (Real.sqrt (v : ℝ)) y]
    · intro h; linarith [h, mul_comm (Real.sqrt (v : ℝ)) y]
  rw [Phi_eq_measureReal, measureReal_def, measureReal_def]
  conv_lhs => rw [← hmap]
  rw [Measure.map_apply (by fun_prop) measurableSet_Iic, hpre]

/-! ## Lemma 1 -/

/-- **Lemma 1, pointwise form.** For `X ∼ N(0, v)` with `v > 0` and `r ≥ 0`,

  `P(|X| < r) = 2 Φ(r / √v) - 1`.

Taking `v = σ² s` and `r = a η` gives the paper's
`P_in(s) = 2 Φ(a η / (σ √s)) - 1`. -/
theorem gaussian_two_sided {v : NNReal} (hv : v ≠ 0) {r : ℝ} (hr : 0 ≤ r) :
    (gaussianReal 0 v).real (Ioo (-r) r) = 2 * Phi (r / Real.sqrt v) - 1 := by
  have hvpos : (0 : ℝ) < (v : ℝ) := NNReal.coe_pos.2 (pos_iff_ne_zero.mpr hv)
  have hs : 0 < Real.sqrt (v : ℝ) := Real.sqrt_pos.2 hvpos
  have hdiff : Iic r \ Iic (-r) = Ioc (-r) r := by
    ext y; simp only [Set.mem_sdiff, mem_Iic, mem_Ioc, not_le]; tauto
  have hIoc : (gaussianReal 0 v).real (Ioc (-r) r)
      = (gaussianReal 0 v).real (Iic r) - (gaussianReal 0 v).real (Iic (-r)) := by
    rw [← hdiff]
    exact measureReal_sdiff (Iic_subset_Iic.2 (by linarith)) measurableSet_Iic
      (measure_ne_top _ _)
  have hOo : (gaussianReal 0 v).real (Ioo (-r) r) = (gaussianReal 0 v).real (Ioc (-r) r) := by
    rw [measureReal_def, measureReal_def, gaussian_Ioo_eq_Ioc hv]
  have hneg : (-r) / Real.sqrt (v : ℝ) = -(r / Real.sqrt (v : ℝ)) := by ring
  rw [hOo, hIoc, gaussian_cdf_scale hv, gaussian_cdf_scale hv, hneg, Phi_neg]
  ring

/-- The variance of `X(s)` under (M1) has `√(σ² s) = σ √s`. -/
theorem sqrt_variance {σ s : ℝ} (hσ : 0 ≤ σ) (_hs : 0 ≤ s) :
    Real.sqrt (σ ^ 2 * s) = σ * Real.sqrt s := by
  rw [Real.sqrt_mul (by positivity), Real.sqrt_sq hσ]

/-! ## The in-range probability as a function of elapsed time -/

/-- The pointwise in-range probability of Appendix A,
`P_in(s) = 2 Φ(a η / (σ √s)) - 1`. -/
noncomputable def Pin (a η σ s : ℝ) : ℝ := 2 * Phi (a * η / (σ * Real.sqrt s)) - 1

/-- `Pin` is exactly the two-sided Gaussian mass of Lemma 1 when the variance
is `σ² s`. -/
theorem Pin_eq {a η σ s : ℝ} {v : NNReal} (hv : v ≠ 0) (hσ : 0 ≤ σ) (hs : 0 ≤ s)
    (hr : 0 ≤ a * η) (hveq : (v : ℝ) = σ ^ 2 * s) :
    (gaussianReal 0 v).real (Ioo (-(a * η)) (a * η)) = Pin a η σ s := by
  rw [gaussian_two_sided hv hr, Pin, hveq, sqrt_variance hσ hs]

/-- **Shape condition for Theorem 1's Chebyshev step.** The in-range
probability is non-increasing in elapsed time: a static position drifts out of
range, never back in, in expectation. -/
theorem Pin_antitoneOn {a η σ : ℝ} (hr : 0 < a * η) (hσ : 0 < σ) :
    AntitoneOn (Pin a η σ) (Ioi 0) := by
  intro x hx y hy hxy
  have hx0 : (0 : ℝ) < x := hx
  have hy0 : (0 : ℝ) < y := hy
  have hsx : 0 < Real.sqrt x := Real.sqrt_pos.2 hx0
  have hsy : 0 < Real.sqrt y := Real.sqrt_pos.2 hy0
  have hle : Real.sqrt x ≤ Real.sqrt y := Real.sqrt_le_sqrt hxy
  have hdx : 0 < σ * Real.sqrt x := by positivity
  have hdy : 0 < σ * Real.sqrt y := by positivity
  have hd : σ * Real.sqrt x ≤ σ * Real.sqrt y := by nlinarith
  have hquot : a * η / (σ * Real.sqrt y) ≤ a * η / (σ * Real.sqrt x) := by
    rw [div_le_div_iff₀ hdy hdx]
    exact mul_le_mul_of_nonneg_left hd hr.le
  have := Phi_monotone hquot
  unfold Pin
  linarith

/-- The in-range probability is at most one, directly from `Phi ≤ 1`. -/
theorem Pin_le_one (a η σ s : ℝ) : Pin a η σ s ≤ 1 := by
  have := Phi_le_one (a * η / (σ * Real.sqrt s))
  unfold Pin
  linarith

/-- The in-range probability is non-negative. Unlike the upper bound this is
not immediate from `Phi`, since it needs `Phi ≥ 1/2` on the non-negative axis;
it is read off the two-sided mass of Lemma 1 instead. -/
theorem Pin_nonneg {a η σ s : ℝ} (hr : 0 ≤ a * η) (hs : 0 ≤ s) {v : NNReal} (hv : v ≠ 0)
    (hσ : 0 ≤ σ) (hveq : (v : ℝ) = σ ^ 2 * s) : 0 ≤ Pin a η σ s := by
  rw [← Pin_eq hv hσ hs hr hveq]
  exact measureReal_nonneg

end ConstructiveGauges
