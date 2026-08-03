/-
Theorem 3: minimal completeness of the three-factor scoring family.

The abstract product family `𝓕` is indexed by subsets `K ⊆ {c, f, 1}`, with
`S^K = L · c_K · f_K · 1_K`. The theorem asserts that `S^K` closes all three
parasitic pathways of Definition 1 if and only if `K = {c, f, 1}`, with the
`K \ {c}` row carrying the theorem's own footnote: it presumes the cap
`c_max` is dropped alongside `c`.

What is proved here:

* `closesSC_iff` - the short-cycle pathway is closed exactly when `f ∈ K`.
* `closesOOR_iff` - the out-of-range pathway is closed exactly when `1 ∈ K`.
* `minimal_completeness_attack_rows` - the conjunction, giving the iff on
  those two rows.
* `wa_bounded` - per-unit-capital revenue is bounded at fixed
  `(w_min, c_max)`, for every `K`, including `K` without `c`.
* `wa_unbounded_without_wmin` - without minimum-width enforcement it is
  unbounded, again for every `K`.

The last two make the paper's footnote precise. In this model the width
arbitrage pathway is closed by minimum-width enforcement together with the
cap, not by the presence of the `c` multiplier: the divergence at narrow
widths comes from `L ∝ C/w`, which is there whether or not `c` sits in the
score. The `iff` in the theorem statement therefore rests entirely on the
cap-dropping convention of the footnote, and `c`'s role in the reverse
direction is scoring-family expressivity rather than attack closure, which is
what the paper's own §5.4 discussion says. The two attack rows are unaffected.
-/
import Mathlib
import ConstructiveGauges.Defs
import ConstructiveGauges.Freshness

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory Set Filter Topology

/-! ## The abstract family -/

/-- A member of the scoring family `𝓕`, indexed by which of the three
multipliers is present. -/
structure Factors where
  hasC : Bool
  hasF : Bool
  hasInd : Bool

/-- The full three-factor scoring function `S^{c, f, 1}`. -/
def Factors.full : Factors := ⟨true, true, true⟩

/-- The fixed deployment against which family members are compared: reward
rate, position liquidity, pool liquidity, background total score, warmup,
minimum width, concentration cap. -/
structure GaugeModel where
  lam : ℝ
  L : ℝ
  Lp : ℝ
  Stot : ℝ
  W : ℝ
  wmin : ℝ
  cmax : ℝ
  hlam : 0 < lam
  hL : 0 < L
  hLp : 0 < Lp
  hStot : 0 < Stot
  hW : 0 < W
  hwmin : 0 < wmin
  hcmax : 1 ≤ cmax

variable {K : Factors} {c ind : ℝ → ℝ} {w W T s : ℝ}

/-! ## The three multipliers -/

/-- The concentration multiplier under `K`: `c(w)` if `c ∈ K`, else unity. -/
noncomputable def cFac (K : Factors) (c : ℝ → ℝ) (w : ℝ) : ℝ := if K.hasC then c w else 1

/-- The freshness multiplier under `K`. -/
noncomputable def fFac (K : Factors) (W s : ℝ) : ℝ := if K.hasF then ramp W s else 1

/-- The in-range multiplier under `K`. -/
noncomputable def iFac (K : Factors) (ind : ℝ → ℝ) (s : ℝ) : ℝ := if K.hasInd then ind s else 1

theorem cFac_of_hasC (h : K.hasC = true) : cFac K c w = c w := by simp [cFac, h]

theorem cFac_of_not_hasC (h : K.hasC = false) : cFac K c w = 1 := by simp [cFac, h]

theorem cFac_pos (hc : 0 < c w) : 0 < cFac K c w := by
  rcases hb : K.hasC with _ | _
  · rw [cFac_of_not_hasC hb]; norm_num
  · rw [cFac_of_hasC hb]; exact hc

theorem cFac_le_cmax {cmax : ℝ} (h1 : 1 ≤ cmax) (hcap : c w ≤ cmax) : cFac K c w ≤ cmax := by
  rcases hb : K.hasC with _ | _
  · rw [cFac_of_not_hasC hb]; exact h1
  · rw [cFac_of_hasC hb]; exact hcap

