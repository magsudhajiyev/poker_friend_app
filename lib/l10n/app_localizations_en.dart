// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navOpponents => 'Opponents';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonError => 'Error';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonSave => 'Save';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDone => 'Done';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonNoData => 'No data available';

  @override
  String get commonClose => 'Close';

  @override
  String get commonNotAvailable => 'N/A';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonUpdate => 'Update';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonToday => 'Today';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsSubtitle => 'Advanced Analytics';

  @override
  String get statsHandsPlayed => 'Hands Played';

  @override
  String get statsFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get statsWinRate => 'Win Rate';

  @override
  String get statsSessionStatistics => 'Session Statistics';

  @override
  String get statsSessions => 'Sessions';

  @override
  String get statsTotalTime => 'Total Time';

  @override
  String get statsAvgSession => 'Avg Session';

  @override
  String get statsPlayToSee => 'Play sessions to see time statistics';

  @override
  String get statsLoadingMessage => 'Loading statistics...';

  @override
  String get statsFetchingMessage => 'Fetching user stats...';

  @override
  String statsFailedToLoad(String error) {
    return 'Failed to load statistics: $error';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Choose app language';

  @override
  String get settingsLanguageSystem => 'System Default';

  @override
  String get settingsKnowledgeBase => 'KNOWLEDGE BASE';

  @override
  String get settingsGuidedTour => 'Guided Tour';

  @override
  String get settingsGuidedTourSubtitle => 'Replay onboarding tours';

  @override
  String get settingsFullLoggingTour => 'Full Logging Tour';

  @override
  String get settingsFullLoggingTourSubtitle =>
      'Complete session tracking flow';

  @override
  String get settingsIndividualLoggingTour => 'Individual Logging Tour';

  @override
  String get settingsIndividualLoggingTourSubtitle =>
      'Single hand tracking flow';

  @override
  String get settingsUnderstandingStats => 'Understanding Your Stats';

  @override
  String get settingsUnderstandingStatsSubtitle =>
      'Learn what each metric means';

  @override
  String get settingsClubsEvents => 'Clubs & Events';

  @override
  String get settingsClubsEventsSubtitle => 'How club play works';

  @override
  String get settingsAdmin => 'ADMIN';

  @override
  String get settingsClubRequests => 'Club Requests';

  @override
  String get settingsClubRequestsSubtitle => 'Manage registration requests';

  @override
  String get settingsSupportRequests => 'Support Requests';

  @override
  String get settingsSupportRequestsSubtitle => 'Manage user support tickets';

  @override
  String get settingsNotificationTester => 'Notification Tester';

  @override
  String get settingsNotificationTesterSubtitle =>
      'Preview all notification designs';

  @override
  String get profileUpgrade => 'Upgrade';

  @override
  String get profileUsername => 'Username';

  @override
  String get profileNotSet => 'Not set';

  @override
  String get profileChange => 'Change';

  @override
  String get profileSetUsername => 'Set username';

  @override
  String get profileUseNicknameInGames => 'Use nickname in games';

  @override
  String profileUseNicknameDescription(String username) {
    return 'Show @$username instead of your name in events and hand logging';
  }

  @override
  String get profileBankrollGoal => 'Bankroll Goal';

  @override
  String get profileUpdateGoal => 'Update Goal';

  @override
  String get profileCurrentBankroll => 'Current Bankroll';

  @override
  String get profileUpdateBankroll => 'Update Bankroll';

  @override
  String get profileAddSessionResult => 'Add Session Result';

  @override
  String get profileSessionResultHint =>
      'Enter positive for wins, negative for losses';

  @override
  String get profileAddResult => 'Add Result';

  @override
  String get profileGoalUpdatedSuccess => 'Goal updated successfully!';

  @override
  String get profileErrorUpdatingGoal => 'Error updating goal';

  @override
  String get profileBankrollUpdatedSuccess => 'Bankroll updated successfully!';

  @override
  String get profileErrorUpdatingBankroll => 'Error updating bankroll';

  @override
  String get profileSessionResultAdded => 'Session result added!';

  @override
  String get profileErrorAddingResult => 'Error adding session result';

  @override
  String get profilePleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String get profileLogOut => 'Log out';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignOutConfirmation => 'Are you sure you want to sign out?';

  @override
  String get sessionHistoryTitle => 'Session History';

  @override
  String get sessionLast30Days => 'Last 30 days';

  @override
  String get sessionUpgradeForFullHistory => 'Upgrade for full history';

  @override
  String get sessionLoadingMessage => 'Loading sessions...';

  @override
  String sessionNoSessions(String gameType) {
    return 'No $gameType Sessions';
  }

  @override
  String sessionPlayToSee(String gameType) {
    return 'Play some $gameType Poker hands\nto see the results';
  }

  @override
  String get sessionLive => 'Live';

  @override
  String sessionPlayersCount(int count) {
    return '$count Players';
  }

  @override
  String get sessionSyncingToCloud => 'Syncing to cloud...';

  @override
  String get sessionClearAllTitle => 'Clear All Sessions?';

  @override
  String get sessionClearAllDescription =>
      'This will permanently delete all poker sessions and hands from both Firebase and local storage.';

  @override
  String get sessionClearAllWarning => 'This action cannot be undone!';

  @override
  String get sessionClearAll => 'Clear All';

  @override
  String get sessionClearedSuccessfully =>
      'All sessions have been cleared successfully';

  @override
  String sessionHandDetails(int handNumber) {
    return 'Hand #$handNumber Details';
  }

  @override
  String get sessionYourCards => 'Your Cards:';

  @override
  String get sessionBoardCards => 'Board Cards:';

  @override
  String get sessionPotByStreet => 'Pot by Street:';

  @override
  String get sessionActions => 'Actions:';

  @override
  String get sessionNoActionsRecorded => 'No actions recorded';

  @override
  String get sessionNoCardsRecorded => 'No cards recorded';

  @override
  String get sessionFinalPot => 'Final Pot:';

  @override
  String sessionChoppedPot(int count) {
    return 'Chopped Pot ($count winners):';
  }

  @override
  String get sessionWinnerNotAvailable => 'Winner information not available';

  @override
  String get opponentsTitle => 'Opponents';

  @override
  String opponentsCountFree(int count, int max) {
    return '$count/$max free';
  }

  @override
  String opponentsCountPremium(int count) {
    return '$count tracked players';
  }

  @override
  String get opponentsSearchHint => 'Search opponents...';

  @override
  String get opponentsLoadingMessage => 'Loading opponents...';

  @override
  String get opponentsNoResults => 'No Results';

  @override
  String get opponentsEmptyTitle => 'No Opponents Yet';

  @override
  String get opponentsEmptySubtitle =>
      'Opponents to track their playing styles and statistics';

  @override
  String get opponentsEmptySearchSubtitle => 'Try a different search term';

  @override
  String get opponentsAddButton => 'Add Opponent';

  @override
  String opponentsLastSeen(String date) {
    return 'Last Seen: $date';
  }

  @override
  String get opponentsHands => 'Hands';

  @override
  String get opponentsEditMenu => 'Edit Opponent';

  @override
  String get opponentsDeleteMenu => 'Delete Opponent';

  @override
  String get opponentsAddDialogTitle => 'Add Opponent';

  @override
  String get opponentsEditDialogTitle => 'Edit Opponent';

  @override
  String get opponentsNameHint => 'Opponent Name';

  @override
  String get opponentsNotesHint => 'Notes (Optional)';

  @override
  String get opponentsPickColor => 'Pick a color';

  @override
  String get opponentsAddedSuccess => 'Opponent added successfully';

  @override
  String get opponentsUpdatedSuccess => 'Opponent updated successfully';

  @override
  String get opponentsDeleteConfirmTitle => 'Delete opponent?';

  @override
  String opponentsDeleteConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?\nThis action cannot be undone';
  }

  @override
  String get opponentsDeletedSuccess => 'Opponent deleted successfully';

  @override
  String get opponentsAnalyticsTitle => 'Opponent Analytics';

  @override
  String get opponentsAnalyticsTotalLabel => 'Total Opponents';

  @override
  String get opponentsAnalyticsHandsTracked => 'Total Hands Tracked';

  @override
  String get opponentsAnalyticsAverage => 'Average Hands/Opponent';

  @override
  String get opponentsAnalyticsMostPlayed => 'Most Played Against';

  @override
  String get opponentsAnalyticsDistribution => 'Player Type Distribution:';

  @override
  String get opponentsClearAllTitle => 'Clear All Opponents?';

  @override
  String get opponentsClearAllMessage =>
      'This will permanently delete all opponent data. This action cannot be undone!';

  @override
  String get opponentsClearAllButton => 'Clear All';

  @override
  String get opponentsClearedSuccess => 'All opponents cleared';

  @override
  String get setupSessionSetup => 'Session Setup';

  @override
  String get setupSessionName => 'Session Name';

  @override
  String get setupSessionNameHint => 'e.g., \"Friday Night Poker\"';

  @override
  String get setupGameType => 'Game Type';

  @override
  String get setupCashGame => 'Cash Game';

  @override
  String get setupTournament => 'Tournament';

  @override
  String get setupSmallBlind => 'Small Blind';

  @override
  String get setupBigBlind => 'Big Blind';

  @override
  String get setupBuyInAmount => 'Buy-in Amount';

  @override
  String get setupEnterAmount => 'Enter amount';

  @override
  String get setupStartingStackEqualsBuyIn =>
      'Starting stack equals your buy-in.';

  @override
  String get setupStartingStack => 'Starting Stack';

  @override
  String get setupEnterChipStack => 'Enter chip stack';

  @override
  String setupMustBeAtLeastBigBlind(int bigBlind) {
    return 'Must be at least the Big Blind ($bigBlind)';
  }

  @override
  String get setupBbAnte => 'BB Ante';

  @override
  String get setupTableSection => 'TABLE';

  @override
  String get setupTableInstructions =>
      'Tap a seat to add a player. Drag the button to set dealer.';

  @override
  String get setupStartSession => 'Start Session';

  @override
  String get setupMe => 'Me';

  @override
  String setupPlayerSeat(int seatNumber) {
    return 'Player $seatNumber';
  }

  @override
  String get setupHero => 'Hero';

  @override
  String get homeLoadingPokerData => 'Loading your poker data...';

  @override
  String get homeWelcomeBack => 'Welcome back';

  @override
  String get homeNoActiveSessions => 'No active sessions';

  @override
  String get homeLiveSessions => 'Live Sessions';

  @override
  String get homeClubNotFound => 'Club not found';

  @override
  String get homeEventNotFound => 'Event not found';

  @override
  String get homeRecentActivity => 'Recent Activity';

  @override
  String get homeWinRate => 'Win Rate';

  @override
  String get homeHours => 'Hours';

  @override
  String get homePlayStyle => 'Play Style';

  @override
  String get homeBankroll => 'Bankroll';

  @override
  String homeBankrollOfGoal(String current, String goal) {
    return '$current of $goal';
  }

  @override
  String homeAmountLeft(String amount) {
    return '$amount left';
  }

  @override
  String get homeEarnings => 'Earnings';

  @override
  String homeAvgAmount(String amount) {
    return 'Avg $amount';
  }

  @override
  String get homeNoEarningsDataYet => 'No earnings data yet';

  @override
  String get homeRecentSessions => 'Recent Sessions';

  @override
  String get homeViewAll => 'View All';

  @override
  String get homeNoRecentSessions => 'No recent sessions';

  @override
  String get homeStartFirstSession => 'Start your first poker session!';

  @override
  String get homeAddNew => 'Add New';

  @override
  String get homeUpcomingEvents => 'Upcoming Events';

  @override
  String get homeNoRecentEvents => 'No recent events';

  @override
  String get homeAddFirstEvent => 'Add your first poker event!';

  @override
  String homePlayersCount(int count) {
    return '$count Players';
  }

  @override
  String homeGoingCount(int count) {
    return '$count going';
  }

  @override
  String get homePrivateGame => 'Private Game';

  @override
  String get homeHomeGame => 'Home Game';

  @override
  String get homeOnline => 'Online';

  @override
  String get homeEditEvent => 'Edit Event';

  @override
  String get homeDeleteEvent => 'Delete Event';

  @override
  String get homeEventName => 'Event Name';

  @override
  String get homeLocationVenue => 'Location/Venue';

  @override
  String get homeBuyInAmount => 'Buy in amount';

  @override
  String get homeSelectDate => 'Select date:';

  @override
  String get homeSaveChanges => 'Save Changes';

  @override
  String homeDeleteEventConfirm(String eventName) {
    return 'Delete $eventName?';
  }

  @override
  String homeDeleteEventDescription(String eventName) {
    return 'Are you sure you want to delete \"$eventName\"?';
  }

  @override
  String get homeEventDeletedSuccessfully => 'Event deleted successfully';

  @override
  String get homeClubInvitation => 'Club Invitation';

  @override
  String get homeYouveBeenInvitedToJoin => 'You\'ve been invited to join';

  @override
  String get homeDecline => 'Decline';

  @override
  String get homeAccept => 'Accept';

  @override
  String get homeInvitationDeclined => 'Invitation Declined';

  @override
  String get homeInvitationAccepted => 'Invitation Accepted';

  @override
  String get homeClubInvitations => 'Club Invitations';

  @override
  String get homeLater => 'Later';

  @override
  String get homeViewInvitations => 'View Invitations';

  @override
  String get homeNoEarningsDataTitle => 'No Earnings Data Yet';

  @override
  String get homeNoEarningsDataDescription =>
      'Add some session results first to view your earnings chart. You can add results from the Profile page.';

  @override
  String handHandNumber(int number) {
    return 'Hand #$number';
  }

  @override
  String handFreeCounter(int used, int max) {
    return '$used/$max free';
  }

  @override
  String get handNextHand => 'Next Hand';

  @override
  String get handFoldedToMe => 'Folded to me';

  @override
  String get handUndoLastAction => 'Undo Last Action';

  @override
  String get handAllInHand => 'ALL IN HAND';

  @override
  String get handPot => 'Pot';

  @override
  String get handStack => 'Stack';

  @override
  String get handToAct => 'To Act';

  @override
  String get handToActYou => 'You';

  @override
  String get handStopSessionTitle => 'Stop Session?';

  @override
  String get handStopSessionMessage =>
      'Are you sure you want to stop this session? All hands will be saved.';

  @override
  String get handStop => 'Stop';

  @override
  String get handChangeTable => 'Change Table';

  @override
  String get handBlinds => 'Blinds';

  @override
  String get handTakesEffectNextHand => 'Takes effect next hand';

  @override
  String get handLeaveSession => 'Leave Session?';

  @override
  String get handSaveAndExit => 'Save & Exit';

  @override
  String get handDiscardAndExit => 'Discard & Exit';

  @override
  String get handAdjustStack => 'Adjust Stack';

  @override
  String get handEnterStackAmount => 'Enter stack amount';

  @override
  String get handGestureGuide => 'Gesture Guide';

  @override
  String get handManagePlayers => 'Manage Players';

  @override
  String get handStopSession => 'Stop Session';

  @override
  String get handRebuy => 'Rebuy';

  @override
  String get handGestures => 'Gestures';

  @override
  String get handGestureTap => 'Tap';

  @override
  String get handGestureCheckCall => 'Check / Call';

  @override
  String get handGestureSwipeOut => 'Swipe Out';

  @override
  String get handGestureSwipeUp => 'Swipe Up';

  @override
  String get handGestureBetRaise => 'Bet / Raise';

  @override
  String get handStreetComplete => 'Street Complete';

  @override
  String get handWinsThePot => 'wins the pot';

  @override
  String get handHandComplete => 'Hand Complete';

  @override
  String get handTapToContinue => 'Tap to continue';

  @override
  String get handRaiseAmount => 'Raise Amount';

  @override
  String get handBetAmount => 'Bet Amount';

  @override
  String get handPleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String get handConfirmRebuy => 'Confirm Rebuy';

  @override
  String get handRebuyReplaceStack =>
      'Proceeding with a rebuy will replace your current stack. Are you sure you want to continue?';

  @override
  String get handProceed => 'Proceed';

  @override
  String get handEnterRebuyDetails => 'Enter rebuy details for the tournament';

  @override
  String get handRebuyAmount => 'Rebuy Amount';

  @override
  String get handNewStackSize => 'New Stack Size';

  @override
  String get handChipCountAfterRebuy => 'Chip count after rebuy';

  @override
  String get handSessionInfo => 'Session Info';

  @override
  String handTotalInvested(String amount) {
    return 'Total Invested: $amount';
  }

  @override
  String handRebuysCount(int count) {
    return 'Rebuys: $count';
  }

  @override
  String get handAddRebuy => 'Add Rebuy';

  @override
  String get handPleaseEnterValidAmounts => 'Please enter valid amounts';

  @override
  String get handHandInProgress => 'Hand in Progress';

  @override
  String get handHandInProgressMessage =>
      'There\'s a hand in progress. Moving to the next hand will discard all actions and restore player stacks.';

  @override
  String get handMoveToNextHand => 'Move to Next Hand';

  @override
  String get handMainPot => 'Main Pot';

  @override
  String handSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String get handPokerSession => 'Poker Session';

  @override
  String handActionsHandNumber(String number) {
    return 'Hand #$number';
  }

  @override
  String handActionsPosition(String position) {
    return 'Position: $position';
  }

  @override
  String get handActionsShareHand => 'Share Hand';

  @override
  String get handActionsShowHoleCards => 'Show hole cards';

  @override
  String get handActionsShowHoleCardsSubtitle =>
      'Your cards will be visible in the shared link';

  @override
  String get handActionsHideHoleCards => 'Hide hole cards';

  @override
  String get handActionsHideHoleCardsSubtitle =>
      'Your cards will be hidden from the shared link';

  @override
  String get handActionsShareMessage => 'Check out this hand on Final Table!';

  @override
  String handActionsShareSubject(String number) {
    return 'Poker Hand #$number';
  }

  @override
  String get handActionsFailedToShareHand => 'Failed to share hand';

  @override
  String get handActionsGeneratingExport => 'Generating PokerStars export...';

  @override
  String handActionsExportedSuccessfully(String number) {
    return 'Hand #$number exported successfully!';
  }

  @override
  String handActionsFailedToExport(String error) {
    return 'Failed to export hand: $error';
  }

  @override
  String get handActionsMissingHeroCards => 'Missing Hero Cards';

  @override
  String get handActionsMissingHeroCardsMessage =>
      'AI analysis requires your hole cards to be recorded. This hand cannot be analyzed because hero cards are missing.';

  @override
  String get handActionsYourCards => 'Your Cards';

  @override
  String get handActionsOpponentCards => 'Opponent Cards';

  @override
  String handActionsPlayerSeat(int id) {
    return 'Player $id';
  }

  @override
  String get handActionsPot => 'POT';

  @override
  String get handActionsBlinds => 'BLINDS';

  @override
  String get handActionsWinner => 'WINNER';

  @override
  String handActionsPlayersCount(int count) {
    return '$count players';
  }

  @override
  String get handActionsActionSummary => 'Action Summary';

  @override
  String get handActionsPreflop => 'PREFLOP';

  @override
  String get handActionsBoard => 'BOARD';

  @override
  String get handActionsPlayer => 'PLAYER';

  @override
  String get handActionsStack => 'STACK';

  @override
  String get handActionsAction => 'ACTION';

  @override
  String get handActionsAmount => 'AMT';

  @override
  String get handActionsYou => 'You';

  @override
  String get handActionsAllIn => 'ALL IN';

  @override
  String get handActionsNotes => 'Notes';

  @override
  String get handActionsAnalyzingHand => 'Analyzing Hand...';

  @override
  String get handActionsHeroCardsMissing => 'Hero Cards Missing';

  @override
  String get handActionsUnlockAiAnalysis => 'Unlock AI Analysis';

  @override
  String get handActionsAnalysisComplete => 'Analysis Complete';

  @override
  String get handActionsAiAnalyzerBeta => 'AI Analyzer (beta)';

  @override
  String get handActionsAnalysisFailed => 'Analysis Failed';

  @override
  String get handActionsAiAnalysis => 'AI Analysis';

  @override
  String get handActionsStreetByStreetBreakdown => 'Street-by-Street Breakdown';

  @override
  String handActionsAnalysisCompletedIn(String time) {
    return 'Analysis completed in ${time}s';
  }

  @override
  String get handActionsFailedToUpdateStar => 'Failed to update star status';

  @override
  String handActionsPotAmount(String amount) {
    return 'Pot: $amount';
  }

  @override
  String opponentDetailHandsTracked(int count) {
    return '$count hands tracked';
  }

  @override
  String get opponentDetailNoDataYet => 'No data yet';

  @override
  String get opponentDetailHands => 'Hands';

  @override
  String get opponentDetailLastSeen => 'Last Seen:';

  @override
  String get opponentDetailNotes => 'Notes';

  @override
  String get opponentDetailEditOpponent => 'Edit Opponent';

  @override
  String get opponentDetailDeleteOpponent => 'Delete Opponent';

  @override
  String get opponentDetailStatistics => 'Statistics';

  @override
  String get opponentDetailNoStatisticsAvailable => 'No statistics available';

  @override
  String get opponentDetailAggressionFreq => 'Aggression Freq';

  @override
  String get opponentDetailShowdownPercent => 'Showdown %';

  @override
  String get opponentDetailHandHistory => 'Hand History';

  @override
  String get opponentDetailViewAllHands =>
      'View all hands played with this opponent';

  @override
  String get opponentDetailViewHandHistory => 'View Hand History';

  @override
  String get opponentDetailNoHandsFound => 'No Hands Found';

  @override
  String opponentDetailNoHandsMessage(String name) {
    return 'You haven\'t played any hands with \"$name\" yet';
  }

  @override
  String get opponentDetailOpponentName => 'Opponent Name';

  @override
  String get opponentDetailNotesOptional => 'Notes (Optional)';

  @override
  String get opponentDetailPickColor => 'Pick a color';

  @override
  String get opponentDetailColorRed => 'Red';

  @override
  String get opponentDetailColorLightBlue => 'Light Blue';

  @override
  String get opponentDetailColorGreen => 'Green';

  @override
  String get opponentDetailColorOrange => 'Orange';

  @override
  String get opponentDetailColorPurple => 'Purple';

  @override
  String get opponentDetailColorTeal => 'Teal';

  @override
  String get opponentDetailColorPink => 'Pink';

  @override
  String get opponentDetailColorIndigo => 'Indigo';

  @override
  String get opponentDetailUpdatedSuccessfully =>
      'Opponent updated successfully';

  @override
  String get opponentDetailDeleteConfirmTitle => 'Delete opponent?';

  @override
  String opponentDetailDeleteConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?\nThis action can not be undone';
  }

  @override
  String get opponentDetailDeletedSuccessfully =>
      'Opponent deleted successfully';

  @override
  String opponentDetailErrorDeleting(String error) {
    return 'Error deleting opponent: $error';
  }

  @override
  String get individualSessionCreatedLocally =>
      'Session created locally. Will sync to cloud when connection is available.';

  @override
  String get individualUpdateCurrentStack => 'Update Current Stack';

  @override
  String get individualCurrentStack => 'Current Stack:';

  @override
  String get individualSetNewTotal => 'Set New Total';

  @override
  String get individualEnterNewTotalStack => 'Enter new total stack';

  @override
  String get individualAddSubtractAmount => 'Add/Subtract Amount';

  @override
  String get individualAmount => 'Amount';

  @override
  String get individualSetTotal => 'Set Total';

  @override
  String get individualNoteLabel => 'Note (optional)';

  @override
  String get individualNoteHint => 'e.g. Won big pot with AA';

  @override
  String get individualUpdateBlinds => 'Update Blinds';

  @override
  String get individualSmallBlind => 'Small Blind';

  @override
  String get individualBigBlind => 'Big Blind';

  @override
  String get individualBbMode => 'BB Mode';

  @override
  String get individualCurrentStackLabel => 'Current Stack';

  @override
  String get individualSessionInfo => 'Session Info';

  @override
  String get individualStartingStack => 'Starting Stack';

  @override
  String get individualInitialBuyIn => 'Initial Buy-in';

  @override
  String get individualRebuys => 'Rebuys';

  @override
  String get individualTotalInvested => 'Total Invested';

  @override
  String get individualBlindsLabel => 'Blinds';

  @override
  String get individualHandsLogged => 'Hands Logged';

  @override
  String get individualLogAHand => 'Log a Hand';

  @override
  String get individualGoBackToHand => 'Go Back to Hand';

  @override
  String get individualStackChart => 'Stack Chart';

  @override
  String get individualCompleteHandToSee =>
      'Complete a hand to see your stack trend';

  @override
  String get individualStopSessionTitle => 'Stop Session?';

  @override
  String get individualStopSessionMessage =>
      'Are you sure you want to stop this session? All hands will be saved.';

  @override
  String get individualStop => 'Stop';

  @override
  String get individualConfirmRebuy => 'Confirm Rebuy';

  @override
  String individualRebuyCurrentStack(String stack) {
    return 'You currently have $stack remaining.';
  }

  @override
  String get individualRebuyReplaceMessage =>
      'Proceeding with a rebuy will replace your current stack. Are you sure you want to continue?';

  @override
  String get individualProceedWithRebuy => 'Proceed with Rebuy';

  @override
  String get individualAddOn => 'Add-on';

  @override
  String get individualAddOnDescription =>
      'Enter add-on amount to increase your total investment';

  @override
  String get individualAddOnAmount => 'Add-on Amount';

  @override
  String get individualAddOnConfirm => 'Add';

  @override
  String get individualAddOnDescriptionTournament =>
      'Enter add-on price and chips received';

  @override
  String get individualAddOnPrice => 'Add-on Price';

  @override
  String get individualAddOnChips => 'Chips Received';

  @override
  String get individualRebuy => 'Rebuy';

  @override
  String get individualEnterRebuyAmount =>
      'Enter rebuy amount (stack will equal rebuy amount)';

  @override
  String get individualEnterRebuyAmountAndStack =>
      'Enter rebuy amount and new stack size';

  @override
  String get individualRebuyAmount => 'Rebuy Amount';

  @override
  String get individualNewStackSize => 'New Stack Size';

  @override
  String get individualChipCountAfterRebuy => 'Chip count after rebuy';

  @override
  String individualTotalInvestedAmount(String amount) {
    return 'Total Invested: \$$amount';
  }

  @override
  String individualCurrentStackAmount(String stack) {
    return 'Current Stack: $stack';
  }

  @override
  String individualRebuysCount(int count) {
    return 'Rebuys: $count';
  }

  @override
  String get individualAddRebuy => 'Add Rebuy';

  @override
  String get individualPleaseEnterValidRebuy =>
      'Please enter a valid rebuy amount';

  @override
  String get individualPleaseEnterValidStack =>
      'Please enter a valid stack size';

  @override
  String individualRebuyAddedSimple(String amount) {
    return 'Rebuy added: \$$amount';
  }

  @override
  String individualRebuyAddedWithStack(String amount, String stack) {
    return 'Rebuy added: \$$amount (Stack: $stack)';
  }

  @override
  String get authWelcome => 'Welcome to Final Table';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authRegister => 'Register';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authDisplayName => 'Display Name';

  @override
  String get authConfirmPassword => 'Confirm Password';

  @override
  String get authPleaseEnterEmail => 'Please enter your email';

  @override
  String get authPleaseEnterValidEmail => 'Please enter a valid email';

  @override
  String get authPleaseEnterPassword => 'Please enter your password';

  @override
  String get authPleaseEnterName => 'Please enter your name';

  @override
  String get authNameMinLength => 'Name must be at least 2 characters';

  @override
  String get authPleaseEnterAPassword => 'Please enter a password';

  @override
  String get authPasswordMinLength => 'Password must be at least 6 characters';

  @override
  String get authPleaseConfirmPassword => 'Please confirm your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authForgotPassword => 'Forgot Password?';

  @override
  String get authResetPassword => 'Reset Password';

  @override
  String get authResetPasswordMessage =>
      'Enter your email address to receive a password reset link.';

  @override
  String get authSendResetLink => 'Send Reset Link';

  @override
  String get authPasswordResetSent => 'Password reset email sent!';

  @override
  String get paywallRestore => 'Restore';

  @override
  String get paywallTitle => 'FINAL TABLE PREMIUM';

  @override
  String paywallUnlockFeature(String featureName) {
    return 'Unlock $featureName';
  }

  @override
  String get paywallGoPremium => 'Go Premium';

  @override
  String get paywallFeatureSubtitle =>
      'This feature is part of Final Table Premium. Pick a plan that fits how you play.';

  @override
  String get paywallGeneralSubtitle =>
      'Unlock everything Final Table has to offer. Track more hands, analyze your game, run your club.';

  @override
  String get paywallProTier => 'PRO';

  @override
  String get paywallFreeTrialBadge => '7-day free trial';

  @override
  String get paywallProDescription =>
      'Everything you need to master your game.';

  @override
  String get paywallUnlimitedHandLogging => 'Unlimited hand logging';

  @override
  String get paywallFullSessionHistory => 'Full session history';

  @override
  String get paywallAiHandAnalysis => 'AI hand analysis';

  @override
  String get paywallExportHandsCsv => 'Export hands to CSV';

  @override
  String get paywallProMonthly => '\$19.99/mo';

  @override
  String get paywallProYearly => '\$199.99/yr';

  @override
  String get paywallStartFreeTrial => 'Start 7-Day Free Trial';

  @override
  String get paywallEliteTier => 'ELITE';

  @override
  String get paywallEliteDescription => 'Take your game to the next level.';

  @override
  String get paywallEverythingInProElite => 'Everything in Pro';

  @override
  String get paywallEliteFeature1 => 'Advanced opponent profiling';

  @override
  String get paywallEliteFeature2 => 'Detailed session analytics';

  @override
  String get paywallEliteFeature3 => 'Priority support';

  @override
  String get paywallEliteMonthly => '\$29.99/mo';

  @override
  String get paywallEliteYearly => '\$249.99/yr';

  @override
  String get paywallGetElite => 'Get Elite';

  @override
  String get paywallClubTier => 'CLUB';

  @override
  String get paywallClubDescription =>
      'For home games, clubs, and live venues.';

  @override
  String get paywallEverythingInPro => 'Everything in Pro';

  @override
  String get paywallClubManagement => 'Club management & member roles';

  @override
  String get paywallLiveDealerVoice => 'Live dealer voice logging';

  @override
  String get paywallMultiTableEvents => 'Multi-table events with rankings';

  @override
  String get paywallClubMonthly => '\$39.99/mo';

  @override
  String get paywallClubYearly => '\$299.99/yr';

  @override
  String get paywallGetClub => 'Get Club';

  @override
  String get paywallDisclaimer =>
      'Subscriptions auto-renew. Cancel anytime from your account settings.';

  @override
  String get paywallTerms => 'Terms';

  @override
  String get paywallPrivacy => 'Privacy';

  @override
  String get paywallPurchasesRestored => 'Purchases restored';

  @override
  String get paywallNoPreviousPurchases => 'No previous purchases found';

  @override
  String paywallComingSoon(String tier) {
    return '$tier subscriptions coming soon';
  }

  @override
  String trialConfirmTitle(String tier) {
    return 'The first 7 days of $tier are on us';
  }

  @override
  String get trialConfirmTodayTitle => 'Today';

  @override
  String trialConfirmTodayBody(String tier) {
    return 'Get full access to all $tier features';
  }

  @override
  String get trialConfirmReminderTitle => 'In 5 days';

  @override
  String get trialConfirmReminderBody =>
      'Get a reminder before your free trial ends';

  @override
  String get trialConfirmStartTitle => 'In 7 days';

  @override
  String get trialConfirmStartBody =>
      'Your subscription starts, unless you cancel anytime before';

  @override
  String get trialConfirmPriceSummary => 'Try 7 days free, then';

  @override
  String get trialConfirmStartCta => 'Start my 7-day free trial';

  @override
  String get trialConfirmDisclaimer =>
      'No charges yet. Cancel anytime on the App Store.';

  @override
  String get introGameSetup => 'Game Setup';

  @override
  String get introConfigureSession => 'Configure your session';

  @override
  String get introSmallBlind => 'Small Blind';

  @override
  String get introBigBlind => 'Big Blind';

  @override
  String get introPlayers => 'Players';

  @override
  String get introGameType => 'Game Type';

  @override
  String get introBbAnte => 'BB Ante';

  @override
  String get introBbAnteDescription => 'Enable big blind ante rule';

  @override
  String get introStartGame => 'START GAME';

  @override
  String get introStartingSession => 'Starting your poker session...';

  @override
  String introEnterField(String title) {
    return 'Enter $title';
  }

  @override
  String get introEnterAmount => 'Enter amount';

  @override
  String get introPleaseEnterValidNumber =>
      'Please enter a valid positive number';

  @override
  String get introRingGame => 'Ring Game';

  @override
  String get introMultiTable => 'Multi-Table';

  @override
  String get invitationTitle => 'Club Invitations';

  @override
  String get invitationNoPending => 'No pending invitations';

  @override
  String get invitationYouWillSeeHere =>
      'You\'ll see invitations from clubs here';

  @override
  String get invitationGoBack => 'Go Back';

  @override
  String invitationFailedToLoad(String error) {
    return 'Failed to load invitations: $error';
  }

  @override
  String invitationJoinedAs(String clubName, String role) {
    return 'Joined $clubName as $role';
  }

  @override
  String invitationFailedToAccept(String error) {
    return 'Failed to accept invitation: $error';
  }

  @override
  String get invitationDeclined => 'Invitation declined';

  @override
  String invitationFailedToDecline(String error) {
    return 'Failed to decline invitation: $error';
  }

  @override
  String get invitationUnknownClub => 'Unknown Club';

  @override
  String invitationInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String invitationExpiresDate(String date) {
    return 'Expires $date';
  }

  @override
  String get invitationExpired => 'Expired';

  @override
  String invitationExpiresInDays(int days) {
    return 'in $days day(s)';
  }

  @override
  String invitationExpiresInHours(int hours) {
    return 'in $hours hour(s)';
  }

  @override
  String get invitationExpiresSoon => 'soon';

  @override
  String get invitationDeclineButton => 'Decline';

  @override
  String get invitationAcceptButton => 'Accept';

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationToday => 'Today';

  @override
  String get notificationYesterday => 'Yesterday';

  @override
  String get notificationThisWeek => 'This Week';

  @override
  String get notificationEarlier => 'Earlier';

  @override
  String get notificationMarkAllRead => 'Mark all as read';

  @override
  String get notificationMarkAsRead => 'Mark as read';

  @override
  String get notificationNoNotifications => 'No notifications';

  @override
  String get notificationEvents => 'Events';

  @override
  String get notificationRsvp => 'RSVP';

  @override
  String get notificationClubs => 'Clubs';

  @override
  String get notificationInvitations => 'Invitations';

  @override
  String get notificationSeats => 'Seats';

  @override
  String get notificationSupport => 'Support';

  @override
  String get notificationClubNotFound => 'Club not found';

  @override
  String get notificationEventNotFound => 'Event not found';

  @override
  String notificationError(String error) {
    return 'Error: $error';
  }

  @override
  String notificationErrorLoadingEvent(String error) {
    return 'Error loading event: $error';
  }

  @override
  String notificationFailedToLoadClub(String error) {
    return 'Failed to load club: $error';
  }

  @override
  String get notificationClubInvitation => 'Club Invitation';

  @override
  String get notificationInvitedToJoin => 'You\'ve been invited to join';

  @override
  String get notificationInvitationDeclined => 'Invitation declined';

  @override
  String get notificationNotAuthenticated => 'Not authenticated';

  @override
  String get notificationInvitationAccepted => 'Invitation Accepted';

  @override
  String notificationAcceptedMessage(String name, String clubName) {
    return '$name has accepted the invitation to join $clubName.';
  }

  @override
  String get notificationInvitationDeclinedTitle => 'Invitation Declined';

  @override
  String notificationDeclinedMessage(String name, String clubName) {
    return '$name has declined the invitation to join $clubName.';
  }

  @override
  String get notificationRequestResolved => 'Request Resolved';

  @override
  String get notificationRequestClosed => 'Request Closed';

  @override
  String get notificationResponse => 'Response';

  @override
  String get calendarTitle => 'Poker Calendar';

  @override
  String get calendarNewEvent => 'New Event';

  @override
  String get calendarEventType => 'Event Type';

  @override
  String get calendarEventTitle => 'Title';

  @override
  String get calendarLocation => 'Location';

  @override
  String get calendarBuyInAmount => 'Buy-in amount';

  @override
  String get calendarEventDateTime => 'Event Date and Time';

  @override
  String get calendarStarts => 'Starts';

  @override
  String get calendarSelectDate => 'Select Date:';

  @override
  String get calendarReset => 'Reset';

  @override
  String get calendarSun => 'SUN';

  @override
  String get calendarMon => 'MON';

  @override
  String get calendarTue => 'TUE';

  @override
  String get calendarWed => 'WED';

  @override
  String get calendarThu => 'THU';

  @override
  String get calendarFri => 'FRI';

  @override
  String get calendarSat => 'SAT';

  @override
  String get calendarNoRecentEvents => 'No recent events';

  @override
  String get calendarAddFirstEvent => 'Add your first poker event!';

  @override
  String get calendarAddNewEvent => 'Add New Event';

  @override
  String get calendarSelectYear => 'Select Year';

  @override
  String get calendarEditEvent => 'Edit Event';

  @override
  String get calendarDeleteEvent => 'Delete Event';

  @override
  String get calendarTournament => 'Tournament';

  @override
  String get calendarCashGame => 'Cash Game';

  @override
  String get calendarPrivateGame => 'Private Game';

  @override
  String get calendarOnline => 'Online';

  @override
  String calendarFailedToCreateEvent(String error) {
    return 'Failed to create event: $error';
  }

  @override
  String calendarFailedToUpdateEvent(String error) {
    return 'Failed to update event: $error';
  }

  @override
  String get calendarFailedToDeleteEvent => 'Failed to delete event';

  @override
  String get calendarClubNotFound => 'Club not found';

  @override
  String get calendarEventNotFound => 'Event not found';

  @override
  String calendarFailedToLoadEvent(String error) {
    return 'Failed to load event: $error';
  }

  @override
  String calendarDeleteConfirmTitle(String title) {
    return 'Delete $title?';
  }

  @override
  String calendarDeleteConfirmMessage(String title) {
    return 'Are you sure you want to delete \"$title\"?\nThis action cannot be undone.';
  }

  @override
  String get sessionAnalyticsTitle => 'Session Analytics';

  @override
  String sessionAnalyticsHandsLogged(int count) {
    return '$count hands logged';
  }

  @override
  String get sessionAnalyticsDeleteTitle => 'Delete Session?';

  @override
  String get sessionAnalyticsDeleteMessage =>
      'This will permanently delete this session including all hand history, stack chart data, and AI analysis reports. This action cannot be undone.';

  @override
  String get sessionAnalyticsDeleted => 'Session deleted';

  @override
  String get sessionAnalyticsFailedToDelete => 'Failed to delete session';

  @override
  String get sessionAnalyticsExportSession => 'Export Session';

  @override
  String sessionAnalyticsExportConfirm(int count, String email) {
    return 'Export $count hands to $email?';
  }

  @override
  String get sessionAnalyticsExport => 'Export';

  @override
  String sessionAnalyticsExportSent(String email) {
    return 'Export sent to $email';
  }

  @override
  String sessionAnalyticsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get sessionAnalyticsNoEmailFound =>
      'No email address found. Please sign in with an email account.';

  @override
  String get sessionAnalyticsPokerSession => 'Poker Session';

  @override
  String get sessionAnalyticsTotalInvested => 'Total Invested';

  @override
  String get sessionAnalyticsFinalStack => 'Final Stack';

  @override
  String get sessionAnalyticsProfitLoss => 'Profit/Loss';

  @override
  String get sessionAnalyticsAvgGrowth => 'Avg Growth';

  @override
  String get sessionAnalyticsDuration => 'Duration';

  @override
  String get sessionAnalyticsRebuys => 'Rebuys';

  @override
  String get sessionAnalyticsStackChart => 'Stack Chart';

  @override
  String get sessionAnalyticsNoStackHistory => 'No Stack History Available';

  @override
  String get sessionAnalyticsStackTrackedFuture =>
      'Stack changes will be tracked in future sessions';

  @override
  String get sessionAnalyticsViewLoggedHands => 'View Logged Hands';

  @override
  String get sessionAnalyticsStart => 'Start';

  @override
  String get sessionAnalyticsRebuy => 'Rebuy';

  @override
  String get sessionAnalyticsEnd => 'End';

  @override
  String get seatSetupTitle => 'Setup Seat';

  @override
  String get seatSetupManagePlayers => 'Manage Players';

  @override
  String get seatSetupClickToConfig =>
      'Click seat to configure. Drag button to position';

  @override
  String get seatSetupButtonLocked => 'Button locked - hand in progress';

  @override
  String get seatSetupUpdatePlayerInfo => 'Update player information';

  @override
  String get seatSetupEmpty => 'Empty';

  @override
  String get seatSetupThisIsMySeat => 'This is my seat';

  @override
  String get seatSetupPlayerName => 'Player Name';

  @override
  String get seatSetupBuyInAmount => 'Buy-in Amount (\$)';

  @override
  String get seatSetupStartingChips => 'Starting Chips';

  @override
  String seatSetupSaveAsOpponent(String name) {
    return 'Save \"$name\" as opponent?';
  }

  @override
  String get seatSetupOpponentSaved => 'Opponent saved!';

  @override
  String seatSetupFailedToSave(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get seatSetupNoData => 'No Data';

  @override
  String get seatSetupStartSession => 'Start Session';

  @override
  String get seatSetupSaveChanges => 'Save Changes';

  @override
  String get seatSetupPleaseSelectSeat => 'Please select your seat';

  @override
  String seatSetupSeatNumber(int number) {
    return 'Seat $number';
  }

  @override
  String seatSetupPlayerDefault(int number) {
    return 'Player $number';
  }

  @override
  String get quickStackTitle => 'Update Stacks & Button';

  @override
  String quickStackBlinds(String blinds) {
    return 'Blinds: $blinds';
  }

  @override
  String get quickStackInstruction =>
      'Tap stack to edit  •  Slide to adjust  •  Tap D for button';

  @override
  String get quickStackContinue => 'CONTINUE TO LOG HAND';

  @override
  String get quickStackEditStack => 'Edit Stack';

  @override
  String get quickStackStackInBb => 'Stack in BB';

  @override
  String quickStackCurrentValue(String bbValue, String chipValue) {
    return 'Current: $bbValue BB = $chipValue';
  }

  @override
  String get quickStackValidationError =>
      'Please enter a value between 0 and 1000 BB';

  @override
  String quickStackSeat(int number) {
    return 'Seat $number';
  }

  @override
  String get quickStackEmpty => 'Empty';

  @override
  String quickStackPlayerDefault(int id) {
    return 'Player $id';
  }

  @override
  String get handReviewTitle => 'Hand Review';

  @override
  String get handReviewYourHoleCards => 'Your Hole Cards';

  @override
  String get handReviewOptional => '(optional)';

  @override
  String get handReviewQuickTags => 'Quick Tags';

  @override
  String get handReviewTagBluff => 'Bluff';

  @override
  String get handReviewTagValue => 'Value';

  @override
  String get handReviewTagMistake => 'Mistake';

  @override
  String get handReviewTagCooler => 'Cooler';

  @override
  String get handReviewTagHeroCall => 'Hero Call';

  @override
  String get handReviewTagExploit => 'Exploit';

  @override
  String get handReviewNotes => 'Notes';

  @override
  String get handReviewNotesHint => 'Add a note about this hand...';

  @override
  String get handReviewSaveHand => 'Save Hand';

  @override
  String get handReviewSkip => 'Skip';

  @override
  String get handReviewDuplicateCardError =>
      'You cannot select the same card twice!';

  @override
  String get handReviewSelectBothOrNone =>
      'Please select both hole cards or leave both empty';

  @override
  String get holeCardsTitle => 'Your Hole Cards';

  @override
  String get holeCardsSubtitle => 'Hole Cards';

  @override
  String get holeCardsWinnerBadge => 'WINNER';

  @override
  String get holeCardsSave => 'Save';

  @override
  String get holeCardsSkip => 'Skip';

  @override
  String get holeCardsSkipAllRemaining => 'Skip All Remaining';

  @override
  String get holeCardsDuplicateCardError =>
      'You cannot select the same card twice!';

  @override
  String get holeCardsSelectBothOrSkip =>
      'Please select both hole cards or skip to continue';

  @override
  String get holeCardsClearAll => 'Clear All';

  @override
  String get showdownTitle => 'Showdown';

  @override
  String get showdownEnterOpponentCards => 'Enter opponent cards at showdown:';

  @override
  String showdownPlayerLabel(int seatNumber) {
    return 'Player $seatNumber';
  }

  @override
  String get showdownCard1 => 'Card 1';

  @override
  String get showdownCard2 => 'Card 2';

  @override
  String get showdownClear => 'Clear';

  @override
  String get showdownWinner => 'Winner:';

  @override
  String get showdownHandDescriptionLabel => 'Hand Description (optional)';

  @override
  String get showdownHandDescriptionHint =>
      'e.g., \"Straight flush\", \"Full house Aces over Kings\"';

  @override
  String get showdownSkip => 'Skip';

  @override
  String get showdownSave => 'Save';

  @override
  String get showdownSelectCard => 'Select Card';

  @override
  String get tableManagementSectionTitle => 'TABLE';

  @override
  String tableManagementPlayersCount(int count) {
    return '$count players';
  }

  @override
  String get tableManagementDealerButton => 'Dealer Button';

  @override
  String get tableManagementAddPlayer => 'Add Player';

  @override
  String tableManagementYouSuffix(String name) {
    return '$name (You)';
  }

  @override
  String get tableManagementAdjustStack => 'Adjust Stack';

  @override
  String get tableManagementRebuy => 'Rebuy';

  @override
  String get tableManagementRemove => 'Remove';

  @override
  String get tableManagementAdjustStackTitle => 'Adjust Stack';

  @override
  String get tableManagementEnterStackAmount => 'Enter stack amount';

  @override
  String get tableManagementRebuyTitle => 'Rebuy';

  @override
  String get tableManagementRebuyAmountHint => 'Rebuy amount to add';

  @override
  String get tableManagementAdd => 'Add';

  @override
  String get tableManagementRemovePlayerTitle => 'Remove Player?';

  @override
  String tableManagementRemovePlayerMessage(String playerName) {
    return 'Remove $playerName from the table?';
  }

  @override
  String tableManagementAddPlayerSeatTitle(int seatNumber) {
    return 'Add Player — Seat $seatNumber';
  }

  @override
  String get tableManagementThisIsMe => 'This is me';

  @override
  String get tableManagementNameLabel => 'Name';

  @override
  String get tableManagementSearchOrEnterName => 'Search or enter name';

  @override
  String tableManagementSaveAsOpponent(String name) {
    return 'Save \"$name\" as opponent';
  }

  @override
  String tableManagementSavedAsOpponent(String name) {
    return '$name saved as opponent';
  }

  @override
  String get tableManagementStartingStack => 'Starting Stack';

  @override
  String get tableManagementStackAmountHint => 'Stack amount';

  @override
  String get tableManagementMoveMeHere => 'Move Me Here';

  @override
  String tableManagementSeatLabel(int seatNumber) {
    return 'Seat $seatNumber';
  }

  @override
  String get seatConfigRemove => 'Remove';

  @override
  String get seatConfigThisIsMe => 'This is me';

  @override
  String get seatConfigNameLabel => 'Name';

  @override
  String get seatConfigSearchOrEnterName => 'Search or enter name';

  @override
  String seatConfigSaveAsOpponent(String name) {
    return 'Save \"$name\" as opponent';
  }

  @override
  String seatConfigSavedAsOpponent(String name) {
    return '$name saved as opponent';
  }

  @override
  String seatConfigSeatTitle(int seatNumber) {
    return 'Seat $seatNumber';
  }

  @override
  String get seatConfigStackLabel => 'Stack';

  @override
  String get seatConfigUpdateButton => 'Update';

  @override
  String get seatConfigAddPlayerButton => 'Add Player';

  @override
  String get seatManagementSetupSeats => 'Setup Seats';

  @override
  String get seatManagementManagePlayers => 'Manage Players';

  @override
  String get seatManagementChooseSeatSubtitle =>
      'Choose your seat and configure table';

  @override
  String get seatManagementUpdatePlayerSubtitle => 'Update player information';

  @override
  String get seatManagementButtonPosition => 'Button Position';

  @override
  String seatManagementSeatLabel(int seatNumber) {
    return 'Seat $seatNumber';
  }

  @override
  String get seatManagementEmpty => 'Empty';

  @override
  String get seatManagementActive => 'Active';

  @override
  String get seatManagementPlayerNameLabel => 'Player Name';

  @override
  String get seatManagementEnterPlayerName => 'Enter player name';

  @override
  String get seatManagementBuyInAmountCash => 'Buy-in Amount (\$)';

  @override
  String get seatManagementStartingChips => 'Starting Chips';

  @override
  String get seatManagementSaveOpponentTitle => 'Save Opponent?';

  @override
  String seatManagementSaveOpponentMessage(String name) {
    return 'Would you like to save \"$name\" to your opponents list for future tracking?';
  }

  @override
  String get seatManagementNotNow => 'Not Now';

  @override
  String seatManagementSaveAsOpponentPrompt(String name) {
    return 'Save \"$name\" as opponent?';
  }

  @override
  String seatManagementOpponentSavedSuccess(String name) {
    return 'Opponent \"$name\" saved successfully!';
  }

  @override
  String seatManagementFailedToSaveOpponent(String error) {
    return 'Failed to save opponent: $error';
  }

  @override
  String get seatManagementStartSession => 'Start Session';

  @override
  String get seatManagementSaveChanges => 'Save Changes';

  @override
  String get seatManagementSelectYourSeat => 'Please select your seat';

  @override
  String get inviteMemberTitle => 'Invite Member';

  @override
  String get inviteMemberEmailLabel => 'EMAIL ADDRESS';

  @override
  String get inviteMemberEmailHint => 'Enter email address';

  @override
  String get inviteMemberEmailRequired => 'Please enter an email address';

  @override
  String get inviteMemberEmailInvalid => 'Please enter a valid email address';

  @override
  String get inviteMemberRoleLabel => 'ROLE';

  @override
  String get inviteMemberRoleDealer => 'Dealer';

  @override
  String get inviteMemberRoleAdmin => 'Admin';

  @override
  String get inviteMemberSendInvite => 'Send Invite';

  @override
  String inviteMemberAlreadyMember(String displayName, String clubName) {
    return '$displayName is already a member of $clubName';
  }

  @override
  String get inviteMemberAddedNotificationTitle =>
      'You\'ve Been Added to a Club!';

  @override
  String inviteMemberAddedNotificationBody(
      String inviterName, String clubName, String role) {
    return '$inviterName added you to \"$clubName\" as $role.';
  }

  @override
  String get inviteMemberAddedSuccessTitle => 'Member Added!';

  @override
  String inviteMemberAddedSuccessMessage(
      String displayName, String clubName, String role) {
    return '$displayName has been added to $clubName as $role.';
  }

  @override
  String get inviteMemberInvitationSentTitle => 'Invitation Sent!';

  @override
  String inviteMemberInvitationSentMessage(String email, String clubName) {
    return 'An invitation email has been sent to $email. Once they sign up, they\'ll be able to join $clubName.';
  }

  @override
  String inviteMemberError(String error) {
    return 'Error: $error';
  }

  @override
  String get inviteMemberRoleAnAdmin => 'an admin';

  @override
  String get inviteMemberRoleADealer => 'a dealer';

  @override
  String get registerClubTitle => 'Register Club';

  @override
  String get registerClubNameLabel => 'Club Name';

  @override
  String get registerClubNamePlaceholder => 'e.g., Lucky Aces Poker Club';

  @override
  String get registerClubNameRequired => 'Please enter a club name';

  @override
  String get registerClubAddressLabel => 'Address';

  @override
  String get registerClubAddressPlaceholder =>
      'e.g., 123 Main St, City, Country';

  @override
  String get registerClubAddressRequired => 'Please enter the club address';

  @override
  String get registerClubPhoneLabel => 'Phone Number';

  @override
  String get registerClubPhonePlaceholder => 'e.g., +1 555-123-4567';

  @override
  String get registerClubPhoneRequired => 'Please enter a phone number';

  @override
  String get registerClubAdminEmailLabel => 'Club Admin Email';

  @override
  String get registerClubAdminEmailPlaceholder => 'e.g., admin@myclub.com';

  @override
  String get registerClubAdminEmailRequired => 'Please enter admin email';

  @override
  String get registerClubAdminEmailInvalid => 'Please enter a valid email';

  @override
  String get registerClubInfoMessage =>
      'This person will be notified when the club is approved and will become the club owner.';

  @override
  String get registerClubSubmitRequest => 'Submit Request';

  @override
  String registerClubFailedToSubmit(String error) {
    return 'Failed to submit request: $error';
  }

  @override
  String get registerClubSuccessTitle => 'Request Submitted!';

  @override
  String registerClubSuccessMessage(String email) {
    return 'Your club registration request has been submitted. We\'ll notify you at $email once it\'s reviewed.';
  }

  @override
  String get registerClubGotIt => 'Got it';

  @override
  String get loggingModeChooseMode => 'Choose Mode';

  @override
  String get loggingModeFullTitle => 'Full Logging Mode';

  @override
  String get loggingModeFullSubtitle => 'Complete Session Tracking';

  @override
  String get loggingModeFullFeature1 => 'Multi-hand session tracking';

  @override
  String get loggingModeFullFeature2 => 'Real time statistics';

  @override
  String get loggingModeFullFeature3 => 'Detailed hand history';

  @override
  String get loggingModeFullFeature4 => 'Session analytics';

  @override
  String get loggingModeIndividualTitle => 'Quick Session Logging Mode';

  @override
  String get loggingModeIndividualSubtitle => 'Single hand tracking';

  @override
  String get loggingModeIndividualFeature1 => 'Single hand focus';

  @override
  String get loggingModeIndividualFeature2 => 'Quick logging';

  @override
  String get loggingModeIndividualFeature3 => 'Hand analysis';

  @override
  String get loggingModeIndividualFeature4 => 'Instant results';

  @override
  String get loggingModeFeatures => 'Features';

  @override
  String get loggingModeStart => 'Start';

  @override
  String get earningsChartAllTimeEarnings => 'All-Time Earnings';

  @override
  String earningsChartSinceDate(String date) {
    return 'Since $date';
  }

  @override
  String get earningsChartTournament => 'Tournament';

  @override
  String get earningsChartCash => 'Cash';

  @override
  String get earningsChartNoData => 'No earnings data yet';

  @override
  String get earningsChartNoDataSubtitle =>
      'Complete some sessions to see your earnings chart';

  @override
  String get earningsChartMtt => 'MTT';

  @override
  String get opponentHandsTitle => 'Hand History';

  @override
  String opponentHandsCount(int count) {
    return '$count hands';
  }

  @override
  String get opponentHandsLoading => 'Loading hand history...';

  @override
  String get opponentHandsError => 'Something went wrong';

  @override
  String get opponentHandsRetry => 'Retry';

  @override
  String get opponentHandsNoHandsTitle => 'No Hands Found';

  @override
  String opponentHandsNoHandsSubtitle(String name) {
    return 'You haven\'t played any hands\nwith $name yet.';
  }

  @override
  String get opponentHandsOppWon => 'OPP WON';

  @override
  String get opponentHandsYou => 'You';

  @override
  String opponentHandsPot(String amount) {
    return 'Pot $amount';
  }

  @override
  String get opponentHandsUnknownSession => 'Unknown Session';

  @override
  String get clubDashboardLive => 'Live';

  @override
  String get clubDashboardUpcoming => 'Upcoming';

  @override
  String get clubDashboardPast => 'Past';

  @override
  String get clubDashboardNoLiveEvents => 'No live events';

  @override
  String get clubDashboardNoUpcomingEvents => 'No upcoming events';

  @override
  String get clubDashboardNoPastEvents => 'No past events';

  @override
  String get clubDashboardAdmin => 'Admin';

  @override
  String get clubDashboardCreateEventHint =>
      'Tap the button below to create one';

  @override
  String get clubDashboardCheckBackLater => 'Check back later for new events';

  @override
  String get clubDashboardEventsWillAppear =>
      'Events will appear here when they start';

  @override
  String get clubDashboardPastEventsWillAppear =>
      'Completed events will appear here';

  @override
  String clubDashboardCashGameStakes(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get clubDashboardCash => 'Cash';

  @override
  String get clubDashboardTables => 'Tables';

  @override
  String get clubDashboardStakes => 'Stakes';

  @override
  String clubDashboardPlayingCount(int count) {
    return '$count playing';
  }

  @override
  String clubDashboardMemberCount(int count) {
    return '$count members';
  }

  @override
  String get clubSettingsTitle => 'Club Settings';

  @override
  String get clubSettingsClubInfo => 'Club Information';

  @override
  String get clubSettingsClubName => 'Club Name';

  @override
  String get clubSettingsAddress => 'Address';

  @override
  String get clubSettingsPhone => 'Phone';

  @override
  String get clubSettingsDescription => 'Description';

  @override
  String get clubSettingsSaveChanges => 'Save Changes';

  @override
  String get clubSettingsInfoSaved => 'Club info saved';

  @override
  String clubSettingsErrorSaving(String error) {
    return 'Error saving: $error';
  }

  @override
  String get clubSettingsNoTablesYet => 'No tables yet';

  @override
  String get clubSettingsAddTableHint => 'Add a table to get started';

  @override
  String clubSettingsErrorLoading(String error) {
    return 'Error loading data: $error';
  }

  @override
  String get eventEditTitle => 'Edit Event';

  @override
  String get eventNewTitle => 'New Event';

  @override
  String get eventNoTablesAssigned => 'No Tables Assigned';

  @override
  String get eventNoTablesAssignedDesc =>
      'No tables assigned to this event. Please go back and assign tables first.';

  @override
  String get eventGoBack => 'Go Back';

  @override
  String get eventContinue => 'Continue';

  @override
  String get eventNameOptional => 'Event Name (optional)';

  @override
  String get eventNameLabel => 'Event Name';

  @override
  String get eventStakesHint => 'Stakes (e.g. 1/2)';

  @override
  String get eventBuyInAmount => 'Buy-in amount';

  @override
  String get eventMinBuyIn => 'Min Buy-in (\$)';

  @override
  String get eventStartingStack => 'Starting stack';

  @override
  String get eventGameType => 'Game Type';

  @override
  String get eventTournament => 'Tournament';

  @override
  String get eventCashGame => 'Cash Game';

  @override
  String get eventDateAndTime => 'Event Date and Time';

  @override
  String get eventStarts => 'Starts';

  @override
  String get eventTables => 'Tables';

  @override
  String get eventDeselectAll => 'Deselect All';

  @override
  String get eventSelectAll => 'Select All';

  @override
  String get eventAllTablesInUse => 'All tables are in use by running events';

  @override
  String get eventNoTablesConfigured => 'No tables configured yet';

  @override
  String get eventDescriptionLabel => 'Description';

  @override
  String get eventNotifyMembers => 'Notify Members';

  @override
  String get eventNotifyMembersSubtitle =>
      'Send notification to all club members';

  @override
  String get eventDeleteEvent => 'Delete Event';

  @override
  String get eventDeleteConfirmTitle => 'Delete Event?';

  @override
  String get eventDeleteConfirmBody =>
      'This will permanently delete this event and all associated data. This action cannot be undone.';

  @override
  String eventDeleteFailed(String error) {
    return 'Failed to delete event: $error';
  }

  @override
  String get eventAttendeesTitle => 'Attendees';

  @override
  String eventAttendeesGoing(int count) {
    return 'Going ($count)';
  }

  @override
  String eventAttendeesMaybe(int count) {
    return 'Maybe ($count)';
  }

  @override
  String eventAttendeesNo(int count) {
    return 'No ($count)';
  }

  @override
  String get eventAttendeesNoConfirmed => 'No one confirmed yet';

  @override
  String get eventAttendeesNoMaybes => 'No maybes';

  @override
  String get eventAttendeesNoDeclines => 'No declines';

  @override
  String get eventDetailLiveNow => 'Event is now LIVE!';

  @override
  String get eventDetailEnded => 'Event has ended';

  @override
  String get eventDetailCancelled => 'Event was cancelled';

  @override
  String get eventDetailPaused => 'Event is paused';

  @override
  String get eventDetailStatusUpdated => 'Event status updated';

  @override
  String get eventDetailRemovedFromCalendar =>
      'Event removed from your calendar';

  @override
  String get eventDetailRsvpGoing => 'Going';

  @override
  String get eventDetailRsvpMaybe => 'Maybe';

  @override
  String get eventDetailRsvpCantGo => 'Can\'t go';

  @override
  String eventDetailRsvpFailed(String error) {
    return 'Failed to update RSVP: $error';
  }

  @override
  String get eventDetailCantStartTitle => 'Can\'t Start Event';

  @override
  String get eventDetailCantStartBody =>
      'No tables are assigned to this event. Please add tables first.';

  @override
  String get eventDetailStarted => 'Event started!';

  @override
  String eventDetailStartFailed(String error) {
    return 'Failed to start event: $error';
  }

  @override
  String get eventDetailFinishTitle => 'Finish Event?';

  @override
  String get eventDetailCancelTitle => 'Cancel Event?';

  @override
  String get eventDetailFinishBody =>
      'This will end all active tables and finalize standings.';

  @override
  String get eventDetailCancelBody =>
      'This will notify all members and cancel the event.';

  @override
  String get eventDetailFinishButton => 'Finish Event';

  @override
  String get eventDetailCancelButton => 'Cancel Event';

  @override
  String get eventDetailKeepEvent => 'Keep Event';

  @override
  String get eventDetailLiveBadge => 'LIVE NOW';

  @override
  String get eventDetailCancelledBadge => 'CANCELLED';

  @override
  String get eventDetailCompletedBadge => 'COMPLETED';

  @override
  String get eventDetailUpcomingBadge => 'UPCOMING';

  @override
  String get eventDetailLocation => 'Location';

  @override
  String get eventDetailBuyIn => 'Buy-in';

  @override
  String get eventDetailStakes => 'Stakes';

  @override
  String get eventDetailStartingStack => 'Starting Stack';

  @override
  String get eventDetailAbout => 'ABOUT';

  @override
  String get eventDetailAddedToCalendar => 'Event added to your calendar!';

  @override
  String eventDetailCalendarFailed(String error) {
    return 'Failed to add to calendar: $error';
  }

  @override
  String get eventManagementEventsTitle => 'Events';

  @override
  String get eventManagementNewEvent => 'New Event';

  @override
  String get eventManagementNoEvents => 'No Events';

  @override
  String get eventManagementNoEventsSubtitle =>
      'Create an event to track live rankings';

  @override
  String get eventManagementActiveEvents => 'Active Events';

  @override
  String get eventManagementPastEvents => 'Past Events';

  @override
  String eventManagementErrorLoading(String error) {
    return 'Error loading events: $error';
  }

  @override
  String get eventManagementNoTables =>
      'No tables available. Create tables first.';

  @override
  String eventManagementCreated(String name) {
    return 'Event \"$name\" created';
  }

  @override
  String eventManagementCreateFailed(String error) {
    return 'Failed to create event: $error';
  }

  @override
  String get eventManagementEndEvent => 'End Event';

  @override
  String eventManagementEndConfirm(String name) {
    return 'Are you sure you want to end \"$name\"?';
  }

  @override
  String eventManagementEnded(String name) {
    return 'Event \"$name\" ended';
  }

  @override
  String eventManagementEndFailed(String error) {
    return 'Failed to end event: $error';
  }

  @override
  String get eventManagementLinkCopied => 'Link copied to clipboard';

  @override
  String get eventManagementShare => 'Share';

  @override
  String get eventManagementPause => 'Pause';

  @override
  String get eventManagementResume => 'Resume';

  @override
  String get eventManagementEnd => 'End';

  @override
  String get eventManagementCreateEvent => 'Create Event';

  @override
  String get eventManagementEventNameHint => 'e.g., Friday Night Tournament';

  @override
  String get eventManagementSelectTables => 'Select Tables';

  @override
  String eventManagementTableNumber(int number) {
    return 'Table $number';
  }

  @override
  String get eventManagementPublicEvent => 'Public Event';

  @override
  String get eventManagementPublicSubtitle => 'Anyone can view the leaderboard';

  @override
  String get eventManagementAccessCode => 'Access Code (optional)';

  @override
  String get eventManagementAccessCodeSubtitle =>
      'For sharing with specific users';

  @override
  String get eventManagementEnterName => 'Please enter an event name';

  @override
  String get eventManagementSelectTable => 'Please select at least one table';

  @override
  String get eventManagementPublic => 'Public';

  @override
  String get eventManagementPrivate => 'Private';

  @override
  String adminEventTablesSummary(int count, int occupied, int open) {
    return '$count tables • $occupied seated • $open open';
  }

  @override
  String get adminEventTablesAddTable => 'Add Table';

  @override
  String get adminEventTablesNoTables => 'No available tables to add';

  @override
  String adminEventTablesCloseConfirm(String tableName) {
    return 'Close $tableName?';
  }

  @override
  String adminEventTablesCloseWithPlayers(int count) {
    return 'This will move $count player(s) to the waitlist and remove the table from this event.';
  }

  @override
  String get adminEventTablesCloseEmpty =>
      'This will remove the table from this event.';

  @override
  String get adminEventTablesCloseButton => 'Close Table';

  @override
  String adminEventTablesTableAdded(String tableName) {
    return '$tableName added to event';
  }

  @override
  String adminEventTablesClosedWithWaitlist(String tableName, int count) {
    return '$tableName closed. $count player(s) moved to waitlist.';
  }

  @override
  String adminEventTablesClosed(String tableName) {
    return '$tableName closed.';
  }

  @override
  String get adminEventTablesNoWaitlist => 'No one in waitlist';

  @override
  String adminEventTablesWaitlistCount(int count) {
    return '$count in waitlist';
  }

  @override
  String adminEventTablesWaitlistNext(String name) {
    return 'Next: $name';
  }

  @override
  String get adminEventTablesWaitlist => 'Waitlist';

  @override
  String get adminEventTablesNotified => 'Notified';

  @override
  String get adminEventTablesNotify => 'Notify';

  @override
  String get adminEventTablesSeat => 'Seat';

  @override
  String adminEventTablesSeatAt(String tableName, int count) {
    return '$tableName ($count open)';
  }

  @override
  String get adminEventTablesNoEmptySeats => 'No empty seats on this table';

  @override
  String adminEventTablesPlayerSeated(String name, String tableName) {
    return '$name seated at $tableName';
  }

  @override
  String adminEventTablesPlayerNotified(String name) {
    return 'Notified $name';
  }

  @override
  String get adminTableSeatPlayer => 'Seat Player';

  @override
  String get adminTableFromWaitlist => 'From Waitlist';

  @override
  String adminTableWaitlistNextIs(String name) {
    return '$name is next';
  }

  @override
  String get adminTableClubMember => 'Club Member';

  @override
  String get adminTableSearchMembers => 'Search existing members';

  @override
  String get adminTableWalkUpPlayer => 'Walk-up Player';

  @override
  String get adminTableAddByName => 'Add by name';

  @override
  String get adminTableSelectMember => 'Select Member';

  @override
  String get adminTableSearch => 'Search...';

  @override
  String get adminTablePlayerName => 'Player name';

  @override
  String adminTableWaitingForApproval(int seatNumber) {
    return 'Waiting for approval to join seat #$seatNumber';
  }

  @override
  String get adminTableReject => 'Reject';

  @override
  String get adminTableApprove => 'Approve';

  @override
  String get adminTableRemove => 'Remove';

  @override
  String adminTableSeatNumber(int seatNumber) {
    return 'Seat #$seatNumber';
  }

  @override
  String get adminTableNoEmptySeats => 'No empty seats available';

  @override
  String adminTableSeatPlayerName(String name) {
    return 'Seat $name';
  }

  @override
  String get adminTableSelectSeat => 'Select a seat:';

  @override
  String adminTablePlayerSeated(String name) {
    return '$name seated';
  }

  @override
  String adminTableAlreadySeated(String name, String location) {
    return '$name is already seated at $location';
  }

  @override
  String adminTablePlayerApproved(String name) {
    return '$name approved';
  }

  @override
  String get adminTablePlayerRejected => 'Player rejected';

  @override
  String get adminTablePlayerRemoved => 'Player removed';

  @override
  String adminTableWaitlistInCount(int count) {
    return '$count in waitlist';
  }

  @override
  String adminTableWaitlistNextName(String name) {
    return 'Next: $name';
  }

  @override
  String adminTableNotifiedName(String name) {
    return 'Notified $name';
  }

  @override
  String clubCashGameStakes(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String clubCashGameTablesSummary(int count, int occupied, int open) {
    return '$count tables · $occupied seated · $open open';
  }

  @override
  String clubCashGameTableNumber(int number) {
    return 'Table $number';
  }

  @override
  String get clubCashGameNoTables => 'No tables in this group';

  @override
  String clubCashGameFailedToLoad(String error) {
    return 'Failed to load tables: $error';
  }

  @override
  String get clubCashGameAlreadySeated => 'You\'re already seated at a table';

  @override
  String get clubCashGameSeatAvailable =>
      'There\'s a seat available for you, approach registration';

  @override
  String clubCashGameJoinedWaitlist(int position) {
    return 'Joined waitlist at position #$position';
  }

  @override
  String clubCashGameJoinFailed(String error) {
    return 'Failed to join waitlist: $error';
  }

  @override
  String get clubCashGameLeftWaitlist => 'Left the waitlist';

  @override
  String clubCashGameLeaveFailed(String error) {
    return 'Failed to leave waitlist: $error';
  }

  @override
  String get clubCashGameViewWaitlist => 'View Waitlist';

  @override
  String get clubCashGameInWaitlist => 'In waitlist';

  @override
  String clubCashGameInWaitlistPosition(int position) {
    return 'In waitlist · #$position';
  }

  @override
  String get clubCashGameJoinWaitlist => 'Join Waitlist';

  @override
  String get clubCashGameLeaveWaitlistConfirm => 'Leave waitlist?';

  @override
  String get clubCashGameLosePosition => 'You will lose your current position.';

  @override
  String get clubCashGameKeep => 'Keep';

  @override
  String get clubCashGameLeave => 'Leave';

  @override
  String clubCashGameRefreshFailed(String error) {
    return 'Could not refresh tables: $error';
  }

  @override
  String get clubCashGameWaitlistTitle => 'Waitlist';

  @override
  String clubCashGameNotified(String name) {
    return '$name has been notified';
  }

  @override
  String clubCashGameNotifyFailed(String error) {
    return 'Failed to notify: $error';
  }

  @override
  String get clubCashGameCouldNotLoad => 'Could not load waitlist';

  @override
  String get clubCashGameNoOneOnWaitlist => 'No one on the waitlist';

  @override
  String get clubCashGamePlayer => 'Player';

  @override
  String clubCashGameNotifiedStatus(String time) {
    return 'Notified • $time';
  }

  @override
  String clubCashGameJoinedTime(String time) {
    return 'Joined $time';
  }

  @override
  String get clubCashGameJustNow => 'just now';

  @override
  String clubCashGameMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String clubCashGameHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String clubCashGameDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get clubCashGameAddTable => 'Add Table';

  @override
  String get clubCashGameNewTableName => 'New table name (optional)';

  @override
  String get clubCashGameAdd => 'Add';

  @override
  String clubCashGameAddedToGroup(String tableName) {
    return 'Added $tableName to the group';
  }

  @override
  String clubCashGameAddFailed(String error) {
    return 'Failed to add table: $error';
  }

  @override
  String clubCashGameAttachFailed(String error) {
    return 'Failed to attach table: $error';
  }

  @override
  String get clubCashGameAvailableTables => 'Available tables';

  @override
  String get clubCashGameInUseByOther => 'In use by other events';

  @override
  String get clubCashGameNoOtherTables => 'No other tables in this club yet';

  @override
  String clubCashGameInUseBy(String eventName) {
    return 'In use by $eventName';
  }

  @override
  String clubCashGameSeats(int count) {
    return 'Seats $count';
  }

  @override
  String memberEventTablesSummary(int count, int occupied, int open) {
    return '$count tables • $occupied seated • $open open';
  }

  @override
  String memberEventJoinedWaitlist(int position) {
    return 'Joined waitlist at position #$position';
  }

  @override
  String memberEventJoinFailed(String error) {
    return 'Failed to join waitlist: $error';
  }

  @override
  String get memberEventLeftWaitlist => 'Left the waitlist';

  @override
  String memberEventLeaveFailed(String error) {
    return 'Failed to leave waitlist: $error';
  }

  @override
  String memberEventWaitlistPosition(int position) {
    return 'Position #$position in waitlist';
  }

  @override
  String memberEventTotalWaiting(int count) {
    return '$count total waiting';
  }

  @override
  String get memberEventLeaveWaitlist => 'Leave Waitlist';

  @override
  String memberEventJoinWaitlistWithCount(int count) {
    return 'Join Waitlist ($count waiting)';
  }

  @override
  String get memberEventJoinWaitlist => 'Join Waitlist';

  @override
  String get memberEventAllTablesFull => 'All tables are full';

  @override
  String get dealerHomeTitle => 'Dealer Mode';

  @override
  String get dealerHomeNoClubs => 'No Clubs Found';

  @override
  String get dealerHomeNoClubsOwnerHint =>
      'Create your first club to get started.';

  @override
  String get dealerHomeNoClubsMemberHint =>
      'You are not a member of any clubs yet.\nAsk a club owner to invite you.';

  @override
  String get dealerHomeCreateClub => 'Create Club';

  @override
  String get dealerHomeDealer => 'Dealer';

  @override
  String dealerHomeClubCount(int count) {
    return '$count clubs';
  }

  @override
  String get dealerHomeActiveSessions => 'Active Sessions';

  @override
  String get dealerHomeClubs => 'Clubs';

  @override
  String get dealerHomeTables => 'Tables';

  @override
  String get dealerHomeAddTable => 'Add Table';

  @override
  String get dealerHomeTableNameLabel => 'Table Name';

  @override
  String get dealerHomeTableNameHint => 'e.g., Table 1, Main Table';

  @override
  String dealerHomeTableAdded(String name, String clubName) {
    return 'Table \"$name\" added to $clubName!';
  }

  @override
  String dealerHomeAddTableFailed(String error) {
    return 'Failed to add table: $error';
  }

  @override
  String get dealerHomeClubName => 'Club Name';

  @override
  String get dealerHomeCreate => 'Create';

  @override
  String dealerHomeClubCreated(String name) {
    return 'Club \"$name\" created successfully!';
  }

  @override
  String dealerHomeClubCreateFailed(String error) {
    return 'Failed to create club: $error';
  }

  @override
  String get dealerHomeNoTables => 'No tables in this club';

  @override
  String dealerHomeActiveHand(int number) {
    return 'Active - Hand #$number';
  }

  @override
  String get dealerHomeInactive => 'Inactive';

  @override
  String get dealerHomeResume => 'Resume';

  @override
  String get dealerHomeStart => 'Start';

  @override
  String get dealerHomeSessionSettings => 'Session Settings';

  @override
  String get dealerHomeSmallBlind => 'Small Blind';

  @override
  String get dealerHomeBigBlind => 'Big Blind';

  @override
  String get dealerHomeBBAnte => 'BB Ante';

  @override
  String get dealerHomeGameType => 'Game Type';

  @override
  String get dealerHomeCash => 'Cash';

  @override
  String get dealerHomeTournament => 'Tournament';

  @override
  String get dealerHomeButtonPosition => 'Button Position';

  @override
  String get dealerHomeStartSession => 'Start Session';

  @override
  String get dealerHomeCouldNotFind => 'Could not find club or table';

  @override
  String dealerHomeStartFailed(String error) {
    return 'Failed to start session: $error';
  }

  @override
  String dealerHomeErrorLoading(String error) {
    return 'Error loading data: $error';
  }

  @override
  String dealerHomeTableCount(int count) {
    return '$count tables';
  }

  @override
  String dealerTableFailedStartHand(String error) {
    return 'Failed to start hand: $error';
  }

  @override
  String dealerTableChopSummary(String winners, String amount) {
    return 'Chop: $winners split $amount';
  }

  @override
  String dealerTableWins(String name, String amount) {
    return '$name wins $amount';
  }

  @override
  String dealerTablePotChopped(String names) {
    return 'Pot chopped between $names';
  }

  @override
  String dealerTableFailedCompleteHand(String error) {
    return 'Failed to complete hand: $error';
  }

  @override
  String dealerTablePlayerBusted(String name) {
    return '$name Busted!';
  }

  @override
  String dealerTableNoChipsRemaining(int seatNumber, String amount) {
    return 'Seat $seatNumber has no chips remaining.\nRebuy amount: $amount';
  }

  @override
  String get dealerTableRemovePlayer => 'Remove Player';

  @override
  String get dealerTableRebuy => 'Rebuy';

  @override
  String dealerTableRebuysFor(String name, String amount) {
    return '$name rebuys for $amount';
  }

  @override
  String dealerTableFinishesIn(String name, String position) {
    return '$name finishes in $position place';
  }

  @override
  String get dealerTableEndSessionTitle => 'End Session?';

  @override
  String get dealerTableEndSessionBody =>
      'Are you sure you want to end this session?';

  @override
  String get dealerTableEnd => 'End';

  @override
  String get dealerTableDealerChange => 'Dealer Change';

  @override
  String get dealerTableDealerChangeBody =>
      'The session will be paused and another dealer can scan the table QR code to continue where you left off.';

  @override
  String get dealerTableDealerChangePreserve =>
      'All players, blinds, and game state will be preserved.';

  @override
  String get dealerTableDealerChangeResume =>
      'You can also resume this session yourself later.';

  @override
  String get dealerTableHandOff => 'Hand Off';

  @override
  String get dealerTableSessionPaused =>
      'Session paused. Another dealer can now take over.';

  @override
  String dealerTablePauseFailed(String error) {
    return 'Failed to pause session: $error';
  }

  @override
  String get dealerTableEventCancelled => 'Event Cancelled';

  @override
  String get dealerTableEventFinished => 'Event Finished';

  @override
  String get dealerTableEventCancelledBody =>
      'The club admin has cancelled this event. All sessions have been saved.';

  @override
  String get dealerTableEventFinishedBody =>
      'The club admin has finished this event. All sessions have been saved.';

  @override
  String get dealerTableSessionEnded => 'Session Ended';

  @override
  String get dealerTableSessionEndedBody =>
      'This session has been ended. All data has been saved.';

  @override
  String get dealerTableLeaveTitle => 'Leave dealer table?';

  @override
  String get dealerTableLeaveActiveHand =>
      'A hand is currently in progress. Leaving now may disrupt logging.';

  @override
  String get dealerTableLeaveInactive =>
      'The session stays live. You can return any time.';

  @override
  String dealerTableAutoCorrection(String detected, String corrected) {
    return 'Auto-corrected \"$detected\" → \"$corrected\"';
  }

  @override
  String dealerTableApprovePlayer(String name) {
    return 'Approve $name?';
  }

  @override
  String get dealerTableStartingChipStack => 'Starting Chip Stack';

  @override
  String dealerTablePlayerRejected(String name) {
    return '$name rejected';
  }

  @override
  String dealerTableRejectFailed(String error) {
    return 'Failed to reject: $error';
  }

  @override
  String dealerTablePlayerJoined(String name, String amount) {
    return '$name joined with $amount';
  }

  @override
  String dealerTableApproveFailed(String error) {
    return 'Failed to approve: $error';
  }

  @override
  String get dealerTableChipStack => 'Chip Stack';

  @override
  String get dealerTableSave => 'Save';

  @override
  String get liveSessionHand => 'HAND';

  @override
  String get liveSessionPot => 'POT';

  @override
  String get liveSessionStatus => 'STATUS';

  @override
  String get liveSessionLive => 'LIVE';

  @override
  String get liveSessionWaiting => 'WAITING';

  @override
  String liveSessionWinnerSummary(String winner, String amount) {
    return '$winner wins \$$amount';
  }

  @override
  String get liveSessionSessionEnded => 'Session Ended';

  @override
  String get liveSessionSessionEndedBody =>
      'The dealer has ended this session.';

  @override
  String get liveSessionLeaveTitle => 'Leave Table?';

  @override
  String get liveSessionLeaveBody =>
      'Are you sure you want to leave this table?';

  @override
  String get liveSessionLeave => 'Leave';

  @override
  String liveSessionLeaveFailed(String error) {
    return 'Failed to leave: $error';
  }

  @override
  String get liveSessionLeaveTooltip => 'Leave Table';

  @override
  String liveSessionSeat(int number) {
    return 'Seat $number';
  }

  @override
  String get liveSessionYourSeat => 'Your Seat';

  @override
  String liveSessionStack(String amount) {
    return 'Stack: $amount';
  }

  @override
  String get liveSessionWaitingForDealer => 'Waiting for dealer...';

  @override
  String get liveSessionOffline => 'OFFLINE';

  @override
  String get liveSessionRecentActions => 'Recent Actions';

  @override
  String get liveSessionWaitingForAction => 'Waiting for action...';

  @override
  String get liveSessionD => 'D';

  @override
  String get qrScanTitle => 'Scan Table QR';

  @override
  String get qrScanInvalidCode =>
      'Invalid QR code. Please scan a valid poker table QR code.';

  @override
  String qrScanError(String error) {
    return 'Error processing QR code: $error';
  }

  @override
  String get qrScanInstructions =>
      'Point your camera at the QR code on the table to join';

  @override
  String get clubRequestsTitle => 'Club Requests';

  @override
  String get clubRequestsAll => 'All';

  @override
  String get clubRequestsPending => 'Pending';

  @override
  String get clubRequestsApproved => 'Approved';

  @override
  String get clubRequestsRejected => 'Rejected';

  @override
  String get clubRequestsApproveTitle => 'Approve Request';

  @override
  String clubRequestsApproveBody(String name) {
    return 'Are you sure you want to approve \"$name\"? This will create a new club and add you as the admin.';
  }

  @override
  String get clubRequestsRejectTitle => 'Reject Request';

  @override
  String clubRequestsRejectBody(String name) {
    return 'Please provide a reason for rejecting \"$name\":';
  }

  @override
  String get clubRequestsRejectHint => 'Reason for rejection...';

  @override
  String get clubRequestsApproveButton => 'Approve';

  @override
  String get clubRequestsRejectButton => 'Reject';

  @override
  String clubRequestsApproved2(String name) {
    return '$name has been approved!';
  }

  @override
  String clubRequestsRejected2(String name) {
    return '$name has been rejected.';
  }

  @override
  String get clubRequestsNoRequests => 'No requests';

  @override
  String get clubRequestsPendingBadge => 'PENDING';

  @override
  String get clubRequestsApprovedBadge => 'APPROVED';

  @override
  String get clubRequestsRejectedBadge => 'REJECTED';

  @override
  String get clubRequestsAddress => 'Address';

  @override
  String get clubRequestsPhone => 'Phone';

  @override
  String get clubRequestsAdminEmail => 'Admin Email';

  @override
  String get clubRequestsRequestedBy => 'Requested By';

  @override
  String get clubRequestsRequesterEmail => 'Requester Email';

  @override
  String get clubRequestsRequestedAt => 'Requested At';

  @override
  String get clubRequestsReviewedAt => 'Reviewed At';

  @override
  String get clubRequestsRejectionReason => 'Rejection Reason:';

  @override
  String get supportRequestsTitle => 'Support Requests';

  @override
  String get supportRequestsAll => 'All';

  @override
  String get supportRequestsPending => 'Pending';

  @override
  String get supportRequestsClosed => 'Closed';

  @override
  String get supportRequestsResolveTitle => 'Resolve Request';

  @override
  String get supportRequestsResolveBody => 'Optional response to the user:';

  @override
  String get supportRequestsResponseHint => 'Response (optional)...';

  @override
  String get supportRequestsResolve => 'Resolve';

  @override
  String get supportRequestsResolved => 'Request resolved';

  @override
  String get supportRequestsRejectTitle => 'Reject Request';

  @override
  String get supportRequestsRejectBody => 'Reason for rejection:';

  @override
  String get supportRequestsRejectHint => 'Reason...';

  @override
  String get supportRequestsReject => 'Reject';

  @override
  String get supportRequestsRejected => 'Request rejected';

  @override
  String get supportRequestsNoRequests => 'No requests';

  @override
  String get supportRequestsPendingBadge => 'PENDING';

  @override
  String get supportRequestsResolvedBadge => 'RESOLVED';

  @override
  String get supportRequestsRejectedBadge => 'REJECTED';

  @override
  String get supportRequestsCategory => 'Category';

  @override
  String get supportRequestsUser => 'User';

  @override
  String get supportRequestsEmail => 'Email';

  @override
  String get supportRequestsSubmitted => 'Submitted';

  @override
  String get supportRequestsDescription => 'Description';

  @override
  String get supportRequestsAdminResponse => 'Admin Response';

  @override
  String get supportRequestsBugReport => 'Bug Report';

  @override
  String get supportRequestsFeatureRequest => 'Feature Request';

  @override
  String get supportRequestsAccountIssue => 'Account Issue';

  @override
  String get debugHandViewerTitle => 'Debug Hand Viewer';

  @override
  String get debugHandViewerSessionName => 'Session Name';

  @override
  String get debugHandViewerHandNumbers =>
      'Hand Numbers (comma-separated, e.g., 27,28)';

  @override
  String get debugHandViewerFetchData => 'Fetch Data';

  @override
  String get debugHandViewerCopied => 'Copied to clipboard';

  @override
  String get debugHandViewerNoData =>
      'No data yet. Enter session name and click Fetch Data.';

  @override
  String get navDrawerSettings => 'Settings';

  @override
  String get navDrawerRegisterClub => 'Register Club';

  @override
  String get navDrawerHelpSupport => 'Help & Support';

  @override
  String get navDrawerLogOut => 'Log out';

  @override
  String get navDrawerUpgrade => 'Upgrade';

  @override
  String get navDrawerUserFallback => 'User';

  @override
  String get navDrawerStatistics => 'Statistics';

  @override
  String get navDrawerEvents => 'Events';

  @override
  String get navDrawerBankroll => 'Bankroll';

  @override
  String get navDrawerClubs => 'Clubs';

  @override
  String get navDrawerNoClubsYet => 'No clubs yet';

  @override
  String navDrawerMemberCount(int count) {
    return '$count members';
  }

  @override
  String get navDrawerRoleAdmin => 'Admin';

  @override
  String get navDrawerRoleDealer => 'Dealer';

  @override
  String get navDrawerRoleMember => 'Member';

  @override
  String get navDrawerVersion => 'Version 1.0.0';

  @override
  String get navDrawerLastLoginToday => 'Last login: Today';

  @override
  String get navDrawerNoEarningsTitle => 'No Earnings Data Yet';

  @override
  String get navDrawerNoEarningsBody =>
      'Add some session results first to view your earnings chart. You can add results from the Profile page.';

  @override
  String get navDrawerSignOutTitle => 'Sign Out';

  @override
  String get navDrawerSignOutMessage => 'Are you sure you want to sign out?';

  @override
  String get navDrawerSignOut => 'Sign Out';

  @override
  String get multiPotMainPot => 'Main Pot';

  @override
  String multiPotSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String multiPotPlayerFallback(String id) {
    return 'Player $id';
  }

  @override
  String get multiPotMainPotWinner => 'main pot winner';

  @override
  String get multiPotEligibleFromPrevious => 'eligible from previous pot';

  @override
  String multiPotAutoAwarded(String name, String reason) {
    return 'Auto-awarded to $name ($reason)';
  }

  @override
  String get multiPotChoppedPot => 'Chopped Pot';

  @override
  String get multiPotSingleWinner => 'Single Winner';

  @override
  String get multiPotSelectAllWinners => 'Select all winners:';

  @override
  String get multiPotSelectTheWinner => 'Select the winner:';

  @override
  String get multiPotSelectWinnersTitle => 'Select Winners';

  @override
  String get multiPotMultiplePots =>
      'Multiple pots - select winner for each pot';

  @override
  String get winnerSelectionWhoChopped => 'Who chopped this pot?';

  @override
  String get winnerSelectionWhoWon => 'Who won this hand?';

  @override
  String get winnerSelectionChoppedPot => 'Chopped Pot';

  @override
  String get winnerSelectionIndividualShares => 'Individual shares:';

  @override
  String get winnerSelectionSelectAllWinners => 'Select all winners:';

  @override
  String get winnerSelectionTapTheWinner => 'Tap the winner:';

  @override
  String get winnerSelectionLongPressHint => 'Long-press for chopped pot';

  @override
  String get winnerSelectionConfirmChop => 'Confirm Chop';

  @override
  String get winnerSelectionBackToSingle => 'Back to Single Winner';

  @override
  String get boardCardsCards => 'Cards';

  @override
  String get boardCardsCard => 'Card';

  @override
  String get allInBoardTitle => 'All-In Board Cards';

  @override
  String get raiseSnapReleaseToType => 'Release at min to type';

  @override
  String get slidingNotificationHeader => 'NOTIFICATION';

  @override
  String get eventSuccessTitle => 'Nice! Your event is now on calendar.';

  @override
  String get eventSuccessSubtitle => 'You can edit or remove it anytime';

  @override
  String get eventSuccessGoToCalendar => 'Go to calendar';

  @override
  String get eventSuccessAddAnother => 'Add another event';

  @override
  String get stackChartNoData => 'No data yet';

  @override
  String get stackChartStart => 'Start';

  @override
  String get stackChartRebuy => 'Rebuy';

  @override
  String get stackChartEnd => 'End';

  @override
  String get stackChartTitle => 'Stack Chart';

  @override
  String get stackChartAvgGrowth => 'Avg Growth';

  @override
  String get stackChartDuration => 'Duration';

  @override
  String get stackChartProfitLoss => 'P/L';

  @override
  String get actionGridSelectAction => 'Select Action';

  @override
  String get pokerTablePlayerFallback => 'Player';

  @override
  String get loadingDefault => 'Loading...';

  @override
  String get forgotPasswordFailedSendCode =>
      'Failed to send code. Please try again.';

  @override
  String get forgotPasswordNewCodeSent => 'New code sent to your email.';

  @override
  String get forgotPasswordFailedResend => 'Failed to resend code.';

  @override
  String get forgotPasswordEnterFullCode =>
      'Please enter the full 6-digit code.';

  @override
  String get forgotPasswordInvalidCode =>
      'Invalid or expired code. Please try again.';

  @override
  String get forgotPasswordResetSuccess =>
      'Password reset successfully! Please sign in.';

  @override
  String get forgotPasswordResetTitle => 'Reset password';

  @override
  String get forgotPasswordResetSubtitle =>
      'Enter your email to receive a verification code';

  @override
  String get forgotPasswordCheckEmail => 'Check your email';

  @override
  String get forgotPasswordSetNewPassword => 'Set new password';

  @override
  String get forgotPasswordSetNewSubtitle =>
      'Choose a strong password for your account';

  @override
  String get forgotPasswordEmail => 'Email';

  @override
  String get forgotPasswordEnterEmail => 'Please enter your email';

  @override
  String get forgotPasswordValidEmail => 'Please enter a valid email';

  @override
  String get forgotPasswordSendCode => 'Send Code';

  @override
  String get forgotPasswordVerifyCode => 'Verify Code';

  @override
  String get forgotPasswordResendCode => 'Resend code';

  @override
  String forgotPasswordResendIn(String time) {
    return 'Resend code in $time';
  }

  @override
  String get forgotPasswordNewPassword => 'New password';

  @override
  String get forgotPasswordEnterPassword => 'Please enter a password';

  @override
  String get forgotPasswordMinLength =>
      'Password must be at least 6 characters';

  @override
  String get forgotPasswordConfirm => 'Confirm password';

  @override
  String get forgotPasswordConfirmRequired => 'Please confirm your password';

  @override
  String get forgotPasswordMismatch => 'Passwords do not match';

  @override
  String get forgotPasswordResetButton => 'Reset Password';

  @override
  String get onboardingTrackTitle => 'TRACK EVERY\nHAND';

  @override
  String get onboardingTrackSubtitle =>
      'Log actions, board cards, and results for every hand you play — live or after the session.';

  @override
  String get onboardingKnowTitle => 'KNOW YOUR\nGAME';

  @override
  String get onboardingKnowSubtitle =>
      'VPIP, PFR, 3-Bet, C-Bet and more — see your stats evolve in real time.';

  @override
  String get onboardingClubsTitle => 'PLAY AT\nCLUBS';

  @override
  String get onboardingClubsSubtitle =>
      'Join live events, see rankings, and track your opponents across sessions.';

  @override
  String get dealerTableEnterStartingStack => 'Enter Starting Stack';

  @override
  String get dealerTableNoPendingRequests => 'No pending join requests';

  @override
  String get dealerTablePendingJoinRequests => 'Pending Join Requests';

  @override
  String get dealerTableUnknown => 'Unknown';

  @override
  String dealerTableSeatNumber(int number) {
    return 'Seat $number';
  }

  @override
  String get dealerTableReview => 'Review';

  @override
  String get dealerTableSmallBlind => 'Small Blind';

  @override
  String get dealerTableBigBlind => 'Big Blind';

  @override
  String get dealerTableNewBlindsNote =>
      'New blinds will apply from the next hand.';

  @override
  String get dealerTableSmallMustBeLess =>
      'Small blind must be less than big blind';

  @override
  String get dealerTableBlindsMustBePositive => 'Blinds must be greater than 0';

  @override
  String dealerTableBlindsUpdated(String sb, String bb) {
    return 'Blinds updated to $sb/$bb';
  }

  @override
  String dealerTableFailedUpdateBlinds(String error) {
    return 'Failed to update blinds: $error';
  }

  @override
  String dealerTableFailedMoveButton(String error) {
    return 'Failed to move button: $error';
  }

  @override
  String get dealerTablePending => 'PENDING';

  @override
  String get dealerTableConnectionLost => 'Connection Lost';

  @override
  String get dealerTableReconnecting => 'Attempting to reconnect...';

  @override
  String get dealerTableReconnect => 'Reconnect';

  @override
  String get dealerTableResetHandTitle => 'Reset Hand?';

  @override
  String get dealerTableResetHandBody =>
      'All actions have been undone. Would you like to start a new hand?';

  @override
  String get dealerTableKeepCurrent => 'Keep Current';

  @override
  String get dealerTableNewHand => 'New Hand';

  @override
  String get dealerTableHandReset => 'Hand reset - ready for new hand';

  @override
  String dealerTableAddPlayerToSeat(int number) {
    return 'Add Player to Seat $number';
  }

  @override
  String get dealerTableSearchUser => 'Search User';

  @override
  String get dealerTableManualEntry => 'Manual Entry';

  @override
  String get dealerTableSearchByName => 'Search by Name';

  @override
  String get dealerTableTypeToSearch => 'Type to search users...';

  @override
  String get dealerTableNoUsersFound => 'No users found. Try manual entry.';

  @override
  String get dealerTablePlayerNameLabel => 'Player Name';

  @override
  String get dealerTableEnterPlayerName => 'Enter player name';

  @override
  String get dealerTableAddPlayer => 'Add Player';

  @override
  String get dealerTableEndSession => 'End session';

  @override
  String dealerTableUpdatedStack(String name, String amount) {
    return 'Updated $name stack to $amount';
  }

  @override
  String dealerTableFailedUpdateStack(String error) {
    return 'Failed to update stack: $error';
  }

  @override
  String dealerTableSittingAtSeat(int number) {
    return 'You are now playing at Seat $number';
  }

  @override
  String dealerTableFailedSitAt(String error) {
    return 'Failed to sit at table: $error';
  }

  @override
  String dealerTableFailedAddPlayer(String error) {
    return 'Failed to add player: $error';
  }

  @override
  String dealerTableFailedRemovePlayer(String error) {
    return 'Failed to remove player: $error';
  }

  @override
  String get eventDetailEventType => 'Event Type';

  @override
  String get eventDetailSeated => 'Seated';

  @override
  String get eventDetailAreYouGoing => 'ARE YOU GOING?';

  @override
  String get eventDetailAddedToCalendarBtn => 'Added to Calendar';

  @override
  String get eventDetailAddToCalendarBtn => 'Add to Calendar';

  @override
  String get eventDetailWhosGoing => 'Who\'s Coming';

  @override
  String get eventDetailSeeAll => 'See all';

  @override
  String get eventDetailStartDealing => 'Start Dealing';

  @override
  String get eventDetailViewLiveRankings => 'View Live Rankings';

  @override
  String get eventDetailNotSeatedAtTable =>
      'You are not currently seated at any table';

  @override
  String get eventDetailNotSeatedInEvent => 'You are not seated in this event';

  @override
  String eventDetailErrorFindingSeat(String error) {
    return 'Error finding your seat: $error';
  }

  @override
  String get eventDetailReturnToSeat => 'Return to My Seat';

  @override
  String get eventDetailViewFinalStandings => 'View Final Standings';

  @override
  String get eventDetailManageTables => 'Manage Tables';

  @override
  String get eventDetailManageTable => 'Manage Table';

  @override
  String get eventDetailSeeAvailability => 'See Availability';

  @override
  String get eventDetailYoureSeated => 'You\'re Seated';

  @override
  String get eventDetailNoTablesAssigned => 'No tables assigned to this event';

  @override
  String get eventDetailStartEvent => 'Start Event';

  @override
  String get eventDetailFinish => 'Finish';

  @override
  String eventDetailFailedFinishCancel(String action, String error) {
    return 'Failed to $action event: $error';
  }

  @override
  String homeTableSeatInfo(String table, String seat) {
    return 'Table $table, Seat #$seat';
  }

  @override
  String get homeRequestResolved => 'Request Resolved';

  @override
  String get homeRequestClosed => 'Request Closed';

  @override
  String get homeResponse => 'Response';

  @override
  String homeErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String homeErrorLoadingEvent(String error) {
    return 'Error loading event: $error';
  }

  @override
  String homeFailedLoadEvent(String error) {
    return 'Failed to load event: $error';
  }

  @override
  String homeFailedUpdateEvent(String error) {
    return 'Failed to update event: $error';
  }

  @override
  String homeErrorDeletingEvent(String error) {
    return 'Error deleting event: $error';
  }

  @override
  String get homeTournament => 'Tournament';

  @override
  String get homeCashGame => 'Cash Game';

  @override
  String commonErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get commonLeave => 'Leave';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonLoadingHands => 'Loading hands...';

  @override
  String sessionHistoryButtonPosition(String position) {
    return 'Button Position: $position';
  }

  @override
  String sessionHistoryPlayerCount(String count) {
    return 'Player Count: $count';
  }

  @override
  String sessionHistoryStartTime(String time) {
    return 'Start Time: $time';
  }

  @override
  String get sessionHistoryPreflop => 'Preflop:';

  @override
  String get sessionHistoryFlop => 'Flop:';

  @override
  String get sessionHistoryTurn => 'Turn:';

  @override
  String get sessionHistoryRiver => 'River:';

  @override
  String sessionHistorySyncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String sessionHistoryClearFailed(String error) {
    return 'Failed to clear sessions: $error';
  }

  @override
  String get notificationsClubNotFound => 'Club not found';

  @override
  String get notificationsAccept => 'Accept';

  @override
  String get notificationsInvitationAccepted => 'Invitation Accepted';

  @override
  String get notificationsInvitationDeclined => 'Invitation Declined';

  @override
  String get notificationsInvitationDeclinedMsg => 'Invitation declined';

  @override
  String get notificationsEventNotFound => 'Event not found';

  @override
  String notificationsFailedLoadClub(String error) {
    return 'Failed to load club: $error';
  }

  @override
  String notificationsErrorLoadingEvent(String error) {
    return 'Error loading event: $error';
  }

  @override
  String invitationsFailedLoad(String error) {
    return 'Failed to load invitations: $error';
  }

  @override
  String invitationsFailedAccept(String error) {
    return 'Failed to accept invitation: $error';
  }

  @override
  String get invitationsDeclined => 'Invitation declined';

  @override
  String invitationsFailedDecline(String error) {
    return 'Failed to decline invitation: $error';
  }

  @override
  String get clubSettingsTableAdded => 'Table added';

  @override
  String get clubSettingsTableDeleted => 'Table deleted';

  @override
  String get clubSettingsQrRegenerated => 'QR codes regenerated';

  @override
  String clubSettingsErrorPdf(String error) {
    return 'Error generating PDF: $error';
  }

  @override
  String get clubDashboardActiveDealers => 'Active Dealers';

  @override
  String get clubDashboardPendingInvitations => 'Pending Invitations';

  @override
  String get clubDashboardDealerEmailHint => 'dealer@example.com';

  @override
  String clubDashboardInvitationSent(String email) {
    return 'Invitation sent to $email';
  }

  @override
  String clubDashboardFailedSendInvite(String error) {
    return 'Failed to send invitation: $error';
  }

  @override
  String clubDashboardFailedCancelInvite(String error) {
    return 'Failed to cancel invitation: $error';
  }

  @override
  String eventManagementClubEvents(String name) {
    return '$name Events';
  }

  @override
  String eventManagementFailedUpdate(String error) {
    return 'Failed to update event: $error';
  }

  @override
  String get profileCash => 'Cash';

  @override
  String get profileTournament => 'Tournament';

  @override
  String get profileDevTools => 'Dev Tools';

  @override
  String get profilePremiumOverride => 'Premium Override';

  @override
  String profileUsingRealStatus(String status) {
    return 'Using real status: $status';
  }

  @override
  String profileOverridden(String status) {
    return 'Overridden: $status';
  }

  @override
  String get profileResetToReal => 'Reset to real status';

  @override
  String get profileVersion => 'Version 1.0';

  @override
  String profileLastLogin(String date) {
    return 'Last login $date';
  }

  @override
  String pokerHandFailedEndSession(String error) {
    return 'Failed to end session: $error';
  }

  @override
  String pokerHandFailedSaveSession(String error) {
    return 'Failed to save session: $error';
  }

  @override
  String pokerHandRebuyAdded(String amount, String stack) {
    return 'Rebuy added: \$$amount (Stack: $stack)';
  }

  @override
  String get pokerHandEndSession => 'End session';

  @override
  String get pokerHandRebuyAmountDollar => 'Rebuy Amount (\$)';

  @override
  String get pokerHandRebuyChips => 'Rebuy Chips';

  @override
  String seatSetupFailedSave(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get seatSetupSelectYourSeat => 'Please select your seat';

  @override
  String get authExpLinkGoogleTitle => 'Link Google Account';

  @override
  String get authExpPassword => 'Password';

  @override
  String get authExpLinkAccount => 'Link Account';

  @override
  String get individualSetupSessionNameHint => 'e.g., \"Friday Night Poker\"';

  @override
  String get individualSetupCashGame => 'Cash Game';

  @override
  String get individualSetupTournament => 'Tournament';

  @override
  String get individualSetupEnterAmount => 'Enter amount';

  @override
  String get individualSetupEnterChipStack => 'Enter chip stack';

  @override
  String get individualSetupSmallBlind => 'Small Blind';

  @override
  String get individualSetupBigBlind => 'Big Blind';

  @override
  String get individualSetupEnterValue => 'Enter value';

  @override
  String get individualHandSetupNameHint => 'e.g., \"AA vs KK Cooler\"';

  @override
  String get individualHandSetupSmallBlind => 'Small Blind';

  @override
  String get individualHandSetupBigBlind => 'Big Blind';

  @override
  String get individualHandSetupPlayers => 'Players';

  @override
  String get individualHandSetupGameType => 'Game Type';

  @override
  String get playerSessionYourHoleCards => 'Your Hole Cards';

  @override
  String get playerSessionSeat => 'SEAT';

  @override
  String get playerSessionStack => 'STACK';

  @override
  String get playerSessionPot => 'POT';

  @override
  String get playerSessionNotesHint => 'Add notes about this hand...';

  @override
  String get dealerQrScanInvalidCode =>
      'Invalid QR code. Please scan a valid table QR code.';

  @override
  String get dealerQrScanWrongClub => 'This table belongs to a different club.';

  @override
  String get dealerQrScanTableNotFound =>
      'Table not found. Please scan a valid table QR code.';

  @override
  String dealerQrScanError(String error) {
    return 'Error processing QR code: $error';
  }

  @override
  String dealerQrScanFailedStart(String error) {
    return 'Failed to start session: $error';
  }

  @override
  String dealerQrScanTakingOver(String name) {
    return 'Taking over from $name';
  }

  @override
  String get dealerQrScanHandsPlayed => 'Hands Played';

  @override
  String get dealerQrScanBlinds => 'Blinds';

  @override
  String get dealerQrScanPlayers => 'Players';

  @override
  String dealerQrScanFailedResume(String error) {
    return 'Failed to resume session: $error';
  }

  @override
  String get usernameSetupLabel => 'Username';

  @override
  String get stackChartScreenAvgGrowth => 'Avg Growth';

  @override
  String get stackChartScreenDuration => 'Duration';

  @override
  String get stackChartScreenProfitLoss => 'P/L';

  @override
  String get stackChartScreenStack => 'Stack';

  @override
  String get quickStackSearchHint => 'Search or add player...';

  @override
  String get sessionHandsLoading => 'Loading hands...';

  @override
  String createEventDefaultCashGame(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get createEventDefaultCashGameNoStakes => 'Cash Game';

  @override
  String get eventDashboardTvMode => 'TV Display Mode';

  @override
  String get tableSelectionTitle => 'Select Table';

  @override
  String get tableSelectionAdminSubtitle => 'Choose a table to manage';

  @override
  String get tableSelectionMemberSubtitle =>
      'Choose a table to view availability';

  @override
  String get tableSelectionNoTables => 'No tables available';

  @override
  String tableSelectionOpenSeats(int count) {
    return '$count open';
  }

  @override
  String tableSelectionSeated(int occupied) {
    return '$occupied/9 seated';
  }

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Apr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Aug';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dec';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String opponentsErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String opponentsErrorDeleting(String error) {
    return 'Error deleting opponent: $error';
  }

  @override
  String opponentsErrorClearing(String error) {
    return 'Error clearing opponents: $error';
  }

  @override
  String get onboardingReadTitle => 'READ THE GAME\nLIKE A PRO';

  @override
  String get onboardingReadSubtitle =>
      'Create an account to start tracking your poker journey.';

  @override
  String get onboardingCreateAccount => 'Create account';

  @override
  String get onboardingLogIn => 'Log in';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingFinalTable => 'Final Table';

  @override
  String get authExpSignUpTitle => 'Sign up';

  @override
  String get authExpLogInTitle => 'Log in to your account';

  @override
  String get authExpSignUpSubtitle => 'Create an account to continue';

  @override
  String get authExpLogInSubtitle => 'Enter your email and password to log in';

  @override
  String get authExpName => 'Name';

  @override
  String get authExpEmail => 'Email';

  @override
  String get authExpEnterName => 'Please enter your name';

  @override
  String get authExpNameMinLength => 'Name must be at least 2 characters';

  @override
  String get authExpEnterEmail => 'Please enter your email';

  @override
  String get authExpValidEmail => 'Please enter a valid email';

  @override
  String get authExpEnterPassword => 'Please enter your password';

  @override
  String get authExpPasswordMinLength =>
      'Password must be at least 6 characters';

  @override
  String get authExpBySigningUp => 'By Signing up, you agree to the ';

  @override
  String get authExpTermsOfService => 'Terms of Service';

  @override
  String get authExpAnd => '\nand ';

  @override
  String get authExpPrivacyPolicy => 'Privacy Policy';

  @override
  String get authExpCreateAccount => 'Create account';

  @override
  String get authExpAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get authExpSignIn => 'Sign in';

  @override
  String get authExpForgotPassword => 'Forgot password?';

  @override
  String get authExpDontHaveAccount => 'Don\'t have an account? ';

  @override
  String get authExpSignUp => 'Sign up';

  @override
  String get authExpOr => 'or';

  @override
  String get authExpContinueGoogle => 'Continue with Google';

  @override
  String authExpLinkGoogleMessage(String email) {
    return 'An account with $email already exists. Enter your password to link your Google account.';
  }

  @override
  String forgotPasswordCodeSubtitle(String email) {
    return 'Enter the 6-digit code sent to $email';
  }

  @override
  String get usernameSetupChangeTitle => 'Change your username';

  @override
  String get usernameSetupChooseTitle => 'Choose your username';

  @override
  String get usernameSetupSubtitle =>
      'This is how other players will know you at the table';

  @override
  String get usernameSetupRequired => 'Username is required';

  @override
  String get usernameSetupCheckingAvailability => 'Checking availability…';

  @override
  String get usernameSetupAvailable => 'Available!';

  @override
  String get usernameSetupAlreadyTaken => 'Already taken';

  @override
  String get usernameSetupCurrentUsername => 'This is your current username';

  @override
  String get usernameSetupCouldNotCheck => 'Could not check availability';

  @override
  String get usernameSetupJustTaken => 'Username was just taken. Try another.';

  @override
  String get usernameSetupRulesHint =>
      '3–20 characters · letters, numbers, underscores';

  @override
  String get usernameSetupUpdateButton => 'Update username';

  @override
  String get usernameSetupClaimButton => 'Claim username';

  @override
  String get usernameSetupSkip => 'Skip for now';

  @override
  String get sessionHandsTitle => 'Session';

  @override
  String sessionHandsHandsLogged(int count) {
    return '$count hands logged';
  }

  @override
  String get sessionHandsError => 'Error';

  @override
  String get sessionHandsNoHandsTitle => 'No Hands Logged';

  @override
  String get sessionHandsNoHandsSubtitle =>
      'This session has no recorded hands yet.';

  @override
  String get sessionHandsWon => 'WON';

  @override
  String sessionHandsActions(int count) {
    return '$count actions';
  }

  @override
  String get sessionHandsPot => 'Pot';

  @override
  String get stackChartScreenTitle => 'Stack Chart';

  @override
  String get stackChartScreenPokerSession => 'Poker Session';

  @override
  String get notificationsScreenTitle => 'Notifications';

  @override
  String get notificationsScreenToday => 'Today';

  @override
  String get notificationsScreenMarkAllAsRead => 'Mark all as read';

  @override
  String get notificationsScreenMarkAsRead => 'Mark as read';

  @override
  String get notificationsScreenNoNotifications => 'No notifications';

  @override
  String get notificationsScreenClubInvitation => 'Club Invitation';

  @override
  String get notificationsScreenInvitedToJoin => 'You\'ve been invited to join';

  @override
  String get notificationsScreenDecline => 'Decline';

  @override
  String get notificationsScreenNotAuthenticated => 'Not authenticated';

  @override
  String get notificationsScreenRequestResolved => 'Request Resolved';

  @override
  String get notificationsScreenRequestClosed => 'Request Closed';

  @override
  String get notificationsScreenResponse => 'Response';

  @override
  String get notificationsScreenEvents => 'Events';

  @override
  String get notificationsScreenRsvp => 'RSVP';

  @override
  String get notificationsScreenClubs => 'Clubs';

  @override
  String get notificationsScreenInvitations => 'Invitations';

  @override
  String get notificationsScreenSeats => 'Seats';

  @override
  String get notificationsScreenSupport => 'Support';

  @override
  String notifEventCreatedTitle(String eventName) {
    return 'New Event: $eventName';
  }

  @override
  String notifEventCreatedBody(String date) {
    return '$date';
  }

  @override
  String notifEventUpdatedTitle(String eventName) {
    return 'Event Updated: $eventName';
  }

  @override
  String notifEventUpdatedBody(String clubName) {
    return '$clubName updated the event details';
  }

  @override
  String notifEventCancelledTitle(String eventName) {
    return 'Event Cancelled: $eventName';
  }

  @override
  String notifEventCancelledBody(String clubName, String date) {
    return '$clubName has cancelled the event scheduled for $date';
  }

  @override
  String notifEventStartingTitle(String eventName) {
    return '$eventName starts in 1 hour!';
  }

  @override
  String notifEventStartingBody(String clubName) {
    return '$clubName event is about to begin';
  }

  @override
  String notifEventStartedTitle(String eventName) {
    return '$eventName is now LIVE!';
  }

  @override
  String notifEventStartedBody(String clubName) {
    return '$clubName event has started - join now to spectate';
  }

  @override
  String notifSeatAvailableTitle(String eventName) {
    return 'Seat is open: $eventName';
  }

  @override
  String notifSeatAvailableBody(String clubName) {
    return 'A seat is now available at $clubName! Open the app to take your spot.';
  }

  @override
  String notifMemberRsvpTitle(String memberName) {
    return 'RSVP: $memberName';
  }

  @override
  String notifMemberRsvpBody(
      String memberName, String rsvpStatus, String eventName) {
    return '$memberName responded \"$rsvpStatus\" to $eventName';
  }

  @override
  String get notifNewClubRequestTitle => 'New Club Request';

  @override
  String get notifNewClubRequestBody =>
      'A new club registration request has been submitted';

  @override
  String get notifClubApprovedTitle => 'Club Approved';

  @override
  String get notifClubApprovedBody => 'Your club has been approved!';

  @override
  String get notifClubRejectedTitle => 'Club Rejected';

  @override
  String get notifClubRejectedBody => 'Your club request has been rejected';

  @override
  String get notifMemberInvitedTitle => 'Club Invitation';

  @override
  String get notifMemberInvitedBody => 'You\'ve been invited to join a club';

  @override
  String get notifInvitationAcceptedTitle => 'Invitation Accepted';

  @override
  String notifInvitationAcceptedBody(String memberName) {
    return '$memberName has accepted the invitation';
  }

  @override
  String get notifInvitationDeclinedTitle => 'Invitation Declined';

  @override
  String notifInvitationDeclinedBody(String memberName) {
    return '$memberName has declined the invitation';
  }

  @override
  String get notifSupportRequestTitle => 'Support Request';

  @override
  String get notifSupportRequestBody =>
      'A new support request has been submitted';

  @override
  String get notifSupportUpdatedTitle => 'Support Update';

  @override
  String get notifSupportUpdatedBody => 'Your support request has been updated';

  @override
  String get notifTypeEventCreated => 'New Event';

  @override
  String get notifTypeEventUpdated => 'Event Updated';

  @override
  String get notifTypeEventCancelled => 'Event Cancelled';

  @override
  String get notifTypeEventStarting => 'Event Starting Soon';

  @override
  String get notifTypeEventStarted => 'Event Started';

  @override
  String get notifTypeMemberRsvp => 'Member RSVP';

  @override
  String get notifTypeNewClubRequest => 'New Club Request';

  @override
  String get notifTypeClubApproved => 'Club Approved';

  @override
  String get notifTypeClubRejected => 'Club Rejected';

  @override
  String get notifTypeMemberInvited => 'Club Invitation';

  @override
  String get notifTypeInvitationAccepted => 'Invitation Accepted';

  @override
  String get notifTypeInvitationDeclined => 'Invitation Declined';

  @override
  String get notifTypeSeatAvailable => 'Seat Available';

  @override
  String get notifTypeSupportRequest => 'Support Request';

  @override
  String get notifTypeSupportUpdated => 'Support Update';

  @override
  String get invitationsScreenTitle => 'Club Invitations';

  @override
  String get invitationsScreenNoPending => 'No pending invitations';

  @override
  String get invitationsScreenYouWillSee =>
      'You\'ll see invitations from clubs here';

  @override
  String get invitationsScreenGoBack => 'Go Back';

  @override
  String get invitationsScreenUnknownClub => 'Unknown Club';

  @override
  String invitationsScreenInvitedBy(String name) {
    return 'Invited by $name';
  }

  @override
  String invitationsScreenExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get invitationsScreenExpired => 'Expired';

  @override
  String invitationsScreenExpiresInDays(int days) {
    return 'in $days day(s)';
  }

  @override
  String invitationsScreenExpiresInHours(int hours) {
    return 'in $hours hour(s)';
  }

  @override
  String get invitationsScreenExpiresSoon => 'soon';

  @override
  String get invitationsScreenDecline => 'Decline';

  @override
  String get invitationsScreenAccept => 'Accept';

  @override
  String invitationsScreenJoinedAs(String clubName, String role) {
    return 'Joined $clubName as $role';
  }

  @override
  String get profilePremium => 'Premium';

  @override
  String get profileFree => 'Free';

  @override
  String get dealerTableStartNewHand => 'Start New Hand';

  @override
  String get dealerTableStartSessionBtn => 'Start Session';

  @override
  String get dealerTableNeedTwoPlayers => 'Need at least 2 players to start';

  @override
  String get dealerTableAddTestPlayers => 'Add Test Players';

  @override
  String dealerTableAddedTestPlayers(int count) {
    return 'Added $count test players';
  }

  @override
  String dealerTableRolledBack(String street) {
    return 'Rolled back to $street';
  }

  @override
  String dealerTableUndoneAction(String playerName, String action) {
    return 'Undone: $playerName $action';
  }

  @override
  String get dealerTableScanToJoin => 'Scan to join this seat';

  @override
  String get dealerTableOccupiedDot => 'Occupied · ';

  @override
  String get dealerTableEmptyLabel => 'Empty';

  @override
  String get dealerTableOccupiedLabel => 'Occupied';

  @override
  String get dealerTableSelectedLabel => 'Selected';

  @override
  String get dealerTableSelectSeatLabel => 'SELECT SEAT';

  @override
  String get dealerTableBetAmountDialog => 'Bet amount';

  @override
  String get dealerTableRaiseToDialog => 'Raise to';

  @override
  String get dealerTablePausedLabel => 'Paused';

  @override
  String get dealerTableListeningLabel => 'Listening';

  @override
  String get dealerTableResumeVoiceTooltip => 'Resume Voice';

  @override
  String get dealerTablePauseVoiceTooltip => 'Pause Voice';

  @override
  String get dealerTableVoiceOffLabel => 'Voice off';

  @override
  String get dealerTableCalibratingLabel => 'Calibrating...';

  @override
  String get dealerTableCalibrationPrompt =>
      'Please announce: \"Table [number], dealer [name]\"';

  @override
  String dealerTableDealerLockedMsg(String name, String table) {
    return 'Dealer locked: $name at table $table';
  }

  @override
  String get dealerTableNoSpeakersMsg =>
      'No speakers detected - please speak clearly';

  @override
  String get dealerTableSayTableDealerMsg =>
      'Please say: \"Table [number], dealer [name]\"';

  @override
  String get dealerTableConnectionLostRecovery =>
      'Connection lost - attempting to recover...';

  @override
  String get dealerTableConnectionTimeout =>
      'Connection timeout - recalibration required';

  @override
  String get dealerTableConnectionRecovered => 'Connection recovered!';

  @override
  String get dealerTableActionHeldMsg => 'Action held';

  @override
  String get dealerTableFailedStartStreaming =>
      'Failed to start streaming - check server connection and microphone';

  @override
  String dealerTableFailedStartVoice(String error) {
    return 'Failed to start voice: $error';
  }

  @override
  String get dealerTableAddPlayerActionLabel => 'Add Player';

  @override
  String get dealerTableSeatAnotherPlayer => 'Seat another player here';

  @override
  String get dealerTableSitHereLabel => 'Sit Here';

  @override
  String get dealerTableJoinAsDealerPlayer => 'Join the game as dealer-player';

  @override
  String get dealerTableDealerFallback => 'Dealer';

  @override
  String dealerTableUpdatedStackMsg(String name, String amount) {
    return 'Updated $name stack to $amount';
  }

  @override
  String dealerTableFailedUpdateStackMsg(String error) {
    return 'Failed to update stack: $error';
  }

  @override
  String dealerTableSittingAtSeatMsg(int number) {
    return 'You are now playing at Seat $number';
  }

  @override
  String dealerTableFailedSitMsg(String error) {
    return 'Failed to sit at table: $error';
  }

  @override
  String dealerTableFailedAddPlayerMsg(String error) {
    return 'Failed to add player: $error';
  }

  @override
  String dealerTableRemovedFromSeat(String name, int seat) {
    return '$name removed from Seat $seat';
  }

  @override
  String dealerTableFailedRemoveMsg(String error) {
    return 'Failed to remove player: $error';
  }

  @override
  String get eventDetailDateAndTime => 'Date & Time';

  @override
  String eventDetailTableSeatInfo(String table, int seat) {
    return 'Table $table, Seat #$seat';
  }

  @override
  String get eventDetailYoureSeatedGoodLuck => 'You\'re seated, good luck!';

  @override
  String get eventDetailHomeGame => 'Home Game';

  @override
  String get clubDashboardDateLabel => 'Date';

  @override
  String get clubDashboardUnknownLabel => 'Unknown';

  @override
  String get clubDashboardActiveLabel => 'Active';

  @override
  String get clubDashboardIdleLabel => 'Idle';

  @override
  String clubDashboardInvitedTimeAgo(String time) {
    return 'Invited $time';
  }

  @override
  String get clubDashboardPendingLabel => 'Pending';

  @override
  String get clubDashboardNoDealersYet => 'No dealers yet';

  @override
  String get clubDashboardInviteDealersHint =>
      'Invite dealers to help manage your tables';

  @override
  String get clubDashboardInviteDealer => 'Invite Dealer';

  @override
  String get clubDashboardInviteDealerBody =>
      'Enter the email address of the dealer you want to invite.';

  @override
  String get clubDashboardSendInvitationBtn => 'Send Invitation';

  @override
  String clubDashboardInvitationSentTo(String email) {
    return 'Invitation sent to $email';
  }

  @override
  String clubDashboardFailedSendInvitationMsg(String error) {
    return 'Failed to send invitation: $error';
  }

  @override
  String get clubDashboardCancelInvitationTitle => 'Cancel Invitation?';

  @override
  String clubDashboardCancelInvitationBody(String email) {
    return 'Cancel the invitation to $email?';
  }

  @override
  String get clubDashboardKeepBtn => 'Keep';

  @override
  String get clubDashboardCancelInvitationBtn => 'Cancel Invitation';

  @override
  String clubDashboardFailedCancelMsg(String error) {
    return 'Failed to cancel invitation: $error';
  }

  @override
  String clubSettingsMembers(int count) {
    return 'Members ($count)';
  }

  @override
  String get clubSettingsNoMembersFound => 'No members found';

  @override
  String get clubSettingsRoleOwner => 'Owner';

  @override
  String get clubSettingsRoleAdmin => 'Admin';

  @override
  String get clubSettingsRoleDealer => 'Dealer';

  @override
  String get clubSettingsRolePlayer => 'Player';

  @override
  String get clubSettingsTableAddedMsg => 'Table added';

  @override
  String get clubSettingsEditTableTitle => 'Edit Table';

  @override
  String get clubSettingsDeleteTableTitle => 'Delete Table?';

  @override
  String clubSettingsDeleteTableBody(String name) {
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
  }

  @override
  String get clubSettingsTableDeletedMsg => 'Table deleted';

  @override
  String get clubSettingsDealerScanHint =>
      'Dealers scan this to start a session at this table';

  @override
  String get clubSettingsRegenerateBtn => 'Regenerate';

  @override
  String get clubSettingsAppQrCodes => 'App QR Codes';

  @override
  String get clubSettingsShareWithPlayers =>
      'Share with players to download the app';

  @override
  String get clubSettingsDownloadPdf => 'Download PDF';

  @override
  String get clubSettingsDownloadFinalTable => 'Download the Final Table App';

  @override
  String get clubSettingsScanQrToGetStarted =>
      'Scan the QR code for your device to get started';

  @override
  String get clubSettingsScanToStartSession =>
      'Scan this QR code to start a session';

  @override
  String get clubSettingsForDealersOnly => 'For dealers only';

  @override
  String clubSettingsTableDefault(int number) {
    return 'Table $number';
  }

  @override
  String eventManagementFailedUpdateEvent(String error) {
    return 'Failed to update event: $error';
  }

  @override
  String adminTableThisWillMoveMsg(int count) {
    return 'This will move $count player(s) to the waitlist and remove the table from this event.';
  }

  @override
  String get adminTableThisWillRemoveMsg =>
      'This will remove the table from this event.';

  @override
  String adminTableClosedWithWaitlistMsg(String table, int count) {
    return '$table closed. $count player(s) moved to waitlist.';
  }

  @override
  String adminTableClosedMsg(String table) {
    return '$table closed.';
  }

  @override
  String get adminTableEmptyLabel => 'Empty';

  @override
  String get adminTableTableFallback => 'Table';

  @override
  String adminTableTableNumberLabel(int number) {
    return 'Table $number';
  }

  @override
  String homePendingInvitationsMsg(int count) {
    return 'You have $count pending club invitation(s).';
  }

  @override
  String get homeEventFallback => 'Event';

  @override
  String get homePokerFallback => 'Poker';

  @override
  String get homeUserFallback => 'User';

  @override
  String homeSeatInfoStr(int seat, String chipStack) {
    return 'Seat #$seat  •  $chipStack';
  }

  @override
  String get pokerHandYouLabel => 'You';

  @override
  String pokerHandMovingToTable(int table, String stack) {
    return 'Moving to Table $table. Your stack ($stack) will carry over. Other players will be cleared.';
  }

  @override
  String pokerHandActiveSessionMsg(int count) {
    return 'You have an active session with $count hand(s) logged. What would you like to do?';
  }

  @override
  String get pokerHandUnknownLabel => 'Unknown';

  @override
  String get pokerHandFoldAction => 'Fold';

  @override
  String get pokerHandRaiseAction => 'Raise';

  @override
  String get pokerHandBetAction => 'Bet';

  @override
  String get pokerHandAllInAction => 'All-In';

  @override
  String get pokerHandAllPlayersAllIn =>
      'All players all-in - dealing remaining cards';

  @override
  String get pokerHandWaitingForCards => 'Waiting for cards to be dealt';

  @override
  String get pokerHandBettingComplete =>
      'Betting complete - ready for next street';

  @override
  String pokerHandSeatFallback(int id) {
    return 'Seat $id';
  }

  @override
  String pokerHandPlayerFallback(int id) {
    return 'Player $id';
  }

  @override
  String get pokerHandChooseOption => 'Choose an option:';

  @override
  String get pokerHandLeaveBtn => 'Leave';

  @override
  String get pokerHandConfirmBtn => 'Confirm';

  @override
  String pokerHandCurrentlyHaveRemaining(String stack) {
    return 'You currently have $stack remaining.';
  }

  @override
  String get opponentsColorRed => 'Red';

  @override
  String get opponentsColorLightBlue => 'Light Blue';

  @override
  String get opponentsColorGreen => 'Green';

  @override
  String get opponentsColorOrange => 'Orange';

  @override
  String get opponentsColorPurple => 'Purple';

  @override
  String get opponentsColorTeal => 'Teal';

  @override
  String get opponentsColorPink => 'Pink';

  @override
  String get opponentsColorIndigo => 'Indigo';

  @override
  String opponentsFailedToLoad(String error) {
    return 'Failed to load opponents: $error';
  }

  @override
  String get opponentDetailFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get opponentDetailStealLabel => 'Steal';

  @override
  String get opponentDetailCheckRaiseLabel => 'Check/Raise';

  @override
  String get individualSetupSessionSetup => 'Session Setup';

  @override
  String get individualSetupSessionNameLabel => 'Session Name';

  @override
  String get individualSetupGameTypeLabel => 'Game Type';

  @override
  String get individualSetupCashGameLabel => 'Cash Game';

  @override
  String get individualSetupTournamentLabel => 'Tournament';

  @override
  String get individualSetupBuyInAmountLabel => 'Buy-in Amount';

  @override
  String get individualSetupEnterAmountHint => 'Enter amount';

  @override
  String get individualSetupCashGameNote =>
      'In cash games your starting stack equals your buy-in amount.';

  @override
  String get individualSetupStartingStackLabel => 'Starting Stack';

  @override
  String get individualSetupEnterChipStackHint => 'Enter chip stack';

  @override
  String individualSetupStackValidation(int bigBlind) {
    return 'Starting stack must be at least equal to the Big Blind ($bigBlind)';
  }

  @override
  String get individualSetupStartSessionBtn => 'Start Session';

  @override
  String get individualSetupEnterValueHint => 'Enter value';

  @override
  String get individualHandSetupTitle => 'Individual Hand';

  @override
  String get individualHandSetupSubtitle => 'Quick hand logging setup';

  @override
  String get individualHandSetupHandNameLabel => 'Hand Name (Optional)';

  @override
  String get playerSessionBluff => 'Bluff';

  @override
  String get playerSessionValue => 'Value';

  @override
  String get playerSessionMistake => 'Mistake';

  @override
  String get playerSessionCooler => 'Cooler';

  @override
  String get playerSessionHeroCall => 'Hero Call';

  @override
  String get playerSessionExploit => 'Exploit';

  @override
  String get playerSessionToughSpot => 'Tough Spot';

  @override
  String get playerSessionEasyFold => 'Easy Fold';

  @override
  String get playerSessionEndedTitle => 'Session Ended';

  @override
  String get playerSessionEndedBody => 'The dealer has ended this session.';

  @override
  String get playerSessionRemovedTitle => 'Removed from Table';

  @override
  String get playerSessionRemovedBody =>
      'You have been removed from the table by the dealer.';

  @override
  String playerSessionYouWon(String amount) {
    return 'You won $amount!';
  }

  @override
  String playerSessionSeatWins(int seat, String amount) {
    return 'Seat $seat wins $amount';
  }

  @override
  String get playerSessionYourHoleCardsTitle => 'Your Hole Cards';

  @override
  String get playerSessionConnecting => 'Connecting...';

  @override
  String get playerSessionGoBackBtn => 'Go Back';

  @override
  String get playerSessionHoleCardsLabel => 'Hole Cards';

  @override
  String get playerSessionEditBtn => 'Edit';

  @override
  String get playerSessionAddBtn => 'Add';

  @override
  String get playerSessionBoardLabel => 'Board';

  @override
  String get playerSessionNoCardsDealt => 'No cards dealt';

  @override
  String get playerSessionWaitingForAction => 'Waiting for action...';

  @override
  String get playerSessionActionsLabel => 'Actions';

  @override
  String get playerSessionYouLabel => 'You';

  @override
  String playerSessionSeatFallback(int seat) {
    return 'Seat $seat';
  }

  @override
  String get playerSessionNotesHintText => 'Add notes about this hand...';

  @override
  String get playerSessionHandHistoryLabel => 'Hand History';

  @override
  String get playerSessionNoCompletedHands => 'No completed hands yet';

  @override
  String playerSessionWonAmount(String amount) {
    return 'Won $amount';
  }

  @override
  String get playerSessionLostLabel => 'Lost';

  @override
  String get playerSessionDealerChangeTitle => 'Dealer Change';

  @override
  String get playerSessionWaitingForDealer =>
      'Waiting for new dealer to take over...';

  @override
  String playerSessionHandUpdated(int number) {
    return 'Hand #$number updated';
  }

  @override
  String playerSessionErrorSaving(String error) {
    return 'Error saving: $error';
  }

  @override
  String playerSessionEditHand(int number) {
    return 'Edit Hand #$number';
  }

  @override
  String get playerSessionViewDetails => 'View Details';

  @override
  String get playerSessionTapToAddHoleCards => 'Tap to add hole cards';

  @override
  String get playerSessionSaveChanges => 'Save Changes';

  @override
  String get playerSessionLeaveTableTitle => 'Leave Table?';

  @override
  String get playerSessionLeaveTableBody =>
      'Are you sure you want to leave this table?';

  @override
  String playerSessionFailedLeave(String error) {
    return 'Failed to leave: $error';
  }

  @override
  String get playerSessionTableSession => 'Table Session';

  @override
  String playerSessionHandNumber(int number) {
    return 'Hand #$number';
  }

  @override
  String get playerSessionUnknownDealer => 'Unknown';

  @override
  String get playerSessionNotAuthenticated => 'Not authenticated';

  @override
  String get dealerQrScanSessionSettings => 'Session Settings';

  @override
  String dealerQrScanTableNameLabel(String name) {
    return 'Table: $name';
  }

  @override
  String dealerQrScanEventNameLabel(String name) {
    return 'Event: $name';
  }

  @override
  String get dealerQrScanBlindsLabel => 'Blinds';

  @override
  String get dealerQrScanSmallBlindLabel => 'Small Blind';

  @override
  String get dealerQrScanBigBlindLabel => 'Big Blind';

  @override
  String get dealerQrScanStartDealingBtn => 'Start Dealing';

  @override
  String get dealerQrScanResumeSessionTitle => 'Resume Session';

  @override
  String dealerQrScanTakingOverFrom(String name) {
    return 'Taking over from $name';
  }

  @override
  String get dealerQrScanHandsPlayedLabel => 'Hands Played';

  @override
  String get dealerQrScanBlindsInfoLabel => 'Blinds';

  @override
  String get dealerQrScanPlayersLabel => 'Players';

  @override
  String get dealerQrScanResumeBtn => 'Resume';

  @override
  String get dealerQrScanTableNotAssigned => 'Table Not Assigned';

  @override
  String get dealerQrScanEventTablesLabel => 'Event tables:';

  @override
  String get dealerQrScanNoTablesAssigned => 'No tables assigned';

  @override
  String get dealerQrScanThisTableId => 'This table\'s ID:';

  @override
  String get dealerQrScanCorrectQrUrl => 'Correct QR code URL:';

  @override
  String get dealerQrScanScanTableQrTitle => 'Scan Table QR';

  @override
  String get dealerQrScanScanInstructions =>
      'Scan the table QR code to start dealing';

  @override
  String get eventDashboardTournamentOnBreak => 'Tournament on Break';

  @override
  String get eventDashboardLiveLabel => 'Live';

  @override
  String get eventDashboardLocalLabel => 'Local';

  @override
  String get eventDashboardDisconnectedLabel => 'Disconnected';

  @override
  String get eventDashboardPlayersLabel => 'Players';

  @override
  String get eventDashboardTablesLabel => 'Tables';

  @override
  String get eventDashboardTotalChipsLabel => 'Total Chips';

  @override
  String get eventDashboardAvgStackLabel => 'Avg Stack';

  @override
  String get eventDashboardChipLeaderLabel => 'Chip Leader';

  @override
  String get eventDashboardNoRankingsYet => 'No Rankings Yet';

  @override
  String get eventDashboardRankingsWillAppear =>
      'Rankings will appear as players join tables';

  @override
  String eventDashboardTableSeatLabel(String table, int seat) {
    return '$table - Seat $seat';
  }

  @override
  String eventDashboardPlayerFallback(String id) {
    return 'Player $id';
  }

  @override
  String get commonNA => 'N/A';

  @override
  String sessionHistoryFailedLoad(String error) {
    return 'Failed to load sessions: $error';
  }

  @override
  String get sessionHistoryCash => 'Cash';

  @override
  String get sessionHistoryTournament => 'Tournament';

  @override
  String sessionHistorySessionId(String id) {
    return 'Session $id...';
  }

  @override
  String sessionHistorySeatWithPosition(String seat, String position) {
    return 'Seat $seat ($position)';
  }

  @override
  String sessionHistorySeat(String seat) {
    return 'Seat $seat';
  }

  @override
  String get sessionHistorySyncCompleted => 'Sync completed';

  @override
  String get sessionHistoryFullHistory => 'Full session history';

  @override
  String get sessionHandsRetry => 'Retry';

  @override
  String get stackChartScreenStart => 'Start';

  @override
  String get stackChartScreenRebuy => 'Rebuy';

  @override
  String get stackChartScreenEnd => 'End';

  @override
  String get quickStackSelectPlayer => 'Select Player';

  @override
  String quickStackAddPlayer(String name) {
    return 'Add \"$name\"';
  }

  @override
  String get quickStackSaveToOpponents => 'Save to opponent list';

  @override
  String get quickStackYou => 'You';

  @override
  String get quickStackNoPlayersFound => 'No players found.';

  @override
  String get seatSetupDone => 'Done';

  @override
  String get seatSetupCancel => 'Cancel';

  @override
  String get authConnectionIssue => 'Connection Issue';

  @override
  String get authConnectionIssueBody =>
      'We couldn\'t connect to our servers.\nPlease check your internet connection\nand try again.';

  @override
  String get authTryAgain => 'Try Again';

  @override
  String get redeemInvitationTitle => 'Redeem Invitation';

  @override
  String get redeemEnterCode => 'Enter Invitation Code';

  @override
  String get redeemCodeDescription =>
      'Enter the 8-character code you received from a club admin to join their club.';

  @override
  String get redeemJoinClub => 'Join Club';

  @override
  String get redeemWelcome => 'Welcome!';

  @override
  String redeemJoinedAs(String clubName, String role) {
    return 'You have joined $clubName as $role';
  }

  @override
  String get redeemContinue => 'Continue';

  @override
  String get supportBugReport => 'Bug Report';

  @override
  String get supportFeatureRequest => 'Feature Request';

  @override
  String get supportAccountIssue => 'Account Issue';

  @override
  String get supportOther => 'Other';

  @override
  String get supportFillAllFields => 'Please fill in all fields';

  @override
  String get supportSubmitted => 'Support request submitted successfully';

  @override
  String supportFailedSubmit(String error) {
    return 'Failed to submit: $error';
  }

  @override
  String get supportTitle => 'Help & Support';

  @override
  String get supportSubmitButton => 'Submit';

  @override
  String get supportCategoryLabel => 'CATEGORY';

  @override
  String get supportSubjectLabel => 'SUBJECT';

  @override
  String get supportDescriptionLabel => 'DESCRIPTION';

  @override
  String get supportSubjectHint => 'Brief summary of the issue';

  @override
  String get supportDescriptionHint => 'Describe the issue in detail...';

  @override
  String get calendarEventLocation => 'Location';

  @override
  String get calendarEventBuyIn => 'Buy-in amount';

  @override
  String get calendarEventEdit => 'Edit';

  @override
  String get calendarEventDelete => 'Delete Event';

  @override
  String calendarEventDeleteConfirm(String title) {
    return 'Delete $title?';
  }

  @override
  String calendarEventDeleteBody(String title) {
    return 'Are you sure you want to delete \"$title\"?\nThis action cannot be undone.';
  }

  @override
  String get calendarEventDeleteButton => 'Delete';

  @override
  String get clubInfoTitle => 'Club Info';

  @override
  String clubInfoMembersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String get clubInfoNoMembers => 'No members found';

  @override
  String get finalStandingsNoData => 'No standings available';

  @override
  String get finalStandingsNoDataHint =>
      'This event may not have recorded standings';

  @override
  String get finalStandingsEmpty => 'No standings recorded';

  @override
  String get finalStandingsTitle => 'Final Standings';

  @override
  String get finalStandingsPlayers => 'Players';

  @override
  String get finalStandingsCompleted => 'Completed';

  @override
  String get liveRankingsTitle => 'Live Rankings';

  @override
  String get liveRankingsEliminated => 'Eliminated players';

  @override
  String get liveRankingsWaiting => 'Waiting for Players';

  @override
  String get liveRankingsWaitingHint =>
      'Rankings will appear once players get seated';

  @override
  String get liveRankingsError => 'Error Loading Rankings';

  @override
  String get liveRankingsTryAgain => 'Try Again';

  @override
  String get leaderboardPlayers => 'Players';

  @override
  String get leaderboardTotalChips => 'Total Chips';

  @override
  String get leaderboardWaiting => 'Waiting for players...';

  @override
  String leaderboardChipLeader(String name) {
    return 'Chip Leader: $name';
  }

  @override
  String get dealerQrScanBbAnte => 'BB Ante';

  @override
  String mainDealerOnClub(String clubName) {
    return 'You are now a dealer on $clubName';
  }

  @override
  String get raiseSnapMin => 'Min';

  @override
  String get raiseSnapPot => 'Pot';

  @override
  String get raiseSnapAllIn => 'All-In';

  @override
  String sessionHistoryPlayerWins(int playerId) {
    return 'Player $playerId wins:';
  }

  @override
  String get inviteClubAdminFallback => 'Club Admin';

  @override
  String pokerHandBetRange(String min, String max) {
    return 'Min: $min · Max: $max';
  }

  @override
  String pokerHandAmountBetween(String min, String max) {
    return 'Amount must be between $min and $max';
  }

  @override
  String get dealerTableBlindsLabel => 'BLINDS';

  @override
  String dealerTableAnteLabel(String amount) {
    return 'ANTE $amount';
  }

  @override
  String get dealerTablePotLabel => 'POT';

  @override
  String get dealerTableCheckLabel => 'CHECK';

  @override
  String dealerTablePlayerToAct(String playerName, String stack) {
    return '$playerName to act ($stack)';
  }

  @override
  String get eventDashboardOnBreakBadge => 'ON BREAK';

  @override
  String get eventDetailAdminActions => 'ADMIN ACTIONS';

  @override
  String get playerSessionHandNotesLabel => 'HAND NOTES';

  @override
  String get playerSessionTagsLabel => 'TAGS';

  @override
  String get playerSessionNotesLabel => 'NOTES';

  @override
  String get playerSessionHoleCardsUpperLabel => 'HOLE CARDS';

  @override
  String get qrJoinDeclined => 'Your join request was declined';

  @override
  String qrJoinFailed(String error) {
    return 'Failed to join seat: $error';
  }

  @override
  String get qrJoinTable => 'Join Table';

  @override
  String get qrJoinLoading => 'Loading table info...';

  @override
  String get qrJoinError => 'Something went wrong';

  @override
  String get qrJoinGoBack => 'Go Back';

  @override
  String get qrJoinSeatOccupied =>
      'This seat may already be occupied. Joining will replace the current player.';

  @override
  String get qrJoinWaitingDealer => 'Waiting for Dealer';

  @override
  String qrJoinRequestSent(int seatNumber) {
    return 'Your request to join Seat $seatNumber has been sent.';
  }

  @override
  String get qrJoinDealerApproval =>
      'The dealer will set your chip stack and approve your join.';

  @override
  String get qrJoinCancelRequest => 'Cancel Request';

  @override
  String get qrJoinRequestButton => 'Request to Join';

  @override
  String get onboardingSkipTour => 'Skip tour';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Final Table';

  @override
  String get onboardingWelcomeBody =>
      'Let\'s take a quick tour to get you started.\n\nYou can always retake this tour from\nProfile → Settings → Knowledge Base.';

  @override
  String get onboardingLetsGo => 'Let\'s go';

  @override
  String get onboardingGotIt => 'Got it';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStartLoggingTitle => 'Start Logging';

  @override
  String get onboardingStartLoggingBody =>
      'Tap the + button to begin logging a hand.';

  @override
  String get onboardingFullModeTitle => 'Full Logging Mode';

  @override
  String get onboardingFullModeBody =>
      'Track every action for every player across all streets. Perfect for serious analysis.';

  @override
  String get onboardingIndividualModeTitle => 'Individual Logging Mode';

  @override
  String get onboardingIndividualModeBody =>
      'Quick profit/loss tracking for a single session. Now choose a mode to continue!';

  @override
  String get onboardingSessionSetupTitle => 'Session Setup';

  @override
  String get onboardingSessionSetupBody =>
      'Fill in your session details — name, buy-in, blinds — then tap Start Game.';

  @override
  String get onboardingTableSetupTitle => 'Setup Your Table';

  @override
  String get onboardingTableSetupBody =>
      'Tap any seat to set up players. Let\'s walk through the seat dialog next.';

  @override
  String get onboardingSeatOpenTitle => 'Seat Open';

  @override
  String get onboardingSeatOpenBody =>
      'Toggle to mark a seat as occupied or empty. Open seats are skipped during the hand.';

  @override
  String get onboardingThisIsMySeatTitle => 'This Is My Seat';

  @override
  String get onboardingThisIsMySeatBody =>
      'Tap here if this is your seat. It auto-fills your name and tracks your personal stats.';

  @override
  String get onboardingPlayerNameTitle => 'Player Name';

  @override
  String get onboardingPlayerNameBody =>
      'Type a name or pick from your saved opponents. Saved opponents track stats across sessions.';

  @override
  String get onboardingSaveOpponentTitle => 'Save Opponent';

  @override
  String get onboardingSaveOpponentBody =>
      'New name? Tap here to save them as an opponent. Their stats will be tracked automatically.';

  @override
  String get onboardingDealerButtonTitle => 'Dealer Button';

  @override
  String get onboardingDealerButtonBody =>
      'Drag this to the seat with the dealer position. It determines blinds and action order.';

  @override
  String get onboardingViewSessionsTitle => 'View Your Sessions';

  @override
  String get onboardingViewSessionsBody =>
      'Tap Sessions to see your session results, hand history, and stats.';

  @override
  String get onboardingAllSetTitle => 'You\'re All Set!';

  @override
  String get onboardingAllSetBody =>
      'You\'re ready to start tracking your poker sessions.';

  @override
  String get onboardingLetsPlay => 'Let\'s play';

  @override
  String get onboardingUpdateStackTitle => 'Update Stack';

  @override
  String get onboardingUpdateStackBody =>
      'Use this to manually update your chip count at any point without logging a full hand.';

  @override
  String get onboardingLogAHandTitle => 'Log a Hand';

  @override
  String get onboardingLogAHandBody =>
      'Tap here to set up the table and log a hand. Let\'s try it now!';

  @override
  String get onboardingMarkSeatOpenTitle => 'Mark Seat Open';

  @override
  String get onboardingMarkSeatOpenBody =>
      'Tap the checkmark to toggle a seat between occupied and empty. Empty seats are skipped in the hand.';

  @override
  String get onboardingDealerButtonQsuTitle => 'Dealer Button';

  @override
  String get onboardingDealerButtonQsuBody =>
      'Tap \"D\" to assign the dealer button to any seat. This controls blind positions and action order.';

  @override
  String get onboardingAssignPlayerTitle => 'Assign a Player';

  @override
  String get onboardingAssignPlayerBody =>
      'Tap a player\'s name to seat yourself or a saved opponent. Your stack is auto-applied when you seat yourself.';

  @override
  String get onboardingAdjustStackTitle => 'Adjust Stack';

  @override
  String get onboardingAdjustStackBody =>
      'Drag the slider to set an opponent\'s stack in BBs. Tap the stack value to type an exact amount.';

  @override
  String get onboardingEndSessionTitle => 'End Your Session';

  @override
  String get onboardingEndSessionBody =>
      'Tap the red Stop button to save your session results and return to the home screen.';

  @override
  String onboardingStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get guidedGestureGuideTitle => 'Gesture Guide';

  @override
  String get guidedGestureGuideBody =>
      'Tap this icon anytime to see all gesture controls.';

  @override
  String get guidedSkipButtonTitle => 'Skip Button';

  @override
  String get guidedSkipButtonBody =>
      'If you skip a hand, this button moves the dealer button to the next player. Keep in mind that stacks will be out of sync — you can update them in Manage Players.';

  @override
  String get guidedGameMenuTitle => 'Game Menu';

  @override
  String get guidedGameMenuBody =>
      'This menu has useful options. Let\'s take a look at one important setting.';

  @override
  String get guidedGameSettingsTitle => 'Game Settings';

  @override
  String get guidedGameSettingsBody =>
      'Here you can change blinds mid-session — useful for tournaments when levels go up.';

  @override
  String get guidedEndSessionTitle => 'End Your Session';

  @override
  String get guidedEndSessionBody =>
      'Tap this menu and select \"Stop Session\" to save your results.';

  @override
  String get guidedReviewHandTitle => 'Review Hand';

  @override
  String get guidedReviewHandBody => 'Enter your hole cards and any notes.';

  @override
  String get guidedHandCompleteTitle => 'Hand Complete!';

  @override
  String get guidedHandCompleteBody =>
      'Great job! You just logged your first hand.';

  @override
  String get guidedSkip => 'Skip';

  @override
  String get guidedYourTurn => 'Your Turn!';

  @override
  String get guidedOpenThePotTitle => 'Open the Pot';

  @override
  String get guidedBetOnceBody => 'Tap once to bet.';

  @override
  String get guidedFoldTitle => 'Fold';

  @override
  String get guidedFoldBody => 'This player folds. Draw a line to fold.';

  @override
  String get guidedCallTitle => 'Call';

  @override
  String get guidedCallBody => 'This player calls. Draw a circle.';

  @override
  String get guidedCheckTitle => 'Check';

  @override
  String get guidedCheckBody => 'This player checks. Double tap.';

  @override
  String get guidedDealFlopTitle => 'Deal the Flop';

  @override
  String get guidedDealFlopBody => 'Select 3 cards for the flop.';

  @override
  String get guidedDealTurnTitle => 'Deal the Turn';

  @override
  String get guidedDealTurnBody => 'Select 1 card for the turn.';

  @override
  String get guidedDealRiverTitle => 'Deal the River';

  @override
  String get guidedDealRiverBody => 'Select 1 card for the river.';

  @override
  String get kbStatsTitle => 'Your Stats';

  @override
  String get kbClubsTitle => 'Clubs & Events';

  @override
  String get kbStatsIntro =>
      'Final Table tracks 7 core poker metrics to help you understand and improve your game.';

  @override
  String get kbClubsIntro =>
      'Clubs let you connect with your local poker room and track live games.';

  @override
  String get kbVpipName => 'VPIP';

  @override
  String get kbVpipFullName => 'Voluntarily Put \$ In Pot';

  @override
  String get kbVpipDescription =>
      'How often you enter a pot voluntarily (excluding blind posts). A high VPIP means you play many hands; a low VPIP means you\'re selective.';

  @override
  String get kbPfrName => 'PFR';

  @override
  String get kbPfrFullName => 'Preflop Raise';

  @override
  String get kbPfrDescription =>
      'How often you raise before the flop. The gap between VPIP and PFR shows how often you limp or cold-call.';

  @override
  String get kbThreeBetName => '3-Bet';

  @override
  String get kbThreeBetFullName => 'Three-Bet Percentage';

  @override
  String get kbThreeBetDescription =>
      'How often you re-raise an opponent\'s open raise preflop. A higher 3-bet% indicates an aggressive preflop style.';

  @override
  String get kbFoldTo3BetName => 'Fold to 3-Bet';

  @override
  String get kbFoldTo3BetFullName => 'Fold to Three-Bet';

  @override
  String get kbFoldTo3BetDescription =>
      'How often you fold after raising and facing a 3-bet. If too high, opponents can exploit you by 3-betting light.';

  @override
  String get kbCBetName => 'C-Bet';

  @override
  String get kbCBetFullName => 'Continuation Bet';

  @override
  String get kbCBetDescription =>
      'How often you bet on the flop after being the last preflop aggressor. A standard play showing strength.';

  @override
  String get kbStealName => 'Steal';

  @override
  String get kbStealFullName => 'Blind Steal Attempt';

  @override
  String get kbStealDescription =>
      'How often you open-raise from late position (CO, BTN, SB) when the pot is unopened, aiming to take the blinds.';

  @override
  String get kbCheckRaiseName => 'Check-Raise';

  @override
  String get kbCheckRaiseFullName => 'Flop Check-Raise';

  @override
  String get kbCheckRaiseDescription =>
      'How often you check then raise on the flop. A deceptive move that can trap aggressive opponents.';

  @override
  String get kbLiveEventsTitle => 'Live Events';

  @override
  String get kbLiveEventsDescription =>
      'Club managers create events with multiple tables. Join an event to be part of the live rankings.';

  @override
  String get kbLiveRankingsTitle => 'Live Rankings';

  @override
  String get kbLiveRankingsDescription =>
      'See where you stand in real-time during events. Rankings update after every hand.';

  @override
  String get kbOpponentTrackingTitle => 'Opponent Tracking';

  @override
  String get kbOpponentTrackingDescription =>
      'Players you face at the club are automatically tracked. Save opponents to build detailed profiles.';

  @override
  String get kbQrSeatTitle => 'QR Seat Assignment';

  @override
  String get kbQrSeatDescription =>
      'Scan a QR code at your table to join the session instantly. Your hands are tracked automatically by the dealer.';

  @override
  String get kbDealerLoggingTitle => 'Dealer-Assisted Logging';

  @override
  String get kbDealerLoggingDescription =>
      'Dealers use voice commands to log actions for the entire table. No manual input needed from players.';

  @override
  String get kbSessionStatsTitle => 'Session Stats';

  @override
  String get kbSessionStatsDescription =>
      'After each session, see your profit/loss and how your stats changed. Every hand is recorded.';

  @override
  String get qrJoinTableInfo => 'TABLE INFO';

  @override
  String qrJoinSeat(int number) {
    return 'Seat $number';
  }

  @override
  String get qrJoinTableFallback => 'Table';

  @override
  String get qrJoinClubLabel => 'Club';

  @override
  String get qrJoinTableLabel => 'Table';

  @override
  String get qrJoinSeatLabel => 'Seat';

  @override
  String get qrJoinStatusLabel => 'Status';

  @override
  String get qrJoinActiveGame => 'Active Game';

  @override
  String get qrJoinWaitingStatus => 'Waiting';

  @override
  String dealerQrTablesAssigned(int count) {
    return '$count table(s) assigned to this event';
  }

  @override
  String dealerQrTableNotAssigned(String tableName) {
    return '$tableName is not assigned to this event.';
  }

  @override
  String dealerTablePlayerAdded(String playerName, int seatNumber) {
    return '$playerName added to Seat $seatNumber';
  }

  @override
  String memberTableSeatedOpen(int seated, int open) {
    return '$seated seated  •  $open open';
  }

  @override
  String get memberTablePlayer => 'Player';

  @override
  String get memberTableEmpty => 'Empty';

  @override
  String get memberTableFallback => 'Table';

  @override
  String get homeEventTypeTournament => 'Tournament';

  @override
  String get homeEventTypeCashGame => 'Cash Game';

  @override
  String get homeEventTypeHomeGame => 'Home Game';

  @override
  String get homeEventTypeOnline => 'Online';

  @override
  String get bankrollSheetTitle => 'Add Result';

  @override
  String get bankrollSheetEditSection => 'Edit Bankroll';

  @override
  String get bankrollSheetGoalLabel => 'Bankroll Goal';

  @override
  String get bankrollSheetCurrentLabel => 'Current Bankroll';

  @override
  String get bankrollSheetGoalUpdated => 'Goal updated';

  @override
  String get bankrollSheetBankrollUpdated => 'Bankroll updated';

  @override
  String get sessionEndResultTitle => 'Session Result';

  @override
  String get sessionEndTournamentTitle => 'Tournament Result';

  @override
  String get sessionEndProfit => 'Profit';

  @override
  String get sessionEndLoss => 'Loss';

  @override
  String get sessionEndApply => 'Apply';

  @override
  String get sessionEndSkip => 'Skip';

  @override
  String get sessionEndFinishingPosition => 'Finishing Position';

  @override
  String get sessionEndFieldSize => 'Total Entries';

  @override
  String get sessionEndPrizeWon => 'Prize Won';

  @override
  String get sessionEndTotalInvested => 'Total Invested';

  @override
  String sessionEndCalculatedProfit(String amount) {
    return 'Calculated Profit: $amount';
  }
}
