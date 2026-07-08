// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get navHome => 'Accueil';

  @override
  String get navOpponents => 'Adversaires';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navProfile => 'Profil';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonError => 'Erreur';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonNoData => 'Aucune donnée disponible';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonNotAvailable => 'N/D';

  @override
  String get commonApply => 'Appliquer';

  @override
  String get commonUpdate => 'Mettre à jour';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonToday => 'Aujourd\'hui';

  @override
  String get statsTitle => 'Statistiques';

  @override
  String get statsSubtitle => 'Analyses avancées';

  @override
  String get statsHandsPlayed => 'Mains jouées';

  @override
  String get statsFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get statsWinRate => 'Win Rate';

  @override
  String get statsSessionStatistics => 'Statistiques de session';

  @override
  String get statsSessions => 'Sessions';

  @override
  String get statsTotalTime => 'Temps total';

  @override
  String get statsAvgSession => 'Session moy.';

  @override
  String get statsPlayToSee =>
      'Jouez des sessions pour voir les statistiques de temps';

  @override
  String get statsGeneral => 'Général';

  @override
  String get statsCash => 'Cash';

  @override
  String get statsTournament => 'Tournoi';

  @override
  String get statsTotalBuyIn => 'Buy-In total';

  @override
  String get statsTotalCashOut => 'Cash-Out total';

  @override
  String get statsNetProfit => 'Profit net';

  @override
  String get statsItm => 'ITM%';

  @override
  String get statsAvgFinish => 'Position moy.';

  @override
  String get statsBestFinish => 'Meilleure position';

  @override
  String get statsRoi => 'ROI%';

  @override
  String get statsFinalTables => 'Tables finales';

  @override
  String get statsAvgBuyIn => 'Buy-In moy.';

  @override
  String get statsAvgFieldSize => 'Taille moy. du champ';

  @override
  String get statsHourlyRate => 'Taux horaire';

  @override
  String get statsHourlyRateNotAvailable => 'Disponible après 60 min de suivi';

  @override
  String get statsBBPerHour => 'BB / Heure';

  @override
  String get statsLoadingMessage => 'Chargement des statistiques...';

  @override
  String get statsFetchingMessage => 'Récupération des statistiques...';

  @override
  String statsFailedToLoad(String error) {
    return 'Échec du chargement des statistiques : $error';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSubtitle => 'Choisir la langue de l\'application';

  @override
  String get settingsLanguageSystem => 'Par défaut du système';

  @override
  String get settingsCurrency => 'Devise';

  @override
  String get settingsKnowledgeBase => 'BASE DE CONNAISSANCES';

  @override
  String get settingsGuidedTour => 'Visite guidée';

  @override
  String get settingsGuidedTourSubtitle =>
      'Rejouer les tutoriels d\'introduction';

  @override
  String get settingsFullLoggingTour => 'Visite du logging complet';

  @override
  String get settingsFullLoggingTourSubtitle => 'Suivi complet de session';

  @override
  String get settingsIndividualLoggingTour => 'Visite du logging individuel';

  @override
  String get settingsIndividualLoggingTourSubtitle =>
      'Suivi d\'une main individuelle';

  @override
  String get settingsUnderstandingStats => 'Comprendre vos statistiques';

  @override
  String get settingsUnderstandingStatsSubtitle =>
      'Apprenez ce que chaque métrique signifie';

  @override
  String get settingsClubsEvents => 'Clubs et événements';

  @override
  String get settingsClubsEventsSubtitle => 'Comment fonctionne le jeu en club';

  @override
  String get settingsLegal => 'JURIDIQUE';

  @override
  String get settingsTermsOfService => 'Conditions d\'utilisation';

  @override
  String get settingsTermsOfServiceSubtitle =>
      'Voir nos conditions d\'utilisation';

  @override
  String get settingsPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsPrivacyPolicySubtitle =>
      'Voir notre politique de confidentialité';

  @override
  String get settingsAdmin => 'ADMIN';

  @override
  String get settingsClubRequests => 'Demandes de club';

  @override
  String get settingsClubRequestsSubtitle =>
      'Gérer les demandes d\'inscription';

  @override
  String get settingsSupportRequests => 'Demandes de support';

  @override
  String get settingsSupportRequestsSubtitle =>
      'Gérer les tickets de support utilisateur';

  @override
  String get settingsNotificationTester => 'Test de notifications';

  @override
  String get settingsNotificationTesterSubtitle =>
      'Prévisualiser tous les designs de notifications';

  @override
  String get profileUpgrade => 'Passer au supérieur';

  @override
  String get profileUsername => 'Nom d\'utilisateur';

  @override
  String get profileNotSet => 'Non défini';

  @override
  String get profileChange => 'Modifier';

  @override
  String get profileSetUsername => 'Définir le nom d\'utilisateur';

  @override
  String get profileUseNicknameInGames => 'Utiliser le pseudo en jeu';

  @override
  String profileUseNicknameDescription(String username) {
    return 'Afficher @$username au lieu de votre nom dans les événements et le logging des mains';
  }

  @override
  String get profileBankrollGoal => 'Objectif de Bankroll';

  @override
  String get profileUpdateGoal => 'Mettre à jour l\'objectif';

  @override
  String get profileCurrentBankroll => 'Bankroll actuelle';

  @override
  String get profileUpdateBankroll => 'Mettre à jour la Bankroll';

  @override
  String get profileAddSessionResult => 'Ajouter un résultat de session';

  @override
  String get profileSessionResultHint =>
      'Entrez un montant positif pour les gains, négatif pour les pertes';

  @override
  String get profileAddResult => 'Ajouter le résultat';

  @override
  String get profileGoalUpdatedSuccess => 'Objectif mis à jour avec succès !';

  @override
  String get profileErrorUpdatingGoal =>
      'Erreur lors de la mise à jour de l\'objectif';

  @override
  String get profileBankrollUpdatedSuccess =>
      'Bankroll mise à jour avec succès !';

  @override
  String get profileErrorUpdatingBankroll =>
      'Erreur lors de la mise à jour de la bankroll';

  @override
  String get profileSessionResultAdded => 'Résultat de session ajouté !';

  @override
  String get profileErrorAddingResult =>
      'Erreur lors de l\'ajout du résultat de session';

  @override
  String get profilePleaseEnterValidAmount =>
      'Veuillez entrer un montant valide';

  @override
  String get profileLogOut => 'Déconnexion';

  @override
  String get profileSignOut => 'Se déconnecter';

  @override
  String get profileSignOutConfirmation =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get sessionHistoryTitle => 'Historique des sessions';

  @override
  String get sessionLast30Days => '30 derniers jours';

  @override
  String get sessionUpgradeForFullHistory =>
      'Passez au supérieur pour l\'historique complet';

  @override
  String get sessionLoadingMessage => 'Chargement des sessions...';

  @override
  String sessionNoSessions(String gameType) {
    return 'Aucune session $gameType';
  }

  @override
  String sessionPlayToSee(String gameType) {
    return 'Jouez quelques mains de $gameType Poker\npour voir les résultats';
  }

  @override
  String get sessionLive => 'En direct';

  @override
  String sessionPlayersCount(int count) {
    return '$count joueurs';
  }

  @override
  String get sessionSyncingToCloud => 'Synchronisation vers le cloud...';

  @override
  String get sessionClearAllTitle => 'Effacer toutes les sessions ?';

  @override
  String get sessionClearAllDescription =>
      'Cela supprimera définitivement toutes les sessions et mains de poker de Firebase et du stockage local.';

  @override
  String get sessionClearAllWarning => 'Cette action est irréversible !';

  @override
  String get sessionClearAll => 'Tout effacer';

  @override
  String get sessionClearedSuccessfully =>
      'Toutes les sessions ont été effacées avec succès';

  @override
  String sessionHandDetails(int handNumber) {
    return 'Détails de la main #$handNumber';
  }

  @override
  String get sessionYourCards => 'Vos cartes :';

  @override
  String get sessionBoardCards => 'Cartes du board :';

  @override
  String get sessionPotByStreet => 'Pot par street :';

  @override
  String get sessionActions => 'Actions :';

  @override
  String get sessionNoActionsRecorded => 'Aucune action enregistrée';

  @override
  String get sessionNoCardsRecorded => 'Aucune carte enregistrée';

  @override
  String get sessionFinalPot => 'Pot final :';

  @override
  String sessionChoppedPot(int count) {
    return 'Pot partagé ($count gagnants) :';
  }

  @override
  String get sessionWinnerNotAvailable =>
      'Information du gagnant non disponible';

  @override
  String get opponentsTitle => 'Adversaires';

  @override
  String opponentsCountFree(int count, int max) {
    return '$count/$max gratuits';
  }

  @override
  String opponentsCountPremium(int count) {
    return '$count joueurs suivis';
  }

  @override
  String get opponentsSearchHint => 'Rechercher des adversaires...';

  @override
  String get opponentsLoadingMessage => 'Chargement des adversaires...';

  @override
  String get opponentsNoResults => 'Aucun résultat';

  @override
  String get opponentsEmptyTitle => 'Aucun adversaire';

  @override
  String get opponentsEmptySubtitle =>
      'Ajoutez des adversaires pour suivre leurs styles de jeu et statistiques';

  @override
  String get opponentsEmptySearchSubtitle =>
      'Essayez un autre terme de recherche';

  @override
  String get opponentsAddButton => 'Ajouter un adversaire';

  @override
  String opponentsLastSeen(String date) {
    return 'Vu le : $date';
  }

  @override
  String get opponentsHands => 'Mains';

  @override
  String get opponentsEditMenu => 'Modifier l\'adversaire';

  @override
  String get opponentsDeleteMenu => 'Supprimer l\'adversaire';

  @override
  String get opponentsAddDialogTitle => 'Ajouter un adversaire';

  @override
  String get opponentsEditDialogTitle => 'Modifier l\'adversaire';

  @override
  String get opponentsNameHint => 'Nom de l\'adversaire';

  @override
  String get opponentsNotesHint => 'Notes (facultatif)';

  @override
  String get opponentsPickColor => 'Choisir une couleur';

  @override
  String get opponentsAddedSuccess => 'Adversaire ajouté avec succès';

  @override
  String opponentAlreadyExists(String name) {
    return 'Un adversaire nommé \"$name\" existe déjà';
  }

  @override
  String get opponentsUpdatedSuccess => 'Adversaire mis à jour avec succès';

  @override
  String get opponentsDeleteConfirmTitle => 'Supprimer l\'adversaire ?';

  @override
  String opponentsDeleteConfirmMessage(String name) {
    return 'Êtes-vous sûr de vouloir supprimer \"$name\" ?\nCette action est irréversible';
  }

  @override
  String get opponentsDeletedSuccess => 'Adversaire supprimé avec succès';

  @override
  String get opponentsAnalyticsTitle => 'Analyse des adversaires';

  @override
  String get opponentsAnalyticsTotalLabel => 'Total des adversaires';

  @override
  String get opponentsAnalyticsHandsTracked => 'Total des mains suivies';

  @override
  String get opponentsAnalyticsAverage => 'Moyenne de mains/adversaire';

  @override
  String get opponentsAnalyticsMostPlayed => 'Le plus joué contre';

  @override
  String get opponentsAnalyticsDistribution =>
      'Répartition par type de joueur :';

  @override
  String get opponentsClearAllTitle => 'Effacer tous les adversaires ?';

  @override
  String get opponentsClearAllMessage =>
      'Cela supprimera définitivement toutes les données des adversaires. Cette action est irréversible !';

  @override
  String get opponentsClearAllButton => 'Tout effacer';

  @override
  String get opponentsClearedSuccess => 'Tous les adversaires ont été effacés';

  @override
  String get setupSessionSetup => 'Configuration de session';

  @override
  String get setupSessionName => 'Nom de la session';

  @override
  String get setupSessionNameHint => 'ex. « Poker du vendredi soir »';

  @override
  String get setupGameType => 'Type de jeu';

  @override
  String get setupCashGame => 'Cash Game';

  @override
  String get setupTournament => 'Tournament';

  @override
  String get setupSmallBlind => 'Small Blind';

  @override
  String get setupBigBlind => 'Big Blind';

  @override
  String get setupBuyInAmount => 'Montant du Buy-in';

  @override
  String get setupEnterAmount => 'Entrer le montant';

  @override
  String get setupStartingStackEqualsBuyIn =>
      'Le stack de départ est égal à votre buy-in.';

  @override
  String get setupStartingStack => 'Stack de départ';

  @override
  String get setupEnterChipStack => 'Entrer le stack de jetons';

  @override
  String setupMustBeAtLeastBigBlind(int bigBlind) {
    return 'Doit être au moins égal au Big Blind ($bigBlind)';
  }

  @override
  String get setupBbAnte => 'BB Ante';

  @override
  String get setupTableSection => 'TABLE';

  @override
  String get setupTableInstructions =>
      'Appuyez sur un siège pour ajouter un joueur. Faites glisser le bouton pour définir le Dealer.';

  @override
  String get setupStartSession => 'Commencer la session';

  @override
  String get setupMe => 'Moi';

  @override
  String setupPlayerSeat(int seatNumber) {
    return 'Joueur $seatNumber';
  }

  @override
  String get setupHero => 'Hero';

  @override
  String get homeLoadingPokerData => 'Chargement de vos données poker...';

  @override
  String get homeWelcomeBack => 'Bon retour';

  @override
  String get homeNoActiveSessions => 'Aucune session active';

  @override
  String get homeLiveSessions => 'Sessions en direct';

  @override
  String get homeClubNotFound => 'Club introuvable';

  @override
  String get homeEventNotFound => 'Événement introuvable';

  @override
  String get homeRecentActivity => 'Activité récente';

  @override
  String get homeWinRate => 'Win Rate';

  @override
  String get homeHours => 'Heures';

  @override
  String get homePlayStyle => 'Style de jeu';

  @override
  String get homePlayStyleTooltip =>
      'Votre style de jeu sera détecté après avoir enregistré 50 mains preflop.';

  @override
  String get homeBankroll => 'Bankroll';

  @override
  String homeBankrollOfGoal(String current, String goal) {
    return '$current sur $goal';
  }

  @override
  String homeAmountLeft(String amount) {
    return '$amount restant';
  }

  @override
  String get homeEarnings => 'Gains';

  @override
  String homeAvgAmount(String amount) {
    return 'Moy. $amount';
  }

  @override
  String get homeNoEarningsDataYet => 'Aucune donnée de gains';

  @override
  String get homeRecentSessions => 'Sessions récentes';

  @override
  String get homeViewAll => 'Tout voir';

  @override
  String get homeNoRecentSessions => 'Aucune session récente';

  @override
  String get homeStartFirstSession =>
      'Commencez votre première session de poker !';

  @override
  String get homeAddNew => 'Ajouter';

  @override
  String get homeUpcomingEvents => 'Événements à venir';

  @override
  String get homeNoRecentEvents => 'Aucun événement récent';

  @override
  String get homeAddFirstEvent => 'Ajoutez votre premier événement poker !';

  @override
  String homePlayersCount(int count) {
    return '$count joueurs';
  }

  @override
  String homeGoingCount(int count) {
    return '$count participants';
  }

  @override
  String get homePrivateGame => 'Partie privée';

  @override
  String get homeHomeGame => 'Home Game';

  @override
  String get homeOnline => 'En ligne';

  @override
  String get homeEditEvent => 'Modifier l\'événement';

  @override
  String get homeDeleteEvent => 'Supprimer l\'événement';

  @override
  String get homeEventName => 'Nom de l\'événement';

  @override
  String get homeLocationVenue => 'Lieu / Salle';

  @override
  String get homeBuyInAmount => 'Montant du Buy-in';

  @override
  String get homeSelectDate => 'Sélectionner la date :';

  @override
  String get homeSaveChanges => 'Enregistrer les modifications';

  @override
  String homeDeleteEventConfirm(String eventName) {
    return 'Supprimer $eventName ?';
  }

  @override
  String homeDeleteEventDescription(String eventName) {
    return 'Êtes-vous sûr de vouloir supprimer \"$eventName\" ?';
  }

  @override
  String get homeEventDeletedSuccessfully => 'Événement supprimé avec succès';

  @override
  String get homeClubInvitation => 'Invitation au club';

  @override
  String get homeYouveBeenInvitedToJoin => 'Vous avez été invité à rejoindre';

  @override
  String get homeDecline => 'Refuser';

  @override
  String get homeAccept => 'Accepter';

  @override
  String get homeInvitationDeclined => 'Invitation refusée';

  @override
  String get homeInvitationAccepted => 'Invitation acceptée';

  @override
  String get homeClubInvitations => 'Invitations de club';

  @override
  String get homeLater => 'Plus tard';

  @override
  String get homeViewInvitations => 'Voir les invitations';

  @override
  String get homeNoEarningsDataTitle => 'Aucune donnée de gains';

  @override
  String get homeNoEarningsDataDescription =>
      'Ajoutez d\'abord des résultats de session pour voir votre graphique de gains. Vous pouvez ajouter des résultats depuis la page Profil.';

  @override
  String handHandNumber(int number) {
    return 'Main #$number';
  }

  @override
  String handFreeCounter(int used, int max) {
    return '$used/$max gratuites';
  }

  @override
  String handAvgPill(String ratio) {
    return '$ratio moy.';
  }

  @override
  String get errorNoConnection => 'Pas de connexion internet. Vérifiez votre réseau et réessayez.';

  @override
  String get errorTimeout => 'La demande a expiré. Veuillez réessayer.';

  @override
  String get errorServer => 'Un problème est survenu de notre côté. Réessayez dans quelques minutes.';

  @override
  String get errorNotAuthorized => 'Vous n\'avez pas l\'autorisation de faire cela. Reconnectez-vous.';

  @override
  String get errorGeneric => 'Un problème est survenu. Veuillez réessayer.';

  @override
  String get handNextHand => 'Main suivante';

  @override
  String get handFoldedToMe => 'Folded to me';

  @override
  String get handUndoLastAction => 'Annuler la dernière action';

  @override
  String get handAllInHand => 'MAIN ALL-IN';

  @override
  String get handPot => 'Pot';

  @override
  String get handStack => 'Stack';

  @override
  String get handToAct => 'À jouer';

  @override
  String get handToActYou => 'Vous';

  @override
  String get handStopSessionTitle => 'Arrêter la session ?';

  @override
  String get handStopSessionMessage =>
      'Êtes-vous sûr de vouloir arrêter cette session ? Toutes les mains seront sauvegardées.';

  @override
  String get handStop => 'Arrêter';

  @override
  String get handChangeTable => 'Changer de table';

  @override
  String get handBlinds => 'Blinds';

  @override
  String get handTakesEffectNextHand => 'Prend effet à la main suivante';

  @override
  String get handLeaveSession => 'Quitter la session ?';

  @override
  String get handSaveAndExit => 'Sauvegarder et quitter';

  @override
  String get handDiscardAndExit => 'Ignorer et quitter';

  @override
  String get handInProgress => 'Hand in Progress';

  @override
  String get handDiscardCurrentHand =>
      'You have an active hand being logged. Discard it and go back?';

  @override
  String get handDiscardHand => 'Discard Hand';

  @override
  String get handAdjustStack => 'Ajuster le Stack';

  @override
  String get handEnterStackAmount => 'Entrer le montant du stack';

  @override
  String get handGestureGuide => 'Guide des gestes';

  @override
  String get handManagePlayers => 'Gérer les joueurs';

  @override
  String get handStopSession => 'Arrêter la session';

  @override
  String get handRebuy => 'Rebuy';

  @override
  String get handGestures => 'Gestes';

  @override
  String get handGestureTap => 'Appuyer';

  @override
  String get handGestureCheckCall => 'Check / Call';

  @override
  String get handGestureSwipeOut => 'Glisser vers l\'extérieur';

  @override
  String get handGestureSwipeUp =>
      'Appuyez & glissez';

  @override
  String get handGestureBetRaise => 'Bet / Raise';

  @override
  String get handStreetComplete => 'Street terminée';

  @override
  String get handWinsThePot => 'remporte le pot';

  @override
  String get handHandComplete => 'Main terminée';

  @override
  String get handTapToContinue => 'Appuyez pour continuer';

  @override
  String get handRaiseAmount => 'Montant du Raise';

  @override
  String get handBetAmount => 'Montant du Bet';

  @override
  String get handPleaseEnterValidNumber => 'Veuillez entrer un nombre valide';

  @override
  String get handConfirmRebuy => 'Confirmer le Rebuy';

  @override
  String get handRebuyReplaceStack =>
      'Un rebuy remplacera votre stack actuel. Êtes-vous sûr de vouloir continuer ?';

  @override
  String get handProceed => 'Continuer';

  @override
  String get handEnterRebuyDetails =>
      'Entrez les détails du rebuy pour le tournament';

  @override
  String get handRebuyAmount => 'Montant du Rebuy';

  @override
  String get handNewStackSize => 'Nouveau Stack';

  @override
  String get handChipCountAfterRebuy => 'Nombre de jetons après le rebuy';

  @override
  String get handSessionInfo => 'Info session';

  @override
  String handTotalInvested(String amount) {
    return 'Total investi : $amount';
  }

  @override
  String handRebuysCount(int count) {
    return 'Rebuys : $count';
  }

  @override
  String get handAddRebuy => 'Ajouter un Rebuy';

  @override
  String get handPleaseEnterValidAmounts =>
      'Veuillez entrer des montants valides';

  @override
  String get handHandInProgress => 'Main en cours';

  @override
  String get handHandInProgressMessage =>
      'Une main est en cours. Passer à la main suivante annulera toutes les actions et restaurera les stacks des joueurs.';

  @override
  String get handMoveToNextHand => 'Passer à la main suivante';

  @override
  String get handMainPot => 'Pot principal';

  @override
  String handSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String get handPokerSession => 'Session de poker';

  @override
  String handActionsHandNumber(String number) {
    return 'Main #$number';
  }

  @override
  String handActionsPosition(String position) {
    return 'Position : $position';
  }

  @override
  String get handActionsShareHand => 'Partager la main';

  @override
  String get handActionsShowHoleCards => 'Afficher les Hole Cards';

  @override
  String get handActionsShowHoleCardsSubtitle =>
      'Vos cartes seront visibles dans le lien partagé';

  @override
  String get handActionsHideHoleCards => 'Masquer les Hole Cards';

  @override
  String get handActionsHideHoleCardsSubtitle =>
      'Vos cartes seront cachées du lien partagé';

  @override
  String get handActionsShareMessage => 'Regardez cette main sur Final Table !';

  @override
  String handActionsShareSubject(String number) {
    return 'Main de poker #$number';
  }

  @override
  String get handActionsFailedToShareHand => 'Échec du partage de la main';

  @override
  String get handActionsGeneratingExport =>
      'Génération de l\'export PokerStars...';

  @override
  String handActionsExportedSuccessfully(String number) {
    return 'Main #$number exportée avec succès !';
  }

  @override
  String handActionsFailedToExport(String error) {
    return 'Échec de l\'export de la main : $error';
  }

  @override
  String get handActionsMissingHeroCards => 'Cartes de Hero manquantes';

  @override
  String get handActionsMissingHeroCardsMessage =>
      'L\'analyse IA nécessite que vos hole cards soient enregistrées. Cette main ne peut pas être analysée car les cartes de hero sont manquantes.';

  @override
  String get handActionsYourCards => 'Vos cartes';

  @override
  String get handActionsOpponentCards => 'Cartes de l\'adversaire';

  @override
  String handActionsPlayerSeat(int id) {
    return 'Joueur $id';
  }

  @override
  String get handActionsPot => 'POT';

  @override
  String get handActionsBlinds => 'BLINDS';

  @override
  String get handActionsWinner => 'GAGNANT';

  @override
  String handActionsPlayersCount(int count) {
    return '$count joueurs';
  }

  @override
  String get handActionsActionSummary => 'Résumé des actions';

  @override
  String get handActionsPreflop => 'PREFLOP';

  @override
  String get handActionsBoard => 'BOARD';

  @override
  String get handActionsPlayer => 'JOUEUR';

  @override
  String get handActionsStack => 'STACK';

  @override
  String get handActionsAction => 'ACTION';

  @override
  String get handActionsAmount => 'MONT.';

  @override
  String get handActionsYou => 'Vous';

  @override
  String get handActionsAllIn => 'ALL IN';

  @override
  String get handActionsNotes => 'Notes';

  @override
  String get handActionsAnalyzingHand => 'Analyse de la main...';

  @override
  String get handActionsHeroCardsMissing => 'Cartes de Hero manquantes';

  @override
  String get handActionsUnlockAiAnalysis => 'Débloquer l\'analyse IA';

  @override
  String get handActionsAnalysisComplete => 'Analyse terminée';

  @override
  String get handActionsAiAnalyzerBeta => 'Analyseur IA (bêta)';

  @override
  String get handActionsAnalysisFailed => 'Échec de l\'analyse';

  @override
  String get handActionsAiAnalysis => 'Analyse IA';

  @override
  String get handActionsStreetByStreetBreakdown => 'Analyse street par street';

  @override
  String handActionsAnalysisCompletedIn(String time) {
    return 'Analyse terminée en ${time}s';
  }

  @override
  String get handActionsFailedToUpdateStar =>
      'Échec de la mise à jour du statut favori';

  @override
  String handActionsPotAmount(String amount) {
    return 'Pot : $amount';
  }

  @override
  String opponentDetailHandsTracked(int count) {
    return '$count mains suivies';
  }

  @override
  String get opponentDetailNoDataYet => 'Pas encore de données';

  @override
  String get opponentDetailHands => 'Mains';

  @override
  String get opponentDetailLastSeen => 'Dernière apparition :';

  @override
  String get opponentDetailNotes => 'Notes';

  @override
  String get opponentDetailEditOpponent => 'Modifier l\'adversaire';

  @override
  String get opponentDetailDeleteOpponent => 'Supprimer l\'adversaire';

  @override
  String get opponentDetailStatistics => 'Statistiques';

  @override
  String get opponentDetailNoStatisticsAvailable =>
      'Aucune statistique disponible';

  @override
  String get opponentDetailStatsDisclaimer =>
      'Les stats sont basées uniquement sur les mains jouées ensemble. Le VPIP n\'est pas suivi car les folds non observés le fausseraient.';

  @override
  String get opponentDetailAggressionFreq => 'Aggression %';

  @override
  String get opponentDetailShowdownPercent => '% Showdown';

  @override
  String get opponentDetailHandHistory => 'Historique des mains';

  @override
  String get opponentDetailViewAllHands =>
      'Voir toutes les mains jouées avec cet adversaire';

  @override
  String get opponentDetailViewHandHistory => 'Voir l\'historique des mains';

  @override
  String get opponentDetailNoHandsFound => 'Aucune main trouvée';

  @override
  String opponentDetailNoHandsMessage(String name) {
    return 'Vous n\'avez pas encore joué de mains avec \"$name\"';
  }

  @override
  String get opponentDetailOpponentName => 'Nom de l\'adversaire';

  @override
  String get opponentDetailNotesOptional => 'Notes (facultatif)';

  @override
  String get opponentDetailPickColor => 'Choisir une couleur';

  @override
  String get opponentDetailColorRed => 'Rouge';

  @override
  String get opponentDetailColorLightBlue => 'Bleu clair';

  @override
  String get opponentDetailColorGreen => 'Vert';

  @override
  String get opponentDetailColorOrange => 'Orange';

  @override
  String get opponentDetailColorPurple => 'Violet';

  @override
  String get opponentDetailColorTeal => 'Sarcelle';

  @override
  String get opponentDetailColorPink => 'Rose';

  @override
  String get opponentDetailColorIndigo => 'Indigo';

  @override
  String get opponentDetailUpdatedSuccessfully =>
      'Adversaire mis à jour avec succès';

  @override
  String get opponentDetailDeleteConfirmTitle => 'Supprimer l\'adversaire ?';

  @override
  String opponentDetailDeleteConfirmMessage(String name) {
    return 'Êtes-vous sûr de vouloir supprimer \"$name\" ?\nCette action est irréversible';
  }

  @override
  String get opponentDetailDeletedSuccessfully =>
      'Adversaire supprimé avec succès';

  @override
  String opponentDetailErrorDeleting(String error) {
    return 'Erreur lors de la suppression de l\'adversaire : $error';
  }

  @override
  String get individualSessionCreatedLocally =>
      'Session créée localement. Sera synchronisée au cloud dès que la connexion sera disponible.';

  @override
  String get individualUpdateCurrentStack => 'Mettre à jour le Stack actuel';

  @override
  String get individualCurrentStack => 'Stack actuel :';

  @override
  String get individualSetNewTotal => 'Définir un nouveau total';

  @override
  String get individualEnterNewTotalStack => 'Entrer le nouveau stack total';

  @override
  String get individualAddSubtractAmount => 'Ajouter/Soustraire un montant';

  @override
  String get individualAmount => 'Montant';

  @override
  String get individualSetTotal => 'Définir le total';

  @override
  String get individualNoteLabel => 'Note (facultatif)';

  @override
  String get individualNoteHint => 'p.ex. Gagné un gros pot avec AA';

  @override
  String get individualTableAvgHint => 'Moyenne de la table (optionnel)';

  @override
  String get individualUpdateBlinds => 'Mettre à jour les Blinds';

  @override
  String get individualSmallBlind => 'Small Blind';

  @override
  String get individualBigBlind => 'Big Blind';

  @override
  String get individualBbMode => 'Mode BB';

  @override
  String get individualCurrentStackLabel => 'Stack actuel';

  @override
  String get individualSessionInfo => 'Info session';

  @override
  String get individualStartingStack => 'Stack de départ';

  @override
  String get individualInitialBuyIn => 'Buy-in initial';

  @override
  String get individualRebuys => 'Rebuys';

  @override
  String get individualTotalInvested => 'Total investi';

  @override
  String get individualBlindsLabel => 'Blinds';

  @override
  String get individualHandsLogged => 'Mains enregistrées';

  @override
  String get individualLogAHand => 'Enregistrer une main';

  @override
  String get individualGoBackToHand => 'Retourner à la main';

  @override
  String get individualStackChart => 'Graphique du Stack';

  @override
  String get individualCompleteHandToSee =>
      'Terminez une main pour voir la tendance de votre stack';

  @override
  String get individualStopSessionTitle => 'Arrêter la session ?';

  @override
  String get individualStopSessionMessage =>
      'Êtes-vous sûr de vouloir arrêter cette session ? Toutes les mains seront sauvegardées.';

  @override
  String get individualStop => 'Arrêter';

  @override
  String get individualConfirmRebuy => 'Confirmer le Rebuy';

  @override
  String individualRebuyCurrentStack(String stack) {
    return 'Vous avez actuellement $stack restant.';
  }

  @override
  String get individualRebuyReplaceMessage =>
      'Un rebuy remplacera votre stack actuel. Êtes-vous sûr de vouloir continuer ?';

  @override
  String get individualProceedWithRebuy => 'Procéder au Rebuy';

  @override
  String get individualAddOn => 'Add-on';

  @override
  String get individualAddOnDescription =>
      'Entrez le montant de l\'add-on pour augmenter votre investissement total';

  @override
  String get individualAddOnAmount => 'Montant de l\'Add-on';

  @override
  String get individualAddOnConfirm => 'Ajouter';

  @override
  String get individualAddOnDescriptionTournament =>
      'Entrez le prix de l\'add-on et les jetons reçus';

  @override
  String get individualAddOnPrice => 'Prix de l\'Add-on';

  @override
  String get individualAddOnChips => 'Jetons reçus';

  @override
  String get individualRebuy => 'Rebuy';

  @override
  String get individualEnterRebuyAmount =>
      'Entrer le montant du rebuy (le stack sera égal au montant du rebuy)';

  @override
  String get individualEnterRebuyAmountAndStack =>
      'Entrer le montant du rebuy et le nouveau stack';

  @override
  String get individualRebuyAmount => 'Montant du Rebuy';

  @override
  String get individualNewStackSize => 'Nouveau Stack';

  @override
  String get individualChipCountAfterRebuy => 'Nombre de jetons après le rebuy';

  @override
  String individualTotalInvestedAmount(String amount) {
    return 'Total investi : \$$amount';
  }

  @override
  String individualCurrentStackAmount(String stack) {
    return 'Stack actuel : $stack';
  }

  @override
  String individualRebuysCount(int count) {
    return 'Rebuys : $count';
  }

  @override
  String get individualAddRebuy => 'Ajouter un Rebuy';

  @override
  String get individualPleaseEnterValidRebuy =>
      'Veuillez entrer un montant de rebuy valide';

  @override
  String get individualPleaseEnterValidStack =>
      'Veuillez entrer un stack valide';

  @override
  String individualRebuyAddedSimple(String amount) {
    return 'Rebuy ajouté : \$$amount';
  }

  @override
  String individualRebuyAddedWithStack(String amount, String stack) {
    return 'Rebuy ajouté : \$$amount (Stack : $stack)';
  }

  @override
  String get authWelcome => 'Bienvenue sur Final Table';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authRegister => 'S\'inscrire';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authDisplayName => 'Nom d\'affichage';

  @override
  String get authConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authPleaseEnterEmail => 'Veuillez entrer votre e-mail';

  @override
  String get authPleaseEnterValidEmail => 'Veuillez entrer un e-mail valide';

  @override
  String get authPleaseEnterPassword => 'Veuillez entrer votre mot de passe';

  @override
  String get authPleaseEnterName => 'Veuillez entrer votre nom';

  @override
  String get authNameMinLength => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get authPleaseEnterAPassword => 'Veuillez entrer un mot de passe';

  @override
  String get authPasswordMinLength =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get authPleaseConfirmPassword =>
      'Veuillez confirmer votre mot de passe';

  @override
  String get authPasswordsDoNotMatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get authCreateAccount => 'Créer un compte';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authResetPassword => 'Réinitialiser le mot de passe';

  @override
  String get authResetPasswordMessage =>
      'Entrez votre adresse e-mail pour recevoir un lien de réinitialisation du mot de passe.';

  @override
  String get authSendResetLink => 'Envoyer le lien';

  @override
  String get authPasswordResetSent => 'E-mail de réinitialisation envoyé !';

  @override
  String get paywallRestore => 'Restaurer';

  @override
  String get paywallTitle => 'FINAL TABLE PREMIUM';

  @override
  String get paywallAvailablePlans => 'Plans disponibles';

  @override
  String get paywallStepLabel => 'Étape 1 sur 2';

  @override
  String get paywallChooseYourPlan => 'Choisissez votre plan';

  @override
  String get paywallUpgradeOrCancel =>
      'Mettez à niveau ou annulez à tout moment';

  @override
  String get paywallContinue => 'Continuer';

  @override
  String paywallUnlockFeature(String featureName) {
    return 'Débloquer $featureName';
  }

  @override
  String get paywallGoPremium => 'Passer Premium';

  @override
  String get paywallFeatureSubtitle =>
      'Cette fonctionnalité fait partie de Final Table Premium. Choisissez le plan qui correspond à votre style de jeu.';

  @override
  String get paywallGeneralSubtitle =>
      'Débloquez tout ce que Final Table a à offrir. Suivez plus de mains, analysez votre jeu, gérez votre club.';

  @override
  String get paywallProTier => 'Pro';

  @override
  String get paywallFreeTrialBadge => 'Essai gratuit de 7 jours';

  @override
  String get paywallProDescription =>
      'Tout ce qu\'il faut pour maîtriser votre jeu.';

  @override
  String get paywallUnlimitedHandLogging => 'Logging de mains illimité';

  @override
  String get paywallFullSessionHistory => 'Historique complet des sessions';

  @override
  String get paywallAiHandAnalysis => 'Analyse IA des mains';

  @override
  String get paywallExportHandsCsv => 'Export des mains en CSV';

  @override
  String get paywallProMonthly => '19,99 \$/mois';

  @override
  String get paywallProYearly => 'ou 199,99 \$/an. Économisez environ 25 %**';

  @override
  String get paywallStartFreeTrial => 'Commencer l\'essai gratuit de 7 jours';

  @override
  String get paywallEliteTier => 'Elite';

  @override
  String get paywallEliteDescription => 'Passez au niveau supérieur.';

  @override
  String get paywallEverythingInProElite => 'Tout dans Pro';

  @override
  String get paywallEliteFeature1 => 'Profilage avancé des adversaires';

  @override
  String get paywallEliteFeature2 => 'Analyses de sessions détaillées';

  @override
  String get paywallEliteFeature3 => 'Support prioritaire';

  @override
  String get paywallEliteMonthly => '29,99 \$/mois';

  @override
  String get paywallEliteYearly => 'ou 199,99 \$/an. Économisez environ 25 %**';

  @override
  String get paywallGetElite => 'Obtenir Elite';

  @override
  String get paywallClubTier => 'Club';

  @override
  String get paywallClubDescription =>
      'Pour les home games, les clubs et les salles de jeu.';

  @override
  String get paywallEverythingInPro => 'Tout ce qui est dans Pro';

  @override
  String get paywallClubManagement => 'Gestion de club et rôles des membres';

  @override
  String get paywallLiveDealerVoice => 'Logging vocal en direct avec Dealer';

  @override
  String get paywallMultiTableEvents =>
      'Événements multi-tables avec classements';

  @override
  String get paywallClubMonthly => '39,99 \$/mois';

  @override
  String get paywallClubYearly => 'ou 199,99 \$/an. Économisez environ 25 %**';

  @override
  String get paywallGetClub => 'Obtenir Club';

  @override
  String get paywallDisclaimer =>
      'Les abonnements se renouvellent automatiquement. Après votre essai gratuit, le prix affiché vous sera facturé sauf si vous annulez au moins 24 heures avant la fin de la période. Annulez à tout moment dans les paramètres de votre compte.';

  @override
  String get paywallTerms => 'Conditions';

  @override
  String get paywallPrivacy => 'Confidentialité';

  @override
  String get paywallPurchasesRestored => 'Achats restaurés';

  @override
  String get paywallNoPreviousPurchases => 'Aucun achat précédent trouvé';

  @override
  String get paywallWelcomePro => 'Bienvenue dans Pro !';

  @override
  String get paywallPurchaseFailed => 'Achat échoué. Veuillez réessayer.';

  @override
  String get paywallSubscriptionUnavailable =>
      'Options d\'abonnement indisponibles. Veuillez réessayer.';

  @override
  String get paywallMonthly => 'Mensuel';

  @override
  String get paywallAnnual => 'Annuel';

  @override
  String get paywallAnnualSave => 'Annuel (Économisez ~40%)';

  @override
  String paywallComingSoon(String tier) {
    return 'Abonnements $tier bientôt disponibles';
  }

  @override
  String trialConfirmTitle(String tier) {
    return 'Les 7 premiers jours de $tier sont offerts';
  }

  @override
  String get trialConfirmTodayTitle => 'Aujourd\'hui';

  @override
  String trialConfirmTodayBody(String tier) {
    return 'Accès complet à toutes les fonctionnalités $tier';
  }

  @override
  String get trialConfirmReminderTitle => 'Dans 5 jours';

  @override
  String get trialConfirmReminderBody =>
      'Recevez un rappel avant la fin de votre essai gratuit';

  @override
  String get trialConfirmStartTitle => 'Dans 7 jours';

  @override
  String get trialConfirmStartBody =>
      'Votre abonnement commence, sauf si vous annulez avant';

  @override
  String get trialConfirmPriceSummary => 'Essayez 7 jours gratuitement, puis';

  @override
  String get trialConfirmStartCta => 'Commencer mon essai gratuit de 7 jours';

  @override
  String get trialConfirmDisclaimer =>
      'Aucun frais pour l\'instant. Annulez à tout moment sur l\'App Store.';

  @override
  String get introGameSetup => 'Configuration du jeu';

  @override
  String get introConfigureSession => 'Configurez votre session';

  @override
  String get introSmallBlind => 'Small Blind';

  @override
  String get introBigBlind => 'Big Blind';

  @override
  String get introPlayers => 'Joueurs';

  @override
  String get introGameType => 'Type de jeu';

  @override
  String get introBbAnte => 'BB Ante';

  @override
  String get introBbAnteDescription => 'Activer la règle du BB ante';

  @override
  String get introStartGame => 'COMMENCER LE JEU';

  @override
  String get introStartingSession => 'Démarrage de votre session de poker...';

  @override
  String introEnterField(String title) {
    return 'Entrer $title';
  }

  @override
  String get introEnterAmount => 'Entrer le montant';

  @override
  String get introPleaseEnterValidNumber =>
      'Veuillez entrer un nombre positif valide';

  @override
  String get introRingGame => 'Ring Game';

  @override
  String get introMultiTable => 'Multi-Table';

  @override
  String get invitationTitle => 'Invitations de club';

  @override
  String get invitationNoPending => 'Aucune invitation en attente';

  @override
  String get invitationYouWillSeeHere =>
      'Vous verrez les invitations des clubs ici';

  @override
  String get invitationGoBack => 'Retour';

  @override
  String invitationFailedToLoad(String error) {
    return 'Échec du chargement des invitations : $error';
  }

  @override
  String invitationJoinedAs(String clubName, String role) {
    return 'Rejoint $clubName en tant que $role';
  }

  @override
  String invitationFailedToAccept(String error) {
    return 'Échec de l\'acceptation de l\'invitation : $error';
  }

  @override
  String get invitationDeclined => 'Invitation refusée';

  @override
  String invitationFailedToDecline(String error) {
    return 'Échec du refus de l\'invitation : $error';
  }

  @override
  String get invitationUnknownClub => 'Club inconnu';

  @override
  String invitationInvitedBy(String name) {
    return 'Invité par $name';
  }

  @override
  String invitationExpiresDate(String date) {
    return 'Expire le $date';
  }

  @override
  String get invitationExpired => 'Expirée';

  @override
  String invitationExpiresInDays(int days) {
    return 'dans $days jour(s)';
  }

  @override
  String invitationExpiresInHours(int hours) {
    return 'dans $hours heure(s)';
  }

  @override
  String get invitationExpiresSoon => 'bientôt';

  @override
  String get invitationDeclineButton => 'Refuser';

  @override
  String get invitationAcceptButton => 'Accepter';

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationToday => 'Aujourd\'hui';

  @override
  String get notificationYesterday => 'Hier';

  @override
  String get notificationThisWeek => 'Cette semaine';

  @override
  String get notificationEarlier => 'Plus tôt';

  @override
  String get notificationMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notificationMarkAsRead => 'Marquer comme lu';

  @override
  String get notificationNoNotifications => 'Aucune notification';

  @override
  String get notificationEvents => 'Événements';

  @override
  String get notificationRsvp => 'RSVP';

  @override
  String get notificationClubs => 'Clubs';

  @override
  String get notificationInvitations => 'Invitations';

  @override
  String get notificationSeats => 'Sièges';

  @override
  String get notificationSupport => 'Support';

  @override
  String get notificationClubNotFound => 'Club introuvable';

  @override
  String get notificationEventNotFound => 'Événement introuvable';

  @override
  String notificationError(String error) {
    return 'Erreur : $error';
  }

  @override
  String notificationErrorLoadingEvent(String error) {
    return 'Erreur de chargement de l\'événement : $error';
  }

  @override
  String notificationFailedToLoadClub(String error) {
    return 'Échec du chargement du club : $error';
  }

  @override
  String get notificationClubInvitation => 'Invitation au club';

  @override
  String get notificationInvitedToJoin => 'Vous avez été invité à rejoindre';

  @override
  String get notificationInvitationDeclined => 'Invitation refusée';

  @override
  String get notificationNotAuthenticated => 'Non authentifié';

  @override
  String get notificationInvitationAccepted => 'Invitation acceptée';

  @override
  String notificationAcceptedMessage(String name, String clubName) {
    return '$name a accepté l\'invitation à rejoindre $clubName.';
  }

  @override
  String get notificationInvitationDeclinedTitle => 'Invitation refusée';

  @override
  String notificationDeclinedMessage(String name, String clubName) {
    return '$name a refusé l\'invitation à rejoindre $clubName.';
  }

  @override
  String get notificationRequestResolved => 'Demande résolue';

  @override
  String get notificationRequestClosed => 'Demande fermée';

  @override
  String get notificationResponse => 'Réponse';

  @override
  String get calendarTitle => 'Calendrier poker';

  @override
  String get calendarNewEvent => 'Nouvel événement';

  @override
  String get calendarEventType => 'Type d\'événement';

  @override
  String get calendarEventTitle => 'Titre';

  @override
  String get calendarLocation => 'Lieu';

  @override
  String get calendarBuyInAmount => 'Montant du Buy-in';

  @override
  String get calendarEventDateTime => 'Date et heure de l\'événement';

  @override
  String get calendarStarts => 'Début';

  @override
  String get calendarSelectDate => 'Sélectionner la date :';

  @override
  String get calendarReset => 'Réinitialiser';

  @override
  String get calendarSun => 'DIM';

  @override
  String get calendarMon => 'LUN';

  @override
  String get calendarTue => 'MAR';

  @override
  String get calendarWed => 'MER';

  @override
  String get calendarThu => 'JEU';

  @override
  String get calendarFri => 'VEN';

  @override
  String get calendarSat => 'SAM';

  @override
  String get calendarNoRecentEvents => 'Aucun événement récent';

  @override
  String get calendarAddFirstEvent => 'Ajoutez votre premier événement poker !';

  @override
  String get calendarAddNewEvent => 'Ajouter un nouvel événement';

  @override
  String get calendarSelectYear => 'Sélectionner l\'année';

  @override
  String get calendarEditEvent => 'Modifier l\'événement';

  @override
  String get calendarDeleteEvent => 'Supprimer l\'événement';

  @override
  String get calendarTournament => 'Tournament';

  @override
  String get calendarCashGame => 'Cash Game';

  @override
  String get calendarPrivateGame => 'Partie privée';

  @override
  String get calendarOnline => 'En ligne';

  @override
  String calendarFailedToCreateEvent(String error) {
    return 'Échec de la création de l\'événement : $error';
  }

  @override
  String calendarFailedToUpdateEvent(String error) {
    return 'Échec de la mise à jour de l\'événement : $error';
  }

  @override
  String get calendarFailedToDeleteEvent =>
      'Échec de la suppression de l\'événement';

  @override
  String get calendarClubNotFound => 'Club introuvable';

  @override
  String get calendarEventNotFound => 'Événement introuvable';

  @override
  String calendarFailedToLoadEvent(String error) {
    return 'Échec du chargement de l\'événement : $error';
  }

  @override
  String calendarDeleteConfirmTitle(String title) {
    return 'Supprimer $title ?';
  }

  @override
  String calendarDeleteConfirmMessage(String title) {
    return 'Êtes-vous sûr de vouloir supprimer \"$title\" ?\nCette action est irréversible.';
  }

  @override
  String get sessionAnalyticsTitle => 'Analyse de session';

  @override
  String sessionAnalyticsHandsLogged(int count) {
    return '$count mains enregistrées';
  }

  @override
  String get sessionAnalyticsDeleteTitle => 'Supprimer la session ?';

  @override
  String get sessionAnalyticsDeleteMessage =>
      'Cela supprimera définitivement cette session, y compris tout l\'historique des mains, les données du graphique de stack et les rapports d\'analyse IA. Cette action est irréversible.';

  @override
  String get sessionAnalyticsDeleted => 'Session supprimée';

  @override
  String get sessionAnalyticsFailedToDelete =>
      'Échec de la suppression de la session';

  @override
  String get sessionAnalyticsExportSession => 'Exporter la session';

  @override
  String sessionAnalyticsExportConfirm(int count, String email) {
    return 'Exporter $count mains vers $email ?';
  }

  @override
  String get sessionAnalyticsExport => 'Exporter';

  @override
  String sessionAnalyticsExportSent(String email) {
    return 'Export envoyé à $email';
  }

  @override
  String sessionAnalyticsExportFailed(String error) {
    return 'Échec de l\'export : $error';
  }

  @override
  String get sessionAnalyticsNoEmailFound =>
      'Aucune adresse e-mail trouvée. Veuillez vous connecter avec un compte e-mail.';

  @override
  String get sessionAnalyticsPokerSession => 'Session de poker';

  @override
  String get sessionAnalyticsTotalInvested => 'Total investi';

  @override
  String get sessionAnalyticsFinalStack => 'Stack final';

  @override
  String get sessionAnalyticsCashout => 'Encaissement';

  @override
  String get sessionAnalyticsProfitLoss => 'Profit/Perte';

  @override
  String get sessionAnalyticsNotAvailableFull => 'Non disponible';

  @override
  String get sessionAnalyticsAvgGrowth => 'Croissance moy.';

  @override
  String get sessionAnalyticsHourlyRate => 'Taux horaire';

  @override
  String get sessionAnalyticsFinished => 'Classement';

  @override
  String get sessionAnalyticsDuration => 'Durée';

  @override
  String get sessionAnalyticsRebuys => 'Rebuys';

  @override
  String get sessionAnalyticsAddons => 'Add-ons';

  @override
  String get sessionAnalyticsStackChart => 'Graphique du Stack';

  @override
  String get sessionAnalyticsNoStackHistory =>
      'Aucun historique de Stack disponible';

  @override
  String get sessionAnalyticsStackTrackedFuture =>
      'Les variations de stack seront suivies dans les futures sessions';

  @override
  String get sessionAnalyticsViewLoggedHands => 'Voir les mains enregistrées';

  @override
  String get sessionAnalyticsStart => 'Début';

  @override
  String get sessionAnalyticsRebuy => 'Rebuy';

  @override
  String get sessionAnalyticsEnd => 'Fin';

  @override
  String get seatSetupTitle => 'Configuration du siège';

  @override
  String get seatSetupManagePlayers => 'Gérer les joueurs';

  @override
  String get seatSetupClickToConfig =>
      'Appuyez sur un siège pour configurer. Faites glisser le bouton pour le positionner';

  @override
  String get seatSetupButtonLocked => 'Bouton verrouillé — main en cours';

  @override
  String get seatSetupUpdatePlayerInfo =>
      'Mettre à jour les informations du joueur';

  @override
  String get seatSetupEmpty => 'Vide';

  @override
  String get seatSetupThisIsMySeat => 'C\'est mon siège';

  @override
  String get seatSetupPlayerName => 'Nom du joueur';

  @override
  String get seatSetupBuyInAmount => 'Montant du Buy-in (\$)';

  @override
  String get seatSetupStartingChips => 'Jetons de départ';

  @override
  String seatSetupSaveAsOpponent(String name) {
    return 'Enregistrer \"$name\" comme adversaire ?';
  }

  @override
  String get seatSetupOpponentSaved => 'Adversaire enregistré !';

  @override
  String seatSetupFailedToSave(String error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String get seatSetupNoData => 'Pas de données';

  @override
  String get seatSetupStartSession => 'Commencer la session';

  @override
  String get seatSetupSaveChanges => 'Enregistrer les modifications';

  @override
  String get seatSetupPleaseSelectSeat => 'Veuillez sélectionner votre siège';

  @override
  String seatSetupSeatNumber(int number) {
    return 'Siège $number';
  }

  @override
  String seatSetupPlayerDefault(int number) {
    return 'Joueur $number';
  }

  @override
  String get quickStackTitle => 'Mettre à jour les Stacks et le Bouton';

  @override
  String quickStackBlinds(String blinds) {
    return 'Blinds : $blinds';
  }

  @override
  String get quickStackInstruction =>
      'Appuyez sur le stack pour modifier  •  Glissez pour ajuster  •  Appuyez sur D pour le bouton';

  @override
  String get quickStackContinue => 'CONTINUER À ENREGISTRER LA MAIN';

  @override
  String get quickStackEditStack => 'Modifier le Stack';

  @override
  String get quickStackStackInBb => 'Stack en BB';

  @override
  String quickStackCurrentValue(String bbValue, String chipValue) {
    return 'Actuel : $bbValue BB = $chipValue';
  }

  @override
  String get quickStackValidationError =>
      'Veuillez entrer une valeur entre 0 et 1000 BB';

  @override
  String quickStackSeat(int number) {
    return 'Siège $number';
  }

  @override
  String get quickStackEmpty => 'Vide';

  @override
  String quickStackPlayerDefault(int id) {
    return 'Joueur $id';
  }

  @override
  String get handReviewTitle => 'Revue de la main';

  @override
  String get handReviewYourHoleCards => 'Vos Hole Cards';

  @override
  String get handReviewOptional => '(facultatif)';

  @override
  String get handReviewQuickTags => 'Tags rapides';

  @override
  String get handReviewTagBluff => 'Bluff';

  @override
  String get handReviewTagValue => 'Value';

  @override
  String get handReviewTagMistake => 'Erreur';

  @override
  String get handReviewTagCooler => 'Cooler';

  @override
  String get handReviewTagHeroCall => 'Hero Call';

  @override
  String get handReviewTagExploit => 'Exploit';

  @override
  String get handReviewNotes => 'Notes';

  @override
  String get handReviewNotesHint => 'Ajouter une note sur cette main...';

  @override
  String get handReviewSaveHand => 'Sauvegarder la main';

  @override
  String get handReviewSkip => 'Passer';

  @override
  String get handReviewDuplicateCardError =>
      'Vous ne pouvez pas sélectionner la même carte deux fois !';

  @override
  String get handReviewSelectBothOrNone =>
      'Veuillez sélectionner les deux hole cards ou laisser les deux vides';

  @override
  String get holeCardsTitle => 'Vos Hole Cards';

  @override
  String get holeCardsSubtitle => 'Hole Cards';

  @override
  String get holeCardsWinnerBadge => 'GAGNANT';

  @override
  String get holeCardsSave => 'Enregistrer';

  @override
  String get holeCardsSkip => 'Passer';

  @override
  String get holeCardsSkipAllRemaining => 'Passer toutes les restantes';

  @override
  String get holeCardsDuplicateCardError =>
      'Vous ne pouvez pas sélectionner la même carte deux fois !';

  @override
  String get holeCardsSelectBothOrSkip =>
      'Veuillez sélectionner les deux hole cards ou passer pour continuer';

  @override
  String get holeCardsClearAll => 'Tout effacer';

  @override
  String get showdownTitle => 'Showdown';

  @override
  String get showdownEnterOpponentCards =>
      'Entrez les cartes des adversaires au showdown :';

  @override
  String showdownPlayerLabel(int seatNumber) {
    return 'Joueur $seatNumber';
  }

  @override
  String get showdownCard1 => 'Carte 1';

  @override
  String get showdownCard2 => 'Carte 2';

  @override
  String get showdownClear => 'Effacer';

  @override
  String get showdownWinner => 'Gagnant :';

  @override
  String get showdownHandDescriptionLabel =>
      'Description de la main (facultatif)';

  @override
  String get showdownHandDescriptionHint =>
      'ex. « Quinte flush », « Full aux as par les rois »';

  @override
  String get showdownSkip => 'Passer';

  @override
  String get showdownSave => 'Enregistrer';

  @override
  String get showdownSelectCard => 'Sélectionner une carte';

  @override
  String get tableManagementSectionTitle => 'TABLE';

  @override
  String tableManagementPlayersCount(int count) {
    return '$count joueurs';
  }

  @override
  String get tableManagementDealerButton => 'Bouton Dealer';

  @override
  String get tableManagementAddPlayer => 'Ajouter un joueur';

  @override
  String tableManagementYouSuffix(String name) {
    return '$name (Vous)';
  }

  @override
  String get tableManagementAdjustStack => 'Ajuster le Stack';

  @override
  String get tableManagementRebuy => 'Rebuy';

  @override
  String get tableManagementRemove => 'Retirer';

  @override
  String get tableManagementAdjustStackTitle => 'Ajuster le Stack';

  @override
  String get tableManagementEnterStackAmount => 'Entrer le montant du stack';

  @override
  String get tableManagementRebuyTitle => 'Rebuy';

  @override
  String get tableManagementRebuyAmountHint => 'Montant du rebuy à ajouter';

  @override
  String get tableManagementAdd => 'Ajouter';

  @override
  String get tableManagementRemovePlayerTitle => 'Retirer le joueur ?';

  @override
  String tableManagementRemovePlayerMessage(String playerName) {
    return 'Retirer $playerName de la table ?';
  }

  @override
  String tableManagementAddPlayerSeatTitle(int seatNumber) {
    return 'Ajouter un joueur — Siège $seatNumber';
  }

  @override
  String get tableManagementThisIsMe => 'C\'est moi';

  @override
  String get tableManagementNameLabel => 'Nom';

  @override
  String get tableManagementSearchOrEnterName => 'Rechercher ou entrer un nom';

  @override
  String tableManagementSaveAsOpponent(String name) {
    return 'Enregistrer \"$name\" comme adversaire';
  }

  @override
  String tableManagementSavedAsOpponent(String name) {
    return '$name enregistré comme adversaire';
  }

  @override
  String get tableManagementStartingStack => 'Stack de départ';

  @override
  String get tableManagementStackAmountHint => 'Montant du stack';

  @override
  String get tableManagementMoveMeHere => 'Me déplacer ici';

  @override
  String tableManagementSeatLabel(int seatNumber) {
    return 'Siège $seatNumber';
  }

  @override
  String get seatConfigRemove => 'Retirer';

  @override
  String get seatConfigRemoveMe => 'Me retirer de ce siège';

  @override
  String get seatConfigThisIsMe => 'C\'est moi';

  @override
  String get seatConfigNameLabel => 'Nom';

  @override
  String get seatConfigSearchOrEnterName => 'Rechercher ou entrer un nom';

  @override
  String seatConfigSaveAsOpponent(String name) {
    return 'Enregistrer \"$name\" comme adversaire';
  }

  @override
  String seatConfigSavedAsOpponent(String name) {
    return '$name enregistré comme adversaire';
  }

  @override
  String seatConfigSeatTitle(int seatNumber) {
    return 'Siège $seatNumber';
  }

  @override
  String get seatConfigStackLabel => 'Stack';

  @override
  String get seatConfigUpdateButton => 'Mettre à jour';

  @override
  String get seatConfigAddPlayerButton => 'Ajouter un joueur';

  @override
  String get seatManagementSetupSeats => 'Configuration des sièges';

  @override
  String get seatManagementManagePlayers => 'Gérer les joueurs';

  @override
  String get seatManagementChooseSeatSubtitle =>
      'Choisissez votre siège et configurez la table';

  @override
  String get seatManagementUpdatePlayerSubtitle =>
      'Mettre à jour les informations du joueur';

  @override
  String get seatManagementButtonPosition => 'Position du bouton';

  @override
  String seatManagementSeatLabel(int seatNumber) {
    return 'Siège $seatNumber';
  }

  @override
  String get seatManagementEmpty => 'Vide';

  @override
  String get seatManagementActive => 'Actif';

  @override
  String get seatManagementPlayerNameLabel => 'Nom du joueur';

  @override
  String get seatManagementEnterPlayerName => 'Entrer le nom du joueur';

  @override
  String get seatManagementBuyInAmountCash => 'Montant du Buy-in (\$)';

  @override
  String get seatManagementStartingChips => 'Jetons de départ';

  @override
  String get seatManagementSaveOpponentTitle => 'Enregistrer l\'adversaire ?';

  @override
  String seatManagementSaveOpponentMessage(String name) {
    return 'Souhaitez-vous enregistrer \"$name\" dans votre liste d\'adversaires pour un suivi futur ?';
  }

  @override
  String get seatManagementNotNow => 'Pas maintenant';

  @override
  String seatManagementSaveAsOpponentPrompt(String name) {
    return 'Enregistrer \"$name\" comme adversaire ?';
  }

  @override
  String seatManagementOpponentSavedSuccess(String name) {
    return 'Adversaire \"$name\" enregistré avec succès !';
  }

  @override
  String seatManagementFailedToSaveOpponent(String error) {
    return 'Échec de l\'enregistrement de l\'adversaire : $error';
  }

  @override
  String get seatManagementStartSession => 'Commencer la session';

  @override
  String get seatManagementSaveChanges => 'Enregistrer les modifications';

  @override
  String get seatManagementSelectYourSeat =>
      'Veuillez sélectionner votre siège';

  @override
  String get inviteMemberTitle => 'Inviter un membre';

  @override
  String get inviteMemberEmailLabel => 'ADRESSE E-MAIL';

  @override
  String get inviteMemberEmailHint => 'Entrer l\'adresse e-mail';

  @override
  String get inviteMemberEmailRequired => 'Veuillez entrer une adresse e-mail';

  @override
  String get inviteMemberEmailInvalid =>
      'Veuillez entrer une adresse e-mail valide';

  @override
  String get inviteMemberRoleLabel => 'RÔLE';

  @override
  String get inviteMemberRoleDealer => 'Dealer';

  @override
  String get inviteMemberRoleAdmin => 'Admin';

  @override
  String get inviteMemberSendInvite => 'Envoyer l\'invitation';

  @override
  String inviteMemberAlreadyMember(String displayName, String clubName) {
    return '$displayName est déjà membre de $clubName';
  }

  @override
  String get inviteMemberAddedNotificationTitle =>
      'Vous avez été ajouté à un club !';

  @override
  String inviteMemberAddedNotificationBody(
      String inviterName, String clubName, String role) {
    return '$inviterName vous a ajouté à \"$clubName\" en tant que $role.';
  }

  @override
  String get inviteMemberAddedSuccessTitle => 'Membre ajouté !';

  @override
  String inviteMemberAddedSuccessMessage(
      String displayName, String clubName, String role) {
    return '$displayName a été ajouté à $clubName en tant que $role.';
  }

  @override
  String get inviteMemberInvitationSentTitle => 'Invitation envoyée !';

  @override
  String inviteMemberInvitationSentMessage(String email, String clubName) {
    return 'Un e-mail d\'invitation a été envoyé à $email. Une fois inscrit, il pourra rejoindre $clubName.';
  }

  @override
  String inviteMemberError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get inviteMemberRoleAnAdmin => 'un admin';

  @override
  String get inviteMemberRoleADealer => 'un dealer';

  @override
  String get registerClubTitle => 'Enregistrer un club';

  @override
  String get registerClubNameLabel => 'Nom du club';

  @override
  String get registerClubNamePlaceholder => 'ex. Lucky Aces Poker Club';

  @override
  String get registerClubNameRequired => 'Veuillez entrer un nom de club';

  @override
  String get registerClubAddressLabel => 'Adresse';

  @override
  String get registerClubAddressPlaceholder =>
      'ex. 123 Rue Principale, Ville, Pays';

  @override
  String get registerClubAddressRequired =>
      'Veuillez entrer l\'adresse du club';

  @override
  String get registerClubPhoneLabel => 'Numéro de téléphone';

  @override
  String get registerClubPhonePlaceholder => 'ex. +33 1 23 45 67 89';

  @override
  String get registerClubPhoneRequired =>
      'Veuillez entrer un numéro de téléphone';

  @override
  String get registerClubAdminEmailLabel =>
      'E-mail de l\'administrateur du club';

  @override
  String get registerClubAdminEmailPlaceholder => 'ex. admin@monclub.com';

  @override
  String get registerClubAdminEmailRequired =>
      'Veuillez entrer l\'e-mail de l\'administrateur';

  @override
  String get registerClubAdminEmailInvalid =>
      'Veuillez entrer un e-mail valide';

  @override
  String get registerClubInfoMessage =>
      'Cette personne sera notifiée lorsque le club sera approuvé et deviendra le propriétaire du club.';

  @override
  String get registerClubSubmitRequest => 'Soumettre la demande';

  @override
  String registerClubFailedToSubmit(String error) {
    return 'Échec de la soumission de la demande : $error';
  }

  @override
  String get registerClubSuccessTitle => 'Demande soumise !';

  @override
  String registerClubSuccessMessage(String email) {
    return 'Votre demande d\'enregistrement de club a été soumise. Nous vous notifierons à $email une fois qu\'elle sera examinée.';
  }

  @override
  String get registerClubGotIt => 'Compris';

  @override
  String get loggingModeChooseMode => 'Choisir le mode';

  @override
  String get loggingModeFullTitle => 'Mode de logging complet';

  @override
  String get loggingModeFullSubtitle => 'Suivi complet de session';

  @override
  String get loggingModeFullFeature1 => 'Suivi de session multi-mains';

  @override
  String get loggingModeFullFeature2 => 'Statistiques en temps réel';

  @override
  String get loggingModeFullFeature3 => 'Historique détaillé des mains';

  @override
  String get loggingModeFullFeature4 => 'Analyse de session';

  @override
  String get loggingModeIndividualTitle => 'Mode session rapide';

  @override
  String get loggingModeIndividualSubtitle => 'Suivi d\'une seule main';

  @override
  String get loggingModeIndividualFeature1 => 'Focus sur une main';

  @override
  String get loggingModeIndividualFeature2 => 'Logging rapide';

  @override
  String get loggingModeIndividualFeature3 => 'Analyse de main';

  @override
  String get loggingModeIndividualFeature4 => 'Résultats instantanés';

  @override
  String get loggingModeFeatures => 'Fonctionnalités';

  @override
  String get loggingModeStart => 'Commencer';

  @override
  String get earningsChartAllTimeEarnings => 'Gains cumulés';

  @override
  String earningsChartSinceDate(String date) {
    return 'Depuis le $date';
  }

  @override
  String get earningsChartTournament => 'Tournament';

  @override
  String get earningsChartCash => 'Cash';

  @override
  String get earningsChartNoData => 'Aucune donnée de gains';

  @override
  String get earningsChartNoDataSubtitle =>
      'Terminez quelques sessions pour voir votre graphique de gains';

  @override
  String get earningsChartMtt => 'MTT';

  @override
  String get opponentHandsTitle => 'Historique des mains';

  @override
  String opponentHandsCount(int count) {
    return '$count mains';
  }

  @override
  String get opponentHandsLoading => 'Chargement de l\'historique des mains...';

  @override
  String get opponentHandsError => 'Une erreur est survenue';

  @override
  String get opponentHandsRetry => 'Réessayer';

  @override
  String get opponentHandsNoHandsTitle => 'Aucune main trouvée';

  @override
  String opponentHandsNoHandsSubtitle(String name) {
    return 'Vous n\'avez pas encore joué de mains\navec $name.';
  }

  @override
  String get opponentHandsOppWon => 'ADV. GAGNE';

  @override
  String get opponentHandsYou => 'Vous';

  @override
  String opponentHandsPot(String amount) {
    return 'Pot $amount';
  }

  @override
  String get opponentHandsUnknownSession => 'Session inconnue';

  @override
  String get clubDashboardLive => 'En direct';

  @override
  String get clubDashboardUpcoming => 'À venir';

  @override
  String get clubDashboardPast => 'Passé';

  @override
  String get clubDashboardNoLiveEvents => 'Aucun événement en direct';

  @override
  String get clubDashboardNoUpcomingEvents => 'Aucun événement à venir';

  @override
  String get clubDashboardNoPastEvents => 'Aucun événement passé';

  @override
  String get clubDashboardAdmin => 'Admin';

  @override
  String get clubDashboardCreateEventHint =>
      'Appuyez sur le bouton ci-dessous pour en créer un';

  @override
  String get clubDashboardCheckBackLater =>
      'Revenez plus tard pour de nouveaux événements';

  @override
  String get clubDashboardEventsWillAppear =>
      'Les événements apparaîtront ici lorsqu\'ils commenceront';

  @override
  String get clubDashboardPastEventsWillAppear =>
      'Les événements terminés apparaîtront ici';

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
    return '$count en jeu';
  }

  @override
  String clubDashboardMemberCount(int count) {
    return '$count membres';
  }

  @override
  String get clubSettingsTitle => 'Paramètres du club';

  @override
  String get clubSettingsClubInfo => 'Informations du club';

  @override
  String get clubSettingsClubName => 'Nom du club';

  @override
  String get clubSettingsAddress => 'Adresse';

  @override
  String get clubSettingsPhone => 'Téléphone';

  @override
  String get clubSettingsDescription => 'Description';

  @override
  String get clubSettingsSaveChanges => 'Enregistrer les modifications';

  @override
  String get clubSettingsInfoSaved => 'Informations du club enregistrées';

  @override
  String clubSettingsErrorSaving(String error) {
    return 'Erreur lors de l\'enregistrement : $error';
  }

  @override
  String get clubSettingsNoTablesYet => 'Aucune table pour le moment';

  @override
  String get clubSettingsAddTableHint => 'Ajoutez une table pour commencer';

  @override
  String clubSettingsErrorLoading(String error) {
    return 'Erreur de chargement des données : $error';
  }

  @override
  String get eventEditTitle => 'Modifier l\'événement';

  @override
  String get eventNewTitle => 'Nouvel événement';

  @override
  String get eventNoTablesAssigned => 'Aucune table assignée';

  @override
  String get eventNoTablesAssignedDesc =>
      'Aucune table assignée à cet événement. Veuillez retourner en arrière et assigner des tables d\'abord.';

  @override
  String get eventGoBack => 'Retour';

  @override
  String get eventContinue => 'Continuer';

  @override
  String get eventNameOptional => 'Nom de l\'événement (facultatif)';

  @override
  String get eventNameLabel => 'Nom de l\'événement';

  @override
  String get eventStakesHint => 'Stakes (ex. 1/2)';

  @override
  String get eventBuyInAmount => 'Montant du Buy-in';

  @override
  String get eventMinBuyIn => 'Buy-in min (\$)';

  @override
  String get eventStartingStack => 'Stack de départ';

  @override
  String get eventGameType => 'Type de jeu';

  @override
  String get eventTournament => 'Tournament';

  @override
  String get eventCashGame => 'Cash Game';

  @override
  String get eventDateAndTime => 'Date et heure de l\'événement';

  @override
  String get eventStarts => 'Début';

  @override
  String get eventTables => 'Tables';

  @override
  String get eventDeselectAll => 'Tout désélectionner';

  @override
  String get eventSelectAll => 'Tout sélectionner';

  @override
  String get eventAllTablesInUse =>
      'Toutes les tables sont utilisées par des événements en cours';

  @override
  String get eventNoTablesConfigured =>
      'Aucune table configurée pour le moment';

  @override
  String get eventDescriptionLabel => 'Description';

  @override
  String get eventNotifyMembers => 'Notifier les membres';

  @override
  String get eventNotifyMembersSubtitle =>
      'Envoyer une notification à tous les membres du club';

  @override
  String get eventDeleteEvent => 'Supprimer l\'événement';

  @override
  String get eventDeleteConfirmTitle => 'Supprimer l\'événement ?';

  @override
  String get eventDeleteConfirmBody =>
      'Cela supprimera définitivement cet événement et toutes les données associées. Cette action est irréversible.';

  @override
  String eventDeleteFailed(String error) {
    return 'Échec de la suppression de l\'événement : $error';
  }

  @override
  String get eventAttendeesTitle => 'Participants';

  @override
  String eventAttendeesGoing(int count) {
    return 'Confirmés ($count)';
  }

  @override
  String eventAttendeesMaybe(int count) {
    return 'Peut-être ($count)';
  }

  @override
  String eventAttendeesNo(int count) {
    return 'Non ($count)';
  }

  @override
  String get eventAttendeesNoConfirmed => 'Personne n\'a encore confirmé';

  @override
  String get eventAttendeesNoMaybes => 'Aucun peut-être';

  @override
  String get eventAttendeesNoDeclines => 'Aucun refus';

  @override
  String get eventDetailLiveNow => 'L\'événement est maintenant EN DIRECT !';

  @override
  String get eventDetailEnded => 'L\'événement est terminé';

  @override
  String get eventDetailCancelled => 'L\'événement a été annulé';

  @override
  String get eventDetailPaused => 'L\'événement est en pause';

  @override
  String get eventDetailStatusUpdated => 'Statut de l\'événement mis à jour';

  @override
  String get eventDetailRemovedFromCalendar =>
      'Événement retiré de votre calendrier';

  @override
  String get eventDetailRsvpGoing => 'Confirmé';

  @override
  String get eventDetailRsvpMaybe => 'Peut-être';

  @override
  String get eventDetailRsvpCantGo => 'Ne peut pas y aller';

  @override
  String eventDetailRsvpFailed(String error) {
    return 'Échec de la mise à jour du RSVP : $error';
  }

  @override
  String get eventDetailCantStartTitle => 'Impossible de démarrer l\'événement';

  @override
  String get eventDetailCantStartBody =>
      'Aucune table n\'est assignée à cet événement. Veuillez d\'abord ajouter des tables.';

  @override
  String get eventDetailStarted => 'Événement démarré !';

  @override
  String eventDetailStartFailed(String error) {
    return 'Échec du démarrage de l\'événement : $error';
  }

  @override
  String get eventDetailFinishTitle => 'Terminer l\'événement ?';

  @override
  String get eventDetailCancelTitle => 'Annuler l\'événement ?';

  @override
  String get eventDetailFinishBody =>
      'Cela terminera toutes les tables actives et finalisera les classements.';

  @override
  String get eventDetailCancelBody =>
      'Cela notifiera tous les membres et annulera l\'événement.';

  @override
  String get eventDetailFinishButton => 'Terminer l\'événement';

  @override
  String get eventDetailCancelButton => 'Annuler l\'événement';

  @override
  String get eventDetailKeepEvent => 'Garder l\'événement';

  @override
  String get eventDetailLiveBadge => 'EN DIRECT';

  @override
  String get eventDetailCancelledBadge => 'ANNULÉ';

  @override
  String get eventDetailCompletedBadge => 'TERMINÉ';

  @override
  String get eventDetailUpcomingBadge => 'À VENIR';

  @override
  String get eventDetailLocation => 'Lieu';

  @override
  String get eventDetailBuyIn => 'Buy-in';

  @override
  String get eventDetailStakes => 'Stakes';

  @override
  String get eventDetailStartingStack => 'Stack de départ';

  @override
  String get eventDetailAbout => 'À PROPOS';

  @override
  String get eventDetailAddedToCalendar =>
      'Événement ajouté à votre calendrier !';

  @override
  String eventDetailCalendarFailed(String error) {
    return 'Échec de l\'ajout au calendrier : $error';
  }

  @override
  String get eventManagementEventsTitle => 'Événements';

  @override
  String get eventManagementNewEvent => 'Nouvel événement';

  @override
  String get eventManagementNoEvents => 'Aucun événement';

  @override
  String get eventManagementNoEventsSubtitle =>
      'Créez un événement pour suivre les classements en direct';

  @override
  String get eventManagementActiveEvents => 'Événements actifs';

  @override
  String get eventManagementPastEvents => 'Événements passés';

  @override
  String eventManagementErrorLoading(String error) {
    return 'Erreur de chargement des événements : $error';
  }

  @override
  String get eventManagementNoTables =>
      'Aucune table disponible. Créez d\'abord des tables.';

  @override
  String eventManagementCreated(String name) {
    return 'Événement \"$name\" créé';
  }

  @override
  String eventManagementCreateFailed(String error) {
    return 'Échec de la création de l\'événement : $error';
  }

  @override
  String get eventManagementEndEvent => 'Terminer l\'événement';

  @override
  String eventManagementEndConfirm(String name) {
    return 'Êtes-vous sûr de vouloir terminer \"$name\" ?';
  }

  @override
  String eventManagementEnded(String name) {
    return 'Événement \"$name\" terminé';
  }

  @override
  String eventManagementEndFailed(String error) {
    return 'Échec de la terminaison de l\'événement : $error';
  }

  @override
  String get eventManagementLinkCopied => 'Lien copié dans le presse-papiers';

  @override
  String get eventManagementShare => 'Partager';

  @override
  String get eventManagementPause => 'Pause';

  @override
  String get eventManagementResume => 'Reprendre';

  @override
  String get eventManagementEnd => 'Terminer';

  @override
  String get eventManagementCreateEvent => 'Créer un événement';

  @override
  String get eventManagementEventNameHint => 'ex. Tournament du vendredi soir';

  @override
  String get eventManagementSelectTables => 'Sélectionner les tables';

  @override
  String eventManagementTableNumber(int number) {
    return 'Table $number';
  }

  @override
  String get eventManagementPublicEvent => 'Événement public';

  @override
  String get eventManagementPublicSubtitle =>
      'Tout le monde peut voir le classement';

  @override
  String get eventManagementAccessCode => 'Code d\'accès (facultatif)';

  @override
  String get eventManagementAccessCodeSubtitle =>
      'Pour partager avec des utilisateurs spécifiques';

  @override
  String get eventManagementEnterName => 'Veuillez entrer un nom d\'événement';

  @override
  String get eventManagementSelectTable =>
      'Veuillez sélectionner au moins une table';

  @override
  String get eventManagementPublic => 'Public';

  @override
  String get eventManagementPrivate => 'Privé';

  @override
  String adminEventTablesSummary(int count, int occupied, int open) {
    return '$count tables • $occupied assis • $open libres';
  }

  @override
  String get adminEventTablesAddTable => 'Ajouter une table';

  @override
  String get adminEventTablesNoTables => 'Aucune table disponible à ajouter';

  @override
  String adminEventTablesCloseConfirm(String tableName) {
    return 'Fermer $tableName ?';
  }

  @override
  String adminEventTablesCloseWithPlayers(int count) {
    return 'Cela déplacera $count joueur(s) sur la liste d\'attente et retirera la table de cet événement.';
  }

  @override
  String get adminEventTablesCloseEmpty =>
      'Cela retirera la table de cet événement.';

  @override
  String get adminEventTablesCloseButton => 'Fermer la table';

  @override
  String adminEventTablesTableAdded(String tableName) {
    return '$tableName ajoutée à l\'événement';
  }

  @override
  String adminEventTablesClosedWithWaitlist(String tableName, int count) {
    return '$tableName fermée. $count joueur(s) déplacé(s) sur la liste d\'attente.';
  }

  @override
  String adminEventTablesClosed(String tableName) {
    return '$tableName fermée.';
  }

  @override
  String get adminEventTablesNoWaitlist => 'Personne en liste d\'attente';

  @override
  String adminEventTablesWaitlistCount(int count) {
    return '$count en liste d\'attente';
  }

  @override
  String adminEventTablesWaitlistNext(String name) {
    return 'Suivant : $name';
  }

  @override
  String get adminEventTablesWaitlist => 'Liste d\'attente';

  @override
  String get adminEventTablesNotified => 'Notifié';

  @override
  String get adminEventTablesNotify => 'Notifier';

  @override
  String get adminEventTablesSeat => 'Siège';

  @override
  String adminEventTablesSeatAt(String tableName, int count) {
    return '$tableName ($count libres)';
  }

  @override
  String get adminEventTablesNoEmptySeats =>
      'Aucun siège libre sur cette table';

  @override
  String adminEventTablesPlayerSeated(String name, String tableName) {
    return '$name assis à $tableName';
  }

  @override
  String adminEventTablesPlayerNotified(String name) {
    return '$name notifié';
  }

  @override
  String get adminTableSeatPlayer => 'Asseoir un joueur';

  @override
  String get adminTableFromWaitlist => 'De la liste d\'attente';

  @override
  String adminTableWaitlistNextIs(String name) {
    return '$name est le suivant';
  }

  @override
  String get adminTableClubMember => 'Membre du club';

  @override
  String get adminTableSearchMembers => 'Rechercher des membres existants';

  @override
  String get adminTableWalkUpPlayer => 'Joueur sans réservation';

  @override
  String get adminTableAddByName => 'Ajouter par nom';

  @override
  String get adminTableSelectMember => 'Sélectionner un membre';

  @override
  String get adminTableSearch => 'Rechercher...';

  @override
  String get adminTablePlayerName => 'Nom du joueur';

  @override
  String adminTableWaitingForApproval(int seatNumber) {
    return 'En attente d\'approbation pour le siège #$seatNumber';
  }

  @override
  String get adminTableReject => 'Rejeter';

  @override
  String get adminTableApprove => 'Approuver';

  @override
  String get adminTableRemove => 'Retirer';

  @override
  String adminTableSeatNumber(int seatNumber) {
    return 'Siège #$seatNumber';
  }

  @override
  String get adminTableNoEmptySeats => 'Aucun siège libre disponible';

  @override
  String adminTableSeatPlayerName(String name) {
    return 'Asseoir $name';
  }

  @override
  String get adminTableSelectSeat => 'Sélectionner un siège :';

  @override
  String adminTablePlayerSeated(String name) {
    return '$name assis';
  }

  @override
  String adminTableAlreadySeated(String name, String location) {
    return '$name est déjà assis à $location';
  }

  @override
  String adminTablePlayerApproved(String name) {
    return '$name approuvé';
  }

  @override
  String get adminTablePlayerRejected => 'Joueur rejeté';

  @override
  String get adminTablePlayerRemoved => 'Joueur retiré';

  @override
  String adminTableWaitlistInCount(int count) {
    return '$count en liste d\'attente';
  }

  @override
  String adminTableWaitlistNextName(String name) {
    return 'Suivant : $name';
  }

  @override
  String adminTableNotifiedName(String name) {
    return '$name notifié';
  }

  @override
  String clubCashGameStakes(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String clubCashGameTablesSummary(int count, int occupied, int open) {
    return '$count tables · $occupied assis · $open libres';
  }

  @override
  String clubCashGameTableNumber(int number) {
    return 'Table $number';
  }

  @override
  String get clubCashGameNoTables => 'Aucune table dans ce groupe';

  @override
  String clubCashGameFailedToLoad(String error) {
    return 'Échec du chargement des tables : $error';
  }

  @override
  String get clubCashGameAlreadySeated => 'Vous êtes déjà assis à une table';

  @override
  String get clubCashGameSeatAvailable =>
      'Un siège est disponible pour vous, approchez-vous de l\'inscription';

  @override
  String clubCashGameJoinedWaitlist(int position) {
    return 'Inscrit sur la liste d\'attente en position #$position';
  }

  @override
  String clubCashGameJoinFailed(String error) {
    return 'Échec de l\'inscription à la liste d\'attente : $error';
  }

  @override
  String get clubCashGameLeftWaitlist => 'Vous avez quitté la liste d\'attente';

  @override
  String clubCashGameLeaveFailed(String error) {
    return 'Échec du retrait de la liste d\'attente : $error';
  }

  @override
  String get clubCashGameViewWaitlist => 'Voir la liste d\'attente';

  @override
  String get clubCashGameInWaitlist => 'En liste d\'attente';

  @override
  String clubCashGameInWaitlistPosition(int position) {
    return 'En liste d\'attente · #$position';
  }

  @override
  String get clubCashGameJoinWaitlist => 'Rejoindre la liste d\'attente';

  @override
  String get clubCashGameLeaveWaitlistConfirm =>
      'Quitter la liste d\'attente ?';

  @override
  String get clubCashGameLosePosition =>
      'Vous perdrez votre position actuelle.';

  @override
  String get clubCashGameKeep => 'Garder';

  @override
  String get clubCashGameLeave => 'Quitter';

  @override
  String clubCashGameRefreshFailed(String error) {
    return 'Impossible de rafraîchir les tables : $error';
  }

  @override
  String get clubCashGameWaitlistTitle => 'Liste d\'attente';

  @override
  String clubCashGameNotified(String name) {
    return '$name a été notifié';
  }

  @override
  String clubCashGameNotifyFailed(String error) {
    return 'Échec de la notification : $error';
  }

  @override
  String get clubCashGameCouldNotLoad =>
      'Impossible de charger la liste d\'attente';

  @override
  String get clubCashGameNoOneOnWaitlist => 'Personne sur la liste d\'attente';

  @override
  String get clubCashGamePlayer => 'Joueur';

  @override
  String clubCashGameNotifiedStatus(String time) {
    return 'Notifié • $time';
  }

  @override
  String clubCashGameJoinedTime(String time) {
    return 'Inscrit $time';
  }

  @override
  String get clubCashGameJustNow => 'à l\'instant';

  @override
  String clubCashGameMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String clubCashGameHoursAgo(int count) {
    return 'il y a ${count}h';
  }

  @override
  String clubCashGameDaysAgo(int count) {
    return 'il y a ${count}j';
  }

  @override
  String get clubCashGameAddTable => 'Ajouter une table';

  @override
  String get clubCashGameNewTableName =>
      'Nom de la nouvelle table (facultatif)';

  @override
  String get clubCashGameAdd => 'Ajouter';

  @override
  String clubCashGameAddedToGroup(String tableName) {
    return '$tableName ajoutée au groupe';
  }

  @override
  String clubCashGameAddFailed(String error) {
    return 'Échec de l\'ajout de la table : $error';
  }

  @override
  String clubCashGameAttachFailed(String error) {
    return 'Échec de l\'attachement de la table : $error';
  }

  @override
  String get clubCashGameAvailableTables => 'Tables disponibles';

  @override
  String get clubCashGameInUseByOther => 'Utilisées par d\'autres événements';

  @override
  String get clubCashGameNoOtherTables =>
      'Aucune autre table dans ce club pour le moment';

  @override
  String clubCashGameInUseBy(String eventName) {
    return 'Utilisée par $eventName';
  }

  @override
  String clubCashGameSeats(int count) {
    return 'Sièges $count';
  }

  @override
  String memberEventTablesSummary(int count, int occupied, int open) {
    return '$count tables • $occupied assis • $open libres';
  }

  @override
  String memberEventJoinedWaitlist(int position) {
    return 'Inscrit sur la liste d\'attente en position #$position';
  }

  @override
  String memberEventJoinFailed(String error) {
    return 'Échec de l\'inscription à la liste d\'attente : $error';
  }

  @override
  String get memberEventLeftWaitlist => 'Vous avez quitté la liste d\'attente';

  @override
  String memberEventLeaveFailed(String error) {
    return 'Échec du retrait de la liste d\'attente : $error';
  }

  @override
  String memberEventWaitlistPosition(int position) {
    return 'Position #$position dans la liste d\'attente';
  }

  @override
  String memberEventTotalWaiting(int count) {
    return '$count en attente au total';
  }

  @override
  String get memberEventLeaveWaitlist => 'Quitter la liste d\'attente';

  @override
  String memberEventJoinWaitlistWithCount(int count) {
    return 'Rejoindre la liste d\'attente ($count en attente)';
  }

  @override
  String get memberEventJoinWaitlist => 'Rejoindre la liste d\'attente';

  @override
  String get memberEventAllTablesFull => 'Toutes les tables sont pleines';

  @override
  String get dealerHomeTitle => 'Mode Dealer';

  @override
  String get dealerHomeNoClubs => 'Aucun club trouvé';

  @override
  String get dealerHomeNoClubsOwnerHint =>
      'Créez votre premier club pour commencer.';

  @override
  String get dealerHomeNoClubsMemberHint =>
      'Vous n\'êtes membre d\'aucun club pour le moment.\nDemandez à un propriétaire de club de vous inviter.';

  @override
  String get dealerHomeCreateClub => 'Créer un club';

  @override
  String get dealerHomeDealer => 'Dealer';

  @override
  String dealerHomeClubCount(int count) {
    return '$count clubs';
  }

  @override
  String get dealerHomeActiveSessions => 'Sessions actives';

  @override
  String get dealerHomeClubs => 'Clubs';

  @override
  String get dealerHomeTables => 'Tables';

  @override
  String get dealerHomeAddTable => 'Ajouter une table';

  @override
  String get dealerHomeTableNameLabel => 'Nom de la table';

  @override
  String get dealerHomeTableNameHint => 'ex. Table 1, Table principale';

  @override
  String dealerHomeTableAdded(String name, String clubName) {
    return 'Table \"$name\" ajoutée à $clubName !';
  }

  @override
  String dealerHomeAddTableFailed(String error) {
    return 'Échec de l\'ajout de la table : $error';
  }

  @override
  String get dealerHomeClubName => 'Nom du club';

  @override
  String get dealerHomeCreate => 'Créer';

  @override
  String dealerHomeClubCreated(String name) {
    return 'Club \"$name\" créé avec succès !';
  }

  @override
  String dealerHomeClubCreateFailed(String error) {
    return 'Échec de la création du club : $error';
  }

  @override
  String get dealerHomeNoTables => 'Aucune table dans ce club';

  @override
  String dealerHomeActiveHand(int number) {
    return 'Active — Main #$number';
  }

  @override
  String get dealerHomeInactive => 'Inactive';

  @override
  String get dealerHomeResume => 'Reprendre';

  @override
  String get dealerHomeStart => 'Démarrer';

  @override
  String get dealerHomeSessionSettings => 'Paramètres de session';

  @override
  String get dealerHomeSmallBlind => 'Small Blind';

  @override
  String get dealerHomeBigBlind => 'Big Blind';

  @override
  String get dealerHomeBBAnte => 'BB Ante';

  @override
  String get dealerHomeGameType => 'Type de jeu';

  @override
  String get dealerHomeCash => 'Cash';

  @override
  String get dealerHomeTournament => 'Tournament';

  @override
  String get dealerHomeButtonPosition => 'Position du bouton';

  @override
  String get dealerHomeStartSession => 'Démarrer la session';

  @override
  String get dealerHomeCouldNotFind => 'Club ou table introuvable';

  @override
  String dealerHomeStartFailed(String error) {
    return 'Échec du démarrage de la session : $error';
  }

  @override
  String dealerHomeErrorLoading(String error) {
    return 'Erreur de chargement des données : $error';
  }

  @override
  String dealerHomeTableCount(int count) {
    return '$count tables';
  }

  @override
  String dealerTableFailedStartHand(String error) {
    return 'Échec du démarrage de la main : $error';
  }

  @override
  String dealerTableChopSummary(String winners, String amount) {
    return 'Chop : $winners se partagent $amount';
  }

  @override
  String dealerTableWins(String name, String amount) {
    return '$name gagne $amount';
  }

  @override
  String dealerTablePotChopped(String names) {
    return 'Pot partagé entre $names';
  }

  @override
  String dealerTableFailedCompleteHand(String error) {
    return 'Échec de la finalisation de la main : $error';
  }

  @override
  String dealerTablePlayerBusted(String name) {
    return '$name éliminé !';
  }

  @override
  String dealerTableNoChipsRemaining(int seatNumber, String amount) {
    return 'Le siège $seatNumber n\'a plus de jetons.\nMontant du rebuy : $amount';
  }

  @override
  String get dealerTableRemovePlayer => 'Retirer le joueur';

  @override
  String get dealerTableRebuy => 'Rebuy';

  @override
  String dealerTableRebuysFor(String name, String amount) {
    return '$name fait un rebuy de $amount';
  }

  @override
  String dealerTableFinishesIn(String name, String position) {
    return '$name finit en ${position}e place';
  }

  @override
  String get dealerTableEndSessionTitle => 'Terminer la session ?';

  @override
  String get dealerTableEndSessionBody =>
      'Êtes-vous sûr de vouloir terminer cette session ?';

  @override
  String get dealerTableEnd => 'Terminer';

  @override
  String get dealerTableDealerChange => 'Changement de Dealer';

  @override
  String get dealerTableDealerChangeBody =>
      'La session sera mise en pause et un autre dealer pourra scanner le QR code de la table pour reprendre là où vous vous êtes arrêté.';

  @override
  String get dealerTableDealerChangePreserve =>
      'Tous les joueurs, blinds et l\'état du jeu seront préservés.';

  @override
  String get dealerTableDealerChangeResume =>
      'Vous pouvez également reprendre cette session vous-même plus tard.';

  @override
  String get dealerTableHandOff => 'Passer la main';

  @override
  String get dealerTableSessionPaused =>
      'Session en pause. Un autre dealer peut maintenant prendre le relais.';

  @override
  String dealerTablePauseFailed(String error) {
    return 'Échec de la mise en pause de la session : $error';
  }

  @override
  String get dealerTableEventCancelled => 'Événement annulé';

  @override
  String get dealerTableEventFinished => 'Événement terminé';

  @override
  String get dealerTableEventCancelledBody =>
      'L\'administrateur du club a annulé cet événement. Toutes les sessions ont été sauvegardées.';

  @override
  String get dealerTableEventFinishedBody =>
      'L\'administrateur du club a terminé cet événement. Toutes les sessions ont été sauvegardées.';

  @override
  String get dealerTableSessionEnded => 'Session terminée';

  @override
  String get dealerTableSessionEndedBody =>
      'Cette session a été terminée. Toutes les données ont été sauvegardées.';

  @override
  String get dealerTableLeaveTitle => 'Quitter la table de dealer ?';

  @override
  String get dealerTableLeaveActiveHand =>
      'Une main est en cours. Quitter maintenant pourrait perturber le logging.';

  @override
  String get dealerTableLeaveInactive =>
      'La session reste active. Vous pouvez revenir à tout moment.';

  @override
  String dealerTableAutoCorrection(String detected, String corrected) {
    return 'Auto-correction \"$detected\" → \"$corrected\"';
  }

  @override
  String dealerTableApprovePlayer(String name) {
    return 'Approuver $name ?';
  }

  @override
  String get dealerTableStartingChipStack => 'Stack de jetons de départ';

  @override
  String dealerTablePlayerRejected(String name) {
    return '$name rejeté';
  }

  @override
  String dealerTableRejectFailed(String error) {
    return 'Échec du rejet : $error';
  }

  @override
  String dealerTablePlayerJoined(String name, String amount) {
    return '$name a rejoint avec $amount';
  }

  @override
  String dealerTableApproveFailed(String error) {
    return 'Échec de l\'approbation : $error';
  }

  @override
  String get dealerTableChipStack => 'Stack de jetons';

  @override
  String get dealerTableSave => 'Enregistrer';

  @override
  String get liveSessionHand => 'MAIN';

  @override
  String get liveSessionPot => 'POT';

  @override
  String get liveSessionStatus => 'STATUT';

  @override
  String get liveSessionLive => 'EN DIRECT';

  @override
  String get liveSessionWaiting => 'EN ATTENTE';

  @override
  String liveSessionWinnerSummary(String winner, String amount) {
    return '$winner gagne \$$amount';
  }

  @override
  String get liveSessionSessionEnded => 'Session terminée';

  @override
  String get liveSessionSessionEndedBody =>
      'Le dealer a terminé cette session.';

  @override
  String get liveSessionLeaveTitle => 'Quitter la table ?';

  @override
  String get liveSessionLeaveBody =>
      'Êtes-vous sûr de vouloir quitter cette table ?';

  @override
  String get liveSessionLeave => 'Quitter';

  @override
  String liveSessionLeaveFailed(String error) {
    return 'Échec du départ : $error';
  }

  @override
  String get liveSessionLeaveTooltip => 'Quitter la table';

  @override
  String liveSessionSeat(int number) {
    return 'Siège $number';
  }

  @override
  String get liveSessionYourSeat => 'Votre siège';

  @override
  String liveSessionStack(String amount) {
    return 'Stack : $amount';
  }

  @override
  String get liveSessionWaitingForDealer => 'En attente du dealer...';

  @override
  String get liveSessionOffline => 'HORS LIGNE';

  @override
  String get liveSessionRecentActions => 'Actions récentes';

  @override
  String get liveSessionWaitingForAction => 'En attente d\'une action...';

  @override
  String get liveSessionD => 'D';

  @override
  String get qrScanTitle => 'Scanner le QR de la table';

  @override
  String get qrScanInvalidCode =>
      'QR code invalide. Veuillez scanner un QR code de table de poker valide.';

  @override
  String qrScanError(String error) {
    return 'Erreur lors du traitement du QR code : $error';
  }

  @override
  String get qrScanInstructions =>
      'Pointez votre caméra vers le QR code de la table pour rejoindre';

  @override
  String get clubRequestsTitle => 'Demandes de club';

  @override
  String get clubRequestsAll => 'Toutes';

  @override
  String get clubRequestsPending => 'En attente';

  @override
  String get clubRequestsApproved => 'Approuvées';

  @override
  String get clubRequestsRejected => 'Rejetées';

  @override
  String get clubRequestsApproveTitle => 'Approuver la demande';

  @override
  String clubRequestsApproveBody(String name) {
    return 'Êtes-vous sûr de vouloir approuver \"$name\" ? Cela créera un nouveau club et vous ajoutera en tant qu\'administrateur.';
  }

  @override
  String get clubRequestsRejectTitle => 'Rejeter la demande';

  @override
  String clubRequestsRejectBody(String name) {
    return 'Veuillez fournir une raison pour le rejet de \"$name\" :';
  }

  @override
  String get clubRequestsRejectHint => 'Raison du rejet...';

  @override
  String get clubRequestsApproveButton => 'Approuver';

  @override
  String get clubRequestsRejectButton => 'Rejeter';

  @override
  String clubRequestsApproved2(String name) {
    return '\"$name\" a été approuvé !';
  }

  @override
  String clubRequestsRejected2(String name) {
    return '\"$name\" a été rejeté.';
  }

  @override
  String get clubRequestsNoRequests => 'Aucune demande';

  @override
  String get clubRequestsPendingBadge => 'EN ATTENTE';

  @override
  String get clubRequestsApprovedBadge => 'APPROUVÉ';

  @override
  String get clubRequestsRejectedBadge => 'REJETÉ';

  @override
  String get clubRequestsAddress => 'Adresse';

  @override
  String get clubRequestsPhone => 'Téléphone';

  @override
  String get clubRequestsAdminEmail => 'E-mail de l\'administrateur';

  @override
  String get clubRequestsRequestedBy => 'Demandé par';

  @override
  String get clubRequestsRequesterEmail => 'E-mail du demandeur';

  @override
  String get clubRequestsRequestedAt => 'Demandé le';

  @override
  String get clubRequestsReviewedAt => 'Examiné le';

  @override
  String get clubRequestsRejectionReason => 'Raison du rejet :';

  @override
  String get supportRequestsTitle => 'Demandes de support';

  @override
  String get supportRequestsAll => 'Toutes';

  @override
  String get supportRequestsPending => 'En attente';

  @override
  String get supportRequestsClosed => 'Fermées';

  @override
  String get supportRequestsResolveTitle => 'Résoudre la demande';

  @override
  String get supportRequestsResolveBody =>
      'Réponse facultative à l\'utilisateur :';

  @override
  String get supportRequestsResponseHint => 'Réponse (facultatif)...';

  @override
  String get supportRequestsResolve => 'Résoudre';

  @override
  String get supportRequestsResolved => 'Demande résolue';

  @override
  String get supportRequestsRejectTitle => 'Rejeter la demande';

  @override
  String get supportRequestsRejectBody => 'Raison du rejet :';

  @override
  String get supportRequestsRejectHint => 'Raison...';

  @override
  String get supportRequestsReject => 'Rejeter';

  @override
  String get supportRequestsRejected => 'Demande rejetée';

  @override
  String get supportRequestsNoRequests => 'Aucune demande';

  @override
  String get supportRequestsPendingBadge => 'EN ATTENTE';

  @override
  String get supportRequestsResolvedBadge => 'RÉSOLU';

  @override
  String get supportRequestsRejectedBadge => 'REJETÉ';

  @override
  String get supportRequestsCategory => 'Catégorie';

  @override
  String get supportRequestsUser => 'Utilisateur';

  @override
  String get supportRequestsEmail => 'E-mail';

  @override
  String get supportRequestsSubmitted => 'Soumis';

  @override
  String get supportRequestsDescription => 'Description';

  @override
  String get supportRequestsAdminResponse => 'Réponse de l\'administrateur';

  @override
  String get supportRequestsBugReport => 'Rapport de bug';

  @override
  String get supportRequestsFeatureRequest => 'Demande de fonctionnalité';

  @override
  String get supportRequestsAccountIssue => 'Problème de compte';

  @override
  String get debugHandViewerTitle => 'Visualiseur de main (débogage)';

  @override
  String get debugHandViewerSessionName => 'Nom de la session';

  @override
  String get debugHandViewerHandNumbers =>
      'Numéros de main (séparés par des virgules, ex. 27,28)';

  @override
  String get debugHandViewerFetchData => 'Récupérer les données';

  @override
  String get debugHandViewerCopied => 'Copié dans le presse-papiers';

  @override
  String get debugHandViewerNoData =>
      'Pas encore de données. Entrez le nom de la session et cliquez sur Récupérer les données.';

  @override
  String get navDrawerSettings => 'Paramètres';

  @override
  String get navDrawerRegisterClub => 'Enregistrer un club';

  @override
  String get navDrawerHelpSupport => 'Aide et support';

  @override
  String get navDrawerLogOut => 'Se déconnecter';

  @override
  String get navDrawerUpgrade => 'Mettre à niveau';

  @override
  String get navDrawerUserFallback => 'Utilisateur';

  @override
  String get navDrawerStatistics => 'Statistiques';

  @override
  String get navDrawerEvents => 'Événements';

  @override
  String get navDrawerBankroll => 'Bankroll';

  @override
  String get navDrawerClubs => 'Clubs';

  @override
  String get navDrawerNoClubsYet => 'Pas encore de clubs';

  @override
  String navDrawerMemberCount(int count) {
    return '$count membres';
  }

  @override
  String get navDrawerRoleAdmin => 'Admin';

  @override
  String get navDrawerRoleDealer => 'Dealer';

  @override
  String get navDrawerRoleMember => 'Membre';

  @override
  String get navDrawerVersion => 'Version 1.0.0';

  @override
  String get navDrawerLastLoginToday => 'Dernière connexion : Aujourd\'hui';

  @override
  String get navDrawerNoEarningsTitle => 'Pas encore de données de gains';

  @override
  String get navDrawerNoEarningsBody =>
      'Ajoutez d\'abord des résultats de session pour voir votre graphique de gains. Vous pouvez ajouter des résultats depuis la page Profil.';

  @override
  String get navDrawerSignOutTitle => 'Déconnexion';

  @override
  String get navDrawerSignOutMessage =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get navDrawerSignOut => 'Se déconnecter';

  @override
  String get multiPotMainPot => 'Main Pot';

  @override
  String multiPotSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String multiPotPlayerFallback(String id) {
    return 'Joueur $id';
  }

  @override
  String get multiPotMainPotWinner => 'gagnant du Main Pot';

  @override
  String get multiPotEligibleFromPrevious => 'éligible du pot précédent';

  @override
  String multiPotAutoAwarded(String name, String reason) {
    return 'Attribué automatiquement à $name ($reason)';
  }

  @override
  String get multiPotChoppedPot => 'Chopped Pot';

  @override
  String get multiPotSingleWinner => 'Gagnant unique';

  @override
  String get multiPotSelectAllWinners => 'Sélectionnez tous les gagnants :';

  @override
  String get multiPotSelectTheWinner => 'Sélectionnez le gagnant :';

  @override
  String get multiPotSelectWinnersTitle => 'Sélectionner les gagnants';

  @override
  String get multiPotMultiplePots =>
      'Plusieurs pots — sélectionnez le gagnant de chaque pot';

  @override
  String get winnerSelectionWhoChopped => 'Qui a choppé ce pot ?';

  @override
  String get winnerSelectionWhoWon => 'Qui a gagné cette main ?';

  @override
  String get winnerSelectionChoppedPot => 'Chopped Pot';

  @override
  String get winnerSelectionIndividualShares => 'Parts individuelles :';

  @override
  String get winnerSelectionSelectAllWinners =>
      'Sélectionnez tous les gagnants :';

  @override
  String get winnerSelectionTapTheWinner => 'Touchez le gagnant :';

  @override
  String get winnerSelectionLongPressHint => 'Appui long pour Chopped Pot';

  @override
  String get winnerSelectionConfirmChop => 'Confirmer le Chop';

  @override
  String get winnerSelectionConfirmWinner => 'Confirmer le gagnant';

  @override
  String get winnerSelectionBackToSingle => 'Retour au gagnant unique';

  @override
  String get boardCardsCards => 'Cartes';

  @override
  String get boardCardsCard => 'Carte';

  @override
  String get allInBoardTitle => 'Cartes du board All-in';

  @override
  String get raiseSnapReleaseToType => 'Relâcher au min pour saisir';

  @override
  String get slidingNotificationHeader => 'NOTIFICATION';

  @override
  String get eventSuccessTitle =>
      'Super ! Votre événement est maintenant au calendrier.';

  @override
  String get eventSuccessSubtitle =>
      'Vous pouvez le modifier ou le supprimer à tout moment';

  @override
  String get eventSuccessGoToCalendar => 'Aller au calendrier';

  @override
  String get eventSuccessAddAnother => 'Ajouter un autre événement';

  @override
  String get stackChartNoData => 'Pas encore de données';

  @override
  String get stackChartStart => 'Début';

  @override
  String get stackChartRebuy => 'Rebuy';

  @override
  String get stackChartEnd => 'Fin';

  @override
  String get stackChartTitle => 'Graphique du Stack';

  @override
  String get stackChartAvgGrowth => 'Croissance moy.';

  @override
  String get stackChartDuration => 'Durée';

  @override
  String get stackChartProfitLoss => 'P/L';

  @override
  String get actionGridSelectAction => 'Sélectionner l\'action';

  @override
  String get pokerTablePlayerFallback => 'Joueur';

  @override
  String get loadingDefault => 'Chargement...';

  @override
  String get forgotPasswordFailedSendCode =>
      'Échec de l\'envoi du code. Veuillez réessayer.';

  @override
  String get forgotPasswordNewCodeSent => 'Nouveau code envoyé à votre e-mail.';

  @override
  String get forgotPasswordFailedResend => 'Échec du renvoi du code.';

  @override
  String get forgotPasswordEnterFullCode =>
      'Veuillez entrer le code à 6 chiffres complet.';

  @override
  String get forgotPasswordInvalidCode =>
      'Code invalide ou expiré. Veuillez réessayer.';

  @override
  String get forgotPasswordResetSuccess =>
      'Mot de passe réinitialisé avec succès ! Veuillez vous connecter.';

  @override
  String get forgotPasswordResetTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotPasswordResetSubtitle =>
      'Entrez votre e-mail pour recevoir un code de vérification';

  @override
  String get forgotPasswordCheckEmail => 'Vérifiez votre e-mail';

  @override
  String get forgotPasswordSetNewPassword => 'Définir un nouveau mot de passe';

  @override
  String get forgotPasswordSetNewSubtitle =>
      'Choisissez un mot de passe fort pour votre compte';

  @override
  String get forgotPasswordEmail => 'E-mail';

  @override
  String get forgotPasswordEnterEmail => 'Veuillez entrer votre e-mail';

  @override
  String get forgotPasswordValidEmail => 'Veuillez entrer un e-mail valide';

  @override
  String get forgotPasswordSendCode => 'Envoyer le code';

  @override
  String get forgotPasswordVerifyCode => 'Vérifier le code';

  @override
  String get forgotPasswordResendCode => 'Renvoyer le code';

  @override
  String forgotPasswordResendIn(String time) {
    return 'Renvoyer le code dans $time';
  }

  @override
  String get forgotPasswordNewPassword => 'Nouveau mot de passe';

  @override
  String get forgotPasswordEnterPassword => 'Veuillez entrer un mot de passe';

  @override
  String get forgotPasswordMinLength =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get forgotPasswordConfirm => 'Confirmer le mot de passe';

  @override
  String get forgotPasswordConfirmRequired =>
      'Veuillez confirmer votre mot de passe';

  @override
  String get forgotPasswordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get forgotPasswordResetButton => 'Réinitialiser le mot de passe';

  @override
  String get onboardingTrackTitle => 'SUIVEZ CHAQUE\nMAIN';

  @override
  String get onboardingTrackSubtitle =>
      'Enregistrez les actions, les cartes du board et les résultats de chaque main — en direct ou après la session.';

  @override
  String get onboardingKnowTitle => 'CONNAISSEZ\nVOTRE JEU';

  @override
  String get onboardingKnowSubtitle =>
      'VPIP, PFR, 3-Bet, C-Bet et plus — voyez vos stats évoluer en temps réel.';

  @override
  String get onboardingClubsTitle => 'JOUEZ EN\nCLUB';

  @override
  String get onboardingClubsSubtitle =>
      'Rejoignez des événements en direct, consultez les classements et suivez vos adversaires entre les sessions.';

  @override
  String get dealerTableEnterStartingStack => 'Entrer le Stack de départ';

  @override
  String get dealerTableNoPendingRequests =>
      'Aucune demande d\'inscription en attente';

  @override
  String get dealerTablePendingJoinRequests =>
      'Demandes d\'inscription en attente';

  @override
  String get dealerTableUnknown => 'Inconnu';

  @override
  String dealerTableSeatNumber(int number) {
    return 'Siège $number';
  }

  @override
  String get dealerTableReview => 'Revoir';

  @override
  String get dealerTableSmallBlind => 'Small Blind';

  @override
  String get dealerTableBigBlind => 'Big Blind';

  @override
  String get dealerTableNewBlindsNote =>
      'Les nouvelles blinds s\'appliqueront à partir de la prochaine main.';

  @override
  String get dealerTableSmallMustBeLess =>
      'La Small Blind doit être inférieure à la Big Blind';

  @override
  String get dealerTableBlindsMustBePositive =>
      'Les blinds doivent être supérieures à 0';

  @override
  String dealerTableBlindsUpdated(String sb, String bb) {
    return 'Blinds mises à jour : $sb/$bb';
  }

  @override
  String dealerTableFailedUpdateBlinds(String error) {
    return 'Échec de la mise à jour des blinds : $error';
  }

  @override
  String dealerTableFailedMoveButton(String error) {
    return 'Échec du déplacement du bouton : $error';
  }

  @override
  String get dealerTablePending => 'EN ATTENTE';

  @override
  String get dealerTableConnectionLost => 'Connexion perdue';

  @override
  String get dealerTableReconnecting => 'Tentative de reconnexion...';

  @override
  String get dealerTableReconnect => 'Reconnecter';

  @override
  String get dealerTableResetHandTitle => 'Réinitialiser la main ?';

  @override
  String get dealerTableResetHandBody =>
      'Toutes les actions ont été annulées. Voulez-vous commencer une nouvelle main ?';

  @override
  String get dealerTableKeepCurrent => 'Garder l\'actuel';

  @override
  String get dealerTableNewHand => 'Nouvelle main';

  @override
  String get dealerTableHandReset =>
      'Main réinitialisée — prêt pour une nouvelle main';

  @override
  String dealerTableAddPlayerToSeat(int number) {
    return 'Ajouter un joueur au siège $number';
  }

  @override
  String get dealerTableSearchUser => 'Rechercher un utilisateur';

  @override
  String get dealerTableManualEntry => 'Saisie manuelle';

  @override
  String get dealerTableSearchByName => 'Rechercher par nom';

  @override
  String get dealerTableTypeToSearch =>
      'Tapez pour rechercher des utilisateurs...';

  @override
  String get dealerTableNoUsersFound =>
      'Aucun utilisateur trouvé. Essayez la saisie manuelle.';

  @override
  String get dealerTablePlayerNameLabel => 'Nom du joueur';

  @override
  String get dealerTableEnterPlayerName => 'Entrer le nom du joueur';

  @override
  String get dealerTableAddPlayer => 'Ajouter un joueur';

  @override
  String get dealerTableEndSession => 'Terminer la session';

  @override
  String dealerTableUpdatedStack(String name, String amount) {
    return 'Stack de $name mis à jour à $amount';
  }

  @override
  String dealerTableFailedUpdateStack(String error) {
    return 'Échec de la mise à jour du Stack : $error';
  }

  @override
  String dealerTableSittingAtSeat(int number) {
    return 'Vous jouez maintenant au siège $number';
  }

  @override
  String dealerTableFailedSitAt(String error) {
    return 'Échec de la prise de place : $error';
  }

  @override
  String dealerTableFailedAddPlayer(String error) {
    return 'Échec de l\'ajout du joueur : $error';
  }

  @override
  String dealerTableFailedRemovePlayer(String error) {
    return 'Échec de la suppression du joueur : $error';
  }

  @override
  String get eventDetailEventType => 'Type d\'événement';

  @override
  String get eventDetailSeated => 'Assis';

  @override
  String get eventDetailAreYouGoing => 'VOUS Y ALLEZ ?';

  @override
  String get eventDetailAddedToCalendarBtn => 'Ajouté au calendrier';

  @override
  String get eventDetailAddToCalendarBtn => 'Ajouter au calendrier';

  @override
  String get eventDetailWhosGoing => 'Qui vient';

  @override
  String get eventDetailSeeAll => 'Voir tout';

  @override
  String get eventDetailStartDealing => 'Commencer à distribuer';

  @override
  String get eventDetailViewLiveRankings => 'Voir le classement en direct';

  @override
  String get eventDetailNotSeatedAtTable =>
      'Vous n\'êtes actuellement assis à aucune table';

  @override
  String get eventDetailNotSeatedInEvent =>
      'Vous n\'êtes pas assis dans cet événement';

  @override
  String eventDetailErrorFindingSeat(String error) {
    return 'Erreur lors de la recherche de votre siège : $error';
  }

  @override
  String get eventDetailReturnToSeat => 'Retourner à mon siège';

  @override
  String get eventDetailViewFinalStandings => 'Voir le classement final';

  @override
  String get eventDetailManageTables => 'Gérer les tables';

  @override
  String get eventDetailManageTable => 'Gérer la table';

  @override
  String get eventDetailSeeAvailability => 'Voir la disponibilité';

  @override
  String get eventDetailYoureSeated => 'Vous êtes assis';

  @override
  String get eventDetailNoTablesAssigned =>
      'Aucune table assignée à cet événement';

  @override
  String get eventDetailStartEvent => 'Démarrer l\'événement';

  @override
  String get eventDetailFinish => 'Terminer';

  @override
  String eventDetailFailedFinishCancel(String action, String error) {
    return 'Échec de $action l\'événement : $error';
  }

  @override
  String homeTableSeatInfo(String table, String seat) {
    return 'Table $table, Siège #$seat';
  }

  @override
  String get homeRequestResolved => 'Demande résolue';

  @override
  String get homeRequestClosed => 'Demande fermée';

  @override
  String get homeResponse => 'Réponse';

  @override
  String homeErrorGeneric(String error) {
    return 'Erreur : $error';
  }

  @override
  String homeErrorLoadingEvent(String error) {
    return 'Erreur lors du chargement de l\'événement : $error';
  }

  @override
  String homeFailedLoadEvent(String error) {
    return 'Échec du chargement de l\'événement : $error';
  }

  @override
  String homeFailedUpdateEvent(String error) {
    return 'Échec de la mise à jour de l\'événement : $error';
  }

  @override
  String homeErrorDeletingEvent(String error) {
    return 'Erreur lors de la suppression de l\'événement : $error';
  }

  @override
  String get homeTournament => 'Tournament';

  @override
  String get homeCashGame => 'Cash Game';

  @override
  String commonErrorGeneric(String error) {
    return 'Erreur : $error';
  }

  @override
  String get commonLeave => 'Quitter';

  @override
  String get commonAccept => 'Accepter';

  @override
  String get commonLoadingHands => 'Chargement des mains...';

  @override
  String sessionHistoryButtonPosition(String position) {
    return 'Position du bouton : $position';
  }

  @override
  String sessionHistoryPlayerCount(String count) {
    return 'Nombre de joueurs : $count';
  }

  @override
  String sessionHistoryStartTime(String time) {
    return 'Heure de début : $time';
  }

  @override
  String get sessionHistoryPreflop => 'Preflop :';

  @override
  String get sessionHistoryFlop => 'Flop :';

  @override
  String get sessionHistoryTurn => 'Turn :';

  @override
  String get sessionHistoryRiver => 'River :';

  @override
  String sessionHistorySyncFailed(String error) {
    return 'Échec de la synchronisation : $error';
  }

  @override
  String sessionHistoryClearFailed(String error) {
    return 'Échec de la suppression des sessions : $error';
  }

  @override
  String get notificationsClubNotFound => 'Club introuvable';

  @override
  String get notificationsAccept => 'Accepter';

  @override
  String get notificationsInvitationAccepted => 'Invitation acceptée';

  @override
  String get notificationsInvitationDeclined => 'Invitation refusée';

  @override
  String get notificationsInvitationDeclinedMsg => 'Invitation refusée';

  @override
  String get notificationsEventNotFound => 'Événement introuvable';

  @override
  String notificationsFailedLoadClub(String error) {
    return 'Échec du chargement du club : $error';
  }

  @override
  String notificationsErrorLoadingEvent(String error) {
    return 'Erreur lors du chargement de l\'événement : $error';
  }

  @override
  String invitationsFailedLoad(String error) {
    return 'Échec du chargement des invitations : $error';
  }

  @override
  String invitationsFailedAccept(String error) {
    return 'Échec de l\'acceptation de l\'invitation : $error';
  }

  @override
  String get invitationsDeclined => 'Invitation refusée';

  @override
  String invitationsFailedDecline(String error) {
    return 'Échec du refus de l\'invitation : $error';
  }

  @override
  String get clubSettingsTableAdded => 'Table ajoutée';

  @override
  String get clubSettingsTableDeleted => 'Table supprimée';

  @override
  String get clubSettingsQrRegenerated => 'Codes QR régénérés';

  @override
  String clubSettingsErrorPdf(String error) {
    return 'Erreur lors de la génération du PDF : $error';
  }

  @override
  String get clubDashboardActiveDealers => 'Dealers actifs';

  @override
  String get clubDashboardPendingInvitations => 'Invitations en attente';

  @override
  String get clubDashboardDealerEmailHint => 'dealer@example.com';

  @override
  String clubDashboardInvitationSent(String email) {
    return 'Invitation envoyée à $email';
  }

  @override
  String clubDashboardFailedSendInvite(String error) {
    return 'Échec de l\'envoi de l\'invitation : $error';
  }

  @override
  String clubDashboardFailedCancelInvite(String error) {
    return 'Échec de l\'annulation de l\'invitation : $error';
  }

  @override
  String eventManagementClubEvents(String name) {
    return 'Événements de $name';
  }

  @override
  String eventManagementFailedUpdate(String error) {
    return 'Échec de la mise à jour de l\'événement : $error';
  }

  @override
  String get profileCash => 'Cash';

  @override
  String get profileTournament => 'Tournament';

  @override
  String get profileDevTools => 'Outils de développement';

  @override
  String get profilePremiumOverride => 'Forcer le Premium';

  @override
  String profileUsingRealStatus(String status) {
    return 'Statut réel utilisé : $status';
  }

  @override
  String profileOverridden(String status) {
    return 'Remplacé : $status';
  }

  @override
  String get profileResetToReal => 'Réinitialiser au statut réel';

  @override
  String get profileVersion => 'Version 1.0';

  @override
  String profileLastLogin(String date) {
    return 'Dernière connexion $date';
  }

  @override
  String pokerHandFailedEndSession(String error) {
    return 'Échec de la fin de session : $error';
  }

  @override
  String pokerHandFailedSaveSession(String error) {
    return 'Échec de la sauvegarde de la session : $error';
  }

  @override
  String pokerHandRebuyAdded(String amount, String stack) {
    return 'Rebuy ajouté : \$$amount (Stack : $stack)';
  }

  @override
  String get pokerHandEndSession => 'Terminer la session';

  @override
  String get pokerHandRebuyAmountDollar => 'Montant du Rebuy (\$)';

  @override
  String get pokerHandRebuyChips => 'Jetons de Rebuy';

  @override
  String seatSetupFailedSave(String error) {
    return 'Échec de la sauvegarde : $error';
  }

  @override
  String get seatSetupSelectYourSeat => 'Veuillez sélectionner votre siège';

  @override
  String get authExpLinkGoogleTitle => 'Lier un compte Google';

  @override
  String get authExpPassword => 'Mot de passe';

  @override
  String get authExpLinkAccount => 'Lier le compte';

  @override
  String get individualSetupSessionNameHint => 'ex. « Poker du vendredi soir »';

  @override
  String get individualSetupCashGame => 'Cash Game';

  @override
  String get individualSetupTournament => 'Tournament';

  @override
  String get individualSetupEnterAmount => 'Entrer le montant';

  @override
  String get individualSetupEnterChipStack => 'Entrer le Stack de jetons';

  @override
  String get individualSetupSmallBlind => 'Small Blind';

  @override
  String get individualSetupBigBlind => 'Big Blind';

  @override
  String get individualSetupEnterValue => 'Entrer la valeur';

  @override
  String get individualHandSetupNameHint => 'ex. « AA vs KK Cooler »';

  @override
  String get individualHandSetupSmallBlind => 'Small Blind';

  @override
  String get individualHandSetupBigBlind => 'Big Blind';

  @override
  String get individualHandSetupPlayers => 'Joueurs';

  @override
  String get individualHandSetupGameType => 'Type de jeu';

  @override
  String get playerSessionYourHoleCards => 'Vos Hole Cards';

  @override
  String get playerSessionSeat => 'SIÈGE';

  @override
  String get playerSessionStack => 'STACK';

  @override
  String get playerSessionPot => 'POT';

  @override
  String get playerSessionNotesHint => 'Ajouter des notes sur cette main...';

  @override
  String get dealerQrScanInvalidCode =>
      'Code QR invalide. Veuillez scanner un code QR de table valide.';

  @override
  String get dealerQrScanWrongClub => 'Cette table appartient à un autre club.';

  @override
  String get dealerQrScanTableNotFound =>
      'Table introuvable. Veuillez scanner un code QR de table valide.';

  @override
  String dealerQrScanError(String error) {
    return 'Erreur lors du traitement du code QR : $error';
  }

  @override
  String dealerQrScanFailedStart(String error) {
    return 'Échec du démarrage de la session : $error';
  }

  @override
  String dealerQrScanTakingOver(String name) {
    return 'Prise en charge depuis $name';
  }

  @override
  String get dealerQrScanHandsPlayed => 'Mains jouées';

  @override
  String get dealerQrScanBlinds => 'Blinds';

  @override
  String get dealerQrScanPlayers => 'Joueurs';

  @override
  String dealerQrScanFailedResume(String error) {
    return 'Échec de la reprise de la session : $error';
  }

  @override
  String get usernameSetupLabel => 'Nom d\'utilisateur';

  @override
  String get stackChartScreenAvgGrowth => 'Croissance moy.';

  @override
  String get stackChartScreenDuration => 'Durée';

  @override
  String get stackChartScreenProfitLoss => 'P/L';

  @override
  String get stackChartScreenStack => 'Stack';

  @override
  String get quickStackSearchHint => 'Rechercher ou ajouter un joueur...';

  @override
  String get sessionHandsLoading => 'Chargement des mains...';

  @override
  String createEventDefaultCashGame(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get createEventDefaultCashGameNoStakes => 'Cash Game';

  @override
  String get eventDashboardTvMode => 'Mode affichage TV';

  @override
  String get tableSelectionTitle => 'Sélectionner la table';

  @override
  String get tableSelectionAdminSubtitle => 'Choisissez une table à gérer';

  @override
  String get tableSelectionMemberSubtitle =>
      'Choisissez une table pour voir la disponibilité';

  @override
  String get tableSelectionNoTables => 'Aucune table disponible';

  @override
  String tableSelectionOpenSeats(int count) {
    return '$count disponible(s)';
  }

  @override
  String tableSelectionSeated(int occupied) {
    return '$occupied/9 assis';
  }

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Fév';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Avr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Juin';

  @override
  String get monthJul => 'Juil';

  @override
  String get monthAug => 'Aoû';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Déc';

  @override
  String get weekdaySun => 'Dim';

  @override
  String get weekdayMon => 'Lun';

  @override
  String get weekdayTue => 'Mar';

  @override
  String get weekdayWed => 'Mer';

  @override
  String get weekdayThu => 'Jeu';

  @override
  String get weekdayFri => 'Ven';

  @override
  String get weekdaySat => 'Sam';

  @override
  String opponentsErrorGeneric(String error) {
    return 'Erreur : $error';
  }

  @override
  String opponentsErrorDeleting(String error) {
    return 'Erreur lors de la suppression de l\'adversaire : $error';
  }

  @override
  String opponentsErrorClearing(String error) {
    return 'Erreur lors de la suppression des adversaires : $error';
  }

  @override
  String get onboardingReadTitle => 'LISEZ LE JEU\nCOMME UN PRO';

  @override
  String get onboardingReadSubtitle =>
      'Créez un compte pour commencer à suivre votre parcours poker.';

  @override
  String get onboardingCreateAccount => 'Créer un compte';

  @override
  String get onboardingLogIn => 'Se connecter';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingFinalTable => 'Final Table';

  @override
  String get authExpSignUpTitle => 'Inscription';

  @override
  String get authExpLogInTitle => 'Connectez-vous à votre compte';

  @override
  String get authExpSignUpSubtitle => 'Créez un compte pour continuer';

  @override
  String get authExpLogInSubtitle =>
      'Entrez votre email et mot de passe pour vous connecter';

  @override
  String get authExpName => 'Nom';

  @override
  String get authExpEmail => 'Email';

  @override
  String get authExpEnterName => 'Entrez votre nom';

  @override
  String get authExpNameMinLength =>
      'Le nom doit contenir au moins 2 caractères';

  @override
  String get authExpEnterEmail => 'Entrez votre email';

  @override
  String get authExpValidEmail => 'Entrez un email valide';

  @override
  String get authExpEnterPassword => 'Entrez votre mot de passe';

  @override
  String get authExpPasswordMinLength =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get authExpBySigningUp => 'En vous inscrivant, vous acceptez les ';

  @override
  String get authExpTermsOfService => 'Conditions d\'utilisation';

  @override
  String get authExpAnd => '\net la ';

  @override
  String get authExpPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get authExpCreateAccount => 'Créer un compte';

  @override
  String get authExpAlreadyHaveAccount => 'Vous avez déjà un compte ? ';

  @override
  String get authExpSignIn => 'Se connecter';

  @override
  String get authExpForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authExpDontHaveAccount => 'Pas encore de compte ? ';

  @override
  String get authExpSignUp => 'S\'inscrire';

  @override
  String get authExpOr => 'ou';

  @override
  String get authExpContinueGoogle => 'Continuer avec Google';

  @override
  String authExpLinkGoogleMessage(String email) {
    return 'Un compte avec $email existe déjà. Entrez votre mot de passe pour lier votre compte Google.';
  }

  @override
  String forgotPasswordCodeSubtitle(String email) {
    return 'Entrez le code à 6 chiffres envoyé à $email';
  }

  @override
  String get usernameSetupChangeTitle => 'Changez votre nom d\'utilisateur';

  @override
  String get usernameSetupChooseTitle => 'Choisissez votre nom d\'utilisateur';

  @override
  String get usernameSetupSubtitle =>
      'C\'est ainsi que les autres joueurs vous connaîtront à la table';

  @override
  String get usernameSetupRequired => 'Le nom d\'utilisateur est requis';

  @override
  String get usernameSetupCheckingAvailability =>
      'Vérification de la disponibilité…';

  @override
  String get usernameSetupAvailable => 'Disponible !';

  @override
  String get usernameSetupAlreadyTaken => 'Déjà pris';

  @override
  String get usernameSetupCurrentUsername =>
      'C\'est votre nom d\'utilisateur actuel';

  @override
  String get usernameSetupCouldNotCheck =>
      'Impossible de vérifier la disponibilité';

  @override
  String get usernameSetupJustTaken =>
      'Ce nom vient d\'être pris. Essayez-en un autre.';

  @override
  String get usernameSetupRulesHint =>
      '3–20 caractères · lettres, chiffres, tirets bas';

  @override
  String get usernameSetupUpdateButton => 'Mettre à jour le nom';

  @override
  String get usernameSetupClaimButton => 'Réserver le nom';

  @override
  String get usernameSetupSkip => 'Passer pour l\'instant';

  @override
  String get sessionHandsTitle => 'Session';

  @override
  String sessionHandsHandsLogged(int count) {
    return '$count mains enregistrées';
  }

  @override
  String get sessionHandsError => 'Erreur';

  @override
  String get sessionHandsNoHandsTitle => 'Aucune main enregistrée';

  @override
  String get sessionHandsNoHandsSubtitle =>
      'Cette session n\'a pas encore de mains enregistrées.';

  @override
  String get sessionHandsWon => 'GAGNÉ';

  @override
  String sessionHandsActions(int count) {
    return '$count actions';
  }

  @override
  String get sessionHandsPot => 'Pot';

  @override
  String get stackChartScreenTitle => 'Graphique Stack';

  @override
  String get stackChartScreenPokerSession => 'Session de poker';

  @override
  String get notificationsScreenTitle => 'Notifications';

  @override
  String get notificationsScreenToday => 'Aujourd\'hui';

  @override
  String get notificationsScreenMarkAllAsRead => 'Tout marquer comme lu';

  @override
  String get notificationsScreenMarkAsRead => 'Marquer comme lu';

  @override
  String get notificationsScreenNoNotifications => 'Aucune notification';

  @override
  String get notificationsScreenClubInvitation => 'Invitation au club';

  @override
  String get notificationsScreenInvitedToJoin =>
      'Vous avez été invité à rejoindre';

  @override
  String get notificationsScreenDecline => 'Refuser';

  @override
  String get notificationsScreenNotAuthenticated => 'Non authentifié';

  @override
  String get notificationsScreenRequestResolved => 'Demande résolue';

  @override
  String get notificationsScreenRequestClosed => 'Demande fermée';

  @override
  String get notificationsScreenResponse => 'Réponse';

  @override
  String get notificationsScreenEvents => 'Événements';

  @override
  String get notificationsScreenRsvp => 'RSVP';

  @override
  String get notificationsScreenClubs => 'Clubs';

  @override
  String get notificationsScreenInvitations => 'Invitations';

  @override
  String get notificationsScreenSeats => 'Places';

  @override
  String get notificationsScreenSupport => 'Support';

  @override
  String notifEventCreatedTitle(String eventName) {
    return 'Nouvel événement : $eventName';
  }

  @override
  String notifEventCreatedBody(String date) {
    return '$date';
  }

  @override
  String notifEventUpdatedTitle(String eventName) {
    return 'Événement mis à jour : $eventName';
  }

  @override
  String notifEventUpdatedBody(String clubName) {
    return '$clubName a mis à jour les détails de l\'événement';
  }

  @override
  String notifEventCancelledTitle(String eventName) {
    return 'Événement annulé : $eventName';
  }

  @override
  String notifEventCancelledBody(String clubName, String date) {
    return '$clubName a annulé l\'événement prévu le $date';
  }

  @override
  String notifEventStartingTitle(String eventName) {
    return '$eventName commence dans 1 heure !';
  }

  @override
  String notifEventStartingBody(String clubName) {
    return 'L\'événement de $clubName va bientôt commencer';
  }

  @override
  String notifEventStartedTitle(String eventName) {
    return '$eventName est EN DIRECT !';
  }

  @override
  String notifEventStartedBody(String clubName) {
    return 'L\'événement de $clubName a commencé - rejoignez pour observer';
  }

  @override
  String notifSeatAvailableTitle(String eventName) {
    return 'Place disponible : $eventName';
  }

  @override
  String notifSeatAvailableBody(String clubName) {
    return 'Une place est disponible chez $clubName ! Ouvrez l\'appli pour la prendre.';
  }

  @override
  String notifMemberRsvpTitle(String memberName) {
    return 'RSVP : $memberName';
  }

  @override
  String notifMemberRsvpBody(
      String memberName, String rsvpStatus, String eventName) {
    return '$memberName a répondu \"$rsvpStatus\" à $eventName';
  }

  @override
  String get notifNewClubRequestTitle => 'Nouvelle demande de club';

  @override
  String get notifNewClubRequestBody =>
      'Une nouvelle demande d\'inscription de club a été soumise';

  @override
  String get notifClubApprovedTitle => 'Club approuvé';

  @override
  String get notifClubApprovedBody => 'Votre club a été approuvé !';

  @override
  String get notifClubRejectedTitle => 'Club refusé';

  @override
  String get notifClubRejectedBody => 'Votre demande de club a été refusée';

  @override
  String get notifMemberInvitedTitle => 'Invitation au club';

  @override
  String get notifMemberInvitedBody =>
      'Vous avez été invité à rejoindre un club';

  @override
  String get notifInvitationAcceptedTitle => 'Invitation acceptée';

  @override
  String notifInvitationAcceptedBody(String memberName) {
    return '$memberName a accepté l\'invitation';
  }

  @override
  String get notifInvitationDeclinedTitle => 'Invitation refusée';

  @override
  String notifInvitationDeclinedBody(String memberName) {
    return '$memberName a refusé l\'invitation';
  }

  @override
  String get notifSupportRequestTitle => 'Demande de support';

  @override
  String get notifSupportRequestBody =>
      'Une nouvelle demande de support a été soumise';

  @override
  String get notifSupportUpdatedTitle => 'Mise à jour du support';

  @override
  String get notifSupportUpdatedBody =>
      'Votre demande de support a été mise à jour';

  @override
  String get notifTypeEventCreated => 'Nouvel événement';

  @override
  String get notifTypeEventUpdated => 'Événement mis à jour';

  @override
  String get notifTypeEventCancelled => 'Événement annulé';

  @override
  String get notifTypeEventStarting => 'Événement imminent';

  @override
  String get notifTypeEventStarted => 'Événement commencé';

  @override
  String get notifTypeMemberRsvp => 'RSVP de membre';

  @override
  String get notifTypeNewClubRequest => 'Nouvelle demande de club';

  @override
  String get notifTypeClubApproved => 'Club approuvé';

  @override
  String get notifTypeClubRejected => 'Club refusé';

  @override
  String get notifTypeMemberInvited => 'Invitation au club';

  @override
  String get notifTypeInvitationAccepted => 'Invitation acceptée';

  @override
  String get notifTypeInvitationDeclined => 'Invitation refusée';

  @override
  String get notifTypeSeatAvailable => 'Place disponible';

  @override
  String get notifTypeSupportRequest => 'Demande de support';

  @override
  String get notifTypeSupportUpdated => 'Mise à jour du support';

  @override
  String get invitationsScreenTitle => 'Invitations aux clubs';

  @override
  String get invitationsScreenNoPending => 'Aucune invitation en attente';

  @override
  String get invitationsScreenYouWillSee =>
      'Vous verrez les invitations des clubs ici';

  @override
  String get invitationsScreenGoBack => 'Retour';

  @override
  String get invitationsScreenUnknownClub => 'Club inconnu';

  @override
  String invitationsScreenInvitedBy(String name) {
    return 'Invité par $name';
  }

  @override
  String invitationsScreenExpires(String date) {
    return 'Expire $date';
  }

  @override
  String get invitationsScreenExpired => 'Expiré';

  @override
  String invitationsScreenExpiresInDays(int days) {
    return 'dans $days jour(s)';
  }

  @override
  String invitationsScreenExpiresInHours(int hours) {
    return 'dans $hours heure(s)';
  }

  @override
  String get invitationsScreenExpiresSoon => 'bientôt';

  @override
  String get invitationsScreenDecline => 'Refuser';

  @override
  String get invitationsScreenAccept => 'Accepter';

  @override
  String invitationsScreenJoinedAs(String clubName, String role) {
    return 'Vous avez rejoint $clubName en tant que $role';
  }

  @override
  String get profilePremium => 'Premium';

  @override
  String get profileFree => 'Gratuit';

  @override
  String get dealerTableStartNewHand => 'Nouvelle main';

  @override
  String get dealerTableStartSessionBtn => 'Démarrer la session';

  @override
  String get dealerTableNeedTwoPlayers =>
      'Il faut au moins 2 joueurs pour commencer';

  @override
  String get dealerTableAddTestPlayers => 'Ajouter des joueurs test';

  @override
  String dealerTableAddedTestPlayers(int count) {
    return '$count joueurs test ajoutés';
  }

  @override
  String dealerTableRolledBack(String street) {
    return 'Retour à $street';
  }

  @override
  String dealerTableUndoneAction(String playerName, String action) {
    return 'Annulé : $playerName $action';
  }

  @override
  String get dealerTableScanToJoin => 'Scannez pour occuper cette place';

  @override
  String get dealerTableOccupiedDot => 'Occupé · ';

  @override
  String get dealerTableEmptyLabel => 'Vide';

  @override
  String get dealerTableOccupiedLabel => 'Occupé';

  @override
  String get dealerTableSelectedLabel => 'Sélectionné';

  @override
  String get dealerTableSelectSeatLabel => 'CHOISIR UNE PLACE';

  @override
  String get dealerTableBetAmountDialog => 'Montant du Bet';

  @override
  String get dealerTableRaiseToDialog => 'Raise à';

  @override
  String get dealerTablePausedLabel => 'En pause';

  @override
  String get dealerTableListeningLabel => 'Écoute';

  @override
  String get dealerTableResumeVoiceTooltip => 'Reprendre la voix';

  @override
  String get dealerTablePauseVoiceTooltip => 'Pause voix';

  @override
  String get dealerTableVoiceOffLabel => 'Voix désactivée';

  @override
  String get dealerTableCalibratingLabel => 'Calibrage...';

  @override
  String get dealerTableCalibrationPrompt =>
      'Veuillez dire : « Table [numéro], Dealer [nom] »';

  @override
  String dealerTableDealerLockedMsg(String name, String table) {
    return 'Dealer verrouillé : $name à la table $table';
  }

  @override
  String get dealerTableNoSpeakersMsg =>
      'Aucune voix détectée — veuillez parler clairement';

  @override
  String get dealerTableSayTableDealerMsg =>
      'Veuillez dire : « Table [numéro], Dealer [nom] »';

  @override
  String get dealerTableConnectionLostRecovery =>
      'Connexion perdue — tentative de récupération...';

  @override
  String get dealerTableConnectionTimeout =>
      'Délai de connexion dépassé — recalibrage nécessaire';

  @override
  String get dealerTableConnectionRecovered => 'Connexion rétablie !';

  @override
  String get dealerTableActionHeldMsg => 'Action retenue';

  @override
  String get dealerTableFailedStartStreaming =>
      'Échec du streaming — vérifiez la connexion au serveur et le microphone';

  @override
  String dealerTableFailedStartVoice(String error) {
    return 'Échec du démarrage vocal : $error';
  }

  @override
  String get dealerTableAddPlayerActionLabel => 'Ajouter un joueur';

  @override
  String get dealerTableSeatAnotherPlayer => 'Asseoir un autre joueur ici';

  @override
  String get dealerTableSitHereLabel => 'S\'asseoir ici';

  @override
  String get dealerTableJoinAsDealerPlayer =>
      'Rejoindre la partie en tant que Dealer-joueur';

  @override
  String get dealerTableDealerFallback => 'Dealer';

  @override
  String dealerTableUpdatedStackMsg(String name, String amount) {
    return 'Stack de $name mis à jour à $amount';
  }

  @override
  String dealerTableFailedUpdateStackMsg(String error) {
    return 'Échec de la mise à jour du Stack : $error';
  }

  @override
  String dealerTableSittingAtSeatMsg(int number) {
    return 'Vous jouez maintenant à la place $number';
  }

  @override
  String dealerTableFailedSitMsg(String error) {
    return 'Échec pour s\'asseoir à la table : $error';
  }

  @override
  String dealerTableFailedAddPlayerMsg(String error) {
    return 'Échec de l\'ajout du joueur : $error';
  }

  @override
  String dealerTableRemovedFromSeat(String name, int seat) {
    return '$name retiré de la place $seat';
  }

  @override
  String dealerTableFailedRemoveMsg(String error) {
    return 'Échec du retrait du joueur : $error';
  }

  @override
  String get eventDetailDateAndTime => 'Date et heure';

  @override
  String eventDetailTableSeatInfo(String table, int seat) {
    return 'Table $table, Place #$seat';
  }

  @override
  String get eventDetailYoureSeatedGoodLuck =>
      'Vous êtes assis, bonne chance !';

  @override
  String get eventDetailHomeGame => 'Partie à domicile';

  @override
  String get clubDashboardDateLabel => 'Date';

  @override
  String get clubDashboardUnknownLabel => 'Inconnu';

  @override
  String get clubDashboardActiveLabel => 'Actif';

  @override
  String get clubDashboardIdleLabel => 'Inactif';

  @override
  String clubDashboardInvitedTimeAgo(String time) {
    return 'Invité $time';
  }

  @override
  String get clubDashboardPendingLabel => 'En attente';

  @override
  String get clubDashboardNoDealersYet => 'Pas encore de Dealers';

  @override
  String get clubDashboardInviteDealersHint =>
      'Invitez des Dealers pour aider à gérer vos tables';

  @override
  String get clubDashboardInviteDealer => 'Inviter un Dealer';

  @override
  String get clubDashboardInviteDealerBody =>
      'Entrez l\'email du Dealer que vous souhaitez inviter.';

  @override
  String get clubDashboardSendInvitationBtn => 'Envoyer l\'invitation';

  @override
  String clubDashboardInvitationSentTo(String email) {
    return 'Invitation envoyée à $email';
  }

  @override
  String clubDashboardFailedSendInvitationMsg(String error) {
    return 'Échec de l\'envoi de l\'invitation : $error';
  }

  @override
  String get clubDashboardCancelInvitationTitle => 'Annuler l\'invitation ?';

  @override
  String clubDashboardCancelInvitationBody(String email) {
    return 'Annuler l\'invitation à $email ?';
  }

  @override
  String get clubDashboardKeepBtn => 'Garder';

  @override
  String get clubDashboardCancelInvitationBtn => 'Annuler l\'invitation';

  @override
  String clubDashboardFailedCancelMsg(String error) {
    return 'Échec de l\'annulation de l\'invitation : $error';
  }

  @override
  String clubSettingsMembers(int count) {
    return 'Membres ($count)';
  }

  @override
  String get clubSettingsNoMembersFound => 'Aucun membre trouvé';

  @override
  String get clubSettingsRoleOwner => 'Propriétaire';

  @override
  String get clubSettingsRoleAdmin => 'Admin';

  @override
  String get clubSettingsRoleDealer => 'Dealer';

  @override
  String get clubSettingsRolePlayer => 'Joueur';

  @override
  String get clubSettingsTableAddedMsg => 'Table ajoutée';

  @override
  String get clubSettingsEditTableTitle => 'Modifier la table';

  @override
  String get clubSettingsDeleteTableTitle => 'Supprimer la table ?';

  @override
  String clubSettingsDeleteTableBody(String name) {
    return 'Êtes-vous sûr de vouloir supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String get clubSettingsTableDeletedMsg => 'Table supprimée';

  @override
  String get clubSettingsDealerScanHint =>
      'Les Dealers scannent ceci pour démarrer une session à cette table';

  @override
  String get clubSettingsRegenerateBtn => 'Régénérer';

  @override
  String get clubSettingsAppQrCodes => 'Codes QR de l\'application';

  @override
  String get clubSettingsShareWithPlayers =>
      'Partagez avec les joueurs pour télécharger l\'application';

  @override
  String get clubSettingsDownloadPdf => 'Télécharger le PDF';

  @override
  String get clubSettingsDownloadFinalTable =>
      'Téléchargez l\'application Final Table';

  @override
  String get clubSettingsScanQrToGetStarted =>
      'Scannez le code QR de votre appareil pour commencer';

  @override
  String get clubSettingsScanToStartSession =>
      'Scannez ce code QR pour démarrer une session';

  @override
  String get clubSettingsForDealersOnly => 'Réservé aux Dealers';

  @override
  String clubSettingsTableDefault(int number) {
    return 'Table $number';
  }

  @override
  String eventManagementFailedUpdateEvent(String error) {
    return 'Échec de la mise à jour de l\'événement : $error';
  }

  @override
  String adminTableThisWillMoveMsg(int count) {
    return 'Cela déplacera $count joueur(s) vers la liste d\'attente et supprimera la table de cet événement.';
  }

  @override
  String get adminTableThisWillRemoveMsg =>
      'Cela supprimera la table de cet événement.';

  @override
  String adminTableClosedWithWaitlistMsg(String table, int count) {
    return '$table fermée. $count joueur(s) déplacé(s) vers la liste d\'attente.';
  }

  @override
  String adminTableClosedMsg(String table) {
    return '$table fermée.';
  }

  @override
  String get adminTableEmptyLabel => 'Vide';

  @override
  String get adminTableTableFallback => 'Table';

  @override
  String adminTableTableNumberLabel(int number) {
    return 'Table $number';
  }

  @override
  String homePendingInvitationsMsg(int count) {
    return 'Vous avez $count invitation(s) en attente.';
  }

  @override
  String get homeEventFallback => 'Événement';

  @override
  String get homePokerFallback => 'Poker';

  @override
  String get homeUserFallback => 'Utilisateur';

  @override
  String homeSeatInfoStr(int seat, String chipStack) {
    return 'Place #$seat  •  $chipStack';
  }

  @override
  String get pokerHandYouLabel => 'Vous';

  @override
  String pokerHandMovingToTable(String stack) {
    return 'Déplacement vers une autre table. Votre Stack ($stack) sera transféré. Les autres joueurs seront supprimés.';
  }

  @override
  String pokerHandActiveSessionMsg(int count) {
    return 'Vous avez une session active avec $count main(s) enregistrée(s). Que souhaitez-vous faire ?';
  }

  @override
  String get pokerHandUnknownLabel => 'Inconnu';

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
      'Tous les joueurs All-In — distribution des cartes restantes';

  @override
  String get pokerHandWaitingForCards =>
      'En attente de la distribution des cartes';

  @override
  String get pokerHandBettingComplete =>
      'Enchères terminées — prêt pour la rue suivante';

  @override
  String pokerHandSeatFallback(int id) {
    return 'Place $id';
  }

  @override
  String pokerHandPlayerFallback(int id) {
    return 'Joueur $id';
  }

  @override
  String get pokerHandChooseOption => 'Choisissez une option :';

  @override
  String get pokerHandLeaveBtn => 'Quitter';

  @override
  String get pokerHandConfirmBtn => 'Confirmer';

  @override
  String pokerHandCurrentlyHaveRemaining(String stack) {
    return 'Il vous reste actuellement $stack.';
  }

  @override
  String get opponentsColorRed => 'Rouge';

  @override
  String get opponentsColorLightBlue => 'Bleu clair';

  @override
  String get opponentsColorGreen => 'Vert';

  @override
  String get opponentsColorOrange => 'Orange';

  @override
  String get opponentsColorPurple => 'Violet';

  @override
  String get opponentsColorTeal => 'Sarcelle';

  @override
  String get opponentsColorPink => 'Rose';

  @override
  String get opponentsColorIndigo => 'Indigo';

  @override
  String opponentsFailedToLoad(String error) {
    return 'Échec du chargement des adversaires : $error';
  }

  @override
  String get opponentDetailFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get opponentDetailStealLabel => 'Steal';

  @override
  String get opponentDetailCheckRaiseLabel => 'Check/Raise';

  @override
  String get individualSetupSessionSetup => 'Configuration de session';

  @override
  String get individualSetupSessionNameLabel => 'Nom de la session';

  @override
  String get individualSetupGameTypeLabel => 'Type de jeu';

  @override
  String get individualSetupCashGameLabel => 'Cash Game';

  @override
  String get individualSetupTournamentLabel => 'Tournament';

  @override
  String get individualSetupBuyInAmountLabel => 'Montant du Buy-in';

  @override
  String get individualSetupEnterAmountHint => 'Entrez le montant';

  @override
  String get individualSetupCashGameNote =>
      'En Cash Game, votre Stack initial est égal au montant du Buy-in.';

  @override
  String get individualSetupStartingStackLabel => 'Stack initial';

  @override
  String get individualSetupEnterChipStackHint => 'Entrez le Stack de jetons';

  @override
  String individualSetupStackValidation(int bigBlind) {
    return 'Le Stack initial doit être au moins égal au Big Blind ($bigBlind)';
  }

  @override
  String get individualSetupStartSessionBtn => 'Démarrer la session';

  @override
  String get individualSetupEnterValueHint => 'Entrez la valeur';

  @override
  String get individualHandSetupTitle => 'Main individuelle';

  @override
  String get individualHandSetupSubtitle => 'Enregistrement rapide de main';

  @override
  String get individualHandSetupHandNameLabel => 'Nom de la main (optionnel)';

  @override
  String get playerSessionBluff => 'Bluff';

  @override
  String get playerSessionValue => 'Value';

  @override
  String get playerSessionMistake => 'Erreur';

  @override
  String get playerSessionCooler => 'Cooler';

  @override
  String get playerSessionHeroCall => 'Hero Call';

  @override
  String get playerSessionExploit => 'Exploit';

  @override
  String get playerSessionToughSpot => 'Situation difficile';

  @override
  String get playerSessionEasyFold => 'Fold facile';

  @override
  String get playerSessionEndedTitle => 'Session terminée';

  @override
  String get playerSessionEndedBody => 'Le Dealer a mis fin à cette session.';

  @override
  String get playerSessionRemovedTitle => 'Retiré de la table';

  @override
  String get playerSessionRemovedBody =>
      'Vous avez été retiré de la table par le Dealer.';

  @override
  String playerSessionYouWon(String amount) {
    return 'Vous avez gagné $amount !';
  }

  @override
  String playerSessionSeatWins(int seat, String amount) {
    return 'Place $seat gagne $amount';
  }

  @override
  String get playerSessionYourHoleCardsTitle => 'Vos Hole Cards';

  @override
  String get playerSessionConnecting => 'Connexion...';

  @override
  String get playerSessionGoBackBtn => 'Retour';

  @override
  String get playerSessionHoleCardsLabel => 'Hole Cards';

  @override
  String get playerSessionEditBtn => 'Modifier';

  @override
  String get playerSessionAddBtn => 'Ajouter';

  @override
  String get playerSessionBoardLabel => 'Board';

  @override
  String get playerSessionNoCardsDealt => 'Aucune carte distribuée';

  @override
  String get playerSessionWaitingForAction => 'En attente d\'une action...';

  @override
  String get playerSessionActionsLabel => 'Actions';

  @override
  String get playerSessionYouLabel => 'Vous';

  @override
  String playerSessionSeatFallback(int seat) {
    return 'Place $seat';
  }

  @override
  String get playerSessionNotesHintText =>
      'Ajoutez des notes sur cette main...';

  @override
  String get playerSessionHandHistoryLabel => 'Historique des mains';

  @override
  String get playerSessionNoCompletedHands => 'Aucune main complétée';

  @override
  String playerSessionWonAmount(String amount) {
    return 'Gagné $amount';
  }

  @override
  String get playerSessionLostLabel => 'Perdu';

  @override
  String get playerSessionDealerChangeTitle => 'Changement de Dealer';

  @override
  String get playerSessionWaitingForDealer => 'En attente du nouveau Dealer...';

  @override
  String playerSessionHandUpdated(int number) {
    return 'Main #$number mise à jour';
  }

  @override
  String playerSessionErrorSaving(String error) {
    return 'Erreur de sauvegarde : $error';
  }

  @override
  String playerSessionEditHand(int number) {
    return 'Modifier la main #$number';
  }

  @override
  String get playerSessionViewDetails => 'Voir les détails';

  @override
  String get playerSessionTapToAddHoleCards =>
      'Appuyez pour ajouter les Hole Cards';

  @override
  String get playerSessionSaveChanges => 'Enregistrer les modifications';

  @override
  String get playerSessionLeaveTableTitle => 'Quitter la table ?';

  @override
  String get playerSessionLeaveTableBody =>
      'Êtes-vous sûr de vouloir quitter cette table ?';

  @override
  String playerSessionFailedLeave(String error) {
    return 'Échec de la sortie : $error';
  }

  @override
  String get playerSessionTableSession => 'Session de table';

  @override
  String playerSessionHandNumber(int number) {
    return 'Main #$number';
  }

  @override
  String get playerSessionUnknownDealer => 'Inconnu';

  @override
  String get playerSessionNotAuthenticated => 'Non authentifié';

  @override
  String get dealerQrScanSessionSettings => 'Paramètres de session';

  @override
  String dealerQrScanTableNameLabel(String name) {
    return 'Table : $name';
  }

  @override
  String dealerQrScanEventNameLabel(String name) {
    return 'Événement : $name';
  }

  @override
  String get dealerQrScanBlindsLabel => 'Blinds';

  @override
  String get dealerQrScanSmallBlindLabel => 'Small Blind';

  @override
  String get dealerQrScanBigBlindLabel => 'Big Blind';

  @override
  String get dealerQrScanStartDealingBtn => 'Commencer à distribuer';

  @override
  String get dealerQrScanResumeSessionTitle => 'Reprendre la session';

  @override
  String dealerQrScanTakingOverFrom(String name) {
    return 'Prise en charge de $name';
  }

  @override
  String get dealerQrScanHandsPlayedLabel => 'Mains jouées';

  @override
  String get dealerQrScanBlindsInfoLabel => 'Blinds';

  @override
  String get dealerQrScanPlayersLabel => 'Joueurs';

  @override
  String get dealerQrScanResumeBtn => 'Reprendre';

  @override
  String get dealerQrScanTableNotAssigned => 'Table non assignée';

  @override
  String get dealerQrScanEventTablesLabel => 'Tables de l\'événement :';

  @override
  String get dealerQrScanNoTablesAssigned => 'Aucune table assignée';

  @override
  String get dealerQrScanThisTableId => 'ID de cette table :';

  @override
  String get dealerQrScanCorrectQrUrl => 'URL correcte du code QR :';

  @override
  String get dealerQrScanScanTableQrTitle => 'Scanner le QR de la table';

  @override
  String get dealerQrScanScanInstructions =>
      'Scannez le code QR de la table pour commencer à distribuer';

  @override
  String get eventDashboardTournamentOnBreak => 'Tournament en pause';

  @override
  String get eventDashboardLiveLabel => 'En direct';

  @override
  String get eventDashboardLocalLabel => 'Local';

  @override
  String get eventDashboardDisconnectedLabel => 'Déconnecté';

  @override
  String get eventDashboardPlayersLabel => 'Joueurs';

  @override
  String get eventDashboardTablesLabel => 'Tables';

  @override
  String get eventDashboardTotalChipsLabel => 'Jetons totaux';

  @override
  String get eventDashboardAvgStackLabel => 'Stack moyen';

  @override
  String get eventDashboardChipLeaderLabel => 'Chip Leader';

  @override
  String get eventDashboardNoRankingsYet => 'Pas encore de classement';

  @override
  String get eventDashboardRankingsWillAppear =>
      'Le classement apparaîtra lorsque les joueurs rejoindront les tables';

  @override
  String eventDashboardTableSeatLabel(String table, int seat) {
    return '$table - Place $seat';
  }

  @override
  String eventDashboardPlayerFallback(String id) {
    return 'Joueur $id';
  }

  @override
  String get commonNA => 'N/D';

  @override
  String sessionHistoryFailedLoad(String error) {
    return 'Échec du chargement des sessions : $error';
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
    return 'Place $seat ($position)';
  }

  @override
  String sessionHistorySeat(String seat) {
    return 'Place $seat';
  }

  @override
  String get sessionHistorySyncCompleted => 'Synchronisation terminée';

  @override
  String get sessionHistoryFullHistory => 'Historique complet des sessions';

  @override
  String get sessionHandsRetry => 'Réessayer';

  @override
  String get stackChartScreenStart => 'Début';

  @override
  String get stackChartScreenRebuy => 'Rebuy';

  @override
  String get stackChartScreenEnd => 'Fin';

  @override
  String get quickStackSelectPlayer => 'Sélectionner un joueur';

  @override
  String quickStackAddPlayer(String name) {
    return 'Ajouter « $name »';
  }

  @override
  String get quickStackSaveToOpponents =>
      'Enregistrer dans la liste d\'adversaires';

  @override
  String get quickStackYou => 'Vous';

  @override
  String get quickStackNoPlayersFound => 'Aucun joueur trouvé.';

  @override
  String get seatSetupDone => 'Terminé';

  @override
  String get seatSetupCancel => 'Annuler';

  @override
  String get authConnectionIssue => 'Problème de connexion';

  @override
  String get authConnectionIssueBody =>
      'Nous n\'avons pas pu nous connecter à nos serveurs.\nVeuillez vérifier votre connexion internet\net réessayer.';

  @override
  String get authTryAgain => 'Réessayer';

  @override
  String get redeemInvitationTitle => 'Utiliser une invitation';

  @override
  String get redeemEnterCode => 'Entrer le code d\'invitation';

  @override
  String get redeemCodeDescription =>
      'Entrez le code à 8 caractères reçu d\'un admin du club pour rejoindre son club.';

  @override
  String get redeemJoinClub => 'Rejoindre le club';

  @override
  String get redeemWelcome => 'Bienvenue !';

  @override
  String redeemJoinedAs(String clubName, String role) {
    return 'Vous avez rejoint $clubName en tant que $role';
  }

  @override
  String get redeemContinue => 'Continuer';

  @override
  String get supportBugReport => 'Rapport de bug';

  @override
  String get supportFeatureRequest => 'Demande de fonctionnalité';

  @override
  String get supportAccountIssue => 'Problème de compte';

  @override
  String get supportOther => 'Autre';

  @override
  String get supportFillAllFields => 'Veuillez remplir tous les champs';

  @override
  String get supportSubmitted => 'Demande d\'assistance soumise avec succès';

  @override
  String supportFailedSubmit(String error) {
    return 'Échec de l\'envoi : $error';
  }

  @override
  String get supportTitle => 'Aide et support';

  @override
  String get supportSubmitButton => 'Envoyer';

  @override
  String get supportCategoryLabel => 'Catégorie';

  @override
  String get supportSubjectLabel => 'Sujet';

  @override
  String get supportDescriptionLabel => 'Description';

  @override
  String get supportSubjectHint => 'Bref résumé du problème';

  @override
  String get supportDescriptionHint => 'Décrivez le problème en détail...';

  @override
  String get calendarEventLocation => 'Lieu';

  @override
  String get calendarEventBuyIn => 'Montant du buy-in';

  @override
  String get calendarEventEdit => 'Modifier';

  @override
  String get calendarEventDelete => 'Supprimer l\'événement';

  @override
  String calendarEventDeleteConfirm(String title) {
    return 'Supprimer $title ?';
  }

  @override
  String calendarEventDeleteBody(String title) {
    return 'Êtes-vous sûr de vouloir supprimer \"$title\" ?\nCette action est irréversible.';
  }

  @override
  String get calendarEventDeleteButton => 'Supprimer';

  @override
  String get clubInfoTitle => 'Info du club';

  @override
  String clubInfoMembersCount(int count) {
    return 'Membres ($count)';
  }

  @override
  String get clubInfoNoMembers => 'Aucun membre trouvé';

  @override
  String get finalStandingsNoData => 'Aucun classement disponible';

  @override
  String get finalStandingsNoDataHint =>
      'Cet événement n\'a peut-être pas enregistré de classement';

  @override
  String get finalStandingsEmpty => 'Aucun classement enregistré';

  @override
  String get finalStandingsTitle => 'Classement final';

  @override
  String get finalStandingsPlayers => 'Joueurs';

  @override
  String get finalStandingsCompleted => 'Terminé';

  @override
  String get liveRankingsTitle => 'Live Rankings';

  @override
  String get liveRankingsEliminated => 'Joueurs éliminés';

  @override
  String get liveRankingsWaiting => 'En attente de joueurs';

  @override
  String get liveRankingsWaitingHint =>
      'Le classement apparaîtra une fois que les joueurs seront assis';

  @override
  String get liveRankingsError => 'Erreur lors du chargement du classement';

  @override
  String get liveRankingsTryAgain => 'Réessayer';

  @override
  String get leaderboardPlayers => 'Joueurs';

  @override
  String get leaderboardTotalChips => 'Total de jetons';

  @override
  String get leaderboardWaiting => 'En attente de joueurs...';

  @override
  String leaderboardChipLeader(String name) {
    return 'Leader de jetons : $name';
  }

  @override
  String get dealerQrScanBbAnte => 'BB Ante';

  @override
  String mainDealerOnClub(String clubName) {
    return 'Vous êtes maintenant dealer sur $clubName';
  }

  @override
  String get raiseSnapMin => 'Min';

  @override
  String get raiseSnapPot => 'Pot';

  @override
  String get raiseSnapAllIn => 'All-In';

  @override
  String sessionHistoryPlayerWins(int playerId) {
    return 'Le joueur $playerId gagne :';
  }

  @override
  String get inviteClubAdminFallback => 'Admin du club';

  @override
  String pokerHandBetRange(String min, String max) {
    return 'Min : $min · Max : $max';
  }

  @override
  String pokerHandAmountBetween(String min, String max) {
    return 'Le montant doit être compris entre $min et $max';
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
    return '$playerName doit agir ($stack)';
  }

  @override
  String get eventDashboardOnBreakBadge => 'EN PAUSE';

  @override
  String get eventDetailAdminActions => 'ACTIONS ADMIN';

  @override
  String get playerSessionHandNotesLabel => 'NOTES DE MAIN';

  @override
  String get playerSessionTagsLabel => 'ÉTIQUETTES';

  @override
  String get playerSessionNotesLabel => 'NOTES';

  @override
  String get playerSessionHoleCardsUpperLabel => 'HOLE CARDS';

  @override
  String get qrJoinDeclined => 'Votre demande d\'adhésion a été refusée';

  @override
  String qrJoinFailed(String error) {
    return 'Échec de l\'adhésion au siège : $error';
  }

  @override
  String get qrJoinTable => 'Rejoindre la table';

  @override
  String get qrJoinLoading => 'Chargement des informations de la table...';

  @override
  String get qrJoinError => 'Une erreur s\'est produite';

  @override
  String get qrJoinGoBack => 'Retour';

  @override
  String get qrJoinSeatOccupied =>
      'Ce siège est peut-être déjà occupé. Rejoindre remplacera le joueur actuel.';

  @override
  String get qrJoinWaitingDealer => 'En attente du dealer';

  @override
  String qrJoinRequestSent(int seatNumber) {
    return 'Votre demande pour rejoindre le Siège $seatNumber a été envoyée.';
  }

  @override
  String get qrJoinDealerApproval =>
      'Le dealer définira votre stack de jetons et approuvera votre adhésion.';

  @override
  String get qrJoinCancelRequest => 'Annuler la demande';

  @override
  String get qrJoinRequestButton => 'Demander à rejoindre';

  @override
  String get onboardingSkipTour => 'Passer le tour';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue sur\nFinal Table';

  @override
  String get onboardingWelcomeBody =>
      'Faisons une visite rapide pour vous aider à démarrer.\n\nVous pouvez toujours reprendre cette visite depuis\nProfil → Paramètres → Base de connaissances.';

  @override
  String get onboardingLetsGo => 'Allons-y';

  @override
  String get onboardingGotIt => 'Compris';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStartLoggingTitle => 'Commencer l\'enregistrement';

  @override
  String get onboardingStartLoggingBody =>
      'Appuyez sur le bouton + pour commencer à enregistrer une main.';

  @override
  String get onboardingFullModeTitle => 'Mode d\'enregistrement complet';

  @override
  String get onboardingFullModeBody =>
      'Suivez chaque action de chaque joueur sur toutes les rues. Parfait pour une analyse sérieuse.';

  @override
  String get onboardingIndividualModeTitle =>
      'Mode d\'enregistrement individuel';

  @override
  String get onboardingIndividualModeBody =>
      'Suivi rapide des gains/pertes pour une seule session. Choisissez maintenant un mode pour continuer !';

  @override
  String get onboardingSessionSetupTitle => 'Configuration de la session';

  @override
  String get onboardingSessionSetupBody =>
      'Ici vous pouvez définir le nom de session, le type de jeu, les blindes, le buy-in et le stack de départ.';

  @override
  String get onboardingTableSetupTitle => 'Configurer votre table';

  @override
  String get onboardingTableSetupBody =>
      'Maintenant, remplissez les détails de la session et configurez la table. Appuyez sur un siège pour vous placer ainsi que vos adversaires, et glissez le bouton du dealer (D) pour définir la position du bouton. Appuyez sur l\'icône ✓ en haut à droite quand vous êtes prêt.';

  @override
  String get onboardingSeatOpenTitle => 'Siège libre';

  @override
  String get onboardingSeatOpenBody =>
      'Basculez pour marquer un siège comme occupé ou vide. Les sièges ouverts sont ignorés pendant la main.';

  @override
  String get onboardingThisIsMySeatTitle => 'C\'est mon siège';

  @override
  String get onboardingThisIsMySeatBody =>
      'Appuyez ici si c\'est votre siège. Cela remplit automatiquement votre nom et suit vos statistiques personnelles.';

  @override
  String get onboardingPlayerNameTitle => 'Nom du joueur';

  @override
  String get onboardingPlayerNameBody =>
      'Tapez un nom ou choisissez parmi vos adversaires sauvegardés. Les adversaires sauvegardés suivent les statistiques entre les sessions.';

  @override
  String get onboardingSaveOpponentTitle => 'Sauvegarder l\'adversaire';

  @override
  String get onboardingSaveOpponentBody =>
      'Nouveau nom ? Appuyez ici pour le sauvegarder comme adversaire. Ses statistiques seront suivies automatiquement.';

  @override
  String get onboardingDealerButtonTitle => 'Bouton dealer';

  @override
  String get onboardingDealerButtonBody =>
      'Faites glisser vers le siège avec la position du dealer. Cela détermine les blindes et l\'ordre des actions.';

  @override
  String get onboardingViewSessionsTitle =>
      'Vos sessions vivent ici';

  @override
  String get onboardingViewSessionsBody =>
      'Touchez l\'icône Sessions pour voir la session que vous venez de jouer.';

  @override
  String get onboardingSessionHistoryCardTitle =>
      'La session que vous venez de jouer';

  @override
  String get onboardingSessionHistoryCardBody =>
      'Voici votre session tutoriel : touchez-la à tout moment pour revoir chaque main.';

  @override
  String get onboardingHandListTitle =>
      'Chaque main, enregistrée';

  @override
  String get onboardingHandListBody =>
      'Touchez ici pour ouvrir les mains enregistrées dans cette session.';

  @override
  String get onboardingHandCardTitle =>
      'Votre main enregistrée';

  @override
  String get onboardingHandCardBody =>
      'Touchez une main pour voir le replay complet, street par street.';

  @override
  String get onboardingHandToolsTitle =>
      'Outils de la main';

  @override
  String get onboardingHandToolsBody =>
      'Basculez les montants en grosses blindes (BB), exportez ou partagez la main, et ajoutez une étoile pour garder vos favorites — le tout depuis ici.';

  @override
  String get onboardingAiAnalysisTitle =>
      'Analyse de main par IA';

  @override
  String get onboardingAiAnalysisBody =>
      'Recevez un coaching instantané sur cette main — votre première analyse est offerte. Touchez le bouton !';

  @override
  String get sessionTutorialBadge =>
      'Tutoriel';

  @override
  String get introGetStarted =>
      'Commencer';

  @override
  String get linkAccountTitle =>
      'Vous jouez en tant qu\'invité';

  @override
  String get linkAccountBody =>
      'Créez un compte gratuit pour protéger vos données sur tous vos appareils.';

  @override
  String get linkAccountSuccess =>
      'Compte créé — vos données sont maintenant sauvegardées.';

  @override
  String get linkAccountConflictTitle =>
      'Ce compte existe déjà';

  @override
  String get linkAccountConflictBody =>
      'Ce compte existe déjà. Se connecter avec celui-ci ? Vos données d\'invité ne seront pas transférées.';

  @override
  String get anonSignOutWarning =>
      'Vous êtes connecté en tant qu\'invité. En vous déconnectant, vous perdrez définitivement l\'accès à vos sessions et à vos mains.';

  @override
  String get paywallAccountReady =>
      'Compte créé ! Vous pouvez maintenant finaliser votre achat.';

  @override
  String get onboardingAllSetTitle => 'Tout est prêt !';

  @override
  String get onboardingAllSetBody =>
      'Vous êtes prêt à commencer à suivre vos sessions de poker.';

  @override
  String get onboardingLetsPlay => 'On joue';

  @override
  String get onboardingUpdateStackTitle => 'Mettre à jour le stack';

  @override
  String get onboardingUpdateStackBody =>
      'Utilisez ceci pour mettre à jour manuellement votre nombre de jetons à tout moment sans enregistrer une main complète.';

  @override
  String get onboardingLogAHandTitle => 'Enregistrer une main';

  @override
  String get onboardingLogAHandBody =>
      'Appuyez ici pour configurer la table et enregistrer une main. Essayons maintenant !';

  @override
  String get onboardingMarkSeatOpenTitle => 'Marquer le siège comme libre';

  @override
  String get onboardingMarkSeatOpenBody =>
      'Appuyez sur la coche pour basculer un siège entre occupé et vide. Les sièges vides sont ignorés dans la main.';

  @override
  String get onboardingDealerButtonQsuTitle => 'Bouton dealer';

  @override
  String get onboardingDealerButtonQsuBody =>
      'Appuyez sur « D » pour assigner le bouton dealer à n\'importe quel siège. Cela contrôle les positions des blindes et l\'ordre des actions.';

  @override
  String get onboardingAssignPlayerTitle => 'Assigner un joueur';

  @override
  String get onboardingAssignPlayerBody =>
      'Appuyez sur le nom d\'un joueur pour vous asseoir vous-même ou un adversaire sauvegardé. Votre stack est appliqué automatiquement quand vous vous asseyez.';

  @override
  String get onboardingAdjustStackTitle => 'Ajuster le stack';

  @override
  String get onboardingAdjustStackBody =>
      'Faites glisser le curseur pour définir le stack d\'un adversaire en BBs. Appuyez sur la valeur du stack pour saisir un montant exact.';

  @override
  String get onboardingEndSessionTitle => 'Terminer votre session';

  @override
  String get onboardingEndSessionBody =>
      'Appuyez sur le bouton rouge Arrêt pour sauvegarder les résultats de votre session et revenir à l\'écran d\'accueil.';

  @override
  String onboardingStepOf(int step, int total) {
    return 'Étape $step sur $total';
  }

  @override
  String get guidedGestureGuideTitle => 'Guide des gestes';

  @override
  String get guidedGestureGuideBody =>
      'Touchez cette icône à tout moment pour revoir le guide des gestes.';

  @override
  String get guidedSkipButtonTitle => 'Bouton passer';

  @override
  String get guidedSkipButtonBody =>
      'Si vous passez une main, ce bouton déplace le bouton de dealer vers le joueur suivant. Notez que les stacks seront désynchronisés — vous pouvez les mettre à jour dans Gérer les joueurs.';

  @override
  String get guidedGameMenuTitle => 'Menu du jeu';

  @override
  String get guidedGameMenuBody =>
      'Ce menu contient des options utiles. Regardons un paramètre important.';

  @override
  String get guidedGameSettingsTitle => 'Paramètres du jeu';

  @override
  String get guidedGameSettingsBody =>
      'Ici, vous pouvez changer les blindes en cours de session — utile lors des tournois quand les niveaux augmentent.';

  @override
  String get guidedEndSessionTitle => 'Terminer votre session';

  @override
  String get guidedEndSessionBody =>
      'Appuyez sur ce menu et sélectionnez « Terminer la session » pour sauvegarder vos résultats.';

  @override
  String get guidedReviewHandTitle => 'Revoir la main';

  @override
  String get guidedReviewHandBody => 'Entrez vos hole cards et vos notes.';

  @override
  String get guidedHandCompleteTitle => 'Main terminée !';

  @override
  String get guidedHandCompleteBody =>
      'Bien joué ! Vous venez d\'enregistrer votre première main.';

  @override
  String get guidedSkip => 'Passer';

  @override
  String get guidedYourTurn => 'À vous de jouer !';

  @override
  String get guidedOpenThePotTitle => 'Ouvrir le pot';

  @override
  String get guidedBetOnceBody => 'Ce joueur mise.';

  @override
  String get guidedFoldTitle => 'Fold';

  @override
  String get guidedFoldBody => 'Ce joueur se couche.';

  @override
  String get guidedCallTitle => 'Call';

  @override
  String get guidedCallBody => 'Ce joueur suit.';

  @override
  String get guidedCheckTitle => 'Check';

  @override
  String get guidedCheckBody => 'Ce joueur check.';

  @override
  String get guidedGestureFold => 'Glisser à gauche ←';

  @override
  String get guidedGestureCheck => 'Appuyer';

  @override
  String get guidedGestureCall => 'Appuyer';

  @override
  String get guidedGestureBet =>
      'Appuyez & glissez vers le haut ↑';

  @override
  String get guidedGestureRaise =>
      'Appuyez & glissez vers le haut ↑';

  @override
  String get guidedActionFold => 'Fold';

  @override
  String get guidedActionCheck => 'Check';

  @override
  String get guidedActionCall => 'Call';

  @override
  String get guidedActionBet => 'Bet';

  @override
  String get guidedActionRaise => 'Raise';

  @override
  String get guidedDealFlopTitle => 'Distribuer le Flop';

  @override
  String get guidedDealFlopBody =>
      'Glissez un rang vers une couleur pour sélectionner une carte. Appuyez sur une carte sélectionnée pour la retirer. Choisissez 3 cartes pour le flop.';

  @override
  String get guidedDealTurnTitle => 'Distribuer le Turn';

  @override
  String get guidedDealTurnBody => 'Sélectionnez 1 carte pour le Turn.';

  @override
  String get guidedDealRiverTitle => 'Distribuer le River';

  @override
  String get guidedDealRiverBody => 'Sélectionnez 1 carte pour le River.';

  @override
  String get guidedStackRingTitle => 'Plage de Stack';

  @override
  String get guidedStackRingBody =>
      'Appuyez et maintenez l\'anneau, faites pivoter votre doigt pour sélectionner une plage de stack, puis relâchez. Cela vous aide à configurer les stacks de vos adversaires avant le flop.';

  @override
  String get guidedTableButtonTitle => 'Gérer la Table';

  @override
  String get guidedTableButtonBody =>
      'Appuyez sur ce bouton pour gérer les joueurs, mettre à jour les stacks, changer les places ou déplacer le bouton du dealer.';

  @override
  String get guidedBlindsPillTitle => 'Blinds';

  @override
  String get guidedBlindsPillBody =>
      'Appuyez ici pour mettre à jour les niveaux de blinds à tout moment — utile quand les niveaux du tournoi augmentent.';

  @override
  String get guidedNextHandTitle =>
      'Encore une main';

  @override
  String get guidedNextHandBody =>
      'Bien joué ! Enregistrons une main de plus. Touchez Main suivante et jouez-la vous-même.';

  @override
  String get guidedInfoButtonTitle => 'Guide des Gestes';

  @override
  String get guidedInfoButtonBody =>
      'Appuyez sur ce bouton à tout moment pour voir tous les contrôles gestuels disponibles pour enregistrer les actions.';

  @override
  String get guidedSessionInfoTitle => 'Détails de Session';

  @override
  String get guidedSessionInfoBody =>
      'Parfait ! Touchez ici pour ouvrir les détails de votre session — on continue là-bas.';

  @override
  String get guidedAddOnTitle => 'Add-Ons et Rebuys';

  @override
  String get guidedAddOnBody => 'Gérez vos add-ons et rebuys ici.';

  @override
  String get guidedUpdateStackTitle => 'Mettre à jour le Stack';

  @override
  String get guidedUpdateStackBody =>
      'Mettez à jour votre stack manuellement et prenez des notes rapides. Elles apparaîtront dans votre graphique de stack.';

  @override
  String get guidedStackChartTitle => 'Graphique de Stack';

  @override
  String get guidedStackChartBody =>
      'Touchez n\'importe quel point pour voir comment se déroule votre partie.';

  @override
  String get guidedStopSessionTitle =>
      'Terminez votre session';

  @override
  String get guidedStopSessionBody =>
      'Touchez le bouton stop pour terminer votre session — nous vous montrerons ensuite où elle est enregistrée.';

  @override
  String get guidedTableIntroTitle =>
      'Votre table';

  @override
  String get guidedTableIntroBody =>
      'C\'est ici que vous enregistrez les actions. Fold : glissez à gauche. Check / Call : touchez. Bet / Raise : appuyez & glissez vers le haut. Enregistrons la première main !';

  @override
  String get guidedUndoTitle =>
      'Annulez à tout moment';

  @override
  String get guidedUndoBody =>
      'Une erreur ? Touchez Annuler la dernière action pour revenir en arrière.';

  @override
  String get guidedSessionInfoFinishTitle =>
      'Terminer';

  @override
  String get guidedSessionInfoFinishBody =>
      'Prêt à conclure ? Touchez ici pour ouvrir les détails de votre session et terminer.';

  @override
  String get guidedDetailsBackTitle =>
      'Retour à la table';

  @override
  String get guidedDetailsBackBody =>
      'Touchez ici pour revenir et enregistrer une main de plus.';

  @override
  String get guidedLogOneMoreTitle =>
      'Enregistrez une main de plus';

  @override
  String get guidedLogOneMoreBody =>
      'Touchez Main suivante pour la distribuer, puis jouez-la vous-même.';

  @override
  String get guidedTourCompleteTitle => 'Tour terminé !';

  @override
  String get guidedTourCompleteBody =>
      'Tout est prêt ! Vous pouvez retrouver vos données de session dans l\'onglet Sessions à tout moment.';

  @override
  String get kbStatsTitle => 'Vos statistiques';

  @override
  String get kbClubsTitle => 'Clubs et événements';

  @override
  String get kbStatsIntro =>
      'Final Table suit 7 métriques clés du poker pour vous aider à comprendre et améliorer votre jeu.';

  @override
  String get kbClubsIntro =>
      'Les clubs vous permettent de vous connecter avec votre salle de poker locale et de suivre les parties en direct.';

  @override
  String get kbVpipName => 'VPIP';

  @override
  String get kbVpipFullName => 'Voluntarily Put \$ In Pot';

  @override
  String get kbVpipDescription =>
      'À quelle fréquence vous entrez volontairement dans un pot (hors posts de blinde). Un VPIP élevé signifie que vous jouez beaucoup de mains ; un VPIP bas signifie que vous êtes sélectif.';

  @override
  String get kbPfrName => 'PFR';

  @override
  String get kbPfrFullName => 'Preflop Raise';

  @override
  String get kbPfrDescription =>
      'À quelle fréquence vous relancez avant le Flop. L\'écart entre VPIP et PFR montre à quelle fréquence vous limpez ou cold-callez.';

  @override
  String get kbThreeBetName => '3-Bet';

  @override
  String get kbThreeBetFullName => 'Three-Bet Percentage';

  @override
  String get kbThreeBetDescription =>
      'À quelle fréquence vous re-relancez l\'open raise d\'un adversaire avant le Flop. Un 3-Bet% plus élevé indique un style preflop agressif.';

  @override
  String get kbFoldTo3BetName => 'Fold to 3-Bet';

  @override
  String get kbFoldTo3BetFullName => 'Fold to Three-Bet';

  @override
  String get kbFoldTo3BetDescription =>
      'À quelle fréquence vous vous couchez après avoir relancé et fait face à un 3-Bet. Si trop élevé, les adversaires peuvent vous exploiter avec des 3-Bets légers.';

  @override
  String get kbCBetName => 'C-Bet';

  @override
  String get kbCBetFullName => 'Continuation Bet';

  @override
  String get kbCBetDescription =>
      'À quelle fréquence vous misez au Flop après avoir été le dernier agresseur preflop. Une mise standard montrant la force.';

  @override
  String get kbStealName => 'Steal';

  @override
  String get kbStealFullName => 'Blind Steal Attempt';

  @override
  String get kbStealDescription =>
      'À quelle fréquence vous ouvrez avec une relance depuis une position tardive (CO, BTN, SB) quand le pot est ouvert, cherchant à voler les blindes.';

  @override
  String get kbCheckRaiseName => 'Check-Raise';

  @override
  String get kbCheckRaiseFullName => 'Flop Check-Raise';

  @override
  String get kbCheckRaiseDescription =>
      'À quelle fréquence vous checkez puis relancez au Flop. Un mouvement trompeur qui peut piéger les adversaires agressifs.';

  @override
  String get kbLiveEventsTitle => 'Événements en direct';

  @override
  String get kbLiveEventsDescription =>
      'Les gestionnaires de clubs créent des événements avec plusieurs tables. Rejoignez un événement pour faire partie du classement en direct.';

  @override
  String get kbLiveRankingsTitle => 'Live Rankings';

  @override
  String get kbLiveRankingsDescription =>
      'Voyez où vous vous situez en temps réel pendant les événements. Les classements se mettent à jour après chaque main.';

  @override
  String get kbOpponentTrackingTitle => 'Suivi des adversaires';

  @override
  String get kbOpponentTrackingDescription =>
      'Les joueurs que vous affrontez au club sont automatiquement suivis. Sauvegardez des adversaires pour créer des profils détaillés.';

  @override
  String get kbQrSeatTitle => 'Attribution de siège par QR';

  @override
  String get kbQrSeatDescription =>
      'Scannez un code QR à votre table pour rejoindre la session instantanément. Vos mains sont automatiquement enregistrées par le dealer.';

  @override
  String get kbDealerLoggingTitle => 'Enregistrement assisté par dealer';

  @override
  String get kbDealerLoggingDescription =>
      'Les dealers utilisent des commandes vocales pour enregistrer les actions de toute la table. Aucune saisie manuelle n\'est nécessaire de la part des joueurs.';

  @override
  String get kbSessionStatsTitle => 'Statistiques de session';

  @override
  String get kbSessionStatsDescription =>
      'Après chaque session, consultez votre profit/perte et l\'évolution de vos statistiques. Chaque main est enregistrée.';

  @override
  String get qrJoinTableInfo => 'INFO TABLE';

  @override
  String qrJoinSeat(int number) {
    return 'Siège $number';
  }

  @override
  String get qrJoinTableFallback => 'Table';

  @override
  String get qrJoinClubLabel => 'Club';

  @override
  String get qrJoinTableLabel => 'Table';

  @override
  String get qrJoinSeatLabel => 'Siège';

  @override
  String get qrJoinStatusLabel => 'Statut';

  @override
  String get qrJoinActiveGame => 'Partie active';

  @override
  String get qrJoinWaitingStatus => 'En attente';

  @override
  String dealerQrTablesAssigned(int count) {
    return '$count table(s) assignée(s) à cet événement';
  }

  @override
  String dealerQrTableNotAssigned(String tableName) {
    return '$tableName n\'est pas assigné à cet événement.';
  }

  @override
  String dealerTablePlayerAdded(String playerName, int seatNumber) {
    return '$playerName ajouté au Siège $seatNumber';
  }

  @override
  String memberTableSeatedOpen(int seated, int open) {
    return '$seated occupés  •  $open libres';
  }

  @override
  String get memberTablePlayer => 'Joueur';

  @override
  String get memberTableEmpty => 'Vide';

  @override
  String get memberTableFallback => 'Table';

  @override
  String get homeEventTypeTournament => 'Tournoi';

  @override
  String get homeEventTypeCashGame => 'Cash Game';

  @override
  String get homeEventTypeHomeGame => 'Partie à domicile';

  @override
  String get homeEventTypeOnline => 'En ligne';

  @override
  String get bankrollSheetTitle => 'Ajouter un résultat';

  @override
  String get bankrollSheetEditSection => 'Modifier le bankroll';

  @override
  String get bankrollSheetGoalLabel => 'Objectif de bankroll';

  @override
  String get bankrollSheetCurrentLabel => 'Bankroll actuel';

  @override
  String get bankrollSheetGoalUpdated => 'Objectif mis à jour';

  @override
  String get bankrollSheetBankrollUpdated => 'Bankroll mis à jour';

  @override
  String get sessionEndResultTitle => 'Résultat de session';

  @override
  String get sessionEndTournamentTitle => 'Résultat du tournoi';

  @override
  String get sessionEndProfit => 'Profit';

  @override
  String get sessionEndLoss => 'Perte';

  @override
  String get sessionEndApply => 'Appliquer';

  @override
  String get sessionEndSkip => 'Passer';

  @override
  String get sessionEndFinishingPosition => 'Position finale';

  @override
  String get sessionEndFieldSize => 'Nombre de participants';

  @override
  String get sessionEndPrizeWon => 'Prix remporté';

  @override
  String get sessionEndTotalInvested => 'Total investi';

  @override
  String sessionEndCalculatedProfit(String amount) {
    return 'Profit calculé : $amount';
  }

  @override
  String get onboardingWelcomeSubtitle =>
      'Votre compagnon poker personnel pour enregistrer vos mains, suivre vos statistiques et améliorer votre jeu.';

  @override
  String get onboardingNicknameTitle => 'Commençons par choisir votre pseudo';

  @override
  String get onboardingNicknameSubtitle =>
      'Vous pouvez basculer entre votre nom et votre pseudo et le modifier à tout moment.';

  @override
  String get onboardingCurrencyTitle => 'Dans quelle devise jouez-vous ?';

  @override
  String get onboardingCurrencySubtitle =>
      'Caves, retraits et statistiques l\'utiliseront. Modifiable à tout moment dans les réglages.';

  @override
  String get onboardingGameTypeTitle => 'Choisissez votre type de jeu';

  @override
  String get onboardingGameTypeSubtitle =>
      'Nous adapterons votre expérience en fonction de ce que vous jouez. Dites-nous, jouez-vous principalement du cash ou du MTT?';

  @override
  String get onboardingGameTypeCash => 'Cash Game';

  @override
  String get onboardingGameTypeTournament => 'Tournament (MTT)';

  @override
  String get onboardingJourneyTitle =>
      'Où en êtes-vous dans votre parcours poker ?';

  @override
  String get onboardingJourneySubtitle =>
      'Cela nous aide à personnaliser votre expérience.';

  @override
  String get onboardingJourneyBeginner => 'Débutant';

  @override
  String get onboardingJourneyFun => 'Je joue pour le plaisir';

  @override
  String get onboardingJourneyRegular => 'Joueur régulier';

  @override
  String get onboardingJourneyPro => 'Pro';

  @override
  String get onboardingMonthlySessionsTitle =>
      'Combien de sessions jouez-vous environ par mois ?';

  @override
  String get onboardingMonthlySessionsSubtitle =>
      'Faites glisser la roue pour sélectionner vos sessions mensuelles.';

  @override
  String get onboardingMonthlySessionsUnit => 'sessions / mois';

  @override
  String get onboardingPurposeTitle =>
      'Quel est votre objectif principal en utilisant Final Table ?';

  @override
  String get onboardingPurposeSubtitle =>
      'Sélectionnez toutes les réponses applicables.';

  @override
  String get onboardingPurposeLogging => 'Enregistrer les mains';

  @override
  String get onboardingPurposeBankroll => 'Suivre le bankroll';

  @override
  String get onboardingPurposeOpponents => 'Analyser les adversaires';

  @override
  String get onboardingPurposeActions =>
      'Enregistrer chaque action pour analyse ultérieure';

  @override
  String get onboardingPurposeStudying => 'Étudier des spots';

  @override
  String get onboardingPurposeSharing =>
      'Partager les historiques de mains avec des amis';

  @override
  String get onboardingPurposeAi => 'Analyser avec AI';

  @override
  String get onboardingPurposeExport =>
      'Exporter les mains vers des outils GTO';

  @override
  String get onboardingPurposeStacks =>
      'Suivre les tailles de stack en tournoi';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingGetStarted => 'Commencer';

  @override
  String get onboardingSkipNickname => 'Passer pour l\'instant';

  @override
  String get drillTitle => 'Training Drills';

  @override
  String get drillSaveLineup => 'Save lineup';

  @override
  String get drillSaveLineupHint => 'e.g. Tuesday home game';

  @override
  String get drillDeleteLineup => 'Delete lineup';

  @override
  String drillDeleteLineupMessage(String name) {
    return 'Remove \"$name\" from your saved lineups?';
  }

  @override
  String get drillSavedLineups => 'SAVED LINEUPS';

  @override
  String get drillTable => 'TABLE';

  @override
  String get drillSeats => 'SEATS';

  @override
  String get drillSeatsInstruction =>
      'Tap a seat to assign an opponent or move yourself.';

  @override
  String get drillSaveThisLineup => 'Save this lineup';

  @override
  String get drillStartDrill => 'Start Drill';

  @override
  String get drillPlayers => 'Players';

  @override
  String get drillStackDepth => 'Stack depth';

  @override
  String get drillFormat => 'Format';

  @override
  String get drillFormatCash => 'Cash';

  @override
  String get drillFormatAnte => 'MTT · Ante';

  @override
  String get drillScouting => 'SCOUTING';

  @override
  String get drillYou => 'You';

  @override
  String drillSeatNumber(int seat) {
    return 'Seat $seat';
  }

  @override
  String get drillPremiumTitle => 'Train against your real opponents';

  @override
  String get drillPremiumDescription =>
      'Seat the players you actually face, drill preflop spots against bots that play with their measured tendencies, and get exploit-based feedback on every decision.';

  @override
  String get drillUpgradeToPremium => 'Upgrade to Premium';

  @override
  String get drillSearchOpponents => 'Search opponents';

  @override
  String get drillThisIsMe => 'This is me';

  @override
  String get drillMoveYourSeatHere => 'Move your seat here';

  @override
  String get drillGenericBot => 'Generic bot';

  @override
  String get drillBalancedRegular => 'Balanced regular';

  @override
  String drillHandNumber(int number) {
    return 'Hand #$number';
  }

  @override
  String drillHandedLabel(int stack, int players) {
    return '${stack}BB · $players-handed';
  }

  @override
  String get drillPot => 'POT';

  @override
  String get drillWalkedNote => 'Everyone folded — you win the blinds.';

  @override
  String drillWonUncontestedNote(String pot) {
    return 'Everyone folded — you take it down (${pot}BB).';
  }

  @override
  String get drillReachedFlopNote =>
      'Hand goes to the flop — preflop drill complete.';

  @override
  String get drillHandOverNote => 'Hand over.';

  @override
  String get drillCorrect => 'CORRECT';

  @override
  String get drillClose => 'CLOSE';

  @override
  String get drillMistake => 'MISTAKE';

  @override
  String drillYouChose(String action) {
    return '· you chose $action';
  }

  @override
  String drillTopPercent(int percent) {
    return 'top $percent%';
  }

  @override
  String drillLineupChanges(String gto, String exploit) {
    return 'This lineup changes the play: GTO ${gto}s, exploit ${exploit}s';
  }

  @override
  String get drillGto => 'GTO';

  @override
  String get drillExploit => 'EXPLOIT';

  @override
  String get drillContinue => 'Continue';

  @override
  String get drillGotIt => 'Got it';

  @override
  String get drillRaiseTo => 'Raise to:';

  @override
  String get drillJam => 'JAM';

  @override
  String drillPotLabel(String pot) {
    return 'Pot ${pot}BB';
  }

  @override
  String drillToCall(String amount) {
    return '${amount}BB to call';
  }

  @override
  String get drillFold => 'FOLD';

  @override
  String get drillCheck => 'CHECK';

  @override
  String get drillCall => 'CALL';

  @override
  String get drillRaise => 'RAISE';

  @override
  String get drillNextHand => 'Next Hand';

  @override
  String get drillSummaryTitle => 'Drill Summary';

  @override
  String get drillAccuracy => 'Accuracy';

  @override
  String get drillDecisions => 'Decisions';

  @override
  String get drillCorrectLabel => 'Correct';

  @override
  String get drillCloseLabel => 'Close';

  @override
  String get drillMistakes => 'Mistakes';

  @override
  String get drillWhereYouLeaked => 'WHERE YOU LEAKED';

  @override
  String drillMistakeDetail(String handClass, String position,
      String heroAction, String recommendedAction) {
    return '$handClass · $position · you chose $heroAction, $recommendedAction was right';
  }

  @override
  String get drillKeepDrilling => 'Keep Drilling';

  @override
  String get drillEndDrill => 'End Drill';

  @override
  String get drillActionSb => 'SB 0.5';

  @override
  String get drillActionBb => 'BB 1';

  @override
  String get drillActionFold => 'FOLD';

  @override
  String get drillActionCheck => 'CHECK';

  @override
  String get drillActionLimp => 'LIMP';

  @override
  String drillActionCall(String amount) {
    return 'CALL $amount';
  }

  @override
  String drillActionRaise(String amount) {
    return 'RAISE $amount';
  }

  @override
  String drillAction3bet(String amount) {
    return '3-BET $amount';
  }

  @override
  String drillAction4bet(String amount) {
    return '4-BET $amount';
  }

  @override
  String drillActionJam(String amount) {
    return 'JAM $amount';
  }

  @override
  String get rangeCash => 'Cash';

  @override
  String get rangeTourney => 'Tourney';

  @override
  String get rangeAllStacks => 'All stacks';

  @override
  String get rangeStackDepth => 'Stack depth';

  @override
  String get rangeAllPositions => 'All';

  @override
  String get rangeAllSpots => 'All spots';

  @override
  String get rangeRfi => 'RFI';

  @override
  String get rangeVsRaise => 'vs Raise';

  @override
  String rangeHandsLogged(int count) {
    return '$count / 169 hands logged';
  }

  @override
  String get rangeSyncingHistory => 'Syncing your hand history…';

  @override
  String get rangePreflopHeader =>
      'PREFLOP RANGE — BUILT FROM YOUR LOGGED HANDS';

  @override
  String get rangeEmptyHint =>
      'Your preflop chart builds itself: log hands and enter your hole cards, and each starting hand fills in with how you actually played it before the flop.';

  @override
  String rangeSpotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'spots',
      one: 'spot',
    );
    return '$count preflop $_temp0';
  }

  @override
  String get rangeRfiSuffix => ' · RFI';

  @override
  String get rangeVsRaiseSuffix => ' · vs raise';

  @override
  String get rangeRaised => 'Raised';

  @override
  String get rangeRaisedLabel => 'Raised';

  @override
  String get rangeCalled => 'Called';

  @override
  String get rangeChecked => 'Checked';

  @override
  String get rangeFolded => 'Folded';

  @override
  String get rangeCalledLimped => 'Called / limped';

  @override
  String get rangeToday => 'Today';

  @override
  String get rangeYesterday => 'Yesterday';

  @override
  String rangeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String rangeWeeksAgo(int weeks) {
    return '${weeks}w ago';
  }

  @override
  String rangeMonthsAgo(int months) {
    return '${months}mo ago';
  }

  @override
  String rangeYearsAgo(int years) {
    return '${years}y ago';
  }

  @override
  String rangeWonBB(int bb) {
    return 'W $bb BB';
  }

  @override
  String rangeLostBB(int bb) {
    return '– $bb BB';
  }

  @override
  String rangeScoutingTitle(String name) {
    return '$name · Scouting report';
  }

  @override
  String get rangeShowdownBias =>
      'Shown hands skew toward value and called-down hands — they tell you what is in the range and its shape, not the full range.';

  @override
  String get rangeNoShowdowns =>
      'Log a few hands to showdown with this opponent\'s cards entered, and their range will start filling in here.';

  @override
  String get rangePremium => 'Premium';

  @override
  String get rangeStrong => 'Strong';

  @override
  String get rangeMedium => 'Medium';

  @override
  String get rangeWeak => 'Weak';

  @override
  String get profileSettings => 'Profile Settings';

  @override
  String get profileEditName => 'Edit Name';

  @override
  String get profileYourName => 'Your name';

  @override
  String get profileEditEmail => 'Edit email';

  @override
  String get profileEditEmailHint =>
      'Email changes require account re-authentication. Contact support to change your email.';

  @override
  String get profileChangePassword => 'Change Password';

  @override
  String get profilePasswordMask => '***********';

  @override
  String get profileContactSupport => 'Contact support';

  @override
  String get profileShareFeedback => 'Share your feedback';

  @override
  String get profileEmailUpdates => 'Email updates';

  @override
  String get profileFollowUs => 'Follow @finaltable';

  @override
  String get profileEdit => 'Edit';

  @override
  String get profileEditUsername => 'Edit username';

  @override
  String get profileUsernameHint => 'username';

  @override
  String get profileInsteadOfName =>
      'instead of your name in events and hand logging';

  @override
  String get profileUsernameTaken => 'Username already taken';

  @override
  String get profileFixUsernameError => 'Fix username error before saving';

  @override
  String get profileUsernameUnavailable => 'Username no longer available';

  @override
  String get profileSavedSuccessfully => 'Saved successfully';

  @override
  String get profileDeleteAccount => 'Delete Account';

  @override
  String get profileDeleteAccountMessage =>
      'This will permanently delete your account and all associated data. This action cannot be undone.\n\nIf you have an active subscription, please cancel it first in your device settings.';

  @override
  String get profileChangePasswordTitle => 'Change Password';

  @override
  String get profileChangePasswordMessage =>
      'We\'ll send a password reset link to your email address.';

  @override
  String profileResetEmailSent(String email) {
    return 'Password reset email sent to $email';
  }

  @override
  String get profileResetEmailFailed => 'Failed to send reset email';

  @override
  String get profileSendResetEmail => 'Send Reset Email';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsClubs => 'Clubs';

  @override
  String get settingsBankroll => 'Bankroll';

  @override
  String get settingsRegisterClub => 'Register Club';

  @override
  String get settingsChooseLanguage => 'Choose Language';

  @override
  String get settingsMoreLanguagesLater =>
      'More languages will be announced later';

  @override
  String get settingsChoose => 'Choose';

  @override
  String get settingsChooseCurrency => 'Choose Currency';

  @override
  String get settingsMoreCurrenciesLater =>
      'More currencies will be announced later';

  @override
  String get settingsNoClubs => 'No clubs';

  @override
  String get settingsNoClubsYet => 'No Clubs Yet';

  @override
  String get settingsNoClubsHint => 'Register or join a club to see them here.';

  @override
  String get settingsRegisterAClub => 'Register a Club';

  @override
  String get settingsYourClubs => 'Your Clubs';

  @override
  String get settingsChooseTour => 'Choose which tour to replay';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsPending(int count) {
    return '$count pending';
  }

  @override
  String get settingsGetPlus => 'Get Final Table Plus';

  @override
  String get settingsGetPlusSubtitle => 'Log more hands and AI analysis';

  @override
  String get statsHandsLogged => 'Hands Logged';

  @override
  String get statsVpip => 'VPIP';

  @override
  String get statsPfr => 'PFR';

  @override
  String get stats3Bet => '3-Bet';

  @override
  String get statsCBet => 'C-Bet';

  @override
  String get statsSteal => 'Steal';

  @override
  String get statsCheckRaise => 'Check-Raise';

  @override
  String get statsRanges => 'Ranges';

  @override
  String get statsStats => 'Stats';

  @override
  String get loggingChoose => 'Choose';

  @override
  String get loggingTrainingDrills => 'Training Drills';

  @override
  String get loggingTrainingDrillsSubtitle =>
      'Practice preflop spots against your real opponents';

  @override
  String get loggingPro => 'PRO';

  @override
  String get opponentsEnterName => 'Enter name';

  @override
  String get opponentsAddNotes => 'Add notes';

  @override
  String get opponentsNoNotesAdded => 'No notes added';

  @override
  String get opponentsDeleteOpponent => 'Delete opponent';

  @override
  String get seatManagePlayers => 'Manage Players';

  @override
  String get seatUpdatePlayerInfo => 'Update player information';

  @override
  String get seatStartSession => 'Start Session';

  @override
  String get seatSaveChanges => 'Save Changes';

  @override
  String get seatYou => 'You';

  @override
  String get seatKeep => 'Keep';

  @override
  String get seatMove => 'Move';

  @override
  String get tableManageTitle => 'Table';

  @override
  String get tableButtonOnEmpty => 'Button on Empty Seat';

  @override
  String get handPlayerLabel => 'Player ';

  @override
  String get handBbLabel => 'BB';

  @override
  String get handRaiseLabel => 'RAISE';

  @override
  String get handBetLabel => 'BET';

  @override
  String get handFoldLabel => 'FOLD';

  @override
  String get handRaiseAction => 'Raise';

  @override
  String get handBetAction => 'Bet';

  @override
  String get handOnlyOneRemaining => 'Hand ends: Only one player remaining';

  @override
  String get handSessionTitle => 'Session';

  @override
  String get settingsSkipHandScouting => 'Skip Hand Scouting';

  @override
  String get settingsSkipHandScoutingDesc =>
      'Track opponent actions when you fold preflop';

  @override
  String get skipScoutTitle => 'What happened?';

  @override
  String get skipScoutNoRaise => 'No one raised';

  @override
  String get skipScoutSkip => 'Skip';

  @override
  String get paywallNotNow => 'Pas maintenant';

  @override
  String get paywallFreeTrialBadge14 => 'Essai gratuit de 14 jours';

  @override
  String get freeTierHandLimitTitle => 'Limite de mains atteinte';

  @override
  String freeTierHandLimitFree(int free, int pro) {
    return 'Les comptes gratuits peuvent enregistrer jusqu\'à $free mains par session. Passez à Pro pour $pro mains ou à Elite pour illimité.';
  }

  @override
  String freeTierHandLimitPro(int pro) {
    return 'Les comptes Pro peuvent enregistrer jusqu\'à $pro mains par session. Passez à Elite pour un enregistrement illimité.';
  }

  @override
  String get freeTierOpponentLimitTitle => 'Limite d\'adversaires atteinte';

  @override
  String freeTierOpponentLimitFree(int free, int pro) {
    return 'Les comptes gratuits peuvent sauvegarder jusqu\'à $free profils d\'adversaires. Passez à Pro pour $pro ou à Elite pour illimité.';
  }

  @override
  String freeTierOpponentLimitPro(int pro) {
    return 'Les comptes Pro peuvent sauvegarder jusqu\'à $pro profils d\'adversaires. Passez à Elite pour des adversaires illimités.';
  }

  @override
  String get freeTierUpgrade => 'Améliorer';

  @override
  String get freeTierNotNow => 'Pas maintenant';

  @override
  String get quotaMonthlyLimitTitle => 'Limite mensuelle atteinte';

  @override
  String quotaAiLimitElite(int max) {
    return 'Vous avez utilisé toutes vos $max analyses IA ce mois-ci. Votre quota se réinitialise le mois prochain.';
  }

  @override
  String quotaAiLimitPro(int max, int elite) {
    return 'Vous avez utilisé toutes vos $max analyses IA ce mois-ci (limite Pro). Passez à Elite pour $elite analyses/mois.';
  }

  @override
  String get quotaExportLimitTitle => 'Limite d\'exportations atteinte';

  @override
  String quotaExportLimitPro(int max) {
    return 'Vous avez utilisé toutes vos $max exportations ce mois-ci (limite Pro). Passez à Elite pour des exportations illimitées.';
  }

  @override
  String quotaSessionExportLimitPro(int max) {
    return 'Vous avez utilisé toutes vos $max exportations de session ce mois-ci (limite Pro). Passez à Elite pour des exportations illimitées.';
  }

  @override
  String get quotaUpgradeToElite => 'Passer à Elite';

  @override
  String get quotaOk => 'OK';

  @override
  String get statsLockedTitle => 'Améliorez pour débloquer';

  @override
  String get statsLockedSubtitle =>
      'Cette section est disponible en Pro et supérieur.';

  @override
  String get statsLockedUpgrade => 'Améliorer';

  @override
  String get paywallBestValue => 'MEILLEURE OFFRE';

  @override
  String get paywallWelcomeElite => 'Bienvenue dans Elite !';

  @override
  String get paywallWelcomeClub => 'Bienvenue dans Club !';

  @override
  String get paywallStartWithPro => 'Commencer avec Pro';

  @override
  String get paywallGetEliteAction => 'Obtenir Elite';

  @override
  String get paywallGetClubAction => 'Obtenir Club';

  @override
  String get paywallCurrentPlan => 'Plan actuel';

  @override
  String get paywallProFeature1 => '50 mains par session';

  @override
  String get paywallProFeature2 => 'Historique de 90 jours';

  @override
  String get paywallProFeature3 => '15 profils d\'adversaires';

  @override
  String get paywallProFeature4 => '10 analyses IA / mois';

  @override
  String get paywallProFeature5 => '30 exportations / mois';

  @override
  String get paywallEliteFeature4 => 'Enregistrement de mains illimité';

  @override
  String get paywallEliteFeature5 => 'Historique de sessions complet';

  @override
  String get paywallEliteFeature6 => 'Adversaires illimités';

  @override
  String get paywallEliteFeature7 => '30 analyses IA / mois';

  @override
  String get paywallEliteFeature8 => 'Exportations illimitées';

  @override
  String get paywallClubFeature1 => 'Tout dans Elite';

  @override
  String get paywallClubFeature2 => 'Créez et gérez votre propre club';

  @override
  String get paywallClubFeature3 => 'Invitez des dealers et gérez les membres';

  @override
  String get paywallClubFeature4 =>
      'Organisez des événements multi-tables avec classements en direct';

  @override
  String get profileTierOverride => 'Remplacer le niveau d\'abonnement';

  @override
  String profileTierOverrideSubtitleReal(String tier) {
    return 'Réel : $tier';
  }

  @override
  String profileTierOverrideSubtitleActive(String tier) {
    return 'Remplacé : $tier';
  }

  @override
  String get profileTierFree => 'gratuit';

  @override
  String get profileTierPro => 'Pro';

  @override
  String get profileTierElite => 'Elite';

  @override
  String get profileTierClub => 'Club';

  @override
  String get authExpContinueApple => 'Continuer avec Apple';

  @override
  String get authExpLinkAppleTitle => 'Lier le compte Apple';

  @override
  String authExpLinkAppleMessage(String email) {
    return 'Un compte avec $email existe déjà. Entrez votre mot de passe pour lier votre compte Apple.';
  }
}
