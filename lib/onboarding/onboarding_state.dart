import 'package:flutter/foundation.dart';
import '../models/poker_game_state.dart'; // PlayerAction

/// Guided hand phases for phase 4 of onboarding.
///
/// Uses a reactive state machine — phases are contextual, not action-specific.
enum GuidedPhase {
  gestureInfo,     // Coach mark spotlight on info icon
  scriptedAction,  // Non-hero player: instruction for a specific scripted action
  heroTurn,        // Hero's turn: show all valid action options
  boardCards,      // Waiting for board cards dialog
  holeCards,       // Hole cards dialog
  handComplete,    // "Hand Complete!"
  tableButton,     // Coach mark: spotlight table button (manage players, settings)
  blindsPill,      // Coach mark: spotlight blinds pill (tap to update blinds)
  nextHandButton,  // Coach mark: spotlight next hand button
  gestureInfoTap,  // Coach mark: spotlight i button — ask user to tap it
  done,
}

/// Tracks onboarding progress across multiple screens.
///
/// Each screen checks [isOnboardingActive] + [currentPhase] in initState
/// to decide whether to show its tour steps.
class OnboardingState {
  static bool isOnboardingActive = false;
  static int currentPhase = 0;

  /// Notifier that fires whenever onboarding active/phase changes.
  /// Used by [OnboardingProgressBar] to self-rebuild.
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  static void _notify() => notifier.value++;
  // 0=home, 1=loggingMode, 2=sessionSetup, 3=seatSetup, 4=handLogging,
  // 5=sessionResult, 6=sessionReview (history → hand list → AI analysis)
  static const int totalPhases = 7;

  /// Whether the seat dialog sub-tour still needs to run (within phase 3).
  static bool seatDialogTourPending = false;

  /// Whether the button token tour needs to run after the seat dialog closes.
  static bool buttonTokenTourPending = false;

  /// Whether the table section tour needs to run (after session details OK in unified setup).
  static bool tableTourPending = false;


  /// Whether the session details tour needs to run (after tapping ⓘ in full session mode).
  static bool sessionDetailsTourPending = false;

  /// Whether the Session Details hub tour needs to run (after session setup → hub screen).
  static bool sessionDetailsHubTourPending = false;

  /// Set on the first (explain) ⓘ visit so the poker screen knows, when the
  /// session-details screen pops, to prompt the user to log one more hand.
  static bool sessionDetailsExplainReturnPending = false;

  /// Whether the user still needs to log the second (free-play) tour hand.
  /// Set when the Next Hand coach mark finishes; consumed when that hand
  /// completes, triggering the finish-session (ⓘ) spotlight.
  static bool secondTourHandPending = false;

  /// Whether the stack chart return tour needs to run when popping back to
  /// SessionDetailsScreen after both tour hands are complete.
  static bool stackChartReturnTourPending = false;

  /// Set after the phase-6 AI-analysis step so the tour completion (and guest
  /// sign-up) fires only once the user LEAVES the hand-details screen — not
  /// while they're still reading the analysis. Consumed on return to the
  /// hand-list screen.
  static bool tourCompletionPending = false;

  /// Whether the session-history tour needs to run (phase 6, after tapping Sessions nav).
  static bool sessionHistoryTourPending = false;

  /// Whether the hand-list tour needs to run (phase 6, inside session analytics).
  static bool handListTourPending = false;

  /// Whether the hand-card tour needs to run (phase 6, inside logged hands list).
  static bool handCardTourPending = false;

  /// Whether the AI-analysis tour needs to run (phase 6, inside hand details).
  static bool aiAnalysisTourPending = false;

  /// Session id of the tutorial session created during the tour, so phase-6
  /// tours can spotlight the exact card without querying.
  static String? tourSessionId;

  // ---------------------------------------------------------------------------
  // Phase 4 — Guided hand state
  // ---------------------------------------------------------------------------

  /// Current phase in the guided example hand.
  static GuidedPhase guidedHandPhase = GuidedPhase.gestureInfo;

  /// The scripted action to instruct for non-hero players.
  static PlayerAction? nextScriptedAction;

  /// Seat number of the player who opened (raised) preflop.
  static int? openerSeat;

  /// Whether the hero has folded (affects who remains in the hand).
  static bool heroFolded = false;

  // ---------------------------------------------------------------------------

  static void start() {
    isOnboardingActive = true;
    currentPhase = 0;
    seatDialogTourPending = false;
    buttonTokenTourPending = false;
    tableTourPending = false;
    sessionDetailsTourPending = false;
    sessionDetailsHubTourPending = false;
    sessionDetailsExplainReturnPending = false;
    secondTourHandPending = false;

    stackChartReturnTourPending = false;
    tourCompletionPending = false;
    sessionHistoryTourPending = false;
    handListTourPending = false;
    handCardTourPending = false;
    aiAnalysisTourPending = false;
    tourSessionId = null;
    _resetGuidedHand();
    _notify();
  }

