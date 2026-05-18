// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navHome => 'Inicio';

  @override
  String get navOpponents => 'Oponentes';

  @override
  String get navSessions => 'Sesiones';

  @override
  String get navProfile => 'Perfil';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonError => 'Error';

  @override
  String get commonLoading => 'Cargando...';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Sí';

  @override
  String get commonNo => 'No';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonNoData => 'No hay datos disponibles';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonNotAvailable => 'N/D';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get commonUpdate => 'Actualizar';

  @override
  String get commonClear => 'Limpiar';

  @override
  String get commonToday => 'Hoy';

  @override
  String get statsTitle => 'Estadísticas';

  @override
  String get statsSubtitle => 'Análisis avanzado';

  @override
  String get statsHandsPlayed => 'Manos jugadas';

  @override
  String get statsFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get statsWinRate => 'Win Rate';

  @override
  String get statsSessionStatistics => 'Estadísticas de sesión';

  @override
  String get statsSessions => 'Sesiones';

  @override
  String get statsTotalTime => 'Tiempo total';

  @override
  String get statsAvgSession => 'Sesión promedio';

  @override
  String get statsPlayToSee => 'Juega sesiones para ver estadísticas de tiempo';

  @override
  String get statsGeneral => 'General';

  @override
  String get statsCash => 'Cash';

  @override
  String get statsTournament => 'Torneo';

  @override
  String get statsTotalBuyIn => 'Buy-In total';

  @override
  String get statsTotalCashOut => 'Cash-Out total';

  @override
  String get statsNetProfit => 'Beneficio neto';

  @override
  String get statsItm => 'ITM%';

  @override
  String get statsAvgFinish => 'Posición media';

  @override
  String get statsBestFinish => 'Mejor posición';

  @override
  String get statsRoi => 'ROI%';

  @override
  String get statsFinalTables => 'Mesas finales';

  @override
  String get statsAvgBuyIn => 'Buy-In medio';

  @override
  String get statsAvgFieldSize => 'Campo medio';

  @override
  String get statsHourlyRate => 'Ganancia/hora';

  @override
  String get statsHourlyRateNotAvailable =>
      'Disponible después de 60 min de seguimiento';

  @override
  String get statsLoadingMessage => 'Cargando estadísticas...';

  @override
  String get statsFetchingMessage => 'Obteniendo estadísticas del usuario...';

  @override
  String statsFailedToLoad(String error) {
    return 'Error al cargar estadísticas: $error';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSubtitle => 'Elegir idioma de la app';

  @override
  String get settingsLanguageSystem => 'Predeterminado del sistema';

  @override
  String get settingsCurrency => 'Moneda';

  @override
  String get settingsKnowledgeBase => 'BASE DE CONOCIMIENTO';

  @override
  String get settingsGuidedTour => 'Tour guiado';

  @override
  String get settingsGuidedTourSubtitle => 'Repetir tours de introducción';

  @override
  String get settingsFullLoggingTour => 'Tour de registro completo';

  @override
  String get settingsFullLoggingTourSubtitle =>
      'Flujo completo de seguimiento de sesión';

  @override
  String get settingsIndividualLoggingTour => 'Tour de registro individual';

  @override
  String get settingsIndividualLoggingTourSubtitle =>
      'Flujo de seguimiento de mano individual';

  @override
  String get settingsUnderstandingStats => 'Entendiendo tus estadísticas';

  @override
  String get settingsUnderstandingStatsSubtitle =>
      'Aprende qué significa cada métrica';

  @override
  String get settingsClubsEvents => 'Clubs y eventos';

  @override
  String get settingsClubsEventsSubtitle => 'Cómo funciona el juego en club';

  @override
  String get settingsLegal => 'LEGAL';

  @override
  String get settingsTermsOfService => 'Términos de servicio';

  @override
  String get settingsTermsOfServiceSubtitle =>
      'Ver nuestros términos de servicio';

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsPrivacyPolicySubtitle =>
      'Ver nuestra política de privacidad';

  @override
  String get settingsAdmin => 'ADMIN';

  @override
  String get settingsClubRequests => 'Solicitudes de club';

  @override
  String get settingsClubRequestsSubtitle =>
      'Gestionar solicitudes de registro';

  @override
  String get settingsSupportRequests => 'Solicitudes de soporte';

  @override
  String get settingsSupportRequestsSubtitle => 'Gestionar tickets de soporte';

  @override
  String get settingsNotificationTester => 'Probador de notificaciones';

  @override
  String get settingsNotificationTesterSubtitle =>
      'Vista previa de diseños de notificación';

  @override
  String get profileUpgrade => 'Mejorar plan';

  @override
  String get profileUsername => 'Nombre de usuario';

  @override
  String get profileNotSet => 'No establecido';

  @override
  String get profileChange => 'Cambiar';

  @override
  String get profileSetUsername => 'Establecer nombre de usuario';

  @override
  String get profileUseNicknameInGames => 'Usar apodo en juegos';

  @override
  String profileUseNicknameDescription(String username) {
    return 'Mostrar @$username en lugar de tu nombre en eventos y registro de manos';
  }

  @override
  String get profileBankrollGoal => 'Meta de Bankroll';

  @override
  String get profileUpdateGoal => 'Actualizar meta';

  @override
  String get profileCurrentBankroll => 'Bankroll actual';

  @override
  String get profileUpdateBankroll => 'Actualizar Bankroll';

  @override
  String get profileAddSessionResult => 'Agregar resultado de sesión';

  @override
  String get profileSessionResultHint =>
      'Ingresa positivo para ganancias, negativo para pérdidas';

  @override
  String get profileAddResult => 'Agregar resultado';

  @override
  String get profileGoalUpdatedSuccess => '¡Meta actualizada exitosamente!';

  @override
  String get profileErrorUpdatingGoal => 'Error al actualizar meta';

  @override
  String get profileBankrollUpdatedSuccess =>
      '¡Bankroll actualizado exitosamente!';

  @override
  String get profileErrorUpdatingBankroll => 'Error al actualizar bankroll';

  @override
  String get profileSessionResultAdded => '¡Resultado de sesión agregado!';

  @override
  String get profileErrorAddingResult => 'Error al agregar resultado de sesión';

  @override
  String get profilePleaseEnterValidAmount =>
      'Por favor ingresa un monto válido';

  @override
  String get profileLogOut => 'Cerrar sesión';

  @override
  String get profileSignOut => 'Cerrar sesión';

  @override
  String get profileSignOutConfirmation =>
      '¿Estás seguro de que deseas cerrar sesión?';

  @override
  String get sessionHistoryTitle => 'Historial de sesiones';

  @override
  String get sessionLast30Days => 'Últimos 30 días';

  @override
  String get sessionUpgradeForFullHistory =>
      'Mejora tu plan para historial completo';

  @override
  String get sessionLoadingMessage => 'Cargando sesiones...';

  @override
  String sessionNoSessions(String gameType) {
    return 'No hay sesiones de $gameType';
  }

  @override
  String sessionPlayToSee(String gameType) {
    return 'Juega algunas manos de $gameType Poker\npara ver los resultados';
  }

  @override
  String get sessionLive => 'En vivo';

  @override
  String sessionPlayersCount(int count) {
    return '$count jugadores';
  }

  @override
  String get sessionSyncingToCloud => 'Sincronizando con la nube...';

  @override
  String get sessionClearAllTitle => '¿Borrar todas las sesiones?';

  @override
  String get sessionClearAllDescription =>
      'Esto eliminará permanentemente todas las sesiones de poker y manos de Firebase y almacenamiento local.';

  @override
  String get sessionClearAllWarning => '¡Esta acción no se puede deshacer!';

  @override
  String get sessionClearAll => 'Borrar todo';

  @override
  String get sessionClearedSuccessfully =>
      'Todas las sesiones han sido eliminadas exitosamente';

  @override
  String sessionHandDetails(int handNumber) {
    return 'Detalles de mano #$handNumber';
  }

  @override
  String get sessionYourCards => 'Tus cartas:';

  @override
  String get sessionBoardCards => 'Cartas del board:';

  @override
  String get sessionPotByStreet => 'Pot por calle:';

  @override
  String get sessionActions => 'Acciones:';

  @override
  String get sessionNoActionsRecorded => 'No se registraron acciones';

  @override
  String get sessionNoCardsRecorded => 'No se registraron cartas';

  @override
  String get sessionFinalPot => 'Pot final:';

  @override
  String sessionChoppedPot(int count) {
    return 'Pot dividido ($count ganadores):';
  }

  @override
  String get sessionWinnerNotAvailable =>
      'Información del ganador no disponible';

  @override
  String get opponentsTitle => 'Oponentes';

  @override
  String opponentsCountFree(int count, int max) {
    return '$count/$max gratis';
  }

  @override
  String opponentsCountPremium(int count) {
    return '$count jugadores rastreados';
  }

  @override
  String get opponentsSearchHint => 'Buscar oponentes...';

  @override
  String get opponentsLoadingMessage => 'Cargando oponentes...';

  @override
  String get opponentsNoResults => 'Sin resultados';

  @override
  String get opponentsEmptyTitle => 'Sin oponentes aún';

  @override
  String get opponentsEmptySubtitle =>
      'Oponentes para rastrear sus estilos de juego y estadísticas';

  @override
  String get opponentsEmptySearchSubtitle =>
      'Intenta con otro término de búsqueda';

  @override
  String get opponentsAddButton => 'Agregar oponente';

  @override
  String opponentsLastSeen(String date) {
    return 'Última vez: $date';
  }

  @override
  String get opponentsHands => 'Manos';

  @override
  String get opponentsEditMenu => 'Editar oponente';

  @override
  String get opponentsDeleteMenu => 'Eliminar oponente';

  @override
  String get opponentsAddDialogTitle => 'Agregar oponente';

  @override
  String get opponentsEditDialogTitle => 'Editar oponente';

  @override
  String get opponentsNameHint => 'Nombre del oponente';

  @override
  String get opponentsNotesHint => 'Notas (Opcional)';

  @override
  String get opponentsPickColor => 'Elige un color';

  @override
  String get opponentsAddedSuccess => 'Oponente agregado exitosamente';

  @override
  String opponentAlreadyExists(String name) {
    return 'Ya existe un oponente llamado \"$name\"';
  }

  @override
  String get opponentsUpdatedSuccess => 'Oponente actualizado exitosamente';

  @override
  String get opponentsDeleteConfirmTitle => '¿Eliminar oponente?';

  @override
  String opponentsDeleteConfirmMessage(String name) {
    return '¿Estás seguro de que deseas eliminar a \"$name\"?\nEsta acción no se puede deshacer';
  }

  @override
  String get opponentsDeletedSuccess => 'Oponente eliminado exitosamente';

  @override
  String get opponentsAnalyticsTitle => 'Análisis de oponentes';

  @override
  String get opponentsAnalyticsTotalLabel => 'Total de oponentes';

  @override
  String get opponentsAnalyticsHandsTracked => 'Manos rastreadas en total';

  @override
  String get opponentsAnalyticsAverage => 'Promedio de manos/oponente';

  @override
  String get opponentsAnalyticsMostPlayed => 'Más jugado contra';

  @override
  String get opponentsAnalyticsDistribution =>
      'Distribución por tipo de jugador:';

  @override
  String get opponentsClearAllTitle => '¿Eliminar todos los oponentes?';

  @override
  String get opponentsClearAllMessage =>
      'Esto eliminará permanentemente todos los datos de oponentes. ¡Esta acción no se puede deshacer!';

  @override
  String get opponentsClearAllButton => 'Eliminar todo';

  @override
  String get opponentsClearedSuccess => 'Todos los oponentes eliminados';

  @override
  String get setupSessionSetup => 'Configuración de sesión';

  @override
  String get setupSessionName => 'Nombre de sesión';

  @override
  String get setupSessionNameHint => 'ej., \"Poker del viernes\"';

  @override
  String get setupGameType => 'Tipo de juego';

  @override
  String get setupCashGame => 'Cash Game';

  @override
  String get setupTournament => 'Tournament';

  @override
  String get setupSmallBlind => 'Small Blind';

  @override
  String get setupBigBlind => 'Big Blind';

  @override
  String get setupBuyInAmount => 'Monto de Buy-in';

  @override
  String get setupEnterAmount => 'Ingresar monto';

  @override
  String get setupStartingStackEqualsBuyIn =>
      'El Stack inicial es igual a tu Buy-in.';

  @override
  String get setupStartingStack => 'Stack inicial';

  @override
  String get setupEnterChipStack => 'Ingresar Stack de fichas';

  @override
  String setupMustBeAtLeastBigBlind(int bigBlind) {
    return 'Debe ser al menos el Big Blind ($bigBlind)';
  }

  @override
  String get setupBbAnte => 'BB Ante';

  @override
  String get setupTableSection => 'MESA';

  @override
  String get setupTableInstructions =>
      'Toca un asiento para agregar un jugador. Arrastra el botón para establecer el Dealer.';

  @override
  String get setupStartSession => 'Iniciar sesión';

  @override
  String get setupMe => 'Yo';

  @override
  String setupPlayerSeat(int seatNumber) {
    return 'Jugador $seatNumber';
  }

  @override
  String get setupHero => 'Hero';

  @override
  String get homeLoadingPokerData => 'Cargando tus datos de poker...';

  @override
  String get homeWelcomeBack => 'Bienvenido de nuevo';

  @override
  String get homeNoActiveSessions => 'No hay sesiones activas';

  @override
  String get homeLiveSessions => 'Sesiones en vivo';

  @override
  String get homeClubNotFound => 'Club no encontrado';

  @override
  String get homeEventNotFound => 'Evento no encontrado';

  @override
  String get homeRecentActivity => 'Actividad reciente';

  @override
  String get homeWinRate => 'Win Rate';

  @override
  String get homeHours => 'Horas';

  @override
  String get homePlayStyle => 'Estilo de juego';

  @override
  String get homePlayStyleTooltip =>
      'Tu estilo de juego se detectará después de registrar 50 manos preflop.';

  @override
  String get homeBankroll => 'Bankroll';

  @override
  String homeBankrollOfGoal(String current, String goal) {
    return '$current de $goal';
  }

  @override
  String homeAmountLeft(String amount) {
    return '$amount restante';
  }

  @override
  String get homeEarnings => 'Ganancias';

  @override
  String homeAvgAmount(String amount) {
    return 'Prom $amount';
  }

  @override
  String get homeNoEarningsDataYet => 'Sin datos de ganancias aún';

  @override
  String get homeRecentSessions => 'Sesiones recientes';

  @override
  String get homeViewAll => 'Ver todo';

  @override
  String get homeNoRecentSessions => 'Sin sesiones recientes';

  @override
  String get homeStartFirstSession => '¡Comienza tu primera sesión de poker!';

  @override
  String get homeAddNew => 'Agregar nuevo';

  @override
  String get homeUpcomingEvents => 'Próximos eventos';

  @override
  String get homeNoRecentEvents => 'Sin eventos recientes';

  @override
  String get homeAddFirstEvent => '¡Agrega tu primer evento de poker!';

  @override
  String homePlayersCount(int count) {
    return '$count jugadores';
  }

  @override
  String homeGoingCount(int count) {
    return '$count asistirán';
  }

  @override
  String get homePrivateGame => 'Juego privado';

  @override
  String get homeHomeGame => 'Home Game';

  @override
  String get homeOnline => 'Online';

  @override
  String get homeEditEvent => 'Editar evento';

  @override
  String get homeDeleteEvent => 'Eliminar evento';

  @override
  String get homeEventName => 'Nombre del evento';

  @override
  String get homeLocationVenue => 'Ubicación/Lugar';

  @override
  String get homeBuyInAmount => 'Monto de Buy-in';

  @override
  String get homeSelectDate => 'Seleccionar fecha:';

  @override
  String get homeSaveChanges => 'Guardar cambios';

  @override
  String homeDeleteEventConfirm(String eventName) {
    return '¿Eliminar $eventName?';
  }

  @override
  String homeDeleteEventDescription(String eventName) {
    return '¿Estás seguro de que deseas eliminar \"$eventName\"?';
  }

  @override
  String get homeEventDeletedSuccessfully => 'Evento eliminado exitosamente';

  @override
  String get homeClubInvitation => 'Invitación al club';

  @override
  String get homeYouveBeenInvitedToJoin => 'Has sido invitado a unirte a';

  @override
  String get homeDecline => 'Rechazar';

  @override
  String get homeAccept => 'Aceptar';

  @override
  String get homeInvitationDeclined => 'Invitación rechazada';

  @override
  String get homeInvitationAccepted => 'Invitación aceptada';

  @override
  String get homeClubInvitations => 'Invitaciones de club';

  @override
  String get homeLater => 'Más tarde';

  @override
  String get homeViewInvitations => 'Ver invitaciones';

  @override
  String get homeNoEarningsDataTitle => 'Sin datos de ganancias aún';

  @override
  String get homeNoEarningsDataDescription =>
      'Agrega algunos resultados de sesión primero para ver tu gráfico de ganancias. Puedes agregar resultados desde la página de Perfil.';

  @override
  String handHandNumber(int number) {
    return 'Mano #$number';
  }

  @override
  String handFreeCounter(int used, int max) {
    return '$used/$max gratis';
  }

  @override
  String get handNextHand => 'Siguiente mano';

  @override
  String get handFoldedToMe => 'Folded to me';

  @override
  String get handUndoLastAction => 'Deshacer última acción';

  @override
  String get handAllInHand => 'MANO ALL IN';

  @override
  String get handPot => 'Pot';

  @override
  String get handStack => 'Stack';

  @override
  String get handToAct => 'Por actuar';

  @override
  String get handToActYou => 'Tú';

  @override
  String get handStopSessionTitle => '¿Detener sesión?';

  @override
  String get handStopSessionMessage =>
      '¿Estás seguro de que deseas detener esta sesión? Todas las manos serán guardadas.';

  @override
  String get handStop => 'Detener';

  @override
  String get handChangeTable => 'Cambiar mesa';

  @override
  String get handBlinds => 'Blinds';

  @override
  String get handTakesEffectNextHand => 'Toma efecto en la próxima mano';

  @override
  String get handLeaveSession => '¿Salir de la sesión?';

  @override
  String get handSaveAndExit => 'Guardar y salir';

  @override
  String get handDiscardAndExit => 'Descartar y salir';

  @override
  String get handInProgress => 'Hand in Progress';

  @override
  String get handDiscardCurrentHand =>
      'You have an active hand being logged. Discard it and go back?';

  @override
  String get handDiscardHand => 'Discard Hand';

  @override
  String get handAdjustStack => 'Ajustar Stack';

  @override
  String get handEnterStackAmount => 'Ingresar monto del Stack';

  @override
  String get handGestureGuide => 'Guía de gestos';

  @override
  String get handManagePlayers => 'Gestionar jugadores';

  @override
  String get handStopSession => 'Detener sesión';

  @override
  String get handRebuy => 'Rebuy';

  @override
  String get handGestures => 'Gestos';

  @override
  String get handGestureTap => 'Tocar';

  @override
  String get handGestureCheckCall => 'Check / Call';

  @override
  String get handGestureSwipeOut => 'Deslizar afuera';

  @override
  String get handGestureSwipeUp => 'Deslizar arriba';

  @override
  String get handGestureBetRaise => 'Bet / Raise';

  @override
  String get handStreetComplete => 'Calle completada';

  @override
  String get handWinsThePot => 'gana el Pot';

  @override
  String get handHandComplete => 'Mano completada';

  @override
  String get handTapToContinue => 'Toca para continuar';

  @override
  String get handRaiseAmount => 'Monto del Raise';

  @override
  String get handBetAmount => 'Monto del Bet';

  @override
  String get handPleaseEnterValidNumber => 'Por favor ingresa un número válido';

  @override
  String get handConfirmRebuy => 'Confirmar Rebuy';

  @override
  String get handRebuyReplaceStack =>
      'Proceder con un Rebuy reemplazará tu Stack actual. ¿Estás seguro de que deseas continuar?';

  @override
  String get handProceed => 'Proceder';

  @override
  String get handEnterRebuyDetails =>
      'Ingresa los detalles de Rebuy para el Tournament';

  @override
  String get handRebuyAmount => 'Monto del Rebuy';

  @override
  String get handNewStackSize => 'Nuevo tamaño de Stack';

  @override
  String get handChipCountAfterRebuy => 'Cantidad de fichas después del Rebuy';

  @override
  String get handSessionInfo => 'Info de sesión';

  @override
  String handTotalInvested(String amount) {
    return 'Total invertido: $amount';
  }

  @override
  String handRebuysCount(int count) {
    return 'Rebuys: $count';
  }

  @override
  String get handAddRebuy => 'Agregar Rebuy';

  @override
  String get handPleaseEnterValidAmounts => 'Por favor ingresa montos válidos';

  @override
  String get handHandInProgress => 'Mano en progreso';

  @override
  String get handHandInProgressMessage =>
      'Hay una mano en progreso. Pasar a la siguiente mano descartará todas las acciones y restaurará los Stacks de los jugadores.';

  @override
  String get handMoveToNextHand => 'Ir a la siguiente mano';

  @override
  String get handMainPot => 'Pot principal';

  @override
  String handSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String get handPokerSession => 'Sesión de poker';

  @override
  String handActionsHandNumber(String number) {
    return 'Mano #$number';
  }

  @override
  String handActionsPosition(String position) {
    return 'Posición: $position';
  }

  @override
  String get handActionsShareHand => 'Compartir mano';

  @override
  String get handActionsShowHoleCards => 'Mostrar Hole Cards';

  @override
  String get handActionsShowHoleCardsSubtitle =>
      'Tus cartas serán visibles en el enlace compartido';

  @override
  String get handActionsHideHoleCards => 'Ocultar Hole Cards';

  @override
  String get handActionsHideHoleCardsSubtitle =>
      'Tus cartas estarán ocultas en el enlace compartido';

  @override
  String get handActionsShareMessage => '¡Mira esta mano en Final Table!';

  @override
  String handActionsShareSubject(String number) {
    return 'Mano de poker #$number';
  }

  @override
  String get handActionsFailedToShareHand => 'Error al compartir mano';

  @override
  String get handActionsGeneratingExport =>
      'Generando exportación PokerStars...';

  @override
  String handActionsExportedSuccessfully(String number) {
    return '¡Mano #$number exportada exitosamente!';
  }

  @override
  String handActionsFailedToExport(String error) {
    return 'Error al exportar mano: $error';
  }

  @override
  String get handActionsMissingHeroCards => 'Faltan cartas de Hero';

  @override
  String get handActionsMissingHeroCardsMessage =>
      'El análisis de IA requiere que se registren tus Hole Cards. Esta mano no puede ser analizada porque faltan las cartas de Hero.';

  @override
  String get handActionsYourCards => 'Tus cartas';

  @override
  String get handActionsOpponentCards => 'Cartas del oponente';

  @override
  String handActionsPlayerSeat(int id) {
    return 'Jugador $id';
  }

  @override
  String get handActionsPot => 'POT';

  @override
  String get handActionsBlinds => 'BLINDS';

  @override
  String get handActionsWinner => 'GANADOR';

  @override
  String handActionsPlayersCount(int count) {
    return '$count jugadores';
  }

  @override
  String get handActionsActionSummary => 'Resumen de acciones';

  @override
  String get handActionsPreflop => 'PREFLOP';

  @override
  String get handActionsBoard => 'BOARD';

  @override
  String get handActionsPlayer => 'JUGADOR';

  @override
  String get handActionsStack => 'STACK';

  @override
  String get handActionsAction => 'ACCIÓN';

  @override
  String get handActionsAmount => 'MONTO';

  @override
  String get handActionsYou => 'Tú';

  @override
  String get handActionsAllIn => 'ALL IN';

  @override
  String get handActionsNotes => 'Notas';

  @override
  String get handActionsAnalyzingHand => 'Analizando mano...';

  @override
  String get handActionsHeroCardsMissing => 'Faltan cartas de Hero';

  @override
  String get handActionsUnlockAiAnalysis => 'Desbloquear análisis IA';

  @override
  String get handActionsAnalysisComplete => 'Análisis completo';

  @override
  String get handActionsAiAnalyzerBeta => 'Analizador IA (beta)';

  @override
  String get handActionsAnalysisFailed => 'Análisis fallido';

  @override
  String get handActionsAiAnalysis => 'Análisis IA';

  @override
  String get handActionsStreetByStreetBreakdown => 'Desglose calle por calle';

  @override
  String handActionsAnalysisCompletedIn(String time) {
    return 'Análisis completado en ${time}s';
  }

  @override
  String get handActionsFailedToUpdateStar =>
      'Error al actualizar estado de estrella';

  @override
  String handActionsPotAmount(String amount) {
    return 'Pot: $amount';
  }

  @override
  String opponentDetailHandsTracked(int count) {
    return '$count manos rastreadas';
  }

  @override
  String get opponentDetailNoDataYet => 'Sin datos aún';

  @override
  String get opponentDetailHands => 'Manos';

  @override
  String get opponentDetailLastSeen => 'Última vez:';

  @override
  String get opponentDetailNotes => 'Notas';

  @override
  String get opponentDetailEditOpponent => 'Editar oponente';

  @override
  String get opponentDetailDeleteOpponent => 'Eliminar oponente';

  @override
  String get opponentDetailStatistics => 'Estadísticas';

  @override
  String get opponentDetailNoStatisticsAvailable =>
      'Sin estadísticas disponibles';

  @override
  String get opponentDetailStatsDisclaimer =>
      'Las estadísticas se basan solo en manos registradas juntos. VPIP no se rastrea ya que los folds no observados lo inflarían.';

  @override
  String get opponentDetailAggressionFreq => 'Aggression %';

  @override
  String get opponentDetailShowdownPercent => '% de Showdown';

  @override
  String get opponentDetailHandHistory => 'Historial de manos';

  @override
  String get opponentDetailViewAllHands =>
      'Ver todas las manos jugadas con este oponente';

  @override
  String get opponentDetailViewHandHistory => 'Ver historial de manos';

  @override
  String get opponentDetailNoHandsFound => 'Sin manos encontradas';

  @override
  String opponentDetailNoHandsMessage(String name) {
    return 'Aún no has jugado manos con \"$name\"';
  }

  @override
  String get opponentDetailOpponentName => 'Nombre del oponente';

  @override
  String get opponentDetailNotesOptional => 'Notas (Opcional)';

  @override
  String get opponentDetailPickColor => 'Elige un color';

  @override
  String get opponentDetailColorRed => 'Rojo';

  @override
  String get opponentDetailColorLightBlue => 'Azul claro';

  @override
  String get opponentDetailColorGreen => 'Verde';

  @override
  String get opponentDetailColorOrange => 'Naranja';

  @override
  String get opponentDetailColorPurple => 'Morado';

  @override
  String get opponentDetailColorTeal => 'Turquesa';

  @override
  String get opponentDetailColorPink => 'Rosa';

  @override
  String get opponentDetailColorIndigo => 'Índigo';

  @override
  String get opponentDetailUpdatedSuccessfully =>
      'Oponente actualizado exitosamente';

  @override
  String get opponentDetailDeleteConfirmTitle => '¿Eliminar oponente?';

  @override
  String opponentDetailDeleteConfirmMessage(String name) {
    return '¿Estás seguro de que deseas eliminar a \"$name\"?\nEsta acción no se puede deshacer';
  }

  @override
  String get opponentDetailDeletedSuccessfully =>
      'Oponente eliminado exitosamente';

  @override
  String opponentDetailErrorDeleting(String error) {
    return 'Error al eliminar oponente: $error';
  }

  @override
  String get individualSessionCreatedLocally =>
      'Sesión creada localmente. Se sincronizará con la nube cuando haya conexión disponible.';

  @override
  String get individualUpdateCurrentStack => 'Actualizar Stack actual';

  @override
  String get individualCurrentStack => 'Stack actual:';

  @override
  String get individualSetNewTotal => 'Establecer nuevo total';

  @override
  String get individualEnterNewTotalStack => 'Ingresar nuevo Stack total';

  @override
  String get individualAddSubtractAmount => 'Agregar/Restar monto';

  @override
  String get individualAmount => 'Monto';

  @override
  String get individualSetTotal => 'Establecer total';

  @override
  String get individualNoteLabel => 'Nota (opcional)';

  @override
  String get individualNoteHint => 'p.ej. Gané bote grande con AA';

  @override
  String get individualUpdateBlinds => 'Actualizar Blinds';

  @override
  String get individualSmallBlind => 'Small Blind';

  @override
  String get individualBigBlind => 'Big Blind';

  @override
  String get individualBbMode => 'Modo BB';

  @override
  String get individualCurrentStackLabel => 'Stack actual';

  @override
  String get individualSessionInfo => 'Info de sesión';

  @override
  String get individualStartingStack => 'Stack inicial';

  @override
  String get individualInitialBuyIn => 'Buy-in inicial';

  @override
  String get individualRebuys => 'Rebuys';

  @override
  String get individualTotalInvested => 'Total invertido';

  @override
  String get individualBlindsLabel => 'Blinds';

  @override
  String get individualHandsLogged => 'Manos registradas';

  @override
  String get individualLogAHand => 'Registrar una mano';

  @override
  String get individualGoBackToHand => 'Volver a la mano';

  @override
  String get individualStackChart => 'Gráfico de Stack';

  @override
  String get individualCompleteHandToSee =>
      'Completa una mano para ver tu tendencia de Stack';

  @override
  String get individualStopSessionTitle => '¿Detener sesión?';

  @override
  String get individualStopSessionMessage =>
      '¿Estás seguro de que deseas detener esta sesión? Todas las manos serán guardadas.';

  @override
  String get individualStop => 'Detener';

  @override
  String get individualConfirmRebuy => 'Confirmar Rebuy';

  @override
  String individualRebuyCurrentStack(String stack) {
    return 'Actualmente tienes $stack restante.';
  }

  @override
  String get individualRebuyReplaceMessage =>
      'Proceder con un Rebuy reemplazará tu Stack actual. ¿Estás seguro de que deseas continuar?';

  @override
  String get individualProceedWithRebuy => 'Proceder con Rebuy';

  @override
  String get individualAddOn => 'Add-on';

  @override
  String get individualAddOnDescription =>
      'Ingresa el monto del add-on para aumentar tu inversión total';

  @override
  String get individualAddOnAmount => 'Monto del Add-on';

  @override
  String get individualAddOnConfirm => 'Agregar';

  @override
  String get individualAddOnDescriptionTournament =>
      'Ingresa el precio del add-on y las fichas recibidas';

  @override
  String get individualAddOnPrice => 'Precio del Add-on';

  @override
  String get individualAddOnChips => 'Fichas recibidas';

  @override
  String get individualRebuy => 'Rebuy';

  @override
  String get individualEnterRebuyAmount =>
      'Ingresa el monto de Rebuy (el Stack será igual al monto de Rebuy)';

  @override
  String get individualEnterRebuyAmountAndStack =>
      'Ingresa el monto de Rebuy y el nuevo tamaño de Stack';

  @override
  String get individualRebuyAmount => 'Monto del Rebuy';

  @override
  String get individualNewStackSize => 'Nuevo tamaño de Stack';

  @override
  String get individualChipCountAfterRebuy =>
      'Cantidad de fichas después del Rebuy';

  @override
  String individualTotalInvestedAmount(String amount) {
    return 'Total invertido: \$$amount';
  }

  @override
  String individualCurrentStackAmount(String stack) {
    return 'Stack actual: $stack';
  }

  @override
  String individualRebuysCount(int count) {
    return 'Rebuys: $count';
  }

  @override
  String get individualAddRebuy => 'Agregar Rebuy';

  @override
  String get individualPleaseEnterValidRebuy =>
      'Por favor ingresa un monto de Rebuy válido';

  @override
  String get individualPleaseEnterValidStack =>
      'Por favor ingresa un tamaño de Stack válido';

  @override
  String individualRebuyAddedSimple(String amount) {
    return 'Rebuy agregado: \$$amount';
  }

  @override
  String individualRebuyAddedWithStack(String amount, String stack) {
    return 'Rebuy agregado: \$$amount (Stack: $stack)';
  }

  @override
  String get authWelcome => 'Bienvenido a Final Table';

  @override
  String get authSignIn => 'Iniciar sesión';

  @override
  String get authRegister => 'Registrarse';

  @override
  String get authEmail => 'Correo electrónico';

  @override
  String get authPassword => 'Contraseña';

  @override
  String get authDisplayName => 'Nombre para mostrar';

  @override
  String get authConfirmPassword => 'Confirmar contraseña';

  @override
  String get authPleaseEnterEmail => 'Por favor ingresa tu correo electrónico';

  @override
  String get authPleaseEnterValidEmail =>
      'Por favor ingresa un correo electrónico válido';

  @override
  String get authPleaseEnterPassword => 'Por favor ingresa tu contraseña';

  @override
  String get authPleaseEnterName => 'Por favor ingresa tu nombre';

  @override
  String get authNameMinLength => 'El nombre debe tener al menos 2 caracteres';

  @override
  String get authPleaseEnterAPassword => 'Por favor ingresa una contraseña';

  @override
  String get authPasswordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get authPleaseConfirmPassword => 'Por favor confirma tu contraseña';

  @override
  String get authPasswordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get authCreateAccount => 'Crear cuenta';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authResetPassword => 'Restablecer contraseña';

  @override
  String get authResetPasswordMessage =>
      'Ingresa tu correo electrónico para recibir un enlace de restablecimiento de contraseña.';

  @override
  String get authSendResetLink => 'Enviar enlace de restablecimiento';

  @override
  String get authPasswordResetSent =>
      '¡Correo de restablecimiento de contraseña enviado!';

  @override
  String get paywallRestore => 'Restaurar';

  @override
  String get paywallTitle => 'FINAL TABLE PREMIUM';

  @override
  String get paywallAvailablePlans => 'Planes disponibles';

  @override
  String get paywallStepLabel => 'Paso 1 de 2';

  @override
  String get paywallChooseYourPlan => 'Elige tu plan';

  @override
  String get paywallUpgradeOrCancel => 'Mejora o cancela* en cualquier momento';

  @override
  String get paywallContinue => 'Continuar';

  @override
  String paywallUnlockFeature(String featureName) {
    return 'Desbloquear $featureName';
  }

  @override
  String get paywallGoPremium => 'Obtener Premium';

  @override
  String get paywallFeatureSubtitle =>
      'Esta función es parte de Final Table Premium. Elige un plan que se adapte a tu forma de jugar.';

  @override
  String get paywallGeneralSubtitle =>
      'Desbloquea todo lo que Final Table tiene para ofrecer. Registra más manos, analiza tu juego, gestiona tu club.';

  @override
  String get paywallProTier => 'Pro';

  @override
  String get paywallFreeTrialBadge => 'Prueba gratis de 7 días';

  @override
  String get paywallProDescription =>
      'Todo lo que necesitas para dominar tu juego.';

  @override
  String get paywallUnlimitedHandLogging => 'Registro ilimitado de manos';

  @override
  String get paywallFullSessionHistory => 'Historial completo de sesiones';

  @override
  String get paywallAiHandAnalysis => 'Análisis de manos con IA';

  @override
  String get paywallExportHandsCsv => 'Exportar manos a CSV';

  @override
  String get paywallProMonthly => '\$19.99/mes';

  @override
  String get paywallProYearly => 'o \$199.99/año. Ahorra un 25 %**';

  @override
  String get paywallStartFreeTrial => 'Iniciar prueba gratis de 7 días';

  @override
  String get paywallEliteTier => 'Elite';

  @override
  String get paywallEliteDescription => 'Lleva tu juego al siguiente nivel.';

  @override
  String get paywallEverythingInProElite => 'Todo en Pro';

  @override
  String get paywallEliteFeature1 => 'Perfilado avanzado de oponentes';

  @override
  String get paywallEliteFeature2 => 'Analítica detallada de sesiones';

  @override
  String get paywallEliteFeature3 => 'Soporte prioritario';

  @override
  String get paywallEliteMonthly => '\$29.99/mes';

  @override
  String get paywallEliteYearly => 'o \$199.99/año. Ahorra un 25 %**';

  @override
  String get paywallGetElite => 'Obtener Elite';

  @override
  String get paywallClubTier => 'Club';

  @override
  String get paywallClubDescription =>
      'Para Home Games, clubs y lugares en vivo.';

  @override
  String get paywallEverythingInPro => 'Todo lo de PRO';

  @override
  String get paywallClubManagement => 'Gestión de club y roles de miembros';

  @override
  String get paywallLiveDealerVoice => 'Registro de voz con Dealer en vivo';

  @override
  String get paywallMultiTableEvents => 'Eventos multi-mesa con rankings';

  @override
  String get paywallClubMonthly => '\$39.99/mes';

  @override
  String get paywallClubYearly => 'o \$199.99/año. Ahorra un 25 %**';

  @override
  String get paywallGetClub => 'Obtener Club';

  @override
  String get paywallDisclaimer =>
      'Las suscripciones se renuevan automáticamente. Cancela* en cualquier momento\ndesde los ajustes de tu cuenta.';

  @override
  String get paywallTerms => 'Términos';

  @override
  String get paywallPrivacy => 'Privacidad';

  @override
  String get paywallPurchasesRestored => 'Compras restauradas';

  @override
  String get paywallNoPreviousPurchases =>
      'No se encontraron compras anteriores';

  @override
  String paywallComingSoon(String tier) {
    return 'Suscripciones $tier próximamente';
  }

  @override
  String trialConfirmTitle(String tier) {
    return 'Los primeros 7 días de $tier van por nuestra cuenta';
  }

  @override
  String get trialConfirmTodayTitle => 'Hoy';

  @override
  String trialConfirmTodayBody(String tier) {
    return 'Acceso completo a todas las funciones de $tier';
  }

  @override
  String get trialConfirmReminderTitle => 'En 5 días';

  @override
  String get trialConfirmReminderBody =>
      'Recibe un recordatorio antes de que termine tu prueba gratuita';

  @override
  String get trialConfirmStartTitle => 'En 7 días';

  @override
  String get trialConfirmStartBody =>
      'Tu suscripción comienza, a menos que canceles antes';

  @override
  String get trialConfirmPriceSummary => 'Prueba 7 días gratis, luego';

  @override
  String get trialConfirmStartCta => 'Iniciar mi prueba gratuita de 7 días';

  @override
  String get trialConfirmDisclaimer =>
      'Sin cargos aún. Cancela en cualquier momento desde la App Store.';

  @override
  String get introGameSetup => 'Configuración de juego';

  @override
  String get introConfigureSession => 'Configura tu sesión';

  @override
  String get introSmallBlind => 'Small Blind';

  @override
  String get introBigBlind => 'Big Blind';

  @override
  String get introPlayers => 'Jugadores';

  @override
  String get introGameType => 'Tipo de juego';

  @override
  String get introBbAnte => 'BB Ante';

  @override
  String get introBbAnteDescription => 'Activar regla de BB Ante';

  @override
  String get introStartGame => 'INICIAR JUEGO';

  @override
  String get introStartingSession => 'Iniciando tu sesión de poker...';

  @override
  String introEnterField(String title) {
    return 'Ingresar $title';
  }

  @override
  String get introEnterAmount => 'Ingresar monto';

  @override
  String get introPleaseEnterValidNumber =>
      'Por favor ingresa un número positivo válido';

  @override
  String get introRingGame => 'Ring Game';

  @override
  String get introMultiTable => 'Multi-mesa';

  @override
  String get invitationTitle => 'Invitaciones de club';

  @override
  String get invitationNoPending => 'Sin invitaciones pendientes';

  @override
  String get invitationYouWillSeeHere => 'Aquí verás invitaciones de clubs';

  @override
  String get invitationGoBack => 'Volver';

  @override
  String invitationFailedToLoad(String error) {
    return 'Error al cargar invitaciones: $error';
  }

  @override
  String invitationJoinedAs(String clubName, String role) {
    return 'Te uniste a $clubName como $role';
  }

  @override
  String invitationFailedToAccept(String error) {
    return 'Error al aceptar invitación: $error';
  }

  @override
  String get invitationDeclined => 'Invitación rechazada';

  @override
  String invitationFailedToDecline(String error) {
    return 'Error al rechazar invitación: $error';
  }

  @override
  String get invitationUnknownClub => 'Club desconocido';

  @override
  String invitationInvitedBy(String name) {
    return 'Invitado por $name';
  }

  @override
  String invitationExpiresDate(String date) {
    return 'Expira $date';
  }

  @override
  String get invitationExpired => 'Expirada';

  @override
  String invitationExpiresInDays(int days) {
    return 'en $days día(s)';
  }

  @override
  String invitationExpiresInHours(int hours) {
    return 'en $hours hora(s)';
  }

  @override
  String get invitationExpiresSoon => 'pronto';

  @override
  String get invitationDeclineButton => 'Rechazar';

  @override
  String get invitationAcceptButton => 'Aceptar';

  @override
  String get notificationTitle => 'Notificaciones';

  @override
  String get notificationToday => 'Hoy';

  @override
  String get notificationYesterday => 'Ayer';

  @override
  String get notificationThisWeek => 'Esta semana';

  @override
  String get notificationEarlier => 'Anteriores';

  @override
  String get notificationMarkAllRead => 'Marcar todo como leído';

  @override
  String get notificationMarkAsRead => 'Marcar como leído';

  @override
  String get notificationNoNotifications => 'Sin notificaciones';

  @override
  String get notificationEvents => 'Eventos';

  @override
  String get notificationRsvp => 'RSVP';

  @override
  String get notificationClubs => 'Clubs';

  @override
  String get notificationInvitations => 'Invitaciones';

  @override
  String get notificationSeats => 'Asientos';

  @override
  String get notificationSupport => 'Soporte';

  @override
  String get notificationClubNotFound => 'Club no encontrado';

  @override
  String get notificationEventNotFound => 'Evento no encontrado';

  @override
  String notificationError(String error) {
    return 'Error: $error';
  }

  @override
  String notificationErrorLoadingEvent(String error) {
    return 'Error al cargar evento: $error';
  }

  @override
  String notificationFailedToLoadClub(String error) {
    return 'Error al cargar club: $error';
  }

  @override
  String get notificationClubInvitation => 'Invitación al club';

  @override
  String get notificationInvitedToJoin => 'Has sido invitado a unirte a';

  @override
  String get notificationInvitationDeclined => 'Invitación rechazada';

  @override
  String get notificationNotAuthenticated => 'No autenticado';

  @override
  String get notificationInvitationAccepted => 'Invitación aceptada';

  @override
  String notificationAcceptedMessage(String name, String clubName) {
    return '$name ha aceptado la invitación para unirse a $clubName.';
  }

  @override
  String get notificationInvitationDeclinedTitle => 'Invitación rechazada';

  @override
  String notificationDeclinedMessage(String name, String clubName) {
    return '$name ha rechazado la invitación para unirse a $clubName.';
  }

  @override
  String get notificationRequestResolved => 'Solicitud resuelta';

  @override
  String get notificationRequestClosed => 'Solicitud cerrada';

  @override
  String get notificationResponse => 'Respuesta';

  @override
  String get calendarTitle => 'Calendario de poker';

  @override
  String get calendarNewEvent => 'Nuevo evento';

  @override
  String get calendarEventType => 'Tipo de evento';

  @override
  String get calendarEventTitle => 'Título';

  @override
  String get calendarLocation => 'Ubicación';

  @override
  String get calendarBuyInAmount => 'Monto de Buy-in';

  @override
  String get calendarEventDateTime => 'Fecha y hora del evento';

  @override
  String get calendarStarts => 'Comienza';

  @override
  String get calendarSelectDate => 'Seleccionar fecha:';

  @override
  String get calendarReset => 'Restablecer';

  @override
  String get calendarSun => 'DOM';

  @override
  String get calendarMon => 'LUN';

  @override
  String get calendarTue => 'MAR';

  @override
  String get calendarWed => 'MIÉ';

  @override
  String get calendarThu => 'JUE';

  @override
  String get calendarFri => 'VIE';

  @override
  String get calendarSat => 'SÁB';

  @override
  String get calendarNoRecentEvents => 'Sin eventos recientes';

  @override
  String get calendarAddFirstEvent => '¡Agrega tu primer evento de poker!';

  @override
  String get calendarAddNewEvent => 'Agregar nuevo evento';

  @override
  String get calendarSelectYear => 'Seleccionar año';

  @override
  String get calendarEditEvent => 'Editar evento';

  @override
  String get calendarDeleteEvent => 'Eliminar evento';

  @override
  String get calendarTournament => 'Tournament';

  @override
  String get calendarCashGame => 'Cash Game';

  @override
  String get calendarPrivateGame => 'Juego privado';

  @override
  String get calendarOnline => 'Online';

  @override
  String calendarFailedToCreateEvent(String error) {
    return 'Error al crear evento: $error';
  }

  @override
  String calendarFailedToUpdateEvent(String error) {
    return 'Error al actualizar evento: $error';
  }

  @override
  String get calendarFailedToDeleteEvent => 'Error al eliminar evento';

  @override
  String get calendarClubNotFound => 'Club no encontrado';

  @override
  String get calendarEventNotFound => 'Evento no encontrado';

  @override
  String calendarFailedToLoadEvent(String error) {
    return 'Error al cargar evento: $error';
  }

  @override
  String calendarDeleteConfirmTitle(String title) {
    return '¿Eliminar $title?';
  }

  @override
  String calendarDeleteConfirmMessage(String title) {
    return '¿Estás seguro de que deseas eliminar \"$title\"?\nEsta acción no se puede deshacer.';
  }

  @override
  String get sessionAnalyticsTitle => 'Análisis de sesión';

  @override
  String sessionAnalyticsHandsLogged(int count) {
    return '$count manos registradas';
  }

  @override
  String get sessionAnalyticsDeleteTitle => '¿Eliminar sesión?';

  @override
  String get sessionAnalyticsDeleteMessage =>
      'Esto eliminará permanentemente esta sesión incluyendo todo el historial de manos, datos del gráfico de Stack y reportes de análisis IA. Esta acción no se puede deshacer.';

  @override
  String get sessionAnalyticsDeleted => 'Sesión eliminada';

  @override
  String get sessionAnalyticsFailedToDelete => 'Error al eliminar sesión';

  @override
  String get sessionAnalyticsExportSession => 'Exportar sesión';

  @override
  String sessionAnalyticsExportConfirm(int count, String email) {
    return '¿Exportar $count manos a $email?';
  }

  @override
  String get sessionAnalyticsExport => 'Exportar';

  @override
  String sessionAnalyticsExportSent(String email) {
    return 'Exportación enviada a $email';
  }

  @override
  String sessionAnalyticsExportFailed(String error) {
    return 'Error de exportación: $error';
  }

  @override
  String get sessionAnalyticsNoEmailFound =>
      'No se encontró dirección de correo electrónico. Por favor inicia sesión con una cuenta de correo.';

  @override
  String get sessionAnalyticsPokerSession => 'Sesión de poker';

  @override
  String get sessionAnalyticsTotalInvested => 'Total invertido';

  @override
  String get sessionAnalyticsFinalStack => 'Stack final';

  @override
  String get sessionAnalyticsCashout => 'Cobro';

  @override
  String get sessionAnalyticsProfitLoss => 'Ganancia/Pérdida';

  @override
  String get sessionAnalyticsNotAvailableFull => 'No disponible';

  @override
  String get sessionAnalyticsAvgGrowth => 'Crecimiento prom.';

  @override
  String get sessionAnalyticsHourlyRate => 'Tarifa por hora';

  @override
  String get sessionAnalyticsFinished => 'Posición';

  @override
  String get sessionAnalyticsDuration => 'Duración';

  @override
  String get sessionAnalyticsRebuys => 'Rebuys';

  @override
  String get sessionAnalyticsAddons => 'Add-ons';

  @override
  String get sessionAnalyticsStackChart => 'Gráfico de Stack';

  @override
  String get sessionAnalyticsNoStackHistory =>
      'Sin historial de Stack disponible';

  @override
  String get sessionAnalyticsStackTrackedFuture =>
      'Los cambios de Stack se rastrearán en futuras sesiones';

  @override
  String get sessionAnalyticsViewLoggedHands => 'Ver manos registradas';

  @override
  String get sessionAnalyticsStart => 'Inicio';

  @override
  String get sessionAnalyticsRebuy => 'Rebuy';

  @override
  String get sessionAnalyticsEnd => 'Fin';

  @override
  String get seatSetupTitle => 'Configurar asiento';

  @override
  String get seatSetupManagePlayers => 'Gestionar jugadores';

  @override
  String get seatSetupClickToConfig =>
      'Toca el asiento para configurar. Arrastra el botón para posicionar';

  @override
  String get seatSetupButtonLocked => 'Botón bloqueado - mano en progreso';

  @override
  String get seatSetupUpdatePlayerInfo => 'Actualizar información del jugador';

  @override
  String get seatSetupEmpty => 'Vacío';

  @override
  String get seatSetupThisIsMySeat => 'Este es mi asiento';

  @override
  String get seatSetupPlayerName => 'Nombre del jugador';

  @override
  String get seatSetupBuyInAmount => 'Monto de Buy-in (\$)';

  @override
  String get seatSetupStartingChips => 'Fichas iniciales';

  @override
  String seatSetupSaveAsOpponent(String name) {
    return '¿Guardar \"$name\" como oponente?';
  }

  @override
  String get seatSetupOpponentSaved => '¡Oponente guardado!';

  @override
  String seatSetupFailedToSave(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get seatSetupNoData => 'Sin datos';

  @override
  String get seatSetupStartSession => 'Iniciar sesión';

  @override
  String get seatSetupSaveChanges => 'Guardar cambios';

  @override
  String get seatSetupPleaseSelectSeat => 'Por favor selecciona tu asiento';

  @override
  String seatSetupSeatNumber(int number) {
    return 'Asiento $number';
  }

  @override
  String seatSetupPlayerDefault(int number) {
    return 'Jugador $number';
  }

  @override
  String get quickStackTitle => 'Actualizar Stacks y botón';

  @override
  String quickStackBlinds(String blinds) {
    return 'Blinds: $blinds';
  }

  @override
  String get quickStackInstruction =>
      'Toca el Stack para editar  •  Desliza para ajustar  •  Toca D para el botón';

  @override
  String get quickStackContinue => 'CONTINUAR PARA REGISTRAR MANO';

  @override
  String get quickStackEditStack => 'Editar Stack';

  @override
  String get quickStackStackInBb => 'Stack en BB';

  @override
  String quickStackCurrentValue(String bbValue, String chipValue) {
    return 'Actual: $bbValue BB = $chipValue';
  }

  @override
  String get quickStackValidationError =>
      'Por favor ingresa un valor entre 0 y 1000 BB';

  @override
  String quickStackSeat(int number) {
    return 'Asiento $number';
  }

  @override
  String get quickStackEmpty => 'Vacío';

  @override
  String quickStackPlayerDefault(int id) {
    return 'Jugador $id';
  }

  @override
  String get handReviewTitle => 'Revisión de mano';

  @override
  String get handReviewYourHoleCards => 'Tus Hole Cards';

  @override
  String get handReviewOptional => '(opcional)';

  @override
  String get handReviewQuickTags => 'Etiquetas rápidas';

  @override
  String get handReviewTagBluff => 'Bluff';

  @override
  String get handReviewTagValue => 'Value';

  @override
  String get handReviewTagMistake => 'Error';

  @override
  String get handReviewTagCooler => 'Cooler';

  @override
  String get handReviewTagHeroCall => 'Hero Call';

  @override
  String get handReviewTagExploit => 'Exploit';

  @override
  String get handReviewNotes => 'Notas';

  @override
  String get handReviewNotesHint => 'Agrega una nota sobre esta mano...';

  @override
  String get handReviewSaveHand => 'Guardar mano';

  @override
  String get handReviewSkip => 'Omitir';

  @override
  String get handReviewDuplicateCardError =>
      '¡No puedes seleccionar la misma carta dos veces!';

  @override
  String get handReviewSelectBothOrNone =>
      'Por favor selecciona ambas Hole Cards o deja ambas vacías';

  @override
  String get holeCardsTitle => 'Tus Hole Cards';

  @override
  String get holeCardsSubtitle => 'Hole Cards';

  @override
  String get holeCardsWinnerBadge => 'GANADOR';

  @override
  String get holeCardsSave => 'Guardar';

  @override
  String get holeCardsSkip => 'Omitir';

  @override
  String get holeCardsSkipAllRemaining => 'Omitir todas las restantes';

  @override
  String get holeCardsDuplicateCardError =>
      '¡No puedes seleccionar la misma carta dos veces!';

  @override
  String get holeCardsSelectBothOrSkip =>
      'Por favor selecciona ambas Hole Cards u omite para continuar';

  @override
  String get holeCardsClearAll => 'Limpiar todo';

  @override
  String get showdownTitle => 'Showdown';

  @override
  String get showdownEnterOpponentCards =>
      'Ingresa las cartas del oponente en el Showdown:';

  @override
  String showdownPlayerLabel(int seatNumber) {
    return 'Jugador $seatNumber';
  }

  @override
  String get showdownCard1 => 'Carta 1';

  @override
  String get showdownCard2 => 'Carta 2';

  @override
  String get showdownClear => 'Limpiar';

  @override
  String get showdownWinner => 'Ganador:';

  @override
  String get showdownHandDescriptionLabel =>
      'Descripción de la mano (opcional)';

  @override
  String get showdownHandDescriptionHint =>
      'ej., \"Escalera de color\", \"Full house de Ases sobre Reyes\"';

  @override
  String get showdownSkip => 'Omitir';

  @override
  String get showdownSave => 'Guardar';

  @override
  String get showdownSelectCard => 'Seleccionar carta';

  @override
  String get tableManagementSectionTitle => 'MESA';

  @override
  String tableManagementPlayersCount(int count) {
    return '$count jugadores';
  }

  @override
  String get tableManagementDealerButton => 'Botón de Dealer';

  @override
  String get tableManagementAddPlayer => 'Agregar jugador';

  @override
  String tableManagementYouSuffix(String name) {
    return '$name (Tú)';
  }

  @override
  String get tableManagementAdjustStack => 'Ajustar Stack';

  @override
  String get tableManagementRebuy => 'Rebuy';

  @override
  String get tableManagementRemove => 'Quitar';

  @override
  String get tableManagementAdjustStackTitle => 'Ajustar Stack';

  @override
  String get tableManagementEnterStackAmount => 'Ingresar monto del Stack';

  @override
  String get tableManagementRebuyTitle => 'Rebuy';

  @override
  String get tableManagementRebuyAmountHint => 'Monto de Rebuy a agregar';

  @override
  String get tableManagementAdd => 'Agregar';

  @override
  String get tableManagementRemovePlayerTitle => '¿Quitar jugador?';

  @override
  String tableManagementRemovePlayerMessage(String playerName) {
    return '¿Quitar a $playerName de la mesa?';
  }

  @override
  String tableManagementAddPlayerSeatTitle(int seatNumber) {
    return 'Agregar jugador — Asiento $seatNumber';
  }

  @override
  String get tableManagementThisIsMe => 'Este soy yo';

  @override
  String get tableManagementNameLabel => 'Nombre';

  @override
  String get tableManagementSearchOrEnterName => 'Buscar o ingresar nombre';

  @override
  String tableManagementSaveAsOpponent(String name) {
    return 'Guardar \"$name\" como oponente';
  }

  @override
  String tableManagementSavedAsOpponent(String name) {
    return '$name guardado como oponente';
  }

  @override
  String get tableManagementStartingStack => 'Stack inicial';

  @override
  String get tableManagementStackAmountHint => 'Monto del Stack';

  @override
  String get tableManagementMoveMeHere => 'Moverme aquí';

  @override
  String tableManagementSeatLabel(int seatNumber) {
    return 'Asiento $seatNumber';
  }

  @override
  String get seatConfigRemove => 'Quitar';

  @override
  String get seatConfigThisIsMe => 'Este soy yo';

  @override
  String get seatConfigNameLabel => 'Nombre';

  @override
  String get seatConfigSearchOrEnterName => 'Buscar o ingresar nombre';

  @override
  String seatConfigSaveAsOpponent(String name) {
    return 'Guardar \"$name\" como oponente';
  }

  @override
  String seatConfigSavedAsOpponent(String name) {
    return '$name guardado como oponente';
  }

  @override
  String seatConfigSeatTitle(int seatNumber) {
    return 'Asiento $seatNumber';
  }

  @override
  String get seatConfigStackLabel => 'Stack';

  @override
  String get seatConfigUpdateButton => 'Actualizar';

  @override
  String get seatConfigAddPlayerButton => 'Agregar jugador';

  @override
  String get seatManagementSetupSeats => 'Configurar asientos';

  @override
  String get seatManagementManagePlayers => 'Gestionar jugadores';

  @override
  String get seatManagementChooseSeatSubtitle =>
      'Elige tu asiento y configura la mesa';

  @override
  String get seatManagementUpdatePlayerSubtitle =>
      'Actualizar información del jugador';

  @override
  String get seatManagementButtonPosition => 'Posición del botón';

  @override
  String seatManagementSeatLabel(int seatNumber) {
    return 'Asiento $seatNumber';
  }

  @override
  String get seatManagementEmpty => 'Vacío';

  @override
  String get seatManagementActive => 'Activo';

  @override
  String get seatManagementPlayerNameLabel => 'Nombre del jugador';

  @override
  String get seatManagementEnterPlayerName => 'Ingresar nombre del jugador';

  @override
  String get seatManagementBuyInAmountCash => 'Monto de Buy-in (\$)';

  @override
  String get seatManagementStartingChips => 'Fichas iniciales';

  @override
  String get seatManagementSaveOpponentTitle => '¿Guardar oponente?';

  @override
  String seatManagementSaveOpponentMessage(String name) {
    return '¿Te gustaría guardar a \"$name\" en tu lista de oponentes para rastreo futuro?';
  }

  @override
  String get seatManagementNotNow => 'Ahora no';

  @override
  String seatManagementSaveAsOpponentPrompt(String name) {
    return '¿Guardar \"$name\" como oponente?';
  }

  @override
  String seatManagementOpponentSavedSuccess(String name) {
    return '¡Oponente \"$name\" guardado exitosamente!';
  }

  @override
  String seatManagementFailedToSaveOpponent(String error) {
    return 'Error al guardar oponente: $error';
  }

  @override
  String get seatManagementStartSession => 'Iniciar sesión';

  @override
  String get seatManagementSaveChanges => 'Guardar cambios';

  @override
  String get seatManagementSelectYourSeat => 'Por favor selecciona tu asiento';

  @override
  String get inviteMemberTitle => 'Invitar miembro';

  @override
  String get inviteMemberEmailLabel => 'CORREO ELECTRÓNICO';

  @override
  String get inviteMemberEmailHint => 'Ingresar correo electrónico';

  @override
  String get inviteMemberEmailRequired =>
      'Por favor ingresa un correo electrónico';

  @override
  String get inviteMemberEmailInvalid =>
      'Por favor ingresa un correo electrónico válido';

  @override
  String get inviteMemberRoleLabel => 'ROL';

  @override
  String get inviteMemberRoleDealer => 'Dealer';

  @override
  String get inviteMemberRoleAdmin => 'Admin';

  @override
  String get inviteMemberSendInvite => 'Enviar invitación';

  @override
  String inviteMemberAlreadyMember(String displayName, String clubName) {
    return '$displayName ya es miembro de $clubName';
  }

  @override
  String get inviteMemberAddedNotificationTitle =>
      '¡Te han agregado a un club!';

  @override
  String inviteMemberAddedNotificationBody(
      String inviterName, String clubName, String role) {
    return '$inviterName te agregó a \"$clubName\" como $role.';
  }

  @override
  String get inviteMemberAddedSuccessTitle => '¡Miembro agregado!';

  @override
  String inviteMemberAddedSuccessMessage(
      String displayName, String clubName, String role) {
    return '$displayName ha sido agregado a $clubName como $role.';
  }

  @override
  String get inviteMemberInvitationSentTitle => '¡Invitación enviada!';

  @override
  String inviteMemberInvitationSentMessage(String email, String clubName) {
    return 'Se ha enviado un correo de invitación a $email. Una vez que se registre, podrá unirse a $clubName.';
  }

  @override
  String inviteMemberError(String error) {
    return 'Error: $error';
  }

  @override
  String get inviteMemberRoleAnAdmin => 'administrador';

  @override
  String get inviteMemberRoleADealer => 'Dealer';

  @override
  String get registerClubTitle => 'Registrar club';

  @override
  String get registerClubNameLabel => 'Nombre del club';

  @override
  String get registerClubNamePlaceholder => 'ej., Club de Poker Lucky Aces';

  @override
  String get registerClubNameRequired => 'Por favor ingresa un nombre de club';

  @override
  String get registerClubAddressLabel => 'Dirección';

  @override
  String get registerClubAddressPlaceholder =>
      'ej., Calle Principal 123, Ciudad, País';

  @override
  String get registerClubAddressRequired =>
      'Por favor ingresa la dirección del club';

  @override
  String get registerClubPhoneLabel => 'Número de teléfono';

  @override
  String get registerClubPhonePlaceholder => 'ej., +1 555-123-4567';

  @override
  String get registerClubPhoneRequired =>
      'Por favor ingresa un número de teléfono';

  @override
  String get registerClubAdminEmailLabel => 'Correo del administrador del club';

  @override
  String get registerClubAdminEmailPlaceholder => 'ej., admin@miclub.com';

  @override
  String get registerClubAdminEmailRequired =>
      'Por favor ingresa el correo del administrador';

  @override
  String get registerClubAdminEmailInvalid =>
      'Por favor ingresa un correo electrónico válido';

  @override
  String get registerClubInfoMessage =>
      'Esta persona será notificada cuando el club sea aprobado y se convertirá en el dueño del club.';

  @override
  String get registerClubSubmitRequest => 'Enviar solicitud';

  @override
  String registerClubFailedToSubmit(String error) {
    return 'Error al enviar solicitud: $error';
  }

  @override
  String get registerClubSuccessTitle => '¡Solicitud enviada!';

  @override
  String registerClubSuccessMessage(String email) {
    return 'Tu solicitud de registro de club ha sido enviada. Te notificaremos a $email una vez que sea revisada.';
  }

  @override
  String get registerClubGotIt => 'Entendido';

  @override
  String get loggingModeChooseMode => 'Elegir modo';

  @override
  String get loggingModeFullTitle => 'Modo de registro completo';

  @override
  String get loggingModeFullSubtitle => 'Seguimiento completo de sesión';

  @override
  String get loggingModeFullFeature1 => 'Seguimiento de sesión multi-mano';

  @override
  String get loggingModeFullFeature2 => 'Estadísticas en tiempo real';

  @override
  String get loggingModeFullFeature3 => 'Historial detallado de manos';

  @override
  String get loggingModeFullFeature4 => 'Análisis de sesión';

  @override
  String get loggingModeIndividualTitle => 'Modo de sesión rápida';

  @override
  String get loggingModeIndividualSubtitle => 'Seguimiento de mano individual';

  @override
  String get loggingModeIndividualFeature1 => 'Enfoque en mano individual';

  @override
  String get loggingModeIndividualFeature2 => 'Registro rápido';

  @override
  String get loggingModeIndividualFeature3 => 'Análisis de mano';

  @override
  String get loggingModeIndividualFeature4 => 'Resultados instantáneos';

  @override
  String get loggingModeFeatures => 'Características';

  @override
  String get loggingModeStart => 'Iniciar';

  @override
  String get earningsChartAllTimeEarnings => 'Ganancias totales';

  @override
  String earningsChartSinceDate(String date) {
    return 'Desde $date';
  }

  @override
  String get earningsChartTournament => 'Tournament';

  @override
  String get earningsChartCash => 'Cash';

  @override
  String get earningsChartNoData => 'Sin datos de ganancias aún';

  @override
  String get earningsChartNoDataSubtitle =>
      'Completa algunas sesiones para ver tu gráfico de ganancias';

  @override
  String get earningsChartMtt => 'MTT';

  @override
  String get opponentHandsTitle => 'Historial de manos';

  @override
  String opponentHandsCount(int count) {
    return '$count manos';
  }

  @override
  String get opponentHandsLoading => 'Cargando historial de manos...';

  @override
  String get opponentHandsError => 'Algo salió mal';

  @override
  String get opponentHandsRetry => 'Reintentar';

  @override
  String get opponentHandsNoHandsTitle => 'Sin manos encontradas';

  @override
  String opponentHandsNoHandsSubtitle(String name) {
    return 'Aún no has jugado manos\ncon $name.';
  }

  @override
  String get opponentHandsOppWon => 'OPONENTE GANÓ';

  @override
  String get opponentHandsYou => 'Tú';

  @override
  String opponentHandsPot(String amount) {
    return 'Pot $amount';
  }

  @override
  String get opponentHandsUnknownSession => 'Sesión desconocida';

  @override
  String get clubDashboardLive => 'En vivo';

  @override
  String get clubDashboardUpcoming => 'Próximos';

  @override
  String get clubDashboardPast => 'Pasados';

  @override
  String get clubDashboardNoLiveEvents => 'Sin eventos en vivo';

  @override
  String get clubDashboardNoUpcomingEvents => 'Sin próximos eventos';

  @override
  String get clubDashboardNoPastEvents => 'Sin eventos pasados';

  @override
  String get clubDashboardAdmin => 'Admin';

  @override
  String get clubDashboardCreateEventHint =>
      'Toca el botón de abajo para crear uno';

  @override
  String get clubDashboardCheckBackLater =>
      'Vuelve más tarde para nuevos eventos';

  @override
  String get clubDashboardEventsWillAppear =>
      'Los eventos aparecerán aquí cuando comiencen';

  @override
  String get clubDashboardPastEventsWillAppear =>
      'Los eventos completados aparecerán aquí';

  @override
  String clubDashboardCashGameStakes(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get clubDashboardCash => 'Cash';

  @override
  String get clubDashboardTables => 'Mesas';

  @override
  String get clubDashboardStakes => 'Stakes';

  @override
  String clubDashboardPlayingCount(int count) {
    return '$count jugando';
  }

  @override
  String clubDashboardMemberCount(int count) {
    return '$count miembros';
  }

  @override
  String get clubSettingsTitle => 'Ajustes del club';

  @override
  String get clubSettingsClubInfo => 'Información del club';

  @override
  String get clubSettingsClubName => 'Nombre del club';

  @override
  String get clubSettingsAddress => 'Dirección';

  @override
  String get clubSettingsPhone => 'Teléfono';

  @override
  String get clubSettingsDescription => 'Descripción';

  @override
  String get clubSettingsSaveChanges => 'Guardar cambios';

  @override
  String get clubSettingsInfoSaved => 'Información del club guardada';

  @override
  String clubSettingsErrorSaving(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get clubSettingsNoTablesYet => 'Sin mesas aún';

  @override
  String get clubSettingsAddTableHint => 'Agrega una mesa para comenzar';

  @override
  String clubSettingsErrorLoading(String error) {
    return 'Error al cargar datos: $error';
  }

  @override
  String get eventEditTitle => 'Editar evento';

  @override
  String get eventNewTitle => 'Nuevo evento';

  @override
  String get eventNoTablesAssigned => 'Sin mesas asignadas';

  @override
  String get eventNoTablesAssignedDesc =>
      'No se asignaron mesas a este evento. Por favor regresa y asigna mesas primero.';

  @override
  String get eventGoBack => 'Volver';

  @override
  String get eventContinue => 'Continuar';

  @override
  String get eventNameOptional => 'Nombre del evento (opcional)';

  @override
  String get eventNameLabel => 'Nombre del evento';

  @override
  String get eventStakesHint => 'Stakes (ej. 1/2)';

  @override
  String get eventBuyInAmount => 'Monto de Buy-in';

  @override
  String get eventMinBuyIn => 'Buy-in mínimo (\$)';

  @override
  String get eventStartingStack => 'Stack inicial';

  @override
  String get eventGameType => 'Tipo de juego';

  @override
  String get eventTournament => 'Tournament';

  @override
  String get eventCashGame => 'Cash Game';

  @override
  String get eventDateAndTime => 'Fecha y hora del evento';

  @override
  String get eventStarts => 'Comienza';

  @override
  String get eventTables => 'Mesas';

  @override
  String get eventDeselectAll => 'Deseleccionar todo';

  @override
  String get eventSelectAll => 'Seleccionar todo';

  @override
  String get eventAllTablesInUse =>
      'Todas las mesas están en uso por eventos activos';

  @override
  String get eventNoTablesConfigured => 'Sin mesas configuradas aún';

  @override
  String get eventDescriptionLabel => 'Descripción';

  @override
  String get eventNotifyMembers => 'Notificar a miembros';

  @override
  String get eventNotifyMembersSubtitle =>
      'Enviar notificación a todos los miembros del club';

  @override
  String get eventDeleteEvent => 'Eliminar evento';

  @override
  String get eventDeleteConfirmTitle => '¿Eliminar evento?';

  @override
  String get eventDeleteConfirmBody =>
      'Esto eliminará permanentemente este evento y todos los datos asociados. Esta acción no se puede deshacer.';

  @override
  String eventDeleteFailed(String error) {
    return 'Error al eliminar evento: $error';
  }

  @override
  String get eventAttendeesTitle => 'Asistentes';

  @override
  String eventAttendeesGoing(int count) {
    return 'Asistirán ($count)';
  }

  @override
  String eventAttendeesMaybe(int count) {
    return 'Quizás ($count)';
  }

  @override
  String eventAttendeesNo(int count) {
    return 'No ($count)';
  }

  @override
  String get eventAttendeesNoConfirmed => 'Nadie confirmó aún';

  @override
  String get eventAttendeesNoMaybes => 'Sin respuestas de quizás';

  @override
  String get eventAttendeesNoDeclines => 'Sin rechazos';

  @override
  String get eventDetailLiveNow => '¡El evento está EN VIVO!';

  @override
  String get eventDetailEnded => 'El evento ha terminado';

  @override
  String get eventDetailCancelled => 'El evento fue cancelado';

  @override
  String get eventDetailPaused => 'El evento está pausado';

  @override
  String get eventDetailStatusUpdated => 'Estado del evento actualizado';

  @override
  String get eventDetailRemovedFromCalendar =>
      'Evento eliminado de tu calendario';

  @override
  String get eventDetailRsvpGoing => 'Asistiré';

  @override
  String get eventDetailRsvpMaybe => 'Quizás';

  @override
  String get eventDetailRsvpCantGo => 'No puedo ir';

  @override
  String eventDetailRsvpFailed(String error) {
    return 'Error al actualizar RSVP: $error';
  }

  @override
  String get eventDetailCantStartTitle => 'No se puede iniciar el evento';

  @override
  String get eventDetailCantStartBody =>
      'No hay mesas asignadas a este evento. Por favor agrega mesas primero.';

  @override
  String get eventDetailStarted => '¡Evento iniciado!';

  @override
  String eventDetailStartFailed(String error) {
    return 'Error al iniciar evento: $error';
  }

  @override
  String get eventDetailFinishTitle => '¿Finalizar evento?';

  @override
  String get eventDetailCancelTitle => '¿Cancelar evento?';

  @override
  String get eventDetailFinishBody =>
      'Esto terminará todas las mesas activas y finalizará las clasificaciones.';

  @override
  String get eventDetailCancelBody =>
      'Esto notificará a todos los miembros y cancelará el evento.';

  @override
  String get eventDetailFinishButton => 'Finalizar evento';

  @override
  String get eventDetailCancelButton => 'Cancelar evento';

  @override
  String get eventDetailKeepEvent => 'Mantener evento';

  @override
  String get eventDetailLiveBadge => 'EN VIVO';

  @override
  String get eventDetailCancelledBadge => 'CANCELADO';

  @override
  String get eventDetailCompletedBadge => 'COMPLETADO';

  @override
  String get eventDetailUpcomingBadge => 'PRÓXIMO';

  @override
  String get eventDetailLocation => 'Ubicación';

  @override
  String get eventDetailBuyIn => 'Buy-in';

  @override
  String get eventDetailStakes => 'Stakes';

  @override
  String get eventDetailStartingStack => 'Stack inicial';

  @override
  String get eventDetailAbout => 'ACERCA DE';

  @override
  String get eventDetailAddedToCalendar => '¡Evento agregado a tu calendario!';

  @override
  String eventDetailCalendarFailed(String error) {
    return 'Error al agregar al calendario: $error';
  }

  @override
  String get eventManagementEventsTitle => 'Eventos';

  @override
  String get eventManagementNewEvent => 'Nuevo evento';

  @override
  String get eventManagementNoEvents => 'Sin eventos';

  @override
  String get eventManagementNoEventsSubtitle =>
      'Crea un evento para rastrear rankings en vivo';

  @override
  String get eventManagementActiveEvents => 'Eventos activos';

  @override
  String get eventManagementPastEvents => 'Eventos pasados';

  @override
  String eventManagementErrorLoading(String error) {
    return 'Error al cargar eventos: $error';
  }

  @override
  String get eventManagementNoTables =>
      'Sin mesas disponibles. Crea mesas primero.';

  @override
  String eventManagementCreated(String name) {
    return 'Evento \"$name\" creado';
  }

  @override
  String eventManagementCreateFailed(String error) {
    return 'Error al crear evento: $error';
  }

  @override
  String get eventManagementEndEvent => 'Terminar evento';

  @override
  String eventManagementEndConfirm(String name) {
    return '¿Estás seguro de que deseas terminar \"$name\"?';
  }

  @override
  String eventManagementEnded(String name) {
    return 'Evento \"$name\" terminado';
  }

  @override
  String eventManagementEndFailed(String error) {
    return 'Error al terminar evento: $error';
  }

  @override
  String get eventManagementLinkCopied => 'Enlace copiado al portapapeles';

  @override
  String get eventManagementShare => 'Compartir';

  @override
  String get eventManagementPause => 'Pausar';

  @override
  String get eventManagementResume => 'Reanudar';

  @override
  String get eventManagementEnd => 'Terminar';

  @override
  String get eventManagementCreateEvent => 'Crear evento';

  @override
  String get eventManagementEventNameHint =>
      'ej., Tournament del viernes por la noche';

  @override
  String get eventManagementSelectTables => 'Seleccionar mesas';

  @override
  String eventManagementTableNumber(int number) {
    return 'Mesa $number';
  }

  @override
  String get eventManagementPublicEvent => 'Evento público';

  @override
  String get eventManagementPublicSubtitle =>
      'Cualquiera puede ver la tabla de clasificación';

  @override
  String get eventManagementAccessCode => 'Código de acceso (opcional)';

  @override
  String get eventManagementAccessCodeSubtitle =>
      'Para compartir con usuarios específicos';

  @override
  String get eventManagementEnterName =>
      'Por favor ingresa un nombre de evento';

  @override
  String get eventManagementSelectTable =>
      'Por favor selecciona al menos una mesa';

  @override
  String get eventManagementPublic => 'Público';

  @override
  String get eventManagementPrivate => 'Privado';

  @override
  String adminEventTablesSummary(int count, int occupied, int open) {
    return '$count mesas • $occupied sentados • $open abiertos';
  }

  @override
  String get adminEventTablesAddTable => 'Agregar mesa';

  @override
  String get adminEventTablesNoTables =>
      'No hay mesas disponibles para agregar';

  @override
  String adminEventTablesCloseConfirm(String tableName) {
    return '¿Cerrar $tableName?';
  }

  @override
  String adminEventTablesCloseWithPlayers(int count) {
    return 'Esto moverá a $count jugador(es) a la lista de espera y quitará la mesa de este evento.';
  }

  @override
  String get adminEventTablesCloseEmpty =>
      'Esto quitará la mesa de este evento.';

  @override
  String get adminEventTablesCloseButton => 'Cerrar mesa';

  @override
  String adminEventTablesTableAdded(String tableName) {
    return '$tableName agregada al evento';
  }

  @override
  String adminEventTablesClosedWithWaitlist(String tableName, int count) {
    return '$tableName cerrada. $count jugador(es) movidos a la lista de espera.';
  }

  @override
  String adminEventTablesClosed(String tableName) {
    return '$tableName cerrada.';
  }

  @override
  String get adminEventTablesNoWaitlist => 'Nadie en la lista de espera';

  @override
  String adminEventTablesWaitlistCount(int count) {
    return '$count en lista de espera';
  }

  @override
  String adminEventTablesWaitlistNext(String name) {
    return 'Siguiente: $name';
  }

  @override
  String get adminEventTablesWaitlist => 'Lista de espera';

  @override
  String get adminEventTablesNotified => 'Notificado';

  @override
  String get adminEventTablesNotify => 'Notificar';

  @override
  String get adminEventTablesSeat => 'Sentar';

  @override
  String adminEventTablesSeatAt(String tableName, int count) {
    return '$tableName ($count abiertos)';
  }

  @override
  String get adminEventTablesNoEmptySeats =>
      'No hay asientos vacíos en esta mesa';

  @override
  String adminEventTablesPlayerSeated(String name, String tableName) {
    return '$name sentado en $tableName';
  }

  @override
  String adminEventTablesPlayerNotified(String name) {
    return '$name notificado';
  }

  @override
  String get adminTableSeatPlayer => 'Sentar jugador';

  @override
  String get adminTableFromWaitlist => 'De la lista de espera';

  @override
  String adminTableWaitlistNextIs(String name) {
    return '$name es el siguiente';
  }

  @override
  String get adminTableClubMember => 'Miembro del club';

  @override
  String get adminTableSearchMembers => 'Buscar miembros existentes';

  @override
  String get adminTableWalkUpPlayer => 'Jugador sin reserva';

  @override
  String get adminTableAddByName => 'Agregar por nombre';

  @override
  String get adminTableSelectMember => 'Seleccionar miembro';

  @override
  String get adminTableSearch => 'Buscar...';

  @override
  String get adminTablePlayerName => 'Nombre del jugador';

  @override
  String adminTableWaitingForApproval(int seatNumber) {
    return 'Esperando aprobación para unirse al asiento #$seatNumber';
  }

  @override
  String get adminTableReject => 'Rechazar';

  @override
  String get adminTableApprove => 'Aprobar';

  @override
  String get adminTableRemove => 'Quitar';

  @override
  String adminTableSeatNumber(int seatNumber) {
    return 'Asiento #$seatNumber';
  }

  @override
  String get adminTableNoEmptySeats => 'No hay asientos vacíos disponibles';

  @override
  String adminTableSeatPlayerName(String name) {
    return 'Sentar a $name';
  }

  @override
  String get adminTableSelectSeat => 'Selecciona un asiento:';

  @override
  String adminTablePlayerSeated(String name) {
    return '$name sentado';
  }

  @override
  String adminTableAlreadySeated(String name, String location) {
    return '$name ya está sentado en $location';
  }

  @override
  String adminTablePlayerApproved(String name) {
    return '$name aprobado';
  }

  @override
  String get adminTablePlayerRejected => 'Jugador rechazado';

  @override
  String get adminTablePlayerRemoved => 'Jugador removido';

  @override
  String adminTableWaitlistInCount(int count) {
    return '$count en lista de espera';
  }

  @override
  String adminTableWaitlistNextName(String name) {
    return 'Siguiente: $name';
  }

  @override
  String adminTableNotifiedName(String name) {
    return '$name notificado';
  }

  @override
  String clubCashGameStakes(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String clubCashGameTablesSummary(int count, int occupied, int open) {
    return '$count mesas · $occupied sentados · $open abiertos';
  }

  @override
  String clubCashGameTableNumber(int number) {
    return 'Mesa $number';
  }

  @override
  String get clubCashGameNoTables => 'Sin mesas en este grupo';

  @override
  String clubCashGameFailedToLoad(String error) {
    return 'Error al cargar mesas: $error';
  }

  @override
  String get clubCashGameAlreadySeated => 'Ya estás sentado en una mesa';

  @override
  String get clubCashGameSeatAvailable =>
      'Hay un asiento disponible para ti, acércate al registro';

  @override
  String clubCashGameJoinedWaitlist(int position) {
    return 'Te uniste a la lista de espera en la posición #$position';
  }

  @override
  String clubCashGameJoinFailed(String error) {
    return 'Error al unirse a la lista de espera: $error';
  }

  @override
  String get clubCashGameLeftWaitlist => 'Saliste de la lista de espera';

  @override
  String clubCashGameLeaveFailed(String error) {
    return 'Error al salir de la lista de espera: $error';
  }

  @override
  String get clubCashGameViewWaitlist => 'Ver lista de espera';

  @override
  String get clubCashGameInWaitlist => 'En lista de espera';

  @override
  String clubCashGameInWaitlistPosition(int position) {
    return 'En lista de espera · #$position';
  }

  @override
  String get clubCashGameJoinWaitlist => 'Unirse a lista de espera';

  @override
  String get clubCashGameLeaveWaitlistConfirm =>
      '¿Salir de la lista de espera?';

  @override
  String get clubCashGameLosePosition => 'Perderás tu posición actual.';

  @override
  String get clubCashGameKeep => 'Mantener';

  @override
  String get clubCashGameLeave => 'Salir';

  @override
  String clubCashGameRefreshFailed(String error) {
    return 'No se pudieron actualizar las mesas: $error';
  }

  @override
  String get clubCashGameWaitlistTitle => 'Lista de espera';

  @override
  String clubCashGameNotified(String name) {
    return '$name ha sido notificado';
  }

  @override
  String clubCashGameNotifyFailed(String error) {
    return 'Error al notificar: $error';
  }

  @override
  String get clubCashGameCouldNotLoad => 'No se pudo cargar la lista de espera';

  @override
  String get clubCashGameNoOneOnWaitlist => 'Nadie en la lista de espera';

  @override
  String get clubCashGamePlayer => 'Jugador';

  @override
  String clubCashGameNotifiedStatus(String time) {
    return 'Notificado • $time';
  }

  @override
  String clubCashGameJoinedTime(String time) {
    return 'Unido $time';
  }

  @override
  String get clubCashGameJustNow => 'ahora mismo';

  @override
  String clubCashGameMinutesAgo(int count) {
    return 'hace ${count}m';
  }

  @override
  String clubCashGameHoursAgo(int count) {
    return 'hace ${count}h';
  }

  @override
  String clubCashGameDaysAgo(int count) {
    return 'hace ${count}d';
  }

  @override
  String get clubCashGameAddTable => 'Agregar mesa';

  @override
  String get clubCashGameNewTableName => 'Nuevo nombre de mesa (opcional)';

  @override
  String get clubCashGameAdd => 'Agregar';

  @override
  String clubCashGameAddedToGroup(String tableName) {
    return '$tableName agregada al grupo';
  }

  @override
  String clubCashGameAddFailed(String error) {
    return 'Error al agregar mesa: $error';
  }

  @override
  String clubCashGameAttachFailed(String error) {
    return 'Error al vincular mesa: $error';
  }

  @override
  String get clubCashGameAvailableTables => 'Mesas disponibles';

  @override
  String get clubCashGameInUseByOther => 'En uso por otros eventos';

  @override
  String get clubCashGameNoOtherTables => 'Sin otras mesas en este club aún';

  @override
  String clubCashGameInUseBy(String eventName) {
    return 'En uso por $eventName';
  }

  @override
  String clubCashGameSeats(int count) {
    return 'Asientos $count';
  }

  @override
  String memberEventTablesSummary(int count, int occupied, int open) {
    return '$count mesas • $occupied sentados • $open abiertos';
  }

  @override
  String memberEventJoinedWaitlist(int position) {
    return 'Te uniste a la lista de espera en la posición #$position';
  }

  @override
  String memberEventJoinFailed(String error) {
    return 'Error al unirse a la lista de espera: $error';
  }

  @override
  String get memberEventLeftWaitlist => 'Saliste de la lista de espera';

  @override
  String memberEventLeaveFailed(String error) {
    return 'Error al salir de la lista de espera: $error';
  }

  @override
  String memberEventWaitlistPosition(int position) {
    return 'Posición #$position en lista de espera';
  }

  @override
  String memberEventTotalWaiting(int count) {
    return '$count en espera total';
  }

  @override
  String get memberEventLeaveWaitlist => 'Salir de la lista de espera';

  @override
  String memberEventJoinWaitlistWithCount(int count) {
    return 'Unirse a lista de espera ($count esperando)';
  }

  @override
  String get memberEventJoinWaitlist => 'Unirse a lista de espera';

  @override
  String get memberEventAllTablesFull => 'Todas las mesas están llenas';

  @override
  String get dealerHomeTitle => 'Modo Dealer';

  @override
  String get dealerHomeNoClubs => 'Sin clubs encontrados';

  @override
  String get dealerHomeNoClubsOwnerHint => 'Crea tu primer club para comenzar.';

  @override
  String get dealerHomeNoClubsMemberHint =>
      'Aún no eres miembro de ningún club.\nPide a un dueño de club que te invite.';

  @override
  String get dealerHomeCreateClub => 'Crear club';

  @override
  String get dealerHomeDealer => 'Dealer';

  @override
  String dealerHomeClubCount(int count) {
    return '$count clubs';
  }

  @override
  String get dealerHomeActiveSessions => 'Sesiones activas';

  @override
  String get dealerHomeClubs => 'Clubs';

  @override
  String get dealerHomeTables => 'Mesas';

  @override
  String get dealerHomeAddTable => 'Agregar mesa';

  @override
  String get dealerHomeTableNameLabel => 'Nombre de la mesa';

  @override
  String get dealerHomeTableNameHint => 'ej., Mesa 1, Mesa principal';

  @override
  String dealerHomeTableAdded(String name, String clubName) {
    return '¡Mesa \"$name\" agregada a $clubName!';
  }

  @override
  String dealerHomeAddTableFailed(String error) {
    return 'Error al agregar mesa: $error';
  }

  @override
  String get dealerHomeClubName => 'Nombre del club';

  @override
  String get dealerHomeCreate => 'Crear';

  @override
  String dealerHomeClubCreated(String name) {
    return '¡Club \"$name\" creado exitosamente!';
  }

  @override
  String dealerHomeClubCreateFailed(String error) {
    return 'Error al crear club: $error';
  }

  @override
  String get dealerHomeNoTables => 'Sin mesas en este club';

  @override
  String dealerHomeActiveHand(int number) {
    return 'Activa - Mano #$number';
  }

  @override
  String get dealerHomeInactive => 'Inactiva';

  @override
  String get dealerHomeResume => 'Reanudar';

  @override
  String get dealerHomeStart => 'Iniciar';

  @override
  String get dealerHomeSessionSettings => 'Ajustes de sesión';

  @override
  String get dealerHomeSmallBlind => 'Small Blind';

  @override
  String get dealerHomeBigBlind => 'Big Blind';

  @override
  String get dealerHomeBBAnte => 'BB Ante';

  @override
  String get dealerHomeGameType => 'Tipo de juego';

  @override
  String get dealerHomeCash => 'Cash';

  @override
  String get dealerHomeTournament => 'Tournament';

  @override
  String get dealerHomeButtonPosition => 'Posición del botón';

  @override
  String get dealerHomeStartSession => 'Iniciar sesión';

  @override
  String get dealerHomeCouldNotFind => 'No se pudo encontrar el club o la mesa';

  @override
  String dealerHomeStartFailed(String error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String dealerHomeErrorLoading(String error) {
    return 'Error al cargar datos: $error';
  }

  @override
  String dealerHomeTableCount(int count) {
    return '$count mesas';
  }

  @override
  String dealerTableFailedStartHand(String error) {
    return 'Error al iniciar mano: $error';
  }

  @override
  String dealerTableChopSummary(String winners, String amount) {
    return 'Chop: $winners dividen $amount';
  }

  @override
  String dealerTableWins(String name, String amount) {
    return '$name gana $amount';
  }

  @override
  String dealerTablePotChopped(String names) {
    return 'Pot dividido entre $names';
  }

  @override
  String dealerTableFailedCompleteHand(String error) {
    return 'Error al completar mano: $error';
  }

  @override
  String dealerTablePlayerBusted(String name) {
    return '¡$name eliminado!';
  }

  @override
  String dealerTableNoChipsRemaining(int seatNumber, String amount) {
    return 'Asiento $seatNumber no tiene fichas restantes.\nMonto de Rebuy: $amount';
  }

  @override
  String get dealerTableRemovePlayer => 'Quitar jugador';

  @override
  String get dealerTableRebuy => 'Rebuy';

  @override
  String dealerTableRebuysFor(String name, String amount) {
    return '$name hace Rebuy por $amount';
  }

  @override
  String dealerTableFinishesIn(String name, String position) {
    return '$name termina en $position° lugar';
  }

  @override
  String get dealerTableEndSessionTitle => '¿Terminar sesión?';

  @override
  String get dealerTableEndSessionBody =>
      '¿Estás seguro de que deseas terminar esta sesión?';

  @override
  String get dealerTableEnd => 'Terminar';

  @override
  String get dealerTableDealerChange => 'Cambio de Dealer';

  @override
  String get dealerTableDealerChangeBody =>
      'La sesión será pausada y otro Dealer puede escanear el código QR de la mesa para continuar donde lo dejaste.';

  @override
  String get dealerTableDealerChangePreserve =>
      'Todos los jugadores, Blinds y estado del juego serán preservados.';

  @override
  String get dealerTableDealerChangeResume =>
      'También puedes reanudar esta sesión tú mismo más tarde.';

  @override
  String get dealerTableHandOff => 'Entregar';

  @override
  String get dealerTableSessionPaused =>
      'Sesión pausada. Otro Dealer puede tomar el control ahora.';

  @override
  String dealerTablePauseFailed(String error) {
    return 'Error al pausar sesión: $error';
  }

  @override
  String get dealerTableEventCancelled => 'Evento cancelado';

  @override
  String get dealerTableEventFinished => 'Evento finalizado';

  @override
  String get dealerTableEventCancelledBody =>
      'El administrador del club ha cancelado este evento. Todas las sesiones han sido guardadas.';

  @override
  String get dealerTableEventFinishedBody =>
      'El administrador del club ha finalizado este evento. Todas las sesiones han sido guardadas.';

  @override
  String get dealerTableSessionEnded => 'Sesión terminada';

  @override
  String get dealerTableSessionEndedBody =>
      'Esta sesión ha sido terminada. Todos los datos han sido guardados.';

  @override
  String get dealerTableLeaveTitle => '¿Salir de la mesa del Dealer?';

  @override
  String get dealerTableLeaveActiveHand =>
      'Hay una mano en progreso. Salir ahora puede interrumpir el registro.';

  @override
  String get dealerTableLeaveInactive =>
      'La sesión permanece activa. Puedes volver en cualquier momento.';

  @override
  String dealerTableAutoCorrection(String detected, String corrected) {
    return 'Auto-corregido \"$detected\" → \"$corrected\"';
  }

  @override
  String dealerTableApprovePlayer(String name) {
    return '¿Aprobar a $name?';
  }

  @override
  String get dealerTableStartingChipStack => 'Stack de fichas inicial';

  @override
  String dealerTablePlayerRejected(String name) {
    return '$name rechazado';
  }

  @override
  String dealerTableRejectFailed(String error) {
    return 'Error al rechazar: $error';
  }

  @override
  String dealerTablePlayerJoined(String name, String amount) {
    return '$name se unió con $amount';
  }

  @override
  String dealerTableApproveFailed(String error) {
    return 'Error al aprobar: $error';
  }

  @override
  String get dealerTableChipStack => 'Stack de fichas';

  @override
  String get dealerTableSave => 'Guardar';

  @override
  String get liveSessionHand => 'MANO';

  @override
  String get liveSessionPot => 'POT';

  @override
  String get liveSessionStatus => 'ESTADO';

  @override
  String get liveSessionLive => 'EN VIVO';

  @override
  String get liveSessionWaiting => 'ESPERANDO';

  @override
  String liveSessionWinnerSummary(String winner, String amount) {
    return '$winner gana \$$amount';
  }

  @override
  String get liveSessionSessionEnded => 'Sesión terminada';

  @override
  String get liveSessionSessionEndedBody =>
      'El Dealer ha terminado esta sesión.';

  @override
  String get liveSessionLeaveTitle => '¿Salir de la mesa?';

  @override
  String get liveSessionLeaveBody =>
      '¿Estás seguro de que deseas salir de esta mesa?';

  @override
  String get liveSessionLeave => 'Salir';

  @override
  String liveSessionLeaveFailed(String error) {
    return 'Error al salir: $error';
  }

  @override
  String get liveSessionLeaveTooltip => 'Salir de la mesa';

  @override
  String liveSessionSeat(int number) {
    return 'Asiento $number';
  }

  @override
  String get liveSessionYourSeat => 'Tu asiento';

  @override
  String liveSessionStack(String amount) {
    return 'Stack: $amount';
  }

  @override
  String get liveSessionWaitingForDealer => 'Esperando al Dealer...';

  @override
  String get liveSessionOffline => 'SIN CONEXIÓN';

  @override
  String get liveSessionRecentActions => 'Acciones recientes';

  @override
  String get liveSessionWaitingForAction => 'Esperando acción...';

  @override
  String get liveSessionD => 'D';

  @override
  String get qrScanTitle => 'Escanear QR de mesa';

  @override
  String get qrScanInvalidCode =>
      'Código QR inválido. Por favor escanea un código QR de mesa de poker válido.';

  @override
  String qrScanError(String error) {
    return 'Error al procesar código QR: $error';
  }

  @override
  String get qrScanInstructions =>
      'Apunta tu cámara al código QR de la mesa para unirte';

  @override
  String get clubRequestsTitle => 'Solicitudes de club';

  @override
  String get clubRequestsAll => 'Todas';

  @override
  String get clubRequestsPending => 'Pendientes';

  @override
  String get clubRequestsApproved => 'Aprobadas';

  @override
  String get clubRequestsRejected => 'Rechazadas';

  @override
  String get clubRequestsApproveTitle => 'Aprobar solicitud';

  @override
  String clubRequestsApproveBody(String name) {
    return '¿Estás seguro de que deseas aprobar \"$name\"? Esto creará un nuevo club y te agregará como administrador.';
  }

  @override
  String get clubRequestsRejectTitle => 'Rechazar solicitud';

  @override
  String clubRequestsRejectBody(String name) {
    return 'Por favor proporciona un motivo para rechazar \"$name\":';
  }

  @override
  String get clubRequestsRejectHint => 'Motivo del rechazo...';

  @override
  String get clubRequestsApproveButton => 'Aprobar';

  @override
  String get clubRequestsRejectButton => 'Rechazar';

  @override
  String clubRequestsApproved2(String name) {
    return '¡$name ha sido aprobado!';
  }

  @override
  String clubRequestsRejected2(String name) {
    return '$name ha sido rechazado.';
  }

  @override
  String get clubRequestsNoRequests => 'Sin solicitudes';

  @override
  String get clubRequestsPendingBadge => 'PENDIENTE';

  @override
  String get clubRequestsApprovedBadge => 'APROBADO';

  @override
  String get clubRequestsRejectedBadge => 'RECHAZADO';

  @override
  String get clubRequestsAddress => 'Dirección';

  @override
  String get clubRequestsPhone => 'Teléfono';

  @override
  String get clubRequestsAdminEmail => 'Correo del administrador';

  @override
  String get clubRequestsRequestedBy => 'Solicitado por';

  @override
  String get clubRequestsRequesterEmail => 'Correo del solicitante';

  @override
  String get clubRequestsRequestedAt => 'Solicitado el';

  @override
  String get clubRequestsReviewedAt => 'Revisado el';

  @override
  String get clubRequestsRejectionReason => 'Motivo del rechazo:';

  @override
  String get supportRequestsTitle => 'Solicitudes de soporte';

  @override
  String get supportRequestsAll => 'Todas';

  @override
  String get supportRequestsPending => 'Pendientes';

  @override
  String get supportRequestsClosed => 'Cerradas';

  @override
  String get supportRequestsResolveTitle => 'Resolver solicitud';

  @override
  String get supportRequestsResolveBody => 'Respuesta opcional al usuario:';

  @override
  String get supportRequestsResponseHint => 'Respuesta (opcional)...';

  @override
  String get supportRequestsResolve => 'Resolver';

  @override
  String get supportRequestsResolved => 'Solicitud resuelta';

  @override
  String get supportRequestsRejectTitle => 'Rechazar solicitud';

  @override
  String get supportRequestsRejectBody => 'Motivo del rechazo:';

  @override
  String get supportRequestsRejectHint => 'Motivo...';

  @override
  String get supportRequestsReject => 'Rechazar';

  @override
  String get supportRequestsRejected => 'Solicitud rechazada';

  @override
  String get supportRequestsNoRequests => 'Sin solicitudes';

  @override
  String get supportRequestsPendingBadge => 'PENDIENTE';

  @override
  String get supportRequestsResolvedBadge => 'RESUELTO';

  @override
  String get supportRequestsRejectedBadge => 'RECHAZADO';

  @override
  String get supportRequestsCategory => 'Categoría';

  @override
  String get supportRequestsUser => 'Usuario';

  @override
  String get supportRequestsEmail => 'Correo electrónico';

  @override
  String get supportRequestsSubmitted => 'Enviado';

  @override
  String get supportRequestsDescription => 'Descripción';

  @override
  String get supportRequestsAdminResponse => 'Respuesta del administrador';

  @override
  String get supportRequestsBugReport => 'Reporte de error';

  @override
  String get supportRequestsFeatureRequest => 'Solicitud de función';

  @override
  String get supportRequestsAccountIssue => 'Problema de cuenta';

  @override
  String get debugHandViewerTitle => 'Visor de manos (Debug)';

  @override
  String get debugHandViewerSessionName => 'Nombre de sesión';

  @override
  String get debugHandViewerHandNumbers =>
      'Números de mano (separados por coma, ej., 27,28)';

  @override
  String get debugHandViewerFetchData => 'Obtener datos';

  @override
  String get debugHandViewerCopied => 'Copiado al portapapeles';

  @override
  String get debugHandViewerNoData =>
      'Sin datos aún. Ingresa el nombre de la sesión y haz clic en Obtener datos.';

  @override
  String get navDrawerSettings => 'Configuración';

  @override
  String get navDrawerRegisterClub => 'Registrar club';

  @override
  String get navDrawerHelpSupport => 'Ayuda y soporte';

  @override
  String get navDrawerLogOut => 'Cerrar sesión';

  @override
  String get navDrawerUpgrade => 'Mejorar plan';

  @override
  String get navDrawerUserFallback => 'Usuario';

  @override
  String get navDrawerStatistics => 'Estadísticas';

  @override
  String get navDrawerEvents => 'Eventos';

  @override
  String get navDrawerBankroll => 'Bankroll';

  @override
  String get navDrawerClubs => 'Clubes';

  @override
  String get navDrawerNoClubsYet => 'Aún no hay clubes';

  @override
  String navDrawerMemberCount(int count) {
    return '$count miembros';
  }

  @override
  String get navDrawerRoleAdmin => 'Admin';

  @override
  String get navDrawerRoleDealer => 'Dealer';

  @override
  String get navDrawerRoleMember => 'Miembro';

  @override
  String get navDrawerVersion => 'Versión 1.0.0';

  @override
  String get navDrawerLastLoginToday => 'Último acceso: Hoy';

  @override
  String get navDrawerNoEarningsTitle => 'Sin datos de ganancias';

  @override
  String get navDrawerNoEarningsBody =>
      'Primero añade resultados de sesiones para ver tu gráfico de ganancias. Puedes añadir resultados desde la página de Perfil.';

  @override
  String get navDrawerSignOutTitle => 'Cerrar sesión';

  @override
  String get navDrawerSignOutMessage =>
      '¿Estás seguro de que quieres cerrar sesión?';

  @override
  String get navDrawerSignOut => 'Cerrar sesión';

  @override
  String get multiPotMainPot => 'Main Pot';

  @override
  String multiPotSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String multiPotPlayerFallback(String id) {
    return 'Jugador $id';
  }

  @override
  String get multiPotMainPotWinner => 'ganador del Main Pot';

  @override
  String get multiPotEligibleFromPrevious => 'elegible del Pot anterior';

  @override
  String multiPotAutoAwarded(String name, String reason) {
    return 'Otorgado automáticamente a $name ($reason)';
  }

  @override
  String get multiPotChoppedPot => 'Chopped Pot';

  @override
  String get multiPotSingleWinner => 'Un solo ganador';

  @override
  String get multiPotSelectAllWinners => 'Selecciona todos los ganadores:';

  @override
  String get multiPotSelectTheWinner => 'Selecciona el ganador:';

  @override
  String get multiPotSelectWinnersTitle => 'Seleccionar ganadores';

  @override
  String get multiPotMultiplePots =>
      'Múltiples Pot — selecciona el ganador de cada uno';

  @override
  String get winnerSelectionWhoChopped => '¿Quién repartió este Pot?';

  @override
  String get winnerSelectionWhoWon => '¿Quién ganó esta mano?';

  @override
  String get winnerSelectionChoppedPot => 'Chopped Pot';

  @override
  String get winnerSelectionIndividualShares => 'Partes individuales:';

  @override
  String get winnerSelectionSelectAllWinners =>
      'Selecciona todos los ganadores:';

  @override
  String get winnerSelectionTapTheWinner => 'Toca al ganador:';

  @override
  String get winnerSelectionLongPressHint => 'Mantén pulsado para Chopped Pot';

  @override
  String get winnerSelectionConfirmChop => 'Confirmar Chop';

  @override
  String get winnerSelectionConfirmWinner => 'Confirmar ganador';

  @override
  String get winnerSelectionBackToSingle => 'Volver a un solo ganador';

  @override
  String get boardCardsCards => 'Cartas';

  @override
  String get boardCardsCard => 'Carta';

  @override
  String get allInBoardTitle => 'Cartas del board en All-in';

  @override
  String get raiseSnapReleaseToType => 'Suelta en mín. para escribir';

  @override
  String get slidingNotificationHeader => 'NOTIFICACIÓN';

  @override
  String get eventSuccessTitle => '¡Listo! Tu evento está en el calendario.';

  @override
  String get eventSuccessSubtitle =>
      'Puedes editarlo o eliminarlo en cualquier momento';

  @override
  String get eventSuccessGoToCalendar => 'Ir al calendario';

  @override
  String get eventSuccessAddAnother => 'Añadir otro evento';

  @override
  String get stackChartNoData => 'Sin datos';

  @override
  String get stackChartStart => 'Inicio';

  @override
  String get stackChartRebuy => 'Rebuy';

  @override
  String get stackChartEnd => 'Fin';

  @override
  String get stackChartTitle => 'Gráfico de Stack';

  @override
  String get stackChartAvgGrowth => 'Crecimiento prom.';

  @override
  String get stackChartDuration => 'Duración';

  @override
  String get stackChartProfitLoss => 'G/P';

  @override
  String get actionGridSelectAction => 'Seleccionar acción';

  @override
  String get pokerTablePlayerFallback => 'Jugador';

  @override
  String get loadingDefault => 'Cargando...';

  @override
  String get forgotPasswordFailedSendCode =>
      'No se pudo enviar el código. Inténtalo de nuevo.';

  @override
  String get forgotPasswordNewCodeSent => 'Nuevo código enviado a tu correo.';

  @override
  String get forgotPasswordFailedResend => 'No se pudo reenviar el código.';

  @override
  String get forgotPasswordEnterFullCode =>
      'Por favor, introduce el código completo de 6 dígitos.';

  @override
  String get forgotPasswordInvalidCode =>
      'Código inválido o expirado. Inténtalo de nuevo.';

  @override
  String get forgotPasswordResetSuccess =>
      '¡Contraseña restablecida! Por favor, inicia sesión.';

  @override
  String get forgotPasswordResetTitle => 'Restablecer contraseña';

  @override
  String get forgotPasswordResetSubtitle =>
      'Introduce tu correo para recibir un código de verificación';

  @override
  String get forgotPasswordCheckEmail => 'Revisa tu correo';

  @override
  String get forgotPasswordSetNewPassword => 'Establecer nueva contraseña';

  @override
  String get forgotPasswordSetNewSubtitle =>
      'Elige una contraseña segura para tu cuenta';

  @override
  String get forgotPasswordEmail => 'Correo electrónico';

  @override
  String get forgotPasswordEnterEmail => 'Por favor, introduce tu correo';

  @override
  String get forgotPasswordValidEmail =>
      'Por favor, introduce un correo válido';

  @override
  String get forgotPasswordSendCode => 'Enviar código';

  @override
  String get forgotPasswordVerifyCode => 'Verificar código';

  @override
  String get forgotPasswordResendCode => 'Reenviar código';

  @override
  String forgotPasswordResendIn(String time) {
    return 'Reenviar código en $time';
  }

  @override
  String get forgotPasswordNewPassword => 'Nueva contraseña';

  @override
  String get forgotPasswordEnterPassword =>
      'Por favor, introduce una contraseña';

  @override
  String get forgotPasswordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get forgotPasswordConfirm => 'Confirmar contraseña';

  @override
  String get forgotPasswordConfirmRequired =>
      'Por favor, confirma tu contraseña';

  @override
  String get forgotPasswordMismatch => 'Las contraseñas no coinciden';

  @override
  String get forgotPasswordResetButton => 'Restablecer contraseña';

  @override
  String get onboardingTrackTitle => 'REGISTRA CADA\nMANO';

  @override
  String get onboardingTrackSubtitle =>
      'Registra acciones, cartas del board y resultados de cada mano — en vivo o después de la sesión.';

  @override
  String get onboardingKnowTitle => 'CONOCE TU\nJUEGO';

  @override
  String get onboardingKnowSubtitle =>
      'VPIP, PFR, 3-Bet, C-Bet y más — observa cómo evolucionan tus estadísticas en tiempo real.';

  @override
  String get onboardingClubsTitle => 'JUEGA EN\nCLUBES';

  @override
  String get onboardingClubsSubtitle =>
      'Únete a eventos en vivo, consulta rankings y rastrea a tus oponentes entre sesiones.';

  @override
  String get dealerTableEnterStartingStack => 'Introduce el Stack inicial';

  @override
  String get dealerTableNoPendingRequests =>
      'No hay solicitudes de unión pendientes';

  @override
  String get dealerTablePendingJoinRequests =>
      'Solicitudes de unión pendientes';

  @override
  String get dealerTableUnknown => 'Desconocido';

  @override
  String dealerTableSeatNumber(int number) {
    return 'Asiento $number';
  }

  @override
  String get dealerTableReview => 'Revisar';

  @override
  String get dealerTableSmallBlind => 'Small Blind';

  @override
  String get dealerTableBigBlind => 'Big Blind';

  @override
  String get dealerTableNewBlindsNote =>
      'Los nuevos Blinds se aplicarán a partir de la siguiente mano.';

  @override
  String get dealerTableSmallMustBeLess =>
      'El Small Blind debe ser menor que el Big Blind';

  @override
  String get dealerTableBlindsMustBePositive =>
      'Los Blinds deben ser mayores que 0';

  @override
  String dealerTableBlindsUpdated(String sb, String bb) {
    return 'Blinds actualizados a $sb/$bb';
  }

  @override
  String dealerTableFailedUpdateBlinds(String error) {
    return 'No se pudieron actualizar los Blinds: $error';
  }

  @override
  String dealerTableFailedMoveButton(String error) {
    return 'No se pudo mover el BTN: $error';
  }

  @override
  String get dealerTablePending => 'PENDIENTE';

  @override
  String get dealerTableConnectionLost => 'Conexión perdida';

  @override
  String get dealerTableReconnecting => 'Intentando reconectar...';

  @override
  String get dealerTableReconnect => 'Reconectar';

  @override
  String get dealerTableResetHandTitle => '¿Reiniciar mano?';

  @override
  String get dealerTableResetHandBody =>
      'Se deshicieron todas las acciones. ¿Quieres iniciar una nueva mano?';

  @override
  String get dealerTableKeepCurrent => 'Mantener actual';

  @override
  String get dealerTableNewHand => 'Nueva mano';

  @override
  String get dealerTableHandReset => 'Mano reiniciada — listo para nueva mano';

  @override
  String dealerTableAddPlayerToSeat(int number) {
    return 'Añadir jugador al asiento $number';
  }

  @override
  String get dealerTableSearchUser => 'Buscar usuario';

  @override
  String get dealerTableManualEntry => 'Entrada manual';

  @override
  String get dealerTableSearchByName => 'Buscar por nombre';

  @override
  String get dealerTableTypeToSearch => 'Escribe para buscar usuarios...';

  @override
  String get dealerTableNoUsersFound =>
      'No se encontraron usuarios. Prueba la entrada manual.';

  @override
  String get dealerTablePlayerNameLabel => 'Nombre del jugador';

  @override
  String get dealerTableEnterPlayerName => 'Introduce el nombre del jugador';

  @override
  String get dealerTableAddPlayer => 'Añadir jugador';

  @override
  String get dealerTableEndSession => 'Finalizar sesión';

  @override
  String dealerTableUpdatedStack(String name, String amount) {
    return 'Stack de $name actualizado a $amount';
  }

  @override
  String dealerTableFailedUpdateStack(String error) {
    return 'No se pudo actualizar el Stack: $error';
  }

  @override
  String dealerTableSittingAtSeat(int number) {
    return 'Ahora estás jugando en el asiento $number';
  }

  @override
  String dealerTableFailedSitAt(String error) {
    return 'No se pudo sentar en la mesa: $error';
  }

  @override
  String dealerTableFailedAddPlayer(String error) {
    return 'No se pudo añadir jugador: $error';
  }

  @override
  String dealerTableFailedRemovePlayer(String error) {
    return 'No se pudo eliminar jugador: $error';
  }

  @override
  String get eventDetailEventType => 'Tipo de evento';

  @override
  String get eventDetailSeated => 'Sentado';

  @override
  String get eventDetailAreYouGoing => '¿VAS A IR?';

  @override
  String get eventDetailAddedToCalendarBtn => 'Añadido al calendario';

  @override
  String get eventDetailAddToCalendarBtn => 'Añadir al calendario';

  @override
  String get eventDetailWhosGoing => 'Quién viene';

  @override
  String get eventDetailSeeAll => 'Ver todo';

  @override
  String get eventDetailStartDealing => 'Empezar a repartir';

  @override
  String get eventDetailViewLiveRankings => 'Ver ranking en vivo';

  @override
  String get eventDetailNotSeatedAtTable =>
      'No estás sentado en ninguna mesa actualmente';

  @override
  String get eventDetailNotSeatedInEvent => 'No estás sentado en este evento';

  @override
  String eventDetailErrorFindingSeat(String error) {
    return 'Error al buscar tu asiento: $error';
  }

  @override
  String get eventDetailReturnToSeat => 'Volver a mi asiento';

  @override
  String get eventDetailViewFinalStandings => 'Ver clasificación final';

  @override
  String get eventDetailManageTables => 'Gestionar mesas';

  @override
  String get eventDetailManageTable => 'Gestionar mesa';

  @override
  String get eventDetailSeeAvailability => 'Ver disponibilidad';

  @override
  String get eventDetailYoureSeated => 'Estás sentado';

  @override
  String get eventDetailNoTablesAssigned =>
      'No hay mesas asignadas a este evento';

  @override
  String get eventDetailStartEvent => 'Iniciar evento';

  @override
  String get eventDetailFinish => 'Finalizar';

  @override
  String eventDetailFailedFinishCancel(String action, String error) {
    return 'No se pudo $action el evento: $error';
  }

  @override
  String homeTableSeatInfo(String table, String seat) {
    return 'Mesa $table, Asiento #$seat';
  }

  @override
  String get homeRequestResolved => 'Solicitud resuelta';

  @override
  String get homeRequestClosed => 'Solicitud cerrada';

  @override
  String get homeResponse => 'Respuesta';

  @override
  String homeErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String homeErrorLoadingEvent(String error) {
    return 'Error al cargar evento: $error';
  }

  @override
  String homeFailedLoadEvent(String error) {
    return 'No se pudo cargar el evento: $error';
  }

  @override
  String homeFailedUpdateEvent(String error) {
    return 'No se pudo actualizar el evento: $error';
  }

  @override
  String homeErrorDeletingEvent(String error) {
    return 'Error al eliminar evento: $error';
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
  String get commonLeave => 'Salir';

  @override
  String get commonAccept => 'Aceptar';

  @override
  String get commonLoadingHands => 'Cargando manos...';

  @override
  String sessionHistoryButtonPosition(String position) {
    return 'Posición del BTN: $position';
  }

  @override
  String sessionHistoryPlayerCount(String count) {
    return 'Número de jugadores: $count';
  }

  @override
  String sessionHistoryStartTime(String time) {
    return 'Hora de inicio: $time';
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
    return 'Error de sincronización: $error';
  }

  @override
  String sessionHistoryClearFailed(String error) {
    return 'No se pudieron borrar las sesiones: $error';
  }

  @override
  String get notificationsClubNotFound => 'Club no encontrado';

  @override
  String get notificationsAccept => 'Aceptar';

  @override
  String get notificationsInvitationAccepted => 'Invitación aceptada';

  @override
  String get notificationsInvitationDeclined => 'Invitación rechazada';

  @override
  String get notificationsInvitationDeclinedMsg => 'Invitación rechazada';

  @override
  String get notificationsEventNotFound => 'Evento no encontrado';

  @override
  String notificationsFailedLoadClub(String error) {
    return 'No se pudo cargar el club: $error';
  }

  @override
  String notificationsErrorLoadingEvent(String error) {
    return 'Error al cargar evento: $error';
  }

  @override
  String invitationsFailedLoad(String error) {
    return 'No se pudieron cargar las invitaciones: $error';
  }

  @override
  String invitationsFailedAccept(String error) {
    return 'No se pudo aceptar la invitación: $error';
  }

  @override
  String get invitationsDeclined => 'Invitación rechazada';

  @override
  String invitationsFailedDecline(String error) {
    return 'No se pudo rechazar la invitación: $error';
  }

  @override
  String get clubSettingsTableAdded => 'Mesa añadida';

  @override
  String get clubSettingsTableDeleted => 'Mesa eliminada';

  @override
  String get clubSettingsQrRegenerated => 'Códigos QR regenerados';

  @override
  String clubSettingsErrorPdf(String error) {
    return 'Error al generar PDF: $error';
  }

  @override
  String get clubDashboardActiveDealers => 'Dealer activos';

  @override
  String get clubDashboardPendingInvitations => 'Invitaciones pendientes';

  @override
  String get clubDashboardDealerEmailHint => 'dealer@example.com';

  @override
  String clubDashboardInvitationSent(String email) {
    return 'Invitación enviada a $email';
  }

  @override
  String clubDashboardFailedSendInvite(String error) {
    return 'No se pudo enviar la invitación: $error';
  }

  @override
  String clubDashboardFailedCancelInvite(String error) {
    return 'No se pudo cancelar la invitación: $error';
  }

  @override
  String eventManagementClubEvents(String name) {
    return 'Eventos de $name';
  }

  @override
  String eventManagementFailedUpdate(String error) {
    return 'No se pudo actualizar el evento: $error';
  }

  @override
  String get profileCash => 'Cash';

  @override
  String get profileTournament => 'Tournament';

  @override
  String get profileDevTools => 'Herramientas de desarrollo';

  @override
  String get profilePremiumOverride => 'Anulación Premium';

  @override
  String profileUsingRealStatus(String status) {
    return 'Estado real: $status';
  }

  @override
  String profileOverridden(String status) {
    return 'Anulado: $status';
  }

  @override
  String get profileResetToReal => 'Restablecer al estado real';

  @override
  String get profileVersion => 'Versión 1.0';

  @override
  String profileLastLogin(String date) {
    return 'Último acceso $date';
  }

  @override
  String pokerHandFailedEndSession(String error) {
    return 'No se pudo finalizar la sesión: $error';
  }

  @override
  String pokerHandFailedSaveSession(String error) {
    return 'No se pudo guardar la sesión: $error';
  }

  @override
  String pokerHandRebuyAdded(String amount, String stack) {
    return 'Rebuy añadido: \$$amount (Stack: $stack)';
  }

  @override
  String get pokerHandEndSession => 'Finalizar sesión';

  @override
  String get pokerHandRebuyAmountDollar => 'Monto del Rebuy (\$)';

  @override
  String get pokerHandRebuyChips => 'Fichas de Rebuy';

  @override
  String seatSetupFailedSave(String error) {
    return 'No se pudo guardar: $error';
  }

  @override
  String get seatSetupSelectYourSeat => 'Selecciona tu asiento';

  @override
  String get authExpLinkGoogleTitle => 'Vincular cuenta de Google';

  @override
  String get authExpPassword => 'Contraseña';

  @override
  String get authExpLinkAccount => 'Vincular cuenta';

  @override
  String get individualSetupSessionNameHint => 'ej. \"Poker del viernes\"';

  @override
  String get individualSetupCashGame => 'Cash Game';

  @override
  String get individualSetupTournament => 'Tournament';

  @override
  String get individualSetupEnterAmount => 'Introduce la cantidad';

  @override
  String get individualSetupEnterChipStack => 'Introduce el Stack de fichas';

  @override
  String get individualSetupSmallBlind => 'Small Blind';

  @override
  String get individualSetupBigBlind => 'Big Blind';

  @override
  String get individualSetupEnterValue => 'Introduce el valor';

  @override
  String get individualHandSetupNameHint => 'ej. \"AA vs KK Cooler\"';

  @override
  String get individualHandSetupSmallBlind => 'Small Blind';

  @override
  String get individualHandSetupBigBlind => 'Big Blind';

  @override
  String get individualHandSetupPlayers => 'Jugadores';

  @override
  String get individualHandSetupGameType => 'Tipo de juego';

  @override
  String get playerSessionYourHoleCards => 'Tus Hole Cards';

  @override
  String get playerSessionSeat => 'ASIENTO';

  @override
  String get playerSessionStack => 'STACK';

  @override
  String get playerSessionPot => 'POT';

  @override
  String get playerSessionNotesHint => 'Añadir notas sobre esta mano...';

  @override
  String get dealerQrScanInvalidCode =>
      'Código QR inválido. Escanea un código QR de mesa válido.';

  @override
  String get dealerQrScanWrongClub => 'Esta mesa pertenece a otro club.';

  @override
  String get dealerQrScanTableNotFound =>
      'Mesa no encontrada. Escanea un código QR de mesa válido.';

  @override
  String dealerQrScanError(String error) {
    return 'Error al procesar código QR: $error';
  }

  @override
  String dealerQrScanFailedStart(String error) {
    return 'No se pudo iniciar la sesión: $error';
  }

  @override
  String dealerQrScanTakingOver(String name) {
    return 'Tomando el relevo de $name';
  }

  @override
  String get dealerQrScanHandsPlayed => 'Manos jugadas';

  @override
  String get dealerQrScanBlinds => 'Blinds';

  @override
  String get dealerQrScanPlayers => 'Jugadores';

  @override
  String dealerQrScanFailedResume(String error) {
    return 'No se pudo reanudar la sesión: $error';
  }

  @override
  String get usernameSetupLabel => 'Nombre de usuario';

  @override
  String get stackChartScreenAvgGrowth => 'Crecimiento prom.';

  @override
  String get stackChartScreenDuration => 'Duración';

  @override
  String get stackChartScreenProfitLoss => 'G/P';

  @override
  String get stackChartScreenStack => 'Stack';

  @override
  String get quickStackSearchHint => 'Buscar o añadir jugador...';

  @override
  String get sessionHandsLoading => 'Cargando manos...';

  @override
  String createEventDefaultCashGame(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get createEventDefaultCashGameNoStakes => 'Cash Game';

  @override
  String get eventDashboardTvMode => 'Modo pantalla TV';

  @override
  String get tableSelectionTitle => 'Seleccionar mesa';

  @override
  String get tableSelectionAdminSubtitle => 'Elige una mesa para gestionar';

  @override
  String get tableSelectionMemberSubtitle =>
      'Elige una mesa para ver disponibilidad';

  @override
  String get tableSelectionNoTables => 'No hay mesas disponibles';

  @override
  String tableSelectionOpenSeats(int count) {
    return '$count libres';
  }

  @override
  String tableSelectionSeated(int occupied) {
    return '$occupied/9 sentados';
  }

  @override
  String get monthJan => 'Ene';

  @override
  String get monthFeb => 'Feb';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Abr';

  @override
  String get monthMay => 'May';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Ago';

  @override
  String get monthSep => 'Sep';

  @override
  String get monthOct => 'Oct';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dic';

  @override
  String get weekdaySun => 'Dom';

  @override
  String get weekdayMon => 'Lun';

  @override
  String get weekdayTue => 'Mar';

  @override
  String get weekdayWed => 'Mié';

  @override
  String get weekdayThu => 'Jue';

  @override
  String get weekdayFri => 'Vie';

  @override
  String get weekdaySat => 'Sáb';

  @override
  String opponentsErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String opponentsErrorDeleting(String error) {
    return 'Error al eliminar oponente: $error';
  }

  @override
  String opponentsErrorClearing(String error) {
    return 'Error al limpiar oponentes: $error';
  }

  @override
  String get onboardingReadTitle => 'LEE EL JUEGO\nCOMO UN PRO';

  @override
  String get onboardingReadSubtitle =>
      'Crea una cuenta para comenzar a seguir tu camino en el póker.';

  @override
  String get onboardingCreateAccount => 'Crear cuenta';

  @override
  String get onboardingLogIn => 'Iniciar sesión';

  @override
  String get onboardingSkip => 'Omitir';

  @override
  String get onboardingFinalTable => 'Final Table';

  @override
  String get authExpSignUpTitle => 'Registrarse';

  @override
  String get authExpLogInTitle => 'Inicia sesión en tu cuenta';

  @override
  String get authExpSignUpSubtitle => 'Crea una cuenta para continuar';

  @override
  String get authExpLogInSubtitle =>
      'Ingresa tu email y contraseña para iniciar sesión';

  @override
  String get authExpName => 'Nombre';

  @override
  String get authExpEmail => 'Email';

  @override
  String get authExpEnterName => 'Ingresa tu nombre';

  @override
  String get authExpNameMinLength =>
      'El nombre debe tener al menos 2 caracteres';

  @override
  String get authExpEnterEmail => 'Ingresa tu email';

  @override
  String get authExpValidEmail => 'Ingresa un email válido';

  @override
  String get authExpEnterPassword => 'Ingresa tu contraseña';

  @override
  String get authExpPasswordMinLength =>
      'La contraseña debe tener al menos 6 caracteres';

  @override
  String get authExpBySigningUp => 'Al registrarte, aceptas los ';

  @override
  String get authExpTermsOfService => 'Términos de Servicio';

  @override
  String get authExpAnd => '\ny la ';

  @override
  String get authExpPrivacyPolicy => 'Política de Privacidad';

  @override
  String get authExpCreateAccount => 'Crear cuenta';

  @override
  String get authExpAlreadyHaveAccount => '¿Ya tienes cuenta? ';

  @override
  String get authExpSignIn => 'Iniciar sesión';

  @override
  String get authExpForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authExpDontHaveAccount => '¿No tienes cuenta? ';

  @override
  String get authExpSignUp => 'Registrarse';

  @override
  String get authExpOr => 'o';

  @override
  String get authExpContinueGoogle => 'Continuar con Google';

  @override
  String authExpLinkGoogleMessage(String email) {
    return 'Ya existe una cuenta con $email. Ingresa tu contraseña para vincular tu cuenta de Google.';
  }

  @override
  String forgotPasswordCodeSubtitle(String email) {
    return 'Ingresa el código de 6 dígitos enviado a $email';
  }

  @override
  String get usernameSetupChangeTitle => 'Cambia tu nombre de usuario';

  @override
  String get usernameSetupChooseTitle => 'Elige tu nombre de usuario';

  @override
  String get usernameSetupSubtitle =>
      'Así te conocerán los demás jugadores en la mesa';

  @override
  String get usernameSetupRequired => 'El nombre de usuario es obligatorio';

  @override
  String get usernameSetupCheckingAvailability => 'Verificando disponibilidad…';

  @override
  String get usernameSetupAvailable => '¡Disponible!';

  @override
  String get usernameSetupAlreadyTaken => 'Ya está en uso';

  @override
  String get usernameSetupCurrentUsername =>
      'Este es tu nombre de usuario actual';

  @override
  String get usernameSetupCouldNotCheck =>
      'No se pudo verificar la disponibilidad';

  @override
  String get usernameSetupJustTaken =>
      'Ese nombre acaba de ser tomado. Intenta otro.';

  @override
  String get usernameSetupRulesHint =>
      '3–20 caracteres · letras, números, guiones bajos';

  @override
  String get usernameSetupUpdateButton => 'Actualizar nombre';

  @override
  String get usernameSetupClaimButton => 'Reservar nombre';

  @override
  String get usernameSetupSkip => 'Omitir por ahora';

  @override
  String get sessionHandsTitle => 'Sesión';

  @override
  String sessionHandsHandsLogged(int count) {
    return '$count manos registradas';
  }

  @override
  String get sessionHandsError => 'Error';

  @override
  String get sessionHandsNoHandsTitle => 'Sin manos registradas';

  @override
  String get sessionHandsNoHandsSubtitle =>
      'Esta sesión aún no tiene manos registradas.';

  @override
  String get sessionHandsWon => 'GANÓ';

  @override
  String sessionHandsActions(int count) {
    return '$count acciones';
  }

  @override
  String get sessionHandsPot => 'Pot';

  @override
  String get stackChartScreenTitle => 'Gráfico de Stack';

  @override
  String get stackChartScreenPokerSession => 'Sesión de póker';

  @override
  String get notificationsScreenTitle => 'Notificaciones';

  @override
  String get notificationsScreenToday => 'Hoy';

  @override
  String get notificationsScreenMarkAllAsRead => 'Marcar todo como leído';

  @override
  String get notificationsScreenMarkAsRead => 'Marcar como leído';

  @override
  String get notificationsScreenNoNotifications => 'Sin notificaciones';

  @override
  String get notificationsScreenClubInvitation => 'Invitación al club';

  @override
  String get notificationsScreenInvitedToJoin => 'Has sido invitado a unirte';

  @override
  String get notificationsScreenDecline => 'Rechazar';

  @override
  String get notificationsScreenNotAuthenticated => 'No autenticado';

  @override
  String get notificationsScreenRequestResolved => 'Solicitud resuelta';

  @override
  String get notificationsScreenRequestClosed => 'Solicitud cerrada';

  @override
  String get notificationsScreenResponse => 'Respuesta';

  @override
  String get notificationsScreenEvents => 'Eventos';

  @override
  String get notificationsScreenRsvp => 'RSVP';

  @override
  String get notificationsScreenClubs => 'Clubes';

  @override
  String get notificationsScreenInvitations => 'Invitaciones';

  @override
  String get notificationsScreenSeats => 'Asientos';

  @override
  String get notificationsScreenSupport => 'Soporte';

  @override
  String notifEventCreatedTitle(String eventName) {
    return 'Nuevo evento: $eventName';
  }

  @override
  String notifEventCreatedBody(String date) {
    return '$date';
  }

  @override
  String notifEventUpdatedTitle(String eventName) {
    return 'Evento actualizado: $eventName';
  }

  @override
  String notifEventUpdatedBody(String clubName) {
    return '$clubName actualizó los detalles del evento';
  }

  @override
  String notifEventCancelledTitle(String eventName) {
    return 'Evento cancelado: $eventName';
  }

  @override
  String notifEventCancelledBody(String clubName, String date) {
    return '$clubName ha cancelado el evento programado para $date';
  }

  @override
  String notifEventStartingTitle(String eventName) {
    return '¡$eventName comienza en 1 hora!';
  }

  @override
  String notifEventStartingBody(String clubName) {
    return 'El evento de $clubName está a punto de comenzar';
  }

  @override
  String notifEventStartedTitle(String eventName) {
    return '¡$eventName está EN VIVO!';
  }

  @override
  String notifEventStartedBody(String clubName) {
    return 'El evento de $clubName ha comenzado - únete para observar';
  }

  @override
  String notifSeatAvailableTitle(String eventName) {
    return 'Asiento disponible: $eventName';
  }

  @override
  String notifSeatAvailableBody(String clubName) {
    return '¡Hay un asiento disponible en $clubName! Abre la app para tomar tu lugar.';
  }

  @override
  String notifMemberRsvpTitle(String memberName) {
    return 'RSVP: $memberName';
  }

  @override
  String notifMemberRsvpBody(
      String memberName, String rsvpStatus, String eventName) {
    return '$memberName respondió \"$rsvpStatus\" a $eventName';
  }

  @override
  String get notifNewClubRequestTitle => 'Nueva solicitud de club';

  @override
  String get notifNewClubRequestBody =>
      'Se ha enviado una nueva solicitud de registro de club';

  @override
  String get notifClubApprovedTitle => 'Club aprobado';

  @override
  String get notifClubApprovedBody => '¡Tu club ha sido aprobado!';

  @override
  String get notifClubRejectedTitle => 'Club rechazado';

  @override
  String get notifClubRejectedBody => 'Tu solicitud de club ha sido rechazada';

  @override
  String get notifMemberInvitedTitle => 'Invitación al club';

  @override
  String get notifMemberInvitedBody => 'Has sido invitado a unirte a un club';

  @override
  String get notifInvitationAcceptedTitle => 'Invitación aceptada';

  @override
  String notifInvitationAcceptedBody(String memberName) {
    return '$memberName ha aceptado la invitación';
  }

  @override
  String get notifInvitationDeclinedTitle => 'Invitación rechazada';

  @override
  String notifInvitationDeclinedBody(String memberName) {
    return '$memberName ha rechazado la invitación';
  }

  @override
  String get notifSupportRequestTitle => 'Solicitud de soporte';

  @override
  String get notifSupportRequestBody =>
      'Se ha enviado una nueva solicitud de soporte';

  @override
  String get notifSupportUpdatedTitle => 'Actualización de soporte';

  @override
  String get notifSupportUpdatedBody =>
      'Tu solicitud de soporte ha sido actualizada';

  @override
  String get notifTypeEventCreated => 'Nuevo evento';

  @override
  String get notifTypeEventUpdated => 'Evento actualizado';

  @override
  String get notifTypeEventCancelled => 'Evento cancelado';

  @override
  String get notifTypeEventStarting => 'Evento próximo';

  @override
  String get notifTypeEventStarted => 'Evento iniciado';

  @override
  String get notifTypeMemberRsvp => 'RSVP de miembro';

  @override
  String get notifTypeNewClubRequest => 'Nueva solicitud de club';

  @override
  String get notifTypeClubApproved => 'Club aprobado';

  @override
  String get notifTypeClubRejected => 'Club rechazado';

  @override
  String get notifTypeMemberInvited => 'Invitación al club';

  @override
  String get notifTypeInvitationAccepted => 'Invitación aceptada';

  @override
  String get notifTypeInvitationDeclined => 'Invitación rechazada';

  @override
  String get notifTypeSeatAvailable => 'Asiento disponible';

  @override
  String get notifTypeSupportRequest => 'Solicitud de soporte';

  @override
  String get notifTypeSupportUpdated => 'Actualización de soporte';

  @override
  String get invitationsScreenTitle => 'Invitaciones a clubes';

  @override
  String get invitationsScreenNoPending => 'Sin invitaciones pendientes';

  @override
  String get invitationsScreenYouWillSee =>
      'Aquí verás las invitaciones de clubes';

  @override
  String get invitationsScreenGoBack => 'Volver';

  @override
  String get invitationsScreenUnknownClub => 'Club desconocido';

  @override
  String invitationsScreenInvitedBy(String name) {
    return 'Invitado por $name';
  }

  @override
  String invitationsScreenExpires(String date) {
    return 'Expira $date';
  }

  @override
  String get invitationsScreenExpired => 'Expirado';

  @override
  String invitationsScreenExpiresInDays(int days) {
    return 'en $days día(s)';
  }

  @override
  String invitationsScreenExpiresInHours(int hours) {
    return 'en $hours hora(s)';
  }

  @override
  String get invitationsScreenExpiresSoon => 'pronto';

  @override
  String get invitationsScreenDecline => 'Rechazar';

  @override
  String get invitationsScreenAccept => 'Aceptar';

  @override
  String invitationsScreenJoinedAs(String clubName, String role) {
    return 'Te uniste a $clubName como $role';
  }

  @override
  String get profilePremium => 'Premium';

  @override
  String get profileFree => 'Gratis';

  @override
  String get dealerTableStartNewHand => 'Nueva mano';

  @override
  String get dealerTableStartSessionBtn => 'Iniciar sesión';

  @override
  String get dealerTableNeedTwoPlayers =>
      'Se necesitan al menos 2 jugadores para comenzar';

  @override
  String get dealerTableAddTestPlayers => 'Agregar jugadores de prueba';

  @override
  String dealerTableAddedTestPlayers(int count) {
    return 'Se agregaron $count jugadores de prueba';
  }

  @override
  String dealerTableRolledBack(String street) {
    return 'Retrocedido a $street';
  }

  @override
  String dealerTableUndoneAction(String playerName, String action) {
    return 'Deshecho: $playerName $action';
  }

  @override
  String get dealerTableScanToJoin => 'Escanea para ocupar este asiento';

  @override
  String get dealerTableOccupiedDot => 'Ocupado · ';

  @override
  String get dealerTableEmptyLabel => 'Vacío';

  @override
  String get dealerTableOccupiedLabel => 'Ocupado';

  @override
  String get dealerTableSelectedLabel => 'Seleccionado';

  @override
  String get dealerTableSelectSeatLabel => 'SELECCIONAR ASIENTO';

  @override
  String get dealerTableBetAmountDialog => 'Monto de Bet';

  @override
  String get dealerTableRaiseToDialog => 'Raise a';

  @override
  String get dealerTablePausedLabel => 'Pausado';

  @override
  String get dealerTableListeningLabel => 'Escuchando';

  @override
  String get dealerTableResumeVoiceTooltip => 'Reanudar voz';

  @override
  String get dealerTablePauseVoiceTooltip => 'Pausar voz';

  @override
  String get dealerTableVoiceOffLabel => 'Voz desactivada';

  @override
  String get dealerTableCalibratingLabel => 'Calibrando...';

  @override
  String get dealerTableCalibrationPrompt =>
      'Por favor diga: \"Mesa [número], Dealer [nombre]\"';

  @override
  String dealerTableDealerLockedMsg(String name, String table) {
    return 'Dealer fijado: $name en mesa $table';
  }

  @override
  String get dealerTableNoSpeakersMsg =>
      'No se detectó voz — hable con claridad';

  @override
  String get dealerTableSayTableDealerMsg =>
      'Por favor diga: \"Mesa [número], Dealer [nombre]\"';

  @override
  String get dealerTableConnectionLostRecovery =>
      'Conexión perdida — intentando recuperar...';

  @override
  String get dealerTableConnectionTimeout =>
      'Tiempo de conexión agotado — se requiere recalibración';

  @override
  String get dealerTableConnectionRecovered => '¡Conexión recuperada!';

  @override
  String get dealerTableActionHeldMsg => 'Acción retenida';

  @override
  String get dealerTableFailedStartStreaming =>
      'Error al iniciar el streaming — verifica la conexión al servidor y el micrófono';

  @override
  String dealerTableFailedStartVoice(String error) {
    return 'Error al iniciar la voz: $error';
  }

  @override
  String get dealerTableAddPlayerActionLabel => 'Agregar jugador';

  @override
  String get dealerTableSeatAnotherPlayer => 'Sentar a otro jugador aquí';

  @override
  String get dealerTableSitHereLabel => 'Sentarse aquí';

  @override
  String get dealerTableJoinAsDealerPlayer =>
      'Unirse al juego como Dealer-jugador';

  @override
  String get dealerTableDealerFallback => 'Dealer';

  @override
  String dealerTableUpdatedStackMsg(String name, String amount) {
    return 'Stack de $name actualizado a $amount';
  }

  @override
  String dealerTableFailedUpdateStackMsg(String error) {
    return 'Error al actualizar Stack: $error';
  }

  @override
  String dealerTableSittingAtSeatMsg(int number) {
    return 'Ahora juegas en el asiento $number';
  }

  @override
  String dealerTableFailedSitMsg(String error) {
    return 'Error al sentarse en la mesa: $error';
  }

  @override
  String dealerTableFailedAddPlayerMsg(String error) {
    return 'Error al agregar jugador: $error';
  }

  @override
  String dealerTableRemovedFromSeat(String name, int seat) {
    return '$name removido del asiento $seat';
  }

  @override
  String dealerTableFailedRemoveMsg(String error) {
    return 'Error al remover jugador: $error';
  }

  @override
  String get eventDetailDateAndTime => 'Fecha y hora';

  @override
  String eventDetailTableSeatInfo(String table, int seat) {
    return 'Mesa $table, Asiento #$seat';
  }

  @override
  String get eventDetailYoureSeatedGoodLuck => 'Estás sentado, ¡buena suerte!';

  @override
  String get eventDetailHomeGame => 'Juego en casa';

  @override
  String get clubDashboardDateLabel => 'Fecha';

  @override
  String get clubDashboardUnknownLabel => 'Desconocido';

  @override
  String get clubDashboardActiveLabel => 'Activo';

  @override
  String get clubDashboardIdleLabel => 'Inactivo';

  @override
  String clubDashboardInvitedTimeAgo(String time) {
    return 'Invitado $time';
  }

  @override
  String get clubDashboardPendingLabel => 'Pendiente';

  @override
  String get clubDashboardNoDealersYet => 'Sin Dealers aún';

  @override
  String get clubDashboardInviteDealersHint =>
      'Invita Dealers para ayudar a gestionar tus mesas';

  @override
  String get clubDashboardInviteDealer => 'Invitar Dealer';

  @override
  String get clubDashboardInviteDealerBody =>
      'Ingresa el email del Dealer que deseas invitar.';

  @override
  String get clubDashboardSendInvitationBtn => 'Enviar invitación';

  @override
  String clubDashboardInvitationSentTo(String email) {
    return 'Invitación enviada a $email';
  }

  @override
  String clubDashboardFailedSendInvitationMsg(String error) {
    return 'Error al enviar invitación: $error';
  }

  @override
  String get clubDashboardCancelInvitationTitle => '¿Cancelar invitación?';

  @override
  String clubDashboardCancelInvitationBody(String email) {
    return '¿Cancelar la invitación a $email?';
  }

  @override
  String get clubDashboardKeepBtn => 'Mantener';

  @override
  String get clubDashboardCancelInvitationBtn => 'Cancelar invitación';

  @override
  String clubDashboardFailedCancelMsg(String error) {
    return 'Error al cancelar invitación: $error';
  }

  @override
  String clubSettingsMembers(int count) {
    return 'Miembros ($count)';
  }

  @override
  String get clubSettingsNoMembersFound => 'No se encontraron miembros';

  @override
  String get clubSettingsRoleOwner => 'Propietario';

  @override
  String get clubSettingsRoleAdmin => 'Admin';

  @override
  String get clubSettingsRoleDealer => 'Dealer';

  @override
  String get clubSettingsRolePlayer => 'Jugador';

  @override
  String get clubSettingsTableAddedMsg => 'Mesa agregada';

  @override
  String get clubSettingsEditTableTitle => 'Editar mesa';

  @override
  String get clubSettingsDeleteTableTitle => '¿Eliminar mesa?';

  @override
  String clubSettingsDeleteTableBody(String name) {
    return '¿Estás seguro de que quieres eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get clubSettingsTableDeletedMsg => 'Mesa eliminada';

  @override
  String get clubSettingsDealerScanHint =>
      'Los Dealers escanean esto para iniciar una sesión en esta mesa';

  @override
  String get clubSettingsRegenerateBtn => 'Regenerar';

  @override
  String get clubSettingsAppQrCodes => 'Códigos QR de la app';

  @override
  String get clubSettingsShareWithPlayers =>
      'Comparte con los jugadores para descargar la app';

  @override
  String get clubSettingsDownloadPdf => 'Descargar PDF';

  @override
  String get clubSettingsDownloadFinalTable => 'Descarga la app Final Table';

  @override
  String get clubSettingsScanQrToGetStarted =>
      'Escanea el código QR de tu dispositivo para comenzar';

  @override
  String get clubSettingsScanToStartSession =>
      'Escanea este código QR para iniciar una sesión';

  @override
  String get clubSettingsForDealersOnly => 'Solo para Dealers';

  @override
  String clubSettingsTableDefault(int number) {
    return 'Mesa $number';
  }

  @override
  String eventManagementFailedUpdateEvent(String error) {
    return 'Error al actualizar evento: $error';
  }

  @override
  String adminTableThisWillMoveMsg(int count) {
    return 'Esto moverá a $count jugador(es) a la lista de espera y eliminará la mesa de este evento.';
  }

  @override
  String get adminTableThisWillRemoveMsg =>
      'Esto eliminará la mesa de este evento.';

  @override
  String adminTableClosedWithWaitlistMsg(String table, int count) {
    return '$table cerrada. $count jugador(es) movidos a la lista de espera.';
  }

  @override
  String adminTableClosedMsg(String table) {
    return '$table cerrada.';
  }

  @override
  String get adminTableEmptyLabel => 'Vacío';

  @override
  String get adminTableTableFallback => 'Mesa';

  @override
  String adminTableTableNumberLabel(int number) {
    return 'Mesa $number';
  }

  @override
  String homePendingInvitationsMsg(int count) {
    return 'Tienes $count invitación(es) pendiente(s) a clubes.';
  }

  @override
  String get homeEventFallback => 'Evento';

  @override
  String get homePokerFallback => 'Póker';

  @override
  String get homeUserFallback => 'Usuario';

  @override
  String homeSeatInfoStr(int seat, String chipStack) {
    return 'Asiento #$seat  •  $chipStack';
  }

  @override
  String get pokerHandYouLabel => 'Tú';

  @override
  String pokerHandMovingToTable(int table, String stack) {
    return 'Moviéndote a la mesa $table. Tu Stack ($stack) se transferirá. Los demás jugadores serán eliminados.';
  }

  @override
  String pokerHandActiveSessionMsg(int count) {
    return 'Tienes una sesión activa con $count mano(s) registrada(s). ¿Qué deseas hacer?';
  }

  @override
  String get pokerHandUnknownLabel => 'Desconocido';

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
      'Todos los jugadores All-In — repartiendo cartas restantes';

  @override
  String get pokerHandWaitingForCards =>
      'Esperando a que se repartan las cartas';

  @override
  String get pokerHandBettingComplete =>
      'Apuestas completadas — listo para la siguiente calle';

  @override
  String pokerHandSeatFallback(int id) {
    return 'Asiento $id';
  }

  @override
  String pokerHandPlayerFallback(int id) {
    return 'Jugador $id';
  }

  @override
  String get pokerHandChooseOption => 'Elige una opción:';

  @override
  String get pokerHandLeaveBtn => 'Salir';

  @override
  String get pokerHandConfirmBtn => 'Confirmar';

  @override
  String pokerHandCurrentlyHaveRemaining(String stack) {
    return 'Actualmente tienes $stack restantes.';
  }

  @override
  String get opponentsColorRed => 'Rojo';

  @override
  String get opponentsColorLightBlue => 'Azul claro';

  @override
  String get opponentsColorGreen => 'Verde';

  @override
  String get opponentsColorOrange => 'Naranja';

  @override
  String get opponentsColorPurple => 'Púrpura';

  @override
  String get opponentsColorTeal => 'Verde azulado';

  @override
  String get opponentsColorPink => 'Rosa';

  @override
  String get opponentsColorIndigo => 'Índigo';

  @override
  String opponentsFailedToLoad(String error) {
    return 'Error al cargar oponentes: $error';
  }

  @override
  String get opponentDetailFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get opponentDetailStealLabel => 'Steal';

  @override
  String get opponentDetailCheckRaiseLabel => 'Check/Raise';

  @override
  String get individualSetupSessionSetup => 'Configuración de sesión';

  @override
  String get individualSetupSessionNameLabel => 'Nombre de sesión';

  @override
  String get individualSetupGameTypeLabel => 'Tipo de juego';

  @override
  String get individualSetupCashGameLabel => 'Cash Game';

  @override
  String get individualSetupTournamentLabel => 'Tournament';

  @override
  String get individualSetupBuyInAmountLabel => 'Monto de Buy-in';

  @override
  String get individualSetupEnterAmountHint => 'Ingresa el monto';

  @override
  String get individualSetupCashGameNote =>
      'En Cash Game tu Stack inicial es igual al monto de Buy-in.';

  @override
  String get individualSetupStartingStackLabel => 'Stack inicial';

  @override
  String get individualSetupEnterChipStackHint => 'Ingresa Stack de fichas';

  @override
  String individualSetupStackValidation(int bigBlind) {
    return 'El Stack inicial debe ser al menos igual al Big Blind ($bigBlind)';
  }

  @override
  String get individualSetupStartSessionBtn => 'Iniciar sesión';

  @override
  String get individualSetupEnterValueHint => 'Ingresa el valor';

  @override
  String get individualHandSetupTitle => 'Mano individual';

  @override
  String get individualHandSetupSubtitle => 'Registro rápido de mano';

  @override
  String get individualHandSetupHandNameLabel => 'Nombre de la mano (opcional)';

  @override
  String get playerSessionBluff => 'Bluff';

  @override
  String get playerSessionValue => 'Value';

  @override
  String get playerSessionMistake => 'Error';

  @override
  String get playerSessionCooler => 'Cooler';

  @override
  String get playerSessionHeroCall => 'Hero Call';

  @override
  String get playerSessionExploit => 'Exploit';

  @override
  String get playerSessionToughSpot => 'Situación difícil';

  @override
  String get playerSessionEasyFold => 'Fold fácil';

  @override
  String get playerSessionEndedTitle => 'Sesión terminada';

  @override
  String get playerSessionEndedBody => 'El Dealer ha terminado esta sesión.';

  @override
  String get playerSessionRemovedTitle => 'Removido de la mesa';

  @override
  String get playerSessionRemovedBody =>
      'Has sido removido de la mesa por el Dealer.';

  @override
  String playerSessionYouWon(String amount) {
    return '¡Ganaste $amount!';
  }

  @override
  String playerSessionSeatWins(int seat, String amount) {
    return 'Asiento $seat gana $amount';
  }

  @override
  String get playerSessionYourHoleCardsTitle => 'Tus Hole Cards';

  @override
  String get playerSessionConnecting => 'Conectando...';

  @override
  String get playerSessionGoBackBtn => 'Volver';

  @override
  String get playerSessionHoleCardsLabel => 'Hole Cards';

  @override
  String get playerSessionEditBtn => 'Editar';

  @override
  String get playerSessionAddBtn => 'Agregar';

  @override
  String get playerSessionBoardLabel => 'Board';

  @override
  String get playerSessionNoCardsDealt => 'No se han repartido cartas';

  @override
  String get playerSessionWaitingForAction => 'Esperando acción...';

  @override
  String get playerSessionActionsLabel => 'Acciones';

  @override
  String get playerSessionYouLabel => 'Tú';

  @override
  String playerSessionSeatFallback(int seat) {
    return 'Asiento $seat';
  }

  @override
  String get playerSessionNotesHintText => 'Agrega notas sobre esta mano...';

  @override
  String get playerSessionHandHistoryLabel => 'Historial de manos';

  @override
  String get playerSessionNoCompletedHands => 'Sin manos completadas aún';

  @override
  String playerSessionWonAmount(String amount) {
    return 'Ganó $amount';
  }

  @override
  String get playerSessionLostLabel => 'Perdió';

  @override
  String get playerSessionDealerChangeTitle => 'Cambio de Dealer';

  @override
  String get playerSessionWaitingForDealer => 'Esperando al nuevo Dealer...';

  @override
  String playerSessionHandUpdated(int number) {
    return 'Mano #$number actualizada';
  }

  @override
  String playerSessionErrorSaving(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String playerSessionEditHand(int number) {
    return 'Editar mano #$number';
  }

  @override
  String get playerSessionViewDetails => 'Ver detalles';

  @override
  String get playerSessionTapToAddHoleCards => 'Toca para agregar Hole Cards';

  @override
  String get playerSessionSaveChanges => 'Guardar cambios';

  @override
  String get playerSessionLeaveTableTitle => '¿Dejar la mesa?';

  @override
  String get playerSessionLeaveTableBody =>
      '¿Estás seguro de que quieres dejar esta mesa?';

  @override
  String playerSessionFailedLeave(String error) {
    return 'Error al salir: $error';
  }

  @override
  String get playerSessionTableSession => 'Sesión de mesa';

  @override
  String playerSessionHandNumber(int number) {
    return 'Mano #$number';
  }

  @override
  String get playerSessionUnknownDealer => 'Desconocido';

  @override
  String get playerSessionNotAuthenticated => 'No autenticado';

  @override
  String get dealerQrScanSessionSettings => 'Configuración de sesión';

  @override
  String dealerQrScanTableNameLabel(String name) {
    return 'Mesa: $name';
  }

  @override
  String dealerQrScanEventNameLabel(String name) {
    return 'Evento: $name';
  }

  @override
  String get dealerQrScanBlindsLabel => 'Blinds';

  @override
  String get dealerQrScanSmallBlindLabel => 'Small Blind';

  @override
  String get dealerQrScanBigBlindLabel => 'Big Blind';

  @override
  String get dealerQrScanStartDealingBtn => 'Comenzar a repartir';

  @override
  String get dealerQrScanResumeSessionTitle => 'Reanudar sesión';

  @override
  String dealerQrScanTakingOverFrom(String name) {
    return 'Tomando el relevo de $name';
  }

  @override
  String get dealerQrScanHandsPlayedLabel => 'Manos jugadas';

  @override
  String get dealerQrScanBlindsInfoLabel => 'Blinds';

  @override
  String get dealerQrScanPlayersLabel => 'Jugadores';

  @override
  String get dealerQrScanResumeBtn => 'Reanudar';

  @override
  String get dealerQrScanTableNotAssigned => 'Mesa no asignada';

  @override
  String get dealerQrScanEventTablesLabel => 'Mesas del evento:';

  @override
  String get dealerQrScanNoTablesAssigned => 'Sin mesas asignadas';

  @override
  String get dealerQrScanThisTableId => 'ID de esta mesa:';

  @override
  String get dealerQrScanCorrectQrUrl => 'URL correcta del QR:';

  @override
  String get dealerQrScanScanTableQrTitle => 'Escanear QR de mesa';

  @override
  String get dealerQrScanScanInstructions =>
      'Escanea el código QR de la mesa para comenzar a repartir';

  @override
  String get eventDashboardTournamentOnBreak => 'Tournament en pausa';

  @override
  String get eventDashboardLiveLabel => 'En vivo';

  @override
  String get eventDashboardLocalLabel => 'Local';

  @override
  String get eventDashboardDisconnectedLabel => 'Desconectado';

  @override
  String get eventDashboardPlayersLabel => 'Jugadores';

  @override
  String get eventDashboardTablesLabel => 'Mesas';

  @override
  String get eventDashboardTotalChipsLabel => 'Fichas totales';

  @override
  String get eventDashboardAvgStackLabel => 'Stack promedio';

  @override
  String get eventDashboardChipLeaderLabel => 'Chip Leader';

  @override
  String get eventDashboardNoRankingsYet => 'Sin clasificaciones aún';

  @override
  String get eventDashboardRankingsWillAppear =>
      'Las clasificaciones aparecerán cuando los jugadores se unan a las mesas';

  @override
  String eventDashboardTableSeatLabel(String table, int seat) {
    return '$table - Asiento $seat';
  }

  @override
  String eventDashboardPlayerFallback(String id) {
    return 'Jugador $id';
  }

  @override
  String get commonNA => 'N/D';

  @override
  String sessionHistoryFailedLoad(String error) {
    return 'Error al cargar sesiones: $error';
  }

  @override
  String get sessionHistoryCash => 'Cash';

  @override
  String get sessionHistoryTournament => 'Tournament';

  @override
  String sessionHistorySessionId(String id) {
    return 'Sesión $id...';
  }

  @override
  String sessionHistorySeatWithPosition(String seat, String position) {
    return 'Asiento $seat ($position)';
  }

  @override
  String sessionHistorySeat(String seat) {
    return 'Asiento $seat';
  }

  @override
  String get sessionHistorySyncCompleted => 'Sincronización completada';

  @override
  String get sessionHistoryFullHistory => 'Historial completo de sesiones';

  @override
  String get sessionHandsRetry => 'Reintentar';

  @override
  String get stackChartScreenStart => 'Inicio';

  @override
  String get stackChartScreenRebuy => 'Rebuy';

  @override
  String get stackChartScreenEnd => 'Fin';

  @override
  String get quickStackSelectPlayer => 'Seleccionar jugador';

  @override
  String quickStackAddPlayer(String name) {
    return 'Agregar \"$name\"';
  }

  @override
  String get quickStackSaveToOpponents => 'Guardar en lista de oponentes';

  @override
  String get quickStackYou => 'Tú';

  @override
  String get quickStackNoPlayersFound => 'No se encontraron jugadores.';

  @override
  String get seatSetupDone => 'Listo';

  @override
  String get seatSetupCancel => 'Cancelar';

  @override
  String get authConnectionIssue => 'Problema de conexión';

  @override
  String get authConnectionIssueBody =>
      'No pudimos conectarnos a nuestros servidores.\nPor favor, verifica tu conexión a internet\ne inténtalo de nuevo.';

  @override
  String get authTryAgain => 'Intentar de nuevo';

  @override
  String get redeemInvitationTitle => 'Canjear invitación';

  @override
  String get redeemEnterCode => 'Ingresar código de invitación';

  @override
  String get redeemCodeDescription =>
      'Ingresa el código de 8 caracteres que recibiste de un admin del club para unirte a su club.';

  @override
  String get redeemJoinClub => 'Unirse al club';

  @override
  String get redeemWelcome => '¡Bienvenido!';

  @override
  String redeemJoinedAs(String clubName, String role) {
    return 'Te has unido a $clubName como $role';
  }

  @override
  String get redeemContinue => 'Continuar';

  @override
  String get supportBugReport => 'Reporte de error';

  @override
  String get supportFeatureRequest => 'Solicitud de función';

  @override
  String get supportAccountIssue => 'Problema de cuenta';

  @override
  String get supportOther => 'Otro';

  @override
  String get supportFillAllFields => 'Por favor, completa todos los campos';

  @override
  String get supportSubmitted => 'Solicitud de soporte enviada correctamente';

  @override
  String supportFailedSubmit(String error) {
    return 'Error al enviar: $error';
  }

  @override
  String get supportTitle => 'Ayuda y soporte';

  @override
  String get supportSubmitButton => 'Enviar';

  @override
  String get supportCategoryLabel => 'CATEGORÍA';

  @override
  String get supportSubjectLabel => 'ASUNTO';

  @override
  String get supportDescriptionLabel => 'DESCRIPCIÓN';

  @override
  String get supportSubjectHint => 'Breve resumen del problema';

  @override
  String get supportDescriptionHint => 'Describe el problema en detalle...';

  @override
  String get calendarEventLocation => 'Ubicación';

  @override
  String get calendarEventBuyIn => 'Monto del buy-in';

  @override
  String get calendarEventEdit => 'Editar';

  @override
  String get calendarEventDelete => 'Eliminar evento';

  @override
  String calendarEventDeleteConfirm(String title) {
    return '¿Eliminar $title?';
  }

  @override
  String calendarEventDeleteBody(String title) {
    return '¿Estás seguro de que deseas eliminar \"$title\"?\nEsta acción no se puede deshacer.';
  }

  @override
  String get calendarEventDeleteButton => 'Eliminar';

  @override
  String get clubInfoTitle => 'Info del club';

  @override
  String clubInfoMembersCount(int count) {
    return 'Miembros ($count)';
  }

  @override
  String get clubInfoNoMembers => 'No se encontraron miembros';

  @override
  String get finalStandingsNoData => 'No hay resultados disponibles';

  @override
  String get finalStandingsNoDataHint =>
      'Es posible que este evento no haya registrado resultados';

  @override
  String get finalStandingsEmpty => 'No hay resultados registrados';

  @override
  String get finalStandingsTitle => 'Resultados finales';

  @override
  String get finalStandingsPlayers => 'Jugadores';

  @override
  String get finalStandingsCompleted => 'Completado';

  @override
  String get liveRankingsTitle => 'Live Rankings';

  @override
  String get liveRankingsEliminated => 'Jugadores eliminados';

  @override
  String get liveRankingsWaiting => 'Esperando jugadores';

  @override
  String get liveRankingsWaitingHint =>
      'El ranking aparecerá una vez que los jugadores tomen asiento';

  @override
  String get liveRankingsError => 'Error al cargar el ranking';

  @override
  String get liveRankingsTryAgain => 'Intentar de nuevo';

  @override
  String get leaderboardPlayers => 'Jugadores';

  @override
  String get leaderboardTotalChips => 'Fichas totales';

  @override
  String get leaderboardWaiting => 'Esperando jugadores...';

  @override
  String leaderboardChipLeader(String name) {
    return 'Líder de fichas: $name';
  }

  @override
  String get dealerQrScanBbAnte => 'BB Ante';

  @override
  String mainDealerOnClub(String clubName) {
    return 'Ahora eres dealer en $clubName';
  }

  @override
  String get raiseSnapMin => 'Mín';

  @override
  String get raiseSnapPot => 'Pot';

  @override
  String get raiseSnapAllIn => 'All-In';

  @override
  String sessionHistoryPlayerWins(int playerId) {
    return 'El jugador $playerId gana:';
  }

  @override
  String get inviteClubAdminFallback => 'Admin del club';

  @override
  String pokerHandBetRange(String min, String max) {
    return 'Mín: $min · Máx: $max';
  }

  @override
  String pokerHandAmountBetween(String min, String max) {
    return 'El monto debe estar entre $min y $max';
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
    return '$playerName debe actuar ($stack)';
  }

  @override
  String get eventDashboardOnBreakBadge => 'EN DESCANSO';

  @override
  String get eventDetailAdminActions => 'ACCIONES DE ADMIN';

  @override
  String get playerSessionHandNotesLabel => 'NOTAS DE MANO';

  @override
  String get playerSessionTagsLabel => 'ETIQUETAS';

  @override
  String get playerSessionNotesLabel => 'NOTAS';

  @override
  String get playerSessionHoleCardsUpperLabel => 'HOLE CARDS';

  @override
  String get qrJoinDeclined => 'Tu solicitud de ingreso fue rechazada';

  @override
  String qrJoinFailed(String error) {
    return 'Error al unirse al asiento: $error';
  }

  @override
  String get qrJoinTable => 'Unirse a la mesa';

  @override
  String get qrJoinLoading => 'Cargando información de la mesa...';

  @override
  String get qrJoinError => 'Algo salió mal';

  @override
  String get qrJoinGoBack => 'Volver';

  @override
  String get qrJoinSeatOccupied =>
      'Este asiento puede estar ya ocupado. Unirte reemplazará al jugador actual.';

  @override
  String get qrJoinWaitingDealer => 'Esperando al dealer';

  @override
  String qrJoinRequestSent(int seatNumber) {
    return 'Tu solicitud para unirte al Asiento $seatNumber ha sido enviada.';
  }

  @override
  String get qrJoinDealerApproval =>
      'El dealer establecerá tu stack de fichas y aprobará tu ingreso.';

  @override
  String get qrJoinCancelRequest => 'Cancelar solicitud';

  @override
  String get qrJoinRequestButton => 'Solicitar unirse';

  @override
  String get onboardingSkipTour => 'Omitir tour';

  @override
  String get onboardingWelcomeTitle => 'Bienvenido a\nFinal Table';

  @override
  String get onboardingWelcomeBody =>
      'Hagamos un recorrido rápido para que puedas comenzar.\n\nSiempre puedes repetir este tour desde\nPerfil → Ajustes → Base de conocimiento.';

  @override
  String get onboardingLetsGo => '¡Vamos!';

  @override
  String get onboardingGotIt => 'Entendido';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingStartLoggingTitle => 'Comenzar a registrar';

  @override
  String get onboardingStartLoggingBody =>
      'Toca el botón + para comenzar a registrar una mano.';

  @override
  String get onboardingFullModeTitle => 'Modo de registro completo';

  @override
  String get onboardingFullModeBody =>
      'Rastrea cada acción de cada jugador en todas las calles. Perfecto para un análisis serio.';

  @override
  String get onboardingIndividualModeTitle => 'Modo de registro individual';

  @override
  String get onboardingIndividualModeBody =>
      'Seguimiento rápido de ganancias/pérdidas para una sola sesión. ¡Elige un modo para continuar!';

  @override
  String get onboardingSessionSetupTitle => 'Configuración de sesión';

  @override
  String get onboardingSessionSetupBody =>
      'Aquí puedes configurar el nombre de sesión, tipo de juego, ciegas, buy-in y stack inicial.';

  @override
  String get onboardingTableSetupTitle => 'Configurar tu mesa';

  @override
  String get onboardingTableSetupBody =>
      'Ahora, completa los detalles de la sesión y configura la mesa. Toca un asiento para ubicarte a ti y a tus oponentes, y arrastra el botón del dealer (D) para establecer la posición del botón. Toca el icono ✓ en la esquina superior derecha cuando estés listo.';

  @override
  String get onboardingSeatOpenTitle => 'Asiento libre';

  @override
  String get onboardingSeatOpenBody =>
      'Alterna para marcar un asiento como ocupado o vacío. Los asientos abiertos se omiten durante la mano.';

  @override
  String get onboardingThisIsMySeatTitle => 'Este es mi asiento';

  @override
  String get onboardingThisIsMySeatBody =>
      'Toca aquí si este es tu asiento. Rellena tu nombre automáticamente y rastrea tus estadísticas personales.';

  @override
  String get onboardingPlayerNameTitle => 'Nombre del jugador';

  @override
  String get onboardingPlayerNameBody =>
      'Escribe un nombre o elige de tus oponentes guardados. Los oponentes guardados rastrean estadísticas entre sesiones.';

  @override
  String get onboardingSaveOpponentTitle => 'Guardar oponente';

  @override
  String get onboardingSaveOpponentBody =>
      '¿Nombre nuevo? Toca aquí para guardarlo como oponente. Sus estadísticas se rastrearán automáticamente.';

  @override
  String get onboardingDealerButtonTitle => 'Botón de dealer';

  @override
  String get onboardingDealerButtonBody =>
      'Arrástralo al asiento con la posición de dealer. Determina las ciegas y el orden de acción.';

  @override
  String get onboardingViewSessionsTitle => 'Ver tus sesiones';

  @override
  String get onboardingViewSessionsBody =>
      'Toca Sesiones para ver los resultados de tu sesión, historial de manos y estadísticas.';

  @override
  String get onboardingAllSetTitle => '¡Todo listo!';

  @override
  String get onboardingAllSetBody =>
      'Estás listo para comenzar a rastrear tus sesiones de póker.';

  @override
  String get onboardingLetsPlay => 'A jugar';

  @override
  String get onboardingUpdateStackTitle => 'Actualizar stack';

  @override
  String get onboardingUpdateStackBody =>
      'Úsalo para actualizar manualmente tu conteo de fichas en cualquier momento sin registrar una mano completa.';

  @override
  String get onboardingLogAHandTitle => 'Registrar una mano';

  @override
  String get onboardingLogAHandBody =>
      'Toca aquí para configurar la mesa y registrar una mano. ¡Intentémoslo ahora!';

  @override
  String get onboardingMarkSeatOpenTitle => 'Marcar asiento como libre';

  @override
  String get onboardingMarkSeatOpenBody =>
      'Toca la marca de verificación para alternar un asiento entre ocupado y vacío. Los asientos vacíos se omiten en la mano.';

  @override
  String get onboardingDealerButtonQsuTitle => 'Botón de dealer';

  @override
  String get onboardingDealerButtonQsuBody =>
      'Toca \"D\" para asignar el botón de dealer a cualquier asiento. Esto controla las posiciones de las ciegas y el orden de acción.';

  @override
  String get onboardingAssignPlayerTitle => 'Asignar un jugador';

  @override
  String get onboardingAssignPlayerBody =>
      'Toca el nombre de un jugador para sentarte a ti mismo o a un oponente guardado. Tu stack se aplica automáticamente cuando te sientas.';

  @override
  String get onboardingAdjustStackTitle => 'Ajustar stack';

  @override
  String get onboardingAdjustStackBody =>
      'Arrastra el control deslizante para establecer el stack de un oponente en BBs. Toca el valor del stack para escribir una cantidad exacta.';

  @override
  String get onboardingEndSessionTitle => 'Terminar tu sesión';

  @override
  String get onboardingEndSessionBody =>
      'Toca el botón rojo de parada para guardar los resultados de tu sesión y volver a la pantalla de inicio.';

  @override
  String onboardingStepOf(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get guidedGestureGuideTitle => 'Guía de gestos';

  @override
  String get guidedGestureGuideBody =>
      'Toca este icono en cualquier momento para ver todos los controles de gestos.';

  @override
  String get guidedSkipButtonTitle => 'Botón omitir';

  @override
  String get guidedSkipButtonBody =>
      'Si omites una mano, este botón mueve el botón de dealer al siguiente jugador. Ten en cuenta que los stacks quedarán desincronizados — puedes actualizarlos en Gestionar jugadores.';

  @override
  String get guidedGameMenuTitle => 'Menú del juego';

  @override
  String get guidedGameMenuBody =>
      'Este menú tiene opciones útiles. Veamos una configuración importante.';

  @override
  String get guidedGameSettingsTitle => 'Configuración del juego';

  @override
  String get guidedGameSettingsBody =>
      'Aquí puedes cambiar las ciegas a mitad de sesión, útil en torneos cuando suben los niveles.';

  @override
  String get guidedEndSessionTitle => 'Terminar tu sesión';

  @override
  String get guidedEndSessionBody =>
      'Toca este menú y selecciona \"Terminar sesión\" para guardar tus resultados.';

  @override
  String get guidedReviewHandTitle => 'Revisar mano';

  @override
  String get guidedReviewHandBody => 'Ingresa tus hole cards y cualquier nota.';

  @override
  String get guidedHandCompleteTitle => '¡Mano completada!';

  @override
  String get guidedHandCompleteBody =>
      '¡Bien hecho! Acabas de registrar tu primera mano.';

  @override
  String get guidedSkip => 'Omitir';

  @override
  String get guidedYourTurn => '¡Tu turno!';

  @override
  String get guidedOpenThePotTitle => 'Abrir el pot';

  @override
  String get guidedBetOnceBody => 'Este jugador apuesta.';

  @override
  String get guidedFoldTitle => 'Fold';

  @override
  String get guidedFoldBody => 'Este jugador hace Fold.';

  @override
  String get guidedCallTitle => 'Call';

  @override
  String get guidedCallBody => 'Este jugador hace Call.';

  @override
  String get guidedCheckTitle => 'Check';

  @override
  String get guidedCheckBody => 'Este jugador hace Check.';

  @override
  String get guidedGestureFold => 'Deslizar izquierda ←';

  @override
  String get guidedGestureCheck => 'Tocar';

  @override
  String get guidedGestureCall => 'Tocar';

  @override
  String get guidedGestureBet => 'Deslizar arriba ↑';

  @override
  String get guidedGestureRaise => 'Deslizar arriba ↑';

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
  String get guidedDealFlopTitle => 'Repartir el Flop';

  @override
  String get guidedDealFlopBody =>
      'Arrastra un rango hacia un palo para seleccionar una carta. Toca una carta seleccionada para eliminarla. Elige 3 cartas para el flop.';

  @override
  String get guidedDealTurnTitle => 'Repartir el Turn';

  @override
  String get guidedDealTurnBody => 'Selecciona 1 carta para el Turn.';

  @override
  String get guidedDealRiverTitle => 'Repartir el River';

  @override
  String get guidedDealRiverBody => 'Selecciona 1 carta para el River.';

  @override
  String get guidedStackRingTitle => 'Rango de Stack';

  @override
  String get guidedStackRingBody =>
      'Mantén pulsado el anillo, gira el dedo para seleccionar un rango de stack y suelta. Esto te ayuda a configurar los stacks de tus oponentes antes del flop.';

  @override
  String get guidedTableButtonTitle => 'Gestionar Mesa';

  @override
  String get guidedTableButtonBody =>
      'Toca este botón para gestionar jugadores, actualizar stacks, cambiar asientos o mover el botón del dealer.';

  @override
  String get guidedBlindsPillTitle => 'Blinds';

  @override
  String get guidedBlindsPillBody =>
      'Toca aquí para actualizar los niveles de blinds en cualquier momento — útil cuando suben los niveles del torneo.';

  @override
  String get guidedNextHandTitle => 'Siguiente Mano';

  @override
  String get guidedNextHandBody =>
      'Toca esto para saltar a la siguiente mano. Mueve el botón del dealer, rastrea tu stack automáticamente y deduce los blinds.';

  @override
  String get guidedInfoButtonTitle => 'Guía de Gestos';

  @override
  String get guidedInfoButtonBody =>
      'Toca este botón en cualquier momento para ver todos los controles gestuales disponibles para registrar acciones.';

  @override
  String get guidedSessionInfoTitle => 'Detalles de Sesión';

  @override
  String get guidedSessionInfoBody =>
      'Toca este botón para ver los detalles de tu sesión, gráfico de stack e historial de manos. ¡Tócalo ahora!';

  @override
  String get guidedAddOnTitle => 'Add-Ons y Rebuys';

  @override
  String get guidedAddOnBody => 'Gestiona tus add-ons y rebuys aquí.';

  @override
  String get guidedUpdateStackTitle => 'Actualizar Stack';

  @override
  String get guidedUpdateStackBody =>
      'Actualiza tu stack manualmente y toma notas rápidas. Aparecerán en tu gráfico de stack.';

  @override
  String get guidedStackChartTitle => 'Gráfico de Stack';

  @override
  String get guidedStackChartBody =>
      'Toca cualquier punto para ver cómo va tu partida.';

  @override
  String get guidedStopSessionTitle => 'Detener Sesión';

  @override
  String get guidedStopSessionBody =>
      'Termina tu sesión en cualquier momento cuando hayas acabado.';

  @override
  String get guidedTourCompleteTitle => '¡Tour completado!';

  @override
  String get guidedTourCompleteBody =>
      '¡Todo listo! Puedes encontrar los datos de tu sesión en la pestaña Sesiones en cualquier momento.';

  @override
  String get kbStatsTitle => 'Tus estadísticas';

  @override
  String get kbClubsTitle => 'Clubs y eventos';

  @override
  String get kbStatsIntro =>
      'Final Table rastrea 7 métricas clave de póker para ayudarte a entender y mejorar tu juego.';

  @override
  String get kbClubsIntro =>
      'Los clubs te permiten conectarte con tu sala de póker local y hacer seguimiento de partidas en vivo.';

  @override
  String get kbVpipName => 'VPIP';

  @override
  String get kbVpipFullName => 'Voluntarily Put \$ In Pot';

  @override
  String get kbVpipDescription =>
      'Con qué frecuencia entras voluntariamente en un pot (excluyendo posts de ciega). Un VPIP alto significa que juegas muchas manos; un VPIP bajo significa que eres selectivo.';

  @override
  String get kbPfrName => 'PFR';

  @override
  String get kbPfrFullName => 'Preflop Raise';

  @override
  String get kbPfrDescription =>
      'Con qué frecuencia subes antes del Flop. La diferencia entre VPIP y PFR muestra con qué frecuencia limpeas o haces cold-call.';

  @override
  String get kbThreeBetName => '3-Bet';

  @override
  String get kbThreeBetFullName => 'Three-Bet Percentage';

  @override
  String get kbThreeBetDescription =>
      'Con qué frecuencia re-subes el open raise de un oponente antes del Flop. Un 3-Bet% mayor indica un estilo preflop agresivo.';

  @override
  String get kbFoldTo3BetName => 'Fold to 3-Bet';

  @override
  String get kbFoldTo3BetFullName => 'Fold to Three-Bet';

  @override
  String get kbFoldTo3BetDescription =>
      'Con qué frecuencia foldeas después de subir y enfrentar un 3-Bet. Si es muy alto, los oponentes pueden explotarte con 3-Bets ligeros.';

  @override
  String get kbCBetName => 'C-Bet';

  @override
  String get kbCBetFullName => 'Continuation Bet';

  @override
  String get kbCBetDescription =>
      'Con qué frecuencia apuestas en el Flop después de ser el último agresor preflop. Una jugada estándar que muestra fuerza.';

  @override
  String get kbStealName => 'Steal';

  @override
  String get kbStealFullName => 'Blind Steal Attempt';

  @override
  String get kbStealDescription =>
      'Con qué frecuencia abres con raise desde posición tardía (CO, BTN, SB) cuando el pot está sin abrir, intentando robar las ciegas.';

  @override
  String get kbCheckRaiseName => 'Check-Raise';

  @override
  String get kbCheckRaiseFullName => 'Flop Check-Raise';

  @override
  String get kbCheckRaiseDescription =>
      'Con qué frecuencia haces Check y luego subes en el Flop. Un movimiento engañoso que puede atrapar a oponentes agresivos.';

  @override
  String get kbLiveEventsTitle => 'Eventos en vivo';

  @override
  String get kbLiveEventsDescription =>
      'Los managers de clubs crean eventos con múltiples mesas. Únete a un evento para ser parte del ranking en vivo.';

  @override
  String get kbLiveRankingsTitle => 'Live Rankings';

  @override
  String get kbLiveRankingsDescription =>
      'Ve dónde estás en tiempo real durante los eventos. Los rankings se actualizan después de cada mano.';

  @override
  String get kbOpponentTrackingTitle => 'Seguimiento de oponentes';

  @override
  String get kbOpponentTrackingDescription =>
      'Los jugadores a los que te enfrentas en el club se rastrean automáticamente. Guarda oponentes para crear perfiles detallados.';

  @override
  String get kbQrSeatTitle => 'Asignación de asiento por QR';

  @override
  String get kbQrSeatDescription =>
      'Escanea un código QR en tu mesa para unirte a la sesión al instante. El dealer registra tus manos automáticamente.';

  @override
  String get kbDealerLoggingTitle => 'Registro asistido por dealer';

  @override
  String get kbDealerLoggingDescription =>
      'Los dealers usan comandos de voz para registrar acciones de toda la mesa. No se necesita entrada manual de los jugadores.';

  @override
  String get kbSessionStatsTitle => 'Estadísticas de sesión';

  @override
  String get kbSessionStatsDescription =>
      'Después de cada sesión, ve tu ganancia/pérdida y cómo cambiaron tus estadísticas. Cada mano queda registrada.';

  @override
  String get qrJoinTableInfo => 'INFO DE MESA';

  @override
  String qrJoinSeat(int number) {
    return 'Asiento $number';
  }

  @override
  String get qrJoinTableFallback => 'Mesa';

  @override
  String get qrJoinClubLabel => 'Club';

  @override
  String get qrJoinTableLabel => 'Mesa';

  @override
  String get qrJoinSeatLabel => 'Asiento';

  @override
  String get qrJoinStatusLabel => 'Estado';

  @override
  String get qrJoinActiveGame => 'Partida activa';

  @override
  String get qrJoinWaitingStatus => 'Esperando';

  @override
  String dealerQrTablesAssigned(int count) {
    return '$count mesa(s) asignada(s) a este evento';
  }

  @override
  String dealerQrTableNotAssigned(String tableName) {
    return '$tableName no está asignado a este evento.';
  }

  @override
  String dealerTablePlayerAdded(String playerName, int seatNumber) {
    return '$playerName agregado al Asiento $seatNumber';
  }

  @override
  String memberTableSeatedOpen(int seated, int open) {
    return '$seated ocupados  •  $open libres';
  }

  @override
  String get memberTablePlayer => 'Jugador';

  @override
  String get memberTableEmpty => 'Vacío';

  @override
  String get memberTableFallback => 'Mesa';

  @override
  String get homeEventTypeTournament => 'Torneo';

  @override
  String get homeEventTypeCashGame => 'Cash Game';

  @override
  String get homeEventTypeHomeGame => 'Partida en casa';

  @override
  String get homeEventTypeOnline => 'En línea';

  @override
  String get bankrollSheetTitle => 'Agregar resultado';

  @override
  String get bankrollSheetEditSection => 'Editar bankroll';

  @override
  String get bankrollSheetGoalLabel => 'Meta de bankroll';

  @override
  String get bankrollSheetCurrentLabel => 'Bankroll actual';

  @override
  String get bankrollSheetGoalUpdated => 'Meta actualizada';

  @override
  String get bankrollSheetBankrollUpdated => 'Bankroll actualizado';

  @override
  String get sessionEndResultTitle => 'Resultado de sesión';

  @override
  String get sessionEndTournamentTitle => 'Resultado del torneo';

  @override
  String get sessionEndProfit => 'Ganancia';

  @override
  String get sessionEndLoss => 'Pérdida';

  @override
  String get sessionEndApply => 'Aplicar';

  @override
  String get sessionEndSkip => 'Omitir';

  @override
  String get sessionEndFinishingPosition => 'Posición final';

  @override
  String get sessionEndFieldSize => 'Total de participantes';

  @override
  String get sessionEndPrizeWon => 'Premio ganado';

  @override
  String get sessionEndTotalInvested => 'Total invertido';

  @override
  String sessionEndCalculatedProfit(String amount) {
    return 'Ganancia calculada: $amount';
  }

  @override
  String get onboardingWelcomeSubtitle =>
      'Tu compañero personal de póker para registrar manos, seguir estadísticas y mejorar tu juego.';

  @override
  String get onboardingNicknameTitle => 'Comencemos eligiendo tu apodo';

  @override
  String get onboardingNicknameSubtitle =>
      'Puedes cambiar entre tu nombre y apodo, y modificarlo cuando quieras.';

  @override
  String get onboardingGameTypeTitle => 'Elige tu tipo de juego';

  @override
  String get onboardingGameTypeSubtitle =>
      'Adaptaremos tu experiencia según lo que juegues. Cuéntanos, ¿juegas principalmente cash o MTT?';

  @override
  String get onboardingGameTypeCash => 'Cash Game';

  @override
  String get onboardingGameTypeTournament => 'Tournament (MTT)';

  @override
  String get onboardingJourneyTitle =>
      '¿En qué punto de tu camino en el póker estás?';

  @override
  String get onboardingJourneySubtitle =>
      'Esto nos ayuda a personalizar tu experiencia.';

  @override
  String get onboardingJourneyBeginner => 'Principiante';

  @override
  String get onboardingJourneyFun => 'Juego por diversión';

  @override
  String get onboardingJourneyRegular => 'Jugador habitual';

  @override
  String get onboardingJourneyPro => 'Profesional';

  @override
  String get onboardingMonthlySessionsTitle =>
      '¿Cuántas sesiones aproximadamente juegas por mes?';

  @override
  String get onboardingMonthlySessionsSubtitle =>
      'Arrastra la rueda para seleccionar tus sesiones mensuales.';

  @override
  String get onboardingMonthlySessionsUnit => 'sesiones / mes';

  @override
  String get onboardingPurposeTitle =>
      '¿Cuál es tu objetivo principal al usar Final Table?';

  @override
  String get onboardingPurposeSubtitle => 'Selecciona todas las que apliquen.';

  @override
  String get onboardingPurposeLogging => 'Registrar manos';

  @override
  String get onboardingPurposeBankroll => 'Seguir el bankroll';

  @override
  String get onboardingPurposeOpponents => 'Analizar oponentes';

  @override
  String get onboardingPurposeActions =>
      'Registrar cada acción para análisis posterior';

  @override
  String get onboardingPurposeStudying => 'Estudiar spots';

  @override
  String get onboardingPurposeSharing =>
      'Compartir historiales de manos con amigos';

  @override
  String get onboardingPurposeAi => 'Analizar con AI';

  @override
  String get onboardingPurposeExport => 'Exportar manos a herramientas GTO';

  @override
  String get onboardingPurposeStacks => 'Seguir tamaños de stack en torneos';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingGetStarted => 'Comenzar';

  @override
  String get onboardingSkipNickname => 'Omitir por ahora';
}
