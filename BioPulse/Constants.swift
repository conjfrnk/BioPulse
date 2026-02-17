//
//  Constants.swift
//  BioPulse
//
//  Created by Connor Frank on 2/16/26.
//

import Foundation

/// Centralized constants for sleep metrics, thresholds, and configuration.
/// Thresholds are based on published sleep science research where noted.
enum SleepConstants {

    // MARK: - Recovery Readiness Thresholds
    // Composite recovery score boundaries inspired by Whoop Recovery / Oura Readiness.
    // Weights: HRV baseline deviation (35%), RHR baseline deviation (25%),
    //          Sleep duration vs goal (25%), Sleep debt factor (15%).

    /// Score at or above which recovery is classified as "Ready"
    static let recoveryReadyThreshold = 67
    /// Score at or above which recovery is classified as "Moderate" (below Ready)
    static let recoveryModerateThreshold = 34

    // MARK: - Recovery Score Weights

    static let recoveryWeightHRV = 0.35
    static let recoveryWeightRHR = 0.25
    static let recoveryWeightDuration = 0.25
    static let recoveryWeightDebt = 0.15

    /// Points deducted per hour of sleep debt in the recovery debt component
    static let recoveryDebtPenaltyPerHour = 15.0

    // MARK: - Sleep Efficiency Thresholds
    // AASM clinical standard: 85-95% is optimal.
    // Reed & Sacco (2016) — efficiency above 95% may indicate
    // insufficient sleep opportunity (rebound from deprivation).

    /// Efficiency at or above this may indicate sleep deprivation
    static let efficiencyDeprivedThreshold = 95.0
    /// Efficiency at or above this is considered optimal
    static let efficiencyOptimalThreshold = 85.0
    /// Efficiency at or above this is considered fair
    static let efficiencyFairThreshold = 75.0

    // MARK: - HRV Coefficient of Variation Thresholds
    // Plews et al. (2013) — HRV monitoring in athletes.
    // Lower CV indicates more stable autonomic nervous system function.

    /// CV below this indicates stable ANS
    static let hrvCVStableThreshold = 8.0
    /// CV above this indicates high day-to-day variability
    static let hrvCVHighThreshold = 20.0
    /// CV above this shown as warning color in UI
    static let hrvCVWarningThreshold = 15.0

    // MARK: - Autonomic Balance Thresholds
    // Shaffer & Ginsberg (2017) — HRV as a marker of ANS function.
    // HRV:RHR ratio as proxy for parasympathetic vs sympathetic dominance.

    /// Raw HRV:RHR ratio at or above this = parasympathetic dominant
    static let autonomicParasympatheticThreshold = 1.0
    /// Raw HRV:RHR ratio at or above this = balanced
    static let autonomicBalancedThreshold = 0.6

    // MARK: - Autonomic Balance Index (ABI)
    // Normalized: (HRV/HRV_baseline) / (RHR/RHR_baseline), centers around 1.0.
    // Shaffer & Ginsberg (2017).

    /// ABI at or above this = strong recovery
    static let abiStrongRecoveryThreshold = 1.1
    /// ABI at or above this = balanced
    static let abiBalancedThreshold = 0.85

    // MARK: - Sleep Regularity Thresholds
    // Phillips et al. (2017), Windred et al. (2024) —
    // highest SRI quintile associated with 30% lower all-cause mortality.

    /// Regularity score at or above this = excellent
    static let regularityExcellentThreshold = 85.0
    /// Regularity score at or above this = good
    static let regularityGoodThreshold = 70.0
    /// Regularity score at or above this = fair
    static let regularityFairThreshold = 50.0

    // MARK: - Bedtime Consistency Thresholds

    /// Bedtime standard deviation (minutes) below this = very consistent
    static let consistencyGoodMinutes = 30.0
    /// Bedtime standard deviation (minutes) below this = moderately consistent
    static let consistencyFairMinutes = 60.0

    // MARK: - Social Jet Lag Thresholds
    // Wittmann et al. (2006) — >1h associated with health risks,
    // >2h associated with metabolic syndrome risk.

    /// Social jet lag (minutes) below this = minimal
    static let socialJetLagMinimalMinutes = 30.0
    /// Social jet lag (minutes) below this = mild
    static let socialJetLagMildMinutes = 60.0
    /// Social jet lag (minutes) below this = moderate
    static let socialJetLagModerateMinutes = 120.0

    // MARK: - Sleep Architecture Healthy Ranges
    // Ohayon et al. (2004) meta-analysis of normal sleep across ages.
    // Deep (N3): 13-23%, REM: 20-25%, Light/Core: remainder.
    // Used in sleep score calculation penalty thresholds.

    /// Minimum healthy deep sleep as fraction of total sleep
    static let deepSleepMinFraction = 0.13
    /// Minimum healthy REM sleep as fraction of total sleep
    static let remSleepMinFraction = 0.20
    /// Awake fraction of total in-bed time above which a penalty applies
    static let awakeTimePenaltyFraction = 0.10

