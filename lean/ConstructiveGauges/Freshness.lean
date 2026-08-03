/-
The freshness ramp and its time average.

Appendix A, eq. (8): for the linear ramp `f(x) = min (x/W) 1` of assumption
(M4) the time-averaged freshness has the closed form

  `f̄(T) = T / (2W)`      for `T ≤ W`,
  `f̄(T) = 1 - W / (2T)`  for `T > W`.

Everything the paper draws from that closed form is proved here: the shape
conditions on the ramp used by Theorem 1's Chebyshev step, strict monotonicity
of `f̄` (Proposition 1, rebalance-spam self-defeat), the short-cycle limit
`f̄(T) → 0` (Corollary 1) and the long-cycle saturation `f̄(T) → 1`
(Corollary 2).
-/
import Mathlib
import ConstructiveGauges.Defs

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory Set Filter Topology

variable {W : ℝ}

/-! ## Shape conditions on the ramp -/

theorem continuous_ramp : Continuous (ramp W) :=
  (continuous_id.div_const W).min continuous_const

theorem ramp_intervalIntegrable (a b : ℝ) : IntervalIntegrable (ramp W) volume a b :=
  continuous_ramp.intervalIntegrable a b

theorem ramp_le_one (x : ℝ) : ramp W x ≤ 1 := min_le_right _ _

theorem ramp_nonneg (hW : 0 < W) {x : ℝ} (hx : 0 ≤ x) : 0 ≤ ramp W x :=
  le_min (div_nonneg hx hW.le) zero_le_one

/-- The ramp is non-decreasing: the shape condition Theorem 1's Chebyshev step
needs of `f`. -/
theorem ramp_monotone (hW : 0 < W) : Monotone (ramp W) := by
  intro x y hxy
  exact min_le_min (by gcongr) le_rfl

theorem ramp_monotoneOn (hW : 0 < W) (s : Set ℝ) : MonotoneOn (ramp W) s :=
  (ramp_monotone hW).monotoneOn s

/-- Below the warmup the ramp is the bare linear function. -/
theorem ramp_eq_linear (hW : 0 < W) {x : ℝ} (hx : x ≤ W) : ramp W x = x / W :=
  min_eq_left (by rw [div_le_one hW]; exact hx)

/-- At or above the warmup the ramp is saturated. -/
theorem ramp_eq_one (hW : 0 < W) {x : ℝ} (hx : W ≤ x) : ramp W x = 1 :=
  min_eq_right (by rw [le_div_iff₀ hW]; linarith)

/-! ## The closed form of `f̄` (Appendix A, eq. 8) -/

/-- The ramp integral below the warmup. -/
theorem integral_ramp_of_le (hW : 0 < W) {T : ℝ} (hT : 0 ≤ T) (hTW : T ≤ W) :
    ∫ s in (0 : ℝ)..T, ramp W s = T ^ 2 / (2 * W) := by
  have hcongr : ∀ s ∈ uIcc (0 : ℝ) T, ramp W s = s / W := by
    intro s hs
    rw [uIcc_of_le hT] at hs
    exact ramp_eq_linear hW (le_trans hs.2 hTW)
  rw [intervalIntegral.integral_congr hcongr]
  simp only [div_eq_mul_inv]
  rw [intervalIntegral.integral_mul_const, integral_id]
  field_simp
  ring

/-- Short-cycle branch: `f̄(T) = T / (2W)` for `0 < T ≤ W`. -/
theorem fbar_ramp_of_le (hW : 0 < W) {T : ℝ} (hT : 0 < T) (hTW : T ≤ W) :
    fbar (ramp W) T = T / (2 * W) := by
  rw [fbar, integral_ramp_of_le hW hT.le hTW]
  field_simp

/-- Long-cycle branch: `f̄(T) = 1 - W / (2T)` for `T > W > 0`. -/
theorem fbar_ramp_of_gt (hW : 0 < W) {T : ℝ} (hTW : W < T) :
    fbar (ramp W) T = 1 - W / (2 * T) := by
  have hT : 0 < T := lt_trans hW hTW
  have hsplit : ∫ s in (0 : ℝ)..T, ramp W s
      = (∫ s in (0 : ℝ)..W, ramp W s) + ∫ s in W..T, ramp W s :=
    (intervalIntegral.integral_add_adjacent_intervals
      (ramp_intervalIntegrable 0 W) (ramp_intervalIntegrable W T)).symm
  have h1 : ∫ s in (0 : ℝ)..W, ramp W s = W / 2 := by
    rw [integral_ramp_of_le hW hW.le le_rfl]
    field_simp
  have h2 : ∫ s in W..T, ramp W s = T - W := by
    have hcongr : ∀ s ∈ uIcc W T, ramp W s = 1 := by
      intro s hs
      rw [uIcc_of_le hTW.le] at hs
      exact ramp_eq_one hW hs.1
    rw [intervalIntegral.integral_congr hcongr]
    simp
  rw [fbar, hsplit, h1, h2]
  field_simp
  ring

/-- `f̄` is strictly positive on positive cycle lengths. -/
theorem fbar_ramp_pos (hW : 0 < W) {T : ℝ} (hT : 0 < T) : 0 < fbar (ramp W) T := by
  rcases le_or_gt T W with h | h
  · rw [fbar_ramp_of_le hW hT h]; positivity
  · rw [fbar_ramp_of_gt hW h]
    have : W / (2 * T) < 1 := by
      rw [div_lt_one (by linarith)]; linarith
    linarith

