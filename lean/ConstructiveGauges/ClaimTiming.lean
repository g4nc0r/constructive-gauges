/-
Proposition 2: claim-timing orthogonality.

Under continuous accrual `Ṙ_i = λ S_i(t) / S_total(t)` the reward claimable at
time `T` is a functional of the score history alone. Two consequences are
formalised here:

* `accrual_congr` - the accumulator depends on `S_i` and `S_total` only
  through their values on `[0, T]`; nothing outside the window can change it.
* `accrual_eq_sum_claims` - the total claimed across any finite schedule of
  claim events summing to `[0, T]` equals the single accumulator value over
  `[0, T]`. A rebalance at `t' < T` cannot retroactively alter the accrual on
  `[0, t')`, and splitting the window differently changes nothing.

The lazy-checkpoint implementation is piecewise of the same form, so the
argument extends; that extension is the second theorem read with the claim
times as checkpoints.
-/
import Mathlib
import ConstructiveGauges.Defs

set_option linter.style.header false

namespace ConstructiveGauges

open MeasureTheory Set

variable {lam : ℝ} {S Stot : ℝ → ℝ}

/-- The accumulator depends only on the score history over the window. -/
theorem accrual_congr {S' Stot' : ℝ → ℝ} {T : ℝ}
    (hS : ∀ s ∈ uIcc (0 : ℝ) T, S s = S' s) (hStot : ∀ s ∈ uIcc (0 : ℝ) T, Stot s = Stot' s) :
    accrual lam S Stot T = accrual lam S' Stot' T := by
  rw [accrual, accrual]
  refine intervalIntegral.integral_congr ?_
  intro s hs
  simp only
  rw [hS s hs, hStot s hs]

/-- The accumulator splits across an intermediate claim. -/
theorem accrual_split {t T : ℝ}
    (h1 : IntervalIntegrable (fun s ↦ lam * S s / Stot s) volume 0 t)
    (h2 : IntervalIntegrable (fun s ↦ lam * S s / Stot s) volume t T) :
    accrual lam S Stot T
      = accrual lam S Stot t + ∫ s in t..T, lam * S s / Stot s := by
  rw [accrual, accrual]
  exact (intervalIntegral.integral_add_adjacent_intervals h1 h2).symm

/-- **Proposition 2 (claim-timing orthogonality).** For any finite schedule
of claim times `t 0 = 0 < t 1 < … < t n = T`, the sum of the amounts claimed
at each event equals the accumulator over the whole window. The schedule
itself does not enter, so the reward claimable at `T` is independent of when
claim operations are invoked. -/
theorem accrual_eq_sum_claims (t : ℕ → ℝ) (n : ℕ) (h0 : t 0 = 0)
    (hint : ∀ k < n, IntervalIntegrable (fun s ↦ lam * S s / Stot s) volume (t k) (t (k + 1))) :
    ∑ k ∈ Finset.range n, (∫ s in (t k)..(t (k + 1)), lam * S s / Stot s)
      = accrual lam S Stot (t n) := by
  rw [accrual, ← h0]
  exact intervalIntegral.sum_integral_adjacent_intervals hint

end ConstructiveGauges
