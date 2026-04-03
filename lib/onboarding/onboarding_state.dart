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
  menuSettings,    // Coach mark: open menu → highlight Settings (change blinds)
  endSession,      // Coach mark on 3-dot menu → Stop Session
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
  // 0=home, 1=loggingMode, 2=sessionSetup, 3=seatSetup, 4=handLogging, 5=sessionResult
  static const int totalPhases = 6;

  /// Whether the seat dialog sub-tour still needs to run (within phase 3).
  static bool seatDialogTourPending = false;

  /// Whether the button token tour needs to run after the seat dialog closes.
  static bool buttonTokenTourPending = false;

  /// Whether the user chose individual logging mode in phase 1.
  static bool isIndividualMode = false;

  /// Whether the IndividualSessionTrackingScreen sub-tour still needs to run.
  static bool individualTrackingTourPending = false;

  /// Whether the QuickStackUpdateScreen sub-tour still needs to run.
  static bool quickStackUpdateTourPending = false;

  /// Whether the individual mode stop-session tour is pending.
  static bool individualStopSessionTourPending = false;

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
    isIndividualMode = false;
    seatDialogTourPending = false;
    buttonTokenTourPending = false;
    individualTrackingTourPending = false;
    quickStackUpdateTourPending = false;
    individualStopSessionTourPending = false;
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
    isIndividualMode = false;
    individualTrackingTourPending = false;
    quickStackUpdateTourPending = false;
    individualStopSessionTourPending = false;
    guidedHandPhase = GuidedPhase.done;
    _notify();
  }

  static void cancel() {
    isOnboardingActive = false;
    currentPhase = 0;
    isIndividualMode = false;
    seatDialogTourPending = false;
    buttonTokenTourPending = false;
    individualTrackingTourPending = false;
    quickStackUpdateTourPending = false;
    individualStopSessionTourPending = false;
    guidedHandPhase = GuidedPhase.done;
    _notify();
  }

  /// Start onboarding from a specific phase (for Knowledge Base replay).
  /// Does NOT mark onboarding as seen on completion.
  static bool _isReplay = false;
  static bool get isReplay => _isReplay;

  static void startFromPhase(int phase, {bool individualMode = false}) {
    isOnboardingActive = true;
    currentPhase = phase;
    isIndividualMode = individualMode;
    _isReplay = true;
    seatDialogTourPending = false;
    buttonTokenTourPending = false;
    individualTrackingTourPending = false;
    quickStackUpdateTourPending = false;
    individualStopSessionTourPending = false;
    if (phase == 4) {
      _resetGuidedHand();
    }
  }

  static void completeReplay() {
    isOnboardingActive = false;
    currentPhase = 0;
    isIndividualMode = false;
    _isReplay = false;
    individualTrackingTourPending = false;
    quickStackUpdateTourPending = false;
    individualStopSessionTourPending = false;
    guidedHandPhase = GuidedPhase.done;
    _notify();
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