/-- `f̄` never exceeds unity. -/
theorem fbar_ramp_le_one (hW : 0 < W) {T : ℝ} (hT : 0 < T) : fbar (ramp W) T ≤ 1 := by
  rcases le_or_gt T W with h | h
  · rw [fbar_ramp_of_le hW hT h, div_le_one (by linarith)]; linarith
  · rw [fbar_ramp_of_gt hW h]
    have : 0 < W / (2 * T) := by positivity
    linarith

/-! ## Strict monotonicity and Proposition 1 -/

/-- `f̄` is strictly increasing in the cycle length. The three branches are
`T ≤ W`, the crossover, and `T > W`; the two closed forms agree at `T = W`,
where both equal one half. -/
theorem fbar_ramp_strictMonoOn (hW : 0 < W) : StrictMonoOn (fbar (ramp W)) (Ioi 0) := by
  intro x hx y hy hxy
  have hx0 : 0 < x := hx
  have hy0 : 0 < y := hy
  rcases le_or_gt y W with hyW | hyW
  · rw [fbar_ramp_of_le hW hx0 (le_trans hxy.le hyW), fbar_ramp_of_le hW hy0 hyW]
    gcongr
  · rcases le_or_gt x W with hxW | hxW
    · rw [fbar_ramp_of_le hW hx0 hxW, fbar_ramp_of_gt hW hyW]
      have h1 : x / (2 * W) ≤ 1 / 2 := by
        rw [div_le_div_iff₀ (by linarith) (by norm_num)]; linarith
      have h2 : W / (2 * y) < 1 / 2 := by
        rw [div_lt_div_iff₀ (by linarith) (by norm_num)]; linarith
      linarith
    · rw [fbar_ramp_of_gt hW hxW, fbar_ramp_of_gt hW hyW]
      have : W / (2 * y) < W / (2 * x) := by
        apply div_lt_div_of_pos_left hW (by linarith) (by linarith)
      linarith

/-- **Proposition 1 (rebalance-spam self-defeat).** An LP rebalancing at
interval `ρ` strictly below the population cadence `ρ_legit` attains strictly
lower time-averaged freshness, hence (via Theorem 2's decomposition) a
freshness factor strictly below unity. Independent of gas costs. -/
theorem rebalance_spam_self_defeat (hW : 0 < W) {ρ ρlegit : ℝ} (hρ : 0 < ρ)
    (hlt : ρ < ρlegit) : fbar (ramp W) ρ < fbar (ramp W) ρlegit :=
  fbar_ramp_strictMonoOn hW hρ (lt_trans hρ hlt) hlt

/-- The freshness factor entering Theorem 2's yield ratio is strictly below
unity for a spamming LP. -/
theorem spam_freshness_factor_lt_one (hW : 0 < W) {ρ ρlegit : ℝ} (hρ : 0 < ρ)
    (hlt : ρ < ρlegit) :
    fbar (ramp W) ρ / fbar (ramp W) ρlegit < 1 := by
  have hpos : 0 < fbar (ramp W) ρlegit := fbar_ramp_pos hW (lt_trans hρ hlt)
  rw [div_lt_one hpos]
  exact rebalance_spam_self_defeat hW hρ hlt

/-! ## The two cycle-length regimes (Corollaries 1 and 2) -/

/-- **Corollary 1 (short-cycle regime).** The time-averaged freshness vanishes
linearly as the cycle length goes to zero, so the extraction bound of
Theorem 1 vanishes with it. -/
theorem fbar_ramp_tendsto_zero (hW : 0 < W) :
    Tendsto (fbar (ramp W)) (𝓝[>] (0 : ℝ)) (𝓝 0) := by
  have heq : fbar (ramp W) =ᶠ[𝓝[>] (0 : ℝ)] fun T ↦ T / (2 * W) := by
    filter_upwards [self_mem_nhdsWithin, eventually_nhdsWithin_of_eventually_nhds
      (eventually_lt_nhds hW)] with T hT hTW
    exact fbar_ramp_of_le hW hT hTW.le
  refine Tendsto.congr' heq.symm ?_
  have : Tendsto (fun T : ℝ ↦ T / (2 * W)) (𝓝 0) (𝓝 (0 / (2 * W))) :=
    (continuous_id.div_const (2 * W)).tendsto 0
  simpa using this.mono_left nhdsWithin_le_nhds

/-- **Corollary 2 (long-cycle saturation).** The time-averaged freshness
saturates at unity, so the extraction bound saturates at
`(1 / f_eq) (c(w_min) / c_ref)`. -/
theorem fbar_ramp_tendsto_one (hW : 0 < W) :
    Tendsto (fbar (ramp W)) atTop (𝓝 1) := by
  have heq : fbar (ramp W) =ᶠ[atTop] fun T ↦ 1 - W / (2 * T) := by
    filter_upwards [eventually_gt_atTop W] with T hT
    exact fbar_ramp_of_gt hW hT
  refine Tendsto.congr' heq.symm ?_
  have : Tendsto (fun T : ℝ ↦ W / (2 * T)) atTop (𝓝 0) := by
    have h2 : Tendsto (fun T : ℝ ↦ 2 * T) atTop atTop :=
      tendsto_id.const_mul_atTop (by norm_num : (0:ℝ) < 2)
    exact Filter.Tendsto.div_atTop tendsto_const_nhds h2
  simpa using tendsto_const_nhds.sub this

end ConstructiveGauges