  static void advanceTo(int phase) {
    currentPhase = phase;
    _notify();
  }

  static void complete() {
    isOnboardingActive = false;
    currentPhase = 0;
    sessionDetailsTourPending = false;
    sessionDetailsHubTourPending = false;
    sessionDetailsExplainReturnPending = false;
    secondTourHandPending = false;

    stackChartReturnTourPending = false;
    tourCompletionPending = false;
    sessionHistoryTourPending = false;
    handListTourPending = false;
    handCardTourPending = false;
    aiAnalysisTourPending = false;
    guidedHandPhase = GuidedPhase.done;
    _notify();
  }

  static void cancel() {
    isOnboardingActive = false;
    currentPhase = 0;
    seatDialogTourPending = false;
    buttonTokenTourPending = false;
    tableTourPending = false;
    sessionDetailsTourPending = false;
    sessionDetailsHubTourPending = false;
    sessionDetailsExplainReturnPending = false;
    secondTourHandPending = false;

    stackChartReturnTourPending = false;
    tourCompletionPending = false;
    sessionHistoryTourPending = false;
    handListTourPending = false;
    handCardTourPending = false;
    aiAnalysisTourPending = false;
    guidedHandPhase = GuidedPhase.done;
    _notify();
  }

  /// Start onboarding from a specific phase (for Knowledge Base replay).
  /// Does NOT mark onboarding as seen on completion.
  static bool _isReplay = false;
  static bool get isReplay => _isReplay;

  static void startFromPhase(int phase) {
    isOnboardingActive = true;
    currentPhase = phase;
    _isReplay = true;
    seatDialogTourPending = false;
    buttonTokenTourPending = false;
    tableTourPending = false;
    sessionDetailsTourPending = false;
    sessionDetailsHubTourPending = false;
    sessionDetailsExplainReturnPending = false;
    secondTourHandPending = false;

    stackChartReturnTourPending = false;
    tourCompletionPending = false;
    sessionHistoryTourPending = false;
    handListTourPending = false;
    handCardTourPending = false;
    aiAnalysisTourPending = false;
    if (phase == 4) {
      _resetGuidedHand();
    }
  }

  static void completeReplay() {
    isOnboardingActive = false;
    currentPhase = 0;
    _isReplay = false;
    sessionDetailsTourPending = false;
    sessionDetailsHubTourPending = false;
    sessionDetailsExplainReturnPending = false;
    secondTourHandPending = false;

    stackChartReturnTourPending = false;
    tourCompletionPending = false;
    sessionHistoryTourPending = false;
    handListTourPending = false;
    handCardTourPending = false;
    aiAnalysisTourPending = false;
    guidedHandPhase = GuidedPhase.done;
    _notify();
  }

  static void _resetGuidedHand() {
    guidedHandPhase = GuidedPhase.gestureInfo;
    nextScriptedAction = null;
    openerSeat = null;
    heroFolded = false;
  }

  /// Resets guided hand state for the second tour hand so scripted guidance
  /// re-activates, but preserves one-time coach mark flags (gesture info,
  /// drawing board, stack ring, undo) that were already shown in hand 1.
  static void resetForSecondHand() {
    guidedHandPhase = GuidedPhase.scriptedAction;
    openerSeat = null;
    heroFolded = false;
    // Do NOT reset nextScriptedAction — _beginScriptedHand() will set it
  }

  /// Maps internal phase to display step.
  /// Replay skips phase 0 (Home), so offset by 1 less.
  /// Phases 2+3 are merged into one step (unified setup screen).
  static int get displayStep {
    final offset = _isReplay ? 0 : 1; // replay starts at phase 1 = step 1
    if (currentPhase <= 2) return currentPhase + offset; // 0→1, 1→2, 2→3 (normal) | 1→1, 2→2 (replay)
    if (currentPhase == 3) return 2 + offset;            // same step as phase 2
    return currentPhase - 1 + offset;                    // 4→4, 5→5, 6→6 (normal) | 4→3, 5→4 (replay)
  }

  static int get displayTotalSteps => _isReplay ? 4 : 6;

  static double get progress => displayStep / displayTotalSteps;

  static bool get isGuidedHandActive =>
      isOnboardingActive && currentPhase == 4 && guidedHandPhase != GuidedPhase.done;

  /// True for the entire guided session (phase 4), including the free-play
  /// second hand where [guidedHandPhase] is already `done`. Used to suppress
  /// the poker screen's auto-advance so the tour controls hand flow.
  static bool get isGuidedSessionActive =>
      isOnboardingActive && currentPhase == 4;
}
