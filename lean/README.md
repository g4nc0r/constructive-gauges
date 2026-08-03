# Lean formalisation

Machine-checked proofs of the theorem layer of *Constructive Gauges*, written
in Lean 4 against mathlib. The scope is the idealised real-arithmetic and
mean-field model of the paper. The Foundry suite under `../foundry/` remains
the check against the gauge accumulator's actual arithmetic on live chain
state, and `../reproduction/` remains the check of Lemma 1's Gaussian model
against realised tick paths.

The library root is `ConstructiveGauges.lean`. The scoring function of §4.1,
the derived freshness averages of Appendix A, and the mean-field revenue
functionals of Appendix B live in `ConstructiveGauges/Defs.lean`, which every
other file imports. File names follow the mathlib convention of descriptive
content names; the mapping to the paper's numbering is recorded below and in
each file's doc comments. All statements refer to the August 2026 revision of
the manuscript.

Two pieces of general machinery are proved here because mathlib does not carry
them. `Chebyshev.lean` gives the anti-monotone inequality in integral form,
mathlib having only the finite-sum version. The Gaussian CDF facts in
`InRange.lean` extend mathlib's generic `ProbabilityTheory.cdf`, which has no
Gaussian instance. Both are stated against a general finite measure rather than
against this paper's quantities. Programme convention is to share by copy, not
by symlink; this repository owns those two originals.

## Coverage

`ConstructiveGauges/Chebyshev.lean` - Appendix B, Step 3, and the bounding
step of Corollary 3:

- `antivary_integral_mul_le` - Chebyshev's anti-monotone inequality on an
  arbitrary finite measure. If `(f x - f y)(g x - g y) ≤ 0` almost everywhere
  on the product, then `μ(univ) ∫ f g ≤ (∫ f)(∫ g)`. Proved from the
  product-measure identity
  `∫∫ (f x - f y)(g x - g y) = 2(‖μ‖ ∫ f g - (∫ f)(∫ g)) ≤ 0`.
- `intervalIntegral_mul_le_of_monotone_antitone` - the specialisation the
  paper invokes, `T ∫₀ᵀ f g ≤ (∫₀ᵀ f)(∫₀ᵀ g)` for `f` non-decreasing and `g`
  non-increasing on `(0, T]`.
- `antivary_pointwise` - monotone-antitone pairs satisfy the pointwise
  hypothesis, which is how the interval form discharges it.

Appendix B's Step 3 and Corollary 3's upper envelope are the same argument
made twice in the paper, so both reduce to this lemma.

`ConstructiveGauges/Freshness.lean` - the freshness ramp of (M4), its time
average in eq. (8), Corollaries 1 and 2, and Proposition 1:

- `ramp_monotone`, `ramp_eq_linear`, `ramp_eq_one`,
  `ramp_intervalIntegrable` - the shape conditions Theorem 1's Chebyshev step
  requires of `f`, and the two branches of the ramp.
- `integral_ramp_of_le`, `fbar_ramp_of_le`, `fbar_ramp_of_gt` - eq. (8) in
  closed form, `f̄(T) = T/(2W)` below the warmup and `1 - W/(2T)` above it.
- `fbar_ramp_pos`, `fbar_ramp_le_one` - `f̄` is a freshness, valued in `(0,
  1]` on positive cycle lengths.
- `fbar_ramp_strictMonoOn` - `f̄` is strictly increasing on the whole positive
  axis. The crossover at `T = W` needs its own case, where the two branches
  agree at one half.
- `rebalance_spam_self_defeat`, `spam_freshness_factor_lt_one` -
  Proposition 1. Rebalancing below the population cadence gives a strictly
  lower time-averaged freshness, hence a freshness factor strictly below unity
  in Theorem 2's decomposition, with no appeal to gas costs.
- `fbar_ramp_tendsto_zero`, `fbar_ramp_tendsto_one` - Corollaries 1 and 2 as
  limits, the short-cycle vanishing and the long-cycle saturation.

`ConstructiveGauges/InRange.lean` - Lemma 1, §5.1 and Appendix A:

