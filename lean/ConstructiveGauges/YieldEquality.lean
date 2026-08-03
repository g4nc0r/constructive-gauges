/-
Theorem 2: the legitimate-LP yield equality, and Corollary 3.

The argument parallels Theorem 1's with one structural difference: the
bounding step is replaced by a direct identification with `f̃`, so the result
is an equality rather than an inequality. In the mean-field reduced model of
`Defs.lean` the equality is exact, which is what `legitimate_yield_equality`
records.

Corollary 3 then re-derives an inequality from it: `f̃(ρ) ≤ f̄(ρ)` by the same
Chebyshev step Theorem 1 uses (`ftilde_le_fbar`), with the range-tracking
limit `P → 1` giving equality, and the `ε`-tracking bracket
(`ftilde_ge_of_tracking`) supplying the matching lower envelope.
-/
import Mathlib
import ConstructiveGauges.Defs
import ConstructiveGauges.Chebyshev
import ConstructiveGauges.Freshness

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory Set

/-- **Theorem 2 (legitimate-LP yield equality).** In the mean-field reduced
model the yield ratio over one rebalance interval is exactly the concentration
ratio times the in-range-weighted freshness ratio. No Chebyshev step is
invoked: `f̃` is defined to absorb `f · P` exactly. -/
theorem legitimate_yield_equality {lam L Lbar cw cref feq T : ℝ} {f P : ℝ → ℝ}
    (hlam : 0 < lam) (hL : 0 < L) (hLbar : 0 < Lbar)
    (hcref : 0 < cref) (hfeq : 0 < feq)
    (hPpos : 0 < ∫ s in (0 : ℝ)..T, P s) :
    meanRevCorr lam L Lbar cw cref feq f P T / meanRevStd lam L Lbar P T
      = cw / cref * (ftilde f P T / feq) := by
  rw [meanRevCorr, meanRevStd, ftilde]
  field_simp

/-- **Corollary 3, upper envelope.** The in-range-weighted freshness never
exceeds the plain time average, by the same anti-monotone Chebyshev step as
Theorem 1: a freshly rebalanced position drifts out of range over time, so
`f` non-decreasing and `P` non-increasing antivary. -/
theorem ftilde_le_fbar {T : ℝ} {f P : ℝ → ℝ} (hT : 0 < T)
    (hf : MonotoneOn f (Ioc 0 T)) (hP : AntitoneOn P (Ioc 0 T))
    (hfi : IntervalIntegrable f volume 0 T) (hPi : IntervalIntegrable P volume 0 T)
    (hfPi : IntervalIntegrable (fun s ↦ f s * P s) volume 0 T)
    (hPpos : 0 < ∫ s in (0 : ℝ)..T, P s) :
    ftilde f P T ≤ fbar f T := by
  have hcheb : T * ∫ s in (0 : ℝ)..T, f s * P s
      ≤ (∫ s in (0 : ℝ)..T, f s) * ∫ s in (0 : ℝ)..T, P s :=
    intervalIntegral_mul_le_of_monotone_antitone hT.le hf hP hfi hPi hfPi
  rw [ftilde, fbar, div_le_div_iff₀ hPpos hT]
  linarith

/-- The yield ratio of Theorem 2 is bounded above by the plain freshness
average, eq. (10). -/
theorem legitimate_yield_upper {lam L Lbar cw cref feq T : ℝ} {f P : ℝ → ℝ}
    (hlam : 0 < lam) (hL : 0 < L) (hLbar : 0 < Lbar) (hcw : 0 ≤ cw)
    (hcref : 0 < cref) (hfeq : 0 < feq) (hT : 0 < T)
    (hf : MonotoneOn f (Ioc 0 T)) (hP : AntitoneOn P (Ioc 0 T))
    (hfi : IntervalIntegrable f volume 0 T) (hPi : IntervalIntegrable P volume 0 T)
    (hfPi : IntervalIntegrable (fun s ↦ f s * P s) volume 0 T)
    (hPpos : 0 < ∫ s in (0 : ℝ)..T, P s) :
    meanRevCorr lam L Lbar cw cref feq f P T / meanRevStd lam L Lbar P T
      ≤ cw / cref * (fbar f T / feq) := by
  rw [legitimate_yield_equality hlam hL hLbar hcref hfeq hPpos]
  have h1 : ftilde f P T / feq ≤ fbar f T / feq := by
    gcongr
    exact ftilde_le_fbar hT hf hP hfi hPi hfPi hPpos
  exact mul_le_mul_of_nonneg_left h1 (by positivity)

/-- **Corollary 3, `ε`-tracking bracket.** For an LP whose position stays in
range with probability at least `1 - ε` throughout the interval, the
in-range-weighted freshness is within `(1 - ε)` of the plain average, and
converges to it as `ε → 0`. -/
theorem ftilde_ge_of_tracking {T ε : ℝ} {f P : ℝ → ℝ} (hT : 0 < T) (hε : ε ≤ 1)
    (hfi : IntervalIntegrable f volume 0 T)
    (hPi : IntervalIntegrable P volume 0 T)
    (hfPi : IntervalIntegrable (fun s ↦ f s * P s) volume 0 T)
    (hf0 : ∀ s ∈ Icc 0 T, 0 ≤ f s)
    (hPlb : ∀ s ∈ Icc 0 T, 1 - ε ≤ P s) (hPub : ∀ s ∈ Icc 0 T, P s ≤ 1)
    (hPpos : 0 < ∫ s in (0 : ℝ)..T, P s) (hfbar : 0 ≤ fbar f T) :
    (1 - ε) * fbar f T ≤ ftilde f P T := by
  have hIF : 0 ≤ ∫ s in (0 : ℝ)..T, f s := by
    have h := hfbar
    rw [fbar, le_div_iff₀ hT] at h
    linarith
  -- the cross integral dominates `(1 - ε)` times the freshness integral
  have h1 : (1 - ε) * ∫ s in (0 : ℝ)..T, f s ≤ ∫ s in (0 : ℝ)..T, f s * P s := by
    rw [← intervalIntegral.integral_const_mul]
    refine intervalIntegral.integral_mono_on hT.le (hfi.const_mul _) hfPi ?_
    intro x hx
    nlinarith [hf0 x hx, hPlb x hx]
  -- the in-range integral is at most the interval length
  have h2 : (∫ s in (0 : ℝ)..T, P s) ≤ T := by
    have : (∫ s in (0 : ℝ)..T, P s) ≤ ∫ _s in (0 : ℝ)..T, (1:ℝ) :=
      intervalIntegral.integral_mono_on hT.le hPi intervalIntegrable_const hPub
    simpa using this
  rw [ftilde, fbar, ← mul_div_assoc, div_le_div_iff₀ hT hPpos]
  have hlow : 0 ≤ (1 - ε) * ∫ s in (0 : ℝ)..T, f s := by
    have : (0 : ℝ) ≤ 1 - ε := by linarith
    positivity
  nlinarith [h1, h2, hlow, hPpos, hT]

end ConstructiveGauges
