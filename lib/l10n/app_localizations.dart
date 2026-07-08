import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pl'),
    Locale('pt'),
    Locale('ru')
  ];

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navOpponents.
  ///
  /// In en, this message translates to:
  /// **'Opponents'**
  String get navOpponents;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get commonNoData;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get commonNotAvailable;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get commonUpdate;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Analytics'**
  String get statsSubtitle;

  /// No description provided for @statsHandsPlayed.
  ///
  /// In en, this message translates to:
  /// **'Hands Played'**
  String get statsHandsPlayed;

  /// No description provided for @statsFoldTo3Bet.
  ///
  /// In en, this message translates to:
  /// **'Fold to 3-Bet'**
  String get statsFoldTo3Bet;

  /// No description provided for @statsWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win Rate'**
  String get statsWinRate;

  /// No description provided for @statsSessionStatistics.
  ///
  /// In en, this message translates to:
  /// **'Session Statistics'**
  String get statsSessionStatistics;

  /// No description provided for @statsSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get statsSessions;

  /// No description provided for @statsTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get statsTotalTime;

  /// No description provided for @statsAvgSession.
  ///
  /// In en, this message translates to:
  /// **'Avg Session'**
  String get statsAvgSession;

  /// No description provided for @statsPlayToSee.
  ///
  /// In en, this message translates to:
  /// **'Play sessions to see time statistics'**
  String get statsPlayToSee;

  /// No description provided for @statsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get statsGeneral;

  /// No description provided for @statsCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get statsCash;

  /// No description provided for @statsTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get statsTournament;

  /// No description provided for @statsTotalBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Total Buy-In'**
  String get statsTotalBuyIn;

  /// No description provided for @statsTotalCashOut.
  ///
  /// In en, this message translates to:
  /// **'Total Cash-Out'**
  String get statsTotalCashOut;

  /// No description provided for @statsNetProfit.
  ///
  /// In en, this message translates to:
  /// **'Net Profit'**
  String get statsNetProfit;

  /// No description provided for @statsItm.
  ///
  /// In en, this message translates to:
  /// **'ITM%'**
  String get statsItm;

  /// No description provided for @statsAvgFinish.
  ///
  /// In en, this message translates to:
  /// **'Avg Finish'**
  String get statsAvgFinish;

  /// No description provided for @statsBestFinish.
  ///
  /// In en, this message translates to:
  /// **'Best Finish'**
  String get statsBestFinish;

  /// No description provided for @statsRoi.
  ///
  /// In en, this message translates to:
  /// **'ROI%'**
  String get statsRoi;

  /// No description provided for @statsFinalTables.
  ///
  /// In en, this message translates to:
  /// **'Final Tables'**
  String get statsFinalTables;

  /// No description provided for @statsAvgBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Avg Buy-In'**
  String get statsAvgBuyIn;

  /// No description provided for @statsAvgFieldSize.
  ///
  /// In en, this message translates to:
  /// **'Avg Field Size'**
  String get statsAvgFieldSize;

  /// No description provided for @statsHourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate'**
  String get statsHourlyRate;

  /// No description provided for @statsHourlyRateNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available after 60 min of tracking'**
  String get statsHourlyRateNotAvailable;

  /// No description provided for @errorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get errorNoConnection;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again in a few minutes.'**
  String get errorServer;

  /// No description provided for @errorNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that. Try signing in again.'**
  String get errorNotAuthorized;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @statsBBPerHour.
  ///
  /// In en, this message translates to:
  /// **'BB / Hour'**
  String get statsBBPerHour;

  /// No description provided for @statsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading statistics...'**
  String get statsLoadingMessage;

  /// No description provided for @statsFetchingMessage.
  ///
  /// In en, this message translates to:
  /// **'Fetching user stats...'**
  String get statsFetchingMessage;

  /// No description provided for @statsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load statistics: {error}'**
  String statsFailedToLoad(String error);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose app language'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @settingsKnowledgeBase.
  ///
  /// In en, this message translates to:
  /// **'KNOWLEDGE BASE'**
  String get settingsKnowledgeBase;

  /// No description provided for @settingsGuidedTour.
  ///
  /// In en, this message translates to:
  /// **'Guided Tour'**
  String get settingsGuidedTour;

  /// No description provided for @settingsGuidedTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replay onboarding tours'**
  String get settingsGuidedTourSubtitle;

  /// No description provided for @settingsFullLoggingTour.
  ///
  /// In en, this message translates to:
  /// **'Full Logging Tour'**
  String get settingsFullLoggingTour;

  /// No description provided for @settingsFullLoggingTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete session tracking flow'**
  String get settingsFullLoggingTourSubtitle;

  /// No description provided for @settingsIndividualLoggingTour.
  ///
  /// In en, this message translates to:
  /// **'Individual Logging Tour'**
  String get settingsIndividualLoggingTour;

  /// No description provided for @settingsIndividualLoggingTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Single hand tracking flow'**
  String get settingsIndividualLoggingTourSubtitle;

  /// No description provided for @settingsUnderstandingStats.
  ///
  /// In en, this message translates to:
  /// **'Understanding Your Stats'**
  String get settingsUnderstandingStats;

  /// No description provided for @settingsUnderstandingStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn what each metric means'**
  String get settingsUnderstandingStatsSubtitle;

  /// No description provided for @settingsClubsEvents.
  ///
  /// In en, this message translates to:
  /// **'Clubs & Events'**
  String get settingsClubsEvents;

  /// No description provided for @settingsClubsEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How club play works'**
  String get settingsClubsEventsSubtitle;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'LEGAL'**
  String get settingsLegal;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTermsOfService;

  /// No description provided for @settingsTermsOfServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View our terms of service'**
  String get settingsTermsOfServiceSubtitle;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsPrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View our privacy policy'**
  String get settingsPrivacyPolicySubtitle;

  /// No description provided for @settingsAdmin.
  ///
  /// In en, this message translates to:
  /// **'ADMIN'**
  String get settingsAdmin;

  /// No description provided for @settingsClubRequests.
  ///
  /// In en, this message translates to:
  /// **'Club Requests'**
  String get settingsClubRequests;

  /// No description provided for @settingsClubRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage registration requests'**
  String get settingsClubRequestsSubtitle;

  /// No description provided for @settingsSupportRequests.
  ///
  /// In en, this message translates to:
  /// **'Support Requests'**
  String get settingsSupportRequests;

  /// No description provided for @settingsSupportRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage user support tickets'**
  String get settingsSupportRequestsSubtitle;

  /// No description provided for @settingsNotificationTester.
  ///
  /// In en, this message translates to:
  /// **'Notification Tester'**
  String get settingsNotificationTester;

  /// No description provided for @settingsNotificationTesterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preview all notification designs'**
  String get settingsNotificationTesterSubtitle;

  /// No description provided for @profileUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get profileUpgrade;

  /// No description provided for @profileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsername;

  /// No description provided for @profileNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet;

  /// No description provided for @profileChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get profileChange;

  /// No description provided for @profileSetUsername.
  ///
  /// In en, this message translates to:
  /// **'Set username'**
  String get profileSetUsername;

  /// No description provided for @profileUseNicknameInGames.
  ///
  /// In en, this message translates to:
  /// **'Use nickname in games'**
  String get profileUseNicknameInGames;

  /// No description provided for @profileUseNicknameDescription.
  ///
  /// In en, this message translates to:
  /// **'Show @{username} instead of your name in events and hand logging'**
  String profileUseNicknameDescription(String username);

  /// No description provided for @profileBankrollGoal.
  ///
  /// In en, this message translates to:
  /// **'Bankroll Goal'**
  String get profileBankrollGoal;

  /// No description provided for @profileUpdateGoal.
  ///
  /// In en, this message translates to:
  /// **'Update Goal'**
  String get profileUpdateGoal;

  /// No description provided for @profileCurrentBankroll.
  ///
  /// In en, this message translates to:
  /// **'Current Bankroll'**
  String get profileCurrentBankroll;

  /// No description provided for @profileUpdateBankroll.
  ///
  /// In en, this message translates to:
  /// **'Update Bankroll'**
  String get profileUpdateBankroll;

  /// No description provided for @profileAddSessionResult.
  ///
  /// In en, this message translates to:
  /// **'Add Session Result'**
  String get profileAddSessionResult;

  /// No description provided for @profileSessionResultHint.
  ///
  /// In en, this message translates to:
  /// **'Enter positive for wins, negative for losses'**
  String get profileSessionResultHint;

  /// No description provided for @profileAddResult.
  ///
  /// In en, this message translates to:
  /// **'Add Result'**
  String get profileAddResult;

  /// No description provided for @profileGoalUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Goal updated successfully!'**
  String get profileGoalUpdatedSuccess;

  /// No description provided for @profileErrorUpdatingGoal.
  ///
  /// In en, this message translates to:
  /// **'Error updating goal'**
  String get profileErrorUpdatingGoal;

  /// No description provided for @profileBankrollUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bankroll updated successfully!'**
  String get profileBankrollUpdatedSuccess;

  /// No description provided for @profileErrorUpdatingBankroll.
  ///
  /// In en, this message translates to:
  /// **'Error updating bankroll'**
  String get profileErrorUpdatingBankroll;

  /// No description provided for @profileSessionResultAdded.
  ///
  /// In en, this message translates to:
  /// **'Session result added!'**
  String get profileSessionResultAdded;

  /// No description provided for @profileErrorAddingResult.
  ///
  /// In en, this message translates to:
  /// **'Error adding session result'**
  String get profileErrorAddingResult;

  /// No description provided for @profilePleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get profilePleaseEnterValidAmount;

  /// No description provided for @profileLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogOut;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileSignOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get profileSignOutConfirmation;

  /// No description provided for @sessionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String get sessionHistoryTitle;

  /// No description provided for @sessionLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get sessionLast30Days;

  /// No description provided for @sessionUpgradeForFullHistory.
  ///
  /// In en, this message translates to:
  /// **'Upgrade for full history'**
  String get sessionUpgradeForFullHistory;

  /// No description provided for @sessionLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading sessions...'**
  String get sessionLoadingMessage;

  /// No description provided for @sessionNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No {gameType} Sessions'**
  String sessionNoSessions(String gameType);

  /// No description provided for @sessionPlayToSee.
  ///
  /// In en, this message translates to:
  /// **'Play some {gameType} Poker hands\nto see the results'**
  String sessionPlayToSee(String gameType);

  /// No description provided for @sessionLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get sessionLive;

  /// No description provided for @sessionPlayersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Players'**
  String sessionPlayersCount(int count);

  /// No description provided for @sessionSyncingToCloud.
  ///
  /// In en, this message translates to:
  /// **'Syncing to cloud...'**
  String get sessionSyncingToCloud;

  /// No description provided for @sessionClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Sessions?'**
  String get sessionClearAllTitle;

  /// No description provided for @sessionClearAllDescription.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all poker sessions and hands from both Firebase and local storage.'**
  String get sessionClearAllDescription;

  /// No description provided for @sessionClearAllWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone!'**
  String get sessionClearAllWarning;

  /// No description provided for @sessionClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get sessionClearAll;

  /// No description provided for @sessionClearedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'All sessions have been cleared successfully'**
  String get sessionClearedSuccessfully;

  /// No description provided for @sessionHandDetails.
  ///
  /// In en, this message translates to:
  /// **'Hand #{handNumber} Details'**
  String sessionHandDetails(int handNumber);

  /// No description provided for @sessionYourCards.
  ///
  /// In en, this message translates to:
  /// **'Your Cards:'**
  String get sessionYourCards;

  /// No description provided for @sessionBoardCards.
  ///
  /// In en, this message translates to:
  /// **'Board Cards:'**
  String get sessionBoardCards;

  /// No description provided for @sessionPotByStreet.
  ///
  /// In en, this message translates to:
  /// **'Pot by Street:'**
  String get sessionPotByStreet;

  /// No description provided for @sessionActions.
  ///
  /// In en, this message translates to:
  /// **'Actions:'**
  String get sessionActions;

  /// No description provided for @sessionNoActionsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No actions recorded'**
  String get sessionNoActionsRecorded;

  /// No description provided for @sessionNoCardsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No cards recorded'**
  String get sessionNoCardsRecorded;

  /// No description provided for @sessionFinalPot.
  ///
  /// In en, this message translates to:
  /// **'Final Pot:'**
  String get sessionFinalPot;

  /// No description provided for @sessionChoppedPot.
  ///
  /// In en, this message translates to:
  /// **'Chopped Pot ({count} winners):'**
  String sessionChoppedPot(int count);

  /// No description provided for @sessionWinnerNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Winner information not available'**
  String get sessionWinnerNotAvailable;

  /// No description provided for @opponentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Opponents'**
  String get opponentsTitle;

  /// No description provided for @opponentsCountFree.
  ///
  /// In en, this message translates to:
  /// **'{count}/{max} free'**
  String opponentsCountFree(int count, int max);

  /// No description provided for @opponentsCountPremium.
  ///
  /// In en, this message translates to:
  /// **'{count} tracked players'**
  String opponentsCountPremium(int count);

  /// No description provided for @opponentsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search opponents...'**
  String get opponentsSearchHint;

  /// No description provided for @opponentsLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Loading opponents...'**
  String get opponentsLoadingMessage;

  /// No description provided for @opponentsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get opponentsNoResults;

  /// No description provided for @opponentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Opponents Yet'**
  String get opponentsEmptyTitle;

  /// No description provided for @opponentsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Opponents to track their playing styles and statistics'**
  String get opponentsEmptySubtitle;

  /// No description provided for @opponentsEmptySearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get opponentsEmptySearchSubtitle;

  /// No description provided for @opponentsAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Opponent'**
  String get opponentsAddButton;

  /// No description provided for @opponentsLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last Seen: {date}'**
  String opponentsLastSeen(String date);

  /// No description provided for @opponentsHands.
  ///
  /// In en, this message translates to:
  /// **'Hands'**
  String get opponentsHands;

  /// No description provided for @opponentsEditMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit Opponent'**
  String get opponentsEditMenu;

  /// No description provided for @opponentsDeleteMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete Opponent'**
  String get opponentsDeleteMenu;

  /// No description provided for @opponentsAddDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Opponent'**
  String get opponentsAddDialogTitle;

  /// No description provided for @opponentsEditDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Opponent'**
  String get opponentsEditDialogTitle;

  /// No description provided for @opponentsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Opponent Name'**
  String get opponentsNameHint;

  /// No description provided for @opponentsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get opponentsNotesHint;

  /// No description provided for @opponentsPickColor.
  ///
  /// In en, this message translates to:
  /// **'Pick a color'**
  String get opponentsPickColor;

  /// No description provided for @opponentsAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Opponent added successfully'**
  String get opponentsAddedSuccess;

  /// No description provided for @opponentAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'An opponent named \"{name}\" already exists'**
  String opponentAlreadyExists(String name);

  /// No description provided for @opponentsUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Opponent updated successfully'**
  String get opponentsUpdatedSuccess;

  /// No description provided for @opponentsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete opponent?'**
  String get opponentsDeleteConfirmTitle;

  /// No description provided for @opponentsDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?\nThis action cannot be undone'**
  String opponentsDeleteConfirmMessage(String name);

  /// No description provided for @opponentsDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Opponent deleted successfully'**
  String get opponentsDeletedSuccess;

  /// No description provided for @opponentsAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Opponent Analytics'**
  String get opponentsAnalyticsTitle;

  /// No description provided for @opponentsAnalyticsTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Opponents'**
  String get opponentsAnalyticsTotalLabel;

  /// No description provided for @opponentsAnalyticsHandsTracked.
  ///
  /// In en, this message translates to:
  /// **'Total Hands Tracked'**
  String get opponentsAnalyticsHandsTracked;

  /// No description provided for @opponentsAnalyticsAverage.
  ///
  /// In en, this message translates to:
  /// **'Average Hands/Opponent'**
  String get opponentsAnalyticsAverage;

  /// No description provided for @opponentsAnalyticsMostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most Played Against'**
  String get opponentsAnalyticsMostPlayed;

  /// No description provided for @opponentsAnalyticsDistribution.
  ///
  /// In en, this message translates to:
  /// **'Player Type Distribution:'**
  String get opponentsAnalyticsDistribution;

  /// No description provided for @opponentsClearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Opponents?'**
  String get opponentsClearAllTitle;

  /// No description provided for @opponentsClearAllMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all opponent data. This action cannot be undone!'**
  String get opponentsClearAllMessage;

  /// No description provided for @opponentsClearAllButton.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get opponentsClearAllButton;

  /// No description provided for @opponentsClearedSuccess.
  ///
  /// In en, this message translates to:
  /// **'All opponents cleared'**
  String get opponentsClearedSuccess;

  /// No description provided for @setupSessionSetup.
  ///
  /// In en, this message translates to:
  /// **'Session Setup'**
  String get setupSessionSetup;

  /// No description provided for @setupSessionName.
  ///
  /// In en, this message translates to:
  /// **'Session Name'**
  String get setupSessionName;

  /// No description provided for @setupSessionNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"Friday Night Poker\"'**
  String get setupSessionNameHint;

  /// No description provided for @setupGameType.
  ///
  /// In en, this message translates to:
  /// **'Game Type'**
  String get setupGameType;

  /// No description provided for @setupCashGame.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get setupCashGame;

  /// No description provided for @setupTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get setupTournament;

  /// No description provided for @setupSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get setupSmallBlind;

  /// No description provided for @setupBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get setupBigBlind;

  /// No description provided for @setupBuyInAmount.
  ///
  /// In en, this message translates to:
  /// **'Buy-in Amount'**
  String get setupBuyInAmount;

  /// No description provided for @setupEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get setupEnterAmount;

  /// No description provided for @setupStartingStackEqualsBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Starting stack equals your buy-in.'**
  String get setupStartingStackEqualsBuyIn;

  /// No description provided for @setupStartingStack.
  ///
  /// In en, this message translates to:
  /// **'Starting Stack'**
  String get setupStartingStack;

  /// No description provided for @setupEnterChipStack.
  ///
  /// In en, this message translates to:
  /// **'Enter chip stack'**
  String get setupEnterChipStack;

  /// No description provided for @setupMustBeAtLeastBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Must be at least the Big Blind ({bigBlind})'**
  String setupMustBeAtLeastBigBlind(int bigBlind);

  /// No description provided for @setupBbAnte.
  ///
  /// In en, this message translates to:
  /// **'BB Ante'**
  String get setupBbAnte;

  /// No description provided for @setupTableSection.
  ///
  /// In en, this message translates to:
  /// **'TABLE'**
  String get setupTableSection;

  /// No description provided for @setupTableInstructions.
  ///
  /// In en, this message translates to:
  /// **'Tap a seat to add a player. Drag the button to set dealer.'**
  String get setupTableInstructions;

  /// No description provided for @setupStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get setupStartSession;

  /// No description provided for @setupMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get setupMe;

  /// No description provided for @setupPlayerSeat.
  ///
  /// In en, this message translates to:
  /// **'Player {seatNumber}'**
  String setupPlayerSeat(int seatNumber);

  /// No description provided for @setupHero.
  ///
  /// In en, this message translates to:
  /// **'Hero'**
  String get setupHero;

  /// No description provided for @homeLoadingPokerData.
  ///
  /// In en, this message translates to:
  /// **'Loading your poker data...'**
  String get homeLoadingPokerData;

  /// No description provided for @homeWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get homeWelcomeBack;

  /// No description provided for @homeNoActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get homeNoActiveSessions;

  /// No description provided for @homeLiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Live Sessions'**
  String get homeLiveSessions;

  /// No description provided for @homeClubNotFound.
  ///
  /// In en, this message translates to:
  /// **'Club not found'**
  String get homeClubNotFound;

  /// No description provided for @homeEventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get homeEventNotFound;

  /// No description provided for @homeRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get homeRecentActivity;

  /// No description provided for @homeWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win Rate'**
  String get homeWinRate;

  /// No description provided for @homeHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get homeHours;

  /// No description provided for @homePlayStyle.
  ///
  /// In en, this message translates to:
  /// **'Play Style'**
  String get homePlayStyle;

  /// No description provided for @homePlayStyleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Your play style will be detected after logging 50 preflop hands.'**
  String get homePlayStyleTooltip;

  /// No description provided for @homeBankroll.
  ///
  /// In en, this message translates to:
  /// **'Bankroll'**
  String get homeBankroll;

  /// No description provided for @homeBankrollOfGoal.
  ///
  /// In en, this message translates to:
  /// **'{current} of {goal}'**
  String homeBankrollOfGoal(String current, String goal);

  /// No description provided for @homeAmountLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String homeAmountLeft(String amount);

  /// No description provided for @homeEarnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get homeEarnings;

  /// No description provided for @homeAvgAmount.
  ///
  /// In en, this message translates to:
  /// **'Avg {amount}'**
  String homeAvgAmount(String amount);

  /// No description provided for @homeNoEarningsDataYet.
  ///
  /// In en, this message translates to:
  /// **'No earnings data yet'**
  String get homeNoEarningsDataYet;

  /// No description provided for @homeRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent Sessions'**
  String get homeRecentSessions;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeViewAll;

  /// No description provided for @homeNoRecentSessions.
  ///
  /// In en, this message translates to:
  /// **'No recent sessions'**
  String get homeNoRecentSessions;

  /// No description provided for @homeStartFirstSession.
  ///
  /// In en, this message translates to:
  /// **'Start your first poker session!'**
  String get homeStartFirstSession;

  /// No description provided for @homeAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get homeAddNew;

  /// No description provided for @homeUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Events'**
  String get homeUpcomingEvents;

  /// No description provided for @homeNoRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'No recent events'**
  String get homeNoRecentEvents;

  /// No description provided for @homeAddFirstEvent.
  ///
  /// In en, this message translates to:
  /// **'Add your first poker event!'**
  String get homeAddFirstEvent;

  /// No description provided for @homePlayersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Players'**
  String homePlayersCount(int count);

  /// No description provided for @homeGoingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} going'**
  String homeGoingCount(int count);

  /// No description provided for @homePrivateGame.
  ///
  /// In en, this message translates to:
  /// **'Private Game'**
  String get homePrivateGame;

  /// No description provided for @homeHomeGame.
  ///
  /// In en, this message translates to:
  /// **'Home Game'**
  String get homeHomeGame;

  /// No description provided for @homeOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get homeOnline;

  /// No description provided for @homeEditEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get homeEditEvent;

  /// No description provided for @homeDeleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get homeDeleteEvent;

  /// No description provided for @homeEventName.
  ///
  /// In en, this message translates to:
  /// **'Event Name'**
  String get homeEventName;

  /// No description provided for @homeLocationVenue.
  ///
  /// In en, this message translates to:
  /// **'Location/Venue'**
  String get homeLocationVenue;

  /// No description provided for @homeBuyInAmount.
  ///
  /// In en, this message translates to:
  /// **'Buy in amount'**
  String get homeBuyInAmount;

  /// No description provided for @homeSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date:'**
  String get homeSelectDate;

  /// No description provided for @homeSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get homeSaveChanges;

  /// No description provided for @homeDeleteEventConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {eventName}?'**
  String homeDeleteEventConfirm(String eventName);

  /// No description provided for @homeDeleteEventDescription.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{eventName}\"?'**
  String homeDeleteEventDescription(String eventName);

  /// No description provided for @homeEventDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Event deleted successfully'**
  String get homeEventDeletedSuccessfully;

  /// No description provided for @homeClubInvitation.
  ///
  /// In en, this message translates to:
  /// **'Club Invitation'**
  String get homeClubInvitation;

  /// No description provided for @homeYouveBeenInvitedToJoin.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to join'**
  String get homeYouveBeenInvitedToJoin;

  /// No description provided for @homeDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get homeDecline;

  /// No description provided for @homeAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get homeAccept;

  /// No description provided for @homeInvitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation Declined'**
  String get homeInvitationDeclined;

  /// No description provided for @homeInvitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invitation Accepted'**
  String get homeInvitationAccepted;

  /// No description provided for @homeClubInvitations.
  ///
  /// In en, this message translates to:
  /// **'Club Invitations'**
  String get homeClubInvitations;

  /// No description provided for @homeLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get homeLater;

  /// No description provided for @homeViewInvitations.
  ///
  /// In en, this message translates to:
  /// **'View Invitations'**
  String get homeViewInvitations;

  /// No description provided for @homeNoEarningsDataTitle.
  ///
  /// In en, this message translates to:
  /// **'No Earnings Data Yet'**
  String get homeNoEarningsDataTitle;

  /// No description provided for @homeNoEarningsDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Add some session results first to view your earnings chart. You can add results from the Profile page.'**
  String get homeNoEarningsDataDescription;

  /// No description provided for @handHandNumber.
  ///
  /// In en, this message translates to:
  /// **'Hand #{number}'**
  String handHandNumber(int number);

  /// No description provided for @handFreeCounter.
  ///
  /// In en, this message translates to:
  /// **'{used}/{max} free'**
  String handFreeCounter(int used, int max);

  /// No description provided for @handAvgPill.
  ///
  /// In en, this message translates to:
  /// **'{ratio} avg'**
  String handAvgPill(String ratio);

  /// No description provided for @handNextHand.
  ///
  /// In en, this message translates to:
  /// **'Next Hand'**
  String get handNextHand;

  /// No description provided for @handFoldedToMe.
  ///
  /// In en, this message translates to:
  /// **'Folded to me'**
  String get handFoldedToMe;

  /// No description provided for @handUndoLastAction.
  ///
  /// In en, this message translates to:
  /// **'Undo Last Action'**
  String get handUndoLastAction;

  /// No description provided for @handAllInHand.
  ///
  /// In en, this message translates to:
  /// **'ALL IN HAND'**
  String get handAllInHand;

  /// No description provided for @handPot.
  ///
  /// In en, this message translates to:
  /// **'Pot'**
  String get handPot;

  /// No description provided for @handStack.
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get handStack;

  /// No description provided for @handToAct.
  ///
  /// In en, this message translates to:
  /// **'To Act'**
  String get handToAct;

  /// No description provided for @handToActYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get handToActYou;

  /// No description provided for @handStopSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop Session?'**
  String get handStopSessionTitle;

  /// No description provided for @handStopSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop this session? All hands will be saved.'**
  String get handStopSessionMessage;

  /// No description provided for @handStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get handStop;

  /// No description provided for @handChangeTable.
  ///
  /// In en, this message translates to:
  /// **'Change Table'**
  String get handChangeTable;

  /// No description provided for @handBlinds.
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get handBlinds;

  /// No description provided for @handTakesEffectNextHand.
  ///
  /// In en, this message translates to:
  /// **'Takes effect next hand'**
  String get handTakesEffectNextHand;

  /// No description provided for @handLeaveSession.
  ///
  /// In en, this message translates to:
  /// **'Leave Session?'**
  String get handLeaveSession;

  /// No description provided for @handSaveAndExit.
  ///
  /// In en, this message translates to:
  /// **'Save & Exit'**
  String get handSaveAndExit;

  /// No description provided for @handDiscardAndExit.
  ///
  /// In en, this message translates to:
  /// **'Discard & Exit'**
  String get handDiscardAndExit;

  /// No description provided for @handInProgress.
  ///
  /// In en, this message translates to:
  /// **'Hand in Progress'**
  String get handInProgress;

  /// No description provided for @handDiscardCurrentHand.
  ///
  /// In en, this message translates to:
  /// **'You have an active hand being logged. Discard it and go back?'**
  String get handDiscardCurrentHand;

  /// No description provided for @handDiscardHand.
  ///
  /// In en, this message translates to:
  /// **'Discard Hand'**
  String get handDiscardHand;

  /// No description provided for @handAdjustStack.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stack'**
  String get handAdjustStack;

  /// No description provided for @handEnterStackAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter stack amount'**
  String get handEnterStackAmount;

  /// No description provided for @handGestureGuide.
  ///
  /// In en, this message translates to:
  /// **'Gesture Guide'**
  String get handGestureGuide;

  /// No description provided for @handManagePlayers.
  ///
  /// In en, this message translates to:
  /// **'Manage Players'**
  String get handManagePlayers;

  /// No description provided for @handStopSession.
  ///
  /// In en, this message translates to:
  /// **'Stop Session'**
  String get handStopSession;

  /// No description provided for @handRebuy.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get handRebuy;

  /// No description provided for @handGestures.
  ///
  /// In en, this message translates to:
  /// **'Gestures'**
  String get handGestures;

  /// No description provided for @handGestureTap.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get handGestureTap;

  /// No description provided for @handGestureCheckCall.
  ///
  /// In en, this message translates to:
  /// **'Check / Call'**
  String get handGestureCheckCall;

  /// No description provided for @handGestureSwipeOut.
  ///
  /// In en, this message translates to:
  /// **'Swipe Out'**
  String get handGestureSwipeOut;

  /// No description provided for @handGestureSwipeUp.
  ///
  /// In en, this message translates to:
  /// **'Swipe Up'**
  String get handGestureSwipeUp;

  /// No description provided for @handGestureBetRaise.
  ///
  /// In en, this message translates to:
  /// **'Bet / Raise'**
  String get handGestureBetRaise;

  /// No description provided for @handStreetComplete.
  ///
  /// In en, this message translates to:
  /// **'Street Complete'**
  String get handStreetComplete;

  /// No description provided for @handWinsThePot.
  ///
  /// In en, this message translates to:
  /// **'wins the pot'**
  String get handWinsThePot;

  /// No description provided for @handHandComplete.
  ///
  /// In en, this message translates to:
  /// **'Hand Complete'**
  String get handHandComplete;

  /// No description provided for @handTapToContinue.
  ///
  /// In en, this message translates to:
  /// **'Tap to continue'**
  String get handTapToContinue;

  /// No description provided for @handRaiseAmount.
  ///
  /// In en, this message translates to:
  /// **'Raise Amount'**
  String get handRaiseAmount;

  /// No description provided for @handBetAmount.
  ///
  /// In en, this message translates to:
  /// **'Bet Amount'**
  String get handBetAmount;

  /// No description provided for @handPleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get handPleaseEnterValidNumber;

  /// No description provided for @handConfirmRebuy.
  ///
  /// In en, this message translates to:
  /// **'Confirm Rebuy'**
  String get handConfirmRebuy;

  /// No description provided for @handRebuyReplaceStack.
  ///
  /// In en, this message translates to:
  /// **'Proceeding with a rebuy will replace your current stack. Are you sure you want to continue?'**
  String get handRebuyReplaceStack;

  /// No description provided for @handProceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get handProceed;

  /// No description provided for @handEnterRebuyDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter rebuy details for the tournament'**
  String get handEnterRebuyDetails;

  /// No description provided for @handRebuyAmount.
  ///
  /// In en, this message translates to:
  /// **'Rebuy Amount'**
  String get handRebuyAmount;

  /// No description provided for @handNewStackSize.
  ///
  /// In en, this message translates to:
  /// **'New Stack Size'**
  String get handNewStackSize;

  /// No description provided for @handChipCountAfterRebuy.
  ///
  /// In en, this message translates to:
  /// **'Chip count after rebuy'**
  String get handChipCountAfterRebuy;

  /// No description provided for @handSessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String get handSessionInfo;

  /// No description provided for @handTotalInvested.
  ///
  /// In en, this message translates to:
  /// **'Total Invested: {amount}'**
  String handTotalInvested(String amount);

  /// No description provided for @handRebuysCount.
  ///
  /// In en, this message translates to:
  /// **'Rebuys: {count}'**
  String handRebuysCount(int count);

  /// No description provided for @handAddRebuy.
  ///
  /// In en, this message translates to:
  /// **'Add Rebuy'**
  String get handAddRebuy;

  /// No description provided for @handPleaseEnterValidAmounts.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid amounts'**
  String get handPleaseEnterValidAmounts;

  /// No description provided for @handHandInProgress.
  ///
  /// In en, this message translates to:
  /// **'Hand in Progress'**
  String get handHandInProgress;

  /// No description provided for @handHandInProgressMessage.
  ///
  /// In en, this message translates to:
  /// **'There\'s a hand in progress. Moving to the next hand will discard all actions and restore player stacks.'**
  String get handHandInProgressMessage;

  /// No description provided for @handMoveToNextHand.
  ///
  /// In en, this message translates to:
  /// **'Move to Next Hand'**
  String get handMoveToNextHand;

  /// No description provided for @handMainPot.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get handMainPot;

  /// No description provided for @handSidePot.
  ///
  /// In en, this message translates to:
  /// **'Side {index}'**
  String handSidePot(int index);

  /// No description provided for @handPokerSession.
  ///
  /// In en, this message translates to:
  /// **'Poker Session'**
  String get handPokerSession;

  /// No description provided for @handActionsHandNumber.
  ///
  /// In en, this message translates to:
  /// **'Hand #{number}'**
  String handActionsHandNumber(String number);

  /// No description provided for @handActionsPosition.
  ///
  /// In en, this message translates to:
  /// **'Position: {position}'**
  String handActionsPosition(String position);

  /// No description provided for @handActionsShareHand.
  ///
  /// In en, this message translates to:
  /// **'Share Hand'**
  String get handActionsShareHand;

  /// No description provided for @handActionsShowHoleCards.
  ///
  /// In en, this message translates to:
  /// **'Show hole cards'**
  String get handActionsShowHoleCards;

  /// No description provided for @handActionsShowHoleCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your cards will be visible in the shared link'**
  String get handActionsShowHoleCardsSubtitle;

  /// No description provided for @handActionsHideHoleCards.
  ///
  /// In en, this message translates to:
  /// **'Hide hole cards'**
  String get handActionsHideHoleCards;

  /// No description provided for @handActionsHideHoleCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your cards will be hidden from the shared link'**
  String get handActionsHideHoleCardsSubtitle;

  /// No description provided for @handActionsShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Check out this hand on Final Table!'**
  String get handActionsShareMessage;

  /// No description provided for @handActionsShareSubject.
  ///
  /// In en, this message translates to:
  /// **'Poker Hand #{number}'**
  String handActionsShareSubject(String number);

  /// No description provided for @handActionsFailedToShareHand.
  ///
  /// In en, this message translates to:
  /// **'Failed to share hand'**
  String get handActionsFailedToShareHand;

  /// No description provided for @handActionsGeneratingExport.
  ///
  /// In en, this message translates to:
  /// **'Generating PokerStars export...'**
  String get handActionsGeneratingExport;

  /// No description provided for @handActionsExportedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Hand #{number} exported successfully!'**
  String handActionsExportedSuccessfully(String number);

  /// No description provided for @handActionsFailedToExport.
  ///
  /// In en, this message translates to:
  /// **'Failed to export hand: {error}'**
  String handActionsFailedToExport(String error);

  /// No description provided for @handActionsMissingHeroCards.
  ///
  /// In en, this message translates to:
  /// **'Missing Hero Cards'**
  String get handActionsMissingHeroCards;

  /// No description provided for @handActionsMissingHeroCardsMessage.
  ///
  /// In en, this message translates to:
  /// **'AI analysis requires your hole cards to be recorded. This hand cannot be analyzed because hero cards are missing.'**
  String get handActionsMissingHeroCardsMessage;

  /// No description provided for @handActionsYourCards.
  ///
  /// In en, this message translates to:
  /// **'Your Cards'**
  String get handActionsYourCards;

  /// No description provided for @handActionsOpponentCards.
  ///
  /// In en, this message translates to:
  /// **'Opponent Cards'**
  String get handActionsOpponentCards;

  /// No description provided for @handActionsPlayerSeat.
  ///
  /// In en, this message translates to:
  /// **'Player {id}'**
  String handActionsPlayerSeat(int id);

  /// No description provided for @handActionsPot.
  ///
  /// In en, this message translates to:
  /// **'POT'**
  String get handActionsPot;

  /// No description provided for @handActionsBlinds.
  ///
  /// In en, this message translates to:
  /// **'BLINDS'**
  String get handActionsBlinds;

  /// No description provided for @handActionsWinner.
  ///
  /// In en, this message translates to:
  /// **'WINNER'**
  String get handActionsWinner;

  /// No description provided for @handActionsPlayersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String handActionsPlayersCount(int count);

  /// No description provided for @handActionsActionSummary.
  ///
  /// In en, this message translates to:
  /// **'Action Summary'**
  String get handActionsActionSummary;

  /// No description provided for @handActionsPreflop.
  ///
  /// In en, this message translates to:
  /// **'PREFLOP'**
  String get handActionsPreflop;

  /// No description provided for @handActionsBoard.
  ///
  /// In en, this message translates to:
  /// **'BOARD'**
  String get handActionsBoard;

  /// No description provided for @handActionsPlayer.
  ///
  /// In en, this message translates to:
  /// **'PLAYER'**
  String get handActionsPlayer;

  /// No description provided for @handActionsStack.
  ///
  /// In en, this message translates to:
  /// **'STACK'**
  String get handActionsStack;

  /// No description provided for @handActionsAction.
  ///
  /// In en, this message translates to:
  /// **'ACTION'**
  String get handActionsAction;

  /// No description provided for @handActionsAmount.
  ///
  /// In en, this message translates to:
  /// **'AMT'**
  String get handActionsAmount;

  /// No description provided for @handActionsYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get handActionsYou;

  /// No description provided for @handActionsAllIn.
  ///
  /// In en, this message translates to:
  /// **'ALL IN'**
  String get handActionsAllIn;

  /// No description provided for @handActionsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get handActionsNotes;

  /// No description provided for @handActionsAnalyzingHand.
  ///
  /// In en, this message translates to:
  /// **'Analyzing Hand...'**
  String get handActionsAnalyzingHand;

  /// No description provided for @handActionsHeroCardsMissing.
  ///
  /// In en, this message translates to:
  /// **'Hero Cards Missing'**
  String get handActionsHeroCardsMissing;

  /// No description provided for @handActionsUnlockAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Unlock AI Analysis'**
  String get handActionsUnlockAiAnalysis;

  /// No description provided for @handActionsAnalysisComplete.
  ///
  /// In en, this message translates to:
  /// **'Analysis Complete'**
  String get handActionsAnalysisComplete;

  /// No description provided for @handActionsAiAnalyzerBeta.
  ///
  /// In en, this message translates to:
  /// **'AI Analyzer (beta)'**
  String get handActionsAiAnalyzerBeta;

  /// No description provided for @handActionsAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis Failed'**
  String get handActionsAnalysisFailed;

  /// No description provided for @handActionsAiAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI Analysis'**
  String get handActionsAiAnalysis;

  /// No description provided for @handActionsStreetByStreetBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Street-by-Street Breakdown'**
  String get handActionsStreetByStreetBreakdown;

  /// No description provided for @handActionsAnalysisCompletedIn.
  ///
  /// In en, this message translates to:
  /// **'Analysis completed in {time}s'**
  String handActionsAnalysisCompletedIn(String time);

  /// No description provided for @handActionsFailedToUpdateStar.
  ///
  /// In en, this message translates to:
  /// **'Failed to update star status'**
  String get handActionsFailedToUpdateStar;

  /// No description provided for @handActionsPotAmount.
  ///
  /// In en, this message translates to:
  /// **'Pot: {amount}'**
  String handActionsPotAmount(String amount);

  /// No description provided for @opponentDetailHandsTracked.
  ///
  /// In en, this message translates to:
  /// **'{count} hands tracked'**
  String opponentDetailHandsTracked(int count);

  /// No description provided for @opponentDetailNoDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get opponentDetailNoDataYet;

  /// No description provided for @opponentDetailHands.
  ///
  /// In en, this message translates to:
  /// **'Hands'**
  String get opponentDetailHands;

  /// No description provided for @opponentDetailLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last Seen:'**
  String get opponentDetailLastSeen;

  /// No description provided for @opponentDetailNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get opponentDetailNotes;

  /// No description provided for @opponentDetailEditOpponent.
  ///
  /// In en, this message translates to:
  /// **'Edit Opponent'**
  String get opponentDetailEditOpponent;

  /// No description provided for @opponentDetailDeleteOpponent.
  ///
  /// In en, this message translates to:
  /// **'Delete Opponent'**
  String get opponentDetailDeleteOpponent;

  /// No description provided for @opponentDetailStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get opponentDetailStatistics;

  /// No description provided for @opponentDetailNoStatisticsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No statistics available'**
  String get opponentDetailNoStatisticsAvailable;

  /// No description provided for @opponentDetailStatsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Stats are based only on hands you logged together. VPIP is not tracked as unobserved folds would inflate it.'**
  String get opponentDetailStatsDisclaimer;

  /// No description provided for @opponentDetailAggressionFreq.
  ///
  /// In en, this message translates to:
  /// **'Aggression %'**
  String get opponentDetailAggressionFreq;

  /// No description provided for @opponentDetailShowdownPercent.
  ///
  /// In en, this message translates to:
  /// **'Showdown %'**
  String get opponentDetailShowdownPercent;

  /// No description provided for @opponentDetailHandHistory.
  ///
  /// In en, this message translates to:
  /// **'Hand History'**
  String get opponentDetailHandHistory;

  /// No description provided for @opponentDetailViewAllHands.
  ///
  /// In en, this message translates to:
  /// **'View all hands played with this opponent'**
  String get opponentDetailViewAllHands;

  /// No description provided for @opponentDetailViewHandHistory.
  ///
  /// In en, this message translates to:
  /// **'View Hand History'**
  String get opponentDetailViewHandHistory;

  /// No description provided for @opponentDetailNoHandsFound.
  ///
  /// In en, this message translates to:
  /// **'No Hands Found'**
  String get opponentDetailNoHandsFound;

  /// No description provided for @opponentDetailNoHandsMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t played any hands with \"{name}\" yet'**
  String opponentDetailNoHandsMessage(String name);

  /// No description provided for @opponentDetailOpponentName.
  ///
  /// In en, this message translates to:
  /// **'Opponent Name'**
  String get opponentDetailOpponentName;

  /// No description provided for @opponentDetailNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get opponentDetailNotesOptional;

  /// No description provided for @opponentDetailPickColor.
  ///
  /// In en, this message translates to:
  /// **'Pick a color'**
  String get opponentDetailPickColor;

  /// No description provided for @opponentDetailColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get opponentDetailColorRed;

  /// No description provided for @opponentDetailColorLightBlue.
  ///
  /// In en, this message translates to:
  /// **'Light Blue'**
  String get opponentDetailColorLightBlue;

  /// No description provided for @opponentDetailColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get opponentDetailColorGreen;

  /// No description provided for @opponentDetailColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get opponentDetailColorOrange;

  /// No description provided for @opponentDetailColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get opponentDetailColorPurple;

  /// No description provided for @opponentDetailColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get opponentDetailColorTeal;

  /// No description provided for @opponentDetailColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get opponentDetailColorPink;

  /// No description provided for @opponentDetailColorIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get opponentDetailColorIndigo;

  /// No description provided for @opponentDetailUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Opponent updated successfully'**
  String get opponentDetailUpdatedSuccessfully;

  /// No description provided for @opponentDetailDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete opponent?'**
  String get opponentDetailDeleteConfirmTitle;

  /// No description provided for @opponentDetailDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?\nThis action can not be undone'**
  String opponentDetailDeleteConfirmMessage(String name);

  /// No description provided for @opponentDetailDeletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Opponent deleted successfully'**
  String get opponentDetailDeletedSuccessfully;

  /// No description provided for @opponentDetailErrorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting opponent: {error}'**
  String opponentDetailErrorDeleting(String error);

  /// No description provided for @individualSessionCreatedLocally.
  ///
  /// In en, this message translates to:
  /// **'Session created locally. Will sync to cloud when connection is available.'**
  String get individualSessionCreatedLocally;

  /// No description provided for @individualUpdateCurrentStack.
  ///
  /// In en, this message translates to:
  /// **'Update Current Stack'**
  String get individualUpdateCurrentStack;

  /// No description provided for @individualCurrentStack.
  ///
  /// In en, this message translates to:
  /// **'Current Stack:'**
  String get individualCurrentStack;

  /// No description provided for @individualSetNewTotal.
  ///
  /// In en, this message translates to:
  /// **'Set New Total'**
  String get individualSetNewTotal;

  /// No description provided for @individualEnterNewTotalStack.
  ///
  /// In en, this message translates to:
  /// **'Enter new total stack'**
  String get individualEnterNewTotalStack;

  /// No description provided for @individualAddSubtractAmount.
  ///
  /// In en, this message translates to:
  /// **'Add/Subtract Amount'**
  String get individualAddSubtractAmount;

  /// No description provided for @individualAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get individualAmount;

  /// No description provided for @individualSetTotal.
  ///
  /// In en, this message translates to:
  /// **'Set Total'**
  String get individualSetTotal;

  /// No description provided for @individualNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get individualNoteLabel;

  /// No description provided for @individualNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Won big pot with AA'**
  String get individualNoteHint;

  /// No description provided for @individualTableAvgHint.
  ///
  /// In en, this message translates to:
  /// **'Table average (optional)'**
  String get individualTableAvgHint;

  /// No description provided for @individualUpdateBlinds.
  ///
  /// In en, this message translates to:
  /// **'Update Blinds'**
  String get individualUpdateBlinds;

  /// No description provided for @individualSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get individualSmallBlind;

  /// No description provided for @individualBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get individualBigBlind;

  /// No description provided for @individualBbMode.
  ///
  /// In en, this message translates to:
  /// **'BB Mode'**
  String get individualBbMode;

  /// No description provided for @individualCurrentStackLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Stack'**
  String get individualCurrentStackLabel;

  /// No description provided for @individualSessionInfo.
  ///
  /// In en, this message translates to:
  /// **'Session Info'**
  String get individualSessionInfo;

  /// No description provided for @individualStartingStack.
  ///
  /// In en, this message translates to:
  /// **'Starting Stack'**
  String get individualStartingStack;

  /// No description provided for @individualInitialBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Initial Buy-in'**
  String get individualInitialBuyIn;

  /// No description provided for @individualRebuys.
  ///
  /// In en, this message translates to:
  /// **'Rebuys'**
  String get individualRebuys;

  /// No description provided for @individualTotalInvested.
  ///
  /// In en, this message translates to:
  /// **'Total Invested'**
  String get individualTotalInvested;

  /// No description provided for @individualBlindsLabel.
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get individualBlindsLabel;

  /// No description provided for @individualHandsLogged.
  ///
  /// In en, this message translates to:
  /// **'Hands Logged'**
  String get individualHandsLogged;

  /// No description provided for @individualLogAHand.
  ///
  /// In en, this message translates to:
  /// **'Log a Hand'**
  String get individualLogAHand;

  /// No description provided for @individualGoBackToHand.
  ///
  /// In en, this message translates to:
  /// **'Go Back to Hand'**
  String get individualGoBackToHand;

  /// No description provided for @individualStackChart.
  ///
  /// In en, this message translates to:
  /// **'Stack Chart'**
  String get individualStackChart;

  /// No description provided for @individualCompleteHandToSee.
  ///
  /// In en, this message translates to:
  /// **'Complete a hand to see your stack trend'**
  String get individualCompleteHandToSee;

  /// No description provided for @individualStopSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop Session?'**
  String get individualStopSessionTitle;

  /// No description provided for @individualStopSessionMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop this session? All hands will be saved.'**
  String get individualStopSessionMessage;

  /// No description provided for @individualStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get individualStop;

  /// No description provided for @individualConfirmRebuy.
  ///
  /// In en, this message translates to:
  /// **'Confirm Rebuy'**
  String get individualConfirmRebuy;

  /// No description provided for @individualRebuyCurrentStack.
  ///
  /// In en, this message translates to:
  /// **'You currently have {stack} remaining.'**
  String individualRebuyCurrentStack(String stack);

  /// No description provided for @individualRebuyReplaceMessage.
  ///
  /// In en, this message translates to:
  /// **'Proceeding with a rebuy will replace your current stack. Are you sure you want to continue?'**
  String get individualRebuyReplaceMessage;

  /// No description provided for @individualProceedWithRebuy.
  ///
  /// In en, this message translates to:
  /// **'Proceed with Rebuy'**
  String get individualProceedWithRebuy;

  /// No description provided for @individualAddOn.
  ///
  /// In en, this message translates to:
  /// **'Add-on'**
  String get individualAddOn;

  /// No description provided for @individualAddOnDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter add-on amount to increase your total investment'**
  String get individualAddOnDescription;

  /// No description provided for @individualAddOnAmount.
  ///
  /// In en, this message translates to:
  /// **'Add-on Amount'**
  String get individualAddOnAmount;

  /// No description provided for @individualAddOnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get individualAddOnConfirm;

  /// No description provided for @individualAddOnDescriptionTournament.
  ///
  /// In en, this message translates to:
  /// **'Enter add-on price and chips received'**
  String get individualAddOnDescriptionTournament;

  /// No description provided for @individualAddOnPrice.
  ///
  /// In en, this message translates to:
  /// **'Add-on Price'**
  String get individualAddOnPrice;

  /// No description provided for @individualAddOnChips.
  ///
  /// In en, this message translates to:
  /// **'Chips Received'**
  String get individualAddOnChips;

  /// No description provided for @individualRebuy.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get individualRebuy;

  /// No description provided for @individualEnterRebuyAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter rebuy amount (stack will equal rebuy amount)'**
  String get individualEnterRebuyAmount;

  /// No description provided for @individualEnterRebuyAmountAndStack.
  ///
  /// In en, this message translates to:
  /// **'Enter rebuy amount and new stack size'**
  String get individualEnterRebuyAmountAndStack;

  /// No description provided for @individualRebuyAmount.
  ///
  /// In en, this message translates to:
  /// **'Rebuy Amount'**
  String get individualRebuyAmount;

  /// No description provided for @individualNewStackSize.
  ///
  /// In en, this message translates to:
  /// **'New Stack Size'**
  String get individualNewStackSize;

  /// No description provided for @individualChipCountAfterRebuy.
  ///
  /// In en, this message translates to:
  /// **'Chip count after rebuy'**
  String get individualChipCountAfterRebuy;

  /// No description provided for @individualTotalInvestedAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Invested: \${amount}'**
  String individualTotalInvestedAmount(String amount);

  /// No description provided for @individualCurrentStackAmount.
  ///
  /// In en, this message translates to:
  /// **'Current Stack: {stack}'**
  String individualCurrentStackAmount(String stack);

  /// No description provided for @individualRebuysCount.
  ///
  /// In en, this message translates to:
  /// **'Rebuys: {count}'**
  String individualRebuysCount(int count);

  /// No description provided for @individualAddRebuy.
  ///
  /// In en, this message translates to:
  /// **'Add Rebuy'**
  String get individualAddRebuy;

  /// No description provided for @individualPleaseEnterValidRebuy.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid rebuy amount'**
  String get individualPleaseEnterValidRebuy;

  /// No description provided for @individualPleaseEnterValidStack.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid stack size'**
  String get individualPleaseEnterValidStack;

  /// No description provided for @individualRebuyAddedSimple.
  ///
  /// In en, this message translates to:
  /// **'Rebuy added: \${amount}'**
  String individualRebuyAddedSimple(String amount);

  /// No description provided for @individualRebuyAddedWithStack.
  ///
  /// In en, this message translates to:
  /// **'Rebuy added: \${amount} (Stack: {stack})'**
  String individualRebuyAddedWithStack(String amount, String stack);

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Final Table'**
  String get authWelcome;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get authDisplayName;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authPleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authPleaseEnterEmail;

  /// No description provided for @authPleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authPleaseEnterValidEmail;

  /// No description provided for @authPleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authPleaseEnterPassword;

  /// No description provided for @authPleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authPleaseEnterName;

  /// No description provided for @authNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get authNameMinLength;

  /// No description provided for @authPleaseEnterAPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get authPleaseEnterAPassword;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authPleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get authPleaseConfirmPassword;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authForgotPassword;

  /// No description provided for @authResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPassword;

  /// No description provided for @authResetPasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address to receive a password reset link.'**
  String get authResetPasswordMessage;

  /// No description provided for @authSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get authSendResetLink;

  /// No description provided for @authPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent!'**
  String get authPasswordResetSent;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get paywallRestore;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'FINAL TABLE PREMIUM'**
  String get paywallTitle;

  /// No description provided for @paywallAvailablePlans.
  ///
  /// In en, this message translates to:
  /// **'Available plans'**
  String get paywallAvailablePlans;

  /// No description provided for @paywallStepLabel.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 2'**
  String get paywallStepLabel;

  /// No description provided for @paywallChooseYourPlan.
  ///
  /// In en, this message translates to:
  /// **'Choose your plan'**
  String get paywallChooseYourPlan;

  /// No description provided for @paywallUpgradeOrCancel.
  ///
  /// In en, this message translates to:
  /// **'Upgrade or cancel at any time'**
  String get paywallUpgradeOrCancel;

  /// No description provided for @paywallContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get paywallContinue;

  /// No description provided for @paywallUnlockFeature.
  ///
  /// In en, this message translates to:
  /// **'Unlock {featureName}'**
  String paywallUnlockFeature(String featureName);

  /// No description provided for @paywallGoPremium.
  ///
  /// In en, this message translates to:
  /// **'Go Premium'**
  String get paywallGoPremium;

  /// No description provided for @paywallFeatureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This feature is part of Final Table Premium. Pick a plan that fits how you play.'**
  String get paywallFeatureSubtitle;

  /// No description provided for @paywallGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock everything Final Table has to offer. Track more hands, analyze your game, run your club.'**
  String get paywallGeneralSubtitle;

  /// No description provided for @paywallProTier.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get paywallProTier;

  /// No description provided for @paywallFreeTrialBadge.
  ///
  /// In en, this message translates to:
  /// **'7-Day Free Trial'**
  String get paywallFreeTrialBadge;

  /// No description provided for @paywallProDescription.
  ///
  /// In en, this message translates to:
  /// **'Everything you need to master your game.'**
  String get paywallProDescription;

  /// No description provided for @paywallUnlimitedHandLogging.
  ///
  /// In en, this message translates to:
  /// **'Unlimited hand logging'**
  String get paywallUnlimitedHandLogging;

  /// No description provided for @paywallFullSessionHistory.
  ///
  /// In en, this message translates to:
  /// **'Full session history'**
  String get paywallFullSessionHistory;

  /// No description provided for @paywallAiHandAnalysis.
  ///
  /// In en, this message translates to:
  /// **'AI hand analysis'**
  String get paywallAiHandAnalysis;

  /// No description provided for @paywallExportHandsCsv.
  ///
  /// In en, this message translates to:
  /// **'Export hands to CSV'**
  String get paywallExportHandsCsv;

  /// No description provided for @paywallProMonthly.
  ///
  /// In en, this message translates to:
  /// **'\$19.99/month'**
  String get paywallProMonthly;

  /// No description provided for @paywallProYearly.
  ///
  /// In en, this message translates to:
  /// **'or \$199.99/year. Save about 25%**'**
  String get paywallProYearly;

  /// No description provided for @paywallStartFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Start 7-Day Free Trial'**
  String get paywallStartFreeTrial;

  /// No description provided for @paywallEliteTier.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get paywallEliteTier;

  /// No description provided for @paywallEliteDescription.
  ///
  /// In en, this message translates to:
  /// **'Take your game to the next level.'**
  String get paywallEliteDescription;

  /// No description provided for @paywallEverythingInProElite.
  ///
  /// In en, this message translates to:
  /// **'Everything in Pro'**
  String get paywallEverythingInProElite;

  /// No description provided for @paywallEliteFeature1.
  ///
  /// In en, this message translates to:
  /// **'Advanced opponent profiling'**
  String get paywallEliteFeature1;

  /// No description provided for @paywallEliteFeature2.
  ///
  /// In en, this message translates to:
  /// **'Detailed session analytics'**
  String get paywallEliteFeature2;

  /// No description provided for @paywallEliteFeature3.
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get paywallEliteFeature3;

  /// No description provided for @paywallEliteMonthly.
  ///
  /// In en, this message translates to:
  /// **'\$29.99/month'**
  String get paywallEliteMonthly;

  /// No description provided for @paywallEliteYearly.
  ///
  /// In en, this message translates to:
  /// **'or \$199.99/year. Save about 25%**'**
  String get paywallEliteYearly;

  /// No description provided for @paywallGetElite.
  ///
  /// In en, this message translates to:
  /// **'Get Elite'**
  String get paywallGetElite;

  /// No description provided for @paywallClubTier.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get paywallClubTier;

  /// No description provided for @paywallClubDescription.
  ///
  /// In en, this message translates to:
  /// **'For home games, clubs, and live venues.'**
  String get paywallClubDescription;

  /// No description provided for @paywallEverythingInPro.
  ///
  /// In en, this message translates to:
  /// **'Everything in Pro'**
  String get paywallEverythingInPro;

  /// No description provided for @paywallClubManagement.
  ///
  /// In en, this message translates to:
  /// **'Club management & member roles'**
  String get paywallClubManagement;

  /// No description provided for @paywallLiveDealerVoice.
  ///
  /// In en, this message translates to:
  /// **'Live dealer voice logging'**
  String get paywallLiveDealerVoice;

  /// No description provided for @paywallMultiTableEvents.
  ///
  /// In en, this message translates to:
  /// **'Multi-table events with rankings'**
  String get paywallMultiTableEvents;

  /// No description provided for @paywallClubMonthly.
  ///
  /// In en, this message translates to:
  /// **'\$39.99/month'**
  String get paywallClubMonthly;

  /// No description provided for @paywallClubYearly.
  ///
  /// In en, this message translates to:
  /// **'or \$199.99/year. Save about 25%**'**
  String get paywallClubYearly;

  /// No description provided for @paywallGetClub.
  ///
  /// In en, this message translates to:
  /// **'Get Club'**
  String get paywallGetClub;

  /// No description provided for @paywallDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions auto-renew. After your free trial, you\'ll be charged the listed price unless you cancel at least 24 hours before the period ends. Cancel anytime in your account settings.'**
  String get paywallDisclaimer;

  /// No description provided for @paywallTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get paywallTerms;

  /// No description provided for @paywallPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get paywallPrivacy;

  /// No description provided for @paywallPurchasesRestored.
  ///
  /// In en, this message translates to:
  /// **'Purchases restored'**
  String get paywallPurchasesRestored;

  /// No description provided for @paywallNoPreviousPurchases.
  ///
  /// In en, this message translates to:
  /// **'No previous purchases found'**
  String get paywallNoPreviousPurchases;

  /// No description provided for @paywallWelcomePro.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Pro!'**
  String get paywallWelcomePro;

  /// No description provided for @paywallPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get paywallPurchaseFailed;

  /// No description provided for @paywallSubscriptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Subscription options unavailable. Please try again.'**
  String get paywallSubscriptionUnavailable;

  /// No description provided for @paywallMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get paywallMonthly;

  /// No description provided for @paywallAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual'**
  String get paywallAnnual;

  /// No description provided for @paywallAnnualSave.
  ///
  /// In en, this message translates to:
  /// **'Annual (Save ~40%)'**
  String get paywallAnnualSave;

  /// No description provided for @paywallComingSoon.
  ///
  /// In en, this message translates to:
  /// **'{tier} subscriptions coming soon'**
  String paywallComingSoon(String tier);

  /// No description provided for @trialConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'The first 7 days of {tier} are on us'**
  String trialConfirmTitle(String tier);

  /// No description provided for @trialConfirmTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get trialConfirmTodayTitle;

  /// No description provided for @trialConfirmTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Get full access to all {tier} features'**
  String trialConfirmTodayBody(String tier);

  /// No description provided for @trialConfirmReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'In 5 days'**
  String get trialConfirmReminderTitle;

  /// No description provided for @trialConfirmReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Get a reminder before your free trial ends'**
  String get trialConfirmReminderBody;

  /// No description provided for @trialConfirmStartTitle.
  ///
  /// In en, this message translates to:
  /// **'In 7 days'**
  String get trialConfirmStartTitle;

  /// No description provided for @trialConfirmStartBody.
  ///
  /// In en, this message translates to:
  /// **'Your subscription starts, unless you cancel anytime before'**
  String get trialConfirmStartBody;

  /// No description provided for @trialConfirmPriceSummary.
  ///
  /// In en, this message translates to:
  /// **'Try 7 days free, then'**
  String get trialConfirmPriceSummary;

  /// No description provided for @trialConfirmStartCta.
  ///
  /// In en, this message translates to:
  /// **'Start my 7-day free trial'**
  String get trialConfirmStartCta;

  /// No description provided for @trialConfirmDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'No charges yet. Cancel anytime on the App Store.'**
  String get trialConfirmDisclaimer;

  /// No description provided for @introGameSetup.
  ///
  /// In en, this message translates to:
  /// **'Game Setup'**
  String get introGameSetup;

  /// No description provided for @introConfigureSession.
  ///
  /// In en, this message translates to:
  /// **'Configure your session'**
  String get introConfigureSession;

  /// No description provided for @introSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get introSmallBlind;

  /// No description provided for @introBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get introBigBlind;

  /// No description provided for @introPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get introPlayers;

  /// No description provided for @introGameType.
  ///
  /// In en, this message translates to:
  /// **'Game Type'**
  String get introGameType;

  /// No description provided for @introBbAnte.
  ///
  /// In en, this message translates to:
  /// **'BB Ante'**
  String get introBbAnte;

  /// No description provided for @introBbAnteDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable big blind ante rule'**
  String get introBbAnteDescription;

  /// No description provided for @introStartGame.
  ///
  /// In en, this message translates to:
  /// **'START GAME'**
  String get introStartGame;

  /// No description provided for @introStartingSession.
  ///
  /// In en, this message translates to:
  /// **'Starting your poker session...'**
  String get introStartingSession;

  /// No description provided for @introEnterField.
  ///
  /// In en, this message translates to:
  /// **'Enter {title}'**
  String introEnterField(String title);

  /// No description provided for @introEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get introEnterAmount;

  /// No description provided for @introPleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid positive number'**
  String get introPleaseEnterValidNumber;

  /// No description provided for @introRingGame.
  ///
  /// In en, this message translates to:
  /// **'Ring Game'**
  String get introRingGame;

  /// No description provided for @introMultiTable.
  ///
  /// In en, this message translates to:
  /// **'Multi-Table'**
  String get introMultiTable;

  /// No description provided for @invitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Invitations'**
  String get invitationTitle;

  /// No description provided for @invitationNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations'**
  String get invitationNoPending;

  /// No description provided for @invitationYouWillSeeHere.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see invitations from clubs here'**
  String get invitationYouWillSeeHere;

  /// No description provided for @invitationGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get invitationGoBack;

  /// No description provided for @invitationFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load invitations: {error}'**
  String invitationFailedToLoad(String error);

  /// No description provided for @invitationJoinedAs.
  ///
  /// In en, this message translates to:
  /// **'Joined {clubName} as {role}'**
  String invitationJoinedAs(String clubName, String role);

  /// No description provided for @invitationFailedToAccept.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept invitation: {error}'**
  String invitationFailedToAccept(String error);

  /// No description provided for @invitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined'**
  String get invitationDeclined;

  /// No description provided for @invitationFailedToDecline.
  ///
  /// In en, this message translates to:
  /// **'Failed to decline invitation: {error}'**
  String invitationFailedToDecline(String error);

  /// No description provided for @invitationUnknownClub.
  ///
  /// In en, this message translates to:
  /// **'Unknown Club'**
  String get invitationUnknownClub;

  /// No description provided for @invitationInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String invitationInvitedBy(String name);

  /// No description provided for @invitationExpiresDate.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String invitationExpiresDate(String date);

  /// No description provided for @invitationExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get invitationExpired;

  /// No description provided for @invitationExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days} day(s)'**
  String invitationExpiresInDays(int days);

  /// No description provided for @invitationExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} hour(s)'**
  String invitationExpiresInHours(int hours);

  /// No description provided for @invitationExpiresSoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get invitationExpiresSoon;

  /// No description provided for @invitationDeclineButton.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get invitationDeclineButton;

  /// No description provided for @invitationAcceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get invitationAcceptButton;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTitle;

  /// No description provided for @notificationToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationToday;

  /// No description provided for @notificationYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notificationYesterday;

  /// No description provided for @notificationThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get notificationThisWeek;

  /// No description provided for @notificationEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationEarlier;

  /// No description provided for @notificationMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationMarkAllRead;

  /// No description provided for @notificationMarkAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationMarkAsRead;

  /// No description provided for @notificationNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationNoNotifications;

  /// No description provided for @notificationEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get notificationEvents;

  /// No description provided for @notificationRsvp.
  ///
  /// In en, this message translates to:
  /// **'RSVP'**
  String get notificationRsvp;

  /// No description provided for @notificationClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get notificationClubs;

  /// No description provided for @notificationInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get notificationInvitations;

  /// No description provided for @notificationSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get notificationSeats;

  /// No description provided for @notificationSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get notificationSupport;

  /// No description provided for @notificationClubNotFound.
  ///
  /// In en, this message translates to:
  /// **'Club not found'**
  String get notificationClubNotFound;

  /// No description provided for @notificationEventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get notificationEventNotFound;

  /// No description provided for @notificationError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String notificationError(String error);

  /// No description provided for @notificationErrorLoadingEvent.
  ///
  /// In en, this message translates to:
  /// **'Error loading event: {error}'**
  String notificationErrorLoadingEvent(String error);

  /// No description provided for @notificationFailedToLoadClub.
  ///
  /// In en, this message translates to:
  /// **'Failed to load club: {error}'**
  String notificationFailedToLoadClub(String error);

  /// No description provided for @notificationClubInvitation.
  ///
  /// In en, this message translates to:
  /// **'Club Invitation'**
  String get notificationClubInvitation;

  /// No description provided for @notificationInvitedToJoin.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to join'**
  String get notificationInvitedToJoin;

  /// No description provided for @notificationInvitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined'**
  String get notificationInvitationDeclined;

  /// No description provided for @notificationNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notificationNotAuthenticated;

  /// No description provided for @notificationInvitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invitation Accepted'**
  String get notificationInvitationAccepted;

  /// No description provided for @notificationAcceptedMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} has accepted the invitation to join {clubName}.'**
  String notificationAcceptedMessage(String name, String clubName);

  /// No description provided for @notificationInvitationDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation Declined'**
  String get notificationInvitationDeclinedTitle;

  /// No description provided for @notificationDeclinedMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} has declined the invitation to join {clubName}.'**
  String notificationDeclinedMessage(String name, String clubName);

  /// No description provided for @notificationRequestResolved.
  ///
  /// In en, this message translates to:
  /// **'Request Resolved'**
  String get notificationRequestResolved;

  /// No description provided for @notificationRequestClosed.
  ///
  /// In en, this message translates to:
  /// **'Request Closed'**
  String get notificationRequestClosed;

  /// No description provided for @notificationResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get notificationResponse;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Poker Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get calendarNewEvent;

  /// No description provided for @calendarEventType.
  ///
  /// In en, this message translates to:
  /// **'Event Type'**
  String get calendarEventType;

  /// No description provided for @calendarEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get calendarEventTitle;

  /// No description provided for @calendarLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get calendarLocation;

  /// No description provided for @calendarBuyInAmount.
  ///
  /// In en, this message translates to:
  /// **'Buy-in amount'**
  String get calendarBuyInAmount;

  /// No description provided for @calendarEventDateTime.
  ///
  /// In en, this message translates to:
  /// **'Event Date and Time'**
  String get calendarEventDateTime;

  /// No description provided for @calendarStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get calendarStarts;

  /// No description provided for @calendarSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date:'**
  String get calendarSelectDate;

  /// No description provided for @calendarReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get calendarReset;

  /// No description provided for @calendarSun.
  ///
  /// In en, this message translates to:
  /// **'SUN'**
  String get calendarSun;

  /// No description provided for @calendarMon.
  ///
  /// In en, this message translates to:
  /// **'MON'**
  String get calendarMon;

  /// No description provided for @calendarTue.
  ///
  /// In en, this message translates to:
  /// **'TUE'**
  String get calendarTue;

  /// No description provided for @calendarWed.
  ///
  /// In en, this message translates to:
  /// **'WED'**
  String get calendarWed;

  /// No description provided for @calendarThu.
  ///
  /// In en, this message translates to:
  /// **'THU'**
  String get calendarThu;

  /// No description provided for @calendarFri.
  ///
  /// In en, this message translates to:
  /// **'FRI'**
  String get calendarFri;

  /// No description provided for @calendarSat.
  ///
  /// In en, this message translates to:
  /// **'SAT'**
  String get calendarSat;

  /// No description provided for @calendarNoRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'No recent events'**
  String get calendarNoRecentEvents;

  /// No description provided for @calendarAddFirstEvent.
  ///
  /// In en, this message translates to:
  /// **'Add your first poker event!'**
  String get calendarAddFirstEvent;

  /// No description provided for @calendarAddNewEvent.
  ///
  /// In en, this message translates to:
  /// **'Add New Event'**
  String get calendarAddNewEvent;

  /// No description provided for @calendarSelectYear.
  ///
  /// In en, this message translates to:
  /// **'Select Year'**
  String get calendarSelectYear;

  /// No description provided for @calendarEditEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get calendarEditEvent;

  /// No description provided for @calendarDeleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get calendarDeleteEvent;

  /// No description provided for @calendarTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get calendarTournament;

  /// No description provided for @calendarCashGame.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get calendarCashGame;

  /// No description provided for @calendarPrivateGame.
  ///
  /// In en, this message translates to:
  /// **'Private Game'**
  String get calendarPrivateGame;

  /// No description provided for @calendarOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get calendarOnline;

  /// No description provided for @calendarFailedToCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to create event: {error}'**
  String calendarFailedToCreateEvent(String error);

  /// No description provided for @calendarFailedToUpdateEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to update event: {error}'**
  String calendarFailedToUpdateEvent(String error);

  /// No description provided for @calendarFailedToDeleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete event'**
  String get calendarFailedToDeleteEvent;

  /// No description provided for @calendarClubNotFound.
  ///
  /// In en, this message translates to:
  /// **'Club not found'**
  String get calendarClubNotFound;

  /// No description provided for @calendarEventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get calendarEventNotFound;

  /// No description provided for @calendarFailedToLoadEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to load event: {error}'**
  String calendarFailedToLoadEvent(String error);

  /// No description provided for @calendarDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}?'**
  String calendarDeleteConfirmTitle(String title);

  /// No description provided for @calendarDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?\nThis action cannot be undone.'**
  String calendarDeleteConfirmMessage(String title);

  /// No description provided for @sessionAnalyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Analytics'**
  String get sessionAnalyticsTitle;

  /// No description provided for @sessionAnalyticsHandsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count} hands logged'**
  String sessionAnalyticsHandsLogged(int count);

  /// No description provided for @sessionAnalyticsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Session?'**
  String get sessionAnalyticsDeleteTitle;

  /// No description provided for @sessionAnalyticsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this session including all hand history, stack chart data, and AI analysis reports. This action cannot be undone.'**
  String get sessionAnalyticsDeleteMessage;

  /// No description provided for @sessionAnalyticsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionAnalyticsDeleted;

  /// No description provided for @sessionAnalyticsFailedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete session'**
  String get sessionAnalyticsFailedToDelete;

  /// No description provided for @sessionAnalyticsExportSession.
  ///
  /// In en, this message translates to:
  /// **'Export Session'**
  String get sessionAnalyticsExportSession;

  /// No description provided for @sessionAnalyticsExportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Export {count} hands to {email}?'**
  String sessionAnalyticsExportConfirm(int count, String email);

  /// No description provided for @sessionAnalyticsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get sessionAnalyticsExport;

  /// No description provided for @sessionAnalyticsExportSent.
  ///
  /// In en, this message translates to:
  /// **'Export sent to {email}'**
  String sessionAnalyticsExportSent(String email);

  /// No description provided for @sessionAnalyticsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String sessionAnalyticsExportFailed(String error);

  /// No description provided for @sessionAnalyticsNoEmailFound.
  ///
  /// In en, this message translates to:
  /// **'No email address found. Please sign in with an email account.'**
  String get sessionAnalyticsNoEmailFound;

  /// No description provided for @sessionAnalyticsPokerSession.
  ///
  /// In en, this message translates to:
  /// **'Poker Session'**
  String get sessionAnalyticsPokerSession;

  /// No description provided for @sessionAnalyticsTotalInvested.
  ///
  /// In en, this message translates to:
  /// **'Total Invested'**
  String get sessionAnalyticsTotalInvested;

  /// No description provided for @sessionAnalyticsFinalStack.
  ///
  /// In en, this message translates to:
  /// **'Final Stack'**
  String get sessionAnalyticsFinalStack;

  /// No description provided for @sessionAnalyticsCashout.
  ///
  /// In en, this message translates to:
  /// **'Cashout'**
  String get sessionAnalyticsCashout;

  /// No description provided for @sessionAnalyticsProfitLoss.
  ///
  /// In en, this message translates to:
  /// **'Profit/Loss'**
  String get sessionAnalyticsProfitLoss;

  /// No description provided for @sessionAnalyticsNotAvailableFull.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get sessionAnalyticsNotAvailableFull;

  /// No description provided for @sessionAnalyticsAvgGrowth.
  ///
  /// In en, this message translates to:
  /// **'Avg Growth'**
  String get sessionAnalyticsAvgGrowth;

  /// No description provided for @sessionAnalyticsHourlyRate.
  ///
  /// In en, this message translates to:
  /// **'Hourly Rate'**
  String get sessionAnalyticsHourlyRate;

  /// No description provided for @sessionAnalyticsFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get sessionAnalyticsFinished;

  /// No description provided for @sessionAnalyticsDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sessionAnalyticsDuration;

  /// No description provided for @sessionAnalyticsRebuys.
  ///
  /// In en, this message translates to:
  /// **'Rebuys'**
  String get sessionAnalyticsRebuys;

  /// No description provided for @sessionAnalyticsAddons.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get sessionAnalyticsAddons;

  /// No description provided for @sessionAnalyticsStackChart.
  ///
  /// In en, this message translates to:
  /// **'Stack Chart'**
  String get sessionAnalyticsStackChart;

  /// No description provided for @sessionAnalyticsNoStackHistory.
  ///
  /// In en, this message translates to:
  /// **'No Stack History Available'**
  String get sessionAnalyticsNoStackHistory;

  /// No description provided for @sessionAnalyticsStackTrackedFuture.
  ///
  /// In en, this message translates to:
  /// **'Stack changes will be tracked in future sessions'**
  String get sessionAnalyticsStackTrackedFuture;

  /// No description provided for @sessionAnalyticsViewLoggedHands.
  ///
  /// In en, this message translates to:
  /// **'View Logged Hands'**
  String get sessionAnalyticsViewLoggedHands;

  /// No description provided for @sessionAnalyticsStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get sessionAnalyticsStart;

  /// No description provided for @sessionAnalyticsRebuy.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get sessionAnalyticsRebuy;

  /// No description provided for @sessionAnalyticsEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get sessionAnalyticsEnd;

  /// No description provided for @seatSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup Seat'**
  String get seatSetupTitle;

  /// No description provided for @seatSetupManagePlayers.
  ///
  /// In en, this message translates to:
  /// **'Manage Players'**
  String get seatSetupManagePlayers;

  /// No description provided for @seatSetupClickToConfig.
  ///
  /// In en, this message translates to:
  /// **'Click seat to configure. Drag button to position'**
  String get seatSetupClickToConfig;

  /// No description provided for @seatSetupButtonLocked.
  ///
  /// In en, this message translates to:
  /// **'Button locked - hand in progress'**
  String get seatSetupButtonLocked;

  /// No description provided for @seatSetupUpdatePlayerInfo.
  ///
  /// In en, this message translates to:
  /// **'Update player information'**
  String get seatSetupUpdatePlayerInfo;

  /// No description provided for @seatSetupEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get seatSetupEmpty;

  /// No description provided for @seatSetupThisIsMySeat.
  ///
  /// In en, this message translates to:
  /// **'This is my seat'**
  String get seatSetupThisIsMySeat;

  /// No description provided for @seatSetupPlayerName.
  ///
  /// In en, this message translates to:
  /// **'Player Name'**
  String get seatSetupPlayerName;

  /// No description provided for @seatSetupBuyInAmount.
  ///
  /// In en, this message translates to:
  /// **'Buy-in Amount (\$)'**
  String get seatSetupBuyInAmount;

  /// No description provided for @seatSetupStartingChips.
  ///
  /// In en, this message translates to:
  /// **'Starting Chips'**
  String get seatSetupStartingChips;

  /// No description provided for @seatSetupSaveAsOpponent.
  ///
  /// In en, this message translates to:
  /// **'Save \"{name}\" as opponent?'**
  String seatSetupSaveAsOpponent(String name);

  /// No description provided for @seatSetupOpponentSaved.
  ///
  /// In en, this message translates to:
  /// **'Opponent saved!'**
  String get seatSetupOpponentSaved;

  /// No description provided for @seatSetupFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String seatSetupFailedToSave(String error);

  /// No description provided for @seatSetupNoData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get seatSetupNoData;

  /// No description provided for @seatSetupStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get seatSetupStartSession;

  /// No description provided for @seatSetupSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get seatSetupSaveChanges;

  /// No description provided for @seatSetupPleaseSelectSeat.
  ///
  /// In en, this message translates to:
  /// **'Please select your seat'**
  String get seatSetupPleaseSelectSeat;

  /// No description provided for @seatSetupSeatNumber.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}'**
  String seatSetupSeatNumber(int number);

  /// No description provided for @seatSetupPlayerDefault.
  ///
  /// In en, this message translates to:
  /// **'Player {number}'**
  String seatSetupPlayerDefault(int number);

  /// No description provided for @quickStackTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Stacks & Button'**
  String get quickStackTitle;

  /// No description provided for @quickStackBlinds.
  ///
  /// In en, this message translates to:
  /// **'Blinds: {blinds}'**
  String quickStackBlinds(String blinds);

  /// No description provided for @quickStackInstruction.
  ///
  /// In en, this message translates to:
  /// **'Tap stack to edit  •  Slide to adjust  •  Tap D for button'**
  String get quickStackInstruction;

  /// No description provided for @quickStackContinue.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE TO LOG HAND'**
  String get quickStackContinue;

  /// No description provided for @quickStackEditStack.
  ///
  /// In en, this message translates to:
  /// **'Edit Stack'**
  String get quickStackEditStack;

  /// No description provided for @quickStackStackInBb.
  ///
  /// In en, this message translates to:
  /// **'Stack in BB'**
  String get quickStackStackInBb;

  /// No description provided for @quickStackCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'Current: {bbValue} BB = {chipValue}'**
  String quickStackCurrentValue(String bbValue, String chipValue);

  /// No description provided for @quickStackValidationError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a value between 0 and 1000 BB'**
  String get quickStackValidationError;

  /// No description provided for @quickStackSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}'**
  String quickStackSeat(int number);

  /// No description provided for @quickStackEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get quickStackEmpty;

  /// No description provided for @quickStackPlayerDefault.
  ///
  /// In en, this message translates to:
  /// **'Player {id}'**
  String quickStackPlayerDefault(int id);

  /// No description provided for @handReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand Review'**
  String get handReviewTitle;

  /// No description provided for @handReviewYourHoleCards.
  ///
  /// In en, this message translates to:
  /// **'Your Hole Cards'**
  String get handReviewYourHoleCards;

  /// No description provided for @handReviewOptional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get handReviewOptional;

  /// No description provided for @handReviewQuickTags.
  ///
  /// In en, this message translates to:
  /// **'Quick Tags'**
  String get handReviewQuickTags;

  /// No description provided for @handReviewTagBluff.
  ///
  /// In en, this message translates to:
  /// **'Bluff'**
  String get handReviewTagBluff;

  /// No description provided for @handReviewTagValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get handReviewTagValue;

  /// No description provided for @handReviewTagMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake'**
  String get handReviewTagMistake;

  /// No description provided for @handReviewTagCooler.
  ///
  /// In en, this message translates to:
  /// **'Cooler'**
  String get handReviewTagCooler;

  /// No description provided for @handReviewTagHeroCall.
  ///
  /// In en, this message translates to:
  /// **'Hero Call'**
  String get handReviewTagHeroCall;

  /// No description provided for @handReviewTagExploit.
  ///
  /// In en, this message translates to:
  /// **'Exploit'**
  String get handReviewTagExploit;

  /// No description provided for @handReviewNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get handReviewNotes;

  /// No description provided for @handReviewNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note about this hand...'**
  String get handReviewNotesHint;

  /// No description provided for @handReviewSaveHand.
  ///
  /// In en, this message translates to:
  /// **'Save Hand'**
  String get handReviewSaveHand;

  /// No description provided for @handReviewSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get handReviewSkip;

  /// No description provided for @handReviewDuplicateCardError.
  ///
  /// In en, this message translates to:
  /// **'You cannot select the same card twice!'**
  String get handReviewDuplicateCardError;

  /// No description provided for @handReviewSelectBothOrNone.
  ///
  /// In en, this message translates to:
  /// **'Please select both hole cards or leave both empty'**
  String get handReviewSelectBothOrNone;

  /// No description provided for @holeCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Hole Cards'**
  String get holeCardsTitle;

  /// No description provided for @holeCardsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hole Cards'**
  String get holeCardsSubtitle;

  /// No description provided for @holeCardsWinnerBadge.
  ///
  /// In en, this message translates to:
  /// **'WINNER'**
  String get holeCardsWinnerBadge;

  /// No description provided for @holeCardsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get holeCardsSave;

  /// No description provided for @holeCardsSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get holeCardsSkip;

  /// No description provided for @holeCardsSkipAllRemaining.
  ///
  /// In en, this message translates to:
  /// **'Skip All Remaining'**
  String get holeCardsSkipAllRemaining;

  /// No description provided for @holeCardsDuplicateCardError.
  ///
  /// In en, this message translates to:
  /// **'You cannot select the same card twice!'**
  String get holeCardsDuplicateCardError;

  /// No description provided for @holeCardsSelectBothOrSkip.
  ///
  /// In en, this message translates to:
  /// **'Please select both hole cards or skip to continue'**
  String get holeCardsSelectBothOrSkip;

  /// No description provided for @holeCardsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get holeCardsClearAll;

  /// No description provided for @showdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Showdown'**
  String get showdownTitle;

  /// No description provided for @showdownEnterOpponentCards.
  ///
  /// In en, this message translates to:
  /// **'Enter opponent cards at showdown:'**
  String get showdownEnterOpponentCards;

  /// No description provided for @showdownPlayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Player {seatNumber}'**
  String showdownPlayerLabel(int seatNumber);

  /// No description provided for @showdownCard1.
  ///
  /// In en, this message translates to:
  /// **'Card 1'**
  String get showdownCard1;

  /// No description provided for @showdownCard2.
  ///
  /// In en, this message translates to:
  /// **'Card 2'**
  String get showdownCard2;

  /// No description provided for @showdownClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get showdownClear;

  /// No description provided for @showdownWinner.
  ///
  /// In en, this message translates to:
  /// **'Winner:'**
  String get showdownWinner;

  /// No description provided for @showdownHandDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Hand Description (optional)'**
  String get showdownHandDescriptionLabel;

  /// No description provided for @showdownHandDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"Straight flush\", \"Full house Aces over Kings\"'**
  String get showdownHandDescriptionHint;

  /// No description provided for @showdownSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get showdownSkip;

  /// No description provided for @showdownSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get showdownSave;

  /// No description provided for @showdownSelectCard.
  ///
  /// In en, this message translates to:
  /// **'Select Card'**
  String get showdownSelectCard;

  /// No description provided for @tableManagementSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'TABLE'**
  String get tableManagementSectionTitle;

  /// No description provided for @tableManagementPlayersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} players'**
  String tableManagementPlayersCount(int count);

  /// No description provided for @tableManagementDealerButton.
  ///
  /// In en, this message translates to:
  /// **'Dealer Button'**
  String get tableManagementDealerButton;

  /// No description provided for @tableManagementAddPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add Player'**
  String get tableManagementAddPlayer;

  /// No description provided for @tableManagementYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (You)'**
  String tableManagementYouSuffix(String name);

  /// No description provided for @tableManagementAdjustStack.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stack'**
  String get tableManagementAdjustStack;

  /// No description provided for @tableManagementRebuy.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get tableManagementRebuy;

  /// No description provided for @tableManagementRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tableManagementRemove;

  /// No description provided for @tableManagementAdjustStackTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stack'**
  String get tableManagementAdjustStackTitle;

  /// No description provided for @tableManagementEnterStackAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter stack amount'**
  String get tableManagementEnterStackAmount;

  /// No description provided for @tableManagementRebuyTitle.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get tableManagementRebuyTitle;

  /// No description provided for @tableManagementRebuyAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Rebuy amount to add'**
  String get tableManagementRebuyAmountHint;

  /// No description provided for @tableManagementAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tableManagementAdd;

  /// No description provided for @tableManagementRemovePlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Player?'**
  String get tableManagementRemovePlayerTitle;

  /// No description provided for @tableManagementRemovePlayerMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove {playerName} from the table?'**
  String tableManagementRemovePlayerMessage(String playerName);

  /// No description provided for @tableManagementAddPlayerSeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Player — Seat {seatNumber}'**
  String tableManagementAddPlayerSeatTitle(int seatNumber);

  /// No description provided for @tableManagementThisIsMe.
  ///
  /// In en, this message translates to:
  /// **'This is me'**
  String get tableManagementThisIsMe;

  /// No description provided for @tableManagementNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tableManagementNameLabel;

  /// No description provided for @tableManagementSearchOrEnterName.
  ///
  /// In en, this message translates to:
  /// **'Search or enter name'**
  String get tableManagementSearchOrEnterName;

  /// No description provided for @tableManagementSaveAsOpponent.
  ///
  /// In en, this message translates to:
  /// **'Save \"{name}\" as opponent'**
  String tableManagementSaveAsOpponent(String name);

  /// No description provided for @tableManagementSavedAsOpponent.
  ///
  /// In en, this message translates to:
  /// **'{name} saved as opponent'**
  String tableManagementSavedAsOpponent(String name);

  /// No description provided for @tableManagementStartingStack.
  ///
  /// In en, this message translates to:
  /// **'Starting Stack'**
  String get tableManagementStartingStack;

  /// No description provided for @tableManagementStackAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Stack amount'**
  String get tableManagementStackAmountHint;

  /// No description provided for @tableManagementMoveMeHere.
  ///
  /// In en, this message translates to:
  /// **'Move Me Here'**
  String get tableManagementMoveMeHere;

  /// No description provided for @tableManagementSeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Seat {seatNumber}'**
  String tableManagementSeatLabel(int seatNumber);

  /// No description provided for @seatConfigRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get seatConfigRemove;

  /// No description provided for @seatConfigRemoveMe.
  ///
  /// In en, this message translates to:
  /// **'Remove me from this seat'**
  String get seatConfigRemoveMe;

  /// No description provided for @seatConfigThisIsMe.
  ///
  /// In en, this message translates to:
  /// **'This is me'**
  String get seatConfigThisIsMe;

  /// No description provided for @seatConfigNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get seatConfigNameLabel;

  /// No description provided for @seatConfigSearchOrEnterName.
  ///
  /// In en, this message translates to:
  /// **'Search or enter name'**
  String get seatConfigSearchOrEnterName;

  /// No description provided for @seatConfigSaveAsOpponent.
  ///
  /// In en, this message translates to:
  /// **'Save \"{name}\" as opponent'**
  String seatConfigSaveAsOpponent(String name);

  /// No description provided for @seatConfigSavedAsOpponent.
  ///
  /// In en, this message translates to:
  /// **'{name} saved as opponent'**
  String seatConfigSavedAsOpponent(String name);

  /// No description provided for @seatConfigSeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat {seatNumber}'**
  String seatConfigSeatTitle(int seatNumber);

  /// No description provided for @seatConfigStackLabel.
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get seatConfigStackLabel;

  /// No description provided for @seatConfigUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get seatConfigUpdateButton;

  /// No description provided for @seatConfigAddPlayerButton.
  ///
  /// In en, this message translates to:
  /// **'Add Player'**
  String get seatConfigAddPlayerButton;

  /// No description provided for @seatManagementSetupSeats.
  ///
  /// In en, this message translates to:
  /// **'Setup Seats'**
  String get seatManagementSetupSeats;

  /// No description provided for @seatManagementManagePlayers.
  ///
  /// In en, this message translates to:
  /// **'Manage Players'**
  String get seatManagementManagePlayers;

  /// No description provided for @seatManagementChooseSeatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your seat and configure table'**
  String get seatManagementChooseSeatSubtitle;

  /// No description provided for @seatManagementUpdatePlayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update player information'**
  String get seatManagementUpdatePlayerSubtitle;

  /// No description provided for @seatManagementButtonPosition.
  ///
  /// In en, this message translates to:
  /// **'Button Position'**
  String get seatManagementButtonPosition;

  /// No description provided for @seatManagementSeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Seat {seatNumber}'**
  String seatManagementSeatLabel(int seatNumber);

  /// No description provided for @seatManagementEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get seatManagementEmpty;

  /// No description provided for @seatManagementActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get seatManagementActive;

  /// No description provided for @seatManagementPlayerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Player Name'**
  String get seatManagementPlayerNameLabel;

  /// No description provided for @seatManagementEnterPlayerName.
  ///
  /// In en, this message translates to:
  /// **'Enter player name'**
  String get seatManagementEnterPlayerName;

  /// No description provided for @seatManagementBuyInAmountCash.
  ///
  /// In en, this message translates to:
  /// **'Buy-in Amount (\$)'**
  String get seatManagementBuyInAmountCash;

  /// No description provided for @seatManagementStartingChips.
  ///
  /// In en, this message translates to:
  /// **'Starting Chips'**
  String get seatManagementStartingChips;

  /// No description provided for @seatManagementSaveOpponentTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Opponent?'**
  String get seatManagementSaveOpponentTitle;

  /// No description provided for @seatManagementSaveOpponentMessage.
  ///
  /// In en, this message translates to:
  /// **'Would you like to save \"{name}\" to your opponents list for future tracking?'**
  String seatManagementSaveOpponentMessage(String name);

  /// No description provided for @seatManagementNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get seatManagementNotNow;

  /// No description provided for @seatManagementSaveAsOpponentPrompt.
  ///
  /// In en, this message translates to:
  /// **'Save \"{name}\" as opponent?'**
  String seatManagementSaveAsOpponentPrompt(String name);

  /// No description provided for @seatManagementOpponentSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Opponent \"{name}\" saved successfully!'**
  String seatManagementOpponentSavedSuccess(String name);

  /// No description provided for @seatManagementFailedToSaveOpponent.
  ///
  /// In en, this message translates to:
  /// **'Failed to save opponent: {error}'**
  String seatManagementFailedToSaveOpponent(String error);

  /// No description provided for @seatManagementStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get seatManagementStartSession;

  /// No description provided for @seatManagementSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get seatManagementSaveChanges;

  /// No description provided for @seatManagementSelectYourSeat.
  ///
  /// In en, this message translates to:
  /// **'Please select your seat'**
  String get seatManagementSelectYourSeat;

  /// No description provided for @inviteMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite Member'**
  String get inviteMemberTitle;

  /// No description provided for @inviteMemberEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'EMAIL ADDRESS'**
  String get inviteMemberEmailLabel;

  /// No description provided for @inviteMemberEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter email address'**
  String get inviteMemberEmailHint;

  /// No description provided for @inviteMemberEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter an email address'**
  String get inviteMemberEmailRequired;

  /// No description provided for @inviteMemberEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get inviteMemberEmailInvalid;

  /// No description provided for @inviteMemberRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'ROLE'**
  String get inviteMemberRoleLabel;

  /// No description provided for @inviteMemberRoleDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get inviteMemberRoleDealer;

  /// No description provided for @inviteMemberRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get inviteMemberRoleAdmin;

  /// No description provided for @inviteMemberSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send Invite'**
  String get inviteMemberSendInvite;

  /// No description provided for @inviteMemberAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'{displayName} is already a member of {clubName}'**
  String inviteMemberAlreadyMember(String displayName, String clubName);

  /// No description provided for @inviteMemberAddedNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'ve Been Added to a Club!'**
  String get inviteMemberAddedNotificationTitle;

  /// No description provided for @inviteMemberAddedNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'{inviterName} added you to \"{clubName}\" as {role}.'**
  String inviteMemberAddedNotificationBody(
      String inviterName, String clubName, String role);

  /// No description provided for @inviteMemberAddedSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Member Added!'**
  String get inviteMemberAddedSuccessTitle;

  /// No description provided for @inviteMemberAddedSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'{displayName} has been added to {clubName} as {role}.'**
  String inviteMemberAddedSuccessMessage(
      String displayName, String clubName, String role);

  /// No description provided for @inviteMemberInvitationSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation Sent!'**
  String get inviteMemberInvitationSentTitle;

  /// No description provided for @inviteMemberInvitationSentMessage.
  ///
  /// In en, this message translates to:
  /// **'An invitation email has been sent to {email}. Once they sign up, they\'ll be able to join {clubName}.'**
  String inviteMemberInvitationSentMessage(String email, String clubName);

  /// No description provided for @inviteMemberError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String inviteMemberError(String error);

  /// No description provided for @inviteMemberRoleAnAdmin.
  ///
  /// In en, this message translates to:
  /// **'an admin'**
  String get inviteMemberRoleAnAdmin;

  /// No description provided for @inviteMemberRoleADealer.
  ///
  /// In en, this message translates to:
  /// **'a dealer'**
  String get inviteMemberRoleADealer;

  /// No description provided for @registerClubTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Club'**
  String get registerClubTitle;

  /// No description provided for @registerClubNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Club Name'**
  String get registerClubNameLabel;

  /// No description provided for @registerClubNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., Lucky Aces Poker Club'**
  String get registerClubNamePlaceholder;

  /// No description provided for @registerClubNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a club name'**
  String get registerClubNameRequired;

  /// No description provided for @registerClubAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get registerClubAddressLabel;

  /// No description provided for @registerClubAddressPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., 123 Main St, City, Country'**
  String get registerClubAddressPlaceholder;

  /// No description provided for @registerClubAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the club address'**
  String get registerClubAddressRequired;

  /// No description provided for @registerClubPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get registerClubPhoneLabel;

  /// No description provided for @registerClubPhonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., +1 555-123-4567'**
  String get registerClubPhonePlaceholder;

  /// No description provided for @registerClubPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a phone number'**
  String get registerClubPhoneRequired;

  /// No description provided for @registerClubAdminEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Club Admin Email'**
  String get registerClubAdminEmailLabel;

  /// No description provided for @registerClubAdminEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., admin@myclub.com'**
  String get registerClubAdminEmailPlaceholder;

  /// No description provided for @registerClubAdminEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter admin email'**
  String get registerClubAdminEmailRequired;

  /// No description provided for @registerClubAdminEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get registerClubAdminEmailInvalid;

  /// No description provided for @registerClubInfoMessage.
  ///
  /// In en, this message translates to:
  /// **'This person will be notified when the club is approved and will become the club owner.'**
  String get registerClubInfoMessage;

  /// No description provided for @registerClubSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get registerClubSubmitRequest;

  /// No description provided for @registerClubFailedToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit request: {error}'**
  String registerClubFailedToSubmit(String error);

  /// No description provided for @registerClubSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Submitted!'**
  String get registerClubSuccessTitle;

  /// No description provided for @registerClubSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your club registration request has been submitted. We\'ll notify you at {email} once it\'s reviewed.'**
  String registerClubSuccessMessage(String email);

  /// No description provided for @registerClubGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get registerClubGotIt;

  /// No description provided for @loggingModeChooseMode.
  ///
  /// In en, this message translates to:
  /// **'Choose Mode'**
  String get loggingModeChooseMode;

  /// No description provided for @loggingModeFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Logging Mode'**
  String get loggingModeFullTitle;

  /// No description provided for @loggingModeFullSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Session Tracking'**
  String get loggingModeFullSubtitle;

  /// No description provided for @loggingModeFullFeature1.
  ///
  /// In en, this message translates to:
  /// **'Multi-hand session tracking'**
  String get loggingModeFullFeature1;

  /// No description provided for @loggingModeFullFeature2.
  ///
  /// In en, this message translates to:
  /// **'Real time statistics'**
  String get loggingModeFullFeature2;

  /// No description provided for @loggingModeFullFeature3.
  ///
  /// In en, this message translates to:
  /// **'Detailed hand history'**
  String get loggingModeFullFeature3;

  /// No description provided for @loggingModeFullFeature4.
  ///
  /// In en, this message translates to:
  /// **'Session analytics'**
  String get loggingModeFullFeature4;

  /// No description provided for @loggingModeIndividualTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Session Logging Mode'**
  String get loggingModeIndividualTitle;

  /// No description provided for @loggingModeIndividualSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Single hand tracking'**
  String get loggingModeIndividualSubtitle;

  /// No description provided for @loggingModeIndividualFeature1.
  ///
  /// In en, this message translates to:
  /// **'Single hand focus'**
  String get loggingModeIndividualFeature1;

  /// No description provided for @loggingModeIndividualFeature2.
  ///
  /// In en, this message translates to:
  /// **'Quick logging'**
  String get loggingModeIndividualFeature2;

  /// No description provided for @loggingModeIndividualFeature3.
  ///
  /// In en, this message translates to:
  /// **'Hand analysis'**
  String get loggingModeIndividualFeature3;

  /// No description provided for @loggingModeIndividualFeature4.
  ///
  /// In en, this message translates to:
  /// **'Instant results'**
  String get loggingModeIndividualFeature4;

  /// No description provided for @loggingModeFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get loggingModeFeatures;

  /// No description provided for @loggingModeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get loggingModeStart;

  /// No description provided for @earningsChartAllTimeEarnings.
  ///
  /// In en, this message translates to:
  /// **'All-Time Earnings'**
  String get earningsChartAllTimeEarnings;

  /// No description provided for @earningsChartSinceDate.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String earningsChartSinceDate(String date);

  /// No description provided for @earningsChartTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get earningsChartTournament;

  /// No description provided for @earningsChartCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get earningsChartCash;

  /// No description provided for @earningsChartNoData.
  ///
  /// In en, this message translates to:
  /// **'No earnings data yet'**
  String get earningsChartNoData;

  /// No description provided for @earningsChartNoDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete some sessions to see your earnings chart'**
  String get earningsChartNoDataSubtitle;

  /// No description provided for @earningsChartMtt.
  ///
  /// In en, this message translates to:
  /// **'MTT'**
  String get earningsChartMtt;

  /// No description provided for @opponentHandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand History'**
  String get opponentHandsTitle;

  /// No description provided for @opponentHandsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} hands'**
  String opponentHandsCount(int count);

  /// No description provided for @opponentHandsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading hand history...'**
  String get opponentHandsLoading;

  /// No description provided for @opponentHandsError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get opponentHandsError;

  /// No description provided for @opponentHandsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get opponentHandsRetry;

  /// No description provided for @opponentHandsNoHandsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Hands Found'**
  String get opponentHandsNoHandsTitle;

  /// No description provided for @opponentHandsNoHandsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t played any hands\nwith {name} yet.'**
  String opponentHandsNoHandsSubtitle(String name);

  /// No description provided for @opponentHandsOppWon.
  ///
  /// In en, this message translates to:
  /// **'OPP WON'**
  String get opponentHandsOppWon;

  /// No description provided for @opponentHandsYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get opponentHandsYou;

  /// No description provided for @opponentHandsPot.
  ///
  /// In en, this message translates to:
  /// **'Pot {amount}'**
  String opponentHandsPot(String amount);

  /// No description provided for @opponentHandsUnknownSession.
  ///
  /// In en, this message translates to:
  /// **'Unknown Session'**
  String get opponentHandsUnknownSession;

  /// No description provided for @clubDashboardLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get clubDashboardLive;

  /// No description provided for @clubDashboardUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get clubDashboardUpcoming;

  /// No description provided for @clubDashboardPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get clubDashboardPast;

  /// No description provided for @clubDashboardNoLiveEvents.
  ///
  /// In en, this message translates to:
  /// **'No live events'**
  String get clubDashboardNoLiveEvents;

  /// No description provided for @clubDashboardNoUpcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events'**
  String get clubDashboardNoUpcomingEvents;

  /// No description provided for @clubDashboardNoPastEvents.
  ///
  /// In en, this message translates to:
  /// **'No past events'**
  String get clubDashboardNoPastEvents;

  /// No description provided for @clubDashboardAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get clubDashboardAdmin;

  /// No description provided for @clubDashboardCreateEventHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to create one'**
  String get clubDashboardCreateEventHint;

  /// No description provided for @clubDashboardCheckBackLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later for new events'**
  String get clubDashboardCheckBackLater;

  /// No description provided for @clubDashboardEventsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Events will appear here when they start'**
  String get clubDashboardEventsWillAppear;

  /// No description provided for @clubDashboardPastEventsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Completed events will appear here'**
  String get clubDashboardPastEventsWillAppear;

  /// No description provided for @clubDashboardCashGameStakes.
  ///
  /// In en, this message translates to:
  /// **'Cash Game {stakes}'**
  String clubDashboardCashGameStakes(String stakes);

  /// No description provided for @clubDashboardCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get clubDashboardCash;

  /// No description provided for @clubDashboardTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get clubDashboardTables;

  /// No description provided for @clubDashboardStakes.
  ///
  /// In en, this message translates to:
  /// **'Stakes'**
  String get clubDashboardStakes;

  /// No description provided for @clubDashboardPlayingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} playing'**
  String clubDashboardPlayingCount(int count);

  /// No description provided for @clubDashboardMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String clubDashboardMemberCount(int count);

  /// No description provided for @clubSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Settings'**
  String get clubSettingsTitle;

  /// No description provided for @clubSettingsClubInfo.
  ///
  /// In en, this message translates to:
  /// **'Club Information'**
  String get clubSettingsClubInfo;

  /// No description provided for @clubSettingsClubName.
  ///
  /// In en, this message translates to:
  /// **'Club Name'**
  String get clubSettingsClubName;

  /// No description provided for @clubSettingsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get clubSettingsAddress;

  /// No description provided for @clubSettingsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get clubSettingsPhone;

  /// No description provided for @clubSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get clubSettingsDescription;

  /// No description provided for @clubSettingsSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get clubSettingsSaveChanges;

  /// No description provided for @clubSettingsInfoSaved.
  ///
  /// In en, this message translates to:
  /// **'Club info saved'**
  String get clubSettingsInfoSaved;

  /// No description provided for @clubSettingsErrorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String clubSettingsErrorSaving(String error);

  /// No description provided for @clubSettingsNoTablesYet.
  ///
  /// In en, this message translates to:
  /// **'No tables yet'**
  String get clubSettingsNoTablesYet;

  /// No description provided for @clubSettingsAddTableHint.
  ///
  /// In en, this message translates to:
  /// **'Add a table to get started'**
  String get clubSettingsAddTableHint;

  /// No description provided for @clubSettingsErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String clubSettingsErrorLoading(String error);

  /// No description provided for @eventEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get eventEditTitle;

  /// No description provided for @eventNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get eventNewTitle;

  /// No description provided for @eventNoTablesAssigned.
  ///
  /// In en, this message translates to:
  /// **'No Tables Assigned'**
  String get eventNoTablesAssigned;

  /// No description provided for @eventNoTablesAssignedDesc.
  ///
  /// In en, this message translates to:
  /// **'No tables assigned to this event. Please go back and assign tables first.'**
  String get eventNoTablesAssignedDesc;

  /// No description provided for @eventGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get eventGoBack;

  /// No description provided for @eventContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get eventContinue;

  /// No description provided for @eventNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Event Name (optional)'**
  String get eventNameOptional;

  /// No description provided for @eventNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Event Name'**
  String get eventNameLabel;

  /// No description provided for @eventStakesHint.
  ///
  /// In en, this message translates to:
  /// **'Stakes (e.g. 1/2)'**
  String get eventStakesHint;

  /// No description provided for @eventBuyInAmount.
  ///
  /// In en, this message translates to:
  /// **'Buy-in amount'**
  String get eventBuyInAmount;

  /// No description provided for @eventMinBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Min Buy-in (\$)'**
  String get eventMinBuyIn;

  /// No description provided for @eventStartingStack.
  ///
  /// In en, this message translates to:
  /// **'Starting stack'**
  String get eventStartingStack;

  /// No description provided for @eventGameType.
  ///
  /// In en, this message translates to:
  /// **'Game Type'**
  String get eventGameType;

  /// No description provided for @eventTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get eventTournament;

  /// No description provided for @eventCashGame.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get eventCashGame;

  /// No description provided for @eventDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Event Date and Time'**
  String get eventDateAndTime;

  /// No description provided for @eventStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get eventStarts;

  /// No description provided for @eventTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get eventTables;

  /// No description provided for @eventDeselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get eventDeselectAll;

  /// No description provided for @eventSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get eventSelectAll;

  /// No description provided for @eventAllTablesInUse.
  ///
  /// In en, this message translates to:
  /// **'All tables are in use by running events'**
  String get eventAllTablesInUse;

  /// No description provided for @eventNoTablesConfigured.
  ///
  /// In en, this message translates to:
  /// **'No tables configured yet'**
  String get eventNoTablesConfigured;

  /// No description provided for @eventDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get eventDescriptionLabel;

  /// No description provided for @eventNotifyMembers.
  ///
  /// In en, this message translates to:
  /// **'Notify Members'**
  String get eventNotifyMembers;

  /// No description provided for @eventNotifyMembersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send notification to all club members'**
  String get eventNotifyMembersSubtitle;

  /// No description provided for @eventDeleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get eventDeleteEvent;

  /// No description provided for @eventDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Event?'**
  String get eventDeleteConfirmTitle;

  /// No description provided for @eventDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this event and all associated data. This action cannot be undone.'**
  String get eventDeleteConfirmBody;

  /// No description provided for @eventDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete event: {error}'**
  String eventDeleteFailed(String error);

  /// No description provided for @eventAttendeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get eventAttendeesTitle;

  /// No description provided for @eventAttendeesGoing.
  ///
  /// In en, this message translates to:
  /// **'Going ({count})'**
  String eventAttendeesGoing(int count);

  /// No description provided for @eventAttendeesMaybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe ({count})'**
  String eventAttendeesMaybe(int count);

  /// No description provided for @eventAttendeesNo.
  ///
  /// In en, this message translates to:
  /// **'No ({count})'**
  String eventAttendeesNo(int count);

  /// No description provided for @eventAttendeesNoConfirmed.
  ///
  /// In en, this message translates to:
  /// **'No one confirmed yet'**
  String get eventAttendeesNoConfirmed;

  /// No description provided for @eventAttendeesNoMaybes.
  ///
  /// In en, this message translates to:
  /// **'No maybes'**
  String get eventAttendeesNoMaybes;

  /// No description provided for @eventAttendeesNoDeclines.
  ///
  /// In en, this message translates to:
  /// **'No declines'**
  String get eventAttendeesNoDeclines;

  /// No description provided for @eventDetailLiveNow.
  ///
  /// In en, this message translates to:
  /// **'Event is now LIVE!'**
  String get eventDetailLiveNow;

  /// No description provided for @eventDetailEnded.
  ///
  /// In en, this message translates to:
  /// **'Event has ended'**
  String get eventDetailEnded;

  /// No description provided for @eventDetailCancelled.
  ///
  /// In en, this message translates to:
  /// **'Event was cancelled'**
  String get eventDetailCancelled;

  /// No description provided for @eventDetailPaused.
  ///
  /// In en, this message translates to:
  /// **'Event is paused'**
  String get eventDetailPaused;

  /// No description provided for @eventDetailStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Event status updated'**
  String get eventDetailStatusUpdated;

  /// No description provided for @eventDetailRemovedFromCalendar.
  ///
  /// In en, this message translates to:
  /// **'Event removed from your calendar'**
  String get eventDetailRemovedFromCalendar;

  /// No description provided for @eventDetailRsvpGoing.
  ///
  /// In en, this message translates to:
  /// **'Going'**
  String get eventDetailRsvpGoing;

  /// No description provided for @eventDetailRsvpMaybe.
  ///
  /// In en, this message translates to:
  /// **'Maybe'**
  String get eventDetailRsvpMaybe;

  /// No description provided for @eventDetailRsvpCantGo.
  ///
  /// In en, this message translates to:
  /// **'Can\'t go'**
  String get eventDetailRsvpCantGo;

  /// No description provided for @eventDetailRsvpFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update RSVP: {error}'**
  String eventDetailRsvpFailed(String error);

  /// No description provided for @eventDetailCantStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t Start Event'**
  String get eventDetailCantStartTitle;

  /// No description provided for @eventDetailCantStartBody.
  ///
  /// In en, this message translates to:
  /// **'No tables are assigned to this event. Please add tables first.'**
  String get eventDetailCantStartBody;

  /// No description provided for @eventDetailStarted.
  ///
  /// In en, this message translates to:
  /// **'Event started!'**
  String get eventDetailStarted;

  /// No description provided for @eventDetailStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start event: {error}'**
  String eventDetailStartFailed(String error);

  /// No description provided for @eventDetailFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish Event?'**
  String get eventDetailFinishTitle;

  /// No description provided for @eventDetailCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Event?'**
  String get eventDetailCancelTitle;

  /// No description provided for @eventDetailFinishBody.
  ///
  /// In en, this message translates to:
  /// **'This will end all active tables and finalize standings.'**
  String get eventDetailFinishBody;

  /// No description provided for @eventDetailCancelBody.
  ///
  /// In en, this message translates to:
  /// **'This will notify all members and cancel the event.'**
  String get eventDetailCancelBody;

  /// No description provided for @eventDetailFinishButton.
  ///
  /// In en, this message translates to:
  /// **'Finish Event'**
  String get eventDetailFinishButton;

  /// No description provided for @eventDetailCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Event'**
  String get eventDetailCancelButton;

  /// No description provided for @eventDetailKeepEvent.
  ///
  /// In en, this message translates to:
  /// **'Keep Event'**
  String get eventDetailKeepEvent;

  /// No description provided for @eventDetailLiveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE NOW'**
  String get eventDetailLiveBadge;

  /// No description provided for @eventDetailCancelledBadge.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get eventDetailCancelledBadge;

  /// No description provided for @eventDetailCompletedBadge.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get eventDetailCompletedBadge;

  /// No description provided for @eventDetailUpcomingBadge.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get eventDetailUpcomingBadge;

  /// No description provided for @eventDetailLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventDetailLocation;

  /// No description provided for @eventDetailBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Buy-in'**
  String get eventDetailBuyIn;

  /// No description provided for @eventDetailStakes.
  ///
  /// In en, this message translates to:
  /// **'Stakes'**
  String get eventDetailStakes;

  /// No description provided for @eventDetailStartingStack.
  ///
  /// In en, this message translates to:
  /// **'Starting Stack'**
  String get eventDetailStartingStack;

  /// No description provided for @eventDetailAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get eventDetailAbout;

  /// No description provided for @eventDetailAddedToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Event added to your calendar!'**
  String get eventDetailAddedToCalendar;

  /// No description provided for @eventDetailCalendarFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add to calendar: {error}'**
  String eventDetailCalendarFailed(String error);

  /// No description provided for @eventManagementEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get eventManagementEventsTitle;

  /// No description provided for @eventManagementNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get eventManagementNewEvent;

  /// No description provided for @eventManagementNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No Events'**
  String get eventManagementNoEvents;

  /// No description provided for @eventManagementNoEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an event to track live rankings'**
  String get eventManagementNoEventsSubtitle;

  /// No description provided for @eventManagementActiveEvents.
  ///
  /// In en, this message translates to:
  /// **'Active Events'**
  String get eventManagementActiveEvents;

  /// No description provided for @eventManagementPastEvents.
  ///
  /// In en, this message translates to:
  /// **'Past Events'**
  String get eventManagementPastEvents;

  /// No description provided for @eventManagementErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading events: {error}'**
  String eventManagementErrorLoading(String error);

  /// No description provided for @eventManagementNoTables.
  ///
  /// In en, this message translates to:
  /// **'No tables available. Create tables first.'**
  String get eventManagementNoTables;

  /// No description provided for @eventManagementCreated.
  ///
  /// In en, this message translates to:
  /// **'Event \"{name}\" created'**
  String eventManagementCreated(String name);

  /// No description provided for @eventManagementCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create event: {error}'**
  String eventManagementCreateFailed(String error);

  /// No description provided for @eventManagementEndEvent.
  ///
  /// In en, this message translates to:
  /// **'End Event'**
  String get eventManagementEndEvent;

  /// No description provided for @eventManagementEndConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end \"{name}\"?'**
  String eventManagementEndConfirm(String name);

  /// No description provided for @eventManagementEnded.
  ///
  /// In en, this message translates to:
  /// **'Event \"{name}\" ended'**
  String eventManagementEnded(String name);

  /// No description provided for @eventManagementEndFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to end event: {error}'**
  String eventManagementEndFailed(String error);

  /// No description provided for @eventManagementLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get eventManagementLinkCopied;

  /// No description provided for @eventManagementShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get eventManagementShare;

  /// No description provided for @eventManagementPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get eventManagementPause;

  /// No description provided for @eventManagementResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get eventManagementResume;

  /// No description provided for @eventManagementEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get eventManagementEnd;

  /// No description provided for @eventManagementCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get eventManagementCreateEvent;

  /// No description provided for @eventManagementEventNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Friday Night Tournament'**
  String get eventManagementEventNameHint;

  /// No description provided for @eventManagementSelectTables.
  ///
  /// In en, this message translates to:
  /// **'Select Tables'**
  String get eventManagementSelectTables;

  /// No description provided for @eventManagementTableNumber.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String eventManagementTableNumber(int number);

  /// No description provided for @eventManagementPublicEvent.
  ///
  /// In en, this message translates to:
  /// **'Public Event'**
  String get eventManagementPublicEvent;

  /// No description provided for @eventManagementPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone can view the leaderboard'**
  String get eventManagementPublicSubtitle;

  /// No description provided for @eventManagementAccessCode.
  ///
  /// In en, this message translates to:
  /// **'Access Code (optional)'**
  String get eventManagementAccessCode;

  /// No description provided for @eventManagementAccessCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For sharing with specific users'**
  String get eventManagementAccessCodeSubtitle;

  /// No description provided for @eventManagementEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter an event name'**
  String get eventManagementEnterName;

  /// No description provided for @eventManagementSelectTable.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one table'**
  String get eventManagementSelectTable;

  /// No description provided for @eventManagementPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get eventManagementPublic;

  /// No description provided for @eventManagementPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get eventManagementPrivate;

  /// No description provided for @adminEventTablesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} tables • {occupied} seated • {open} open'**
  String adminEventTablesSummary(int count, int occupied, int open);

  /// No description provided for @adminEventTablesAddTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get adminEventTablesAddTable;

  /// No description provided for @adminEventTablesNoTables.
  ///
  /// In en, this message translates to:
  /// **'No available tables to add'**
  String get adminEventTablesNoTables;

  /// No description provided for @adminEventTablesCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close {tableName}?'**
  String adminEventTablesCloseConfirm(String tableName);

  /// No description provided for @adminEventTablesCloseWithPlayers.
  ///
  /// In en, this message translates to:
  /// **'This will move {count} player(s) to the waitlist and remove the table from this event.'**
  String adminEventTablesCloseWithPlayers(int count);

  /// No description provided for @adminEventTablesCloseEmpty.
  ///
  /// In en, this message translates to:
  /// **'This will remove the table from this event.'**
  String get adminEventTablesCloseEmpty;

  /// No description provided for @adminEventTablesCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close Table'**
  String get adminEventTablesCloseButton;

  /// No description provided for @adminEventTablesTableAdded.
  ///
  /// In en, this message translates to:
  /// **'{tableName} added to event'**
  String adminEventTablesTableAdded(String tableName);

  /// No description provided for @adminEventTablesClosedWithWaitlist.
  ///
  /// In en, this message translates to:
  /// **'{tableName} closed. {count} player(s) moved to waitlist.'**
  String adminEventTablesClosedWithWaitlist(String tableName, int count);

  /// No description provided for @adminEventTablesClosed.
  ///
  /// In en, this message translates to:
  /// **'{tableName} closed.'**
  String adminEventTablesClosed(String tableName);

  /// No description provided for @adminEventTablesNoWaitlist.
  ///
  /// In en, this message translates to:
  /// **'No one in waitlist'**
  String get adminEventTablesNoWaitlist;

  /// No description provided for @adminEventTablesWaitlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in waitlist'**
  String adminEventTablesWaitlistCount(int count);

  /// No description provided for @adminEventTablesWaitlistNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {name}'**
  String adminEventTablesWaitlistNext(String name);

  /// No description provided for @adminEventTablesWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get adminEventTablesWaitlist;

  /// No description provided for @adminEventTablesNotified.
  ///
  /// In en, this message translates to:
  /// **'Notified'**
  String get adminEventTablesNotified;

  /// No description provided for @adminEventTablesNotify.
  ///
  /// In en, this message translates to:
  /// **'Notify'**
  String get adminEventTablesNotify;

  /// No description provided for @adminEventTablesSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get adminEventTablesSeat;

  /// No description provided for @adminEventTablesSeatAt.
  ///
  /// In en, this message translates to:
  /// **'{tableName} ({count} open)'**
  String adminEventTablesSeatAt(String tableName, int count);

  /// No description provided for @adminEventTablesNoEmptySeats.
  ///
  /// In en, this message translates to:
  /// **'No empty seats on this table'**
  String get adminEventTablesNoEmptySeats;

  /// No description provided for @adminEventTablesPlayerSeated.
  ///
  /// In en, this message translates to:
  /// **'{name} seated at {tableName}'**
  String adminEventTablesPlayerSeated(String name, String tableName);

  /// No description provided for @adminEventTablesPlayerNotified.
  ///
  /// In en, this message translates to:
  /// **'Notified {name}'**
  String adminEventTablesPlayerNotified(String name);

  /// No description provided for @adminTableSeatPlayer.
  ///
  /// In en, this message translates to:
  /// **'Seat Player'**
  String get adminTableSeatPlayer;

  /// No description provided for @adminTableFromWaitlist.
  ///
  /// In en, this message translates to:
  /// **'From Waitlist'**
  String get adminTableFromWaitlist;

  /// No description provided for @adminTableWaitlistNextIs.
  ///
  /// In en, this message translates to:
  /// **'{name} is next'**
  String adminTableWaitlistNextIs(String name);

  /// No description provided for @adminTableClubMember.
  ///
  /// In en, this message translates to:
  /// **'Club Member'**
  String get adminTableClubMember;

  /// No description provided for @adminTableSearchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search existing members'**
  String get adminTableSearchMembers;

  /// No description provided for @adminTableWalkUpPlayer.
  ///
  /// In en, this message translates to:
  /// **'Walk-up Player'**
  String get adminTableWalkUpPlayer;

  /// No description provided for @adminTableAddByName.
  ///
  /// In en, this message translates to:
  /// **'Add by name'**
  String get adminTableAddByName;

  /// No description provided for @adminTableSelectMember.
  ///
  /// In en, this message translates to:
  /// **'Select Member'**
  String get adminTableSelectMember;

  /// No description provided for @adminTableSearch.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get adminTableSearch;

  /// No description provided for @adminTablePlayerName.
  ///
  /// In en, this message translates to:
  /// **'Player name'**
  String get adminTablePlayerName;

  /// No description provided for @adminTableWaitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval to join seat #{seatNumber}'**
  String adminTableWaitingForApproval(int seatNumber);

  /// No description provided for @adminTableReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminTableReject;

  /// No description provided for @adminTableApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminTableApprove;

  /// No description provided for @adminTableRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminTableRemove;

  /// No description provided for @adminTableSeatNumber.
  ///
  /// In en, this message translates to:
  /// **'Seat #{seatNumber}'**
  String adminTableSeatNumber(int seatNumber);

  /// No description provided for @adminTableNoEmptySeats.
  ///
  /// In en, this message translates to:
  /// **'No empty seats available'**
  String get adminTableNoEmptySeats;

  /// No description provided for @adminTableSeatPlayerName.
  ///
  /// In en, this message translates to:
  /// **'Seat {name}'**
  String adminTableSeatPlayerName(String name);

  /// No description provided for @adminTableSelectSeat.
  ///
  /// In en, this message translates to:
  /// **'Select a seat:'**
  String get adminTableSelectSeat;

  /// No description provided for @adminTablePlayerSeated.
  ///
  /// In en, this message translates to:
  /// **'{name} seated'**
  String adminTablePlayerSeated(String name);

  /// No description provided for @adminTableAlreadySeated.
  ///
  /// In en, this message translates to:
  /// **'{name} is already seated at {location}'**
  String adminTableAlreadySeated(String name, String location);

  /// No description provided for @adminTablePlayerApproved.
  ///
  /// In en, this message translates to:
  /// **'{name} approved'**
  String adminTablePlayerApproved(String name);

  /// No description provided for @adminTablePlayerRejected.
  ///
  /// In en, this message translates to:
  /// **'Player rejected'**
  String get adminTablePlayerRejected;

  /// No description provided for @adminTablePlayerRemoved.
  ///
  /// In en, this message translates to:
  /// **'Player removed'**
  String get adminTablePlayerRemoved;

  /// No description provided for @adminTableWaitlistInCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in waitlist'**
  String adminTableWaitlistInCount(int count);

  /// No description provided for @adminTableWaitlistNextName.
  ///
  /// In en, this message translates to:
  /// **'Next: {name}'**
  String adminTableWaitlistNextName(String name);

  /// No description provided for @adminTableNotifiedName.
  ///
  /// In en, this message translates to:
  /// **'Notified {name}'**
  String adminTableNotifiedName(String name);

  /// No description provided for @clubCashGameStakes.
  ///
  /// In en, this message translates to:
  /// **'Cash Game {stakes}'**
  String clubCashGameStakes(String stakes);

  /// No description provided for @clubCashGameTablesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} tables · {occupied} seated · {open} open'**
  String clubCashGameTablesSummary(int count, int occupied, int open);

  /// No description provided for @clubCashGameTableNumber.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String clubCashGameTableNumber(int number);

  /// No description provided for @clubCashGameNoTables.
  ///
  /// In en, this message translates to:
  /// **'No tables in this group'**
  String get clubCashGameNoTables;

  /// No description provided for @clubCashGameFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tables: {error}'**
  String clubCashGameFailedToLoad(String error);

  /// No description provided for @clubCashGameAlreadySeated.
  ///
  /// In en, this message translates to:
  /// **'You\'re already seated at a table'**
  String get clubCashGameAlreadySeated;

  /// No description provided for @clubCashGameSeatAvailable.
  ///
  /// In en, this message translates to:
  /// **'There\'s a seat available for you, approach registration'**
  String get clubCashGameSeatAvailable;

  /// No description provided for @clubCashGameJoinedWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Joined waitlist at position #{position}'**
  String clubCashGameJoinedWaitlist(int position);

  /// No description provided for @clubCashGameJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join waitlist: {error}'**
  String clubCashGameJoinFailed(String error);

  /// No description provided for @clubCashGameLeftWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Left the waitlist'**
  String get clubCashGameLeftWaitlist;

  /// No description provided for @clubCashGameLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave waitlist: {error}'**
  String clubCashGameLeaveFailed(String error);

  /// No description provided for @clubCashGameViewWaitlist.
  ///
  /// In en, this message translates to:
  /// **'View Waitlist'**
  String get clubCashGameViewWaitlist;

  /// No description provided for @clubCashGameInWaitlist.
  ///
  /// In en, this message translates to:
  /// **'In waitlist'**
  String get clubCashGameInWaitlist;

  /// No description provided for @clubCashGameInWaitlistPosition.
  ///
  /// In en, this message translates to:
  /// **'In waitlist · #{position}'**
  String clubCashGameInWaitlistPosition(int position);

  /// No description provided for @clubCashGameJoinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist'**
  String get clubCashGameJoinWaitlist;

  /// No description provided for @clubCashGameLeaveWaitlistConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave waitlist?'**
  String get clubCashGameLeaveWaitlistConfirm;

  /// No description provided for @clubCashGameLosePosition.
  ///
  /// In en, this message translates to:
  /// **'You will lose your current position.'**
  String get clubCashGameLosePosition;

  /// No description provided for @clubCashGameKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get clubCashGameKeep;

  /// No description provided for @clubCashGameLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get clubCashGameLeave;

  /// No description provided for @clubCashGameRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh tables: {error}'**
  String clubCashGameRefreshFailed(String error);

  /// No description provided for @clubCashGameWaitlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Waitlist'**
  String get clubCashGameWaitlistTitle;

  /// No description provided for @clubCashGameNotified.
  ///
  /// In en, this message translates to:
  /// **'{name} has been notified'**
  String clubCashGameNotified(String name);

  /// No description provided for @clubCashGameNotifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to notify: {error}'**
  String clubCashGameNotifyFailed(String error);

  /// No description provided for @clubCashGameCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load waitlist'**
  String get clubCashGameCouldNotLoad;

  /// No description provided for @clubCashGameNoOneOnWaitlist.
  ///
  /// In en, this message translates to:
  /// **'No one on the waitlist'**
  String get clubCashGameNoOneOnWaitlist;

  /// No description provided for @clubCashGamePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get clubCashGamePlayer;

  /// No description provided for @clubCashGameNotifiedStatus.
  ///
  /// In en, this message translates to:
  /// **'Notified • {time}'**
  String clubCashGameNotifiedStatus(String time);

  /// No description provided for @clubCashGameJoinedTime.
  ///
  /// In en, this message translates to:
  /// **'Joined {time}'**
  String clubCashGameJoinedTime(String time);

  /// No description provided for @clubCashGameJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get clubCashGameJustNow;

  /// No description provided for @clubCashGameMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String clubCashGameMinutesAgo(int count);

  /// No description provided for @clubCashGameHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String clubCashGameHoursAgo(int count);

  /// No description provided for @clubCashGameDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String clubCashGameDaysAgo(int count);

  /// No description provided for @clubCashGameAddTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get clubCashGameAddTable;

  /// No description provided for @clubCashGameNewTableName.
  ///
  /// In en, this message translates to:
  /// **'New table name (optional)'**
  String get clubCashGameNewTableName;

  /// No description provided for @clubCashGameAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get clubCashGameAdd;

  /// No description provided for @clubCashGameAddedToGroup.
  ///
  /// In en, this message translates to:
  /// **'Added {tableName} to the group'**
  String clubCashGameAddedToGroup(String tableName);

  /// No description provided for @clubCashGameAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add table: {error}'**
  String clubCashGameAddFailed(String error);

  /// No description provided for @clubCashGameAttachFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to attach table: {error}'**
  String clubCashGameAttachFailed(String error);

  /// No description provided for @clubCashGameAvailableTables.
  ///
  /// In en, this message translates to:
  /// **'Available tables'**
  String get clubCashGameAvailableTables;

  /// No description provided for @clubCashGameInUseByOther.
  ///
  /// In en, this message translates to:
  /// **'In use by other events'**
  String get clubCashGameInUseByOther;

  /// No description provided for @clubCashGameNoOtherTables.
  ///
  /// In en, this message translates to:
  /// **'No other tables in this club yet'**
  String get clubCashGameNoOtherTables;

  /// No description provided for @clubCashGameInUseBy.
  ///
  /// In en, this message translates to:
  /// **'In use by {eventName}'**
  String clubCashGameInUseBy(String eventName);

  /// No description provided for @clubCashGameSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats {count}'**
  String clubCashGameSeats(int count);

  /// No description provided for @memberEventTablesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} tables • {occupied} seated • {open} open'**
  String memberEventTablesSummary(int count, int occupied, int open);

  /// No description provided for @memberEventJoinedWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Joined waitlist at position #{position}'**
  String memberEventJoinedWaitlist(int position);

  /// No description provided for @memberEventJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join waitlist: {error}'**
  String memberEventJoinFailed(String error);

  /// No description provided for @memberEventLeftWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Left the waitlist'**
  String get memberEventLeftWaitlist;

  /// No description provided for @memberEventLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave waitlist: {error}'**
  String memberEventLeaveFailed(String error);

  /// No description provided for @memberEventWaitlistPosition.
  ///
  /// In en, this message translates to:
  /// **'Position #{position} in waitlist'**
  String memberEventWaitlistPosition(int position);

  /// No description provided for @memberEventTotalWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} total waiting'**
  String memberEventTotalWaiting(int count);

  /// No description provided for @memberEventLeaveWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Leave Waitlist'**
  String get memberEventLeaveWaitlist;

  /// No description provided for @memberEventJoinWaitlistWithCount.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist ({count} waiting)'**
  String memberEventJoinWaitlistWithCount(int count);

  /// No description provided for @memberEventJoinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist'**
  String get memberEventJoinWaitlist;

  /// No description provided for @memberEventAllTablesFull.
  ///
  /// In en, this message translates to:
  /// **'All tables are full'**
  String get memberEventAllTablesFull;

  /// No description provided for @dealerHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dealer Mode'**
  String get dealerHomeTitle;

  /// No description provided for @dealerHomeNoClubs.
  ///
  /// In en, this message translates to:
  /// **'No Clubs Found'**
  String get dealerHomeNoClubs;

  /// No description provided for @dealerHomeNoClubsOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Create your first club to get started.'**
  String get dealerHomeNoClubsOwnerHint;

  /// No description provided for @dealerHomeNoClubsMemberHint.
  ///
  /// In en, this message translates to:
  /// **'You are not a member of any clubs yet.\nAsk a club owner to invite you.'**
  String get dealerHomeNoClubsMemberHint;

  /// No description provided for @dealerHomeCreateClub.
  ///
  /// In en, this message translates to:
  /// **'Create Club'**
  String get dealerHomeCreateClub;

  /// No description provided for @dealerHomeDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get dealerHomeDealer;

  /// No description provided for @dealerHomeClubCount.
  ///
  /// In en, this message translates to:
  /// **'{count} clubs'**
  String dealerHomeClubCount(int count);

  /// No description provided for @dealerHomeActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'Active Sessions'**
  String get dealerHomeActiveSessions;

  /// No description provided for @dealerHomeClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get dealerHomeClubs;

  /// No description provided for @dealerHomeTables.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get dealerHomeTables;

  /// No description provided for @dealerHomeAddTable.
  ///
  /// In en, this message translates to:
  /// **'Add Table'**
  String get dealerHomeAddTable;

  /// No description provided for @dealerHomeTableNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Table Name'**
  String get dealerHomeTableNameLabel;

  /// No description provided for @dealerHomeTableNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Table 1, Main Table'**
  String get dealerHomeTableNameHint;

  /// No description provided for @dealerHomeTableAdded.
  ///
  /// In en, this message translates to:
  /// **'Table \"{name}\" added to {clubName}!'**
  String dealerHomeTableAdded(String name, String clubName);

  /// No description provided for @dealerHomeAddTableFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add table: {error}'**
  String dealerHomeAddTableFailed(String error);

  /// No description provided for @dealerHomeClubName.
  ///
  /// In en, this message translates to:
  /// **'Club Name'**
  String get dealerHomeClubName;

  /// No description provided for @dealerHomeCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get dealerHomeCreate;

  /// No description provided for @dealerHomeClubCreated.
  ///
  /// In en, this message translates to:
  /// **'Club \"{name}\" created successfully!'**
  String dealerHomeClubCreated(String name);

  /// No description provided for @dealerHomeClubCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create club: {error}'**
  String dealerHomeClubCreateFailed(String error);

  /// No description provided for @dealerHomeNoTables.
  ///
  /// In en, this message translates to:
  /// **'No tables in this club'**
  String get dealerHomeNoTables;

  /// No description provided for @dealerHomeActiveHand.
  ///
  /// In en, this message translates to:
  /// **'Active - Hand #{number}'**
  String dealerHomeActiveHand(int number);

  /// No description provided for @dealerHomeInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get dealerHomeInactive;

  /// No description provided for @dealerHomeResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get dealerHomeResume;

  /// No description provided for @dealerHomeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get dealerHomeStart;

  /// No description provided for @dealerHomeSessionSettings.
  ///
  /// In en, this message translates to:
  /// **'Session Settings'**
  String get dealerHomeSessionSettings;

  /// No description provided for @dealerHomeSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get dealerHomeSmallBlind;

  /// No description provided for @dealerHomeBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get dealerHomeBigBlind;

  /// No description provided for @dealerHomeBBAnte.
  ///
  /// In en, this message translates to:
  /// **'BB Ante'**
  String get dealerHomeBBAnte;

  /// No description provided for @dealerHomeGameType.
  ///
  /// In en, this message translates to:
  /// **'Game Type'**
  String get dealerHomeGameType;

  /// No description provided for @dealerHomeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get dealerHomeCash;

  /// No description provided for @dealerHomeTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get dealerHomeTournament;

  /// No description provided for @dealerHomeButtonPosition.
  ///
  /// In en, this message translates to:
  /// **'Button Position'**
  String get dealerHomeButtonPosition;

  /// No description provided for @dealerHomeStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get dealerHomeStartSession;

  /// No description provided for @dealerHomeCouldNotFind.
  ///
  /// In en, this message translates to:
  /// **'Could not find club or table'**
  String get dealerHomeCouldNotFind;

  /// No description provided for @dealerHomeStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start session: {error}'**
  String dealerHomeStartFailed(String error);

  /// No description provided for @dealerHomeErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String dealerHomeErrorLoading(String error);

  /// No description provided for @dealerHomeTableCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tables'**
  String dealerHomeTableCount(int count);

  /// No description provided for @dealerTableFailedStartHand.
  ///
  /// In en, this message translates to:
  /// **'Failed to start hand: {error}'**
  String dealerTableFailedStartHand(String error);

  /// No description provided for @dealerTableChopSummary.
  ///
  /// In en, this message translates to:
  /// **'Chop: {winners} split {amount}'**
  String dealerTableChopSummary(String winners, String amount);

  /// No description provided for @dealerTableWins.
  ///
  /// In en, this message translates to:
  /// **'{name} wins {amount}'**
  String dealerTableWins(String name, String amount);

  /// No description provided for @dealerTablePotChopped.
  ///
  /// In en, this message translates to:
  /// **'Pot chopped between {names}'**
  String dealerTablePotChopped(String names);

  /// No description provided for @dealerTableFailedCompleteHand.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete hand: {error}'**
  String dealerTableFailedCompleteHand(String error);

  /// No description provided for @dealerTablePlayerBusted.
  ///
  /// In en, this message translates to:
  /// **'{name} Busted!'**
  String dealerTablePlayerBusted(String name);

  /// No description provided for @dealerTableNoChipsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Seat {seatNumber} has no chips remaining.\nRebuy amount: {amount}'**
  String dealerTableNoChipsRemaining(int seatNumber, String amount);

  /// No description provided for @dealerTableRemovePlayer.
  ///
  /// In en, this message translates to:
  /// **'Remove Player'**
  String get dealerTableRemovePlayer;

  /// No description provided for @dealerTableRebuy.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get dealerTableRebuy;

  /// No description provided for @dealerTableRebuysFor.
  ///
  /// In en, this message translates to:
  /// **'{name} rebuys for {amount}'**
  String dealerTableRebuysFor(String name, String amount);

  /// No description provided for @dealerTableFinishesIn.
  ///
  /// In en, this message translates to:
  /// **'{name} finishes in {position} place'**
  String dealerTableFinishesIn(String name, String position);

  /// No description provided for @dealerTableEndSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'End Session?'**
  String get dealerTableEndSessionTitle;

  /// No description provided for @dealerTableEndSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end this session?'**
  String get dealerTableEndSessionBody;

  /// No description provided for @dealerTableEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get dealerTableEnd;

  /// No description provided for @dealerTableDealerChange.
  ///
  /// In en, this message translates to:
  /// **'Dealer Change'**
  String get dealerTableDealerChange;

  /// No description provided for @dealerTableDealerChangeBody.
  ///
  /// In en, this message translates to:
  /// **'The session will be paused and another dealer can scan the table QR code to continue where you left off.'**
  String get dealerTableDealerChangeBody;

  /// No description provided for @dealerTableDealerChangePreserve.
  ///
  /// In en, this message translates to:
  /// **'All players, blinds, and game state will be preserved.'**
  String get dealerTableDealerChangePreserve;

  /// No description provided for @dealerTableDealerChangeResume.
  ///
  /// In en, this message translates to:
  /// **'You can also resume this session yourself later.'**
  String get dealerTableDealerChangeResume;

  /// No description provided for @dealerTableHandOff.
  ///
  /// In en, this message translates to:
  /// **'Hand Off'**
  String get dealerTableHandOff;

  /// No description provided for @dealerTableSessionPaused.
  ///
  /// In en, this message translates to:
  /// **'Session paused. Another dealer can now take over.'**
  String get dealerTableSessionPaused;

  /// No description provided for @dealerTablePauseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pause session: {error}'**
  String dealerTablePauseFailed(String error);

  /// No description provided for @dealerTableEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'Event Cancelled'**
  String get dealerTableEventCancelled;

  /// No description provided for @dealerTableEventFinished.
  ///
  /// In en, this message translates to:
  /// **'Event Finished'**
  String get dealerTableEventFinished;

  /// No description provided for @dealerTableEventCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'The club admin has cancelled this event. All sessions have been saved.'**
  String get dealerTableEventCancelledBody;

  /// No description provided for @dealerTableEventFinishedBody.
  ///
  /// In en, this message translates to:
  /// **'The club admin has finished this event. All sessions have been saved.'**
  String get dealerTableEventFinishedBody;

  /// No description provided for @dealerTableSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session Ended'**
  String get dealerTableSessionEnded;

  /// No description provided for @dealerTableSessionEndedBody.
  ///
  /// In en, this message translates to:
  /// **'This session has been ended. All data has been saved.'**
  String get dealerTableSessionEndedBody;

  /// No description provided for @dealerTableLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave dealer table?'**
  String get dealerTableLeaveTitle;

  /// No description provided for @dealerTableLeaveActiveHand.
  ///
  /// In en, this message translates to:
  /// **'A hand is currently in progress. Leaving now may disrupt logging.'**
  String get dealerTableLeaveActiveHand;

  /// No description provided for @dealerTableLeaveInactive.
  ///
  /// In en, this message translates to:
  /// **'The session stays live. You can return any time.'**
  String get dealerTableLeaveInactive;

  /// No description provided for @dealerTableAutoCorrection.
  ///
  /// In en, this message translates to:
  /// **'Auto-corrected \"{detected}\" → \"{corrected}\"'**
  String dealerTableAutoCorrection(String detected, String corrected);

  /// No description provided for @dealerTableApprovePlayer.
  ///
  /// In en, this message translates to:
  /// **'Approve {name}?'**
  String dealerTableApprovePlayer(String name);

  /// No description provided for @dealerTableStartingChipStack.
  ///
  /// In en, this message translates to:
  /// **'Starting Chip Stack'**
  String get dealerTableStartingChipStack;

  /// No description provided for @dealerTablePlayerRejected.
  ///
  /// In en, this message translates to:
  /// **'{name} rejected'**
  String dealerTablePlayerRejected(String name);

  /// No description provided for @dealerTableRejectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject: {error}'**
  String dealerTableRejectFailed(String error);

  /// No description provided for @dealerTablePlayerJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined with {amount}'**
  String dealerTablePlayerJoined(String name, String amount);

  /// No description provided for @dealerTableApproveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve: {error}'**
  String dealerTableApproveFailed(String error);

  /// No description provided for @dealerTableChipStack.
  ///
  /// In en, this message translates to:
  /// **'Chip Stack'**
  String get dealerTableChipStack;

  /// No description provided for @dealerTableSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dealerTableSave;

  /// No description provided for @liveSessionHand.
  ///
  /// In en, this message translates to:
  /// **'HAND'**
  String get liveSessionHand;

  /// No description provided for @liveSessionPot.
  ///
  /// In en, this message translates to:
  /// **'POT'**
  String get liveSessionPot;

  /// No description provided for @liveSessionStatus.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get liveSessionStatus;

  /// No description provided for @liveSessionLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveSessionLive;

  /// No description provided for @liveSessionWaiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get liveSessionWaiting;

  /// No description provided for @liveSessionWinnerSummary.
  ///
  /// In en, this message translates to:
  /// **'{winner} wins \${amount}'**
  String liveSessionWinnerSummary(String winner, String amount);

  /// No description provided for @liveSessionSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Session Ended'**
  String get liveSessionSessionEnded;

  /// No description provided for @liveSessionSessionEndedBody.
  ///
  /// In en, this message translates to:
  /// **'The dealer has ended this session.'**
  String get liveSessionSessionEndedBody;

  /// No description provided for @liveSessionLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Table?'**
  String get liveSessionLeaveTitle;

  /// No description provided for @liveSessionLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this table?'**
  String get liveSessionLeaveBody;

  /// No description provided for @liveSessionLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get liveSessionLeave;

  /// No description provided for @liveSessionLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave: {error}'**
  String liveSessionLeaveFailed(String error);

  /// No description provided for @liveSessionLeaveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Leave Table'**
  String get liveSessionLeaveTooltip;

  /// No description provided for @liveSessionSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}'**
  String liveSessionSeat(int number);

  /// No description provided for @liveSessionYourSeat.
  ///
  /// In en, this message translates to:
  /// **'Your Seat'**
  String get liveSessionYourSeat;

  /// No description provided for @liveSessionStack.
  ///
  /// In en, this message translates to:
  /// **'Stack: {amount}'**
  String liveSessionStack(String amount);

  /// No description provided for @liveSessionWaitingForDealer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for dealer...'**
  String get liveSessionWaitingForDealer;

  /// No description provided for @liveSessionOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get liveSessionOffline;

  /// No description provided for @liveSessionRecentActions.
  ///
  /// In en, this message translates to:
  /// **'Recent Actions'**
  String get liveSessionRecentActions;

  /// No description provided for @liveSessionWaitingForAction.
  ///
  /// In en, this message translates to:
  /// **'Waiting for action...'**
  String get liveSessionWaitingForAction;

  /// No description provided for @liveSessionD.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get liveSessionD;

  /// No description provided for @qrScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Table QR'**
  String get qrScanTitle;

  /// No description provided for @qrScanInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code. Please scan a valid poker table QR code.'**
  String get qrScanInvalidCode;

  /// No description provided for @qrScanError.
  ///
  /// In en, this message translates to:
  /// **'Error processing QR code: {error}'**
  String qrScanError(String error);

  /// No description provided for @qrScanInstructions.
  ///
  /// In en, this message translates to:
  /// **'Point your camera at the QR code on the table to join'**
  String get qrScanInstructions;

  /// No description provided for @clubRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Requests'**
  String get clubRequestsTitle;

  /// No description provided for @clubRequestsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get clubRequestsAll;

  /// No description provided for @clubRequestsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get clubRequestsPending;

  /// No description provided for @clubRequestsApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get clubRequestsApproved;

  /// No description provided for @clubRequestsRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get clubRequestsRejected;

  /// No description provided for @clubRequestsApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Request'**
  String get clubRequestsApproveTitle;

  /// No description provided for @clubRequestsApproveBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve \"{name}\"? This will create a new club and add you as the admin.'**
  String clubRequestsApproveBody(String name);

  /// No description provided for @clubRequestsRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Request'**
  String get clubRequestsRejectTitle;

  /// No description provided for @clubRequestsRejectBody.
  ///
  /// In en, this message translates to:
  /// **'Please provide a reason for rejecting \"{name}\":'**
  String clubRequestsRejectBody(String name);

  /// No description provided for @clubRequestsRejectHint.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection...'**
  String get clubRequestsRejectHint;

  /// No description provided for @clubRequestsApproveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get clubRequestsApproveButton;

  /// No description provided for @clubRequestsRejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get clubRequestsRejectButton;

  /// No description provided for @clubRequestsApproved2.
  ///
  /// In en, this message translates to:
  /// **'{name} has been approved!'**
  String clubRequestsApproved2(String name);

  /// No description provided for @clubRequestsRejected2.
  ///
  /// In en, this message translates to:
  /// **'{name} has been rejected.'**
  String clubRequestsRejected2(String name);

  /// No description provided for @clubRequestsNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get clubRequestsNoRequests;

  /// No description provided for @clubRequestsPendingBadge.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get clubRequestsPendingBadge;

  /// No description provided for @clubRequestsApprovedBadge.
  ///
  /// In en, this message translates to:
  /// **'APPROVED'**
  String get clubRequestsApprovedBadge;

  /// No description provided for @clubRequestsRejectedBadge.
  ///
  /// In en, this message translates to:
  /// **'REJECTED'**
  String get clubRequestsRejectedBadge;

  /// No description provided for @clubRequestsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get clubRequestsAddress;

  /// No description provided for @clubRequestsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get clubRequestsPhone;

  /// No description provided for @clubRequestsAdminEmail.
  ///
  /// In en, this message translates to:
  /// **'Admin Email'**
  String get clubRequestsAdminEmail;

  /// No description provided for @clubRequestsRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested By'**
  String get clubRequestsRequestedBy;

  /// No description provided for @clubRequestsRequesterEmail.
  ///
  /// In en, this message translates to:
  /// **'Requester Email'**
  String get clubRequestsRequesterEmail;

  /// No description provided for @clubRequestsRequestedAt.
  ///
  /// In en, this message translates to:
  /// **'Requested At'**
  String get clubRequestsRequestedAt;

  /// No description provided for @clubRequestsReviewedAt.
  ///
  /// In en, this message translates to:
  /// **'Reviewed At'**
  String get clubRequestsReviewedAt;

  /// No description provided for @clubRequestsRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason:'**
  String get clubRequestsRejectionReason;

  /// No description provided for @supportRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Requests'**
  String get supportRequestsTitle;

  /// No description provided for @supportRequestsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get supportRequestsAll;

  /// No description provided for @supportRequestsPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get supportRequestsPending;

  /// No description provided for @supportRequestsClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get supportRequestsClosed;

  /// No description provided for @supportRequestsResolveTitle.
  ///
  /// In en, this message translates to:
  /// **'Resolve Request'**
  String get supportRequestsResolveTitle;

  /// No description provided for @supportRequestsResolveBody.
  ///
  /// In en, this message translates to:
  /// **'Optional response to the user:'**
  String get supportRequestsResolveBody;

  /// No description provided for @supportRequestsResponseHint.
  ///
  /// In en, this message translates to:
  /// **'Response (optional)...'**
  String get supportRequestsResponseHint;

  /// No description provided for @supportRequestsResolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get supportRequestsResolve;

  /// No description provided for @supportRequestsResolved.
  ///
  /// In en, this message translates to:
  /// **'Request resolved'**
  String get supportRequestsResolved;

  /// No description provided for @supportRequestsRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Request'**
  String get supportRequestsRejectTitle;

  /// No description provided for @supportRequestsRejectBody.
  ///
  /// In en, this message translates to:
  /// **'Reason for rejection:'**
  String get supportRequestsRejectBody;

  /// No description provided for @supportRequestsRejectHint.
  ///
  /// In en, this message translates to:
  /// **'Reason...'**
  String get supportRequestsRejectHint;

  /// No description provided for @supportRequestsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get supportRequestsReject;

  /// No description provided for @supportRequestsRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get supportRequestsRejected;

  /// No description provided for @supportRequestsNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get supportRequestsNoRequests;

  /// No description provided for @supportRequestsPendingBadge.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get supportRequestsPendingBadge;

  /// No description provided for @supportRequestsResolvedBadge.
  ///
  /// In en, this message translates to:
  /// **'RESOLVED'**
  String get supportRequestsResolvedBadge;

  /// No description provided for @supportRequestsRejectedBadge.
  ///
  /// In en, this message translates to:
  /// **'REJECTED'**
  String get supportRequestsRejectedBadge;

  /// No description provided for @supportRequestsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get supportRequestsCategory;

  /// No description provided for @supportRequestsUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get supportRequestsUser;

  /// No description provided for @supportRequestsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get supportRequestsEmail;

  /// No description provided for @supportRequestsSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get supportRequestsSubmitted;

  /// No description provided for @supportRequestsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get supportRequestsDescription;

  /// No description provided for @supportRequestsAdminResponse.
  ///
  /// In en, this message translates to:
  /// **'Admin Response'**
  String get supportRequestsAdminResponse;

  /// No description provided for @supportRequestsBugReport.
  ///
  /// In en, this message translates to:
  /// **'Bug Report'**
  String get supportRequestsBugReport;

  /// No description provided for @supportRequestsFeatureRequest.
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get supportRequestsFeatureRequest;

  /// No description provided for @supportRequestsAccountIssue.
  ///
  /// In en, this message translates to:
  /// **'Account Issue'**
  String get supportRequestsAccountIssue;

  /// No description provided for @debugHandViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Debug Hand Viewer'**
  String get debugHandViewerTitle;

  /// No description provided for @debugHandViewerSessionName.
  ///
  /// In en, this message translates to:
  /// **'Session Name'**
  String get debugHandViewerSessionName;

  /// No description provided for @debugHandViewerHandNumbers.
  ///
  /// In en, this message translates to:
  /// **'Hand Numbers (comma-separated, e.g., 27,28)'**
  String get debugHandViewerHandNumbers;

  /// No description provided for @debugHandViewerFetchData.
  ///
  /// In en, this message translates to:
  /// **'Fetch Data'**
  String get debugHandViewerFetchData;

  /// No description provided for @debugHandViewerCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get debugHandViewerCopied;

  /// No description provided for @debugHandViewerNoData.
  ///
  /// In en, this message translates to:
  /// **'No data yet. Enter session name and click Fetch Data.'**
  String get debugHandViewerNoData;

  /// No description provided for @navDrawerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navDrawerSettings;

  /// No description provided for @navDrawerRegisterClub.
  ///
  /// In en, this message translates to:
  /// **'Register Club'**
  String get navDrawerRegisterClub;

  /// No description provided for @navDrawerHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get navDrawerHelpSupport;

  /// No description provided for @navDrawerLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get navDrawerLogOut;

  /// No description provided for @navDrawerUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get navDrawerUpgrade;

  /// No description provided for @navDrawerUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get navDrawerUserFallback;

  /// No description provided for @navDrawerStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get navDrawerStatistics;

  /// No description provided for @navDrawerEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navDrawerEvents;

  /// No description provided for @navDrawerBankroll.
  ///
  /// In en, this message translates to:
  /// **'Bankroll'**
  String get navDrawerBankroll;

  /// No description provided for @navDrawerClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get navDrawerClubs;

  /// No description provided for @navDrawerNoClubsYet.
  ///
  /// In en, this message translates to:
  /// **'No clubs yet'**
  String get navDrawerNoClubsYet;

  /// No description provided for @navDrawerMemberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String navDrawerMemberCount(int count);

  /// No description provided for @navDrawerRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get navDrawerRoleAdmin;

  /// No description provided for @navDrawerRoleDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get navDrawerRoleDealer;

  /// No description provided for @navDrawerRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get navDrawerRoleMember;

  /// No description provided for @navDrawerVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.0'**
  String get navDrawerVersion;

  /// No description provided for @navDrawerLastLoginToday.
  ///
  /// In en, this message translates to:
  /// **'Last login: Today'**
  String get navDrawerLastLoginToday;

  /// No description provided for @navDrawerNoEarningsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Earnings Data Yet'**
  String get navDrawerNoEarningsTitle;

  /// No description provided for @navDrawerNoEarningsBody.
  ///
  /// In en, this message translates to:
  /// **'Add some session results first to view your earnings chart. You can add results from the Profile page.'**
  String get navDrawerNoEarningsBody;

  /// No description provided for @navDrawerSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get navDrawerSignOutTitle;

  /// No description provided for @navDrawerSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get navDrawerSignOutMessage;

  /// No description provided for @navDrawerSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get navDrawerSignOut;

  /// No description provided for @multiPotMainPot.
  ///
  /// In en, this message translates to:
  /// **'Main Pot'**
  String get multiPotMainPot;

  /// No description provided for @multiPotSidePot.
  ///
  /// In en, this message translates to:
  /// **'Side Pot {index}'**
  String multiPotSidePot(int index);

  /// No description provided for @multiPotPlayerFallback.
  ///
  /// In en, this message translates to:
  /// **'Player {id}'**
  String multiPotPlayerFallback(String id);

  /// No description provided for @multiPotMainPotWinner.
  ///
  /// In en, this message translates to:
  /// **'main pot winner'**
  String get multiPotMainPotWinner;

  /// No description provided for @multiPotEligibleFromPrevious.
  ///
  /// In en, this message translates to:
  /// **'eligible from previous pot'**
  String get multiPotEligibleFromPrevious;

  /// No description provided for @multiPotAutoAwarded.
  ///
  /// In en, this message translates to:
  /// **'Auto-awarded to {name} ({reason})'**
  String multiPotAutoAwarded(String name, String reason);

  /// No description provided for @multiPotChoppedPot.
  ///
  /// In en, this message translates to:
  /// **'Chopped Pot'**
  String get multiPotChoppedPot;

  /// No description provided for @multiPotSingleWinner.
  ///
  /// In en, this message translates to:
  /// **'Single Winner'**
  String get multiPotSingleWinner;

  /// No description provided for @multiPotSelectAllWinners.
  ///
  /// In en, this message translates to:
  /// **'Select all winners:'**
  String get multiPotSelectAllWinners;

  /// No description provided for @multiPotSelectTheWinner.
  ///
  /// In en, this message translates to:
  /// **'Select the winner:'**
  String get multiPotSelectTheWinner;

  /// No description provided for @multiPotSelectWinnersTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Winners'**
  String get multiPotSelectWinnersTitle;

  /// No description provided for @multiPotMultiplePots.
  ///
  /// In en, this message translates to:
  /// **'Multiple pots - select winner for each pot'**
  String get multiPotMultiplePots;

  /// No description provided for @winnerSelectionWhoChopped.
  ///
  /// In en, this message translates to:
  /// **'Who chopped this pot?'**
  String get winnerSelectionWhoChopped;

  /// No description provided for @winnerSelectionWhoWon.
  ///
  /// In en, this message translates to:
  /// **'Who won this hand?'**
  String get winnerSelectionWhoWon;

  /// No description provided for @winnerSelectionChoppedPot.
  ///
  /// In en, this message translates to:
  /// **'Chopped Pot'**
  String get winnerSelectionChoppedPot;

  /// No description provided for @winnerSelectionIndividualShares.
  ///
  /// In en, this message translates to:
  /// **'Individual shares:'**
  String get winnerSelectionIndividualShares;

  /// No description provided for @winnerSelectionSelectAllWinners.
  ///
  /// In en, this message translates to:
  /// **'Select all winners:'**
  String get winnerSelectionSelectAllWinners;

  /// No description provided for @winnerSelectionTapTheWinner.
  ///
  /// In en, this message translates to:
  /// **'Tap the winner:'**
  String get winnerSelectionTapTheWinner;

  /// No description provided for @winnerSelectionLongPressHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press for chopped pot'**
  String get winnerSelectionLongPressHint;

  /// No description provided for @winnerSelectionConfirmChop.
  ///
  /// In en, this message translates to:
  /// **'Confirm Chop'**
  String get winnerSelectionConfirmChop;

  /// No description provided for @winnerSelectionConfirmWinner.
  ///
  /// In en, this message translates to:
  /// **'Confirm Winner'**
  String get winnerSelectionConfirmWinner;

  /// No description provided for @winnerSelectionBackToSingle.
  ///
  /// In en, this message translates to:
  /// **'Back to Single Winner'**
  String get winnerSelectionBackToSingle;

  /// No description provided for @boardCardsCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get boardCardsCards;

  /// No description provided for @boardCardsCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get boardCardsCard;

  /// No description provided for @allInBoardTitle.
  ///
  /// In en, this message translates to:
  /// **'All-In Board Cards'**
  String get allInBoardTitle;

  /// No description provided for @raiseSnapReleaseToType.
  ///
  /// In en, this message translates to:
  /// **'Release at min to type'**
  String get raiseSnapReleaseToType;

  /// No description provided for @slidingNotificationHeader.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATION'**
  String get slidingNotificationHeader;

  /// No description provided for @eventSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Nice! Your event is now on calendar.'**
  String get eventSuccessTitle;

  /// No description provided for @eventSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can edit or remove it anytime'**
  String get eventSuccessSubtitle;

  /// No description provided for @eventSuccessGoToCalendar.
  ///
  /// In en, this message translates to:
  /// **'Go to calendar'**
  String get eventSuccessGoToCalendar;

  /// No description provided for @eventSuccessAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Add another event'**
  String get eventSuccessAddAnother;

  /// No description provided for @stackChartNoData.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get stackChartNoData;

  /// No description provided for @stackChartStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get stackChartStart;

  /// No description provided for @stackChartRebuy.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get stackChartRebuy;

  /// No description provided for @stackChartEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get stackChartEnd;

  /// No description provided for @stackChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Stack Chart'**
  String get stackChartTitle;

  /// No description provided for @stackChartAvgGrowth.
  ///
  /// In en, this message translates to:
  /// **'Avg Growth'**
  String get stackChartAvgGrowth;

  /// No description provided for @stackChartDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get stackChartDuration;

  /// No description provided for @stackChartProfitLoss.
  ///
  /// In en, this message translates to:
  /// **'P/L'**
  String get stackChartProfitLoss;

  /// No description provided for @actionGridSelectAction.
  ///
  /// In en, this message translates to:
  /// **'Select Action'**
  String get actionGridSelectAction;

  /// No description provided for @pokerTablePlayerFallback.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get pokerTablePlayerFallback;

  /// No description provided for @loadingDefault.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingDefault;

  /// No description provided for @forgotPasswordFailedSendCode.
  ///
  /// In en, this message translates to:
  /// **'Failed to send code. Please try again.'**
  String get forgotPasswordFailedSendCode;

  /// No description provided for @forgotPasswordNewCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New code sent to your email.'**
  String get forgotPasswordNewCodeSent;

  /// No description provided for @forgotPasswordFailedResend.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend code.'**
  String get forgotPasswordFailedResend;

  /// No description provided for @forgotPasswordEnterFullCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter the full 6-digit code.'**
  String get forgotPasswordEnterFullCode;

  /// No description provided for @forgotPasswordInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code. Please try again.'**
  String get forgotPasswordInvalidCode;

  /// No description provided for @forgotPasswordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successfully! Please sign in.'**
  String get forgotPasswordResetSuccess;

  /// No description provided for @forgotPasswordResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordResetTitle;

  /// No description provided for @forgotPasswordResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a verification code'**
  String get forgotPasswordResetSubtitle;

  /// No description provided for @forgotPasswordCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get forgotPasswordCheckEmail;

  /// No description provided for @forgotPasswordSetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get forgotPasswordSetNewPassword;

  /// No description provided for @forgotPasswordSetNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a strong password for your account'**
  String get forgotPasswordSetNewSubtitle;

  /// No description provided for @forgotPasswordEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get forgotPasswordEmail;

  /// No description provided for @forgotPasswordEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get forgotPasswordEnterEmail;

  /// No description provided for @forgotPasswordValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get forgotPasswordValidEmail;

  /// No description provided for @forgotPasswordSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get forgotPasswordSendCode;

  /// No description provided for @forgotPasswordVerifyCode.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get forgotPasswordVerifyCode;

  /// No description provided for @forgotPasswordResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get forgotPasswordResendCode;

  /// No description provided for @forgotPasswordResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {time}'**
  String forgotPasswordResendIn(String time);

  /// No description provided for @forgotPasswordNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get forgotPasswordNewPassword;

  /// No description provided for @forgotPasswordEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get forgotPasswordEnterPassword;

  /// No description provided for @forgotPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get forgotPasswordMinLength;

  /// No description provided for @forgotPasswordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get forgotPasswordConfirm;

  /// No description provided for @forgotPasswordConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get forgotPasswordConfirmRequired;

  /// No description provided for @forgotPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get forgotPasswordMismatch;

  /// No description provided for @forgotPasswordResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get forgotPasswordResetButton;

  /// No description provided for @onboardingTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'TRACK EVERY\nHAND'**
  String get onboardingTrackTitle;

  /// No description provided for @onboardingTrackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log actions, board cards, and results for every hand you play — live or after the session.'**
  String get onboardingTrackSubtitle;

  /// No description provided for @onboardingKnowTitle.
  ///
  /// In en, this message translates to:
  /// **'KNOW YOUR\nGAME'**
  String get onboardingKnowTitle;

  /// No description provided for @onboardingKnowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'VPIP, PFR, 3-Bet, C-Bet and more — see your stats evolve in real time.'**
  String get onboardingKnowSubtitle;

  /// No description provided for @onboardingClubsTitle.
  ///
  /// In en, this message translates to:
  /// **'PLAY AT\nCLUBS'**
  String get onboardingClubsTitle;

  /// No description provided for @onboardingClubsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join live events, see rankings, and track your opponents across sessions.'**
  String get onboardingClubsSubtitle;

  /// No description provided for @dealerTableEnterStartingStack.
  ///
  /// In en, this message translates to:
  /// **'Enter Starting Stack'**
  String get dealerTableEnterStartingStack;

  /// No description provided for @dealerTableNoPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending join requests'**
  String get dealerTableNoPendingRequests;

  /// No description provided for @dealerTablePendingJoinRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Join Requests'**
  String get dealerTablePendingJoinRequests;

  /// No description provided for @dealerTableUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get dealerTableUnknown;

  /// No description provided for @dealerTableSeatNumber.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}'**
  String dealerTableSeatNumber(int number);

  /// No description provided for @dealerTableReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get dealerTableReview;

  /// No description provided for @dealerTableSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get dealerTableSmallBlind;

  /// No description provided for @dealerTableBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get dealerTableBigBlind;

  /// No description provided for @dealerTableNewBlindsNote.
  ///
  /// In en, this message translates to:
  /// **'New blinds will apply from the next hand.'**
  String get dealerTableNewBlindsNote;

  /// No description provided for @dealerTableSmallMustBeLess.
  ///
  /// In en, this message translates to:
  /// **'Small blind must be less than big blind'**
  String get dealerTableSmallMustBeLess;

  /// No description provided for @dealerTableBlindsMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Blinds must be greater than 0'**
  String get dealerTableBlindsMustBePositive;

  /// No description provided for @dealerTableBlindsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Blinds updated to {sb}/{bb}'**
  String dealerTableBlindsUpdated(String sb, String bb);

  /// No description provided for @dealerTableFailedUpdateBlinds.
  ///
  /// In en, this message translates to:
  /// **'Failed to update blinds: {error}'**
  String dealerTableFailedUpdateBlinds(String error);

  /// No description provided for @dealerTableFailedMoveButton.
  ///
  /// In en, this message translates to:
  /// **'Failed to move button: {error}'**
  String dealerTableFailedMoveButton(String error);

  /// No description provided for @dealerTablePending.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get dealerTablePending;

  /// No description provided for @dealerTableConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection Lost'**
  String get dealerTableConnectionLost;

  /// No description provided for @dealerTableReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Attempting to reconnect...'**
  String get dealerTableReconnecting;

  /// No description provided for @dealerTableReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get dealerTableReconnect;

  /// No description provided for @dealerTableResetHandTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Hand?'**
  String get dealerTableResetHandTitle;

  /// No description provided for @dealerTableResetHandBody.
  ///
  /// In en, this message translates to:
  /// **'All actions have been undone. Would you like to start a new hand?'**
  String get dealerTableResetHandBody;

  /// No description provided for @dealerTableKeepCurrent.
  ///
  /// In en, this message translates to:
  /// **'Keep Current'**
  String get dealerTableKeepCurrent;

  /// No description provided for @dealerTableNewHand.
  ///
  /// In en, this message translates to:
  /// **'New Hand'**
  String get dealerTableNewHand;

  /// No description provided for @dealerTableHandReset.
  ///
  /// In en, this message translates to:
  /// **'Hand reset - ready for new hand'**
  String get dealerTableHandReset;

  /// No description provided for @dealerTableAddPlayerToSeat.
  ///
  /// In en, this message translates to:
  /// **'Add Player to Seat {number}'**
  String dealerTableAddPlayerToSeat(int number);

  /// No description provided for @dealerTableSearchUser.
  ///
  /// In en, this message translates to:
  /// **'Search User'**
  String get dealerTableSearchUser;

  /// No description provided for @dealerTableManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get dealerTableManualEntry;

  /// No description provided for @dealerTableSearchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by Name'**
  String get dealerTableSearchByName;

  /// No description provided for @dealerTableTypeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type to search users...'**
  String get dealerTableTypeToSearch;

  /// No description provided for @dealerTableNoUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found. Try manual entry.'**
  String get dealerTableNoUsersFound;

  /// No description provided for @dealerTablePlayerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Player Name'**
  String get dealerTablePlayerNameLabel;

  /// No description provided for @dealerTableEnterPlayerName.
  ///
  /// In en, this message translates to:
  /// **'Enter player name'**
  String get dealerTableEnterPlayerName;

  /// No description provided for @dealerTableAddPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add Player'**
  String get dealerTableAddPlayer;

  /// No description provided for @dealerTableEndSession.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get dealerTableEndSession;

  /// No description provided for @dealerTableUpdatedStack.
  ///
  /// In en, this message translates to:
  /// **'Updated {name} stack to {amount}'**
  String dealerTableUpdatedStack(String name, String amount);

  /// No description provided for @dealerTableFailedUpdateStack.
  ///
  /// In en, this message translates to:
  /// **'Failed to update stack: {error}'**
  String dealerTableFailedUpdateStack(String error);

  /// No description provided for @dealerTableSittingAtSeat.
  ///
  /// In en, this message translates to:
  /// **'You are now playing at Seat {number}'**
  String dealerTableSittingAtSeat(int number);

  /// No description provided for @dealerTableFailedSitAt.
  ///
  /// In en, this message translates to:
  /// **'Failed to sit at table: {error}'**
  String dealerTableFailedSitAt(String error);

  /// No description provided for @dealerTableFailedAddPlayer.
  ///
  /// In en, this message translates to:
  /// **'Failed to add player: {error}'**
  String dealerTableFailedAddPlayer(String error);

  /// No description provided for @dealerTableFailedRemovePlayer.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove player: {error}'**
  String dealerTableFailedRemovePlayer(String error);

  /// No description provided for @eventDetailEventType.
  ///
  /// In en, this message translates to:
  /// **'Event Type'**
  String get eventDetailEventType;

  /// No description provided for @eventDetailSeated.
  ///
  /// In en, this message translates to:
  /// **'Seated'**
  String get eventDetailSeated;

  /// No description provided for @eventDetailAreYouGoing.
  ///
  /// In en, this message translates to:
  /// **'ARE YOU GOING?'**
  String get eventDetailAreYouGoing;

  /// No description provided for @eventDetailAddedToCalendarBtn.
  ///
  /// In en, this message translates to:
  /// **'Added to Calendar'**
  String get eventDetailAddedToCalendarBtn;

  /// No description provided for @eventDetailAddToCalendarBtn.
  ///
  /// In en, this message translates to:
  /// **'Add to Calendar'**
  String get eventDetailAddToCalendarBtn;

  /// No description provided for @eventDetailWhosGoing.
  ///
  /// In en, this message translates to:
  /// **'Who\'s Coming'**
  String get eventDetailWhosGoing;

  /// No description provided for @eventDetailSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get eventDetailSeeAll;

  /// No description provided for @eventDetailStartDealing.
  ///
  /// In en, this message translates to:
  /// **'Start Dealing'**
  String get eventDetailStartDealing;

  /// No description provided for @eventDetailViewLiveRankings.
  ///
  /// In en, this message translates to:
  /// **'View Live Rankings'**
  String get eventDetailViewLiveRankings;

  /// No description provided for @eventDetailNotSeatedAtTable.
  ///
  /// In en, this message translates to:
  /// **'You are not currently seated at any table'**
  String get eventDetailNotSeatedAtTable;

  /// No description provided for @eventDetailNotSeatedInEvent.
  ///
  /// In en, this message translates to:
  /// **'You are not seated in this event'**
  String get eventDetailNotSeatedInEvent;

  /// No description provided for @eventDetailErrorFindingSeat.
  ///
  /// In en, this message translates to:
  /// **'Error finding your seat: {error}'**
  String eventDetailErrorFindingSeat(String error);

  /// No description provided for @eventDetailReturnToSeat.
  ///
  /// In en, this message translates to:
  /// **'Return to My Seat'**
  String get eventDetailReturnToSeat;

  /// No description provided for @eventDetailViewFinalStandings.
  ///
  /// In en, this message translates to:
  /// **'View Final Standings'**
  String get eventDetailViewFinalStandings;

  /// No description provided for @eventDetailManageTables.
  ///
  /// In en, this message translates to:
  /// **'Manage Tables'**
  String get eventDetailManageTables;

  /// No description provided for @eventDetailManageTable.
  ///
  /// In en, this message translates to:
  /// **'Manage Table'**
  String get eventDetailManageTable;

  /// No description provided for @eventDetailSeeAvailability.
  ///
  /// In en, this message translates to:
  /// **'See Availability'**
  String get eventDetailSeeAvailability;

  /// No description provided for @eventDetailYoureSeated.
  ///
  /// In en, this message translates to:
  /// **'You\'re Seated'**
  String get eventDetailYoureSeated;

  /// No description provided for @eventDetailNoTablesAssigned.
  ///
  /// In en, this message translates to:
  /// **'No tables assigned to this event'**
  String get eventDetailNoTablesAssigned;

  /// No description provided for @eventDetailStartEvent.
  ///
  /// In en, this message translates to:
  /// **'Start Event'**
  String get eventDetailStartEvent;

  /// No description provided for @eventDetailFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get eventDetailFinish;

  /// No description provided for @eventDetailFailedFinishCancel.
  ///
  /// In en, this message translates to:
  /// **'Failed to {action} event: {error}'**
  String eventDetailFailedFinishCancel(String action, String error);

  /// No description provided for @homeTableSeatInfo.
  ///
  /// In en, this message translates to:
  /// **'Table {table}, Seat #{seat}'**
  String homeTableSeatInfo(String table, String seat);

  /// No description provided for @homeRequestResolved.
  ///
  /// In en, this message translates to:
  /// **'Request Resolved'**
  String get homeRequestResolved;

  /// No description provided for @homeRequestClosed.
  ///
  /// In en, this message translates to:
  /// **'Request Closed'**
  String get homeRequestClosed;

  /// No description provided for @homeResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get homeResponse;

  /// No description provided for @homeErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String homeErrorGeneric(String error);

  /// No description provided for @homeErrorLoadingEvent.
  ///
  /// In en, this message translates to:
  /// **'Error loading event: {error}'**
  String homeErrorLoadingEvent(String error);

  /// No description provided for @homeFailedLoadEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to load event: {error}'**
  String homeFailedLoadEvent(String error);

  /// No description provided for @homeFailedUpdateEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to update event: {error}'**
  String homeFailedUpdateEvent(String error);

  /// No description provided for @homeErrorDeletingEvent.
  ///
  /// In en, this message translates to:
  /// **'Error deleting event: {error}'**
  String homeErrorDeletingEvent(String error);

  /// No description provided for @homeTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get homeTournament;

  /// No description provided for @homeCashGame.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get homeCashGame;

  /// No description provided for @commonErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonErrorGeneric(String error);

  /// No description provided for @commonLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get commonLeave;

  /// No description provided for @commonAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get commonAccept;

  /// No description provided for @commonLoadingHands.
  ///
  /// In en, this message translates to:
  /// **'Loading hands...'**
  String get commonLoadingHands;

  /// No description provided for @sessionHistoryButtonPosition.
  ///
  /// In en, this message translates to:
  /// **'Button Position: {position}'**
  String sessionHistoryButtonPosition(String position);

  /// No description provided for @sessionHistoryPlayerCount.
  ///
  /// In en, this message translates to:
  /// **'Player Count: {count}'**
  String sessionHistoryPlayerCount(String count);

  /// No description provided for @sessionHistoryStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time: {time}'**
  String sessionHistoryStartTime(String time);

  /// No description provided for @sessionHistoryPreflop.
  ///
  /// In en, this message translates to:
  /// **'Preflop:'**
  String get sessionHistoryPreflop;

  /// No description provided for @sessionHistoryFlop.
  ///
  /// In en, this message translates to:
  /// **'Flop:'**
  String get sessionHistoryFlop;

  /// No description provided for @sessionHistoryTurn.
  ///
  /// In en, this message translates to:
  /// **'Turn:'**
  String get sessionHistoryTurn;

  /// No description provided for @sessionHistoryRiver.
  ///
  /// In en, this message translates to:
  /// **'River:'**
  String get sessionHistoryRiver;

  /// No description provided for @sessionHistorySyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String sessionHistorySyncFailed(String error);

  /// No description provided for @sessionHistoryClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear sessions: {error}'**
  String sessionHistoryClearFailed(String error);

  /// No description provided for @notificationsClubNotFound.
  ///
  /// In en, this message translates to:
  /// **'Club not found'**
  String get notificationsClubNotFound;

  /// No description provided for @notificationsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get notificationsAccept;

  /// No description provided for @notificationsInvitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invitation Accepted'**
  String get notificationsInvitationAccepted;

  /// No description provided for @notificationsInvitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation Declined'**
  String get notificationsInvitationDeclined;

  /// No description provided for @notificationsInvitationDeclinedMsg.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined'**
  String get notificationsInvitationDeclinedMsg;

  /// No description provided for @notificationsEventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get notificationsEventNotFound;

  /// No description provided for @notificationsFailedLoadClub.
  ///
  /// In en, this message translates to:
  /// **'Failed to load club: {error}'**
  String notificationsFailedLoadClub(String error);

  /// No description provided for @notificationsErrorLoadingEvent.
  ///
  /// In en, this message translates to:
  /// **'Error loading event: {error}'**
  String notificationsErrorLoadingEvent(String error);

  /// No description provided for @invitationsFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load invitations: {error}'**
  String invitationsFailedLoad(String error);

  /// No description provided for @invitationsFailedAccept.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept invitation: {error}'**
  String invitationsFailedAccept(String error);

  /// No description provided for @invitationsDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined'**
  String get invitationsDeclined;

  /// No description provided for @invitationsFailedDecline.
  ///
  /// In en, this message translates to:
  /// **'Failed to decline invitation: {error}'**
  String invitationsFailedDecline(String error);

  /// No description provided for @clubSettingsTableAdded.
  ///
  /// In en, this message translates to:
  /// **'Table added'**
  String get clubSettingsTableAdded;

  /// No description provided for @clubSettingsTableDeleted.
  ///
  /// In en, this message translates to:
  /// **'Table deleted'**
  String get clubSettingsTableDeleted;

  /// No description provided for @clubSettingsQrRegenerated.
  ///
  /// In en, this message translates to:
  /// **'QR codes regenerated'**
  String get clubSettingsQrRegenerated;

  /// No description provided for @clubSettingsErrorPdf.
  ///
  /// In en, this message translates to:
  /// **'Error generating PDF: {error}'**
  String clubSettingsErrorPdf(String error);

  /// No description provided for @clubDashboardActiveDealers.
  ///
  /// In en, this message translates to:
  /// **'Active Dealers'**
  String get clubDashboardActiveDealers;

  /// No description provided for @clubDashboardPendingInvitations.
  ///
  /// In en, this message translates to:
  /// **'Pending Invitations'**
  String get clubDashboardPendingInvitations;

  /// No description provided for @clubDashboardDealerEmailHint.
  ///
  /// In en, this message translates to:
  /// **'dealer@example.com'**
  String get clubDashboardDealerEmailHint;

  /// No description provided for @clubDashboardInvitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {email}'**
  String clubDashboardInvitationSent(String email);

  /// No description provided for @clubDashboardFailedSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invitation: {error}'**
  String clubDashboardFailedSendInvite(String error);

  /// No description provided for @clubDashboardFailedCancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel invitation: {error}'**
  String clubDashboardFailedCancelInvite(String error);

  /// No description provided for @eventManagementClubEvents.
  ///
  /// In en, this message translates to:
  /// **'{name} Events'**
  String eventManagementClubEvents(String name);

  /// No description provided for @eventManagementFailedUpdate.
  ///
  /// In en, this message translates to:
  /// **'Failed to update event: {error}'**
  String eventManagementFailedUpdate(String error);

  /// No description provided for @profileCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get profileCash;

  /// No description provided for @profileTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get profileTournament;

  /// No description provided for @profileDevTools.
  ///
  /// In en, this message translates to:
  /// **'Dev Tools'**
  String get profileDevTools;

  /// No description provided for @profilePremiumOverride.
  ///
  /// In en, this message translates to:
  /// **'Premium Override'**
  String get profilePremiumOverride;

  /// No description provided for @profileUsingRealStatus.
  ///
  /// In en, this message translates to:
  /// **'Using real status: {status}'**
  String profileUsingRealStatus(String status);

  /// No description provided for @profileOverridden.
  ///
  /// In en, this message translates to:
  /// **'Overridden: {status}'**
  String profileOverridden(String status);

  /// No description provided for @profileResetToReal.
  ///
  /// In en, this message translates to:
  /// **'Reset to real status'**
  String get profileResetToReal;

  /// No description provided for @profileVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0'**
  String get profileVersion;

  /// No description provided for @profileLastLogin.
  ///
  /// In en, this message translates to:
  /// **'Last login {date}'**
  String profileLastLogin(String date);

  /// No description provided for @pokerHandFailedEndSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to end session: {error}'**
  String pokerHandFailedEndSession(String error);

  /// No description provided for @pokerHandFailedSaveSession.
  ///
  /// In en, this message translates to:
  /// **'Failed to save session: {error}'**
  String pokerHandFailedSaveSession(String error);

  /// No description provided for @pokerHandRebuyAdded.
  ///
  /// In en, this message translates to:
  /// **'Rebuy added: \${amount} (Stack: {stack})'**
  String pokerHandRebuyAdded(String amount, String stack);

  /// No description provided for @pokerHandEndSession.
  ///
  /// In en, this message translates to:
  /// **'End session'**
  String get pokerHandEndSession;

  /// No description provided for @pokerHandRebuyAmountDollar.
  ///
  /// In en, this message translates to:
  /// **'Rebuy Amount (\$)'**
  String get pokerHandRebuyAmountDollar;

  /// No description provided for @pokerHandRebuyChips.
  ///
  /// In en, this message translates to:
  /// **'Rebuy Chips'**
  String get pokerHandRebuyChips;

  /// No description provided for @seatSetupFailedSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String seatSetupFailedSave(String error);

  /// No description provided for @seatSetupSelectYourSeat.
  ///
  /// In en, this message translates to:
  /// **'Please select your seat'**
  String get seatSetupSelectYourSeat;

  /// No description provided for @authExpLinkGoogleTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Google Account'**
  String get authExpLinkGoogleTitle;

  /// No description provided for @authExpPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authExpPassword;

  /// No description provided for @authExpLinkAccount.
  ///
  /// In en, this message translates to:
  /// **'Link Account'**
  String get authExpLinkAccount;

  /// No description provided for @individualSetupSessionNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"Friday Night Poker\"'**
  String get individualSetupSessionNameHint;

  /// No description provided for @individualSetupCashGame.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get individualSetupCashGame;

  /// No description provided for @individualSetupTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get individualSetupTournament;

  /// No description provided for @individualSetupEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get individualSetupEnterAmount;

  /// No description provided for @individualSetupEnterChipStack.
  ///
  /// In en, this message translates to:
  /// **'Enter chip stack'**
  String get individualSetupEnterChipStack;

  /// No description provided for @individualSetupSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get individualSetupSmallBlind;

  /// No description provided for @individualSetupBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get individualSetupBigBlind;

  /// No description provided for @individualSetupEnterValue.
  ///
  /// In en, this message translates to:
  /// **'Enter value'**
  String get individualSetupEnterValue;

  /// No description provided for @individualHandSetupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., \"AA vs KK Cooler\"'**
  String get individualHandSetupNameHint;

  /// No description provided for @individualHandSetupSmallBlind.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get individualHandSetupSmallBlind;

  /// No description provided for @individualHandSetupBigBlind.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get individualHandSetupBigBlind;

  /// No description provided for @individualHandSetupPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get individualHandSetupPlayers;

  /// No description provided for @individualHandSetupGameType.
  ///
  /// In en, this message translates to:
  /// **'Game Type'**
  String get individualHandSetupGameType;

  /// No description provided for @playerSessionYourHoleCards.
  ///
  /// In en, this message translates to:
  /// **'Your Hole Cards'**
  String get playerSessionYourHoleCards;

  /// No description provided for @playerSessionSeat.
  ///
  /// In en, this message translates to:
  /// **'SEAT'**
  String get playerSessionSeat;

  /// No description provided for @playerSessionStack.
  ///
  /// In en, this message translates to:
  /// **'STACK'**
  String get playerSessionStack;

  /// No description provided for @playerSessionPot.
  ///
  /// In en, this message translates to:
  /// **'POT'**
  String get playerSessionPot;

  /// No description provided for @playerSessionNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add notes about this hand...'**
  String get playerSessionNotesHint;

  /// No description provided for @dealerQrScanInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR code. Please scan a valid table QR code.'**
  String get dealerQrScanInvalidCode;

  /// No description provided for @dealerQrScanWrongClub.
  ///
  /// In en, this message translates to:
  /// **'This table belongs to a different club.'**
  String get dealerQrScanWrongClub;

  /// No description provided for @dealerQrScanTableNotFound.
  ///
  /// In en, this message translates to:
  /// **'Table not found. Please scan a valid table QR code.'**
  String get dealerQrScanTableNotFound;

  /// No description provided for @dealerQrScanError.
  ///
  /// In en, this message translates to:
  /// **'Error processing QR code: {error}'**
  String dealerQrScanError(String error);

  /// No description provided for @dealerQrScanFailedStart.
  ///
  /// In en, this message translates to:
  /// **'Failed to start session: {error}'**
  String dealerQrScanFailedStart(String error);

  /// No description provided for @dealerQrScanTakingOver.
  ///
  /// In en, this message translates to:
  /// **'Taking over from {name}'**
  String dealerQrScanTakingOver(String name);

  /// No description provided for @dealerQrScanHandsPlayed.
  ///
  /// In en, this message translates to:
  /// **'Hands Played'**
  String get dealerQrScanHandsPlayed;

  /// No description provided for @dealerQrScanBlinds.
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get dealerQrScanBlinds;

  /// No description provided for @dealerQrScanPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get dealerQrScanPlayers;

  /// No description provided for @dealerQrScanFailedResume.
  ///
  /// In en, this message translates to:
  /// **'Failed to resume session: {error}'**
  String dealerQrScanFailedResume(String error);

  /// No description provided for @usernameSetupLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameSetupLabel;

  /// No description provided for @stackChartScreenAvgGrowth.
  ///
  /// In en, this message translates to:
  /// **'Avg Growth'**
  String get stackChartScreenAvgGrowth;

  /// No description provided for @stackChartScreenDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get stackChartScreenDuration;

  /// No description provided for @stackChartScreenProfitLoss.
  ///
  /// In en, this message translates to:
  /// **'P/L'**
  String get stackChartScreenProfitLoss;

  /// No description provided for @stackChartScreenStack.
  ///
  /// In en, this message translates to:
  /// **'Stack'**
  String get stackChartScreenStack;

  /// No description provided for @quickStackSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search or add player...'**
  String get quickStackSearchHint;

  /// No description provided for @sessionHandsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading hands...'**
  String get sessionHandsLoading;

  /// No description provided for @createEventDefaultCashGame.
  ///
  /// In en, this message translates to:
  /// **'Cash Game {stakes}'**
  String createEventDefaultCashGame(String stakes);

  /// No description provided for @createEventDefaultCashGameNoStakes.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get createEventDefaultCashGameNoStakes;

  /// No description provided for @eventDashboardTvMode.
  ///
  /// In en, this message translates to:
  /// **'TV Display Mode'**
  String get eventDashboardTvMode;

  /// No description provided for @tableSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Table'**
  String get tableSelectionTitle;

  /// No description provided for @tableSelectionAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a table to manage'**
  String get tableSelectionAdminSubtitle;

  /// No description provided for @tableSelectionMemberSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a table to view availability'**
  String get tableSelectionMemberSubtitle;

  /// No description provided for @tableSelectionNoTables.
  ///
  /// In en, this message translates to:
  /// **'No tables available'**
  String get tableSelectionNoTables;

  /// No description provided for @tableSelectionOpenSeats.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String tableSelectionOpenSeats(int count);

  /// No description provided for @tableSelectionSeated.
  ///
  /// In en, this message translates to:
  /// **'{occupied}/9 seated'**
  String tableSelectionSeated(int occupied);

  /// No description provided for @monthJan.
  ///
  /// In en, this message translates to:
  /// **'Jan'**
  String get monthJan;

  /// No description provided for @monthFeb.
  ///
  /// In en, this message translates to:
  /// **'Feb'**
  String get monthFeb;

  /// No description provided for @monthMar.
  ///
  /// In en, this message translates to:
  /// **'Mar'**
  String get monthMar;

  /// No description provided for @monthApr.
  ///
  /// In en, this message translates to:
  /// **'Apr'**
  String get monthApr;

  /// No description provided for @monthMay.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get monthMay;

  /// No description provided for @monthJun.
  ///
  /// In en, this message translates to:
  /// **'Jun'**
  String get monthJun;

  /// No description provided for @monthJul.
  ///
  /// In en, this message translates to:
  /// **'Jul'**
  String get monthJul;

  /// No description provided for @monthAug.
  ///
  /// In en, this message translates to:
  /// **'Aug'**
  String get monthAug;

  /// No description provided for @monthSep.
  ///
  /// In en, this message translates to:
  /// **'Sep'**
  String get monthSep;

  /// No description provided for @monthOct.
  ///
  /// In en, this message translates to:
  /// **'Oct'**
  String get monthOct;

  /// No description provided for @monthNov.
  ///
  /// In en, this message translates to:
  /// **'Nov'**
  String get monthNov;

  /// No description provided for @monthDec.
  ///
  /// In en, this message translates to:
  /// **'Dec'**
  String get monthDec;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @opponentsErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String opponentsErrorGeneric(String error);

  /// No description provided for @opponentsErrorDeleting.
  ///
  /// In en, this message translates to:
  /// **'Error deleting opponent: {error}'**
  String opponentsErrorDeleting(String error);

  /// No description provided for @opponentsErrorClearing.
  ///
  /// In en, this message translates to:
  /// **'Error clearing opponents: {error}'**
  String opponentsErrorClearing(String error);

  /// No description provided for @onboardingReadTitle.
  ///
  /// In en, this message translates to:
  /// **'READ THE GAME\nLIKE A PRO'**
  String get onboardingReadTitle;

  /// No description provided for @onboardingReadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to start tracking your poker journey.'**
  String get onboardingReadSubtitle;

  /// No description provided for @onboardingCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get onboardingCreateAccount;

  /// No description provided for @onboardingLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get onboardingLogIn;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingFinalTable.
  ///
  /// In en, this message translates to:
  /// **'Final Table'**
  String get onboardingFinalTable;

  /// No description provided for @authExpSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authExpSignUpTitle;

  /// No description provided for @authExpLogInTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to your account'**
  String get authExpLogInTitle;

  /// No description provided for @authExpSignUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account to continue'**
  String get authExpSignUpSubtitle;

  /// No description provided for @authExpLogInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password to log in'**
  String get authExpLogInSubtitle;

  /// No description provided for @authExpName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get authExpName;

  /// No description provided for @authExpEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authExpEmail;

  /// No description provided for @authExpEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authExpEnterName;

  /// No description provided for @authExpNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get authExpNameMinLength;

  /// No description provided for @authExpEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authExpEnterEmail;

  /// No description provided for @authExpValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authExpValidEmail;

  /// No description provided for @authExpEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authExpEnterPassword;

  /// No description provided for @authExpPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authExpPasswordMinLength;

  /// No description provided for @authExpBySigningUp.
  ///
  /// In en, this message translates to:
  /// **'By Signing up, you agree to the '**
  String get authExpBySigningUp;

  /// No description provided for @authExpTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authExpTermsOfService;

  /// No description provided for @authExpAnd.
  ///
  /// In en, this message translates to:
  /// **'\nand '**
  String get authExpAnd;

  /// No description provided for @authExpPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authExpPrivacyPolicy;

  /// No description provided for @authExpCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authExpCreateAccount;

  /// No description provided for @authExpAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authExpAlreadyHaveAccount;

  /// No description provided for @authExpSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authExpSignIn;

  /// No description provided for @authExpForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authExpForgotPassword;

  /// No description provided for @authExpDontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authExpDontHaveAccount;

  /// No description provided for @authExpSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get authExpSignUp;

  /// No description provided for @authExpOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authExpOr;

  /// No description provided for @authExpContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authExpContinueGoogle;

  /// No description provided for @authExpLinkGoogleMessage.
  ///
  /// In en, this message translates to:
  /// **'An account with {email} already exists. Enter your password to link your Google account.'**
  String authExpLinkGoogleMessage(String email);

  /// No description provided for @forgotPasswordCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {email}'**
  String forgotPasswordCodeSubtitle(String email);

  /// No description provided for @usernameSetupChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Change your username'**
  String get usernameSetupChangeTitle;

  /// No description provided for @usernameSetupChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your username'**
  String get usernameSetupChooseTitle;

  /// No description provided for @usernameSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is how other players will know you at the table'**
  String get usernameSetupSubtitle;

  /// No description provided for @usernameSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameSetupRequired;

  /// No description provided for @usernameSetupCheckingAvailability.
  ///
  /// In en, this message translates to:
  /// **'Checking availability…'**
  String get usernameSetupCheckingAvailability;

  /// No description provided for @usernameSetupAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available!'**
  String get usernameSetupAvailable;

  /// No description provided for @usernameSetupAlreadyTaken.
  ///
  /// In en, this message translates to:
  /// **'Already taken'**
  String get usernameSetupAlreadyTaken;

  /// No description provided for @usernameSetupCurrentUsername.
  ///
  /// In en, this message translates to:
  /// **'This is your current username'**
  String get usernameSetupCurrentUsername;

  /// No description provided for @usernameSetupCouldNotCheck.
  ///
  /// In en, this message translates to:
  /// **'Could not check availability'**
  String get usernameSetupCouldNotCheck;

  /// No description provided for @usernameSetupJustTaken.
  ///
  /// In en, this message translates to:
  /// **'Username was just taken. Try another.'**
  String get usernameSetupJustTaken;

  /// No description provided for @usernameSetupRulesHint.
  ///
  /// In en, this message translates to:
  /// **'3–20 characters · letters, numbers, underscores'**
  String get usernameSetupRulesHint;

  /// No description provided for @usernameSetupUpdateButton.
  ///
  /// In en, this message translates to:
  /// **'Update username'**
  String get usernameSetupUpdateButton;

  /// No description provided for @usernameSetupClaimButton.
  ///
  /// In en, this message translates to:
  /// **'Claim username'**
  String get usernameSetupClaimButton;

  /// No description provided for @usernameSetupSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get usernameSetupSkip;

  /// No description provided for @sessionHandsTitle.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionHandsTitle;

  /// No description provided for @sessionHandsHandsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count} hands logged'**
  String sessionHandsHandsLogged(int count);

  /// No description provided for @sessionHandsError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get sessionHandsError;

  /// No description provided for @sessionHandsNoHandsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Hands Logged'**
  String get sessionHandsNoHandsTitle;

  /// No description provided for @sessionHandsNoHandsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This session has no recorded hands yet.'**
  String get sessionHandsNoHandsSubtitle;

  /// No description provided for @sessionHandsWon.
  ///
  /// In en, this message translates to:
  /// **'WON'**
  String get sessionHandsWon;

  /// No description provided for @sessionHandsActions.
  ///
  /// In en, this message translates to:
  /// **'{count} actions'**
  String sessionHandsActions(int count);

  /// No description provided for @sessionHandsPot.
  ///
  /// In en, this message translates to:
  /// **'Pot'**
  String get sessionHandsPot;

  /// No description provided for @stackChartScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Stack Chart'**
  String get stackChartScreenTitle;

  /// No description provided for @stackChartScreenPokerSession.
  ///
  /// In en, this message translates to:
  /// **'Poker Session'**
  String get stackChartScreenPokerSession;

  /// No description provided for @notificationsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsScreenTitle;

  /// No description provided for @notificationsScreenToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsScreenToday;

  /// No description provided for @notificationsScreenMarkAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsScreenMarkAllAsRead;

  /// No description provided for @notificationsScreenMarkAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get notificationsScreenMarkAsRead;

  /// No description provided for @notificationsScreenNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsScreenNoNotifications;

  /// No description provided for @notificationsScreenClubInvitation.
  ///
  /// In en, this message translates to:
  /// **'Club Invitation'**
  String get notificationsScreenClubInvitation;

  /// No description provided for @notificationsScreenInvitedToJoin.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to join'**
  String get notificationsScreenInvitedToJoin;

  /// No description provided for @notificationsScreenDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get notificationsScreenDecline;

  /// No description provided for @notificationsScreenNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notificationsScreenNotAuthenticated;

  /// No description provided for @notificationsScreenRequestResolved.
  ///
  /// In en, this message translates to:
  /// **'Request Resolved'**
  String get notificationsScreenRequestResolved;

  /// No description provided for @notificationsScreenRequestClosed.
  ///
  /// In en, this message translates to:
  /// **'Request Closed'**
  String get notificationsScreenRequestClosed;

  /// No description provided for @notificationsScreenResponse.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get notificationsScreenResponse;

  /// No description provided for @notificationsScreenEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get notificationsScreenEvents;

  /// No description provided for @notificationsScreenRsvp.
  ///
  /// In en, this message translates to:
  /// **'RSVP'**
  String get notificationsScreenRsvp;

  /// No description provided for @notificationsScreenClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get notificationsScreenClubs;

  /// No description provided for @notificationsScreenInvitations.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get notificationsScreenInvitations;

  /// No description provided for @notificationsScreenSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get notificationsScreenSeats;

  /// No description provided for @notificationsScreenSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get notificationsScreenSupport;

  /// No description provided for @notifEventCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'New Event: {eventName}'**
  String notifEventCreatedTitle(String eventName);

  /// No description provided for @notifEventCreatedBody.
  ///
  /// In en, this message translates to:
  /// **'{date}'**
  String notifEventCreatedBody(String date);

  /// No description provided for @notifEventUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Updated: {eventName}'**
  String notifEventUpdatedTitle(String eventName);

  /// No description provided for @notifEventUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'{clubName} updated the event details'**
  String notifEventUpdatedBody(String clubName);

  /// No description provided for @notifEventCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Cancelled: {eventName}'**
  String notifEventCancelledTitle(String eventName);

  /// No description provided for @notifEventCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'{clubName} has cancelled the event scheduled for {date}'**
  String notifEventCancelledBody(String clubName, String date);

  /// No description provided for @notifEventStartingTitle.
  ///
  /// In en, this message translates to:
  /// **'{eventName} starts in 1 hour!'**
  String notifEventStartingTitle(String eventName);

  /// No description provided for @notifEventStartingBody.
  ///
  /// In en, this message translates to:
  /// **'{clubName} event is about to begin'**
  String notifEventStartingBody(String clubName);

  /// No description provided for @notifEventStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'{eventName} is now LIVE!'**
  String notifEventStartedTitle(String eventName);

  /// No description provided for @notifEventStartedBody.
  ///
  /// In en, this message translates to:
  /// **'{clubName} event has started - join now to spectate'**
  String notifEventStartedBody(String clubName);

  /// No description provided for @notifSeatAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat is open: {eventName}'**
  String notifSeatAvailableTitle(String eventName);

  /// No description provided for @notifSeatAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'A seat is now available at {clubName}! Open the app to take your spot.'**
  String notifSeatAvailableBody(String clubName);

  /// No description provided for @notifMemberRsvpTitle.
  ///
  /// In en, this message translates to:
  /// **'RSVP: {memberName}'**
  String notifMemberRsvpTitle(String memberName);

  /// No description provided for @notifMemberRsvpBody.
  ///
  /// In en, this message translates to:
  /// **'{memberName} responded \"{rsvpStatus}\" to {eventName}'**
  String notifMemberRsvpBody(
      String memberName, String rsvpStatus, String eventName);

  /// No description provided for @notifNewClubRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'New Club Request'**
  String get notifNewClubRequestTitle;

  /// No description provided for @notifNewClubRequestBody.
  ///
  /// In en, this message translates to:
  /// **'A new club registration request has been submitted'**
  String get notifNewClubRequestBody;

  /// No description provided for @notifClubApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Approved'**
  String get notifClubApprovedTitle;

  /// No description provided for @notifClubApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Your club has been approved!'**
  String get notifClubApprovedBody;

  /// No description provided for @notifClubRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Rejected'**
  String get notifClubRejectedTitle;

  /// No description provided for @notifClubRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your club request has been rejected'**
  String get notifClubRejectedBody;

  /// No description provided for @notifMemberInvitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Invitation'**
  String get notifMemberInvitedTitle;

  /// No description provided for @notifMemberInvitedBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve been invited to join a club'**
  String get notifMemberInvitedBody;

  /// No description provided for @notifInvitationAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation Accepted'**
  String get notifInvitationAcceptedTitle;

  /// No description provided for @notifInvitationAcceptedBody.
  ///
  /// In en, this message translates to:
  /// **'{memberName} has accepted the invitation'**
  String notifInvitationAcceptedBody(String memberName);

  /// No description provided for @notifInvitationDeclinedTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation Declined'**
  String get notifInvitationDeclinedTitle;

  /// No description provided for @notifInvitationDeclinedBody.
  ///
  /// In en, this message translates to:
  /// **'{memberName} has declined the invitation'**
  String notifInvitationDeclinedBody(String memberName);

  /// No description provided for @notifSupportRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Request'**
  String get notifSupportRequestTitle;

  /// No description provided for @notifSupportRequestBody.
  ///
  /// In en, this message translates to:
  /// **'A new support request has been submitted'**
  String get notifSupportRequestBody;

  /// No description provided for @notifSupportUpdatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Support Update'**
  String get notifSupportUpdatedTitle;

  /// No description provided for @notifSupportUpdatedBody.
  ///
  /// In en, this message translates to:
  /// **'Your support request has been updated'**
  String get notifSupportUpdatedBody;

  /// No description provided for @notifTypeEventCreated.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get notifTypeEventCreated;

  /// No description provided for @notifTypeEventUpdated.
  ///
  /// In en, this message translates to:
  /// **'Event Updated'**
  String get notifTypeEventUpdated;

  /// No description provided for @notifTypeEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'Event Cancelled'**
  String get notifTypeEventCancelled;

  /// No description provided for @notifTypeEventStarting.
  ///
  /// In en, this message translates to:
  /// **'Event Starting Soon'**
  String get notifTypeEventStarting;

  /// No description provided for @notifTypeEventStarted.
  ///
  /// In en, this message translates to:
  /// **'Event Started'**
  String get notifTypeEventStarted;

  /// No description provided for @notifTypeMemberRsvp.
  ///
  /// In en, this message translates to:
  /// **'Member RSVP'**
  String get notifTypeMemberRsvp;

  /// No description provided for @notifTypeNewClubRequest.
  ///
  /// In en, this message translates to:
  /// **'New Club Request'**
  String get notifTypeNewClubRequest;

  /// No description provided for @notifTypeClubApproved.
  ///
  /// In en, this message translates to:
  /// **'Club Approved'**
  String get notifTypeClubApproved;

  /// No description provided for @notifTypeClubRejected.
  ///
  /// In en, this message translates to:
  /// **'Club Rejected'**
  String get notifTypeClubRejected;

  /// No description provided for @notifTypeMemberInvited.
  ///
  /// In en, this message translates to:
  /// **'Club Invitation'**
  String get notifTypeMemberInvited;

  /// No description provided for @notifTypeInvitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invitation Accepted'**
  String get notifTypeInvitationAccepted;

  /// No description provided for @notifTypeInvitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation Declined'**
  String get notifTypeInvitationDeclined;

  /// No description provided for @notifTypeSeatAvailable.
  ///
  /// In en, this message translates to:
  /// **'Seat Available'**
  String get notifTypeSeatAvailable;

  /// No description provided for @notifTypeSupportRequest.
  ///
  /// In en, this message translates to:
  /// **'Support Request'**
  String get notifTypeSupportRequest;

  /// No description provided for @notifTypeSupportUpdated.
  ///
  /// In en, this message translates to:
  /// **'Support Update'**
  String get notifTypeSupportUpdated;

  /// No description provided for @invitationsScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Invitations'**
  String get invitationsScreenTitle;

  /// No description provided for @invitationsScreenNoPending.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations'**
  String get invitationsScreenNoPending;

  /// No description provided for @invitationsScreenYouWillSee.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see invitations from clubs here'**
  String get invitationsScreenYouWillSee;

  /// No description provided for @invitationsScreenGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get invitationsScreenGoBack;

  /// No description provided for @invitationsScreenUnknownClub.
  ///
  /// In en, this message translates to:
  /// **'Unknown Club'**
  String get invitationsScreenUnknownClub;

  /// No description provided for @invitationsScreenInvitedBy.
  ///
  /// In en, this message translates to:
  /// **'Invited by {name}'**
  String invitationsScreenInvitedBy(String name);

  /// No description provided for @invitationsScreenExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String invitationsScreenExpires(String date);

  /// No description provided for @invitationsScreenExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get invitationsScreenExpired;

  /// No description provided for @invitationsScreenExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days} day(s)'**
  String invitationsScreenExpiresInDays(int days);

  /// No description provided for @invitationsScreenExpiresInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} hour(s)'**
  String invitationsScreenExpiresInHours(int hours);

  /// No description provided for @invitationsScreenExpiresSoon.
  ///
  /// In en, this message translates to:
  /// **'soon'**
  String get invitationsScreenExpiresSoon;

  /// No description provided for @invitationsScreenDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get invitationsScreenDecline;

  /// No description provided for @invitationsScreenAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get invitationsScreenAccept;

  /// No description provided for @invitationsScreenJoinedAs.
  ///
  /// In en, this message translates to:
  /// **'Joined {clubName} as {role}'**
  String invitationsScreenJoinedAs(String clubName, String role);

  /// No description provided for @profilePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get profilePremium;

  /// No description provided for @profileFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get profileFree;

  /// No description provided for @dealerTableStartNewHand.
  ///
  /// In en, this message translates to:
  /// **'Start New Hand'**
  String get dealerTableStartNewHand;

  /// No description provided for @dealerTableStartSessionBtn.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get dealerTableStartSessionBtn;

  /// No description provided for @dealerTableNeedTwoPlayers.
  ///
  /// In en, this message translates to:
  /// **'Need at least 2 players to start'**
  String get dealerTableNeedTwoPlayers;

  /// No description provided for @dealerTableAddTestPlayers.
  ///
  /// In en, this message translates to:
  /// **'Add Test Players'**
  String get dealerTableAddTestPlayers;

  /// No description provided for @dealerTableAddedTestPlayers.
  ///
  /// In en, this message translates to:
  /// **'Added {count} test players'**
  String dealerTableAddedTestPlayers(int count);

  /// No description provided for @dealerTableRolledBack.
  ///
  /// In en, this message translates to:
  /// **'Rolled back to {street}'**
  String dealerTableRolledBack(String street);

  /// No description provided for @dealerTableUndoneAction.
  ///
  /// In en, this message translates to:
  /// **'Undone: {playerName} {action}'**
  String dealerTableUndoneAction(String playerName, String action);

  /// No description provided for @dealerTableScanToJoin.
  ///
  /// In en, this message translates to:
  /// **'Scan to join this seat'**
  String get dealerTableScanToJoin;

  /// No description provided for @dealerTableOccupiedDot.
  ///
  /// In en, this message translates to:
  /// **'Occupied · '**
  String get dealerTableOccupiedDot;

  /// No description provided for @dealerTableEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get dealerTableEmptyLabel;

  /// No description provided for @dealerTableOccupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get dealerTableOccupiedLabel;

  /// No description provided for @dealerTableSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get dealerTableSelectedLabel;

  /// No description provided for @dealerTableSelectSeatLabel.
  ///
  /// In en, this message translates to:
  /// **'SELECT SEAT'**
  String get dealerTableSelectSeatLabel;

  /// No description provided for @dealerTableBetAmountDialog.
  ///
  /// In en, this message translates to:
  /// **'Bet amount'**
  String get dealerTableBetAmountDialog;

  /// No description provided for @dealerTableRaiseToDialog.
  ///
  /// In en, this message translates to:
  /// **'Raise to'**
  String get dealerTableRaiseToDialog;

  /// No description provided for @dealerTablePausedLabel.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get dealerTablePausedLabel;

  /// No description provided for @dealerTableListeningLabel.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get dealerTableListeningLabel;

  /// No description provided for @dealerTableResumeVoiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Resume Voice'**
  String get dealerTableResumeVoiceTooltip;

  /// No description provided for @dealerTablePauseVoiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause Voice'**
  String get dealerTablePauseVoiceTooltip;

  /// No description provided for @dealerTableVoiceOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Voice off'**
  String get dealerTableVoiceOffLabel;

  /// No description provided for @dealerTableCalibratingLabel.
  ///
  /// In en, this message translates to:
  /// **'Calibrating...'**
  String get dealerTableCalibratingLabel;

  /// No description provided for @dealerTableCalibrationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please announce: \"Table [number], dealer [name]\"'**
  String get dealerTableCalibrationPrompt;

  /// No description provided for @dealerTableDealerLockedMsg.
  ///
  /// In en, this message translates to:
  /// **'Dealer locked: {name} at table {table}'**
  String dealerTableDealerLockedMsg(String name, String table);

  /// No description provided for @dealerTableNoSpeakersMsg.
  ///
  /// In en, this message translates to:
  /// **'No speakers detected - please speak clearly'**
  String get dealerTableNoSpeakersMsg;

  /// No description provided for @dealerTableSayTableDealerMsg.
  ///
  /// In en, this message translates to:
  /// **'Please say: \"Table [number], dealer [name]\"'**
  String get dealerTableSayTableDealerMsg;

  /// No description provided for @dealerTableConnectionLostRecovery.
  ///
  /// In en, this message translates to:
  /// **'Connection lost - attempting to recover...'**
  String get dealerTableConnectionLostRecovery;

  /// No description provided for @dealerTableConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout - recalibration required'**
  String get dealerTableConnectionTimeout;

  /// No description provided for @dealerTableConnectionRecovered.
  ///
  /// In en, this message translates to:
  /// **'Connection recovered!'**
  String get dealerTableConnectionRecovered;

  /// No description provided for @dealerTableActionHeldMsg.
  ///
  /// In en, this message translates to:
  /// **'Action held'**
  String get dealerTableActionHeldMsg;

  /// No description provided for @dealerTableFailedStartStreaming.
  ///
  /// In en, this message translates to:
  /// **'Failed to start streaming - check server connection and microphone'**
  String get dealerTableFailedStartStreaming;

  /// No description provided for @dealerTableFailedStartVoice.
  ///
  /// In en, this message translates to:
  /// **'Failed to start voice: {error}'**
  String dealerTableFailedStartVoice(String error);

  /// No description provided for @dealerTableAddPlayerActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Add Player'**
  String get dealerTableAddPlayerActionLabel;

  /// No description provided for @dealerTableSeatAnotherPlayer.
  ///
  /// In en, this message translates to:
  /// **'Seat another player here'**
  String get dealerTableSeatAnotherPlayer;

  /// No description provided for @dealerTableSitHereLabel.
  ///
  /// In en, this message translates to:
  /// **'Sit Here'**
  String get dealerTableSitHereLabel;

  /// No description provided for @dealerTableJoinAsDealerPlayer.
  ///
  /// In en, this message translates to:
  /// **'Join the game as dealer-player'**
  String get dealerTableJoinAsDealerPlayer;

  /// No description provided for @dealerTableDealerFallback.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get dealerTableDealerFallback;

  /// No description provided for @dealerTableUpdatedStackMsg.
  ///
  /// In en, this message translates to:
  /// **'Updated {name} stack to {amount}'**
  String dealerTableUpdatedStackMsg(String name, String amount);

  /// No description provided for @dealerTableFailedUpdateStackMsg.
  ///
  /// In en, this message translates to:
  /// **'Failed to update stack: {error}'**
  String dealerTableFailedUpdateStackMsg(String error);

  /// No description provided for @dealerTableSittingAtSeatMsg.
  ///
  /// In en, this message translates to:
  /// **'You are now playing at Seat {number}'**
  String dealerTableSittingAtSeatMsg(int number);

  /// No description provided for @dealerTableFailedSitMsg.
  ///
  /// In en, this message translates to:
  /// **'Failed to sit at table: {error}'**
  String dealerTableFailedSitMsg(String error);

  /// No description provided for @dealerTableFailedAddPlayerMsg.
  ///
  /// In en, this message translates to:
  /// **'Failed to add player: {error}'**
  String dealerTableFailedAddPlayerMsg(String error);

  /// No description provided for @dealerTableRemovedFromSeat.
  ///
  /// In en, this message translates to:
  /// **'{name} removed from Seat {seat}'**
  String dealerTableRemovedFromSeat(String name, int seat);

  /// No description provided for @dealerTableFailedRemoveMsg.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove player: {error}'**
  String dealerTableFailedRemoveMsg(String error);

  /// No description provided for @eventDetailDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get eventDetailDateAndTime;

  /// No description provided for @eventDetailTableSeatInfo.
  ///
  /// In en, this message translates to:
  /// **'Table {table}, Seat #{seat}'**
  String eventDetailTableSeatInfo(String table, int seat);

  /// No description provided for @eventDetailYoureSeatedGoodLuck.
  ///
  /// In en, this message translates to:
  /// **'You\'re seated, good luck!'**
  String get eventDetailYoureSeatedGoodLuck;

  /// No description provided for @eventDetailHomeGame.
  ///
  /// In en, this message translates to:
  /// **'Home Game'**
  String get eventDetailHomeGame;

  /// No description provided for @clubDashboardDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get clubDashboardDateLabel;

  /// No description provided for @clubDashboardUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get clubDashboardUnknownLabel;

  /// No description provided for @clubDashboardActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get clubDashboardActiveLabel;

  /// No description provided for @clubDashboardIdleLabel.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get clubDashboardIdleLabel;

  /// No description provided for @clubDashboardInvitedTimeAgo.
  ///
  /// In en, this message translates to:
  /// **'Invited {time}'**
  String clubDashboardInvitedTimeAgo(String time);

  /// No description provided for @clubDashboardPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get clubDashboardPendingLabel;

  /// No description provided for @clubDashboardNoDealersYet.
  ///
  /// In en, this message translates to:
  /// **'No dealers yet'**
  String get clubDashboardNoDealersYet;

  /// No description provided for @clubDashboardInviteDealersHint.
  ///
  /// In en, this message translates to:
  /// **'Invite dealers to help manage your tables'**
  String get clubDashboardInviteDealersHint;

  /// No description provided for @clubDashboardInviteDealer.
  ///
  /// In en, this message translates to:
  /// **'Invite Dealer'**
  String get clubDashboardInviteDealer;

  /// No description provided for @clubDashboardInviteDealerBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email address of the dealer you want to invite.'**
  String get clubDashboardInviteDealerBody;

  /// No description provided for @clubDashboardSendInvitationBtn.
  ///
  /// In en, this message translates to:
  /// **'Send Invitation'**
  String get clubDashboardSendInvitationBtn;

  /// No description provided for @clubDashboardInvitationSentTo.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {email}'**
  String clubDashboardInvitationSentTo(String email);

  /// No description provided for @clubDashboardFailedSendInvitationMsg.
  ///
  /// In en, this message translates to:
  /// **'Failed to send invitation: {error}'**
  String clubDashboardFailedSendInvitationMsg(String error);

  /// No description provided for @clubDashboardCancelInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Invitation?'**
  String get clubDashboardCancelInvitationTitle;

  /// No description provided for @clubDashboardCancelInvitationBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel the invitation to {email}?'**
  String clubDashboardCancelInvitationBody(String email);

  /// No description provided for @clubDashboardKeepBtn.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get clubDashboardKeepBtn;

  /// No description provided for @clubDashboardCancelInvitationBtn.
  ///
  /// In en, this message translates to:
  /// **'Cancel Invitation'**
  String get clubDashboardCancelInvitationBtn;

  /// No description provided for @clubDashboardFailedCancelMsg.
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel invitation: {error}'**
  String clubDashboardFailedCancelMsg(String error);

  /// No description provided for @clubSettingsMembers.
  ///
  /// In en, this message translates to:
  /// **'Members ({count})'**
  String clubSettingsMembers(int count);

  /// No description provided for @clubSettingsNoMembersFound.
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get clubSettingsNoMembersFound;

  /// No description provided for @clubSettingsRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get clubSettingsRoleOwner;

  /// No description provided for @clubSettingsRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get clubSettingsRoleAdmin;

  /// No description provided for @clubSettingsRoleDealer.
  ///
  /// In en, this message translates to:
  /// **'Dealer'**
  String get clubSettingsRoleDealer;

  /// No description provided for @clubSettingsRolePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get clubSettingsRolePlayer;

  /// No description provided for @clubSettingsTableAddedMsg.
  ///
  /// In en, this message translates to:
  /// **'Table added'**
  String get clubSettingsTableAddedMsg;

  /// No description provided for @clubSettingsEditTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Table'**
  String get clubSettingsEditTableTitle;

  /// No description provided for @clubSettingsDeleteTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Table?'**
  String get clubSettingsDeleteTableTitle;

  /// No description provided for @clubSettingsDeleteTableBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This cannot be undone.'**
  String clubSettingsDeleteTableBody(String name);

  /// No description provided for @clubSettingsTableDeletedMsg.
  ///
  /// In en, this message translates to:
  /// **'Table deleted'**
  String get clubSettingsTableDeletedMsg;

  /// No description provided for @clubSettingsDealerScanHint.
  ///
  /// In en, this message translates to:
  /// **'Dealers scan this to start a session at this table'**
  String get clubSettingsDealerScanHint;

  /// No description provided for @clubSettingsRegenerateBtn.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get clubSettingsRegenerateBtn;

  /// No description provided for @clubSettingsAppQrCodes.
  ///
  /// In en, this message translates to:
  /// **'App QR Codes'**
  String get clubSettingsAppQrCodes;

  /// No description provided for @clubSettingsShareWithPlayers.
  ///
  /// In en, this message translates to:
  /// **'Share with players to download the app'**
  String get clubSettingsShareWithPlayers;

  /// No description provided for @clubSettingsDownloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get clubSettingsDownloadPdf;

  /// No description provided for @clubSettingsDownloadFinalTable.
  ///
  /// In en, this message translates to:
  /// **'Download the Final Table App'**
  String get clubSettingsDownloadFinalTable;

  /// No description provided for @clubSettingsScanQrToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code for your device to get started'**
  String get clubSettingsScanQrToGetStarted;

  /// No description provided for @clubSettingsScanToStartSession.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code to start a session'**
  String get clubSettingsScanToStartSession;

  /// No description provided for @clubSettingsForDealersOnly.
  ///
  /// In en, this message translates to:
  /// **'For dealers only'**
  String get clubSettingsForDealersOnly;

  /// No description provided for @clubSettingsTableDefault.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String clubSettingsTableDefault(int number);

  /// No description provided for @eventManagementFailedUpdateEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to update event: {error}'**
  String eventManagementFailedUpdateEvent(String error);

  /// No description provided for @adminTableThisWillMoveMsg.
  ///
  /// In en, this message translates to:
  /// **'This will move {count} player(s) to the waitlist and remove the table from this event.'**
  String adminTableThisWillMoveMsg(int count);

  /// No description provided for @adminTableThisWillRemoveMsg.
  ///
  /// In en, this message translates to:
  /// **'This will remove the table from this event.'**
  String get adminTableThisWillRemoveMsg;

  /// No description provided for @adminTableClosedWithWaitlistMsg.
  ///
  /// In en, this message translates to:
  /// **'{table} closed. {count} player(s) moved to waitlist.'**
  String adminTableClosedWithWaitlistMsg(String table, int count);

  /// No description provided for @adminTableClosedMsg.
  ///
  /// In en, this message translates to:
  /// **'{table} closed.'**
  String adminTableClosedMsg(String table);

  /// No description provided for @adminTableEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get adminTableEmptyLabel;

  /// No description provided for @adminTableTableFallback.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get adminTableTableFallback;

  /// No description provided for @adminTableTableNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Table {number}'**
  String adminTableTableNumberLabel(int number);

  /// No description provided for @homePendingInvitationsMsg.
  ///
  /// In en, this message translates to:
  /// **'You have {count} pending club invitation(s).'**
  String homePendingInvitationsMsg(int count);

  /// No description provided for @homeEventFallback.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get homeEventFallback;

  /// No description provided for @homePokerFallback.
  ///
  /// In en, this message translates to:
  /// **'Poker'**
  String get homePokerFallback;

  /// No description provided for @homeUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get homeUserFallback;

  /// No description provided for @homeSeatInfoStr.
  ///
  /// In en, this message translates to:
  /// **'Seat #{seat}  •  {chipStack}'**
  String homeSeatInfoStr(int seat, String chipStack);

  /// No description provided for @pokerHandYouLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get pokerHandYouLabel;

  /// No description provided for @pokerHandMovingToTable.
  ///
  /// In en, this message translates to:
  /// **'Moving to a different table. Your stack ({stack}) will carry over. Other players will be cleared.'**
  String pokerHandMovingToTable(String stack);

  /// No description provided for @pokerHandActiveSessionMsg.
  ///
  /// In en, this message translates to:
  /// **'You have an active session with {count} hand(s) logged. What would you like to do?'**
  String pokerHandActiveSessionMsg(int count);

  /// No description provided for @pokerHandUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get pokerHandUnknownLabel;

  /// No description provided for @pokerHandFoldAction.
  ///
  /// In en, this message translates to:
  /// **'Fold'**
  String get pokerHandFoldAction;

  /// No description provided for @pokerHandRaiseAction.
  ///
  /// In en, this message translates to:
  /// **'Raise'**
  String get pokerHandRaiseAction;

  /// No description provided for @pokerHandBetAction.
  ///
  /// In en, this message translates to:
  /// **'Bet'**
  String get pokerHandBetAction;

  /// No description provided for @pokerHandAllInAction.
  ///
  /// In en, this message translates to:
  /// **'All-In'**
  String get pokerHandAllInAction;

  /// No description provided for @pokerHandAllPlayersAllIn.
  ///
  /// In en, this message translates to:
  /// **'All players all-in - dealing remaining cards'**
  String get pokerHandAllPlayersAllIn;

  /// No description provided for @pokerHandWaitingForCards.
  ///
  /// In en, this message translates to:
  /// **'Waiting for cards to be dealt'**
  String get pokerHandWaitingForCards;

  /// No description provided for @pokerHandBettingComplete.
  ///
  /// In en, this message translates to:
  /// **'Betting complete - ready for next street'**
  String get pokerHandBettingComplete;

  /// No description provided for @pokerHandSeatFallback.
  ///
  /// In en, this message translates to:
  /// **'Seat {id}'**
  String pokerHandSeatFallback(int id);

  /// No description provided for @pokerHandPlayerFallback.
  ///
  /// In en, this message translates to:
  /// **'Player {id}'**
  String pokerHandPlayerFallback(int id);

  /// No description provided for @pokerHandChooseOption.
  ///
  /// In en, this message translates to:
  /// **'Choose an option:'**
  String get pokerHandChooseOption;

  /// No description provided for @pokerHandLeaveBtn.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get pokerHandLeaveBtn;

  /// No description provided for @pokerHandConfirmBtn.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get pokerHandConfirmBtn;

  /// No description provided for @pokerHandCurrentlyHaveRemaining.
  ///
  /// In en, this message translates to:
  /// **'You currently have {stack} remaining.'**
  String pokerHandCurrentlyHaveRemaining(String stack);

  /// No description provided for @opponentsColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get opponentsColorRed;

  /// No description provided for @opponentsColorLightBlue.
  ///
  /// In en, this message translates to:
  /// **'Light Blue'**
  String get opponentsColorLightBlue;

  /// No description provided for @opponentsColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get opponentsColorGreen;

  /// No description provided for @opponentsColorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get opponentsColorOrange;

  /// No description provided for @opponentsColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get opponentsColorPurple;

  /// No description provided for @opponentsColorTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get opponentsColorTeal;

  /// No description provided for @opponentsColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get opponentsColorPink;

  /// No description provided for @opponentsColorIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get opponentsColorIndigo;

  /// No description provided for @opponentsFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load opponents: {error}'**
  String opponentsFailedToLoad(String error);

  /// No description provided for @opponentDetailFoldTo3Bet.
  ///
  /// In en, this message translates to:
  /// **'Fold to 3-Bet'**
  String get opponentDetailFoldTo3Bet;

  /// No description provided for @opponentDetailStealLabel.
  ///
  /// In en, this message translates to:
  /// **'Steal'**
  String get opponentDetailStealLabel;

  /// No description provided for @opponentDetailCheckRaiseLabel.
  ///
  /// In en, this message translates to:
  /// **'Check/Raise'**
  String get opponentDetailCheckRaiseLabel;

  /// No description provided for @individualSetupSessionSetup.
  ///
  /// In en, this message translates to:
  /// **'Session Setup'**
  String get individualSetupSessionSetup;

  /// No description provided for @individualSetupSessionNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Session Name'**
  String get individualSetupSessionNameLabel;

  /// No description provided for @individualSetupGameTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Game Type'**
  String get individualSetupGameTypeLabel;

  /// No description provided for @individualSetupCashGameLabel.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get individualSetupCashGameLabel;

  /// No description provided for @individualSetupTournamentLabel.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get individualSetupTournamentLabel;

  /// No description provided for @individualSetupBuyInAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Buy-in Amount'**
  String get individualSetupBuyInAmountLabel;

  /// No description provided for @individualSetupEnterAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get individualSetupEnterAmountHint;

  /// No description provided for @individualSetupCashGameNote.
  ///
  /// In en, this message translates to:
  /// **'In cash games your starting stack equals your buy-in amount.'**
  String get individualSetupCashGameNote;

  /// No description provided for @individualSetupStartingStackLabel.
  ///
  /// In en, this message translates to:
  /// **'Starting Stack'**
  String get individualSetupStartingStackLabel;

  /// No description provided for @individualSetupEnterChipStackHint.
  ///
  /// In en, this message translates to:
  /// **'Enter chip stack'**
  String get individualSetupEnterChipStackHint;

  /// No description provided for @individualSetupStackValidation.
  ///
  /// In en, this message translates to:
  /// **'Starting stack must be at least equal to the Big Blind ({bigBlind})'**
  String individualSetupStackValidation(int bigBlind);

  /// No description provided for @individualSetupStartSessionBtn.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get individualSetupStartSessionBtn;

  /// No description provided for @individualSetupEnterValueHint.
  ///
  /// In en, this message translates to:
  /// **'Enter value'**
  String get individualSetupEnterValueHint;

  /// No description provided for @individualHandSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Individual Hand'**
  String get individualHandSetupTitle;

  /// No description provided for @individualHandSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick hand logging setup'**
  String get individualHandSetupSubtitle;

  /// No description provided for @individualHandSetupHandNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Hand Name (Optional)'**
  String get individualHandSetupHandNameLabel;

  /// No description provided for @playerSessionBluff.
  ///
  /// In en, this message translates to:
  /// **'Bluff'**
  String get playerSessionBluff;

  /// No description provided for @playerSessionValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get playerSessionValue;

  /// No description provided for @playerSessionMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake'**
  String get playerSessionMistake;

  /// No description provided for @playerSessionCooler.
  ///
  /// In en, this message translates to:
  /// **'Cooler'**
  String get playerSessionCooler;

  /// No description provided for @playerSessionHeroCall.
  ///
  /// In en, this message translates to:
  /// **'Hero Call'**
  String get playerSessionHeroCall;

  /// No description provided for @playerSessionExploit.
  ///
  /// In en, this message translates to:
  /// **'Exploit'**
  String get playerSessionExploit;

  /// No description provided for @playerSessionToughSpot.
  ///
  /// In en, this message translates to:
  /// **'Tough Spot'**
  String get playerSessionToughSpot;

  /// No description provided for @playerSessionEasyFold.
  ///
  /// In en, this message translates to:
  /// **'Easy Fold'**
  String get playerSessionEasyFold;

  /// No description provided for @playerSessionEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Ended'**
  String get playerSessionEndedTitle;

  /// No description provided for @playerSessionEndedBody.
  ///
  /// In en, this message translates to:
  /// **'The dealer has ended this session.'**
  String get playerSessionEndedBody;

  /// No description provided for @playerSessionRemovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Removed from Table'**
  String get playerSessionRemovedTitle;

  /// No description provided for @playerSessionRemovedBody.
  ///
  /// In en, this message translates to:
  /// **'You have been removed from the table by the dealer.'**
  String get playerSessionRemovedBody;

  /// No description provided for @playerSessionYouWon.
  ///
  /// In en, this message translates to:
  /// **'You won {amount}!'**
  String playerSessionYouWon(String amount);

  /// No description provided for @playerSessionSeatWins.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat} wins {amount}'**
  String playerSessionSeatWins(int seat, String amount);

  /// No description provided for @playerSessionYourHoleCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Hole Cards'**
  String get playerSessionYourHoleCardsTitle;

  /// No description provided for @playerSessionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get playerSessionConnecting;

  /// No description provided for @playerSessionGoBackBtn.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get playerSessionGoBackBtn;

  /// No description provided for @playerSessionHoleCardsLabel.
  ///
  /// In en, this message translates to:
  /// **'Hole Cards'**
  String get playerSessionHoleCardsLabel;

  /// No description provided for @playerSessionEditBtn.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get playerSessionEditBtn;

  /// No description provided for @playerSessionAddBtn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get playerSessionAddBtn;

  /// No description provided for @playerSessionBoardLabel.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get playerSessionBoardLabel;

  /// No description provided for @playerSessionNoCardsDealt.
  ///
  /// In en, this message translates to:
  /// **'No cards dealt'**
  String get playerSessionNoCardsDealt;

  /// No description provided for @playerSessionWaitingForAction.
  ///
  /// In en, this message translates to:
  /// **'Waiting for action...'**
  String get playerSessionWaitingForAction;

  /// No description provided for @playerSessionActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get playerSessionActionsLabel;

  /// No description provided for @playerSessionYouLabel.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get playerSessionYouLabel;

  /// No description provided for @playerSessionSeatFallback.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}'**
  String playerSessionSeatFallback(int seat);

  /// No description provided for @playerSessionNotesHintText.
  ///
  /// In en, this message translates to:
  /// **'Add notes about this hand...'**
  String get playerSessionNotesHintText;

  /// No description provided for @playerSessionHandHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Hand History'**
  String get playerSessionHandHistoryLabel;

  /// No description provided for @playerSessionNoCompletedHands.
  ///
  /// In en, this message translates to:
  /// **'No completed hands yet'**
  String get playerSessionNoCompletedHands;

  /// No description provided for @playerSessionWonAmount.
  ///
  /// In en, this message translates to:
  /// **'Won {amount}'**
  String playerSessionWonAmount(String amount);

  /// No description provided for @playerSessionLostLabel.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get playerSessionLostLabel;

  /// No description provided for @playerSessionDealerChangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Dealer Change'**
  String get playerSessionDealerChangeTitle;

  /// No description provided for @playerSessionWaitingForDealer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new dealer to take over...'**
  String get playerSessionWaitingForDealer;

  /// No description provided for @playerSessionHandUpdated.
  ///
  /// In en, this message translates to:
  /// **'Hand #{number} updated'**
  String playerSessionHandUpdated(int number);

  /// No description provided for @playerSessionErrorSaving.
  ///
  /// In en, this message translates to:
  /// **'Error saving: {error}'**
  String playerSessionErrorSaving(String error);

  /// No description provided for @playerSessionEditHand.
  ///
  /// In en, this message translates to:
  /// **'Edit Hand #{number}'**
  String playerSessionEditHand(int number);

  /// No description provided for @playerSessionViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get playerSessionViewDetails;

  /// No description provided for @playerSessionTapToAddHoleCards.
  ///
  /// In en, this message translates to:
  /// **'Tap to add hole cards'**
  String get playerSessionTapToAddHoleCards;

  /// No description provided for @playerSessionSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get playerSessionSaveChanges;

  /// No description provided for @playerSessionLeaveTableTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Table?'**
  String get playerSessionLeaveTableTitle;

  /// No description provided for @playerSessionLeaveTableBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this table?'**
  String get playerSessionLeaveTableBody;

  /// No description provided for @playerSessionFailedLeave.
  ///
  /// In en, this message translates to:
  /// **'Failed to leave: {error}'**
  String playerSessionFailedLeave(String error);

  /// No description provided for @playerSessionTableSession.
  ///
  /// In en, this message translates to:
  /// **'Table Session'**
  String get playerSessionTableSession;

  /// No description provided for @playerSessionHandNumber.
  ///
  /// In en, this message translates to:
  /// **'Hand #{number}'**
  String playerSessionHandNumber(int number);

  /// No description provided for @playerSessionUnknownDealer.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get playerSessionUnknownDealer;

  /// No description provided for @playerSessionNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get playerSessionNotAuthenticated;

  /// No description provided for @dealerQrScanSessionSettings.
  ///
  /// In en, this message translates to:
  /// **'Session Settings'**
  String get dealerQrScanSessionSettings;

  /// No description provided for @dealerQrScanTableNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Table: {name}'**
  String dealerQrScanTableNameLabel(String name);

  /// No description provided for @dealerQrScanEventNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Event: {name}'**
  String dealerQrScanEventNameLabel(String name);

  /// No description provided for @dealerQrScanBlindsLabel.
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get dealerQrScanBlindsLabel;

  /// No description provided for @dealerQrScanSmallBlindLabel.
  ///
  /// In en, this message translates to:
  /// **'Small Blind'**
  String get dealerQrScanSmallBlindLabel;

  /// No description provided for @dealerQrScanBigBlindLabel.
  ///
  /// In en, this message translates to:
  /// **'Big Blind'**
  String get dealerQrScanBigBlindLabel;

  /// No description provided for @dealerQrScanStartDealingBtn.
  ///
  /// In en, this message translates to:
  /// **'Start Dealing'**
  String get dealerQrScanStartDealingBtn;

  /// No description provided for @dealerQrScanResumeSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Resume Session'**
  String get dealerQrScanResumeSessionTitle;

  /// No description provided for @dealerQrScanTakingOverFrom.
  ///
  /// In en, this message translates to:
  /// **'Taking over from {name}'**
  String dealerQrScanTakingOverFrom(String name);

  /// No description provided for @dealerQrScanHandsPlayedLabel.
  ///
  /// In en, this message translates to:
  /// **'Hands Played'**
  String get dealerQrScanHandsPlayedLabel;

  /// No description provided for @dealerQrScanBlindsInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get dealerQrScanBlindsInfoLabel;

  /// No description provided for @dealerQrScanPlayersLabel.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get dealerQrScanPlayersLabel;

  /// No description provided for @dealerQrScanResumeBtn.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get dealerQrScanResumeBtn;

  /// No description provided for @dealerQrScanTableNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'Table Not Assigned'**
  String get dealerQrScanTableNotAssigned;

  /// No description provided for @dealerQrScanEventTablesLabel.
  ///
  /// In en, this message translates to:
  /// **'Event tables:'**
  String get dealerQrScanEventTablesLabel;

  /// No description provided for @dealerQrScanNoTablesAssigned.
  ///
  /// In en, this message translates to:
  /// **'No tables assigned'**
  String get dealerQrScanNoTablesAssigned;

  /// No description provided for @dealerQrScanThisTableId.
  ///
  /// In en, this message translates to:
  /// **'This table\'s ID:'**
  String get dealerQrScanThisTableId;

  /// No description provided for @dealerQrScanCorrectQrUrl.
  ///
  /// In en, this message translates to:
  /// **'Correct QR code URL:'**
  String get dealerQrScanCorrectQrUrl;

  /// No description provided for @dealerQrScanScanTableQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Table QR'**
  String get dealerQrScanScanTableQrTitle;

  /// No description provided for @dealerQrScanScanInstructions.
  ///
  /// In en, this message translates to:
  /// **'Scan the table QR code to start dealing'**
  String get dealerQrScanScanInstructions;

  /// No description provided for @eventDashboardTournamentOnBreak.
  ///
  /// In en, this message translates to:
  /// **'Tournament on Break'**
  String get eventDashboardTournamentOnBreak;

  /// No description provided for @eventDashboardLiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get eventDashboardLiveLabel;

  /// No description provided for @eventDashboardLocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get eventDashboardLocalLabel;

  /// No description provided for @eventDashboardDisconnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get eventDashboardDisconnectedLabel;

  /// No description provided for @eventDashboardPlayersLabel.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get eventDashboardPlayersLabel;

  /// No description provided for @eventDashboardTablesLabel.
  ///
  /// In en, this message translates to:
  /// **'Tables'**
  String get eventDashboardTablesLabel;

  /// No description provided for @eventDashboardTotalChipsLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Chips'**
  String get eventDashboardTotalChipsLabel;

  /// No description provided for @eventDashboardAvgStackLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg Stack'**
  String get eventDashboardAvgStackLabel;

  /// No description provided for @eventDashboardChipLeaderLabel.
  ///
  /// In en, this message translates to:
  /// **'Chip Leader'**
  String get eventDashboardChipLeaderLabel;

  /// No description provided for @eventDashboardNoRankingsYet.
  ///
  /// In en, this message translates to:
  /// **'No Rankings Yet'**
  String get eventDashboardNoRankingsYet;

  /// No description provided for @eventDashboardRankingsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Rankings will appear as players join tables'**
  String get eventDashboardRankingsWillAppear;

  /// No description provided for @eventDashboardTableSeatLabel.
  ///
  /// In en, this message translates to:
  /// **'{table} - Seat {seat}'**
  String eventDashboardTableSeatLabel(String table, int seat);

  /// No description provided for @eventDashboardPlayerFallback.
  ///
  /// In en, this message translates to:
  /// **'Player {id}'**
  String eventDashboardPlayerFallback(String id);

  /// No description provided for @commonNA.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get commonNA;

  /// No description provided for @sessionHistoryFailedLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sessions: {error}'**
  String sessionHistoryFailedLoad(String error);

  /// No description provided for @sessionHistoryCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get sessionHistoryCash;

  /// No description provided for @sessionHistoryTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get sessionHistoryTournament;

  /// No description provided for @sessionHistorySessionId.
  ///
  /// In en, this message translates to:
  /// **'Session {id}...'**
  String sessionHistorySessionId(String id);

  /// No description provided for @sessionHistorySeatWithPosition.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat} ({position})'**
  String sessionHistorySeatWithPosition(String seat, String position);

  /// No description provided for @sessionHistorySeat.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}'**
  String sessionHistorySeat(String seat);

  /// No description provided for @sessionHistorySyncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get sessionHistorySyncCompleted;

  /// No description provided for @sessionHistoryFullHistory.
  ///
  /// In en, this message translates to:
  /// **'Full session history'**
  String get sessionHistoryFullHistory;

  /// No description provided for @sessionHandsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sessionHandsRetry;

  /// No description provided for @stackChartScreenStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get stackChartScreenStart;

  /// No description provided for @stackChartScreenRebuy.
  ///
  /// In en, this message translates to:
  /// **'Rebuy'**
  String get stackChartScreenRebuy;

  /// No description provided for @stackChartScreenEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get stackChartScreenEnd;

  /// No description provided for @quickStackSelectPlayer.
  ///
  /// In en, this message translates to:
  /// **'Select Player'**
  String get quickStackSelectPlayer;

  /// No description provided for @quickStackAddPlayer.
  ///
  /// In en, this message translates to:
  /// **'Add \"{name}\"'**
  String quickStackAddPlayer(String name);

  /// No description provided for @quickStackSaveToOpponents.
  ///
  /// In en, this message translates to:
  /// **'Save to opponent list'**
  String get quickStackSaveToOpponents;

  /// No description provided for @quickStackYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get quickStackYou;

  /// No description provided for @quickStackNoPlayersFound.
  ///
  /// In en, this message translates to:
  /// **'No players found.'**
  String get quickStackNoPlayersFound;

  /// No description provided for @seatSetupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get seatSetupDone;

  /// No description provided for @seatSetupCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get seatSetupCancel;

  /// No description provided for @authConnectionIssue.
  ///
  /// In en, this message translates to:
  /// **'Connection Issue'**
  String get authConnectionIssue;

  /// No description provided for @authConnectionIssueBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t connect to our servers.\nPlease check your internet connection\nand try again.'**
  String get authConnectionIssueBody;

  /// No description provided for @authTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get authTryAgain;

  /// No description provided for @redeemInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem Invitation'**
  String get redeemInvitationTitle;

  /// No description provided for @redeemEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Invitation Code'**
  String get redeemEnterCode;

  /// No description provided for @redeemCodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-character code you received from a club admin to join their club.'**
  String get redeemCodeDescription;

  /// No description provided for @redeemJoinClub.
  ///
  /// In en, this message translates to:
  /// **'Join Club'**
  String get redeemJoinClub;

  /// No description provided for @redeemWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get redeemWelcome;

  /// No description provided for @redeemJoinedAs.
  ///
  /// In en, this message translates to:
  /// **'You have joined {clubName} as {role}'**
  String redeemJoinedAs(String clubName, String role);

  /// No description provided for @redeemContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get redeemContinue;

  /// No description provided for @supportBugReport.
  ///
  /// In en, this message translates to:
  /// **'Bug Report'**
  String get supportBugReport;

  /// No description provided for @supportFeatureRequest.
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get supportFeatureRequest;

  /// No description provided for @supportAccountIssue.
  ///
  /// In en, this message translates to:
  /// **'Account Issue'**
  String get supportAccountIssue;

  /// No description provided for @supportOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get supportOther;

  /// No description provided for @supportFillAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get supportFillAllFields;

  /// No description provided for @supportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Support request submitted successfully'**
  String get supportSubmitted;

  /// No description provided for @supportFailedSubmit.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit: {error}'**
  String supportFailedSubmit(String error);

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get supportTitle;

  /// No description provided for @supportSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get supportSubmitButton;

  /// No description provided for @supportCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get supportCategoryLabel;

  /// No description provided for @supportSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get supportSubjectLabel;

  /// No description provided for @supportDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get supportDescriptionLabel;

  /// No description provided for @supportSubjectHint.
  ///
  /// In en, this message translates to:
  /// **'Brief summary of the issue'**
  String get supportSubjectHint;

  /// No description provided for @supportDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue in detail...'**
  String get supportDescriptionHint;

  /// No description provided for @calendarEventLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get calendarEventLocation;

  /// No description provided for @calendarEventBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Buy-in amount'**
  String get calendarEventBuyIn;

  /// No description provided for @calendarEventEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get calendarEventEdit;

  /// No description provided for @calendarEventDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get calendarEventDelete;

  /// No description provided for @calendarEventDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}?'**
  String calendarEventDeleteConfirm(String title);

  /// No description provided for @calendarEventDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"?\nThis action cannot be undone.'**
  String calendarEventDeleteBody(String title);

  /// No description provided for @calendarEventDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get calendarEventDeleteButton;

  /// No description provided for @clubInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Club Info'**
  String get clubInfoTitle;

  /// No description provided for @clubInfoMembersCount.
  ///
  /// In en, this message translates to:
  /// **'Members ({count})'**
  String clubInfoMembersCount(int count);

  /// No description provided for @clubInfoNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No members found'**
  String get clubInfoNoMembers;

  /// No description provided for @finalStandingsNoData.
  ///
  /// In en, this message translates to:
  /// **'No standings available'**
  String get finalStandingsNoData;

  /// No description provided for @finalStandingsNoDataHint.
  ///
  /// In en, this message translates to:
  /// **'This event may not have recorded standings'**
  String get finalStandingsNoDataHint;

  /// No description provided for @finalStandingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No standings recorded'**
  String get finalStandingsEmpty;

  /// No description provided for @finalStandingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Final Standings'**
  String get finalStandingsTitle;

  /// No description provided for @finalStandingsPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get finalStandingsPlayers;

  /// No description provided for @finalStandingsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get finalStandingsCompleted;

  /// No description provided for @liveRankingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Rankings'**
  String get liveRankingsTitle;

  /// No description provided for @liveRankingsEliminated.
  ///
  /// In en, this message translates to:
  /// **'Eliminated players'**
  String get liveRankingsEliminated;

  /// No description provided for @liveRankingsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Players'**
  String get liveRankingsWaiting;

  /// No description provided for @liveRankingsWaitingHint.
  ///
  /// In en, this message translates to:
  /// **'Rankings will appear once players get seated'**
  String get liveRankingsWaitingHint;

  /// No description provided for @liveRankingsError.
  ///
  /// In en, this message translates to:
  /// **'Error Loading Rankings'**
  String get liveRankingsError;

  /// No description provided for @liveRankingsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get liveRankingsTryAgain;

  /// No description provided for @leaderboardPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get leaderboardPlayers;

  /// No description provided for @leaderboardTotalChips.
  ///
  /// In en, this message translates to:
  /// **'Total Chips'**
  String get leaderboardTotalChips;

  /// No description provided for @leaderboardWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for players...'**
  String get leaderboardWaiting;

  /// No description provided for @leaderboardChipLeader.
  ///
  /// In en, this message translates to:
  /// **'Chip Leader: {name}'**
  String leaderboardChipLeader(String name);

  /// No description provided for @dealerQrScanBbAnte.
  ///
  /// In en, this message translates to:
  /// **'BB Ante'**
  String get dealerQrScanBbAnte;

  /// No description provided for @mainDealerOnClub.
  ///
  /// In en, this message translates to:
  /// **'You are now a dealer on {clubName}'**
  String mainDealerOnClub(String clubName);

  /// No description provided for @raiseSnapMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get raiseSnapMin;

  /// No description provided for @raiseSnapPot.
  ///
  /// In en, this message translates to:
  /// **'Pot'**
  String get raiseSnapPot;

  /// No description provided for @raiseSnapAllIn.
  ///
  /// In en, this message translates to:
  /// **'All-In'**
  String get raiseSnapAllIn;

  /// No description provided for @sessionHistoryPlayerWins.
  ///
  /// In en, this message translates to:
  /// **'Player {playerId} wins:'**
  String sessionHistoryPlayerWins(int playerId);

  /// No description provided for @inviteClubAdminFallback.
  ///
  /// In en, this message translates to:
  /// **'Club Admin'**
  String get inviteClubAdminFallback;

  /// No description provided for @pokerHandBetRange.
  ///
  /// In en, this message translates to:
  /// **'Min: {min} · Max: {max}'**
  String pokerHandBetRange(String min, String max);

  /// No description provided for @pokerHandAmountBetween.
  ///
  /// In en, this message translates to:
  /// **'Amount must be between {min} and {max}'**
  String pokerHandAmountBetween(String min, String max);

  /// No description provided for @dealerTableBlindsLabel.
  ///
  /// In en, this message translates to:
  /// **'BLINDS'**
  String get dealerTableBlindsLabel;

  /// No description provided for @dealerTableAnteLabel.
  ///
  /// In en, this message translates to:
  /// **'ANTE {amount}'**
  String dealerTableAnteLabel(String amount);

  /// No description provided for @dealerTablePotLabel.
  ///
  /// In en, this message translates to:
  /// **'POT'**
  String get dealerTablePotLabel;

  /// No description provided for @dealerTableCheckLabel.
  ///
  /// In en, this message translates to:
  /// **'CHECK'**
  String get dealerTableCheckLabel;

  /// No description provided for @dealerTablePlayerToAct.
  ///
  /// In en, this message translates to:
  /// **'{playerName} to act ({stack})'**
  String dealerTablePlayerToAct(String playerName, String stack);

  /// No description provided for @eventDashboardOnBreakBadge.
  ///
  /// In en, this message translates to:
  /// **'ON BREAK'**
  String get eventDashboardOnBreakBadge;

  /// No description provided for @eventDetailAdminActions.
  ///
  /// In en, this message translates to:
  /// **'ADMIN ACTIONS'**
  String get eventDetailAdminActions;

  /// No description provided for @playerSessionHandNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'HAND NOTES'**
  String get playerSessionHandNotesLabel;

  /// No description provided for @playerSessionTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'TAGS'**
  String get playerSessionTagsLabel;

  /// No description provided for @playerSessionNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get playerSessionNotesLabel;

  /// No description provided for @playerSessionHoleCardsUpperLabel.
  ///
  /// In en, this message translates to:
  /// **'HOLE CARDS'**
  String get playerSessionHoleCardsUpperLabel;

  /// No description provided for @qrJoinDeclined.
  ///
  /// In en, this message translates to:
  /// **'Your join request was declined'**
  String get qrJoinDeclined;

  /// No description provided for @qrJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join seat: {error}'**
  String qrJoinFailed(String error);

  /// No description provided for @qrJoinTable.
  ///
  /// In en, this message translates to:
  /// **'Join Table'**
  String get qrJoinTable;

  /// No description provided for @qrJoinLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading table info...'**
  String get qrJoinLoading;

  /// No description provided for @qrJoinError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get qrJoinError;

  /// No description provided for @qrJoinGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get qrJoinGoBack;

  /// No description provided for @qrJoinSeatOccupied.
  ///
  /// In en, this message translates to:
  /// **'This seat may already be occupied. Joining will replace the current player.'**
  String get qrJoinSeatOccupied;

  /// No description provided for @qrJoinWaitingDealer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Dealer'**
  String get qrJoinWaitingDealer;

  /// No description provided for @qrJoinRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Your request to join Seat {seatNumber} has been sent.'**
  String qrJoinRequestSent(int seatNumber);

  /// No description provided for @qrJoinDealerApproval.
  ///
  /// In en, this message translates to:
  /// **'The dealer will set your chip stack and approve your join.'**
  String get qrJoinDealerApproval;

  /// No description provided for @qrJoinCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get qrJoinCancelRequest;

  /// No description provided for @qrJoinRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Request to Join'**
  String get qrJoinRequestButton;

  /// No description provided for @onboardingSkipTour.
  ///
  /// In en, this message translates to:
  /// **'Skip tour'**
  String get onboardingSkipTour;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to\nFinal Table'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Let\'s take a quick tour to get you started.\n\nYou can always retake this tour from\nProfile → Settings → Knowledge Base.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingLetsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get onboardingLetsGo;

  /// No description provided for @onboardingGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get onboardingGotIt;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStartLoggingTitle.
  ///
  /// In en, this message translates to:
  /// **'Start Logging'**
  String get onboardingStartLoggingTitle;

  /// No description provided for @onboardingStartLoggingBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to begin logging a hand.'**
  String get onboardingStartLoggingBody;

  /// No description provided for @onboardingFullModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Logging Mode'**
  String get onboardingFullModeTitle;

  /// No description provided for @onboardingFullModeBody.
  ///
  /// In en, this message translates to:
  /// **'Track every action for every player across all streets. Perfect for serious analysis.'**
  String get onboardingFullModeBody;

  /// No description provided for @onboardingIndividualModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Individual Logging Mode'**
  String get onboardingIndividualModeTitle;

  /// No description provided for @onboardingIndividualModeBody.
  ///
  /// In en, this message translates to:
  /// **'Quick profit/loss tracking for a single session. Now choose a mode to continue!'**
  String get onboardingIndividualModeBody;

  /// No description provided for @onboardingSessionSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Details'**
  String get onboardingSessionSetupTitle;

  /// No description provided for @onboardingSessionSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Here you can set your session name, game type, blinds, buy-in amount, and starting stack.'**
  String get onboardingSessionSetupBody;

  /// No description provided for @onboardingTableSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup Your Table'**
  String get onboardingTableSetupTitle;

  /// No description provided for @onboardingTableSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Now, fill in the session details and set up the table. Tap a seat to place yourself and your opponents, and drag the dealer button (D) to set the button position. Tap the ✓ icon on the top right corner when you are ready.'**
  String get onboardingTableSetupBody;

  /// No description provided for @onboardingSeatOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Seat Open'**
  String get onboardingSeatOpenTitle;

  /// No description provided for @onboardingSeatOpenBody.
  ///
  /// In en, this message translates to:
  /// **'Toggle to mark a seat as occupied or empty. Open seats are skipped during the hand.'**
  String get onboardingSeatOpenBody;

  /// No description provided for @onboardingThisIsMySeatTitle.
  ///
  /// In en, this message translates to:
  /// **'This Is My Seat'**
  String get onboardingThisIsMySeatTitle;

  /// No description provided for @onboardingThisIsMySeatBody.
  ///
  /// In en, this message translates to:
  /// **'Tap here if this is your seat. It auto-fills your name and tracks your personal stats.'**
  String get onboardingThisIsMySeatBody;

  /// No description provided for @onboardingPlayerNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Player Name'**
  String get onboardingPlayerNameTitle;

  /// No description provided for @onboardingPlayerNameBody.
  ///
  /// In en, this message translates to:
  /// **'Type a name or pick from your saved opponents. Saved opponents track stats across sessions.'**
  String get onboardingPlayerNameBody;

  /// No description provided for @onboardingSaveOpponentTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Opponent'**
  String get onboardingSaveOpponentTitle;

  /// No description provided for @onboardingSaveOpponentBody.
  ///
  /// In en, this message translates to:
  /// **'New name? Tap here to save them as an opponent. Their stats will be tracked automatically.'**
  String get onboardingSaveOpponentBody;

  /// No description provided for @onboardingDealerButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Dealer Button'**
  String get onboardingDealerButtonTitle;

  /// No description provided for @onboardingDealerButtonBody.
  ///
  /// In en, this message translates to:
  /// **'Drag this to the seat with the dealer position. It determines blinds and action order.'**
  String get onboardingDealerButtonBody;

  /// No description provided for @onboardingViewSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'View Your Sessions'**
  String get onboardingViewSessionsTitle;

  /// No description provided for @onboardingViewSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap Sessions to see your session results, hand history, and stats.'**
  String get onboardingViewSessionsBody;

  /// No description provided for @onboardingAllSetTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set!'**
  String get onboardingAllSetTitle;

  /// No description provided for @onboardingAllSetBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re ready to start tracking your poker sessions.'**
  String get onboardingAllSetBody;

  /// No description provided for @onboardingLetsPlay.
  ///
  /// In en, this message translates to:
  /// **'Let\'s play'**
  String get onboardingLetsPlay;

  /// No description provided for @onboardingUpdateStackTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Stack'**
  String get onboardingUpdateStackTitle;

  /// No description provided for @onboardingUpdateStackBody.
  ///
  /// In en, this message translates to:
  /// **'Use this to manually update your chip count at any point without logging a full hand.'**
  String get onboardingUpdateStackBody;

  /// No description provided for @onboardingLogAHandTitle.
  ///
  /// In en, this message translates to:
  /// **'Log a Hand'**
  String get onboardingLogAHandTitle;

  /// No description provided for @onboardingLogAHandBody.
  ///
  /// In en, this message translates to:
  /// **'Tap here to set up the table and log a hand. Let\'s try it now!'**
  String get onboardingLogAHandBody;

  /// No description provided for @onboardingMarkSeatOpenTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark Seat Open'**
  String get onboardingMarkSeatOpenTitle;

  /// No description provided for @onboardingMarkSeatOpenBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the checkmark to toggle a seat between occupied and empty. Empty seats are skipped in the hand.'**
  String get onboardingMarkSeatOpenBody;

  /// No description provided for @onboardingDealerButtonQsuTitle.
  ///
  /// In en, this message translates to:
  /// **'Dealer Button'**
  String get onboardingDealerButtonQsuTitle;

  /// No description provided for @onboardingDealerButtonQsuBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"D\" to assign the dealer button to any seat. This controls blind positions and action order.'**
  String get onboardingDealerButtonQsuBody;

  /// No description provided for @onboardingAssignPlayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign a Player'**
  String get onboardingAssignPlayerTitle;

  /// No description provided for @onboardingAssignPlayerBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a player\'s name to seat yourself or a saved opponent. Your stack is auto-applied when you seat yourself.'**
  String get onboardingAssignPlayerBody;

  /// No description provided for @onboardingAdjustStackTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust Stack'**
  String get onboardingAdjustStackTitle;

  /// No description provided for @onboardingAdjustStackBody.
  ///
  /// In en, this message translates to:
  /// **'Drag the slider to set an opponent\'s stack in BBs. Tap the stack value to type an exact amount.'**
  String get onboardingAdjustStackBody;

  /// No description provided for @onboardingEndSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'End Your Session'**
  String get onboardingEndSessionTitle;

  /// No description provided for @onboardingEndSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the red Stop button to save your session results and return to the home screen.'**
  String get onboardingEndSessionBody;

  /// No description provided for @onboardingStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String onboardingStepOf(int step, int total);

  /// No description provided for @guidedGestureGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Gesture Guide'**
  String get guidedGestureGuideTitle;

  /// No description provided for @guidedGestureGuideBody.
  ///
  /// In en, this message translates to:
  /// **'Tap this icon anytime to see all gesture controls.'**
  String get guidedGestureGuideBody;

  /// No description provided for @guidedSkipButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip Button'**
  String get guidedSkipButtonTitle;

  /// No description provided for @guidedSkipButtonBody.
  ///
  /// In en, this message translates to:
  /// **'If you skip a hand, this button moves the dealer button to the next player. Keep in mind that stacks will be out of sync — you can update them in Manage Players.'**
  String get guidedSkipButtonBody;

  /// No description provided for @guidedGameMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Menu'**
  String get guidedGameMenuTitle;

  /// No description provided for @guidedGameMenuBody.
  ///
  /// In en, this message translates to:
  /// **'This menu has useful options. Let\'s take a look at one important setting.'**
  String get guidedGameMenuBody;

  /// No description provided for @guidedGameSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Game Settings'**
  String get guidedGameSettingsTitle;

  /// No description provided for @guidedGameSettingsBody.
  ///
  /// In en, this message translates to:
  /// **'Here you can change blinds mid-session — useful for tournaments when levels go up.'**
  String get guidedGameSettingsBody;

  /// No description provided for @guidedEndSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'End Your Session'**
  String get guidedEndSessionTitle;

  /// No description provided for @guidedEndSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Tap this menu and select \"Stop Session\" to save your results.'**
  String get guidedEndSessionBody;

  /// No description provided for @guidedReviewHandTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Hand'**
  String get guidedReviewHandTitle;

  /// No description provided for @guidedReviewHandBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your hole cards and any notes.'**
  String get guidedReviewHandBody;

  /// No description provided for @guidedHandCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand Complete!'**
  String get guidedHandCompleteTitle;

  /// No description provided for @guidedHandCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Great job! You just logged your first hand.'**
  String get guidedHandCompleteBody;

  /// No description provided for @guidedSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get guidedSkip;

  /// No description provided for @guidedYourTurn.
  ///
  /// In en, this message translates to:
  /// **'Your Turn!'**
  String get guidedYourTurn;

  /// No description provided for @guidedOpenThePotTitle.
  ///
  /// In en, this message translates to:
  /// **'Open the Pot'**
  String get guidedOpenThePotTitle;

  /// No description provided for @guidedBetOnceBody.
  ///
  /// In en, this message translates to:
  /// **'This player bets.'**
  String get guidedBetOnceBody;

  /// No description provided for @guidedFoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Fold'**
  String get guidedFoldTitle;

  /// No description provided for @guidedFoldBody.
  ///
  /// In en, this message translates to:
  /// **'This player folds.'**
  String get guidedFoldBody;

  /// No description provided for @guidedCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get guidedCallTitle;

  /// No description provided for @guidedCallBody.
  ///
  /// In en, this message translates to:
  /// **'This player calls.'**
  String get guidedCallBody;

  /// No description provided for @guidedCheckTitle.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get guidedCheckTitle;

  /// No description provided for @guidedCheckBody.
  ///
  /// In en, this message translates to:
  /// **'This player checks.'**
  String get guidedCheckBody;

  /// No description provided for @guidedGestureFold.
  ///
  /// In en, this message translates to:
  /// **'Swipe left ←'**
  String get guidedGestureFold;

  /// No description provided for @guidedGestureCheck.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get guidedGestureCheck;

  /// No description provided for @guidedGestureCall.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get guidedGestureCall;

  /// No description provided for @guidedGestureBet.
  ///
  /// In en, this message translates to:
  /// **'Swipe up ↑'**
  String get guidedGestureBet;

  /// No description provided for @guidedGestureRaise.
  ///
  /// In en, this message translates to:
  /// **'Swipe up ↑'**
  String get guidedGestureRaise;

  /// No description provided for @guidedActionFold.
  ///
  /// In en, this message translates to:
  /// **'Fold'**
  String get guidedActionFold;

  /// No description provided for @guidedActionCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get guidedActionCheck;

  /// No description provided for @guidedActionCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get guidedActionCall;

  /// No description provided for @guidedActionBet.
  ///
  /// In en, this message translates to:
  /// **'Bet'**
  String get guidedActionBet;

  /// No description provided for @guidedActionRaise.
  ///
  /// In en, this message translates to:
  /// **'Raise'**
  String get guidedActionRaise;

  /// No description provided for @guidedDealFlopTitle.
  ///
  /// In en, this message translates to:
  /// **'Deal the Flop'**
  String get guidedDealFlopTitle;

  /// No description provided for @guidedDealFlopBody.
  ///
  /// In en, this message translates to:
  /// **'Drag a rank to a suit to select a card. Tap a selected card to remove it. Pick 3 cards for the flop.'**
  String get guidedDealFlopBody;

  /// No description provided for @guidedDealTurnTitle.
  ///
  /// In en, this message translates to:
  /// **'Deal the Turn'**
  String get guidedDealTurnTitle;

  /// No description provided for @guidedDealTurnBody.
  ///
  /// In en, this message translates to:
  /// **'Select 1 card for the turn.'**
  String get guidedDealTurnBody;

  /// No description provided for @guidedDealRiverTitle.
  ///
  /// In en, this message translates to:
  /// **'Deal the River'**
  String get guidedDealRiverTitle;

  /// No description provided for @guidedDealRiverBody.
  ///
  /// In en, this message translates to:
  /// **'Select 1 card for the river.'**
  String get guidedDealRiverBody;

  /// No description provided for @guidedStackRingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stack Range'**
  String get guidedStackRingTitle;

  /// No description provided for @guidedStackRingBody.
  ///
  /// In en, this message translates to:
  /// **'Press and hold the ring, rotate your finger to select a stack range, then release. This helps you set up opponents\' stacks before the flop.'**
  String get guidedStackRingBody;

  /// No description provided for @guidedTableButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Table'**
  String get guidedTableButtonTitle;

  /// No description provided for @guidedTableButtonBody.
  ///
  /// In en, this message translates to:
  /// **'Tap this button to manage players, update stacks, change seating, or move the dealer button.'**
  String get guidedTableButtonBody;

  /// No description provided for @guidedBlindsPillTitle.
  ///
  /// In en, this message translates to:
  /// **'Blinds'**
  String get guidedBlindsPillTitle;

  /// No description provided for @guidedBlindsPillBody.
  ///
  /// In en, this message translates to:
  /// **'Tap here to update the blind levels anytime — useful when tournament levels go up.'**
  String get guidedBlindsPillBody;

  /// No description provided for @guidedNextHandTitle.
  ///
  /// In en, this message translates to:
  /// **'Next Hand'**
  String get guidedNextHandTitle;

  /// No description provided for @guidedNextHandBody.
  ///
  /// In en, this message translates to:
  /// **'Tap this to skip to the next hand. It moves the dealer button, auto-tracks your stack, and deducts blinds automatically.'**
  String get guidedNextHandBody;

  /// No description provided for @guidedInfoButtonTitle.
  ///
  /// In en, this message translates to:
  /// **'Gesture Guide'**
  String get guidedInfoButtonTitle;

  /// No description provided for @guidedInfoButtonBody.
  ///
  /// In en, this message translates to:
  /// **'Tap this button anytime to see all available gesture controls for logging actions.'**
  String get guidedInfoButtonBody;

  /// No description provided for @guidedSessionInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Details'**
  String get guidedSessionInfoTitle;

  /// No description provided for @guidedSessionInfoBody.
  ///
  /// In en, this message translates to:
  /// **'Tap this button to view your session details, stack chart, and hand history. Go ahead and tap it now!'**
  String get guidedSessionInfoBody;

  /// No description provided for @guidedAddOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Add-Ons & Rebuys'**
  String get guidedAddOnTitle;

  /// No description provided for @guidedAddOnBody.
  ///
  /// In en, this message translates to:
  /// **'Manage your add-ons and rebuys here.'**
  String get guidedAddOnBody;

  /// No description provided for @guidedUpdateStackTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Stack'**
  String get guidedUpdateStackTitle;

  /// No description provided for @guidedUpdateStackBody.
  ///
  /// In en, this message translates to:
  /// **'Update your stack manually and take quick notes. They will appear on your stack chart.'**
  String get guidedUpdateStackBody;

  /// No description provided for @guidedStackChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Stack Chart'**
  String get guidedStackChartTitle;

  /// No description provided for @guidedStackChartBody.
  ///
  /// In en, this message translates to:
  /// **'Tap any point to see how your game is going.'**
  String get guidedStackChartBody;

  /// No description provided for @guidedStopSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop Session'**
  String get guidedStopSessionTitle;

  /// No description provided for @guidedStopSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Finish your session anytime you are done.'**
  String get guidedStopSessionBody;

  /// No description provided for @guidedTourCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Tour Complete!'**
  String get guidedTourCompleteTitle;

  /// No description provided for @guidedTourCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set! You can find your session data under the Sessions tab anytime.'**
  String get guidedTourCompleteBody;

  /// No description provided for @kbStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Stats'**
  String get kbStatsTitle;

  /// No description provided for @kbClubsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clubs & Events'**
  String get kbClubsTitle;

  /// No description provided for @kbStatsIntro.
  ///
  /// In en, this message translates to:
  /// **'Final Table tracks 7 core poker metrics to help you understand and improve your game.'**
  String get kbStatsIntro;

  /// No description provided for @kbClubsIntro.
  ///
  /// In en, this message translates to:
  /// **'Clubs let you connect with your local poker room and track live games.'**
  String get kbClubsIntro;

  /// No description provided for @kbVpipName.
  ///
  /// In en, this message translates to:
  /// **'VPIP'**
  String get kbVpipName;

  /// No description provided for @kbVpipFullName.
  ///
  /// In en, this message translates to:
  /// **'Voluntarily Put \$ In Pot'**
  String get kbVpipFullName;

  /// No description provided for @kbVpipDescription.
  ///
  /// In en, this message translates to:
  /// **'How often you enter a pot voluntarily (excluding blind posts). A high VPIP means you play many hands; a low VPIP means you\'re selective.'**
  String get kbVpipDescription;

  /// No description provided for @kbPfrName.
  ///
  /// In en, this message translates to:
  /// **'PFR'**
  String get kbPfrName;

  /// No description provided for @kbPfrFullName.
  ///
  /// In en, this message translates to:
  /// **'Preflop Raise'**
  String get kbPfrFullName;

  /// No description provided for @kbPfrDescription.
  ///
  /// In en, this message translates to:
  /// **'How often you raise before the flop. The gap between VPIP and PFR shows how often you limp or cold-call.'**
  String get kbPfrDescription;

  /// No description provided for @kbThreeBetName.
  ///
  /// In en, this message translates to:
  /// **'3-Bet'**
  String get kbThreeBetName;

  /// No description provided for @kbThreeBetFullName.
  ///
  /// In en, this message translates to:
  /// **'Three-Bet Percentage'**
  String get kbThreeBetFullName;

  /// No description provided for @kbThreeBetDescription.
  ///
  /// In en, this message translates to:
  /// **'How often you re-raise an opponent\'s open raise preflop. A higher 3-bet% indicates an aggressive preflop style.'**
  String get kbThreeBetDescription;

  /// No description provided for @kbFoldTo3BetName.
  ///
  /// In en, this message translates to:
  /// **'Fold to 3-Bet'**
  String get kbFoldTo3BetName;

  /// No description provided for @kbFoldTo3BetFullName.
  ///
  /// In en, this message translates to:
  /// **'Fold to Three-Bet'**
  String get kbFoldTo3BetFullName;

  /// No description provided for @kbFoldTo3BetDescription.
  ///
  /// In en, this message translates to:
  /// **'How often you fold after raising and facing a 3-bet. If too high, opponents can exploit you by 3-betting light.'**
  String get kbFoldTo3BetDescription;

  /// No description provided for @kbCBetName.
  ///
  /// In en, this message translates to:
  /// **'C-Bet'**
  String get kbCBetName;

  /// No description provided for @kbCBetFullName.
  ///
  /// In en, this message translates to:
  /// **'Continuation Bet'**
  String get kbCBetFullName;

  /// No description provided for @kbCBetDescription.
  ///
  /// In en, this message translates to:
  /// **'How often you bet on the flop after being the last preflop aggressor. A standard play showing strength.'**
  String get kbCBetDescription;

  /// No description provided for @kbStealName.
  ///
  /// In en, this message translates to:
  /// **'Steal'**
  String get kbStealName;

  /// No description provided for @kbStealFullName.
  ///
  /// In en, this message translates to:
  /// **'Blind Steal Attempt'**
  String get kbStealFullName;

  /// No description provided for @kbStealDescription.
  ///
  /// In en, this message translates to:
  /// **'How often you open-raise from late position (CO, BTN, SB) when the pot is unopened, aiming to take the blinds.'**
  String get kbStealDescription;

  /// No description provided for @kbCheckRaiseName.
  ///
  /// In en, this message translates to:
  /// **'Check-Raise'**
  String get kbCheckRaiseName;

  /// No description provided for @kbCheckRaiseFullName.
  ///
  /// In en, this message translates to:
  /// **'Flop Check-Raise'**
  String get kbCheckRaiseFullName;

  /// No description provided for @kbCheckRaiseDescription.
  ///
  /// In en, this message translates to:
  /// **'How often you check then raise on the flop. A deceptive move that can trap aggressive opponents.'**
  String get kbCheckRaiseDescription;

  /// No description provided for @kbLiveEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Events'**
  String get kbLiveEventsTitle;

  /// No description provided for @kbLiveEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Club managers create events with multiple tables. Join an event to be part of the live rankings.'**
  String get kbLiveEventsDescription;

  /// No description provided for @kbLiveRankingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Rankings'**
  String get kbLiveRankingsTitle;

  /// No description provided for @kbLiveRankingsDescription.
  ///
  /// In en, this message translates to:
  /// **'See where you stand in real-time during events. Rankings update after every hand.'**
  String get kbLiveRankingsDescription;

  /// No description provided for @kbOpponentTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Opponent Tracking'**
  String get kbOpponentTrackingTitle;

  /// No description provided for @kbOpponentTrackingDescription.
  ///
  /// In en, this message translates to:
  /// **'Players you face at the club are automatically tracked. Save opponents to build detailed profiles.'**
  String get kbOpponentTrackingDescription;

  /// No description provided for @kbQrSeatTitle.
  ///
  /// In en, this message translates to:
  /// **'QR Seat Assignment'**
  String get kbQrSeatTitle;

  /// No description provided for @kbQrSeatDescription.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code at your table to join the session instantly. Your hands are tracked automatically by the dealer.'**
  String get kbQrSeatDescription;

  /// No description provided for @kbDealerLoggingTitle.
  ///
  /// In en, this message translates to:
  /// **'Dealer-Assisted Logging'**
  String get kbDealerLoggingTitle;

  /// No description provided for @kbDealerLoggingDescription.
  ///
  /// In en, this message translates to:
  /// **'Dealers use voice commands to log actions for the entire table. No manual input needed from players.'**
  String get kbDealerLoggingDescription;

  /// No description provided for @kbSessionStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Stats'**
  String get kbSessionStatsTitle;

  /// No description provided for @kbSessionStatsDescription.
  ///
  /// In en, this message translates to:
  /// **'After each session, see your profit/loss and how your stats changed. Every hand is recorded.'**
  String get kbSessionStatsDescription;

  /// No description provided for @qrJoinTableInfo.
  ///
  /// In en, this message translates to:
  /// **'TABLE INFO'**
  String get qrJoinTableInfo;

  /// No description provided for @qrJoinSeat.
  ///
  /// In en, this message translates to:
  /// **'Seat {number}'**
  String qrJoinSeat(int number);

  /// No description provided for @qrJoinTableFallback.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get qrJoinTableFallback;

  /// No description provided for @qrJoinClubLabel.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get qrJoinClubLabel;

  /// No description provided for @qrJoinTableLabel.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get qrJoinTableLabel;

  /// No description provided for @qrJoinSeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get qrJoinSeatLabel;

  /// No description provided for @qrJoinStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get qrJoinStatusLabel;

  /// No description provided for @qrJoinActiveGame.
  ///
  /// In en, this message translates to:
  /// **'Active Game'**
  String get qrJoinActiveGame;

  /// No description provided for @qrJoinWaitingStatus.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get qrJoinWaitingStatus;

  /// No description provided for @dealerQrTablesAssigned.
  ///
  /// In en, this message translates to:
  /// **'{count} table(s) assigned to this event'**
  String dealerQrTablesAssigned(int count);

  /// No description provided for @dealerQrTableNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'{tableName} is not assigned to this event.'**
  String dealerQrTableNotAssigned(String tableName);

  /// No description provided for @dealerTablePlayerAdded.
  ///
  /// In en, this message translates to:
  /// **'{playerName} added to Seat {seatNumber}'**
  String dealerTablePlayerAdded(String playerName, int seatNumber);

  /// No description provided for @memberTableSeatedOpen.
  ///
  /// In en, this message translates to:
  /// **'{seated} seated  •  {open} open'**
  String memberTableSeatedOpen(int seated, int open);

  /// No description provided for @memberTablePlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get memberTablePlayer;

  /// No description provided for @memberTableEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get memberTableEmpty;

  /// No description provided for @memberTableFallback.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get memberTableFallback;

  /// No description provided for @homeEventTypeTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament'**
  String get homeEventTypeTournament;

  /// No description provided for @homeEventTypeCashGame.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get homeEventTypeCashGame;

  /// No description provided for @homeEventTypeHomeGame.
  ///
  /// In en, this message translates to:
  /// **'Home Game'**
  String get homeEventTypeHomeGame;

  /// No description provided for @homeEventTypeOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get homeEventTypeOnline;

  /// No description provided for @bankrollSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Result'**
  String get bankrollSheetTitle;

  /// No description provided for @bankrollSheetEditSection.
  ///
  /// In en, this message translates to:
  /// **'Edit Bankroll'**
  String get bankrollSheetEditSection;

  /// No description provided for @bankrollSheetGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Bankroll Goal'**
  String get bankrollSheetGoalLabel;

  /// No description provided for @bankrollSheetCurrentLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Bankroll'**
  String get bankrollSheetCurrentLabel;

  /// No description provided for @bankrollSheetGoalUpdated.
  ///
  /// In en, this message translates to:
  /// **'Goal updated'**
  String get bankrollSheetGoalUpdated;

  /// No description provided for @bankrollSheetBankrollUpdated.
  ///
  /// In en, this message translates to:
  /// **'Bankroll updated'**
  String get bankrollSheetBankrollUpdated;

  /// No description provided for @sessionEndResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Result'**
  String get sessionEndResultTitle;

  /// No description provided for @sessionEndTournamentTitle.
  ///
  /// In en, this message translates to:
  /// **'Tournament Result'**
  String get sessionEndTournamentTitle;

  /// No description provided for @sessionEndProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get sessionEndProfit;

  /// No description provided for @sessionEndLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get sessionEndLoss;

  /// No description provided for @sessionEndApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get sessionEndApply;

  /// No description provided for @sessionEndSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get sessionEndSkip;

  /// No description provided for @sessionEndFinishingPosition.
  ///
  /// In en, this message translates to:
  /// **'Finishing Position'**
  String get sessionEndFinishingPosition;

  /// No description provided for @sessionEndFieldSize.
  ///
  /// In en, this message translates to:
  /// **'Total Entries'**
  String get sessionEndFieldSize;

  /// No description provided for @sessionEndPrizeWon.
  ///
  /// In en, this message translates to:
  /// **'Prize Won'**
  String get sessionEndPrizeWon;

  /// No description provided for @sessionEndTotalInvested.
  ///
  /// In en, this message translates to:
  /// **'Total Invested'**
  String get sessionEndTotalInvested;

  /// No description provided for @sessionEndCalculatedProfit.
  ///
  /// In en, this message translates to:
  /// **'Calculated Profit: {amount}'**
  String sessionEndCalculatedProfit(String amount);

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal poker companion for logging hands, tracking stats, and improving your game.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingNicknameTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s start by choosing your nickname'**
  String get onboardingNicknameTitle;

  /// No description provided for @onboardingNicknameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can switch between your name and nickname and change it whenever you want.'**
  String get onboardingNicknameSubtitle;

  /// No description provided for @onboardingCurrencyTitle.
  ///
  /// In en, this message translates to:
  /// **'What currency do you play in?'**
  String get onboardingCurrencyTitle;

  /// No description provided for @onboardingCurrencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Buy-ins, cashouts, and stats will all use it. You can change it anytime in Settings.'**
  String get onboardingCurrencySubtitle;

  /// No description provided for @onboardingGameTypeTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your game type'**
  String get onboardingGameTypeTitle;

  /// No description provided for @onboardingGameTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tailor your experience based on what you play. Let us know, are you mainly a cash or MTT player?'**
  String get onboardingGameTypeSubtitle;

  /// No description provided for @onboardingGameTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash Game'**
  String get onboardingGameTypeCash;

  /// No description provided for @onboardingGameTypeTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament (MTT)'**
  String get onboardingGameTypeTournament;

  /// No description provided for @onboardingJourneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Where are you in your poker journey?'**
  String get onboardingJourneyTitle;

  /// No description provided for @onboardingJourneySubtitle.
  ///
  /// In en, this message translates to:
  /// **'This helps us personalize your experience.'**
  String get onboardingJourneySubtitle;

  /// No description provided for @onboardingJourneyBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get onboardingJourneyBeginner;

  /// No description provided for @onboardingJourneyFun.
  ///
  /// In en, this message translates to:
  /// **'Playing for fun'**
  String get onboardingJourneyFun;

  /// No description provided for @onboardingJourneyRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular player'**
  String get onboardingJourneyRegular;

  /// No description provided for @onboardingJourneyPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get onboardingJourneyPro;

  /// No description provided for @onboardingMonthlySessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'How many sessions are you approximately playing a month?'**
  String get onboardingMonthlySessionsTitle;

  /// No description provided for @onboardingMonthlySessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drag the wheel to select your monthly sessions.'**
  String get onboardingMonthlySessionsSubtitle;

  /// No description provided for @onboardingMonthlySessionsUnit.
  ///
  /// In en, this message translates to:
  /// **'sessions / month'**
  String get onboardingMonthlySessionsUnit;

  /// No description provided for @onboardingPurposeTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your main purpose of using Final Table?'**
  String get onboardingPurposeTitle;

  /// No description provided for @onboardingPurposeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply.'**
  String get onboardingPurposeSubtitle;

  /// No description provided for @onboardingPurposeLogging.
  ///
  /// In en, this message translates to:
  /// **'Logging hands'**
  String get onboardingPurposeLogging;

  /// No description provided for @onboardingPurposeBankroll.
  ///
  /// In en, this message translates to:
  /// **'Tracking bankroll'**
  String get onboardingPurposeBankroll;

  /// No description provided for @onboardingPurposeOpponents.
  ///
  /// In en, this message translates to:
  /// **'Analysing opponents'**
  String get onboardingPurposeOpponents;

  /// No description provided for @onboardingPurposeActions.
  ///
  /// In en, this message translates to:
  /// **'Logging every action for later analysis'**
  String get onboardingPurposeActions;

  /// No description provided for @onboardingPurposeStudying.
  ///
  /// In en, this message translates to:
  /// **'Studying spots'**
  String get onboardingPurposeStudying;

  /// No description provided for @onboardingPurposeSharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing hand histories with friends'**
  String get onboardingPurposeSharing;

  /// No description provided for @onboardingPurposeAi.
  ///
  /// In en, this message translates to:
  /// **'Analyzing with AI'**
  String get onboardingPurposeAi;

  /// No description provided for @onboardingPurposeExport.
  ///
  /// In en, this message translates to:
  /// **'Exporting hands to GTO tools'**
  String get onboardingPurposeExport;

  /// No description provided for @onboardingPurposeStacks.
  ///
  /// In en, this message translates to:
  /// **'Tracking stack sizes in tournaments'**
  String get onboardingPurposeStacks;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingSkipNickname.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkipNickname;

  /// No description provided for @drillTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Drills'**
  String get drillTitle;

  /// No description provided for @drillSaveLineup.
  ///
  /// In en, this message translates to:
  /// **'Save lineup'**
  String get drillSaveLineup;

  /// No description provided for @drillSaveLineupHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tuesday home game'**
  String get drillSaveLineupHint;

  /// No description provided for @drillDeleteLineup.
  ///
  /// In en, this message translates to:
  /// **'Delete lineup'**
  String get drillDeleteLineup;

  /// No description provided for @drillDeleteLineupMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from your saved lineups?'**
  String drillDeleteLineupMessage(String name);

  /// No description provided for @drillSavedLineups.
  ///
  /// In en, this message translates to:
  /// **'SAVED LINEUPS'**
  String get drillSavedLineups;

  /// No description provided for @drillTable.
  ///
  /// In en, this message translates to:
  /// **'TABLE'**
  String get drillTable;

  /// No description provided for @drillSeats.
  ///
  /// In en, this message translates to:
  /// **'SEATS'**
  String get drillSeats;

  /// No description provided for @drillSeatsInstruction.
  ///
  /// In en, this message translates to:
  /// **'Tap a seat to assign an opponent or move yourself.'**
  String get drillSeatsInstruction;

  /// No description provided for @drillSaveThisLineup.
  ///
  /// In en, this message translates to:
  /// **'Save this lineup'**
  String get drillSaveThisLineup;

  /// No description provided for @drillStartDrill.
  ///
  /// In en, this message translates to:
  /// **'Start Drill'**
  String get drillStartDrill;

  /// No description provided for @drillPlayers.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get drillPlayers;

  /// No description provided for @drillStackDepth.
  ///
  /// In en, this message translates to:
  /// **'Stack depth'**
  String get drillStackDepth;

  /// No description provided for @drillFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get drillFormat;

  /// No description provided for @drillFormatCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get drillFormatCash;

  /// No description provided for @drillFormatAnte.
  ///
  /// In en, this message translates to:
  /// **'MTT · Ante'**
  String get drillFormatAnte;

  /// No description provided for @drillScouting.
  ///
  /// In en, this message translates to:
  /// **'SCOUTING'**
  String get drillScouting;

  /// No description provided for @drillYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get drillYou;

  /// No description provided for @drillSeatNumber.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}'**
  String drillSeatNumber(int seat);

  /// No description provided for @drillPremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Train against your real opponents'**
  String get drillPremiumTitle;

  /// No description provided for @drillPremiumDescription.
  ///
  /// In en, this message translates to:
  /// **'Seat the players you actually face, drill preflop spots against bots that play with their measured tendencies, and get exploit-based feedback on every decision.'**
  String get drillPremiumDescription;

  /// No description provided for @drillUpgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get drillUpgradeToPremium;

  /// No description provided for @drillSearchOpponents.
  ///
  /// In en, this message translates to:
  /// **'Search opponents'**
  String get drillSearchOpponents;

  /// No description provided for @drillThisIsMe.
  ///
  /// In en, this message translates to:
  /// **'This is me'**
  String get drillThisIsMe;

  /// No description provided for @drillMoveYourSeatHere.
  ///
  /// In en, this message translates to:
  /// **'Move your seat here'**
  String get drillMoveYourSeatHere;

  /// No description provided for @drillGenericBot.
  ///
  /// In en, this message translates to:
  /// **'Generic bot'**
  String get drillGenericBot;

  /// No description provided for @drillBalancedRegular.
  ///
  /// In en, this message translates to:
  /// **'Balanced regular'**
  String get drillBalancedRegular;

  /// No description provided for @drillHandNumber.
  ///
  /// In en, this message translates to:
  /// **'Hand #{number}'**
  String drillHandNumber(int number);

  /// No description provided for @drillHandedLabel.
  ///
  /// In en, this message translates to:
  /// **'{stack}BB · {players}-handed'**
  String drillHandedLabel(int stack, int players);

  /// No description provided for @drillPot.
  ///
  /// In en, this message translates to:
  /// **'POT'**
  String get drillPot;

  /// No description provided for @drillWalkedNote.
  ///
  /// In en, this message translates to:
  /// **'Everyone folded — you win the blinds.'**
  String get drillWalkedNote;

  /// No description provided for @drillWonUncontestedNote.
  ///
  /// In en, this message translates to:
  /// **'Everyone folded — you take it down ({pot}BB).'**
  String drillWonUncontestedNote(String pot);

  /// No description provided for @drillReachedFlopNote.
  ///
  /// In en, this message translates to:
  /// **'Hand goes to the flop — preflop drill complete.'**
  String get drillReachedFlopNote;

  /// No description provided for @drillHandOverNote.
  ///
  /// In en, this message translates to:
  /// **'Hand over.'**
  String get drillHandOverNote;

  /// No description provided for @drillCorrect.
  ///
  /// In en, this message translates to:
  /// **'CORRECT'**
  String get drillCorrect;

  /// No description provided for @drillClose.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get drillClose;

  /// No description provided for @drillMistake.
  ///
  /// In en, this message translates to:
  /// **'MISTAKE'**
  String get drillMistake;

  /// No description provided for @drillYouChose.
  ///
  /// In en, this message translates to:
  /// **'· you chose {action}'**
  String drillYouChose(String action);

  /// No description provided for @drillTopPercent.
  ///
  /// In en, this message translates to:
  /// **'top {percent}%'**
  String drillTopPercent(int percent);

  /// No description provided for @drillLineupChanges.
  ///
  /// In en, this message translates to:
  /// **'This lineup changes the play: GTO {gto}s, exploit {exploit}s'**
  String drillLineupChanges(String gto, String exploit);

  /// No description provided for @drillGto.
  ///
  /// In en, this message translates to:
  /// **'GTO'**
  String get drillGto;

  /// No description provided for @drillExploit.
  ///
  /// In en, this message translates to:
  /// **'EXPLOIT'**
  String get drillExploit;

  /// No description provided for @drillContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get drillContinue;

  /// No description provided for @drillGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get drillGotIt;

  /// No description provided for @drillRaiseTo.
  ///
  /// In en, this message translates to:
  /// **'Raise to:'**
  String get drillRaiseTo;

  /// No description provided for @drillJam.
  ///
  /// In en, this message translates to:
  /// **'JAM'**
  String get drillJam;

  /// No description provided for @drillPotLabel.
  ///
  /// In en, this message translates to:
  /// **'Pot {pot}BB'**
  String drillPotLabel(String pot);

  /// No description provided for @drillToCall.
  ///
  /// In en, this message translates to:
  /// **'{amount}BB to call'**
  String drillToCall(String amount);

  /// No description provided for @drillFold.
  ///
  /// In en, this message translates to:
  /// **'FOLD'**
  String get drillFold;

  /// No description provided for @drillCheck.
  ///
  /// In en, this message translates to:
  /// **'CHECK'**
  String get drillCheck;

  /// No description provided for @drillCall.
  ///
  /// In en, this message translates to:
  /// **'CALL'**
  String get drillCall;

  /// No description provided for @drillRaise.
  ///
  /// In en, this message translates to:
  /// **'RAISE'**
  String get drillRaise;

  /// No description provided for @drillNextHand.
  ///
  /// In en, this message translates to:
  /// **'Next Hand'**
  String get drillNextHand;

  /// No description provided for @drillSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Drill Summary'**
  String get drillSummaryTitle;

  /// No description provided for @drillAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get drillAccuracy;

  /// No description provided for @drillDecisions.
  ///
  /// In en, this message translates to:
  /// **'Decisions'**
  String get drillDecisions;

  /// No description provided for @drillCorrectLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get drillCorrectLabel;

  /// No description provided for @drillCloseLabel.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get drillCloseLabel;

  /// No description provided for @drillMistakes.
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get drillMistakes;

  /// No description provided for @drillWhereYouLeaked.
  ///
  /// In en, this message translates to:
  /// **'WHERE YOU LEAKED'**
  String get drillWhereYouLeaked;

  /// No description provided for @drillMistakeDetail.
  ///
  /// In en, this message translates to:
  /// **'{handClass} · {position} · you chose {heroAction}, {recommendedAction} was right'**
  String drillMistakeDetail(String handClass, String position,
      String heroAction, String recommendedAction);

  /// No description provided for @drillKeepDrilling.
  ///
  /// In en, this message translates to:
  /// **'Keep Drilling'**
  String get drillKeepDrilling;

  /// No description provided for @drillEndDrill.
  ///
  /// In en, this message translates to:
  /// **'End Drill'**
  String get drillEndDrill;

  /// No description provided for @drillActionSb.
  ///
  /// In en, this message translates to:
  /// **'SB 0.5'**
  String get drillActionSb;

  /// No description provided for @drillActionBb.
  ///
  /// In en, this message translates to:
  /// **'BB 1'**
  String get drillActionBb;

  /// No description provided for @drillActionFold.
  ///
  /// In en, this message translates to:
  /// **'FOLD'**
  String get drillActionFold;

  /// No description provided for @drillActionCheck.
  ///
  /// In en, this message translates to:
  /// **'CHECK'**
  String get drillActionCheck;

  /// No description provided for @drillActionLimp.
  ///
  /// In en, this message translates to:
  /// **'LIMP'**
  String get drillActionLimp;

  /// No description provided for @drillActionCall.
  ///
  /// In en, this message translates to:
  /// **'CALL {amount}'**
  String drillActionCall(String amount);

  /// No description provided for @drillActionRaise.
  ///
  /// In en, this message translates to:
  /// **'RAISE {amount}'**
  String drillActionRaise(String amount);

  /// No description provided for @drillAction3bet.
  ///
  /// In en, this message translates to:
  /// **'3-BET {amount}'**
  String drillAction3bet(String amount);

  /// No description provided for @drillAction4bet.
  ///
  /// In en, this message translates to:
  /// **'4-BET {amount}'**
  String drillAction4bet(String amount);

  /// No description provided for @drillActionJam.
  ///
  /// In en, this message translates to:
  /// **'JAM {amount}'**
  String drillActionJam(String amount);

  /// No description provided for @rangeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get rangeCash;

  /// No description provided for @rangeTourney.
  ///
  /// In en, this message translates to:
  /// **'Tourney'**
  String get rangeTourney;

  /// No description provided for @rangeAllStacks.
  ///
  /// In en, this message translates to:
  /// **'All stacks'**
  String get rangeAllStacks;

  /// No description provided for @rangeStackDepth.
  ///
  /// In en, this message translates to:
  /// **'Stack depth'**
  String get rangeStackDepth;

  /// No description provided for @rangeAllPositions.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get rangeAllPositions;

  /// No description provided for @rangeAllSpots.
  ///
  /// In en, this message translates to:
  /// **'All spots'**
  String get rangeAllSpots;

  /// No description provided for @rangeRfi.
  ///
  /// In en, this message translates to:
  /// **'RFI'**
  String get rangeRfi;

  /// No description provided for @rangeVsRaise.
  ///
  /// In en, this message translates to:
  /// **'vs Raise'**
  String get rangeVsRaise;

  /// No description provided for @rangeHandsLogged.
  ///
  /// In en, this message translates to:
  /// **'{count} / 169 hands logged'**
  String rangeHandsLogged(int count);

  /// No description provided for @rangeSyncingHistory.
  ///
  /// In en, this message translates to:
  /// **'Syncing your hand history…'**
  String get rangeSyncingHistory;

  /// No description provided for @rangePreflopHeader.
  ///
  /// In en, this message translates to:
  /// **'PREFLOP RANGE — BUILT FROM YOUR LOGGED HANDS'**
  String get rangePreflopHeader;

  /// No description provided for @rangeEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Your preflop chart builds itself: log hands and enter your hole cards, and each starting hand fills in with how you actually played it before the flop.'**
  String get rangeEmptyHint;

  /// No description provided for @rangeSpotsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} preflop {count, plural, =1{spot} other{spots}}'**
  String rangeSpotsCount(int count);

  /// No description provided for @rangeRfiSuffix.
  ///
  /// In en, this message translates to:
  /// **' · RFI'**
  String get rangeRfiSuffix;

  /// No description provided for @rangeVsRaiseSuffix.
  ///
  /// In en, this message translates to:
  /// **' · vs raise'**
  String get rangeVsRaiseSuffix;

  /// No description provided for @rangeRaised.
  ///
  /// In en, this message translates to:
  /// **'Raised'**
  String get rangeRaised;

  /// No description provided for @rangeRaisedLabel.
  ///
  /// In en, this message translates to:
  /// **'Raised'**
  String get rangeRaisedLabel;

  /// No description provided for @rangeCalled.
  ///
  /// In en, this message translates to:
  /// **'Called'**
  String get rangeCalled;

  /// No description provided for @rangeChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get rangeChecked;

  /// No description provided for @rangeFolded.
  ///
  /// In en, this message translates to:
  /// **'Folded'**
  String get rangeFolded;

  /// No description provided for @rangeCalledLimped.
  ///
  /// In en, this message translates to:
  /// **'Called / limped'**
  String get rangeCalledLimped;

  /// No description provided for @rangeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get rangeToday;

  /// No description provided for @rangeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get rangeYesterday;

  /// No description provided for @rangeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String rangeDaysAgo(int days);

  /// No description provided for @rangeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{weeks}w ago'**
  String rangeWeeksAgo(int weeks);

  /// No description provided for @rangeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{months}mo ago'**
  String rangeMonthsAgo(int months);

  /// No description provided for @rangeYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{years}y ago'**
  String rangeYearsAgo(int years);

  /// No description provided for @rangeWonBB.
  ///
  /// In en, this message translates to:
  /// **'W {bb} BB'**
  String rangeWonBB(int bb);

  /// No description provided for @rangeLostBB.
  ///
  /// In en, this message translates to:
  /// **'– {bb} BB'**
  String rangeLostBB(int bb);

  /// No description provided for @rangeScoutingTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} · Scouting report'**
  String rangeScoutingTitle(String name);

  /// No description provided for @rangeShowdownBias.
  ///
  /// In en, this message translates to:
  /// **'Shown hands skew toward value and called-down hands — they tell you what is in the range and its shape, not the full range.'**
  String get rangeShowdownBias;

  /// No description provided for @rangeNoShowdowns.
  ///
  /// In en, this message translates to:
  /// **'Log a few hands to showdown with this opponent\'s cards entered, and their range will start filling in here.'**
  String get rangeNoShowdowns;

  /// No description provided for @rangePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get rangePremium;

  /// No description provided for @rangeStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get rangeStrong;

  /// No description provided for @rangeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get rangeMedium;

  /// No description provided for @rangeWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get rangeWeak;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile Settings'**
  String get profileSettings;

  /// No description provided for @profileEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get profileEditName;

  /// No description provided for @profileYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileYourName;

  /// No description provided for @profileEditEmail.
  ///
  /// In en, this message translates to:
  /// **'Edit email'**
  String get profileEditEmail;

  /// No description provided for @profileEditEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email changes require account re-authentication. Contact support to change your email.'**
  String get profileEditEmailHint;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profileChangePassword;

  /// No description provided for @profilePasswordMask.
  ///
  /// In en, this message translates to:
  /// **'***********'**
  String get profilePasswordMask;

  /// No description provided for @profileContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get profileContactSupport;

  /// No description provided for @profileShareFeedback.
  ///
  /// In en, this message translates to:
  /// **'Share your feedback'**
  String get profileShareFeedback;

  /// No description provided for @profileEmailUpdates.
  ///
  /// In en, this message translates to:
  /// **'Email updates'**
  String get profileEmailUpdates;

  /// No description provided for @profileFollowUs.
  ///
  /// In en, this message translates to:
  /// **'Follow @finaltable'**
  String get profileFollowUs;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEdit;

  /// No description provided for @profileEditUsername.
  ///
  /// In en, this message translates to:
  /// **'Edit username'**
  String get profileEditUsername;

  /// No description provided for @profileUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get profileUsernameHint;

  /// No description provided for @profileInsteadOfName.
  ///
  /// In en, this message translates to:
  /// **'instead of your name in events and hand logging'**
  String get profileInsteadOfName;

  /// No description provided for @profileUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username already taken'**
  String get profileUsernameTaken;

  /// No description provided for @profileFixUsernameError.
  ///
  /// In en, this message translates to:
  /// **'Fix username error before saving'**
  String get profileFixUsernameError;

  /// No description provided for @profileUsernameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Username no longer available'**
  String get profileUsernameUnavailable;

  /// No description provided for @profileSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get profileSavedSuccessfully;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data. This action cannot be undone.\n\nIf you have an active subscription, please cancel it first in your device settings.'**
  String get profileDeleteAccountMessage;

  /// No description provided for @profileChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profileChangePasswordTitle;

  /// No description provided for @profileChangePasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a password reset link to your email address.'**
  String get profileChangePasswordMessage;

  /// No description provided for @profileResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}'**
  String profileResetEmailSent(String email);

  /// No description provided for @profileResetEmailFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email'**
  String get profileResetEmailFailed;

  /// No description provided for @profileSendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Email'**
  String get profileSendResetEmail;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsClubs.
  ///
  /// In en, this message translates to:
  /// **'Clubs'**
  String get settingsClubs;

  /// No description provided for @settingsBankroll.
  ///
  /// In en, this message translates to:
  /// **'Bankroll'**
  String get settingsBankroll;

  /// No description provided for @settingsRegisterClub.
  ///
  /// In en, this message translates to:
  /// **'Register Club'**
  String get settingsRegisterClub;

  /// No description provided for @settingsChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose Language'**
  String get settingsChooseLanguage;

  /// No description provided for @settingsMoreLanguagesLater.
  ///
  /// In en, this message translates to:
  /// **'More languages will be announced later'**
  String get settingsMoreLanguagesLater;

  /// No description provided for @settingsChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get settingsChoose;

  /// No description provided for @settingsChooseCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose Currency'**
  String get settingsChooseCurrency;

  /// No description provided for @settingsMoreCurrenciesLater.
  ///
  /// In en, this message translates to:
  /// **'More currencies will be announced later'**
  String get settingsMoreCurrenciesLater;

  /// No description provided for @settingsNoClubs.
  ///
  /// In en, this message translates to:
  /// **'No clubs'**
  String get settingsNoClubs;

  /// No description provided for @settingsNoClubsYet.
  ///
  /// In en, this message translates to:
  /// **'No Clubs Yet'**
  String get settingsNoClubsYet;

  /// No description provided for @settingsNoClubsHint.
  ///
  /// In en, this message translates to:
  /// **'Register or join a club to see them here.'**
  String get settingsNoClubsHint;

  /// No description provided for @settingsRegisterAClub.
  ///
  /// In en, this message translates to:
  /// **'Register a Club'**
  String get settingsRegisterAClub;

  /// No description provided for @settingsYourClubs.
  ///
  /// In en, this message translates to:
  /// **'Your Clubs'**
  String get settingsYourClubs;

  /// No description provided for @settingsChooseTour.
  ///
  /// In en, this message translates to:
  /// **'Choose which tour to replay'**
  String get settingsChooseTour;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsPending.
  ///
  /// In en, this message translates to:
  /// **'{count} pending'**
  String settingsPending(int count);

  /// No description provided for @settingsGetPlus.
  ///
  /// In en, this message translates to:
  /// **'Get Final Table Plus'**
  String get settingsGetPlus;

  /// No description provided for @settingsGetPlusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log more hands and AI analysis'**
  String get settingsGetPlusSubtitle;

  /// No description provided for @statsHandsLogged.
  ///
  /// In en, this message translates to:
  /// **'Hands Logged'**
  String get statsHandsLogged;

  /// No description provided for @statsVpip.
  ///
  /// In en, this message translates to:
  /// **'VPIP'**
  String get statsVpip;

  /// No description provided for @statsPfr.
  ///
  /// In en, this message translates to:
  /// **'PFR'**
  String get statsPfr;

  /// No description provided for @stats3Bet.
  ///
  /// In en, this message translates to:
  /// **'3-Bet'**
  String get stats3Bet;

  /// No description provided for @statsCBet.
  ///
  /// In en, this message translates to:
  /// **'C-Bet'**
  String get statsCBet;

  /// No description provided for @statsSteal.
  ///
  /// In en, this message translates to:
  /// **'Steal'**
  String get statsSteal;

  /// No description provided for @statsCheckRaise.
  ///
  /// In en, this message translates to:
  /// **'Check-Raise'**
  String get statsCheckRaise;

  /// No description provided for @statsRanges.
  ///
  /// In en, this message translates to:
  /// **'Ranges'**
  String get statsRanges;

  /// No description provided for @statsStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsStats;

  /// No description provided for @loggingChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get loggingChoose;

  /// No description provided for @loggingTrainingDrills.
  ///
  /// In en, this message translates to:
  /// **'Training Drills'**
  String get loggingTrainingDrills;

  /// No description provided for @loggingTrainingDrillsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Practice preflop spots against your real opponents'**
  String get loggingTrainingDrillsSubtitle;

  /// No description provided for @loggingPro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get loggingPro;

  /// No description provided for @opponentsEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get opponentsEnterName;

  /// No description provided for @opponentsAddNotes.
  ///
  /// In en, this message translates to:
  /// **'Add notes'**
  String get opponentsAddNotes;

  /// No description provided for @opponentsNoNotesAdded.
  ///
  /// In en, this message translates to:
  /// **'No notes added'**
  String get opponentsNoNotesAdded;

  /// No description provided for @opponentsDeleteOpponent.
  ///
  /// In en, this message translates to:
  /// **'Delete opponent'**
  String get opponentsDeleteOpponent;

  /// No description provided for @seatManagePlayers.
  ///
  /// In en, this message translates to:
  /// **'Manage Players'**
  String get seatManagePlayers;

  /// No description provided for @seatUpdatePlayerInfo.
  ///
  /// In en, this message translates to:
  /// **'Update player information'**
  String get seatUpdatePlayerInfo;

  /// No description provided for @seatStartSession.
  ///
  /// In en, this message translates to:
  /// **'Start Session'**
  String get seatStartSession;

  /// No description provided for @seatSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get seatSaveChanges;

  /// No description provided for @seatYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get seatYou;

  /// No description provided for @seatKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get seatKeep;

  /// No description provided for @seatMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get seatMove;

  /// No description provided for @tableManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get tableManageTitle;

  /// No description provided for @tableButtonOnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Button on Empty Seat'**
  String get tableButtonOnEmpty;

  /// No description provided for @handPlayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Player '**
  String get handPlayerLabel;

  /// No description provided for @handBbLabel.
  ///
  /// In en, this message translates to:
  /// **'BB'**
  String get handBbLabel;

  /// No description provided for @handRaiseLabel.
  ///
  /// In en, this message translates to:
  /// **'RAISE'**
  String get handRaiseLabel;

  /// No description provided for @handBetLabel.
  ///
  /// In en, this message translates to:
  /// **'BET'**
  String get handBetLabel;

  /// No description provided for @handFoldLabel.
  ///
  /// In en, this message translates to:
  /// **'FOLD'**
  String get handFoldLabel;

  /// No description provided for @handRaiseAction.
  ///
  /// In en, this message translates to:
  /// **'Raise'**
  String get handRaiseAction;

  /// No description provided for @handBetAction.
  ///
  /// In en, this message translates to:
  /// **'Bet'**
  String get handBetAction;

  /// No description provided for @handOnlyOneRemaining.
  ///
  /// In en, this message translates to:
  /// **'Hand ends: Only one player remaining'**
  String get handOnlyOneRemaining;

  /// No description provided for @handSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get handSessionTitle;

  /// No description provided for @settingsSkipHandScouting.
  ///
  /// In en, this message translates to:
  /// **'Skip Hand Scouting'**
  String get settingsSkipHandScouting;

  /// No description provided for @settingsSkipHandScoutingDesc.
  ///
  /// In en, this message translates to:
  /// **'Track opponent actions when you fold preflop'**
  String get settingsSkipHandScoutingDesc;

  /// No description provided for @skipScoutTitle.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get skipScoutTitle;

  /// No description provided for @skipScoutNoRaise.
  ///
  /// In en, this message translates to:
  /// **'No one raised'**
  String get skipScoutNoRaise;

  /// No description provided for @skipScoutSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipScoutSkip;

  /// No description provided for @paywallNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get paywallNotNow;

  /// No description provided for @paywallFreeTrialBadge14.
  ///
  /// In en, this message translates to:
  /// **'14-Day Free Trial'**
  String get paywallFreeTrialBadge14;

  /// No description provided for @freeTierHandLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand limit reached'**
  String get freeTierHandLimitTitle;

  /// No description provided for @freeTierHandLimitFree.
  ///
  /// In en, this message translates to:
  /// **'Free accounts can log up to {free} hands per session. Upgrade to Pro for {pro} hands, or Elite for unlimited.'**
  String freeTierHandLimitFree(int free, int pro);

  /// No description provided for @freeTierHandLimitPro.
  ///
  /// In en, this message translates to:
  /// **'Pro accounts can log up to {pro} hands per session. Upgrade to Elite for unlimited hand logging.'**
  String freeTierHandLimitPro(int pro);

  /// No description provided for @freeTierOpponentLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Opponent limit reached'**
  String get freeTierOpponentLimitTitle;

  /// No description provided for @freeTierOpponentLimitFree.
  ///
  /// In en, this message translates to:
  /// **'Free accounts can save up to {free} opponent profiles. Upgrade to Pro for {pro}, or Elite for unlimited.'**
  String freeTierOpponentLimitFree(int free, int pro);

  /// No description provided for @freeTierOpponentLimitPro.
  ///
  /// In en, this message translates to:
  /// **'Pro accounts can save up to {pro} opponent profiles. Upgrade to Elite for unlimited opponents.'**
  String freeTierOpponentLimitPro(int pro);

  /// No description provided for @freeTierUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get freeTierUpgrade;

  /// No description provided for @freeTierNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get freeTierNotNow;

  /// No description provided for @quotaMonthlyLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly Limit Reached'**
  String get quotaMonthlyLimitTitle;

  /// No description provided for @quotaAiLimitElite.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {max} AI analyses this month. Your quota resets next month.'**
  String quotaAiLimitElite(int max);

  /// No description provided for @quotaAiLimitPro.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {max} AI analyses this month (Pro limit). Upgrade to Elite for {elite} analyses/month.'**
  String quotaAiLimitPro(int max, int elite);

  /// No description provided for @quotaExportLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Limit Reached'**
  String get quotaExportLimitTitle;

  /// No description provided for @quotaExportLimitPro.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {max} exports this month (Pro limit). Upgrade to Elite for unlimited exports.'**
  String quotaExportLimitPro(int max);

  /// No description provided for @quotaSessionExportLimitPro.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used all {max} session exports this month (Pro limit). Upgrade to Elite for unlimited exports.'**
  String quotaSessionExportLimitPro(int max);

  /// No description provided for @quotaUpgradeToElite.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Elite'**
  String get quotaUpgradeToElite;

  /// No description provided for @quotaOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get quotaOk;

  /// No description provided for @statsLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to unlock'**
  String get statsLockedTitle;

  /// No description provided for @statsLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This section is available on Pro and above.'**
  String get statsLockedSubtitle;

  /// No description provided for @statsLockedUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get statsLockedUpgrade;

  /// No description provided for @paywallBestValue.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get paywallBestValue;

  /// No description provided for @paywallWelcomeElite.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Elite!'**
  String get paywallWelcomeElite;

  /// No description provided for @paywallWelcomeClub.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Club!'**
  String get paywallWelcomeClub;

  /// No description provided for @paywallStartWithPro.
  ///
  /// In en, this message translates to:
  /// **'Start with Pro'**
  String get paywallStartWithPro;

  /// No description provided for @paywallGetEliteAction.
  ///
  /// In en, this message translates to:
  /// **'Get Elite'**
  String get paywallGetEliteAction;

  /// No description provided for @paywallGetClubAction.
  ///
  /// In en, this message translates to:
  /// **'Get Club'**
  String get paywallGetClubAction;

  /// No description provided for @paywallCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get paywallCurrentPlan;

  /// No description provided for @paywallProFeature1.
  ///
  /// In en, this message translates to:
  /// **'50 hands per session'**
  String get paywallProFeature1;

  /// No description provided for @paywallProFeature2.
  ///
  /// In en, this message translates to:
  /// **'90-day session history'**
  String get paywallProFeature2;

  /// No description provided for @paywallProFeature3.
  ///
  /// In en, this message translates to:
  /// **'15 opponent profiles'**
  String get paywallProFeature3;

  /// No description provided for @paywallProFeature4.
  ///
  /// In en, this message translates to:
  /// **'10 AI analyses / month'**
  String get paywallProFeature4;

  /// No description provided for @paywallProFeature5.
  ///
  /// In en, this message translates to:
  /// **'30 exports / month'**
  String get paywallProFeature5;

  /// No description provided for @paywallEliteFeature4.
  ///
  /// In en, this message translates to:
  /// **'Unlimited hand logging'**
  String get paywallEliteFeature4;

  /// No description provided for @paywallEliteFeature5.
  ///
  /// In en, this message translates to:
  /// **'All-time session history'**
  String get paywallEliteFeature5;

  /// No description provided for @paywallEliteFeature6.
  ///
  /// In en, this message translates to:
  /// **'Unlimited opponents'**
  String get paywallEliteFeature6;

  /// No description provided for @paywallEliteFeature7.
  ///
  /// In en, this message translates to:
  /// **'30 AI analyses / month'**
  String get paywallEliteFeature7;

  /// No description provided for @paywallEliteFeature8.
  ///
  /// In en, this message translates to:
  /// **'Unlimited exports'**
  String get paywallEliteFeature8;

  /// No description provided for @paywallClubFeature1.
  ///
  /// In en, this message translates to:
  /// **'Everything in Elite'**
  String get paywallClubFeature1;

  /// No description provided for @paywallClubFeature2.
  ///
  /// In en, this message translates to:
  /// **'Create & run your own club'**
  String get paywallClubFeature2;

  /// No description provided for @paywallClubFeature3.
  ///
  /// In en, this message translates to:
  /// **'Invite dealers & manage members'**
  String get paywallClubFeature3;

  /// No description provided for @paywallClubFeature4.
  ///
  /// In en, this message translates to:
  /// **'Host multi-table events with live rankings'**
  String get paywallClubFeature4;

  /// No description provided for @profileTierOverride.
  ///
  /// In en, this message translates to:
  /// **'Subscription tier override'**
  String get profileTierOverride;

  /// No description provided for @profileTierOverrideSubtitleReal.
  ///
  /// In en, this message translates to:
  /// **'Real: {tier}'**
  String profileTierOverrideSubtitleReal(String tier);

  /// No description provided for @profileTierOverrideSubtitleActive.
  ///
  /// In en, this message translates to:
  /// **'Override: {tier}'**
  String profileTierOverrideSubtitleActive(String tier);

  /// No description provided for @profileTierFree.
  ///
  /// In en, this message translates to:
  /// **'free'**
  String get profileTierFree;

  /// No description provided for @profileTierPro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get profileTierPro;

  /// No description provided for @profileTierElite.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get profileTierElite;

  /// No description provided for @profileTierClub.
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get profileTierClub;

  /// No description provided for @authExpContinueApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authExpContinueApple;

  /// No description provided for @authExpLinkAppleTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Apple Account'**
  String get authExpLinkAppleTitle;

  /// No description provided for @authExpLinkAppleMessage.
  ///
  /// In en, this message translates to:
  /// **'An account with {email} already exists. Enter your password to link your Apple account.'**
  String authExpLinkAppleMessage(String email);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'pl',
        'pt',
        'ru'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
