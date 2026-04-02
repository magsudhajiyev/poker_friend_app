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
  endSession,      // Coach mark on 3-dot menu
  done,
}

/// Tracks onboarding progress across multiple screens.
///
/// Each screen checks [isOnboardingActive] + [currentPhase] in initState
/// to decide whether to show its tour steps.
class OnboardingState {
  static bool isOnboardingActive = false;
  static int currentPhase = 0;
  // 0=home, 1=loggingMode, 2=sessionSetup, 3=seatSetup, 4=handLogging, 5=sessionResult
  static const int totalPhases = 6;

  /// Whether the seat dialog sub-tour still needs to run (within phase 3).
  static bool seatDialogTourPending = false;

  /// Whether the button token tour needs to run after the seat dialog closes.
  static bool buttonTokenTourPending = false;

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
    _resetGuidedHand();
  }

  static void advanceTo(int phase) {
    currentPhase = phase;
  }

  static void complete() {
    isOnboardingActive = false;
    currentPhase = 0;
    guidedHandPhase = GuidedPhase.done;
  }

  static void cancel() {
    isOnboardingActive = false;
    currentPhase = 0;
    seatDialogTourPending = false;
    buttonTokenTourPending = false;
    guidedHandPhase = GuidedPhase.done;
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
    if (phase == 4) {
      _resetGuidedHand();
    }
  }

  static void completeReplay() {
    isOnboardingActive = false;
    currentPhase = 0;
    _isReplay = false;
    guidedHandPhase = GuidedPhase.done;
  }

  static void _resetGuidedHand() {
    guidedHandPhase = GuidedPhase.gestureInfo;
    nextScriptedAction = null;
    openerSeat = null;
    heroFolded = false;
  }

  static double get progress => (currentPhase + 1) / totalPhases;

  static bool get isGuidedHandActive =>
      isOnboardingActive && currentPhase == 4 && guidedHandPhase != GuidedPhase.done;
}
