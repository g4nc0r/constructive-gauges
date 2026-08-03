/-
Chebyshev's anti-monotone integral inequality.

Appendix B, Step 3 of "Constructive Gauges" and the upper envelope of
Corollary 3 both rest on the integral form of Chebyshev's sum inequality: for
`f` non-decreasing and `g` non-increasing on `(0, T]`,

  `T · ∫₀ᵀ f g  ≤  (∫₀ᵀ f) (∫₀ᵀ g)`,

equivalently `(1/T) ∫ f g ≤ f̄ · ḡ`. Mathlib carries the finite-sum form
(`AntivaryOn.card_mul_sum_le_sum_mul_sum`) but no integral form, so it is
proved here from the standard product-measure identity

  `∫∫ (f x - f y)(g x - g y) = 2 (‖μ‖ ∫ f g - (∫ f)(∫ g)) ≤ 0`.

The general finite-measure statement is `antivary_integral_mul_le`; the
interval-integral specialisation used by the paper is
`intervalIntegral_mul_le_of_monotone_antitone`.
-/
import Mathlib
import ConstructiveGauges.Defs

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory Set

/-! ## The general finite-measure form -/

/-- **Chebyshev's anti-monotone integral inequality**, finite-measure form.

If `(f x - f y) (g x - g y) ≤ 0` almost everywhere on the product (the
continuous analogue of `f` and `g` antivarying), then

  `μ(univ) · ∫ f g ∂μ ≤ (∫ f ∂μ) (∫ g ∂μ)`. -/
theorem antivary_integral_mul_le {α : Type*} [MeasurableSpace α] {μ : Measure α}
    [IsFiniteMeasure μ] {f g : α → ℝ} (hf : Integrable f μ) (hg : Integrable g μ)
    (hfg : Integrable (fun x ↦ f x * g x) μ)
    (h : ∀ᵐ p ∂(μ.prod μ), (f p.1 - f p.2) * (g p.1 - g p.2) ≤ 0) :
    (μ univ).toReal * ∫ x, f x * g x ∂μ ≤ (∫ x, f x ∂μ) * (∫ x, g x ∂μ) := by
  set m : ℝ := (μ univ).toReal with hm
  set A : ℝ := ∫ x, f x ∂μ with hA
  set B : ℝ := ∫ x, g x ∂μ with hB
  set C : ℝ := ∫ x, f x * g x ∂μ with hC
  -- the four pieces of the expanded product, each integrable on `μ.prod μ`
  have i1 : Integrable (fun p : α × α ↦ f p.1 * g p.1) (μ.prod μ) := hfg.comp_fst μ
  have i2 : Integrable (fun p : α × α ↦ f p.1 * g p.2) (μ.prod μ) := hf.mul_prod hg
  have i3 : Integrable (fun p : α × α ↦ f p.2 * g p.1) (μ.prod μ) :=
    (hf.mul_prod hg).swap
  have i4 : Integrable (fun p : α × α ↦ f p.2 * g p.2) (μ.prod μ) := hfg.comp_snd μ
  -- the four integrals
  have e1 : ∫ p : α × α, f p.1 * g p.1 ∂(μ.prod μ) = m * C := by
    rw [integral_prod _ i1]
    simp only [integral_const, smul_eq_mul, integral_const_mul, measureReal_def]
    rw [hm, hC]
  have e4 : ∫ p : α × α, f p.2 * g p.2 ∂(μ.prod μ) = m * C := by
    rw [integral_prod _ i4]
    simp only [integral_const, smul_eq_mul, measureReal_def]
    rw [hm, hC]
  have e2 : ∫ p : α × α, f p.1 * g p.2 ∂(μ.prod μ) = A * B := by
    rw [integral_prod _ i2]
    simp only [integral_const_mul, integral_mul_const, hA, hB]
  have e3 : ∫ p : α × α, f p.2 * g p.1 ∂(μ.prod μ) = A * B := by
    rw [integral_prod _ i3]
    simp only [integral_mul_const, integral_const_mul, hA, hB]
  -- the double integral of the product is non-positive
  have hnonpos : ∫ p : α × α, (f p.1 - f p.2) * (g p.1 - g p.2) ∂(μ.prod μ) ≤ 0 :=
    integral_nonpos_of_ae h
  have hexp : ∫ p : α × α, (f p.1 - f p.2) * (g p.1 - g p.2) ∂(μ.prod μ)
      = (m * C - A * B) - (A * B - m * C) := by
    have : ∀ p : α × α, (f p.1 - f p.2) * (g p.1 - g p.2)
        = (f p.1 * g p.1 - f p.1 * g p.2) - (f p.2 * g p.1 - f p.2 * g p.2) := by
      intro p; ring
    simp_rw [this]
    have j1 : Integrable (fun p : α × α ↦ f p.1 * g p.1 - f p.1 * g p.2) (μ.prod μ) := i1.sub i2
    have j2 : Integrable (fun p : α × α ↦ f p.2 * g p.1 - f p.2 * g p.2) (μ.prod μ) := i3.sub i4
    rw [integral_sub j1 j2, integral_sub i1 i2, integral_sub i3 i4, e1, e2, e3, e4]
  rw [hexp] at hnonpos
  linarith