theorem cFac_mono {w w' : ℝ} (h : c w ≤ c w') : cFac K c w ≤ cFac K c w' := by
  rcases hb : K.hasC with _ | _
  · rw [cFac_of_not_hasC hb, cFac_of_not_hasC hb]
  · rw [cFac_of_hasC hb, cFac_of_hasC hb]; exact h

theorem fFac_of_hasF (h : K.hasF = true) : fFac K W s = ramp W s := by simp [fFac, h]

theorem fFac_of_not_hasF (h : K.hasF = false) : fFac K W s = 1 := by simp [fFac, h]

theorem iFac_one : iFac K (fun _ ↦ (1:ℝ)) s = 1 := by
  rcases hb : K.hasInd with _ | _ <;> simp [iFac, hb]

theorem iFac_zero_of_hasInd (h : K.hasInd = true) : iFac K (fun _ ↦ (0 : ℝ)) s = 0 := by
  simp [iFac, h]

theorem iFac_of_not_hasInd (h : K.hasInd = false) : iFac K ind s = 1 := by simp [iFac, h]

/-! ## Scores and revenues -/

/-- The score of a static position of width `w` under family member `K`. -/
noncomputable def scoreK (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ)
    (ind : ℝ → ℝ) (s : ℝ) : ℝ :=
  M.L * cFac K c w * fFac K M.W s * iFac K ind s

/-- Operator revenue under family member `K` over a cycle `[0, T]`. -/
noncomputable def revK (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ)
    (ind : ℝ → ℝ) (T : ℝ) : ℝ :=
  M.lam / M.Stot * ∫ s in (0 : ℝ)..T, scoreK M K c w ind s

/-- Operator revenue under the standard concentrated liquidity accumulator. -/
noncomputable def revStd (M : GaugeModel) (ind : ℝ → ℝ) (T : ℝ) : ℝ :=
  M.lam * M.L / M.Lp * ∫ s in (0 : ℝ)..T, ind s

theorem integral_fFac_of_hasF (h : K.hasF = true) (hW : 0 < W) (hT : 0 ≤ T) (hTW : T ≤ W) :
    ∫ s in (0 : ℝ)..T, fFac K W s = T ^ 2 / (2 * W) := by
  simp_rw [fFac_of_hasF h]
  exact integral_ramp_of_le hW hT hTW

theorem integral_fFac_of_not_hasF (h : K.hasF = false) :
    ∫ s in (0 : ℝ)..T, fFac K W s = T := by
  simp_rw [fFac_of_not_hasF h]
  simp

theorem revStd_in_range (M : GaugeModel) :
    revStd M (fun _ ↦ 1) T = M.lam * M.L / M.Lp * T := by
  rw [revStd]; simp

/-- Revenue for a position that stays in range, with the freshness factor
present and a cycle no longer than the warmup: `Θ(T²)`. -/
theorem revK_in_range_of_hasF (M : GaugeModel) (h : K.hasF = true) (hT : 0 ≤ T)
    (hTW : T ≤ M.W) :
    revK M K c w (fun _ ↦ 1) T
      = M.lam * M.L * cFac K c w / M.Stot * (T ^ 2 / (2 * M.W)) := by
  have hpt : ∀ s : ℝ, scoreK M K c w (fun _ ↦ 1) s = (M.L * cFac K c w) * fFac K M.W s := by
    intro s; rw [scoreK, iFac_one]; ring
  rw [revK]
  simp_rw [hpt]
  rw [intervalIntegral.integral_const_mul, integral_fFac_of_hasF h M.hW hT hTW]
  ring

/-- Revenue for a position that stays in range, with the freshness factor
absent: `Θ(T)`, the same order as the standard accumulator. -/
theorem revK_in_range_of_not_hasF (M : GaugeModel) (h : K.hasF = false) :
    revK M K c w (fun _ ↦ 1) T = M.lam * M.L * cFac K c w / M.Stot * T := by
  have hpt : ∀ s : ℝ, scoreK M K c w (fun _ ↦ 1) s = (M.L * cFac K c w) * fFac K M.W s := by
    intro s; rw [scoreK, iFac_one]; ring
  rw [revK]
  simp_rw [hpt]
  rw [intervalIntegral.integral_const_mul, integral_fFac_of_not_hasF h]
  ring