    // MARK: - Sleep Debt
    // Kitamura et al. (2016) — sleep debt accumulates over ~14 days;
    // beyond ~20h the body's recovery mechanisms cap further accumulation.

    /// Maximum trackable sleep debt in hours
    static let sleepDebtCapHours = 20.0
    /// Number of days over which rolling sleep debt is calculated
    static let sleepDebtRollingDays = 14

    // MARK: - Sleep Debt Severity

    /// Debt below this (hours) = well rested
    static let debtLowHours = 1.0
    /// Debt below this (hours) = moderate
    static let debtModerateHours = 3.0
    /// Debt below this (hours) = significant; above = severe
    static let debtHighHours = 5.0

    // MARK: - Sleep Score Thresholds

    /// Score at or above this is colored green / good
    static let scoreGoodThreshold = 80
    /// Score at or above this is colored yellow / fair
    static let scoreFairThreshold = 60

    // MARK: - Advanced Sleep Score Adjustments

    /// HRV ratio below this triggers major penalty
    static let hrvRatioSeverePenalty = 0.5
    /// HRV ratio below this triggers minor penalty
    static let hrvRatioMildPenalty = 0.8
    /// RHR ratio above this triggers major penalty
    static let rhrRatioSeverePenalty = 1.3
    /// RHR ratio above this triggers minor penalty
    static let rhrRatioMildPenalty = 1.1
    /// Bedtime mismatch (seconds) above this triggers major penalty
    static let bedtimeMismatchSevereSec = 4.0 * 3600.0
    /// Bedtime mismatch (seconds) above this triggers minor penalty
    static let bedtimeMismatchMildSec = 2.0 * 3600.0
    /// Duration below this (seconds) triggers penalty
    static let minDurationPenaltySec = 5.0 * 3600.0

    // MARK: - Flagged Issue Thresholds

    /// RHR above this (bpm) is flagged as elevated
    static let flaggedRHRThreshold = 100.0
    /// HRV below this (ms) is flagged as low
    static let flaggedHRVLowThreshold = 30.0

    // MARK: - Time Constants

    static let secondsPerMinute = 60.0
    static let secondsPerHour = 3600.0
    static let minutesPerHour = 60
    static let minutesPerDay = 1440.0
    static let hoursPerDay = 24

    // MARK: - Default Settings
    // Defaults used when no user preference has been set.

    /// Default sleep goal in minutes (8 hours)
    static let defaultSleepGoalMinutes = 480
    /// Default wake time hour (7:00 AM)
    static let defaultWakeHour = 7
    /// Default wake time minute
    static let defaultWakeMinute = 0
    /// Default HRV baseline when no data is available
    static let defaultHRVBaseline = 50.0
    /// Default RHR baseline when no data is available
    static let defaultRHRBaseline = 60.0

    // MARK: - UserDefaults Keys

    static let sleepGoalKey = "sleepGoal"
    static let goalWakeTimeKey = "goalWakeTime"
    static let bedtimeNotificationsEnabledKey = "bedtimeNotificationsEnabled"

    // MARK: - HealthKit Query Ranges (days)

    /// Short lookback for weekly summaries and trends
    static let queryRangeShort = 14
    /// Medium lookback for baselines and monthly patterns
    static let queryRangeMedium = 30
    /// Long lookback for extended baselines (HRV/RHR)
    static let queryRangeLong = 90

    // MARK: - Chart & UI Constants

    /// Corner radius for card backgrounds
    static let cardCornerRadius: CGFloat = 16
    /// Corner radius for expanded/modal views
    static let expandedCornerRadius: CGFloat = 20
    /// Line width for score ring indicators
    static let scoreRingLineWidth: CGFloat = 3
    /// Line width for recovery ring indicator
    static let recoveryRingLineWidth: CGFloat = 8
    /// Recovery ring diameter
    static let recoveryRingSize: CGFloat = 70
    /// Debt ring diameter
    static let debtRingSize: CGFloat = 50
    /// Debt ring line width
    static let debtRingLineWidth: CGFloat = 6
    /// Shadow radius for cards
    static let cardShadowRadius: CGFloat = 5
    /// Shadow opacity for cards
    static let cardShadowOpacity = 0.2

    // MARK: - Chronotype Boundaries (sleep midpoint in minutes from midnight)
    // Roenneberg et al. (2004) Munich ChronoType Questionnaire.
    // Midpoint of sleep on free days determines chronotype.

    /// Midpoint < 150 min (2:30 AM) = Definite Early
    static let chronotypeDefiniteEarly = 150.0
    /// Midpoint < 210 min (3:30 AM) = Moderate Early
    static let chronotypeModerateEarly = 210.0
    /// Midpoint < 270 min (4:30 AM) = Intermediate
    static let chronotypeIntermediate = 270.0
    /// Midpoint < 330 min (5:30 AM) = Moderate Late; above = Definite Late
    static let chronotypeModerateLate = 330.0
}