/-! ## The interval form used in the paper -/

/-- Monotone-antitone pairs satisfy the pointwise antivariation hypothesis. -/
theorem antivary_pointwise {s : Set ℝ} {f g : ℝ → ℝ} (hf : MonotoneOn f s)
    (hg : AntitoneOn g s) {x y : ℝ} (hx : x ∈ s) (hy : y ∈ s) :
    (f x - f y) * (g x - g y) ≤ 0 := by
  rcases le_total x y with hxy | hxy
  · have h1 : f x - f y ≤ 0 := sub_nonpos.2 (hf hx hy hxy)
    have h2 : 0 ≤ g x - g y := sub_nonneg.2 (hg hx hy hxy)
    exact mul_nonpos_of_nonpos_of_nonneg h1 h2
  · have h1 : 0 ≤ f x - f y := sub_nonneg.2 (hf hy hx hxy)
    have h2 : g x - g y ≤ 0 := sub_nonpos.2 (hg hy hx hxy)
    exact mul_nonpos_of_nonneg_of_nonpos h1 h2

/-- **Appendix B, Step 3.** For `f` non-decreasing and `g` non-increasing on
`(0, T]`, the cross integral is bounded by the product of the two averages:

  `T · ∫₀ᵀ f(s) g(s) ds ≤ (∫₀ᵀ f) (∫₀ᵀ g)`.

This is the inequality the paper invokes as "Chebyshev's sum inequality for
anti-monotone functions". -/
theorem intervalIntegral_mul_le_of_monotone_antitone {f g : ℝ → ℝ} {T : ℝ} (hT : 0 ≤ T)
    (hf : MonotoneOn f (Ioc 0 T)) (hg : AntitoneOn g (Ioc 0 T))
    (hfi : IntervalIntegrable f volume 0 T) (hgi : IntervalIntegrable g volume 0 T)
    (hfgi : IntervalIntegrable (fun s ↦ f s * g s) volume 0 T) :
    T * ∫ s in (0 : ℝ)..T, f s * g s ≤ (∫ s in (0 : ℝ)..T, f s) * (∫ s in (0 : ℝ)..T, g s) := by
  set μ : Measure ℝ := volume.restrict (Ioc 0 T) with hμ
  have hfin : IsFiniteMeasure μ :=
    ⟨by rw [hμ, Measure.restrict_apply_univ]; exact measure_Ioc_lt_top⟩
  have hmass : (μ univ).toReal = T := by
    rw [hμ, Measure.restrict_apply_univ, Real.volume_Ioc]
    simp [ENNReal.toReal_ofReal, sub_zero, hT]
  -- the interval integrals are integrals against `μ`
  have hrw : ∀ h : ℝ → ℝ, ∫ s in (0 : ℝ)..T, h s = ∫ x, h x ∂μ := by
    intro h; rw [intervalIntegral.integral_of_le hT, hμ]
  -- integrability transfers
  have hfI : Integrable f μ := (intervalIntegrable_iff_integrableOn_Ioc_of_le hT).1 hfi
  have hgI : Integrable g μ := (intervalIntegrable_iff_integrableOn_Ioc_of_le hT).1 hgi
  have hfgI : Integrable (fun x ↦ f x * g x) μ :=
    (intervalIntegrable_iff_integrableOn_Ioc_of_le hT).1 hfgi
  -- the a.e. antivariation hypothesis on the product
  have hae : ∀ᵐ p ∂(μ.prod μ), (f p.1 - f p.2) * (g p.1 - g p.2) ≤ 0 := by
    have hprod : μ.prod μ = (volume.prod volume).restrict (Ioc 0 T ×ˢ Ioc 0 T) := by
      rw [hμ, Measure.prod_restrict]
    rw [hprod]
    refine (ae_restrict_iff' (measurableSet_Ioc.prod measurableSet_Ioc)).2
      (Filter.Eventually.of_forall ?_)
    rintro ⟨x, y⟩ ⟨hx, hy⟩
    exact antivary_pointwise hf hg hx hy
  have := @antivary_integral_mul_le ℝ _ μ hfin f g hfI hgI hfgI hae
  rw [hmass] at this
  rw [hrw f, hrw g, hrw (fun s ↦ f s * g s)]
  exact this

end ConstructiveGauges