/-! ## The short-cycle pathway -/

/-- The short-cycle pathway is closed under `K` when the revenue ratio against
the standard accumulator vanishes as the cycle length goes to zero. Compare
Definition 1: the pathway is *admitted* when the `liminf` of that ratio is
strictly positive. -/
def ClosesSC (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ) : Prop :=
  Tendsto (fun T ↦ revK M K c w (fun _ ↦ 1) T / revStd M (fun _ ↦ 1) T)
    (𝓝[>] (0 : ℝ)) (𝓝 0)

theorem sc_ratio_of_hasF (M : GaugeModel) (h : K.hasF = true) (hT : 0 < T) (hTW : T ≤ M.W) :
    revK M K c w (fun _ ↦ 1) T / revStd M (fun _ ↦ 1) T
      = cFac K c w * M.Lp / M.Stot * (T / (2 * M.W)) := by
  have hlam := M.hlam
  have hL := M.hL
  have hLp := M.hLp
  have hStot := M.hStot
  have hW := M.hW
  rw [revK_in_range_of_hasF M h hT.le hTW, revStd_in_range]
  field_simp

theorem sc_ratio_of_not_hasF (M : GaugeModel) (h : K.hasF = false) (hT : 0 < T) :
    revK M K c w (fun _ ↦ 1) T / revStd M (fun _ ↦ 1) T = cFac K c w * M.Lp / M.Stot := by
  have hlam := M.hlam
  have hL := M.hL
  have hLp := M.hLp
  have hStot := M.hStot
  rw [revK_in_range_of_not_hasF M h, revStd_in_range]
  field_simp

/-- **Theorem 3, short-cycle row.** The short-cycle pathway is closed exactly
when the freshness factor is present. Without it both revenues scale as
`Θ(δt)` and the ratio stays bounded away from zero; with it the corrective
revenue is `Θ(δt²)` and the ratio vanishes linearly. -/
theorem closesSC_iff (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ) (hcw : 0 < c w) :
    ClosesSC M K c w ↔ K.hasF = true := by
  have hStot := M.hStot
  have hLp := M.hLp
  have hcK : 0 < cFac K c w := cFac_pos hcw
  set A : ℝ := cFac K c w * M.Lp / M.Stot with hA
  have hApos : 0 < A := by rw [hA]; positivity
  constructor
  · intro h
    by_contra hf
    simp only [Bool.not_eq_true] at hf
    have heq : (fun T ↦ revK M K c w (fun _ ↦ 1) T / revStd M (fun _ ↦ 1) T)
        =ᶠ[𝓝[>] (0 : ℝ)] fun _ ↦ A := by
      filter_upwards [self_mem_nhdsWithin] with T hT
      exact sc_ratio_of_not_hasF M hf hT
    have h0 : Tendsto (fun _ : ℝ ↦ A) (𝓝[>] (0 : ℝ)) (𝓝 0) := h.congr' heq
    have := tendsto_nhds_unique h0 tendsto_const_nhds
    exact absurd this.symm hApos.ne'
  · intro hf
    have heq : (fun T ↦ revK M K c w (fun _ ↦ 1) T / revStd M (fun _ ↦ 1) T)
        =ᶠ[𝓝[>] (0 : ℝ)] fun T ↦ A * (T / (2 * M.W)) := by
      filter_upwards [self_mem_nhdsWithin,
        eventually_nhdsWithin_of_eventually_nhds (eventually_lt_nhds M.hW)] with T hT hTW
      exact sc_ratio_of_hasF M hf hT hTW.le
    refine Tendsto.congr' heq.symm ?_
    have hcont : Tendsto (fun T : ℝ ↦ A * (T / (2 * M.W))) (𝓝 0) (𝓝 (A * (0 / (2 * M.W)))) :=
      ((continuous_id.div_const (2 * M.W)).const_mul A).tendsto 0
    simpa using hcont.mono_left nhdsWithin_le_nhds

