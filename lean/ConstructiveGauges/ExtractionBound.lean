/-
Theorem 1: the parasitic extraction ratio bound.

Appendix B reduces both revenue expectations to deterministic time integrals
via Lemma 2 (Steps 1 and 2), bounds the cross integral by Chebyshev's
anti-monotone inequality (Step 3), and divides (Step 4). Steps 1 and 2 are
the mean-field reduction, taken as the definition of the reduced functionals
in `Defs.lean` and quantified in `Concentration.lean`; Steps 3 and 4 are the
content proved here, exactly and with no error term.

`parasitic_extraction_bound` is the first inequality of eq. (6);
`parasitic_extraction_bound_worst_case` is the second, the substitution
`c(w) ≤ c(w_min)` justified by `c` being non-increasing; `short_cycle_bound`
is Corollary 1.
-/
import Mathlib
import ConstructiveGauges.Defs
import ConstructiveGauges.Chebyshev
import ConstructiveGauges.Freshness

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory Set

/-- **Theorem 1 (parasitic extraction ratio bound).** In the mean-field
reduced model, the ratio of corrective to standard-gauge parasitic revenue
over a cycle `[0, T]` is bounded by the freshness ratio times the
concentration ratio.

The pointwise in-range probability does not appear: it is present in both
numerator and denominator and cancels. -/
theorem parasitic_extraction_bound {lam L Lbar cw cref feq T : ℝ} {f P : ℝ → ℝ}
    (hlam : 0 < lam) (hL : 0 < L) (hLbar : 0 < Lbar) (hcw : 0 ≤ cw)
    (hcref : 0 < cref) (hfeq : 0 < feq) (hT : 0 < T)
    (hf : MonotoneOn f (Ioc 0 T)) (hP : AntitoneOn P (Ioc 0 T))
    (hfi : IntervalIntegrable f volume 0 T) (hPi : IntervalIntegrable P volume 0 T)
    (hfPi : IntervalIntegrable (fun s ↦ f s * P s) volume 0 T)
    (hPpos : 0 < ∫ s in (0 : ℝ)..T, P s) :
    meanRevCorr lam L Lbar cw cref feq f P T / meanRevStd lam L Lbar P T
      ≤ fbar f T / feq * (cw / cref) := by
  have hcheb : T * ∫ s in (0 : ℝ)..T, f s * P s
      ≤ (∫ s in (0 : ℝ)..T, f s) * ∫ s in (0 : ℝ)..T, P s :=
    intervalIntegral_mul_le_of_monotone_antitone hT.le hf hP hfi hPi hfPi
  have hstd : 0 < meanRevStd lam L Lbar P T := by
    rw [meanRevStd]; positivity
  rw [div_le_iff₀ hstd, meanRevCorr, meanRevStd, fbar]
  have hK : (0 : ℝ) ≤ lam * L * cw / (Lbar * cref * feq) := by positivity
  have key : (∫ s in (0 : ℝ)..T, f s * P s)
      ≤ (∫ s in (0 : ℝ)..T, f s) * (∫ s in (0 : ℝ)..T, P s) / T := by
    rw [le_div_iff₀ hT]; linarith
  calc lam * L * cw / (Lbar * cref * feq) * ∫ s in (0 : ℝ)..T, f s * P s
      ≤ lam * L * cw / (Lbar * cref * feq) *
          ((∫ s in (0 : ℝ)..T, f s) * (∫ s in (0 : ℝ)..T, P s) / T) :=
        mul_le_mul_of_nonneg_left key hK
    _ = (∫ s in (0 : ℝ)..T, f s) / T / feq * (cw / cref) *
          (lam * L / Lbar * ∫ s in (0 : ℝ)..T, P s) := by
        field_simp

/-- **Theorem 1, worst-case substitution.** Since the concentration weight is
non-increasing in width, the bound is loosest at the minimum width. -/
theorem parasitic_extraction_bound_worst_case {lam L Lbar cw cmin cref feq T : ℝ} {f P : ℝ → ℝ}
    (hlam : 0 < lam) (hL : 0 < L) (hLbar : 0 < Lbar) (hcw : 0 ≤ cw)
    (hcref : 0 < cref) (hfeq : 0 < feq) (hT : 0 < T)
    (hf : MonotoneOn f (Ioc 0 T)) (hP : AntitoneOn P (Ioc 0 T))
    (hfi : IntervalIntegrable f volume 0 T) (hPi : IntervalIntegrable P volume 0 T)
    (hfPi : IntervalIntegrable (fun s ↦ f s * P s) volume 0 T)
    (hPpos : 0 < ∫ s in (0 : ℝ)..T, P s)
    (hfbar : 0 ≤ fbar f T) (hcmin : cw ≤ cmin) :
    meanRevCorr lam L Lbar cw cref feq f P T / meanRevStd lam L Lbar P T
      ≤ fbar f T / feq * (cmin / cref) := by
  refine le_trans (parasitic_extraction_bound hlam hL hLbar hcw hcref hfeq hT hf hP hfi hPi
    hfPi hPpos) ?_
  have h1 : cw / cref ≤ cmin / cref := by gcongr
  have h2 : (0 : ℝ) ≤ fbar f T / feq := by positivity
  exact mul_le_mul_of_nonneg_left h1 h2

/-- **Corollary 1 (short-cycle regime).** Under the bare linear ramp, for
cycle times at or below the warmup the bound is `δt / (2 W f_eq)` times the
concentration ratio, vanishing linearly as `δt → 0`. -/
theorem short_cycle_bound {lam L Lbar cw cref feq T W : ℝ} {P : ℝ → ℝ}
    (hlam : 0 < lam) (hL : 0 < L) (hLbar : 0 < Lbar) (hcw : 0 ≤ cw)
    (hcref : 0 < cref) (hfeq : 0 < feq) (hT : 0 < T) (hW : 0 < W) (hTW : T ≤ W)
    (hP : AntitoneOn P (Ioc 0 T)) (hPi : IntervalIntegrable P volume 0 T)
    (hfPi : IntervalIntegrable (fun s ↦ ramp W s * P s) volume 0 T)
    (hPpos : 0 < ∫ s in (0 : ℝ)..T, P s) :
    meanRevCorr lam L Lbar cw cref feq (ramp W) P T / meanRevStd lam L Lbar P T
      ≤ T / (2 * W) / feq * (cw / cref) := by
  have h := parasitic_extraction_bound hlam hL hLbar hcw hcref hfeq hT
    (ramp_monotoneOn hW (Ioc 0 T)) hP (ramp_intervalIntegrable 0 T) hPi hfPi hPpos
  rwa [fbar_ramp_of_le hW hT hTW] at h

end ConstructiveGauges