- `Phi` - the standard normal CDF, mathlib's `cdf` at `gaussianReal 0 1`.
  `Phi_monotone`, `Phi_nonneg` and `Phi_le_one` come with it.
- `Phi_neg` - the reflection `Φ(-x) = 1 - Φ(x)`, from `gaussianReal_map_neg`
  together with the absence of atoms.
- `gaussian_cdf_scale` - a centred Gaussian of variance `v` has CDF
  `Φ(x/√v)`, by pushing the standard Gaussian forward along `y ↦ √v · y`.
- `gaussian_two_sided` - Lemma 1 proper, `P(|X| < r) = 2 Φ(r/√v) - 1`.
- `Pin`, `Pin_eq`, `sqrt_variance` - the identification with the paper's
  `P_in(s)` under `v = σ²s` and `r = aη`.
- `Pin_antitoneOn` - the in-range probability is non-increasing in elapsed
  time, which is the second shape condition Theorem 1's Chebyshev step needs.
- `Pin_le_one`, `Pin_nonneg` - `P_in` is a probability. The lower bound needs
  `Φ ≥ 1/2` on the non-negative axis and so is read off the two-sided mass.

The paper obtains the time average `P̄_in` of eq. (4) from the pointwise law
by Fubini. Here the time average is the definition (`Pbar` in `Defs.lean`), so
the content of the lemma is the pointwise identity.

`ConstructiveGauges/Concentration.lean` - Lemma 2, §5.1:

- `variance_total_score` - variance additivity for the total score under
  pairwise independence, `Var(∑ S_j) ≤ N V`.
- `total_score_concentration` - the lemma as an explicit finite-`N` bound
  rather than an asymptotic statement. For any relative tolerance `ε`,
  `P(|S_total - E[S_total]| ≥ ε N m) ≤ V/(N m² ε²)`. The paper's `O(1/√N)`
  relative fluctuation is that bound read at fixed confidence, since the
  deviation scale holding the right-hand side constant is `ε ∝ N^{-1/2}`.

`ConstructiveGauges/ExtractionBound.lean` - Theorem 1 and Corollary 1, §5.2
and Appendix B:

- `parasitic_extraction_bound` - the first inequality of eq. (6). The
  pointwise in-range probability appears in both numerator and denominator and
  cancels, which is why it is absent from the statement.
- `parasitic_extraction_bound_worst_case` - the second inequality, the
  substitution `c(w) ≤ c(w_min)` licensed by `c` being non-increasing.
- `short_cycle_bound` - Corollary 1 in closed form under the bare ramp.

`ConstructiveGauges/YieldEquality.lean` - Theorem 2 and Corollary 3, §5.3 and
Appendix B:

- `legitimate_yield_equality` - Theorem 2. On the reduced functionals this is
  an exact identity, not an inequality, because `f̃` is defined to absorb
  `f · P_in,legit` exactly and no Chebyshev step is invoked.
- `ftilde_le_fbar` - `f̃(ρ) ≤ f̄(ρ)`, by the same anti-monotone step Theorem 1
  uses.
- `legitimate_yield_upper` - the resulting upper envelope, eq. (10).
- `ftilde_ge_of_tracking` - the `ε`-tracking bracket, eq. (11). For an LP in
  range with probability at least `1 - ε` throughout, `f̃` is within `(1 - ε)`
  of `f̄`, and converges to it as `ε → 0`.

`ConstructiveGauges/MinimalCompleteness.lean` - Theorem 3, §5.4. The family
`𝓕` is declared as a `Factors` record of three flags against a `GaugeModel`
of fixed deployment parameters, and revenue is a time integral of the score:

- `closesSC_iff` - the short-cycle pathway is closed exactly when `f ∈ K`.
  Without it both revenues are `Θ(δt)` and the ratio is a positive constant;
  with it the corrective revenue is `Θ(δt²)` and the ratio vanishes linearly.
- `closesOOR_iff` - the out-of-range pathway is closed exactly when the
  indicator is in `K`.
- `minimal_completeness_attack_rows`, `full_closes_attack_rows` - the
  conjunction, and its instance at the full three-factor member.