/-! ## The out-of-range pathway -/

/-- The out-of-range pathway is closed under `K` when a position accrues no
revenue on an interval throughout which the tick lies outside its range. -/
def ClosesOOR (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ) : Prop :=
  ∀ T : ℝ, revK M K c w (fun _ ↦ 0) T = 0

/-- **Theorem 3, out-of-range row.** The out-of-range pathway is closed
exactly when the in-range indicator is present. -/
theorem closesOOR_iff (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ) (hcw : 0 < c w) :
    ClosesOOR M K c w ↔ K.hasInd = true := by
  have hlam := M.hlam
  have hL := M.hL
  have hStot := M.hStot
  have hW := M.hW
  have hcK : 0 < cFac K c w := cFac_pos hcw
  constructor
  · intro h
    by_contra hind
    simp only [Bool.not_eq_true] at hind
    have hpt : ∀ s : ℝ, scoreK M K c w (fun _ ↦ 0) s = (M.L * cFac K c w) * fFac K M.W s := by
      intro s; rw [scoreK, iFac_of_not_hasInd hind]; ring
    have hspec := h M.W
    rw [revK] at hspec
    simp_rw [hpt] at hspec
    rw [intervalIntegral.integral_const_mul] at hspec
    rcases hb : K.hasF with _ | _
    · rw [integral_fFac_of_not_hasF hb] at hspec
      have : M.lam / M.Stot * (M.L * cFac K c w * M.W) > 0 := by positivity
      rw [hspec] at this
      exact lt_irrefl 0 this
    · rw [integral_fFac_of_hasF hb M.hW M.hW.le le_rfl] at hspec
      have : M.lam / M.Stot * (M.L * cFac K c w * (M.W ^ 2 / (2 * M.W))) > 0 := by positivity
      rw [hspec] at this
      exact lt_irrefl 0 this
  · intro hind T
    have hpt : ∀ s : ℝ, scoreK M K c w (fun _ ↦ 0) s = 0 := by
      intro s; rw [scoreK, iFac_zero_of_hasInd hind]; ring
    rw [revK]
    simp_rw [hpt]
    simp

/-! ## The two attack rows together -/

/-- **Theorem 3, the two attack rows.** Within the family, the short-cycle and
out-of-range pathways are closed if and only if the freshness weight and the
in-range indicator are both present. This is the part of the minimal
completeness characterisation that is an attack-closure statement at fixed
deployment parameters. -/
theorem minimal_completeness_attack_rows (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ)
    (hcw : 0 < c w) :
    (ClosesSC M K c w ∧ ClosesOOR M K c w) ↔ (K.hasF = true ∧ K.hasInd = true) :=
  and_congr (closesSC_iff M K c w hcw) (closesOOR_iff M K c w hcw)

/-- The full three-factor member closes both attack pathways. -/
theorem full_closes_attack_rows (M : GaugeModel) (c : ℝ → ℝ) (w : ℝ) (hcw : 0 < c w) :
    ClosesSC M Factors.full c w ∧ ClosesOOR M Factors.full c w :=
  (minimal_completeness_attack_rows M Factors.full c w hcw).2 ⟨rfl, rfl⟩

/-! ## The width arbitrage row -/

/-- Per-unit-capital revenue rate at width `w`. At fixed capital `C` the
nominal liquidity of a narrow position scales as `L ∝ C / w`, so the rate
carries a `1 / w` alongside the concentration weight. -/
noncomputable def perCapitalRate (M : GaugeModel) (K : Factors) (c : ℝ → ℝ) (w : ℝ) : ℝ :=
  M.lam * cFac K c w / (w * M.Stot)

