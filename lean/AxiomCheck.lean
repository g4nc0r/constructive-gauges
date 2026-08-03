import ConstructiveGauges

-- Chebyshev's anti-monotone integral inequality
#print axioms ConstructiveGauges.antivary_integral_mul_le
#print axioms ConstructiveGauges.antivary_pointwise
#print axioms ConstructiveGauges.intervalIntegral_mul_le_of_monotone_antitone

-- Freshness ramp and its time average (Appendix A, Corollaries 1 and 2, Prop. A.1)
#print axioms ConstructiveGauges.ramp_monotone
#print axioms ConstructiveGauges.integral_ramp_of_le
#print axioms ConstructiveGauges.fbar_ramp_of_le
#print axioms ConstructiveGauges.fbar_ramp_of_gt
#print axioms ConstructiveGauges.fbar_ramp_pos
#print axioms ConstructiveGauges.fbar_ramp_le_one
#print axioms ConstructiveGauges.fbar_ramp_strictMonoOn
#print axioms ConstructiveGauges.rebalance_spam_self_defeat
#print axioms ConstructiveGauges.spam_freshness_factor_lt_one
#print axioms ConstructiveGauges.fbar_ramp_tendsto_zero
#print axioms ConstructiveGauges.fbar_ramp_tendsto_one

-- Lemma 1, in-range probability
#print axioms ConstructiveGauges.Phi_monotone
#print axioms ConstructiveGauges.Phi_neg
#print axioms ConstructiveGauges.gaussian_cdf_scale
#print axioms ConstructiveGauges.gaussian_two_sided
#print axioms ConstructiveGauges.sqrt_variance
#print axioms ConstructiveGauges.Pin_eq
#print axioms ConstructiveGauges.Pin_antitoneOn
#print axioms ConstructiveGauges.Pin_le_one
#print axioms ConstructiveGauges.Pin_nonneg

-- Lemma 2, total-score concentration
#print axioms ConstructiveGauges.variance_total_score
#print axioms ConstructiveGauges.total_score_concentration

-- Theorem 1 and Corollary 1
#print axioms ConstructiveGauges.parasitic_extraction_bound
#print axioms ConstructiveGauges.parasitic_extraction_bound_worst_case
#print axioms ConstructiveGauges.short_cycle_bound

-- Theorem 2 and Corollary 3
#print axioms ConstructiveGauges.legitimate_yield_equality
#print axioms ConstructiveGauges.ftilde_le_fbar
#print axioms ConstructiveGauges.legitimate_yield_upper
#print axioms ConstructiveGauges.ftilde_ge_of_tracking

-- Theorem 3, minimal completeness
#print axioms ConstructiveGauges.revK_in_range_of_hasF
#print axioms ConstructiveGauges.revK_in_range_of_not_hasF
#print axioms ConstructiveGauges.sc_ratio_of_hasF
#print axioms ConstructiveGauges.sc_ratio_of_not_hasF
#print axioms ConstructiveGauges.closesSC_iff
#print axioms ConstructiveGauges.closesOOR_iff
#print axioms ConstructiveGauges.minimal_completeness_attack_rows
#print axioms ConstructiveGauges.full_closes_attack_rows
#print axioms ConstructiveGauges.wa_bounded
#print axioms ConstructiveGauges.wa_unbounded_without_wmin

-- Proposition A.2, claim-timing orthogonality
#print axioms ConstructiveGauges.accrual_congr
#print axioms ConstructiveGauges.accrual_split
#print axioms ConstructiveGauges.accrual_eq_sum_claims