- `wa_bounded`, `wa_unbounded_without_wmin` - the width arbitrage row, which
  does not behave like the other two. See the note below.

**On the width arbitrage row.** This row comes out weaker than the table
states, and closer to the theorem's own dagger footnote. Per-unit-capital
revenue is bounded whenever `w ≥ w_min > 0` under a capped concentration curve,
and that bound holds for *every* member `K`, including those without `c`.
Conversely, dropping minimum-width enforcement makes it unbounded, again for
every `K`. The divergence at narrow widths is carried by `L ∝ C/w`, which is in
the score whether or not `c` is. So the pathway is closed by `w_min` together
with `c_max`, not by the presence of the concentration multiplier, and the
`iff` in the theorem statement rests entirely on the footnote's convention
that `c_max` is dropped alongside `c`. This agrees with §5.4's own discussion,
which already describes `c`'s reverse-direction role as scoring-family
expressivity rather than attack closure. The two attack rows are unaffected and
hold as stated.

`ConstructiveGauges/ClaimTiming.lean` - Proposition 2, Appendix C:

- `accrual_congr` - the accumulator depends on the score history only through
  its values on the window, so nothing outside can change it.
- `accrual_split`, `accrual_eq_sum_claims` - the total claimed across any
  finite schedule of claim events equals the single accumulator value over the
  whole window. A rebalance partway through cannot retroactively alter the
  accrual before it, and splitting the window differently changes nothing. The
  lazy-checkpoint implementation is piecewise of the same form, which is this
  statement read with the claim times as checkpoints.

Proposition 1 is proved in `Freshness.lean`, where the monotonicity it rests on
already lives.

## Scope: what is not formalised

Recorded explicitly, since two of the three theorems carry an asymptotic error
term that is isolated here rather than proved.

- **The mean-field substitution as an asymptotic statement.** Theorems 1 and 2
  are proved on the reduced functionals of `Defs.lean`, in which the pool
  liquidity and total score have already been replaced by their expectations.
  That replacement is Appendix B's Steps 1 and 2, and the delta-method-style
  bound on `E[Y/S_total] - E[Y]/E[S_total]` is not carried through
  symbolically. The effect is that the deterministic content is exact, with no
  error term anywhere in `ExtractionBound.lean` or `YieldEquality.lean`, and the
  `O(N^{-1/2})` bookkeeping sits in `Concentration.lean`, quantified at
  finite `N`.
- **The positive-dependence variant of Lemma 2.** The remark following the
  lemma notes that under finite dependence range `d_max` the variance bound
  degrades to `N V d_max`, preserving the rate with a worse constant. Only the
  independent case is formalised; the paper defers the formal weak-dependence
  treatment to future work.
- **The Brownian price process as a process.** `InRange.lean` works with the
  time-`s` marginal `N(0, σ²s)`, which is everything Lemma 1 consumes. Path
  properties are not needed and are not formalised, so nothing here depends on
  mathlib's Brownian motion.
- **The empirical layer.** The conservativeness argument for mean reversion at
  long horizons, the calibration of `c_ref`, `f_eq`, `w_min` and `W`, and the
  reference implementation's piecewise ramp with its plateau and decay are
  empirical, and remain with `../reproduction/` and `../foundry/`.
- **Fixed-point arithmetic** remains the Foundry suite's job, as in the sibling
  repositories. Everything here is over `ℝ`, so tick rounding and wei-level
  truncation in the accumulator are outside the model.
- **The auxiliary arguments of §5.5.** The minimum displacement `Δ_min`, the
  oracle-manipulation argument, and the single-tick snipe are informal in the
  paper and have no closed form to formalise.

## Building

Requires elan, the Lean toolchain manager. The pinned toolchain is in
`lean-toolchain`; mathlib is pinned by `lake-manifest.json`, at the same
revision as the Geometric Siphon and Master Equation formalisations.

```
lake exe cache get   # fetch prebuilt mathlib (several GB, one-off)
lake build
```

Axiom audit, confirming that every theorem depends only on `propext`,
`Classical.choice` and `Quot.sound`, and that none contains a `sorry`:

```
lake env lean AxiomCheck.lean
```

45 checks, all clean.