/-- **Width arbitrage is closed by minimum-width enforcement together with the
cap, for every family member.** The bound holds whether or not the
concentration factor is present. -/
theorem wa_bounded (M : GaugeModel) (K : Factors) (c : ℝ → ℝ)
    (hc0 : ∀ x, 0 ≤ c x) (hcap : ∀ x, c x ≤ M.cmax) {w : ℝ} (hw : M.wmin ≤ w) :
    perCapitalRate M K c w ≤ M.lam * M.cmax / (M.wmin * M.Stot) := by
  have hlam := M.hlam
  have hStot := M.hStot
  have hwmin := M.hwmin
  have hcmaxpos : 0 < M.cmax := lt_of_lt_of_le zero_lt_one M.hcmax
  have hw0 : 0 < w := lt_of_lt_of_le hwmin hw
  have hcK : cFac K c w ≤ M.cmax := cFac_le_cmax M.hcmax (hcap w)
  have hcKnn : 0 ≤ cFac K c w := by
    rcases hb : K.hasC with _ | _
    · rw [cFac_of_not_hasC hb]; norm_num
    · rw [cFac_of_hasC hb]; exact hc0 w
  rw [perCapitalRate, div_le_div_iff₀ (by positivity) (by positivity)]
  have h1 : M.lam * cFac K c w ≤ M.lam * M.cmax := mul_le_mul_of_nonneg_left hcK hlam.le
  have h2 : M.wmin * M.Stot ≤ w * M.Stot := by nlinarith
  exact mul_le_mul h1 h2 (by positivity) (by positivity)

/-- **Width arbitrage reopens when minimum-width enforcement is dropped, for
every family member.** The divergence at narrow widths comes from `L ∝ C / w`,
not from the concentration multiplier: it is there with or without `c` in the
score. Together with `wa_bounded` this makes the theorem's footnote precise. -/
theorem wa_unbounded_without_wmin (M : GaugeModel) (K : Factors) (c : ℝ → ℝ)
    (hc : AntitoneOn c (Ioi 0)) {w : ℝ} (hw : 0 < w) (hcw : 0 < c w) (B : ℝ) :
    ∃ w' : ℝ, 0 < w' ∧ w' ≤ w ∧ B < perCapitalRate M K c w' := by
  have hlam := M.hlam
  have hStot := M.hStot
  have hcK : 0 < cFac K c w := cFac_pos hcw
  have hBpos : (0 : ℝ) < max B 0 + 1 := by have := le_max_right B 0; linarith
  set Y : ℝ := M.lam * cFac K c w with hY
  have hYpos : 0 < Y := by rw [hY]; positivity
  set X : ℝ := Y / ((max B 0 + 1) * M.Stot) with hX
  have hXpos : 0 < X := by rw [hX]; positivity
  refine ⟨min w X, lt_min hw hXpos, min_le_left _ _, ?_⟩
  set w' : ℝ := min w X with hw'
  have hw'pos : 0 < w' := lt_min hw hXpos
  have hw'X : w' ≤ X := min_le_right _ _
  have hw'w : w' ≤ w := min_le_left _ _
  have hcmono : cFac K c w ≤ cFac K c w' :=
    cFac_mono (hc (mem_Ioi.2 hw'pos) (mem_Ioi.2 hw) hw'w)
  have e1 : X * M.Stot = Y / (max B 0 + 1) := by rw [hX]; field_simp
  have e2 : B * (w' * M.Stot) ≤ max B 0 * (X * M.Stot) := by
    have hb : B ≤ max B 0 := le_max_left _ _
    have hm : (0 : ℝ) ≤ max B 0 := le_max_right _ _
    have hws : (0 : ℝ) ≤ w' * M.Stot := by positivity
    have hxs : w' * M.Stot ≤ X * M.Stot := by nlinarith
    calc B * (w' * M.Stot) ≤ max B 0 * (w' * M.Stot) := mul_le_mul_of_nonneg_right hb hws
      _ ≤ max B 0 * (X * M.Stot) := mul_le_mul_of_nonneg_left hxs hm
  have e3 : max B 0 * (X * M.Stot) < Y := by
    rw [e1, mul_div_assoc', div_lt_iff₀ hBpos]
    nlinarith
  have e4 : Y ≤ M.lam * cFac K c w' := by
    rw [hY]
    exact mul_le_mul_of_nonneg_left hcmono hlam.le
  rw [perCapitalRate, lt_div_iff₀ (by positivity)]
  linarith

end ConstructiveGauges
