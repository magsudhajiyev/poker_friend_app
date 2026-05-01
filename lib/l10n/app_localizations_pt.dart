// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get navHome => 'Inicio';

  @override
  String get navOpponents => 'Oponentes';

  @override
  String get navSessions => 'Sessoes';

  @override
  String get navProfile => 'Perfil';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonError => 'Erro';

  @override
  String get commonLoading => 'Carregando...';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonDone => 'Concluido';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Sim';

  @override
  String get commonNo => 'Nao';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonNoData => 'Nenhum dado disponivel';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonNotAvailable => 'N/D';

  @override
  String get commonApply => 'Aplicar';

  @override
  String get commonUpdate => 'Atualizar';

  @override
  String get commonClear => 'Limpar';

  @override
  String get commonToday => 'Hoje';

  @override
  String get statsTitle => 'Estatisticas';

  @override
  String get statsSubtitle => 'Analise Avancada';

  @override
  String get statsHandsPlayed => 'Maos Jogadas';

  @override
  String get statsFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get statsWinRate => 'Win Rate';

  @override
  String get statsSessionStatistics => 'Estatisticas de Sessao';

  @override
  String get statsSessions => 'Sessoes';

  @override
  String get statsTotalTime => 'Tempo Total';

  @override
  String get statsAvgSession => 'Media por Sessao';

  @override
  String get statsPlayToSee => 'Jogue sessoes para ver estatisticas de tempo';

  @override
  String get statsLoadingMessage => 'Carregando estatisticas...';

  @override
  String get statsFetchingMessage => 'Buscando estatisticas do usuario...';

  @override
  String statsFailedToLoad(String error) {
    return 'Falha ao carregar estatisticas: $error';
  }

  @override
  String get settingsTitle => 'Configuracoes';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSubtitle => 'Escolha o idioma do app';

  @override
  String get settingsLanguageSystem => 'Padrao do Sistema';

  @override
  String get settingsKnowledgeBase => 'BASE DE CONHECIMENTO';

  @override
  String get settingsGuidedTour => 'Tour Guiado';

  @override
  String get settingsGuidedTourSubtitle => 'Repetir tours de introducao';

  @override
  String get settingsFullLoggingTour => 'Tour de Registro Completo';

  @override
  String get settingsFullLoggingTourSubtitle =>
      'Fluxo completo de rastreamento de sessao';

  @override
  String get settingsIndividualLoggingTour => 'Tour de Registro Individual';

  @override
  String get settingsIndividualLoggingTourSubtitle =>
      'Fluxo de rastreamento de mao individual';

  @override
  String get settingsUnderstandingStats => 'Entendendo Suas Estatisticas';

  @override
  String get settingsUnderstandingStatsSubtitle =>
      'Aprenda o que cada metrica significa';

  @override
  String get settingsClubsEvents => 'Clubes e Eventos';

  @override
  String get settingsClubsEventsSubtitle => 'Como funciona o jogo em clube';

  @override
  String get settingsAdmin => 'ADMIN';

  @override
  String get settingsClubRequests => 'Solicitacoes de Clube';

  @override
  String get settingsClubRequestsSubtitle =>
      'Gerenciar solicitacoes de registro';

  @override
  String get settingsSupportRequests => 'Solicitacoes de Suporte';

  @override
  String get settingsSupportRequestsSubtitle => 'Gerenciar tickets de suporte';

  @override
  String get settingsNotificationTester => 'Testador de Notificacoes';

  @override
  String get settingsNotificationTesterSubtitle =>
      'Visualizar todos os designs de notificacao';

  @override
  String get profileUpgrade => 'Upgrade';

  @override
  String get profileUsername => 'Nome de usuario';

  @override
  String get profileNotSet => 'Nao definido';

  @override
  String get profileChange => 'Alterar';

  @override
  String get profileSetUsername => 'Definir nome de usuario';

  @override
  String get profileUseNicknameInGames => 'Usar apelido nos jogos';

  @override
  String profileUseNicknameDescription(String username) {
    return 'Mostrar @$username em vez do seu nome em eventos e registro de maos';
  }

  @override
  String get profileBankrollGoal => 'Meta de Bankroll';

  @override
  String get profileUpdateGoal => 'Atualizar Meta';

  @override
  String get profileCurrentBankroll => 'Bankroll Atual';

  @override
  String get profileUpdateBankroll => 'Atualizar Bankroll';

  @override
  String get profileAddSessionResult => 'Adicionar Resultado da Sessao';

  @override
  String get profileSessionResultHint =>
      'Insira positivo para ganhos, negativo para perdas';

  @override
  String get profileAddResult => 'Adicionar Resultado';

  @override
  String get profileGoalUpdatedSuccess => 'Meta atualizada com sucesso!';

  @override
  String get profileErrorUpdatingGoal => 'Erro ao atualizar meta';

  @override
  String get profileBankrollUpdatedSuccess =>
      'Bankroll atualizado com sucesso!';

  @override
  String get profileErrorUpdatingBankroll => 'Erro ao atualizar bankroll';

  @override
  String get profileSessionResultAdded => 'Resultado da sessao adicionado!';

  @override
  String get profileErrorAddingResult =>
      'Erro ao adicionar resultado da sessao';

  @override
  String get profilePleaseEnterValidAmount =>
      'Por favor, insira um valor valido';

  @override
  String get profileLogOut => 'Sair';

  @override
  String get profileSignOut => 'Sair';

  @override
  String get profileSignOutConfirmation => 'Tem certeza de que deseja sair?';

  @override
  String get sessionHistoryTitle => 'Historico de Sessoes';

  @override
  String get sessionLast30Days => 'Ultimos 30 dias';

  @override
  String get sessionUpgradeForFullHistory =>
      'Faca upgrade para historico completo';

  @override
  String get sessionLoadingMessage => 'Carregando sessoes...';

  @override
  String sessionNoSessions(String gameType) {
    return 'Nenhuma Sessao de $gameType';
  }

  @override
  String sessionPlayToSee(String gameType) {
    return 'Jogue algumas maos de Poker $gameType\npara ver os resultados';
  }

  @override
  String get sessionLive => 'Ao Vivo';

  @override
  String sessionPlayersCount(int count) {
    return '$count Jogadores';
  }

  @override
  String get sessionSyncingToCloud => 'Sincronizando com a nuvem...';

  @override
  String get sessionClearAllTitle => 'Limpar Todas as Sessoes?';

  @override
  String get sessionClearAllDescription =>
      'Isso excluira permanentemente todas as sessoes e maos de poker do Firebase e do armazenamento local.';

  @override
  String get sessionClearAllWarning => 'Esta acao nao pode ser desfeita!';

  @override
  String get sessionClearAll => 'Limpar Tudo';

  @override
  String get sessionClearedSuccessfully =>
      'Todas as sessoes foram limpas com sucesso';

  @override
  String sessionHandDetails(int handNumber) {
    return 'Detalhes da Mao #$handNumber';
  }

  @override
  String get sessionYourCards => 'Suas Cartas:';

  @override
  String get sessionBoardCards => 'Cartas da Mesa:';

  @override
  String get sessionPotByStreet => 'Pot por Street:';

  @override
  String get sessionActions => 'Acoes:';

  @override
  String get sessionNoActionsRecorded => 'Nenhuma acao registrada';

  @override
  String get sessionNoCardsRecorded => 'Nenhuma carta registrada';

  @override
  String get sessionFinalPot => 'Pot Final:';

  @override
  String sessionChoppedPot(int count) {
    return 'Pot Dividido ($count vencedores):';
  }

  @override
  String get sessionWinnerNotAvailable =>
      'Informacao do vencedor nao disponivel';

  @override
  String get opponentsTitle => 'Oponentes';

  @override
  String opponentsCountFree(int count, int max) {
    return '$count/$max gratis';
  }

  @override
  String opponentsCountPremium(int count) {
    return '$count jogadores rastreados';
  }

  @override
  String get opponentsSearchHint => 'Buscar oponentes...';

  @override
  String get opponentsLoadingMessage => 'Carregando oponentes...';

  @override
  String get opponentsNoResults => 'Sem Resultados';

  @override
  String get opponentsEmptyTitle => 'Nenhum Oponente Ainda';

  @override
  String get opponentsEmptySubtitle =>
      'Oponentes para rastrear seus estilos de jogo e estatisticas';

  @override
  String get opponentsEmptySearchSubtitle =>
      'Tente um termo de busca diferente';

  @override
  String get opponentsAddButton => 'Adicionar Oponente';

  @override
  String opponentsLastSeen(String date) {
    return 'Visto por ultimo: $date';
  }

  @override
  String get opponentsHands => 'Maos';

  @override
  String get opponentsEditMenu => 'Editar Oponente';

  @override
  String get opponentsDeleteMenu => 'Excluir Oponente';

  @override
  String get opponentsAddDialogTitle => 'Adicionar Oponente';

  @override
  String get opponentsEditDialogTitle => 'Editar Oponente';

  @override
  String get opponentsNameHint => 'Nome do Oponente';

  @override
  String get opponentsNotesHint => 'Notas (Opcional)';

  @override
  String get opponentsPickColor => 'Escolha uma cor';

  @override
  String get opponentsAddedSuccess => 'Oponente adicionado com sucesso';

  @override
  String get opponentsUpdatedSuccess => 'Oponente atualizado com sucesso';

  @override
  String get opponentsDeleteConfirmTitle => 'Excluir oponente?';

  @override
  String opponentsDeleteConfirmMessage(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"?\nEsta acao nao pode ser desfeita';
  }

  @override
  String get opponentsDeletedSuccess => 'Oponente excluido com sucesso';

  @override
  String get opponentsAnalyticsTitle => 'Analise de Oponentes';

  @override
  String get opponentsAnalyticsTotalLabel => 'Total de Oponentes';

  @override
  String get opponentsAnalyticsHandsTracked => 'Total de Maos Rastreadas';

  @override
  String get opponentsAnalyticsAverage => 'Media de Maos/Oponente';

  @override
  String get opponentsAnalyticsMostPlayed => 'Mais Jogado Contra';

  @override
  String get opponentsAnalyticsDistribution =>
      'Distribuicao por Tipo de Jogador:';

  @override
  String get opponentsClearAllTitle => 'Limpar Todos os Oponentes?';

  @override
  String get opponentsClearAllMessage =>
      'Isso excluira permanentemente todos os dados de oponentes. Esta acao nao pode ser desfeita!';

  @override
  String get opponentsClearAllButton => 'Limpar Tudo';

  @override
  String get opponentsClearedSuccess => 'Todos os oponentes foram removidos';

  @override
  String get setupSessionSetup => 'Configuracao da Sessao';

  @override
  String get setupSessionName => 'Nome da Sessao';

  @override
  String get setupSessionNameHint => 'ex., \"Poker de Sexta a Noite\"';

  @override
  String get setupGameType => 'Tipo de Jogo';

  @override
  String get setupCashGame => 'Cash Game';

  @override
  String get setupTournament => 'Tournament';

  @override
  String get setupSmallBlind => 'Small Blind';

  @override
  String get setupBigBlind => 'Big Blind';

  @override
  String get setupBuyInAmount => 'Valor do Buy-in';

  @override
  String get setupEnterAmount => 'Insira o valor';

  @override
  String get setupStartingStackEqualsBuyIn =>
      'Stack inicial igual ao seu buy-in.';

  @override
  String get setupStartingStack => 'Stack Inicial';

  @override
  String get setupEnterChipStack => 'Insira o stack de fichas';

  @override
  String setupMustBeAtLeastBigBlind(int bigBlind) {
    return 'Deve ser pelo menos o Big Blind ($bigBlind)';
  }

  @override
  String get setupBbAnte => 'BB Ante';

  @override
  String get setupTableSection => 'MESA';

  @override
  String get setupTableInstructions =>
      'Toque em um assento para adicionar um jogador. Arraste o botao para definir o dealer.';

  @override
  String get setupStartSession => 'Iniciar Sessao';

  @override
  String get setupMe => 'Eu';

  @override
  String setupPlayerSeat(int seatNumber) {
    return 'Jogador $seatNumber';
  }

  @override
  String get setupHero => 'Hero';

  @override
  String get homeLoadingPokerData => 'Carregando seus dados de poker...';

  @override
  String get homeWelcomeBack => 'Bem-vindo de volta';

  @override
  String get homeNoActiveSessions => 'Nenhuma sessao ativa';

  @override
  String get homeLiveSessions => 'Sessoes ao Vivo';

  @override
  String get homeClubNotFound => 'Clube nao encontrado';

  @override
  String get homeEventNotFound => 'Evento nao encontrado';

  @override
  String get homeRecentActivity => 'Atividade Recente';

  @override
  String get homeWinRate => 'Win Rate';

  @override
  String get homeHours => 'Horas';

  @override
  String get homePlayStyle => 'Estilo de Jogo';

  @override
  String get homeBankroll => 'Bankroll';

  @override
  String homeBankrollOfGoal(String current, String goal) {
    return '$current de $goal';
  }

  @override
  String homeAmountLeft(String amount) {
    return 'Faltam $amount';
  }

  @override
  String get homeEarnings => 'Ganhos';

  @override
  String homeAvgAmount(String amount) {
    return 'Media $amount';
  }

  @override
  String get homeNoEarningsDataYet => 'Nenhum dado de ganhos ainda';

  @override
  String get homeRecentSessions => 'Sessoes Recentes';

  @override
  String get homeViewAll => 'Ver Tudo';

  @override
  String get homeNoRecentSessions => 'Nenhuma sessao recente';

  @override
  String get homeStartFirstSession => 'Comece sua primeira sessao de poker!';

  @override
  String get homeAddNew => 'Adicionar Novo';

  @override
  String get homeUpcomingEvents => 'Proximos Eventos';

  @override
  String get homeNoRecentEvents => 'Nenhum evento recente';

  @override
  String get homeAddFirstEvent => 'Adicione seu primeiro evento de poker!';

  @override
  String homePlayersCount(int count) {
    return '$count Jogadores';
  }

  @override
  String homeGoingCount(int count) {
    return '$count confirmados';
  }

  @override
  String get homePrivateGame => 'Jogo Privado';

  @override
  String get homeHomeGame => 'Home Game';

  @override
  String get homeOnline => 'Online';

  @override
  String get homeEditEvent => 'Editar Evento';

  @override
  String get homeDeleteEvent => 'Excluir Evento';

  @override
  String get homeEventName => 'Nome do Evento';

  @override
  String get homeLocationVenue => 'Local/Estabelecimento';

  @override
  String get homeBuyInAmount => 'Valor do Buy-in';

  @override
  String get homeSelectDate => 'Selecione a data:';

  @override
  String get homeSaveChanges => 'Salvar Alteracoes';

  @override
  String homeDeleteEventConfirm(String eventName) {
    return 'Excluir $eventName?';
  }

  @override
  String homeDeleteEventDescription(String eventName) {
    return 'Tem certeza de que deseja excluir \"$eventName\"?';
  }

  @override
  String get homeEventDeletedSuccessfully => 'Evento excluido com sucesso';

  @override
  String get homeClubInvitation => 'Convite de Clube';

  @override
  String get homeYouveBeenInvitedToJoin => 'Voce foi convidado para participar';

  @override
  String get homeDecline => 'Recusar';

  @override
  String get homeAccept => 'Aceitar';

  @override
  String get homeInvitationDeclined => 'Convite recusado';

  @override
  String get homeInvitationAccepted => 'Convite Aceito';

  @override
  String get homeClubInvitations => 'Convites de Clube';

  @override
  String get homeLater => 'Depois';

  @override
  String get homeViewInvitations => 'Ver Convites';

  @override
  String get homeNoEarningsDataTitle => 'Nenhum Dado de Ganhos Ainda';

  @override
  String get homeNoEarningsDataDescription =>
      'Adicione alguns resultados de sessao primeiro para ver seu grafico de ganhos. Voce pode adicionar resultados na pagina de Perfil.';

  @override
  String handHandNumber(int number) {
    return 'Mao #$number';
  }

  @override
  String handFreeCounter(int used, int max) {
    return '$used/$max gratis';
  }

  @override
  String get handNextHand => 'Proxima Mao';

  @override
  String get handFoldedToMe => 'Fold para mim';

  @override
  String get handUndoLastAction => 'Desfazer Ultima Acao';

  @override
  String get handAllInHand => 'MAO ALL IN';

  @override
  String get handPot => 'Pot';

  @override
  String get handStack => 'Stack';

  @override
  String get handToAct => 'Para Agir';

  @override
  String get handStopSessionTitle => 'Encerrar Sessao?';

  @override
  String get handStopSessionMessage =>
      'Tem certeza de que deseja encerrar esta sessao? Todas as maos serao salvas.';

  @override
  String get handStop => 'Encerrar';

  @override
  String get handChangeTable => 'Trocar Mesa';

  @override
  String get handBlinds => 'Blinds';

  @override
  String get handTakesEffectNextHand => 'Entra em vigor na proxima mao';

  @override
  String get handLeaveSession => 'Sair da Sessao?';

  @override
  String get handSaveAndExit => 'Salvar e Sair';

  @override
  String get handDiscardAndExit => 'Descartar e Sair';

  @override
  String get handAdjustStack => 'Ajustar Stack';

  @override
  String get handEnterStackAmount => 'Insira o valor do stack';

  @override
  String get handGestureGuide => 'Guia de Gestos';

  @override
  String get handManagePlayers => 'Gerenciar Jogadores';

  @override
  String get handStopSession => 'Encerrar Sessao';

  @override
  String get handRebuy => 'Rebuy';

  @override
  String get handGestures => 'Gestos';

  @override
  String get handGestureTap => 'Toque';

  @override
  String get handGestureCheckCall => 'Check / Call';

  @override
  String get handGestureSwipeOut => 'Deslizar para Fora';

  @override
  String get handGestureSwipeUp => 'Deslizar para Cima';

  @override
  String get handGestureBetRaise => 'Bet / Raise';

  @override
  String get handStreetComplete => 'Street Completa';

  @override
  String get handWinsThePot => 'ganha o pot';

  @override
  String get handHandComplete => 'Mao Completa';

  @override
  String get handTapToContinue => 'Toque para continuar';

  @override
  String get handRaiseAmount => 'Valor do Raise';

  @override
  String get handBetAmount => 'Valor do Bet';

  @override
  String get handPleaseEnterValidNumber => 'Por favor, insira um numero valido';

  @override
  String get handConfirmRebuy => 'Confirmar Rebuy';

  @override
  String get handRebuyReplaceStack =>
      'Prosseguir com um rebuy substituira seu stack atual. Tem certeza de que deseja continuar?';

  @override
  String get handProceed => 'Prosseguir';

  @override
  String get handEnterRebuyDetails =>
      'Insira os detalhes do rebuy para o tournament';

  @override
  String get handRebuyAmount => 'Valor do Rebuy';

  @override
  String get handNewStackSize => 'Novo Tamanho do Stack';

  @override
  String get handChipCountAfterRebuy => 'Quantidade de fichas apos o rebuy';

  @override
  String get handSessionInfo => 'Info da Sessao';

  @override
  String handTotalInvested(String amount) {
    return 'Total Investido: $amount';
  }

  @override
  String handRebuysCount(int count) {
    return 'Rebuys: $count';
  }

  @override
  String get handAddRebuy => 'Adicionar Rebuy';

  @override
  String get handPleaseEnterValidAmounts => 'Por favor, insira valores validos';

  @override
  String get handHandInProgress => 'Mao em Andamento';

  @override
  String get handHandInProgressMessage =>
      'Ha uma mao em andamento. Avancar para a proxima mao descartara todas as acoes e restaurara os stacks dos jogadores.';

  @override
  String get handMoveToNextHand => 'Ir para a Proxima Mao';

  @override
  String get handMainPot => 'Pot Principal';

  @override
  String handSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String get handPokerSession => 'Sessao de Poker';

  @override
  String handActionsHandNumber(String number) {
    return 'Mao #$number';
  }

  @override
  String handActionsPosition(String position) {
    return 'Posicao: $position';
  }

  @override
  String get handActionsShareHand => 'Compartilhar Mao';

  @override
  String get handActionsShowHoleCards => 'Mostrar hole cards';

  @override
  String get handActionsShowHoleCardsSubtitle =>
      'Suas cartas ficarao visiveis no link compartilhado';

  @override
  String get handActionsHideHoleCards => 'Ocultar hole cards';

  @override
  String get handActionsHideHoleCardsSubtitle =>
      'Suas cartas ficarao ocultas no link compartilhado';

  @override
  String get handActionsShareMessage => 'Confira essa mao no Final Table!';

  @override
  String handActionsShareSubject(String number) {
    return 'Mao de Poker #$number';
  }

  @override
  String get handActionsFailedToShareHand => 'Falha ao compartilhar mao';

  @override
  String get handActionsGeneratingExport => 'Gerando exportacao PokerStars...';

  @override
  String handActionsExportedSuccessfully(String number) {
    return 'Mao #$number exportada com sucesso!';
  }

  @override
  String handActionsFailedToExport(String error) {
    return 'Falha ao exportar mao: $error';
  }

  @override
  String get handActionsMissingHeroCards => 'Cartas do Hero Ausentes';

  @override
  String get handActionsMissingHeroCardsMessage =>
      'A analise de IA requer que suas hole cards estejam registradas. Esta mao nao pode ser analisada porque as cartas do hero estao ausentes.';

  @override
  String get handActionsYourCards => 'Suas Cartas';

  @override
  String get handActionsOpponentCards => 'Cartas do Oponente';

  @override
  String handActionsPlayerSeat(int id) {
    return 'Jogador $id';
  }

  @override
  String get handActionsPot => 'POT';

  @override
  String get handActionsBlinds => 'BLINDS';

  @override
  String get handActionsWinner => 'VENCEDOR';

  @override
  String handActionsPlayersCount(int count) {
    return '$count jogadores';
  }

  @override
  String get handActionsActionSummary => 'Resumo das Acoes';

  @override
  String get handActionsPreflop => 'PREFLOP';

  @override
  String get handActionsBoard => 'BOARD';

  @override
  String get handActionsPlayer => 'JOGADOR';

  @override
  String get handActionsStack => 'STACK';

  @override
  String get handActionsAction => 'ACAO';

  @override
  String get handActionsAmount => 'VALOR';

  @override
  String get handActionsYou => 'Voce';

  @override
  String get handActionsAllIn => 'ALL IN';

  @override
  String get handActionsNotes => 'Notas';

  @override
  String get handActionsAnalyzingHand => 'Analisando Mao...';

  @override
  String get handActionsHeroCardsMissing => 'Cartas do Hero Ausentes';

  @override
  String get handActionsUnlockAiAnalysis => 'Desbloquear Analise de IA';

  @override
  String get handActionsAnalysisComplete => 'Analise Concluida';

  @override
  String get handActionsAiAnalyzerBeta => 'Analisador IA (beta)';

  @override
  String get handActionsAnalysisFailed => 'Falha na Analise';

  @override
  String get handActionsAiAnalysis => 'Analise de IA';

  @override
  String get handActionsStreetByStreetBreakdown => 'Analise por Street';

  @override
  String handActionsAnalysisCompletedIn(String time) {
    return 'Analise concluida em ${time}s';
  }

  @override
  String get handActionsFailedToUpdateStar =>
      'Falha ao atualizar status de favorito';

  @override
  String handActionsPotAmount(String amount) {
    return 'Pot: $amount';
  }

  @override
  String opponentDetailHandsTracked(int count) {
    return '$count maos rastreadas';
  }

  @override
  String get opponentDetailNoDataYet => 'Sem dados ainda';

  @override
  String get opponentDetailHands => 'Maos';

  @override
  String get opponentDetailLastSeen => 'Visto por ultimo:';

  @override
  String get opponentDetailNotes => 'Notas';

  @override
  String get opponentDetailEditOpponent => 'Editar Oponente';

  @override
  String get opponentDetailDeleteOpponent => 'Excluir Oponente';

  @override
  String get opponentDetailStatistics => 'Estatisticas';

  @override
  String get opponentDetailNoStatisticsAvailable =>
      'Nenhuma estatistica disponivel';

  @override
  String get opponentDetailAggressionFreq => 'Freq. de Agressao';

  @override
  String get opponentDetailShowdownPercent => 'Showdown %';

  @override
  String get opponentDetailHandHistory => 'Historico de Maos';

  @override
  String get opponentDetailViewAllHands =>
      'Ver todas as maos jogadas com este oponente';

  @override
  String get opponentDetailViewHandHistory => 'Ver Historico de Maos';

  @override
  String get opponentDetailNoHandsFound => 'Nenhuma Mao Encontrada';

  @override
  String opponentDetailNoHandsMessage(String name) {
    return 'Voce ainda nao jogou nenhuma mao com \"$name\"';
  }

  @override
  String get opponentDetailOpponentName => 'Nome do Oponente';

  @override
  String get opponentDetailNotesOptional => 'Notas (Opcional)';

  @override
  String get opponentDetailPickColor => 'Escolha uma cor';

  @override
  String get opponentDetailColorRed => 'Vermelho';

  @override
  String get opponentDetailColorLightBlue => 'Azul Claro';

  @override
  String get opponentDetailColorGreen => 'Verde';

  @override
  String get opponentDetailColorOrange => 'Laranja';

  @override
  String get opponentDetailColorPurple => 'Roxo';

  @override
  String get opponentDetailColorTeal => 'Verde-azulado';

  @override
  String get opponentDetailColorPink => 'Rosa';

  @override
  String get opponentDetailColorIndigo => 'Indigo';

  @override
  String get opponentDetailUpdatedSuccessfully =>
      'Oponente atualizado com sucesso';

  @override
  String get opponentDetailDeleteConfirmTitle => 'Excluir oponente?';

  @override
  String opponentDetailDeleteConfirmMessage(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"?\nEsta acao nao pode ser desfeita';
  }

  @override
  String get opponentDetailDeletedSuccessfully =>
      'Oponente excluido com sucesso';

  @override
  String opponentDetailErrorDeleting(String error) {
    return 'Erro ao excluir oponente: $error';
  }

  @override
  String get individualSessionCreatedLocally =>
      'Sessao criada localmente. Sera sincronizada com a nuvem quando houver conexao.';

  @override
  String get individualUpdateCurrentStack => 'Atualizar Stack Atual';

  @override
  String get individualCurrentStack => 'Stack Atual:';

  @override
  String get individualSetNewTotal => 'Definir Novo Total';

  @override
  String get individualEnterNewTotalStack => 'Insira o novo stack total';

  @override
  String get individualAddSubtractAmount => 'Adicionar/Subtrair Valor';

  @override
  String get individualAmount => 'Valor';

  @override
  String get individualSetTotal => 'Definir Total';

  @override
  String get individualNoteLabel => 'Nota (opcional)';

  @override
  String get individualNoteHint => 'p.ex. Ganhei um grande pote com AA';

  @override
  String get individualUpdateBlinds => 'Atualizar Blinds';

  @override
  String get individualSmallBlind => 'Small Blind';

  @override
  String get individualBigBlind => 'Big Blind';

  @override
  String get individualBbMode => 'Modo BB';

  @override
  String get individualCurrentStackLabel => 'Stack Atual';

  @override
  String get individualSessionInfo => 'Info da Sessao';

  @override
  String get individualStartingStack => 'Stack Inicial';

  @override
  String get individualInitialBuyIn => 'Buy-in Inicial';

  @override
  String get individualRebuys => 'Rebuys';

  @override
  String get individualTotalInvested => 'Total Investido';

  @override
  String get individualBlindsLabel => 'Blinds';

  @override
  String get individualHandsLogged => 'Maos Registradas';

  @override
  String get individualLogAHand => 'Registrar uma Mao';

  @override
  String get individualGoBackToHand => 'Voltar para a Mao';

  @override
  String get individualStackChart => 'Grafico de Stack';

  @override
  String get individualCompleteHandToSee =>
      'Complete uma mao para ver a tendencia do seu stack';

  @override
  String get individualStopSessionTitle => 'Encerrar Sessao?';

  @override
  String get individualStopSessionMessage =>
      'Tem certeza de que deseja encerrar esta sessao? Todas as maos serao salvas.';

  @override
  String get individualStop => 'Encerrar';

  @override
  String get individualConfirmRebuy => 'Confirmar Rebuy';

  @override
  String individualRebuyCurrentStack(String stack) {
    return 'Voce tem $stack restante atualmente.';
  }

  @override
  String get individualRebuyReplaceMessage =>
      'Prosseguir com um rebuy substituira seu stack atual. Tem certeza de que deseja continuar?';

  @override
  String get individualProceedWithRebuy => 'Prosseguir com Rebuy';

  @override
  String get individualAddOn => 'Add-on';

  @override
  String get individualAddOnDescription =>
      'Insira o valor do add-on para aumentar seu investimento total';

  @override
  String get individualAddOnAmount => 'Valor do Add-on';

  @override
  String get individualAddOnConfirm => 'Adicionar';

  @override
  String get individualAddOnDescriptionTournament =>
      'Insira o preço do add-on e as fichas recebidas';

  @override
  String get individualAddOnPrice => 'Preço do Add-on';

  @override
  String get individualAddOnChips => 'Fichas recebidas';

  @override
  String get individualRebuy => 'Rebuy';

  @override
  String get individualEnterRebuyAmount =>
      'Insira o valor do rebuy (stack sera igual ao valor do rebuy)';

  @override
  String get individualEnterRebuyAmountAndStack =>
      'Insira o valor do rebuy e o novo tamanho do stack';

  @override
  String get individualRebuyAmount => 'Valor do Rebuy';

  @override
  String get individualNewStackSize => 'Novo Tamanho do Stack';

  @override
  String get individualChipCountAfterRebuy =>
      'Quantidade de fichas apos o rebuy';

  @override
  String individualTotalInvestedAmount(String amount) {
    return 'Total Investido: \$$amount';
  }

  @override
  String individualCurrentStackAmount(String stack) {
    return 'Stack Atual: $stack';
  }

  @override
  String individualRebuysCount(int count) {
    return 'Rebuys: $count';
  }

  @override
  String get individualAddRebuy => 'Adicionar Rebuy';

  @override
  String get individualPleaseEnterValidRebuy =>
      'Por favor, insira um valor de rebuy valido';

  @override
  String get individualPleaseEnterValidStack =>
      'Por favor, insira um tamanho de stack valido';

  @override
  String individualRebuyAddedSimple(String amount) {
    return 'Rebuy adicionado: \$$amount';
  }

  @override
  String individualRebuyAddedWithStack(String amount, String stack) {
    return 'Rebuy adicionado: \$$amount (Stack: $stack)';
  }

  @override
  String get authWelcome => 'Bem-vindo ao Final Table';

  @override
  String get authSignIn => 'Entrar';

  @override
  String get authRegister => 'Registrar';

  @override
  String get authEmail => 'E-mail';

  @override
  String get authPassword => 'Senha';

  @override
  String get authDisplayName => 'Nome de Exibicao';

  @override
  String get authConfirmPassword => 'Confirmar Senha';

  @override
  String get authPleaseEnterEmail => 'Por favor, insira seu e-mail';

  @override
  String get authPleaseEnterValidEmail => 'Por favor, insira um e-mail valido';

  @override
  String get authPleaseEnterPassword => 'Por favor, insira sua senha';

  @override
  String get authPleaseEnterName => 'Por favor, insira seu nome';

  @override
  String get authNameMinLength => 'O nome deve ter pelo menos 2 caracteres';

  @override
  String get authPleaseEnterAPassword => 'Por favor, insira uma senha';

  @override
  String get authPasswordMinLength =>
      'A senha deve ter pelo menos 6 caracteres';

  @override
  String get authPleaseConfirmPassword => 'Por favor, confirme sua senha';

  @override
  String get authPasswordsDoNotMatch => 'As senhas nao coincidem';

  @override
  String get authCreateAccount => 'Criar Conta';

  @override
  String get authForgotPassword => 'Esqueceu a Senha?';

  @override
  String get authResetPassword => 'Redefinir Senha';

  @override
  String get authResetPasswordMessage =>
      'Insira seu endereco de e-mail para receber um link de redefinicao de senha.';

  @override
  String get authSendResetLink => 'Enviar Link de Redefinicao';

  @override
  String get authPasswordResetSent => 'E-mail de redefinicao de senha enviado!';

  @override
  String get paywallRestore => 'Restaurar';

  @override
  String get paywallTitle => 'FINAL TABLE PREMIUM';

  @override
  String paywallUnlockFeature(String featureName) {
    return 'Desbloquear $featureName';
  }

  @override
  String get paywallGoPremium => 'Seja Premium';

  @override
  String get paywallFeatureSubtitle =>
      'Este recurso faz parte do Final Table Premium. Escolha um plano que combina com o seu jogo.';

  @override
  String get paywallGeneralSubtitle =>
      'Desbloqueie tudo que o Final Table tem a oferecer. Registre mais maos, analise seu jogo, gerencie seu clube.';

  @override
  String get paywallProTier => 'PRO';

  @override
  String get paywallFreeTrialBadge => '7 dias gratis';

  @override
  String get paywallProDescription =>
      'Tudo que voce precisa para dominar seu jogo.';

  @override
  String get paywallUnlimitedHandLogging => 'Registro ilimitado de maos';

  @override
  String get paywallFullSessionHistory => 'Historico completo de sessoes';

  @override
  String get paywallAiHandAnalysis => 'Analise de maos por IA';

  @override
  String get paywallExportHandsCsv => 'Exportar maos para CSV';

  @override
  String get paywallProMonthly => '\$29,99/mes';

  @override
  String get paywallProYearly => '\$249,99/ano';

  @override
  String get paywallStartFreeTrial => 'Iniciar Teste Gratis de 7 Dias';

  @override
  String get paywallEliteTier => 'ELITE';

  @override
  String get paywallEliteDescription => 'Leve seu jogo para o proximo nivel.';

  @override
  String get paywallEverythingInProElite => 'Tudo do Pro';

  @override
  String get paywallEliteFeature1 => 'Perfil avancado de oponentes';

  @override
  String get paywallEliteFeature2 => 'Analise detalhada de sessoes';

  @override
  String get paywallEliteFeature3 => 'Suporte prioritario';

  @override
  String get paywallEliteMonthly => '\$29,99/mes';

  @override
  String get paywallEliteYearly => '\$249,99/ano';

  @override
  String get paywallGetElite => 'Obter Elite';

  @override
  String get paywallClubTier => 'CLUB';

  @override
  String get paywallClubDescription =>
      'Para home games, clubes e locais ao vivo.';

  @override
  String get paywallEverythingInPro => 'Tudo do Pro';

  @override
  String get paywallClubManagement =>
      'Gerenciamento de clube e cargos de membros';

  @override
  String get paywallLiveDealerVoice => 'Registro por voz com dealer ao vivo';

  @override
  String get paywallMultiTableEvents => 'Eventos multi-mesa com rankings';

  @override
  String get paywallClubMonthly => '\$39,99/mes';

  @override
  String get paywallClubYearly => '\$299,99/ano';

  @override
  String get paywallGetClub => 'Obter Club';

  @override
  String get paywallDisclaimer =>
      'Assinaturas renovam automaticamente. Cancele a qualquer momento nas configuracoes da sua conta.';

  @override
  String get paywallTerms => 'Termos';

  @override
  String get paywallPrivacy => 'Privacidade';

  @override
  String get paywallPurchasesRestored => 'Compras restauradas';

  @override
  String get paywallNoPreviousPurchases => 'Nenhuma compra anterior encontrada';

  @override
  String paywallComingSoon(String tier) {
    return 'Assinaturas $tier em breve';
  }

  @override
  String trialConfirmTitle(String tier) {
    return 'Os primeiros 7 dias de $tier são por nossa conta';
  }

  @override
  String get trialConfirmTodayTitle => 'Hoje';

  @override
  String trialConfirmTodayBody(String tier) {
    return 'Acesso completo a todos os recursos $tier';
  }

  @override
  String get trialConfirmReminderTitle => 'Em 5 dias';

  @override
  String get trialConfirmReminderBody =>
      'Receba um lembrete antes do fim do período gratuito';

  @override
  String get trialConfirmStartTitle => 'Em 7 dias';

  @override
  String get trialConfirmStartBody =>
      'Sua assinatura começa, a menos que você cancele antes';

  @override
  String get trialConfirmPriceSummary => 'Teste 7 dias grátis, depois';

  @override
  String get trialConfirmStartCta => 'Iniciar meu teste gratuito de 7 dias';

  @override
  String get trialConfirmDisclaimer =>
      'Sem cobranças ainda. Cancele a qualquer momento na App Store.';

  @override
  String get introGameSetup => 'Configuracao do Jogo';

  @override
  String get introConfigureSession => 'Configure sua sessao';

  @override
  String get introSmallBlind => 'Small Blind';

  @override
  String get introBigBlind => 'Big Blind';

  @override
  String get introPlayers => 'Jogadores';

  @override
  String get introGameType => 'Tipo de Jogo';

  @override
  String get introBbAnte => 'BB Ante';

  @override
  String get introBbAnteDescription => 'Ativar regra de BB ante';

  @override
  String get introStartGame => 'INICIAR JOGO';

  @override
  String get introStartingSession => 'Iniciando sua sessao de poker...';

  @override
  String introEnterField(String title) {
    return 'Insira $title';
  }

  @override
  String get introEnterAmount => 'Insira o valor';

  @override
  String get introPleaseEnterValidNumber =>
      'Por favor, insira um numero positivo valido';

  @override
  String get introRingGame => 'Ring Game';

  @override
  String get introMultiTable => 'Multi-Table';

  @override
  String get invitationTitle => 'Convites de Clube';

  @override
  String get invitationNoPending => 'Nenhum convite pendente';

  @override
  String get invitationYouWillSeeHere => 'Voce vera convites de clubes aqui';

  @override
  String get invitationGoBack => 'Voltar';

  @override
  String invitationFailedToLoad(String error) {
    return 'Falha ao carregar convites: $error';
  }

  @override
  String invitationJoinedAs(String clubName, String role) {
    return 'Entrou em $clubName como $role';
  }

  @override
  String invitationFailedToAccept(String error) {
    return 'Falha ao aceitar convite: $error';
  }

  @override
  String get invitationDeclined => 'Convite recusado';

  @override
  String invitationFailedToDecline(String error) {
    return 'Falha ao recusar convite: $error';
  }

  @override
  String get invitationUnknownClub => 'Clube Desconhecido';

  @override
  String invitationInvitedBy(String name) {
    return 'Convidado por $name';
  }

  @override
  String invitationExpiresDate(String date) {
    return 'Expira em $date';
  }

  @override
  String get invitationExpired => 'Expirado';

  @override
  String invitationExpiresInDays(int days) {
    return 'em $days dia(s)';
  }

  @override
  String invitationExpiresInHours(int hours) {
    return 'em $hours hora(s)';
  }

  @override
  String get invitationExpiresSoon => 'em breve';

  @override
  String get invitationDeclineButton => 'Recusar';

  @override
  String get invitationAcceptButton => 'Aceitar';

  @override
  String get notificationTitle => 'Notificacoes';

  @override
  String get notificationToday => 'Hoje';

  @override
  String get notificationYesterday => 'Ontem';

  @override
  String get notificationThisWeek => 'Esta Semana';

  @override
  String get notificationEarlier => 'Anteriores';

  @override
  String get notificationMarkAllRead => 'Marcar todas como lidas';

  @override
  String get notificationMarkAsRead => 'Marcar como lida';

  @override
  String get notificationNoNotifications => 'Sem notificacoes';

  @override
  String get notificationEvents => 'Eventos';

  @override
  String get notificationRsvp => 'RSVP';

  @override
  String get notificationClubs => 'Clubes';

  @override
  String get notificationInvitations => 'Convites';

  @override
  String get notificationSeats => 'Assentos';

  @override
  String get notificationSupport => 'Suporte';

  @override
  String get notificationClubNotFound => 'Clube nao encontrado';

  @override
  String get notificationEventNotFound => 'Evento nao encontrado';

  @override
  String notificationError(String error) {
    return 'Erro: $error';
  }

  @override
  String notificationErrorLoadingEvent(String error) {
    return 'Erro ao carregar evento: $error';
  }

  @override
  String notificationFailedToLoadClub(String error) {
    return 'Falha ao carregar clube: $error';
  }

  @override
  String get notificationClubInvitation => 'Convite de Clube';

  @override
  String get notificationInvitedToJoin => 'Voce foi convidado para participar';

  @override
  String get notificationInvitationDeclined => 'Convite recusado';

  @override
  String get notificationNotAuthenticated => 'Nao autenticado';

  @override
  String get notificationInvitationAccepted => 'Convite Aceito';

  @override
  String notificationAcceptedMessage(String name, String clubName) {
    return '$name aceitou o convite para participar de $clubName.';
  }

  @override
  String get notificationInvitationDeclinedTitle => 'Convite Recusado';

  @override
  String notificationDeclinedMessage(String name, String clubName) {
    return '$name recusou o convite para participar de $clubName.';
  }

  @override
  String get notificationRequestResolved => 'Solicitacao Resolvida';

  @override
  String get notificationRequestClosed => 'Solicitacao Fechada';

  @override
  String get notificationResponse => 'Resposta';

  @override
  String get calendarTitle => 'Calendario de Poker';

  @override
  String get calendarNewEvent => 'Novo Evento';

  @override
  String get calendarEventType => 'Tipo de Evento';

  @override
  String get calendarEventTitle => 'Titulo';

  @override
  String get calendarLocation => 'Local';

  @override
  String get calendarBuyInAmount => 'Valor do Buy-in';

  @override
  String get calendarEventDateTime => 'Data e Hora do Evento';

  @override
  String get calendarStarts => 'Inicio';

  @override
  String get calendarSelectDate => 'Selecione a Data:';

  @override
  String get calendarReset => 'Resetar';

  @override
  String get calendarSun => 'DOM';

  @override
  String get calendarMon => 'SEG';

  @override
  String get calendarTue => 'TER';

  @override
  String get calendarWed => 'QUA';

  @override
  String get calendarThu => 'QUI';

  @override
  String get calendarFri => 'SEX';

  @override
  String get calendarSat => 'SAB';

  @override
  String get calendarNoRecentEvents => 'Nenhum evento recente';

  @override
  String get calendarAddFirstEvent => 'Adicione seu primeiro evento de poker!';

  @override
  String get calendarAddNewEvent => 'Adicionar Novo Evento';

  @override
  String get calendarSelectYear => 'Selecionar Ano';

  @override
  String get calendarEditEvent => 'Editar Evento';

  @override
  String get calendarDeleteEvent => 'Excluir Evento';

  @override
  String get calendarTournament => 'Tournament';

  @override
  String get calendarCashGame => 'Cash Game';

  @override
  String get calendarPrivateGame => 'Jogo Privado';

  @override
  String get calendarOnline => 'Online';

  @override
  String calendarFailedToCreateEvent(String error) {
    return 'Falha ao criar evento: $error';
  }

  @override
  String calendarFailedToUpdateEvent(String error) {
    return 'Falha ao atualizar evento: $error';
  }

  @override
  String get calendarFailedToDeleteEvent => 'Falha ao excluir evento';

  @override
  String get calendarClubNotFound => 'Clube nao encontrado';

  @override
  String get calendarEventNotFound => 'Evento nao encontrado';

  @override
  String calendarFailedToLoadEvent(String error) {
    return 'Falha ao carregar evento: $error';
  }

  @override
  String calendarDeleteConfirmTitle(String title) {
    return 'Excluir $title?';
  }

  @override
  String calendarDeleteConfirmMessage(String title) {
    return 'Tem certeza de que deseja excluir \"$title\"?\nEsta acao nao pode ser desfeita.';
  }

  @override
  String get sessionAnalyticsTitle => 'Analise da Sessao';

  @override
  String sessionAnalyticsHandsLogged(int count) {
    return '$count maos registradas';
  }

  @override
  String get sessionAnalyticsDeleteTitle => 'Excluir Sessao?';

  @override
  String get sessionAnalyticsDeleteMessage =>
      'Isso excluira permanentemente esta sessao, incluindo todo o historico de maos, dados do grafico de stack e relatorios de analise de IA. Esta acao nao pode ser desfeita.';

  @override
  String get sessionAnalyticsDeleted => 'Sessao excluida';

  @override
  String get sessionAnalyticsFailedToDelete => 'Falha ao excluir sessao';

  @override
  String get sessionAnalyticsExportSession => 'Exportar Sessao';

  @override
  String sessionAnalyticsExportConfirm(int count, String email) {
    return 'Exportar $count maos para $email?';
  }

  @override
  String get sessionAnalyticsExport => 'Exportar';

  @override
  String sessionAnalyticsExportSent(String email) {
    return 'Exportacao enviada para $email';
  }

  @override
  String sessionAnalyticsExportFailed(String error) {
    return 'Falha na exportacao: $error';
  }

  @override
  String get sessionAnalyticsNoEmailFound =>
      'Nenhum endereco de e-mail encontrado. Por favor, entre com uma conta de e-mail.';

  @override
  String get sessionAnalyticsPokerSession => 'Sessao de Poker';

  @override
  String get sessionAnalyticsTotalInvested => 'Total Investido';

  @override
  String get sessionAnalyticsFinalStack => 'Stack Final';

  @override
  String get sessionAnalyticsProfitLoss => 'Lucro/Perda';

  @override
  String get sessionAnalyticsAvgGrowth => 'Crescimento Medio';

  @override
  String get sessionAnalyticsDuration => 'Duracao';

  @override
  String get sessionAnalyticsRebuys => 'Rebuys';

  @override
  String get sessionAnalyticsStackChart => 'Grafico de Stack';

  @override
  String get sessionAnalyticsNoStackHistory =>
      'Sem Historico de Stack Disponivel';

  @override
  String get sessionAnalyticsStackTrackedFuture =>
      'Mudancas de stack serao rastreadas em sessoes futuras';

  @override
  String get sessionAnalyticsViewLoggedHands => 'Ver Maos Registradas';

  @override
  String get sessionAnalyticsStart => 'Inicio';

  @override
  String get sessionAnalyticsRebuy => 'Rebuy';

  @override
  String get sessionAnalyticsEnd => 'Fim';

  @override
  String get seatSetupTitle => 'Configurar Assento';

  @override
  String get seatSetupManagePlayers => 'Gerenciar Jogadores';

  @override
  String get seatSetupClickToConfig =>
      'Clique no assento para configurar. Arraste o botao para posicionar';

  @override
  String get seatSetupButtonLocked => 'Botao bloqueado - mao em andamento';

  @override
  String get seatSetupUpdatePlayerInfo => 'Atualizar informacoes do jogador';

  @override
  String get seatSetupEmpty => 'Vazio';

  @override
  String get seatSetupThisIsMySeat => 'Este e meu assento';

  @override
  String get seatSetupPlayerName => 'Nome do Jogador';

  @override
  String get seatSetupBuyInAmount => 'Valor do Buy-in (\$)';

  @override
  String get seatSetupStartingChips => 'Fichas Iniciais';

  @override
  String seatSetupSaveAsOpponent(String name) {
    return 'Salvar \"$name\" como oponente?';
  }

  @override
  String get seatSetupOpponentSaved => 'Oponente salvo!';

  @override
  String seatSetupFailedToSave(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get seatSetupNoData => 'Sem Dados';

  @override
  String get seatSetupStartSession => 'Iniciar Sessao';

  @override
  String get seatSetupSaveChanges => 'Salvar Alteracoes';

  @override
  String get seatSetupPleaseSelectSeat => 'Por favor, selecione seu assento';

  @override
  String seatSetupSeatNumber(int number) {
    return 'Assento $number';
  }

  @override
  String seatSetupPlayerDefault(int number) {
    return 'Jogador $number';
  }

  @override
  String get quickStackTitle => 'Atualizar Stacks e Botao';

  @override
  String quickStackBlinds(String blinds) {
    return 'Blinds: $blinds';
  }

  @override
  String get quickStackInstruction =>
      'Toque no stack para editar  •  Deslize para ajustar  •  Toque D para botao';

  @override
  String get quickStackContinue => 'CONTINUAR PARA REGISTRAR MAO';

  @override
  String get quickStackEditStack => 'Editar Stack';

  @override
  String get quickStackStackInBb => 'Stack em BB';

  @override
  String quickStackCurrentValue(String bbValue, String chipValue) {
    return 'Atual: $bbValue BB = $chipValue';
  }

  @override
  String get quickStackValidationError =>
      'Por favor, insira um valor entre 0 e 1000 BB';

  @override
  String quickStackSeat(int number) {
    return 'Assento $number';
  }

  @override
  String get quickStackEmpty => 'Vazio';

  @override
  String quickStackPlayerDefault(int id) {
    return 'Jogador $id';
  }

  @override
  String get handReviewTitle => 'Revisao da Mao';

  @override
  String get handReviewYourHoleCards => 'Suas Hole Cards';

  @override
  String get handReviewOptional => '(opcional)';

  @override
  String get handReviewQuickTags => 'Tags Rapidas';

  @override
  String get handReviewTagBluff => 'Bluff';

  @override
  String get handReviewTagValue => 'Value';

  @override
  String get handReviewTagMistake => 'Erro';

  @override
  String get handReviewTagCooler => 'Cooler';

  @override
  String get handReviewTagHeroCall => 'Hero Call';

  @override
  String get handReviewTagExploit => 'Exploit';

  @override
  String get handReviewNotes => 'Notas';

  @override
  String get handReviewNotesHint => 'Adicione uma nota sobre esta mao...';

  @override
  String get handReviewSaveHand => 'Salvar Mao';

  @override
  String get handReviewSkip => 'Pular';

  @override
  String get handReviewDuplicateCardError =>
      'Voce nao pode selecionar a mesma carta duas vezes!';

  @override
  String get handReviewSelectBothOrNone =>
      'Por favor, selecione ambas as hole cards ou deixe ambas vazias';

  @override
  String get holeCardsTitle => 'Suas Hole Cards';

  @override
  String get holeCardsSubtitle => 'Hole Cards';

  @override
  String get holeCardsWinnerBadge => 'VENCEDOR';

  @override
  String get holeCardsSave => 'Salvar';

  @override
  String get holeCardsSkip => 'Pular';

  @override
  String get holeCardsSkipAllRemaining => 'Pular Todas Restantes';

  @override
  String get holeCardsDuplicateCardError =>
      'Voce nao pode selecionar a mesma carta duas vezes!';

  @override
  String get holeCardsSelectBothOrSkip =>
      'Por favor, selecione ambas as hole cards ou pule para continuar';

  @override
  String get holeCardsClearAll => 'Limpar Tudo';

  @override
  String get showdownTitle => 'Showdown';

  @override
  String get showdownEnterOpponentCards =>
      'Insira as cartas do oponente no showdown:';

  @override
  String showdownPlayerLabel(int seatNumber) {
    return 'Jogador $seatNumber';
  }

  @override
  String get showdownCard1 => 'Carta 1';

  @override
  String get showdownCard2 => 'Carta 2';

  @override
  String get showdownClear => 'Limpar';

  @override
  String get showdownWinner => 'Vencedor:';

  @override
  String get showdownHandDescriptionLabel => 'Descricao da Mao (opcional)';

  @override
  String get showdownHandDescriptionHint =>
      'ex., \"Straight flush\", \"Full house Ases sobre Reis\"';

  @override
  String get showdownSkip => 'Pular';

  @override
  String get showdownSave => 'Salvar';

  @override
  String get showdownSelectCard => 'Selecionar Carta';

  @override
  String get tableManagementSectionTitle => 'MESA';

  @override
  String tableManagementPlayersCount(int count) {
    return '$count jogadores';
  }

  @override
  String get tableManagementDealerButton => 'Botao do Dealer';

  @override
  String get tableManagementAddPlayer => 'Adicionar Jogador';

  @override
  String tableManagementYouSuffix(String name) {
    return '$name (Voce)';
  }

  @override
  String get tableManagementAdjustStack => 'Ajustar Stack';

  @override
  String get tableManagementRebuy => 'Rebuy';

  @override
  String get tableManagementRemove => 'Remover';

  @override
  String get tableManagementAdjustStackTitle => 'Ajustar Stack';

  @override
  String get tableManagementEnterStackAmount => 'Insira o valor do stack';

  @override
  String get tableManagementRebuyTitle => 'Rebuy';

  @override
  String get tableManagementRebuyAmountHint => 'Valor do rebuy a adicionar';

  @override
  String get tableManagementAdd => 'Adicionar';

  @override
  String get tableManagementRemovePlayerTitle => 'Remover Jogador?';

  @override
  String tableManagementRemovePlayerMessage(String playerName) {
    return 'Remover $playerName da mesa?';
  }

  @override
  String tableManagementAddPlayerSeatTitle(int seatNumber) {
    return 'Adicionar Jogador — Assento $seatNumber';
  }

  @override
  String get tableManagementThisIsMe => 'Sou eu';

  @override
  String get tableManagementNameLabel => 'Nome';

  @override
  String get tableManagementSearchOrEnterName => 'Buscar ou inserir nome';

  @override
  String tableManagementSaveAsOpponent(String name) {
    return 'Salvar \"$name\" como oponente';
  }

  @override
  String tableManagementSavedAsOpponent(String name) {
    return '$name salvo como oponente';
  }

  @override
  String get tableManagementStartingStack => 'Stack Inicial';

  @override
  String get tableManagementStackAmountHint => 'Valor do stack';

  @override
  String get tableManagementMoveMeHere => 'Mover-me Para Aqui';

  @override
  String tableManagementSeatLabel(int seatNumber) {
    return 'Assento $seatNumber';
  }

  @override
  String get seatConfigRemove => 'Remover';

  @override
  String get seatConfigThisIsMe => 'Sou eu';

  @override
  String get seatConfigNameLabel => 'Nome';

  @override
  String get seatConfigSearchOrEnterName => 'Buscar ou inserir nome';

  @override
  String seatConfigSaveAsOpponent(String name) {
    return 'Salvar \"$name\" como oponente';
  }

  @override
  String seatConfigSavedAsOpponent(String name) {
    return '$name salvo como oponente';
  }

  @override
  String seatConfigSeatTitle(int seatNumber) {
    return 'Assento $seatNumber';
  }

  @override
  String get seatConfigStackLabel => 'Stack';

  @override
  String get seatConfigUpdateButton => 'Atualizar';

  @override
  String get seatConfigAddPlayerButton => 'Adicionar Jogador';

  @override
  String get seatManagementSetupSeats => 'Configurar Assentos';

  @override
  String get seatManagementManagePlayers => 'Gerenciar Jogadores';

  @override
  String get seatManagementChooseSeatSubtitle =>
      'Escolha seu assento e configure a mesa';

  @override
  String get seatManagementUpdatePlayerSubtitle =>
      'Atualizar informacoes do jogador';

  @override
  String get seatManagementButtonPosition => 'Posicao do Botao';

  @override
  String seatManagementSeatLabel(int seatNumber) {
    return 'Assento $seatNumber';
  }

  @override
  String get seatManagementEmpty => 'Vazio';

  @override
  String get seatManagementActive => 'Ativo';

  @override
  String get seatManagementPlayerNameLabel => 'Nome do Jogador';

  @override
  String get seatManagementEnterPlayerName => 'Insira o nome do jogador';

  @override
  String get seatManagementBuyInAmountCash => 'Valor do Buy-in (\$)';

  @override
  String get seatManagementStartingChips => 'Fichas Iniciais';

  @override
  String get seatManagementSaveOpponentTitle => 'Salvar Oponente?';

  @override
  String seatManagementSaveOpponentMessage(String name) {
    return 'Gostaria de salvar \"$name\" na sua lista de oponentes para rastreamento futuro?';
  }

  @override
  String get seatManagementNotNow => 'Agora Nao';

  @override
  String seatManagementSaveAsOpponentPrompt(String name) {
    return 'Salvar \"$name\" como oponente?';
  }

  @override
  String seatManagementOpponentSavedSuccess(String name) {
    return 'Oponente \"$name\" salvo com sucesso!';
  }

  @override
  String seatManagementFailedToSaveOpponent(String error) {
    return 'Falha ao salvar oponente: $error';
  }

  @override
  String get seatManagementStartSession => 'Iniciar Sessao';

  @override
  String get seatManagementSaveChanges => 'Salvar Alteracoes';

  @override
  String get seatManagementSelectYourSeat => 'Por favor, selecione seu assento';

  @override
  String get inviteMemberTitle => 'Convidar Membro';

  @override
  String get inviteMemberEmailLabel => 'ENDERECO DE E-MAIL';

  @override
  String get inviteMemberEmailHint => 'Insira o endereco de e-mail';

  @override
  String get inviteMemberEmailRequired =>
      'Por favor, insira um endereco de e-mail';

  @override
  String get inviteMemberEmailInvalid =>
      'Por favor, insira um endereco de e-mail valido';

  @override
  String get inviteMemberRoleLabel => 'CARGO';

  @override
  String get inviteMemberRoleDealer => 'Dealer';

  @override
  String get inviteMemberRoleAdmin => 'Admin';

  @override
  String get inviteMemberSendInvite => 'Enviar Convite';

  @override
  String inviteMemberAlreadyMember(String displayName, String clubName) {
    return '$displayName ja e membro de $clubName';
  }

  @override
  String get inviteMemberAddedNotificationTitle =>
      'Voce Foi Adicionado a um Clube!';

  @override
  String inviteMemberAddedNotificationBody(
      String inviterName, String clubName, String role) {
    return '$inviterName adicionou voce ao \"$clubName\" como $role.';
  }

  @override
  String get inviteMemberAddedSuccessTitle => 'Membro Adicionado!';

  @override
  String inviteMemberAddedSuccessMessage(
      String displayName, String clubName, String role) {
    return '$displayName foi adicionado ao $clubName como $role.';
  }

  @override
  String get inviteMemberInvitationSentTitle => 'Convite Enviado!';

  @override
  String inviteMemberInvitationSentMessage(String email, String clubName) {
    return 'Um e-mail de convite foi enviado para $email. Quando eles se registrarem, poderao entrar no $clubName.';
  }

  @override
  String inviteMemberError(String error) {
    return 'Erro: $error';
  }

  @override
  String get inviteMemberRoleAnAdmin => 'um admin';

  @override
  String get inviteMemberRoleADealer => 'um dealer';

  @override
  String get registerClubTitle => 'Registrar Clube';

  @override
  String get registerClubNameLabel => 'Nome do Clube';

  @override
  String get registerClubNamePlaceholder => 'ex., Clube de Poker Ases da Sorte';

  @override
  String get registerClubNameRequired => 'Por favor, insira o nome do clube';

  @override
  String get registerClubAddressLabel => 'Endereco';

  @override
  String get registerClubAddressPlaceholder =>
      'ex., Rua Principal, 123, Cidade, Pais';

  @override
  String get registerClubAddressRequired =>
      'Por favor, insira o endereco do clube';

  @override
  String get registerClubPhoneLabel => 'Numero de Telefone';

  @override
  String get registerClubPhonePlaceholder => 'ex., +55 11 99999-9999';

  @override
  String get registerClubPhoneRequired =>
      'Por favor, insira um numero de telefone';

  @override
  String get registerClubAdminEmailLabel => 'E-mail do Admin do Clube';

  @override
  String get registerClubAdminEmailPlaceholder => 'ex., admin@meuclube.com';

  @override
  String get registerClubAdminEmailRequired =>
      'Por favor, insira o e-mail do admin';

  @override
  String get registerClubAdminEmailInvalid =>
      'Por favor, insira um e-mail valido';

  @override
  String get registerClubInfoMessage =>
      'Esta pessoa sera notificada quando o clube for aprovado e se tornara o proprietario do clube.';

  @override
  String get registerClubSubmitRequest => 'Enviar Solicitacao';

  @override
  String registerClubFailedToSubmit(String error) {
    return 'Falha ao enviar solicitacao: $error';
  }

  @override
  String get registerClubSuccessTitle => 'Solicitacao Enviada!';

  @override
  String registerClubSuccessMessage(String email) {
    return 'Sua solicitacao de registro de clube foi enviada. Notificaremos voce em $email quando for revisada.';
  }

  @override
  String get registerClubGotIt => 'Entendido';

  @override
  String get loggingModeChooseMode => 'Escolha o Modo';

  @override
  String get loggingModeFullTitle => 'Modo de Registro Completo';

  @override
  String get loggingModeFullSubtitle => 'Rastreamento Completo de Sessao';

  @override
  String get loggingModeFullFeature1 =>
      'Rastreamento de sessao com multiplas maos';

  @override
  String get loggingModeFullFeature2 => 'Estatisticas em tempo real';

  @override
  String get loggingModeFullFeature3 => 'Historico detalhado de maos';

  @override
  String get loggingModeFullFeature4 => 'Analise de sessao';

  @override
  String get loggingModeIndividualTitle => 'Modo de Sessão Rápida';

  @override
  String get loggingModeIndividualSubtitle => 'Rastreamento de mao individual';

  @override
  String get loggingModeIndividualFeature1 => 'Foco em uma mao';

  @override
  String get loggingModeIndividualFeature2 => 'Registro rapido';

  @override
  String get loggingModeIndividualFeature3 => 'Analise de mao';

  @override
  String get loggingModeIndividualFeature4 => 'Resultados instantaneos';

  @override
  String get loggingModeFeatures => 'Recursos';

  @override
  String get loggingModeStart => 'Iniciar';

  @override
  String get earningsChartAllTimeEarnings => 'Ganhos Totais';

  @override
  String earningsChartSinceDate(String date) {
    return 'Desde $date';
  }

  @override
  String get earningsChartTournament => 'Tournament';

  @override
  String get earningsChartCash => 'Cash';

  @override
  String get earningsChartNoData => 'Nenhum dado de ganhos ainda';

  @override
  String get earningsChartNoDataSubtitle =>
      'Complete algumas sessoes para ver seu grafico de ganhos';

  @override
  String get earningsChartMtt => 'MTT';

  @override
  String get opponentHandsTitle => 'Historico de Maos';

  @override
  String opponentHandsCount(int count) {
    return '$count maos';
  }

  @override
  String get opponentHandsLoading => 'Carregando historico de maos...';

  @override
  String get opponentHandsError => 'Algo deu errado';

  @override
  String get opponentHandsRetry => 'Tentar novamente';

  @override
  String get opponentHandsNoHandsTitle => 'Nenhuma Mao Encontrada';

  @override
  String opponentHandsNoHandsSubtitle(String name) {
    return 'Voce ainda nao jogou nenhuma mao\ncom $name.';
  }

  @override
  String get opponentHandsOppWon => 'OPP GANHOU';

  @override
  String get opponentHandsYou => 'Voce';

  @override
  String opponentHandsPot(String amount) {
    return 'Pot $amount';
  }

  @override
  String get opponentHandsUnknownSession => 'Sessao Desconhecida';

  @override
  String get clubDashboardLive => 'Ao Vivo';

  @override
  String get clubDashboardUpcoming => 'Proximos';

  @override
  String get clubDashboardPast => 'Anteriores';

  @override
  String get clubDashboardNoLiveEvents => 'Nenhum evento ao vivo';

  @override
  String get clubDashboardNoUpcomingEvents => 'Nenhum evento proximo';

  @override
  String get clubDashboardNoPastEvents => 'Nenhum evento passado';

  @override
  String get clubDashboardAdmin => 'Admin';

  @override
  String get clubDashboardCreateEventHint =>
      'Toque no botao abaixo para criar um';

  @override
  String get clubDashboardCheckBackLater =>
      'Volte mais tarde para novos eventos';

  @override
  String get clubDashboardEventsWillAppear =>
      'Eventos aparecerão aqui quando comecarem';

  @override
  String get clubDashboardPastEventsWillAppear =>
      'Eventos concluidos aparecerão aqui';

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
    return '$count jogando';
  }

  @override
  String clubDashboardMemberCount(int count) {
    return '$count membros';
  }

  @override
  String get clubSettingsTitle => 'Configuracoes do Clube';

  @override
  String get clubSettingsClubInfo => 'Informacoes do Clube';

  @override
  String get clubSettingsClubName => 'Nome do Clube';

  @override
  String get clubSettingsAddress => 'Endereco';

  @override
  String get clubSettingsPhone => 'Telefone';

  @override
  String get clubSettingsDescription => 'Descricao';

  @override
  String get clubSettingsSaveChanges => 'Salvar Alteracoes';

  @override
  String get clubSettingsInfoSaved => 'Informacoes do clube salvas';

  @override
  String clubSettingsErrorSaving(String error) {
    return 'Erro ao salvar: $error';
  }

  @override
  String get clubSettingsNoTablesYet => 'Nenhuma mesa ainda';

  @override
  String get clubSettingsAddTableHint => 'Adicione uma mesa para comecar';

  @override
  String clubSettingsErrorLoading(String error) {
    return 'Erro ao carregar dados: $error';
  }

  @override
  String get eventEditTitle => 'Editar Evento';

  @override
  String get eventNewTitle => 'Novo Evento';

  @override
  String get eventNoTablesAssigned => 'Nenhuma Mesa Atribuida';

  @override
  String get eventNoTablesAssignedDesc =>
      'Nenhuma mesa atribuida a este evento. Volte e atribua mesas primeiro.';

  @override
  String get eventGoBack => 'Voltar';

  @override
  String get eventContinue => 'Continuar';

  @override
  String get eventNameOptional => 'Nome do Evento (opcional)';

  @override
  String get eventNameLabel => 'Nome do Evento';

  @override
  String get eventStakesHint => 'Stakes (ex. 1/2)';

  @override
  String get eventBuyInAmount => 'Valor do Buy-in';

  @override
  String get eventMinBuyIn => 'Buy-in Minimo (\$)';

  @override
  String get eventStartingStack => 'Stack inicial';

  @override
  String get eventGameType => 'Tipo de Jogo';

  @override
  String get eventTournament => 'Tournament';

  @override
  String get eventCashGame => 'Cash Game';

  @override
  String get eventDateAndTime => 'Data e Hora do Evento';

  @override
  String get eventStarts => 'Inicio';

  @override
  String get eventTables => 'Mesas';

  @override
  String get eventDeselectAll => 'Desmarcar Todas';

  @override
  String get eventSelectAll => 'Selecionar Todas';

  @override
  String get eventAllTablesInUse =>
      'Todas as mesas estao em uso por eventos ativos';

  @override
  String get eventNoTablesConfigured => 'Nenhuma mesa configurada ainda';

  @override
  String get eventDescriptionLabel => 'Descricao';

  @override
  String get eventNotifyMembers => 'Notificar Membros';

  @override
  String get eventNotifyMembersSubtitle =>
      'Enviar notificacao a todos os membros do clube';

  @override
  String get eventDeleteEvent => 'Excluir Evento';

  @override
  String get eventDeleteConfirmTitle => 'Excluir Evento?';

  @override
  String get eventDeleteConfirmBody =>
      'Isso excluira permanentemente este evento e todos os dados associados. Esta acao nao pode ser desfeita.';

  @override
  String eventDeleteFailed(String error) {
    return 'Falha ao excluir evento: $error';
  }

  @override
  String get eventAttendeesTitle => 'Participantes';

  @override
  String eventAttendeesGoing(int count) {
    return 'Confirmados ($count)';
  }

  @override
  String eventAttendeesMaybe(int count) {
    return 'Talvez ($count)';
  }

  @override
  String eventAttendeesNo(int count) {
    return 'Nao ($count)';
  }

  @override
  String get eventAttendeesNoConfirmed => 'Ninguem confirmado ainda';

  @override
  String get eventAttendeesNoMaybes => 'Nenhum talvez';

  @override
  String get eventAttendeesNoDeclines => 'Nenhuma recusa';

  @override
  String get eventDetailLiveNow => 'O evento esta AO VIVO agora!';

  @override
  String get eventDetailEnded => 'O evento terminou';

  @override
  String get eventDetailCancelled => 'O evento foi cancelado';

  @override
  String get eventDetailPaused => 'O evento esta pausado';

  @override
  String get eventDetailStatusUpdated => 'Status do evento atualizado';

  @override
  String get eventDetailRemovedFromCalendar =>
      'Evento removido do seu calendario';

  @override
  String get eventDetailRsvpGoing => 'Confirmado';

  @override
  String get eventDetailRsvpMaybe => 'Talvez';

  @override
  String get eventDetailRsvpCantGo => 'Nao posso ir';

  @override
  String eventDetailRsvpFailed(String error) {
    return 'Falha ao atualizar RSVP: $error';
  }

  @override
  String get eventDetailCantStartTitle => 'Nao e Possivel Iniciar Evento';

  @override
  String get eventDetailCantStartBody =>
      'Nenhuma mesa esta atribuida a este evento. Adicione mesas primeiro.';

  @override
  String get eventDetailStarted => 'Evento iniciado!';

  @override
  String eventDetailStartFailed(String error) {
    return 'Falha ao iniciar evento: $error';
  }

  @override
  String get eventDetailFinishTitle => 'Encerrar Evento?';

  @override
  String get eventDetailCancelTitle => 'Cancelar Evento?';

  @override
  String get eventDetailFinishBody =>
      'Isso encerrara todas as mesas ativas e finalizara as classificacoes.';

  @override
  String get eventDetailCancelBody =>
      'Isso notificara todos os membros e cancelara o evento.';

  @override
  String get eventDetailFinishButton => 'Encerrar Evento';

  @override
  String get eventDetailCancelButton => 'Cancelar Evento';

  @override
  String get eventDetailKeepEvent => 'Manter Evento';

  @override
  String get eventDetailLiveBadge => 'AO VIVO';

  @override
  String get eventDetailCancelledBadge => 'CANCELADO';

  @override
  String get eventDetailCompletedBadge => 'CONCLUIDO';

  @override
  String get eventDetailUpcomingBadge => 'EM BREVE';

  @override
  String get eventDetailLocation => 'Local';

  @override
  String get eventDetailBuyIn => 'Buy-in';

  @override
  String get eventDetailStakes => 'Stakes';

  @override
  String get eventDetailStartingStack => 'Stack Inicial';

  @override
  String get eventDetailAbout => 'SOBRE';

  @override
  String get eventDetailAddedToCalendar =>
      'Evento adicionado ao seu calendario!';

  @override
  String eventDetailCalendarFailed(String error) {
    return 'Falha ao adicionar ao calendario: $error';
  }

  @override
  String get eventManagementEventsTitle => 'Eventos';

  @override
  String get eventManagementNewEvent => 'Novo Evento';

  @override
  String get eventManagementNoEvents => 'Sem Eventos';

  @override
  String get eventManagementNoEventsSubtitle =>
      'Crie um evento para acompanhar rankings ao vivo';

  @override
  String get eventManagementActiveEvents => 'Eventos Ativos';

  @override
  String get eventManagementPastEvents => 'Eventos Anteriores';

  @override
  String eventManagementErrorLoading(String error) {
    return 'Erro ao carregar eventos: $error';
  }

  @override
  String get eventManagementNoTables =>
      'Nenhuma mesa disponivel. Crie mesas primeiro.';

  @override
  String eventManagementCreated(String name) {
    return 'Evento \"$name\" criado';
  }

  @override
  String eventManagementCreateFailed(String error) {
    return 'Falha ao criar evento: $error';
  }

  @override
  String get eventManagementEndEvent => 'Encerrar Evento';

  @override
  String eventManagementEndConfirm(String name) {
    return 'Tem certeza de que deseja encerrar \"$name\"?';
  }

  @override
  String eventManagementEnded(String name) {
    return 'Evento \"$name\" encerrado';
  }

  @override
  String eventManagementEndFailed(String error) {
    return 'Falha ao encerrar evento: $error';
  }

  @override
  String get eventManagementLinkCopied =>
      'Link copiado para a area de transferencia';

  @override
  String get eventManagementShare => 'Compartilhar';

  @override
  String get eventManagementPause => 'Pausar';

  @override
  String get eventManagementResume => 'Retomar';

  @override
  String get eventManagementEnd => 'Encerrar';

  @override
  String get eventManagementCreateEvent => 'Criar Evento';

  @override
  String get eventManagementEventNameHint => 'ex., Tournament de Sexta a Noite';

  @override
  String get eventManagementSelectTables => 'Selecionar Mesas';

  @override
  String eventManagementTableNumber(int number) {
    return 'Mesa $number';
  }

  @override
  String get eventManagementPublicEvent => 'Evento Publico';

  @override
  String get eventManagementPublicSubtitle =>
      'Qualquer pessoa pode ver o placar';

  @override
  String get eventManagementAccessCode => 'Codigo de Acesso (opcional)';

  @override
  String get eventManagementAccessCodeSubtitle =>
      'Para compartilhar com usuarios especificos';

  @override
  String get eventManagementEnterName => 'Por favor, insira o nome do evento';

  @override
  String get eventManagementSelectTable =>
      'Por favor, selecione pelo menos uma mesa';

  @override
  String get eventManagementPublic => 'Publico';

  @override
  String get eventManagementPrivate => 'Privado';

  @override
  String adminEventTablesSummary(int count, int occupied, int open) {
    return '$count mesas • $occupied sentados • $open disponiveis';
  }

  @override
  String get adminEventTablesAddTable => 'Adicionar Mesa';

  @override
  String get adminEventTablesNoTables =>
      'Nenhuma mesa disponivel para adicionar';

  @override
  String adminEventTablesCloseConfirm(String tableName) {
    return 'Fechar $tableName?';
  }

  @override
  String adminEventTablesCloseWithPlayers(int count) {
    return 'Isso movera $count jogador(es) para a lista de espera e removera a mesa deste evento.';
  }

  @override
  String get adminEventTablesCloseEmpty => 'Isso removera a mesa deste evento.';

  @override
  String get adminEventTablesCloseButton => 'Fechar Mesa';

  @override
  String adminEventTablesTableAdded(String tableName) {
    return '$tableName adicionada ao evento';
  }

  @override
  String adminEventTablesClosedWithWaitlist(String tableName, int count) {
    return '$tableName fechada. $count jogador(es) movido(s) para a lista de espera.';
  }

  @override
  String adminEventTablesClosed(String tableName) {
    return '$tableName fechada.';
  }

  @override
  String get adminEventTablesNoWaitlist => 'Ninguem na lista de espera';

  @override
  String adminEventTablesWaitlistCount(int count) {
    return '$count na lista de espera';
  }

  @override
  String adminEventTablesWaitlistNext(String name) {
    return 'Proximo: $name';
  }

  @override
  String get adminEventTablesWaitlist => 'Lista de Espera';

  @override
  String get adminEventTablesNotified => 'Notificado';

  @override
  String get adminEventTablesNotify => 'Notificar';

  @override
  String get adminEventTablesSeat => 'Assento';

  @override
  String adminEventTablesSeatAt(String tableName, int count) {
    return '$tableName ($count disponiveis)';
  }

  @override
  String get adminEventTablesNoEmptySeats => 'Nenhum assento vazio nesta mesa';

  @override
  String adminEventTablesPlayerSeated(String name, String tableName) {
    return '$name sentado na $tableName';
  }

  @override
  String adminEventTablesPlayerNotified(String name) {
    return '$name notificado';
  }

  @override
  String get adminTableSeatPlayer => 'Sentar Jogador';

  @override
  String get adminTableFromWaitlist => 'Da Lista de Espera';

  @override
  String adminTableWaitlistNextIs(String name) {
    return '$name e o proximo';
  }

  @override
  String get adminTableClubMember => 'Membro do Clube';

  @override
  String get adminTableSearchMembers => 'Buscar membros existentes';

  @override
  String get adminTableWalkUpPlayer => 'Jogador Avulso';

  @override
  String get adminTableAddByName => 'Adicionar por nome';

  @override
  String get adminTableSelectMember => 'Selecionar Membro';

  @override
  String get adminTableSearch => 'Buscar...';

  @override
  String get adminTablePlayerName => 'Nome do jogador';

  @override
  String adminTableWaitingForApproval(int seatNumber) {
    return 'Aguardando aprovacao para o assento #$seatNumber';
  }

  @override
  String get adminTableReject => 'Rejeitar';

  @override
  String get adminTableApprove => 'Aprovar';

  @override
  String get adminTableRemove => 'Remover';

  @override
  String adminTableSeatNumber(int seatNumber) {
    return 'Assento #$seatNumber';
  }

  @override
  String get adminTableNoEmptySeats => 'Nenhum assento vazio disponivel';

  @override
  String adminTableSeatPlayerName(String name) {
    return 'Sentar $name';
  }

  @override
  String get adminTableSelectSeat => 'Selecione um assento:';

  @override
  String adminTablePlayerSeated(String name) {
    return '$name sentado';
  }

  @override
  String adminTableAlreadySeated(String name, String location) {
    return '$name ja esta sentado em $location';
  }

  @override
  String adminTablePlayerApproved(String name) {
    return '$name aprovado';
  }

  @override
  String get adminTablePlayerRejected => 'Jogador rejeitado';

  @override
  String get adminTablePlayerRemoved => 'Jogador removido';

  @override
  String adminTableWaitlistInCount(int count) {
    return '$count na lista de espera';
  }

  @override
  String adminTableWaitlistNextName(String name) {
    return 'Proximo: $name';
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
    return '$count mesas · $occupied sentados · $open disponiveis';
  }

  @override
  String clubCashGameTableNumber(int number) {
    return 'Mesa $number';
  }

  @override
  String get clubCashGameNoTables => 'Nenhuma mesa neste grupo';

  @override
  String clubCashGameFailedToLoad(String error) {
    return 'Falha ao carregar mesas: $error';
  }

  @override
  String get clubCashGameAlreadySeated => 'Voce ja esta sentado em uma mesa';

  @override
  String get clubCashGameSeatAvailable =>
      'Ha um assento disponivel para voce, procure a recepcao';

  @override
  String clubCashGameJoinedWaitlist(int position) {
    return 'Entrou na lista de espera na posicao #$position';
  }

  @override
  String clubCashGameJoinFailed(String error) {
    return 'Falha ao entrar na lista de espera: $error';
  }

  @override
  String get clubCashGameLeftWaitlist => 'Saiu da lista de espera';

  @override
  String clubCashGameLeaveFailed(String error) {
    return 'Falha ao sair da lista de espera: $error';
  }

  @override
  String get clubCashGameViewWaitlist => 'Ver Lista de Espera';

  @override
  String get clubCashGameInWaitlist => 'Na lista de espera';

  @override
  String clubCashGameInWaitlistPosition(int position) {
    return 'Na lista de espera · #$position';
  }

  @override
  String get clubCashGameJoinWaitlist => 'Entrar na Lista de Espera';

  @override
  String get clubCashGameLeaveWaitlistConfirm => 'Sair da lista de espera?';

  @override
  String get clubCashGameLosePosition => 'Voce perdera sua posicao atual.';

  @override
  String get clubCashGameKeep => 'Manter';

  @override
  String get clubCashGameLeave => 'Sair';

  @override
  String clubCashGameRefreshFailed(String error) {
    return 'Nao foi possivel atualizar as mesas: $error';
  }

  @override
  String get clubCashGameWaitlistTitle => 'Lista de Espera';

  @override
  String clubCashGameNotified(String name) {
    return '$name foi notificado';
  }

  @override
  String clubCashGameNotifyFailed(String error) {
    return 'Falha ao notificar: $error';
  }

  @override
  String get clubCashGameCouldNotLoad =>
      'Nao foi possivel carregar a lista de espera';

  @override
  String get clubCashGameNoOneOnWaitlist => 'Ninguem na lista de espera';

  @override
  String get clubCashGamePlayer => 'Jogador';

  @override
  String clubCashGameNotifiedStatus(String time) {
    return 'Notificado • $time';
  }

  @override
  String clubCashGameJoinedTime(String time) {
    return 'Entrou $time';
  }

  @override
  String get clubCashGameJustNow => 'agora';

  @override
  String clubCashGameMinutesAgo(int count) {
    return '${count}min atras';
  }

  @override
  String clubCashGameHoursAgo(int count) {
    return '${count}h atras';
  }

  @override
  String clubCashGameDaysAgo(int count) {
    return '${count}d atras';
  }

  @override
  String get clubCashGameAddTable => 'Adicionar Mesa';

  @override
  String get clubCashGameNewTableName => 'Nome da nova mesa (opcional)';

  @override
  String get clubCashGameAdd => 'Adicionar';

  @override
  String clubCashGameAddedToGroup(String tableName) {
    return '$tableName adicionada ao grupo';
  }

  @override
  String clubCashGameAddFailed(String error) {
    return 'Falha ao adicionar mesa: $error';
  }

  @override
  String clubCashGameAttachFailed(String error) {
    return 'Falha ao anexar mesa: $error';
  }

  @override
  String get clubCashGameAvailableTables => 'Mesas disponiveis';

  @override
  String get clubCashGameInUseByOther => 'Em uso por outros eventos';

  @override
  String get clubCashGameNoOtherTables =>
      'Nenhuma outra mesa neste clube ainda';

  @override
  String clubCashGameInUseBy(String eventName) {
    return 'Em uso por $eventName';
  }

  @override
  String clubCashGameSeats(int count) {
    return '$count Assentos';
  }

  @override
  String memberEventTablesSummary(int count, int occupied, int open) {
    return '$count mesas • $occupied sentados • $open disponiveis';
  }

  @override
  String memberEventJoinedWaitlist(int position) {
    return 'Entrou na lista de espera na posicao #$position';
  }

  @override
  String memberEventJoinFailed(String error) {
    return 'Falha ao entrar na lista de espera: $error';
  }

  @override
  String get memberEventLeftWaitlist => 'Saiu da lista de espera';

  @override
  String memberEventLeaveFailed(String error) {
    return 'Falha ao sair da lista de espera: $error';
  }

  @override
  String memberEventWaitlistPosition(int position) {
    return 'Posicao #$position na lista de espera';
  }

  @override
  String memberEventTotalWaiting(int count) {
    return '$count no total esperando';
  }

  @override
  String get memberEventLeaveWaitlist => 'Sair da Lista de Espera';

  @override
  String memberEventJoinWaitlistWithCount(int count) {
    return 'Entrar na Lista de Espera ($count esperando)';
  }

  @override
  String get memberEventJoinWaitlist => 'Entrar na Lista de Espera';

  @override
  String get memberEventAllTablesFull => 'Todas as mesas estao cheias';

  @override
  String get dealerHomeTitle => 'Modo Dealer';

  @override
  String get dealerHomeNoClubs => 'Nenhum Clube Encontrado';

  @override
  String get dealerHomeNoClubsOwnerHint =>
      'Crie seu primeiro clube para comecar.';

  @override
  String get dealerHomeNoClubsMemberHint =>
      'Voce ainda nao e membro de nenhum clube.\nPeca a um proprietario de clube para convida-lo.';

  @override
  String get dealerHomeCreateClub => 'Criar Clube';

  @override
  String get dealerHomeDealer => 'Dealer';

  @override
  String dealerHomeClubCount(int count) {
    return '$count clubes';
  }

  @override
  String get dealerHomeActiveSessions => 'Sessoes Ativas';

  @override
  String get dealerHomeClubs => 'Clubes';

  @override
  String get dealerHomeTables => 'Mesas';

  @override
  String get dealerHomeAddTable => 'Adicionar Mesa';

  @override
  String get dealerHomeTableNameLabel => 'Nome da Mesa';

  @override
  String get dealerHomeTableNameHint => 'ex., Mesa 1, Mesa Principal';

  @override
  String dealerHomeTableAdded(String name, String clubName) {
    return 'Mesa \"$name\" adicionada ao $clubName!';
  }

  @override
  String dealerHomeAddTableFailed(String error) {
    return 'Falha ao adicionar mesa: $error';
  }

  @override
  String get dealerHomeClubName => 'Nome do Clube';

  @override
  String get dealerHomeCreate => 'Criar';

  @override
  String dealerHomeClubCreated(String name) {
    return 'Clube \"$name\" criado com sucesso!';
  }

  @override
  String dealerHomeClubCreateFailed(String error) {
    return 'Falha ao criar clube: $error';
  }

  @override
  String get dealerHomeNoTables => 'Nenhuma mesa neste clube';

  @override
  String dealerHomeActiveHand(int number) {
    return 'Ativo - Mao #$number';
  }

  @override
  String get dealerHomeInactive => 'Inativo';

  @override
  String get dealerHomeResume => 'Retomar';

  @override
  String get dealerHomeStart => 'Iniciar';

  @override
  String get dealerHomeSessionSettings => 'Configuracoes da Sessao';

  @override
  String get dealerHomeSmallBlind => 'Small Blind';

  @override
  String get dealerHomeBigBlind => 'Big Blind';

  @override
  String get dealerHomeBBAnte => 'BB Ante';

  @override
  String get dealerHomeGameType => 'Tipo de Jogo';

  @override
  String get dealerHomeCash => 'Cash';

  @override
  String get dealerHomeTournament => 'Tournament';

  @override
  String get dealerHomeButtonPosition => 'Posicao do Botao';

  @override
  String get dealerHomeStartSession => 'Iniciar Sessao';

  @override
  String get dealerHomeCouldNotFind =>
      'Nao foi possivel encontrar o clube ou mesa';

  @override
  String dealerHomeStartFailed(String error) {
    return 'Falha ao iniciar sessao: $error';
  }

  @override
  String dealerHomeErrorLoading(String error) {
    return 'Erro ao carregar dados: $error';
  }

  @override
  String dealerHomeTableCount(int count) {
    return '$count mesas';
  }

  @override
  String dealerTableFailedStartHand(String error) {
    return 'Falha ao iniciar mao: $error';
  }

  @override
  String dealerTableChopSummary(String winners, String amount) {
    return 'Chop: $winners dividem $amount';
  }

  @override
  String dealerTableWins(String name, String amount) {
    return '$name ganha $amount';
  }

  @override
  String dealerTablePotChopped(String names) {
    return 'Pot dividido entre $names';
  }

  @override
  String dealerTableFailedCompleteHand(String error) {
    return 'Falha ao completar mao: $error';
  }

  @override
  String dealerTablePlayerBusted(String name) {
    return '$name Eliminado!';
  }

  @override
  String dealerTableNoChipsRemaining(int seatNumber, String amount) {
    return 'Assento $seatNumber nao tem mais fichas.\nValor do rebuy: $amount';
  }

  @override
  String get dealerTableRemovePlayer => 'Remover Jogador';

  @override
  String get dealerTableRebuy => 'Rebuy';

  @override
  String dealerTableRebuysFor(String name, String amount) {
    return '$name faz rebuy de $amount';
  }

  @override
  String dealerTableFinishesIn(String name, String position) {
    return '$name termina em ${position}o lugar';
  }

  @override
  String get dealerTableEndSessionTitle => 'Encerrar Sessao?';

  @override
  String get dealerTableEndSessionBody =>
      'Tem certeza de que deseja encerrar esta sessao?';

  @override
  String get dealerTableEnd => 'Encerrar';

  @override
  String get dealerTableDealerChange => 'Troca de Dealer';

  @override
  String get dealerTableDealerChangeBody =>
      'A sessao sera pausada e outro dealer pode escanear o codigo QR da mesa para continuar de onde parou.';

  @override
  String get dealerTableDealerChangePreserve =>
      'Todos os jogadores, blinds e estado do jogo serao preservados.';

  @override
  String get dealerTableDealerChangeResume =>
      'Voce tambem pode retomar esta sessao depois.';

  @override
  String get dealerTableHandOff => 'Passar';

  @override
  String get dealerTableSessionPaused =>
      'Sessao pausada. Outro dealer pode assumir agora.';

  @override
  String dealerTablePauseFailed(String error) {
    return 'Falha ao pausar sessao: $error';
  }

  @override
  String get dealerTableEventCancelled => 'Evento Cancelado';

  @override
  String get dealerTableEventFinished => 'Evento Encerrado';

  @override
  String get dealerTableEventCancelledBody =>
      'O admin do clube cancelou este evento. Todas as sessoes foram salvas.';

  @override
  String get dealerTableEventFinishedBody =>
      'O admin do clube encerrou este evento. Todas as sessoes foram salvas.';

  @override
  String get dealerTableSessionEnded => 'Sessao Encerrada';

  @override
  String get dealerTableSessionEndedBody =>
      'Esta sessao foi encerrada. Todos os dados foram salvos.';

  @override
  String get dealerTableLeaveTitle => 'Sair da mesa de dealer?';

  @override
  String get dealerTableLeaveActiveHand =>
      'Uma mao esta em andamento. Sair agora pode interromper o registro.';

  @override
  String get dealerTableLeaveInactive =>
      'A sessao permanece ativa. Voce pode voltar a qualquer momento.';

  @override
  String dealerTableAutoCorrection(String detected, String corrected) {
    return 'Auto-corrigido \"$detected\" → \"$corrected\"';
  }

  @override
  String dealerTableApprovePlayer(String name) {
    return 'Aprovar $name?';
  }

  @override
  String get dealerTableStartingChipStack => 'Stack Inicial de Fichas';

  @override
  String dealerTablePlayerRejected(String name) {
    return '$name rejeitado';
  }

  @override
  String dealerTableRejectFailed(String error) {
    return 'Falha ao rejeitar: $error';
  }

  @override
  String dealerTablePlayerJoined(String name, String amount) {
    return '$name entrou com $amount';
  }

  @override
  String dealerTableApproveFailed(String error) {
    return 'Falha ao aprovar: $error';
  }

  @override
  String get dealerTableChipStack => 'Stack de Fichas';

  @override
  String get dealerTableSave => 'Salvar';

  @override
  String get liveSessionHand => 'MAO';

  @override
  String get liveSessionPot => 'POT';

  @override
  String get liveSessionStatus => 'STATUS';

  @override
  String get liveSessionLive => 'AO VIVO';

  @override
  String get liveSessionWaiting => 'AGUARDANDO';

  @override
  String liveSessionWinnerSummary(String winner, String amount) {
    return '$winner ganha \$$amount';
  }

  @override
  String get liveSessionSessionEnded => 'Sessao Encerrada';

  @override
  String get liveSessionSessionEndedBody => 'O dealer encerrou esta sessao.';

  @override
  String get liveSessionLeaveTitle => 'Sair da Mesa?';

  @override
  String get liveSessionLeaveBody =>
      'Tem certeza de que deseja sair desta mesa?';

  @override
  String get liveSessionLeave => 'Sair';

  @override
  String liveSessionLeaveFailed(String error) {
    return 'Falha ao sair: $error';
  }

  @override
  String get liveSessionLeaveTooltip => 'Sair da Mesa';

  @override
  String liveSessionSeat(int number) {
    return 'Assento $number';
  }

  @override
  String get liveSessionYourSeat => 'Seu Assento';

  @override
  String liveSessionStack(String amount) {
    return 'Stack: $amount';
  }

  @override
  String get liveSessionWaitingForDealer => 'Aguardando o dealer...';

  @override
  String get liveSessionOffline => 'OFFLINE';

  @override
  String get liveSessionRecentActions => 'Acoes Recentes';

  @override
  String get liveSessionWaitingForAction => 'Aguardando acao...';

  @override
  String get liveSessionD => 'D';

  @override
  String get qrScanTitle => 'Escanear QR da Mesa';

  @override
  String get qrScanInvalidCode =>
      'Codigo QR invalido. Por favor, escaneie um codigo QR de mesa de poker valido.';

  @override
  String qrScanError(String error) {
    return 'Erro ao processar codigo QR: $error';
  }

  @override
  String get qrScanInstructions =>
      'Aponte sua camera para o codigo QR na mesa para participar';

  @override
  String get clubRequestsTitle => 'Solicitacoes de Clube';

  @override
  String get clubRequestsAll => 'Todas';

  @override
  String get clubRequestsPending => 'Pendentes';

  @override
  String get clubRequestsApproved => 'Aprovadas';

  @override
  String get clubRequestsRejected => 'Rejeitadas';

  @override
  String get clubRequestsApproveTitle => 'Aprovar Solicitacao';

  @override
  String clubRequestsApproveBody(String name) {
    return 'Tem certeza de que deseja aprovar \"$name\"? Isso criara um novo clube e adicionara voce como admin.';
  }

  @override
  String get clubRequestsRejectTitle => 'Rejeitar Solicitacao';

  @override
  String clubRequestsRejectBody(String name) {
    return 'Por favor, forneca um motivo para rejeitar \"$name\":';
  }

  @override
  String get clubRequestsRejectHint => 'Motivo da rejeicao...';

  @override
  String get clubRequestsApproveButton => 'Aprovar';

  @override
  String get clubRequestsRejectButton => 'Rejeitar';

  @override
  String clubRequestsApproved2(String name) {
    return '$name foi aprovado!';
  }

  @override
  String clubRequestsRejected2(String name) {
    return '$name foi rejeitado.';
  }

  @override
  String get clubRequestsNoRequests => 'Sem solicitacoes';

  @override
  String get clubRequestsPendingBadge => 'PENDENTE';

  @override
  String get clubRequestsApprovedBadge => 'APROVADO';

  @override
  String get clubRequestsRejectedBadge => 'REJEITADO';

  @override
  String get clubRequestsAddress => 'Endereco';

  @override
  String get clubRequestsPhone => 'Telefone';

  @override
  String get clubRequestsAdminEmail => 'E-mail do Admin';

  @override
  String get clubRequestsRequestedBy => 'Solicitado Por';

  @override
  String get clubRequestsRequesterEmail => 'E-mail do Solicitante';

  @override
  String get clubRequestsRequestedAt => 'Solicitado Em';

  @override
  String get clubRequestsReviewedAt => 'Revisado Em';

  @override
  String get clubRequestsRejectionReason => 'Motivo da Rejeicao:';

  @override
  String get supportRequestsTitle => 'Solicitacoes de Suporte';

  @override
  String get supportRequestsAll => 'Todas';

  @override
  String get supportRequestsPending => 'Pendentes';

  @override
  String get supportRequestsClosed => 'Fechadas';

  @override
  String get supportRequestsResolveTitle => 'Resolver Solicitacao';

  @override
  String get supportRequestsResolveBody => 'Resposta opcional ao usuario:';

  @override
  String get supportRequestsResponseHint => 'Resposta (opcional)...';

  @override
  String get supportRequestsResolve => 'Resolver';

  @override
  String get supportRequestsResolved => 'Solicitacao resolvida';

  @override
  String get supportRequestsRejectTitle => 'Rejeitar Solicitacao';

  @override
  String get supportRequestsRejectBody => 'Motivo da rejeicao:';

  @override
  String get supportRequestsRejectHint => 'Motivo...';

  @override
  String get supportRequestsReject => 'Rejeitar';

  @override
  String get supportRequestsRejected => 'Solicitacao rejeitada';

  @override
  String get supportRequestsNoRequests => 'Sem solicitacoes';

  @override
  String get supportRequestsPendingBadge => 'PENDENTE';

  @override
  String get supportRequestsResolvedBadge => 'RESOLVIDO';

  @override
  String get supportRequestsRejectedBadge => 'REJEITADO';

  @override
  String get supportRequestsCategory => 'Categoria';

  @override
  String get supportRequestsUser => 'Usuario';

  @override
  String get supportRequestsEmail => 'E-mail';

  @override
  String get supportRequestsSubmitted => 'Enviado';

  @override
  String get supportRequestsDescription => 'Descricao';

  @override
  String get supportRequestsAdminResponse => 'Resposta do Admin';

  @override
  String get supportRequestsBugReport => 'Relatorio de Bug';

  @override
  String get supportRequestsFeatureRequest => 'Solicitacao de Recurso';

  @override
  String get supportRequestsAccountIssue => 'Problema com Conta';

  @override
  String get debugHandViewerTitle => 'Visualizador de Maos (Debug)';

  @override
  String get debugHandViewerSessionName => 'Nome da Sessao';

  @override
  String get debugHandViewerHandNumbers =>
      'Numeros das Maos (separados por virgula, ex., 27,28)';

  @override
  String get debugHandViewerFetchData => 'Buscar Dados';

  @override
  String get debugHandViewerCopied => 'Copiado para a area de transferencia';

  @override
  String get debugHandViewerNoData =>
      'Sem dados ainda. Insira o nome da sessao e clique em Buscar Dados.';

  @override
  String get navDrawerSettings => 'Configurações';

  @override
  String get navDrawerRegisterClub => 'Registrar clube';

  @override
  String get navDrawerHelpSupport => 'Ajuda e suporte';

  @override
  String get navDrawerLogOut => 'Sair';

  @override
  String get navDrawerUpgrade => 'Fazer upgrade';

  @override
  String get navDrawerUserFallback => 'Usuário';

  @override
  String get navDrawerStatistics => 'Estatísticas';

  @override
  String get navDrawerEvents => 'Eventos';

  @override
  String get navDrawerBankroll => 'Bankroll';

  @override
  String get navDrawerClubs => 'Clubes';

  @override
  String get navDrawerNoClubsYet => 'Nenhum clube ainda';

  @override
  String navDrawerMemberCount(int count) {
    return '$count membros';
  }

  @override
  String get navDrawerRoleAdmin => 'Admin';

  @override
  String get navDrawerRoleDealer => 'Dealer';

  @override
  String get navDrawerRoleMember => 'Membro';

  @override
  String get navDrawerVersion => 'Versão 1.0.0';

  @override
  String get navDrawerLastLoginToday => 'Último login: Hoje';

  @override
  String get navDrawerNoEarningsTitle => 'Sem dados de ganhos ainda';

  @override
  String get navDrawerNoEarningsBody =>
      'Adicione resultados de sessão primeiro para ver seu gráfico de ganhos. Você pode adicionar resultados na página de Perfil.';

  @override
  String get navDrawerSignOutTitle => 'Sair';

  @override
  String get navDrawerSignOutMessage => 'Tem certeza de que deseja sair?';

  @override
  String get navDrawerSignOut => 'Sair';

  @override
  String get multiPotMainPot => 'Main Pot';

  @override
  String multiPotSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String multiPotPlayerFallback(String id) {
    return 'Jogador $id';
  }

  @override
  String get multiPotMainPotWinner => 'vencedor do Main Pot';

  @override
  String get multiPotEligibleFromPrevious => 'elegível do pot anterior';

  @override
  String multiPotAutoAwarded(String name, String reason) {
    return 'Atribuído automaticamente a $name ($reason)';
  }

  @override
  String get multiPotChoppedPot => 'Chopped Pot';

  @override
  String get multiPotSingleWinner => 'Vencedor único';

  @override
  String get multiPotSelectAllWinners => 'Selecione todos os vencedores:';

  @override
  String get multiPotSelectTheWinner => 'Selecione o vencedor:';

  @override
  String get multiPotSelectWinnersTitle => 'Selecionar vencedores';

  @override
  String get multiPotMultiplePots =>
      'Múltiplos pots — selecione o vencedor de cada pot';

  @override
  String get winnerSelectionWhoChopped => 'Quem choppou este pot?';

  @override
  String get winnerSelectionWhoWon => 'Quem ganhou esta mão?';

  @override
  String get winnerSelectionChoppedPot => 'Chopped Pot';

  @override
  String get winnerSelectionIndividualShares => 'Partes individuais:';

  @override
  String get winnerSelectionSelectAllWinners =>
      'Selecione todos os vencedores:';

  @override
  String get winnerSelectionTapTheWinner => 'Toque no vencedor:';

  @override
  String get winnerSelectionLongPressHint =>
      'Pressione e segure para Chopped Pot';

  @override
  String get winnerSelectionConfirmChop => 'Confirmar Chop';

  @override
  String get winnerSelectionBackToSingle => 'Voltar para vencedor único';

  @override
  String get boardCardsCards => 'Cartas';

  @override
  String get boardCardsCard => 'Carta';

  @override
  String get allInBoardTitle => 'Cartas do board All-in';

  @override
  String get raiseSnapReleaseToType => 'Solte no mín para digitar';

  @override
  String get slidingNotificationHeader => 'NOTIFICAÇÃO';

  @override
  String get eventSuccessTitle => 'Pronto! Seu evento está no calendário.';

  @override
  String get eventSuccessSubtitle =>
      'Você pode editar ou remover a qualquer momento';

  @override
  String get eventSuccessGoToCalendar => 'Ir ao calendário';

  @override
  String get eventSuccessAddAnother => 'Adicionar outro evento';

  @override
  String get stackChartNoData => 'Sem dados ainda';

  @override
  String get stackChartStart => 'Início';

  @override
  String get stackChartRebuy => 'Rebuy';

  @override
  String get stackChartEnd => 'Fim';

  @override
  String get stackChartTitle => 'Gráfico de Stack';

  @override
  String get stackChartAvgGrowth => 'Cresc. médio';

  @override
  String get stackChartDuration => 'Duração';

  @override
  String get stackChartProfitLoss => 'L/P';

  @override
  String get actionGridSelectAction => 'Selecionar ação';

  @override
  String get pokerTablePlayerFallback => 'Jogador';

  @override
  String get loadingDefault => 'Carregando...';

  @override
  String get forgotPasswordFailedSendCode =>
      'Falha ao enviar o código. Tente novamente.';

  @override
  String get forgotPasswordNewCodeSent =>
      'Novo código enviado para seu e-mail.';

  @override
  String get forgotPasswordFailedResend => 'Falha ao reenviar o código.';

  @override
  String get forgotPasswordEnterFullCode =>
      'Por favor, insira o código completo de 6 dígitos.';

  @override
  String get forgotPasswordInvalidCode =>
      'Código inválido ou expirado. Tente novamente.';

  @override
  String get forgotPasswordResetSuccess =>
      'Senha redefinida com sucesso! Por favor, faça login.';

  @override
  String get forgotPasswordResetTitle => 'Redefinir senha';

  @override
  String get forgotPasswordResetSubtitle =>
      'Insira seu e-mail para receber um código de verificação';

  @override
  String get forgotPasswordCheckEmail => 'Verifique seu e-mail';

  @override
  String get forgotPasswordSetNewPassword => 'Definir nova senha';

  @override
  String get forgotPasswordSetNewSubtitle =>
      'Escolha uma senha forte para sua conta';

  @override
  String get forgotPasswordEmail => 'E-mail';

  @override
  String get forgotPasswordEnterEmail => 'Por favor, insira seu e-mail';

  @override
  String get forgotPasswordValidEmail => 'Por favor, insira um e-mail válido';

  @override
  String get forgotPasswordSendCode => 'Enviar código';

  @override
  String get forgotPasswordVerifyCode => 'Verificar código';

  @override
  String get forgotPasswordResendCode => 'Reenviar código';

  @override
  String forgotPasswordResendIn(String time) {
    return 'Reenviar código em $time';
  }

  @override
  String get forgotPasswordNewPassword => 'Nova senha';

  @override
  String get forgotPasswordEnterPassword => 'Por favor, insira uma senha';

  @override
  String get forgotPasswordMinLength =>
      'A senha deve ter pelo menos 6 caracteres';

  @override
  String get forgotPasswordConfirm => 'Confirmar senha';

  @override
  String get forgotPasswordConfirmRequired => 'Por favor, confirme sua senha';

  @override
  String get forgotPasswordMismatch => 'As senhas não coincidem';

  @override
  String get forgotPasswordResetButton => 'Redefinir senha';

  @override
  String get onboardingTrackTitle => 'REGISTRE CADA\nMÃO';

  @override
  String get onboardingTrackSubtitle =>
      'Registre ações, cartas do board e resultados de cada mão — ao vivo ou após a sessão.';

  @override
  String get onboardingKnowTitle => 'CONHEÇA\nSEU JOGO';

  @override
  String get onboardingKnowSubtitle =>
      'VPIP, PFR, 3-Bet, C-Bet e mais — veja suas stats evoluírem em tempo real.';

  @override
  String get onboardingClubsTitle => 'JOGUE EM\nCLUBES';

  @override
  String get onboardingClubsSubtitle =>
      'Participe de eventos ao vivo, veja rankings e acompanhe seus oponentes entre as sessões.';

  @override
  String get dealerTableEnterStartingStack => 'Digite o Stack inicial';

  @override
  String get dealerTableNoPendingRequests =>
      'Nenhuma solicitação de entrada pendente';

  @override
  String get dealerTablePendingJoinRequests =>
      'Solicitações de entrada pendentes';

  @override
  String get dealerTableUnknown => 'Desconhecido';

  @override
  String dealerTableSeatNumber(int number) {
    return 'Assento $number';
  }

  @override
  String get dealerTableReview => 'Revisar';

  @override
  String get dealerTableSmallBlind => 'Small Blind';

  @override
  String get dealerTableBigBlind => 'Big Blind';

  @override
  String get dealerTableNewBlindsNote =>
      'Os novos blinds serão aplicados a partir da próxima mão.';

  @override
  String get dealerTableSmallMustBeLess =>
      'Small Blind deve ser menor que Big Blind';

  @override
  String get dealerTableBlindsMustBePositive =>
      'Os blinds devem ser maiores que 0';

  @override
  String dealerTableBlindsUpdated(String sb, String bb) {
    return 'Blinds atualizados para $sb/$bb';
  }

  @override
  String dealerTableFailedUpdateBlinds(String error) {
    return 'Falha ao atualizar blinds: $error';
  }

  @override
  String dealerTableFailedMoveButton(String error) {
    return 'Falha ao mover o botão: $error';
  }

  @override
  String get dealerTablePending => 'PENDENTE';

  @override
  String get dealerTableConnectionLost => 'Conexão perdida';

  @override
  String get dealerTableReconnecting => 'Tentando reconectar...';

  @override
  String get dealerTableReconnect => 'Reconectar';

  @override
  String get dealerTableResetHandTitle => 'Reiniciar mão?';

  @override
  String get dealerTableResetHandBody =>
      'Todas as ações foram desfeitas. Deseja iniciar uma nova mão?';

  @override
  String get dealerTableKeepCurrent => 'Manter atual';

  @override
  String get dealerTableNewHand => 'Nova mão';

  @override
  String get dealerTableHandReset => 'Mão reiniciada — pronto para nova mão';

  @override
  String dealerTableAddPlayerToSeat(int number) {
    return 'Adicionar jogador ao assento $number';
  }

  @override
  String get dealerTableSearchUser => 'Buscar usuário';

  @override
  String get dealerTableManualEntry => 'Entrada manual';

  @override
  String get dealerTableSearchByName => 'Buscar por nome';

  @override
  String get dealerTableTypeToSearch => 'Digite para buscar usuários...';

  @override
  String get dealerTableNoUsersFound =>
      'Nenhum usuário encontrado. Tente a entrada manual.';

  @override
  String get dealerTablePlayerNameLabel => 'Nome do jogador';

  @override
  String get dealerTableEnterPlayerName => 'Digite o nome do jogador';

  @override
  String get dealerTableAddPlayer => 'Adicionar jogador';

  @override
  String get dealerTableEndSession => 'Encerrar sessão';

  @override
  String dealerTableUpdatedStack(String name, String amount) {
    return 'Stack de $name atualizado para $amount';
  }

  @override
  String dealerTableFailedUpdateStack(String error) {
    return 'Falha ao atualizar Stack: $error';
  }

  @override
  String dealerTableSittingAtSeat(int number) {
    return 'Você agora está jogando no assento $number';
  }

  @override
  String dealerTableFailedSitAt(String error) {
    return 'Falha ao sentar na mesa: $error';
  }

  @override
  String dealerTableFailedAddPlayer(String error) {
    return 'Falha ao adicionar jogador: $error';
  }

  @override
  String dealerTableFailedRemovePlayer(String error) {
    return 'Falha ao remover jogador: $error';
  }

  @override
  String get eventDetailEventType => 'Tipo de evento';

  @override
  String get eventDetailSeated => 'Sentado';

  @override
  String get eventDetailAreYouGoing => 'VOCÊ VAI?';

  @override
  String get eventDetailAddedToCalendarBtn => 'Adicionado ao calendário';

  @override
  String get eventDetailAddToCalendarBtn => 'Adicionar ao calendário';

  @override
  String get eventDetailWhosGoing => 'Quem vai';

  @override
  String get eventDetailSeeAll => 'Ver tudo';

  @override
  String get eventDetailStartDealing => 'Começar a distribuir';

  @override
  String get eventDetailViewLiveRankings => 'Ver ranking ao vivo';

  @override
  String get eventDetailNotSeatedAtTable =>
      'Você não está sentado em nenhuma mesa no momento';

  @override
  String get eventDetailNotSeatedInEvent =>
      'Você não está sentado neste evento';

  @override
  String eventDetailErrorFindingSeat(String error) {
    return 'Erro ao encontrar seu assento: $error';
  }

  @override
  String get eventDetailReturnToSeat => 'Voltar ao meu assento';

  @override
  String get eventDetailViewFinalStandings => 'Ver classificação final';

  @override
  String get eventDetailManageTables => 'Gerenciar mesas';

  @override
  String get eventDetailManageTable => 'Gerenciar mesa';

  @override
  String get eventDetailSeeAvailability => 'Ver disponibilidade';

  @override
  String get eventDetailYoureSeated => 'Você está sentado';

  @override
  String get eventDetailNoTablesAssigned =>
      'Nenhuma mesa atribuída a este evento';

  @override
  String get eventDetailStartEvent => 'Iniciar evento';

  @override
  String get eventDetailFinish => 'Finalizar';

  @override
  String eventDetailFailedFinishCancel(String action, String error) {
    return 'Falha ao $action evento: $error';
  }

  @override
  String homeTableSeatInfo(String table, String seat) {
    return 'Mesa $table, Assento #$seat';
  }

  @override
  String get homeRequestResolved => 'Solicitação resolvida';

  @override
  String get homeRequestClosed => 'Solicitação encerrada';

  @override
  String get homeResponse => 'Resposta';

  @override
  String homeErrorGeneric(String error) {
    return 'Erro: $error';
  }

  @override
  String homeErrorLoadingEvent(String error) {
    return 'Erro ao carregar evento: $error';
  }

  @override
  String homeFailedLoadEvent(String error) {
    return 'Falha ao carregar evento: $error';
  }

  @override
  String homeFailedUpdateEvent(String error) {
    return 'Falha ao atualizar evento: $error';
  }

  @override
  String homeErrorDeletingEvent(String error) {
    return 'Erro ao excluir evento: $error';
  }

  @override
  String get homeTournament => 'Tournament';

  @override
  String get homeCashGame => 'Cash Game';

  @override
  String commonErrorGeneric(String error) {
    return 'Erro: $error';
  }

  @override
  String get commonLeave => 'Sair';

  @override
  String get commonAccept => 'Aceitar';

  @override
  String get commonLoadingHands => 'Carregando mãos...';

  @override
  String sessionHistoryButtonPosition(String position) {
    return 'Posição do botão: $position';
  }

  @override
  String sessionHistoryPlayerCount(String count) {
    return 'Número de jogadores: $count';
  }

  @override
  String sessionHistoryStartTime(String time) {
    return 'Horário de início: $time';
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
    return 'Falha na sincronização: $error';
  }

  @override
  String sessionHistoryClearFailed(String error) {
    return 'Falha ao limpar sessões: $error';
  }

  @override
  String get notificationsClubNotFound => 'Clube não encontrado';

  @override
  String get notificationsAccept => 'Aceitar';

  @override
  String get notificationsInvitationAccepted => 'Convite aceito';

  @override
  String get notificationsInvitationDeclined => 'Convite recusado';

  @override
  String get notificationsInvitationDeclinedMsg => 'Convite recusado';

  @override
  String get notificationsEventNotFound => 'Evento não encontrado';

  @override
  String notificationsFailedLoadClub(String error) {
    return 'Falha ao carregar clube: $error';
  }

  @override
  String notificationsErrorLoadingEvent(String error) {
    return 'Erro ao carregar evento: $error';
  }

  @override
  String invitationsFailedLoad(String error) {
    return 'Falha ao carregar convites: $error';
  }

  @override
  String invitationsFailedAccept(String error) {
    return 'Falha ao aceitar convite: $error';
  }

  @override
  String get invitationsDeclined => 'Convite recusado';

  @override
  String invitationsFailedDecline(String error) {
    return 'Falha ao recusar convite: $error';
  }

  @override
  String get clubSettingsTableAdded => 'Mesa adicionada';

  @override
  String get clubSettingsTableDeleted => 'Mesa excluída';

  @override
  String get clubSettingsQrRegenerated => 'Códigos QR regenerados';

  @override
  String clubSettingsErrorPdf(String error) {
    return 'Erro ao gerar PDF: $error';
  }

  @override
  String get clubDashboardActiveDealers => 'Dealers ativos';

  @override
  String get clubDashboardPendingInvitations => 'Convites pendentes';

  @override
  String get clubDashboardDealerEmailHint => 'dealer@example.com';

  @override
  String clubDashboardInvitationSent(String email) {
    return 'Convite enviado para $email';
  }

  @override
  String clubDashboardFailedSendInvite(String error) {
    return 'Falha ao enviar convite: $error';
  }

  @override
  String clubDashboardFailedCancelInvite(String error) {
    return 'Falha ao cancelar convite: $error';
  }

  @override
  String eventManagementClubEvents(String name) {
    return 'Eventos de $name';
  }

  @override
  String eventManagementFailedUpdate(String error) {
    return 'Falha ao atualizar evento: $error';
  }

  @override
  String get profileCash => 'Cash';

  @override
  String get profileTournament => 'Tournament';

  @override
  String get profileDevTools => 'Ferramentas de desenvolvimento';

  @override
  String get profilePremiumOverride => 'Forçar Premium';

  @override
  String profileUsingRealStatus(String status) {
    return 'Usando status real: $status';
  }

  @override
  String profileOverridden(String status) {
    return 'Sobrescrito: $status';
  }

  @override
  String get profileResetToReal => 'Redefinir para status real';

  @override
  String get profileVersion => 'Versão 1.0';

  @override
  String profileLastLogin(String date) {
    return 'Último login $date';
  }

  @override
  String pokerHandFailedEndSession(String error) {
    return 'Falha ao encerrar sessão: $error';
  }

  @override
  String pokerHandFailedSaveSession(String error) {
    return 'Falha ao salvar sessão: $error';
  }

  @override
  String pokerHandRebuyAdded(String amount, String stack) {
    return 'Rebuy adicionado: \$$amount (Stack: $stack)';
  }

  @override
  String get pokerHandEndSession => 'Encerrar sessão';

  @override
  String get pokerHandRebuyAmountDollar => 'Valor do Rebuy (\$)';

  @override
  String get pokerHandRebuyChips => 'Fichas de Rebuy';

  @override
  String seatSetupFailedSave(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get seatSetupSelectYourSeat => 'Por favor, selecione seu assento';

  @override
  String get authExpLinkGoogleTitle => 'Vincular conta Google';

  @override
  String get authExpPassword => 'Senha';

  @override
  String get authExpLinkAccount => 'Vincular conta';

  @override
  String get individualSetupSessionNameHint => 'ex. \"Poker de sexta à noite\"';

  @override
  String get individualSetupCashGame => 'Cash Game';

  @override
  String get individualSetupTournament => 'Tournament';

  @override
  String get individualSetupEnterAmount => 'Insira o valor';

  @override
  String get individualSetupEnterChipStack => 'Insira o Stack de fichas';

  @override
  String get individualSetupSmallBlind => 'Small Blind';

  @override
  String get individualSetupBigBlind => 'Big Blind';

  @override
  String get individualSetupEnterValue => 'Insira o valor';

  @override
  String get individualHandSetupNameHint => 'ex. \"AA vs KK Cooler\"';

  @override
  String get individualHandSetupSmallBlind => 'Small Blind';

  @override
  String get individualHandSetupBigBlind => 'Big Blind';

  @override
  String get individualHandSetupPlayers => 'Jogadores';

  @override
  String get individualHandSetupGameType => 'Tipo de jogo';

  @override
  String get playerSessionYourHoleCards => 'Suas Hole Cards';

  @override
  String get playerSessionSeat => 'ASSENTO';

  @override
  String get playerSessionStack => 'STACK';

  @override
  String get playerSessionPot => 'POT';

  @override
  String get playerSessionNotesHint => 'Adicionar notas sobre esta mão...';

  @override
  String get dealerQrScanInvalidCode =>
      'Código QR inválido. Por favor, escaneie um código QR de mesa válido.';

  @override
  String get dealerQrScanWrongClub => 'Esta mesa pertence a outro clube.';

  @override
  String get dealerQrScanTableNotFound =>
      'Mesa não encontrada. Por favor, escaneie um código QR de mesa válido.';

  @override
  String dealerQrScanError(String error) {
    return 'Erro ao processar código QR: $error';
  }

  @override
  String dealerQrScanFailedStart(String error) {
    return 'Falha ao iniciar sessão: $error';
  }

  @override
  String dealerQrScanTakingOver(String name) {
    return 'Assumindo de $name';
  }

  @override
  String get dealerQrScanHandsPlayed => 'Mãos jogadas';

  @override
  String get dealerQrScanBlinds => 'Blinds';

  @override
  String get dealerQrScanPlayers => 'Jogadores';

  @override
  String dealerQrScanFailedResume(String error) {
    return 'Falha ao retomar sessão: $error';
  }

  @override
  String get usernameSetupLabel => 'Nome de usuário';

  @override
  String get stackChartScreenAvgGrowth => 'Cresc. médio';

  @override
  String get stackChartScreenDuration => 'Duração';

  @override
  String get stackChartScreenProfitLoss => 'L/P';

  @override
  String get stackChartScreenStack => 'Stack';

  @override
  String get quickStackSearchHint => 'Buscar ou adicionar jogador...';

  @override
  String get sessionHandsLoading => 'Carregando mãos...';

  @override
  String createEventDefaultCashGame(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get createEventDefaultCashGameNoStakes => 'Cash Game';

  @override
  String get eventDashboardTvMode => 'Modo exibição TV';

  @override
  String get tableSelectionTitle => 'Selecionar mesa';

  @override
  String get tableSelectionAdminSubtitle => 'Escolha uma mesa para gerenciar';

  @override
  String get tableSelectionMemberSubtitle =>
      'Escolha uma mesa para ver a disponibilidade';

  @override
  String get tableSelectionNoTables => 'Nenhuma mesa disponível';

  @override
  String tableSelectionOpenSeats(int count) {
    return '$count disponível(is)';
  }

  @override
  String tableSelectionSeated(int occupied) {
    return '$occupied/9 sentados';
  }

  @override
  String get monthJan => 'Jan';

  @override
  String get monthFeb => 'Fev';

  @override
  String get monthMar => 'Mar';

  @override
  String get monthApr => 'Abr';

  @override
  String get monthMay => 'Mai';

  @override
  String get monthJun => 'Jun';

  @override
  String get monthJul => 'Jul';

  @override
  String get monthAug => 'Ago';

  @override
  String get monthSep => 'Set';

  @override
  String get monthOct => 'Out';

  @override
  String get monthNov => 'Nov';

  @override
  String get monthDec => 'Dez';

  @override
  String get weekdaySun => 'Dom';

  @override
  String get weekdayMon => 'Seg';

  @override
  String get weekdayTue => 'Ter';

  @override
  String get weekdayWed => 'Qua';

  @override
  String get weekdayThu => 'Qui';

  @override
  String get weekdayFri => 'Sex';

  @override
  String get weekdaySat => 'Sáb';

  @override
  String opponentsErrorGeneric(String error) {
    return 'Erro: $error';
  }

  @override
  String opponentsErrorDeleting(String error) {
    return 'Erro ao excluir oponente: $error';
  }

  @override
  String opponentsErrorClearing(String error) {
    return 'Erro ao limpar oponentes: $error';
  }

  @override
  String get onboardingReadTitle => 'LEIA O JOGO\nCOMO UM PRO';

  @override
  String get onboardingReadSubtitle =>
      'Crie uma conta para começar a acompanhar sua jornada no poker.';

  @override
  String get onboardingCreateAccount => 'Criar conta';

  @override
  String get onboardingLogIn => 'Entrar';

  @override
  String get onboardingSkip => 'Pular';

  @override
  String get onboardingFinalTable => 'Final Table';

  @override
  String get authExpSignUpTitle => 'Cadastrar';

  @override
  String get authExpLogInTitle => 'Entre na sua conta';

  @override
  String get authExpSignUpSubtitle => 'Crie uma conta para continuar';

  @override
  String get authExpLogInSubtitle => 'Digite seu email e senha para entrar';

  @override
  String get authExpName => 'Nome';

  @override
  String get authExpEmail => 'Email';

  @override
  String get authExpEnterName => 'Digite seu nome';

  @override
  String get authExpNameMinLength => 'O nome deve ter pelo menos 2 caracteres';

  @override
  String get authExpEnterEmail => 'Digite seu email';

  @override
  String get authExpValidEmail => 'Digite um email válido';

  @override
  String get authExpEnterPassword => 'Digite sua senha';

  @override
  String get authExpPasswordMinLength =>
      'A senha deve ter pelo menos 6 caracteres';

  @override
  String get authExpBySigningUp => 'Ao se cadastrar, você concorda com os ';

  @override
  String get authExpTermsOfService => 'Termos de Serviço';

  @override
  String get authExpAnd => '\ne a ';

  @override
  String get authExpPrivacyPolicy => 'Política de Privacidade';

  @override
  String get authExpCreateAccount => 'Criar conta';

  @override
  String get authExpAlreadyHaveAccount => 'Já tem uma conta? ';

  @override
  String get authExpSignIn => 'Entrar';

  @override
  String get authExpForgotPassword => 'Esqueceu a senha?';

  @override
  String get authExpDontHaveAccount => 'Não tem uma conta? ';

  @override
  String get authExpSignUp => 'Cadastrar';

  @override
  String get authExpOr => 'ou';

  @override
  String get authExpContinueGoogle => 'Continuar com Google';

  @override
  String authExpLinkGoogleMessage(String email) {
    return 'Uma conta com $email já existe. Digite sua senha para vincular sua conta Google.';
  }

  @override
  String forgotPasswordCodeSubtitle(String email) {
    return 'Digite o código de 6 dígitos enviado para $email';
  }

  @override
  String get usernameSetupChangeTitle => 'Altere seu nome de usuário';

  @override
  String get usernameSetupChooseTitle => 'Escolha seu nome de usuário';

  @override
  String get usernameSetupSubtitle =>
      'É assim que outros jogadores vão te conhecer na mesa';

  @override
  String get usernameSetupRequired => 'Nome de usuário é obrigatório';

  @override
  String get usernameSetupCheckingAvailability =>
      'Verificando disponibilidade…';

  @override
  String get usernameSetupAvailable => 'Disponível!';

  @override
  String get usernameSetupAlreadyTaken => 'Já está em uso';

  @override
  String get usernameSetupCurrentUsername => 'Este é seu nome de usuário atual';

  @override
  String get usernameSetupCouldNotCheck =>
      'Não foi possível verificar a disponibilidade';

  @override
  String get usernameSetupJustTaken =>
      'Esse nome acabou de ser usado. Tente outro.';

  @override
  String get usernameSetupRulesHint =>
      '3–20 caracteres · letras, números, underscores';

  @override
  String get usernameSetupUpdateButton => 'Atualizar nome';

  @override
  String get usernameSetupClaimButton => 'Reservar nome';

  @override
  String get usernameSetupSkip => 'Pular por enquanto';

  @override
  String get sessionHandsTitle => 'Sessão';

  @override
  String sessionHandsHandsLogged(int count) {
    return '$count mãos registradas';
  }

  @override
  String get sessionHandsError => 'Erro';

  @override
  String get sessionHandsNoHandsTitle => 'Nenhuma mão registrada';

  @override
  String get sessionHandsNoHandsSubtitle =>
      'Esta sessão ainda não tem mãos registradas.';

  @override
  String get sessionHandsWon => 'GANHOU';

  @override
  String sessionHandsActions(int count) {
    return '$count ações';
  }

  @override
  String get sessionHandsPot => 'Pot';

  @override
  String get stackChartScreenTitle => 'Gráfico de Stack';

  @override
  String get stackChartScreenPokerSession => 'Sessão de poker';

  @override
  String get notificationsScreenTitle => 'Notificações';

  @override
  String get notificationsScreenToday => 'Hoje';

  @override
  String get notificationsScreenMarkAllAsRead => 'Marcar tudo como lido';

  @override
  String get notificationsScreenMarkAsRead => 'Marcar como lido';

  @override
  String get notificationsScreenNoNotifications => 'Sem notificações';

  @override
  String get notificationsScreenClubInvitation => 'Convite para o clube';

  @override
  String get notificationsScreenInvitedToJoin =>
      'Você foi convidado para participar';

  @override
  String get notificationsScreenDecline => 'Recusar';

  @override
  String get notificationsScreenNotAuthenticated => 'Não autenticado';

  @override
  String get notificationsScreenRequestResolved => 'Solicitação resolvida';

  @override
  String get notificationsScreenRequestClosed => 'Solicitação fechada';

  @override
  String get notificationsScreenResponse => 'Resposta';

  @override
  String get notificationsScreenEvents => 'Eventos';

  @override
  String get notificationsScreenRsvp => 'RSVP';

  @override
  String get notificationsScreenClubs => 'Clubes';

  @override
  String get notificationsScreenInvitations => 'Convites';

  @override
  String get notificationsScreenSeats => 'Assentos';

  @override
  String get notificationsScreenSupport => 'Suporte';

  @override
  String notifEventCreatedTitle(String eventName) {
    return 'Novo evento: $eventName';
  }

  @override
  String notifEventCreatedBody(String date) {
    return '$date';
  }

  @override
  String notifEventUpdatedTitle(String eventName) {
    return 'Evento atualizado: $eventName';
  }

  @override
  String notifEventUpdatedBody(String clubName) {
    return '$clubName atualizou os detalhes do evento';
  }

  @override
  String notifEventCancelledTitle(String eventName) {
    return 'Evento cancelado: $eventName';
  }

  @override
  String notifEventCancelledBody(String clubName, String date) {
    return '$clubName cancelou o evento agendado para $date';
  }

  @override
  String notifEventStartingTitle(String eventName) {
    return '$eventName começa em 1 hora!';
  }

  @override
  String notifEventStartingBody(String clubName) {
    return 'O evento do $clubName está prestes a começar';
  }

  @override
  String notifEventStartedTitle(String eventName) {
    return '$eventName está AO VIVO!';
  }

  @override
  String notifEventStartedBody(String clubName) {
    return 'O evento do $clubName começou - entre para assistir';
  }

  @override
  String notifSeatAvailableTitle(String eventName) {
    return 'Lugar disponível: $eventName';
  }

  @override
  String notifSeatAvailableBody(String clubName) {
    return 'Um lugar está disponível em $clubName! Abra o app para garantir o seu.';
  }

  @override
  String notifMemberRsvpTitle(String memberName) {
    return 'RSVP: $memberName';
  }

  @override
  String notifMemberRsvpBody(
      String memberName, String rsvpStatus, String eventName) {
    return '$memberName respondeu \"$rsvpStatus\" para $eventName';
  }

  @override
  String get notifNewClubRequestTitle => 'Nova solicitação de clube';

  @override
  String get notifNewClubRequestBody =>
      'Uma nova solicitação de registro de clube foi enviada';

  @override
  String get notifClubApprovedTitle => 'Clube aprovado';

  @override
  String get notifClubApprovedBody => 'Seu clube foi aprovado!';

  @override
  String get notifClubRejectedTitle => 'Clube rejeitado';

  @override
  String get notifClubRejectedBody => 'Sua solicitação de clube foi rejeitada';

  @override
  String get notifMemberInvitedTitle => 'Convite para clube';

  @override
  String get notifMemberInvitedBody =>
      'Você foi convidado para entrar em um clube';

  @override
  String get notifInvitationAcceptedTitle => 'Convite aceito';

  @override
  String notifInvitationAcceptedBody(String memberName) {
    return '$memberName aceitou o convite';
  }

  @override
  String get notifInvitationDeclinedTitle => 'Convite recusado';

  @override
  String notifInvitationDeclinedBody(String memberName) {
    return '$memberName recusou o convite';
  }

  @override
  String get notifSupportRequestTitle => 'Solicitação de suporte';

  @override
  String get notifSupportRequestBody =>
      'Uma nova solicitação de suporte foi enviada';

  @override
  String get notifSupportUpdatedTitle => 'Atualização de suporte';

  @override
  String get notifSupportUpdatedBody =>
      'Sua solicitação de suporte foi atualizada';

  @override
  String get notifTypeEventCreated => 'Novo evento';

  @override
  String get notifTypeEventUpdated => 'Evento atualizado';

  @override
  String get notifTypeEventCancelled => 'Evento cancelado';

  @override
  String get notifTypeEventStarting => 'Evento em breve';

  @override
  String get notifTypeEventStarted => 'Evento iniciado';

  @override
  String get notifTypeMemberRsvp => 'RSVP de membro';

  @override
  String get notifTypeNewClubRequest => 'Nova solicitação de clube';

  @override
  String get notifTypeClubApproved => 'Clube aprovado';

  @override
  String get notifTypeClubRejected => 'Clube rejeitado';

  @override
  String get notifTypeMemberInvited => 'Convite para clube';

  @override
  String get notifTypeInvitationAccepted => 'Convite aceito';

  @override
  String get notifTypeInvitationDeclined => 'Convite recusado';

  @override
  String get notifTypeSeatAvailable => 'Lugar disponível';

  @override
  String get notifTypeSupportRequest => 'Solicitação de suporte';

  @override
  String get notifTypeSupportUpdated => 'Atualização de suporte';

  @override
  String get invitationsScreenTitle => 'Convites para clubes';

  @override
  String get invitationsScreenNoPending => 'Nenhum convite pendente';

  @override
  String get invitationsScreenYouWillSee => 'Você verá convites de clubes aqui';

  @override
  String get invitationsScreenGoBack => 'Voltar';

  @override
  String get invitationsScreenUnknownClub => 'Clube desconhecido';

  @override
  String invitationsScreenInvitedBy(String name) {
    return 'Convidado por $name';
  }

  @override
  String invitationsScreenExpires(String date) {
    return 'Expira $date';
  }

  @override
  String get invitationsScreenExpired => 'Expirado';

  @override
  String invitationsScreenExpiresInDays(int days) {
    return 'em $days dia(s)';
  }

  @override
  String invitationsScreenExpiresInHours(int hours) {
    return 'em $hours hora(s)';
  }

  @override
  String get invitationsScreenExpiresSoon => 'em breve';

  @override
  String get invitationsScreenDecline => 'Recusar';

  @override
  String get invitationsScreenAccept => 'Aceitar';

  @override
  String invitationsScreenJoinedAs(String clubName, String role) {
    return 'Você entrou em $clubName como $role';
  }

  @override
  String get profilePremium => 'Premium';

  @override
  String get profileFree => 'Grátis';

  @override
  String get dealerTableStartNewHand => 'Nova mão';

  @override
  String get dealerTableStartSessionBtn => 'Iniciar sessão';

  @override
  String get dealerTableNeedTwoPlayers =>
      'Precisa de pelo menos 2 jogadores para começar';

  @override
  String get dealerTableAddTestPlayers => 'Adicionar jogadores de teste';

  @override
  String dealerTableAddedTestPlayers(int count) {
    return '$count jogadores de teste adicionados';
  }

  @override
  String dealerTableRolledBack(String street) {
    return 'Retornado para $street';
  }

  @override
  String dealerTableUndoneAction(String playerName, String action) {
    return 'Desfeito: $playerName $action';
  }

  @override
  String get dealerTableScanToJoin => 'Escaneie para ocupar este assento';

  @override
  String get dealerTableOccupiedDot => 'Ocupado · ';

  @override
  String get dealerTableEmptyLabel => 'Vazio';

  @override
  String get dealerTableOccupiedLabel => 'Ocupado';

  @override
  String get dealerTableSelectedLabel => 'Selecionado';

  @override
  String get dealerTableSelectSeatLabel => 'SELECIONAR ASSENTO';

  @override
  String get dealerTableBetAmountDialog => 'Valor do Bet';

  @override
  String get dealerTableRaiseToDialog => 'Raise para';

  @override
  String get dealerTablePausedLabel => 'Pausado';

  @override
  String get dealerTableListeningLabel => 'Ouvindo';

  @override
  String get dealerTableResumeVoiceTooltip => 'Retomar voz';

  @override
  String get dealerTablePauseVoiceTooltip => 'Pausar voz';

  @override
  String get dealerTableVoiceOffLabel => 'Voz desligada';

  @override
  String get dealerTableCalibratingLabel => 'Calibrando...';

  @override
  String get dealerTableCalibrationPrompt =>
      'Por favor diga: \"Mesa [número], Dealer [nome]\"';

  @override
  String dealerTableDealerLockedMsg(String name, String table) {
    return 'Dealer fixado: $name na mesa $table';
  }

  @override
  String get dealerTableNoSpeakersMsg =>
      'Nenhuma voz detectada — fale com clareza';

  @override
  String get dealerTableSayTableDealerMsg =>
      'Por favor diga: \"Mesa [número], Dealer [nome]\"';

  @override
  String get dealerTableConnectionLostRecovery =>
      'Conexão perdida — tentando recuperar...';

  @override
  String get dealerTableConnectionTimeout =>
      'Tempo de conexão esgotado — recalibração necessária';

  @override
  String get dealerTableConnectionRecovered => 'Conexão recuperada!';

  @override
  String get dealerTableActionHeldMsg => 'Ação retida';

  @override
  String get dealerTableFailedStartStreaming =>
      'Falha ao iniciar streaming — verifique a conexão com o servidor e o microfone';

  @override
  String dealerTableFailedStartVoice(String error) {
    return 'Falha ao iniciar voz: $error';
  }

  @override
  String get dealerTableAddPlayerActionLabel => 'Adicionar jogador';

  @override
  String get dealerTableSeatAnotherPlayer => 'Sentar outro jogador aqui';

  @override
  String get dealerTableSitHereLabel => 'Sentar aqui';

  @override
  String get dealerTableJoinAsDealerPlayer =>
      'Entrar no jogo como Dealer-jogador';

  @override
  String get dealerTableDealerFallback => 'Dealer';

  @override
  String dealerTableUpdatedStackMsg(String name, String amount) {
    return 'Stack de $name atualizado para $amount';
  }

  @override
  String dealerTableFailedUpdateStackMsg(String error) {
    return 'Falha ao atualizar Stack: $error';
  }

  @override
  String dealerTableSittingAtSeatMsg(int number) {
    return 'Você agora está jogando no assento $number';
  }

  @override
  String dealerTableFailedSitMsg(String error) {
    return 'Falha ao sentar na mesa: $error';
  }

  @override
  String dealerTableFailedAddPlayerMsg(String error) {
    return 'Falha ao adicionar jogador: $error';
  }

  @override
  String dealerTableRemovedFromSeat(String name, int seat) {
    return '$name removido do assento $seat';
  }

  @override
  String dealerTableFailedRemoveMsg(String error) {
    return 'Falha ao remover jogador: $error';
  }

  @override
  String get eventDetailDateAndTime => 'Data e hora';

  @override
  String eventDetailTableSeatInfo(String table, int seat) {
    return 'Mesa $table, Assento #$seat';
  }

  @override
  String get eventDetailYoureSeatedGoodLuck => 'Você está sentado, boa sorte!';

  @override
  String get eventDetailHomeGame => 'Jogo em casa';

  @override
  String get clubDashboardDateLabel => 'Data';

  @override
  String get clubDashboardUnknownLabel => 'Desconhecido';

  @override
  String get clubDashboardActiveLabel => 'Ativo';

  @override
  String get clubDashboardIdleLabel => 'Inativo';

  @override
  String clubDashboardInvitedTimeAgo(String time) {
    return 'Convidado $time';
  }

  @override
  String get clubDashboardPendingLabel => 'Pendente';

  @override
  String get clubDashboardNoDealersYet => 'Nenhum Dealer ainda';

  @override
  String get clubDashboardInviteDealersHint =>
      'Convide Dealers para ajudar a gerenciar suas mesas';

  @override
  String get clubDashboardInviteDealer => 'Convidar Dealer';

  @override
  String get clubDashboardInviteDealerBody =>
      'Digite o email do Dealer que você deseja convidar.';

  @override
  String get clubDashboardSendInvitationBtn => 'Enviar convite';

  @override
  String clubDashboardInvitationSentTo(String email) {
    return 'Convite enviado para $email';
  }

  @override
  String clubDashboardFailedSendInvitationMsg(String error) {
    return 'Falha ao enviar convite: $error';
  }

  @override
  String get clubDashboardCancelInvitationTitle => 'Cancelar convite?';

  @override
  String clubDashboardCancelInvitationBody(String email) {
    return 'Cancelar o convite para $email?';
  }

  @override
  String get clubDashboardKeepBtn => 'Manter';

  @override
  String get clubDashboardCancelInvitationBtn => 'Cancelar convite';

  @override
  String clubDashboardFailedCancelMsg(String error) {
    return 'Falha ao cancelar convite: $error';
  }

  @override
  String clubSettingsMembers(int count) {
    return 'Membros ($count)';
  }

  @override
  String get clubSettingsNoMembersFound => 'Nenhum membro encontrado';

  @override
  String get clubSettingsRoleOwner => 'Proprietário';

  @override
  String get clubSettingsRoleAdmin => 'Admin';

  @override
  String get clubSettingsRoleDealer => 'Dealer';

  @override
  String get clubSettingsRolePlayer => 'Jogador';

  @override
  String get clubSettingsTableAddedMsg => 'Mesa adicionada';

  @override
  String get clubSettingsEditTableTitle => 'Editar mesa';

  @override
  String get clubSettingsDeleteTableTitle => 'Excluir mesa?';

  @override
  String clubSettingsDeleteTableBody(String name) {
    return 'Tem certeza de que deseja excluir \"$name\"? Esta ação não pode ser desfeita.';
  }

  @override
  String get clubSettingsTableDeletedMsg => 'Mesa excluída';

  @override
  String get clubSettingsDealerScanHint =>
      'Dealers escaneiam isto para iniciar uma sessão nesta mesa';

  @override
  String get clubSettingsRegenerateBtn => 'Regenerar';

  @override
  String get clubSettingsAppQrCodes => 'Códigos QR do app';

  @override
  String get clubSettingsShareWithPlayers =>
      'Compartilhe com os jogadores para baixar o app';

  @override
  String get clubSettingsDownloadPdf => 'Baixar PDF';

  @override
  String get clubSettingsDownloadFinalTable => 'Baixe o app Final Table';

  @override
  String get clubSettingsScanQrToGetStarted =>
      'Escaneie o código QR do seu dispositivo para começar';

  @override
  String get clubSettingsScanToStartSession =>
      'Escaneie este código QR para iniciar uma sessão';

  @override
  String get clubSettingsForDealersOnly => 'Apenas para Dealers';

  @override
  String clubSettingsTableDefault(int number) {
    return 'Mesa $number';
  }

  @override
  String eventManagementFailedUpdateEvent(String error) {
    return 'Falha ao atualizar evento: $error';
  }

  @override
  String adminTableThisWillMoveMsg(int count) {
    return 'Isto moverá $count jogador(es) para a lista de espera e removerá a mesa deste evento.';
  }

  @override
  String get adminTableThisWillRemoveMsg =>
      'Isto removerá a mesa deste evento.';

  @override
  String adminTableClosedWithWaitlistMsg(String table, int count) {
    return '$table fechada. $count jogador(es) movido(s) para a lista de espera.';
  }

  @override
  String adminTableClosedMsg(String table) {
    return '$table fechada.';
  }

  @override
  String get adminTableEmptyLabel => 'Vazio';

  @override
  String get adminTableTableFallback => 'Mesa';

  @override
  String adminTableTableNumberLabel(int number) {
    return 'Mesa $number';
  }

  @override
  String homePendingInvitationsMsg(int count) {
    return 'Você tem $count convite(s) pendente(s) de clubes.';
  }

  @override
  String get homeEventFallback => 'Evento';

  @override
  String get homePokerFallback => 'Poker';

  @override
  String get homeUserFallback => 'Usuário';

  @override
  String homeSeatInfoStr(int seat, String chipStack) {
    return 'Assento #$seat  •  $chipStack';
  }

  @override
  String get pokerHandYouLabel => 'Você';

  @override
  String pokerHandMovingToTable(int table, String stack) {
    return 'Indo para a mesa $table. Seu Stack ($stack) será transferido. Os outros jogadores serão removidos.';
  }

  @override
  String pokerHandActiveSessionMsg(int count) {
    return 'Você tem uma sessão ativa com $count mão(s) registrada(s). O que deseja fazer?';
  }

  @override
  String get pokerHandUnknownLabel => 'Desconhecido';

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
      'Todos os jogadores All-In — distribuindo cartas restantes';

  @override
  String get pokerHandWaitingForCards => 'Aguardando distribuição das cartas';

  @override
  String get pokerHandBettingComplete =>
      'Apostas concluídas — pronto para a próxima rua';

  @override
  String pokerHandSeatFallback(int id) {
    return 'Assento $id';
  }

  @override
  String pokerHandPlayerFallback(int id) {
    return 'Jogador $id';
  }

  @override
  String get pokerHandChooseOption => 'Escolha uma opção:';

  @override
  String get pokerHandLeaveBtn => 'Sair';

  @override
  String get pokerHandConfirmBtn => 'Confirmar';

  @override
  String pokerHandCurrentlyHaveRemaining(String stack) {
    return 'Você tem $stack restantes.';
  }

  @override
  String get opponentsColorRed => 'Vermelho';

  @override
  String get opponentsColorLightBlue => 'Azul claro';

  @override
  String get opponentsColorGreen => 'Verde';

  @override
  String get opponentsColorOrange => 'Laranja';

  @override
  String get opponentsColorPurple => 'Roxo';

  @override
  String get opponentsColorTeal => 'Azul-petróleo';

  @override
  String get opponentsColorPink => 'Rosa';

  @override
  String get opponentsColorIndigo => 'Índigo';

  @override
  String opponentsFailedToLoad(String error) {
    return 'Falha ao carregar oponentes: $error';
  }

  @override
  String get opponentDetailFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get opponentDetailStealLabel => 'Steal';

  @override
  String get opponentDetailCheckRaiseLabel => 'Check/Raise';

  @override
  String get individualSetupSessionSetup => 'Configuração da sessão';

  @override
  String get individualSetupSessionNameLabel => 'Nome da sessão';

  @override
  String get individualSetupGameTypeLabel => 'Tipo de jogo';

  @override
  String get individualSetupCashGameLabel => 'Cash Game';

  @override
  String get individualSetupTournamentLabel => 'Tournament';

  @override
  String get individualSetupBuyInAmountLabel => 'Valor do Buy-in';

  @override
  String get individualSetupEnterAmountHint => 'Digite o valor';

  @override
  String get individualSetupCashGameNote =>
      'No Cash Game, seu Stack inicial é igual ao valor do Buy-in.';

  @override
  String get individualSetupStartingStackLabel => 'Stack inicial';

  @override
  String get individualSetupEnterChipStackHint => 'Digite o Stack de fichas';

  @override
  String individualSetupStackValidation(int bigBlind) {
    return 'O Stack inicial deve ser pelo menos igual ao Big Blind ($bigBlind)';
  }

  @override
  String get individualSetupStartSessionBtn => 'Iniciar sessão';

  @override
  String get individualSetupEnterValueHint => 'Digite o valor';

  @override
  String get individualHandSetupTitle => 'Mão individual';

  @override
  String get individualHandSetupSubtitle => 'Registro rápido de mão';

  @override
  String get individualHandSetupHandNameLabel => 'Nome da mão (opcional)';

  @override
  String get playerSessionBluff => 'Bluff';

  @override
  String get playerSessionValue => 'Value';

  @override
  String get playerSessionMistake => 'Erro';

  @override
  String get playerSessionCooler => 'Cooler';

  @override
  String get playerSessionHeroCall => 'Hero Call';

  @override
  String get playerSessionExploit => 'Exploit';

  @override
  String get playerSessionToughSpot => 'Situação difícil';

  @override
  String get playerSessionEasyFold => 'Fold fácil';

  @override
  String get playerSessionEndedTitle => 'Sessão encerrada';

  @override
  String get playerSessionEndedBody => 'O Dealer encerrou esta sessão.';

  @override
  String get playerSessionRemovedTitle => 'Removido da mesa';

  @override
  String get playerSessionRemovedBody =>
      'Você foi removido da mesa pelo Dealer.';

  @override
  String playerSessionYouWon(String amount) {
    return 'Você ganhou $amount!';
  }

  @override
  String playerSessionSeatWins(int seat, String amount) {
    return 'Assento $seat ganha $amount';
  }

  @override
  String get playerSessionYourHoleCardsTitle => 'Suas Hole Cards';

  @override
  String get playerSessionConnecting => 'Conectando...';

  @override
  String get playerSessionGoBackBtn => 'Voltar';

  @override
  String get playerSessionHoleCardsLabel => 'Hole Cards';

  @override
  String get playerSessionEditBtn => 'Editar';

  @override
  String get playerSessionAddBtn => 'Adicionar';

  @override
  String get playerSessionBoardLabel => 'Board';

  @override
  String get playerSessionNoCardsDealt => 'Nenhuma carta distribuída';

  @override
  String get playerSessionWaitingForAction => 'Aguardando ação...';

  @override
  String get playerSessionActionsLabel => 'Ações';

  @override
  String get playerSessionYouLabel => 'Você';

  @override
  String playerSessionSeatFallback(int seat) {
    return 'Assento $seat';
  }

  @override
  String get playerSessionNotesHintText => 'Adicione notas sobre esta mão...';

  @override
  String get playerSessionHandHistoryLabel => 'Histórico de mãos';

  @override
  String get playerSessionNoCompletedHands => 'Nenhuma mão concluída ainda';

  @override
  String playerSessionWonAmount(String amount) {
    return 'Ganhou $amount';
  }

  @override
  String get playerSessionLostLabel => 'Perdeu';

  @override
  String get playerSessionDealerChangeTitle => 'Troca de Dealer';

  @override
  String get playerSessionWaitingForDealer => 'Aguardando novo Dealer...';

  @override
  String playerSessionHandUpdated(int number) {
    return 'Mão #$number atualizada';
  }

  @override
  String playerSessionErrorSaving(String error) {
    return 'Erro ao salvar: $error';
  }

  @override
  String playerSessionEditHand(int number) {
    return 'Editar mão #$number';
  }

  @override
  String get playerSessionViewDetails => 'Ver detalhes';

  @override
  String get playerSessionTapToAddHoleCards =>
      'Toque para adicionar Hole Cards';

  @override
  String get playerSessionSaveChanges => 'Salvar alterações';

  @override
  String get playerSessionLeaveTableTitle => 'Sair da mesa?';

  @override
  String get playerSessionLeaveTableBody =>
      'Tem certeza de que deseja sair desta mesa?';

  @override
  String playerSessionFailedLeave(String error) {
    return 'Falha ao sair: $error';
  }

  @override
  String get playerSessionTableSession => 'Sessão de mesa';

  @override
  String playerSessionHandNumber(int number) {
    return 'Mão #$number';
  }

  @override
  String get playerSessionUnknownDealer => 'Desconhecido';

  @override
  String get playerSessionNotAuthenticated => 'Não autenticado';

  @override
  String get dealerQrScanSessionSettings => 'Configurações da sessão';

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
  String get dealerQrScanStartDealingBtn => 'Começar a distribuir';

  @override
  String get dealerQrScanResumeSessionTitle => 'Retomar sessão';

  @override
  String dealerQrScanTakingOverFrom(String name) {
    return 'Assumindo de $name';
  }

  @override
  String get dealerQrScanHandsPlayedLabel => 'Mãos jogadas';

  @override
  String get dealerQrScanBlindsInfoLabel => 'Blinds';

  @override
  String get dealerQrScanPlayersLabel => 'Jogadores';

  @override
  String get dealerQrScanResumeBtn => 'Retomar';

  @override
  String get dealerQrScanTableNotAssigned => 'Mesa não atribuída';

  @override
  String get dealerQrScanEventTablesLabel => 'Mesas do evento:';

  @override
  String get dealerQrScanNoTablesAssigned => 'Nenhuma mesa atribuída';

  @override
  String get dealerQrScanThisTableId => 'ID desta mesa:';

  @override
  String get dealerQrScanCorrectQrUrl => 'URL correta do QR:';

  @override
  String get dealerQrScanScanTableQrTitle => 'Escanear QR da mesa';

  @override
  String get dealerQrScanScanInstructions =>
      'Escaneie o código QR da mesa para começar a distribuir';

  @override
  String get eventDashboardTournamentOnBreak => 'Tournament em pausa';

  @override
  String get eventDashboardLiveLabel => 'Ao vivo';

  @override
  String get eventDashboardLocalLabel => 'Local';

  @override
  String get eventDashboardDisconnectedLabel => 'Desconectado';

  @override
  String get eventDashboardPlayersLabel => 'Jogadores';

  @override
  String get eventDashboardTablesLabel => 'Mesas';

  @override
  String get eventDashboardTotalChipsLabel => 'Total de fichas';

  @override
  String get eventDashboardAvgStackLabel => 'Stack médio';

  @override
  String get eventDashboardChipLeaderLabel => 'Chip Leader';

  @override
  String get eventDashboardNoRankingsYet => 'Sem classificações ainda';

  @override
  String get eventDashboardRankingsWillAppear =>
      'As classificações aparecerão quando os jogadores entrarem nas mesas';

  @override
  String eventDashboardTableSeatLabel(String table, int seat) {
    return '$table - Assento $seat';
  }

  @override
  String eventDashboardPlayerFallback(String id) {
    return 'Jogador $id';
  }

  @override
  String get commonNA => 'N/D';

  @override
  String sessionHistoryFailedLoad(String error) {
    return 'Falha ao carregar sessões: $error';
  }

  @override
  String get sessionHistoryCash => 'Cash';

  @override
  String get sessionHistoryTournament => 'Tournament';

  @override
  String sessionHistorySessionId(String id) {
    return 'Sessão $id...';
  }

  @override
  String sessionHistorySeatWithPosition(String seat, String position) {
    return 'Assento $seat ($position)';
  }

  @override
  String sessionHistorySeat(String seat) {
    return 'Assento $seat';
  }

  @override
  String get sessionHistorySyncCompleted => 'Sincronização concluída';

  @override
  String get sessionHistoryFullHistory => 'Histórico completo de sessões';

  @override
  String get sessionHandsRetry => 'Tentar novamente';

  @override
  String get stackChartScreenStart => 'Início';

  @override
  String get stackChartScreenRebuy => 'Rebuy';

  @override
  String get stackChartScreenEnd => 'Fim';

  @override
  String get quickStackSelectPlayer => 'Selecionar jogador';

  @override
  String quickStackAddPlayer(String name) {
    return 'Adicionar \"$name\"';
  }

  @override
  String get quickStackSaveToOpponents => 'Salvar na lista de oponentes';

  @override
  String get quickStackYou => 'Você';

  @override
  String get quickStackNoPlayersFound => 'Nenhum jogador encontrado.';

  @override
  String get seatSetupDone => 'Pronto';

  @override
  String get seatSetupCancel => 'Cancelar';

  @override
  String get authConnectionIssue => 'Problema de Conexão';

  @override
  String get authConnectionIssueBody =>
      'Não conseguimos conectar aos nossos servidores.\nVerifique sua conexão com a internet\ne tente novamente.';

  @override
  String get authTryAgain => 'Tentar Novamente';

  @override
  String get redeemInvitationTitle => 'Resgatar Convite';

  @override
  String get redeemEnterCode => 'Inserir Código de Convite';

  @override
  String get redeemCodeDescription =>
      'Insira o código de 8 caracteres recebido de um admin do clube para entrar no clube deles.';

  @override
  String get redeemJoinClub => 'Entrar no Clube';

  @override
  String get redeemWelcome => 'Bem-vindo!';

  @override
  String redeemJoinedAs(String clubName, String role) {
    return 'Você entrou em $clubName como $role';
  }

  @override
  String get redeemContinue => 'Continuar';

  @override
  String get supportBugReport => 'Relato de Bug';

  @override
  String get supportFeatureRequest => 'Solicitação de Funcionalidade';

  @override
  String get supportAccountIssue => 'Problema de Conta';

  @override
  String get supportOther => 'Outro';

  @override
  String get supportFillAllFields => 'Por favor, preencha todos os campos';

  @override
  String get supportSubmitted => 'Solicitação de suporte enviada com sucesso';

  @override
  String supportFailedSubmit(String error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String get supportTitle => 'Ajuda e Suporte';

  @override
  String get supportSubmitButton => 'Enviar';

  @override
  String get supportCategoryLabel => 'CATEGORIA';

  @override
  String get supportSubjectLabel => 'ASSUNTO';

  @override
  String get supportDescriptionLabel => 'DESCRIÇÃO';

  @override
  String get supportSubjectHint => 'Breve resumo do problema';

  @override
  String get supportDescriptionHint => 'Descreva o problema em detalhes...';

  @override
  String get calendarEventLocation => 'Localização';

  @override
  String get calendarEventBuyIn => 'Valor do buy-in';

  @override
  String get calendarEventEdit => 'Editar';

  @override
  String get calendarEventDelete => 'Excluir Evento';

  @override
  String calendarEventDeleteConfirm(String title) {
    return 'Excluir $title?';
  }

  @override
  String calendarEventDeleteBody(String title) {
    return 'Tem certeza que deseja excluir \"$title\"?\nEsta ação não pode ser desfeita.';
  }

  @override
  String get calendarEventDeleteButton => 'Excluir';

  @override
  String get clubInfoTitle => 'Informações do Clube';

  @override
  String clubInfoMembersCount(int count) {
    return 'Membros ($count)';
  }

  @override
  String get clubInfoNoMembers => 'Nenhum membro encontrado';

  @override
  String get finalStandingsNoData => 'Nenhuma classificação disponível';

  @override
  String get finalStandingsNoDataHint =>
      'Este evento pode não ter registrado classificações';

  @override
  String get finalStandingsEmpty => 'Nenhuma classificação registrada';

  @override
  String get finalStandingsTitle => 'Classificação Final';

  @override
  String get finalStandingsPlayers => 'Jogadores';

  @override
  String get finalStandingsCompleted => 'Concluído';

  @override
  String get liveRankingsTitle => 'Rankings ao Vivo';

  @override
  String get liveRankingsEliminated => 'Jogadores eliminados';

  @override
  String get liveRankingsWaiting => 'Aguardando Jogadores';

  @override
  String get liveRankingsWaitingHint =>
      'Os rankings aparecerão quando os jogadores se sentarem';

  @override
  String get liveRankingsError => 'Erro ao Carregar Rankings';

  @override
  String get liveRankingsTryAgain => 'Tentar Novamente';

  @override
  String get leaderboardPlayers => 'Jogadores';

  @override
  String get leaderboardTotalChips => 'Total de Fichas';

  @override
  String get leaderboardWaiting => 'Aguardando jogadores...';

  @override
  String leaderboardChipLeader(String name) {
    return 'Chip Leader: $name';
  }

  @override
  String get dealerQrScanBbAnte => 'BB Ante';

  @override
  String mainDealerOnClub(String clubName) {
    return 'Agora você é dealer em $clubName';
  }

  @override
  String get raiseSnapMin => 'Mín';

  @override
  String get raiseSnapPot => 'Pot';

  @override
  String get raiseSnapAllIn => 'All-In';

  @override
  String sessionHistoryPlayerWins(int playerId) {
    return 'Jogador $playerId vence:';
  }

  @override
  String get inviteClubAdminFallback => 'Admin do Clube';

  @override
  String pokerHandBetRange(String min, String max) {
    return 'Mín: $min · Máx: $max';
  }

  @override
  String pokerHandAmountBetween(String min, String max) {
    return 'O valor deve estar entre $min e $max';
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
    return '$playerName para agir ($stack)';
  }

  @override
  String get eventDashboardOnBreakBadge => 'EM INTERVALO';

  @override
  String get eventDetailAdminActions => 'AÇÕES DO ADMIN';

  @override
  String get playerSessionHandNotesLabel => 'NOTAS DA MÃO';

  @override
  String get playerSessionTagsLabel => 'TAGS';

  @override
  String get playerSessionNotesLabel => 'NOTAS';

  @override
  String get playerSessionHoleCardsUpperLabel => 'CARTAS NA MÃO';

  @override
  String get qrJoinDeclined => 'Seu pedido de entrada foi recusado';

  @override
  String qrJoinFailed(String error) {
    return 'Falha ao entrar no assento: $error';
  }

  @override
  String get qrJoinTable => 'Entrar na Mesa';

  @override
  String get qrJoinLoading => 'Carregando informações da mesa...';

  @override
  String get qrJoinError => 'Algo deu errado';

  @override
  String get qrJoinGoBack => 'Voltar';

  @override
  String get qrJoinSeatOccupied =>
      'Este assento pode já estar ocupado. Entrar substituirá o jogador atual.';

  @override
  String get qrJoinWaitingDealer => 'Aguardando Dealer';

  @override
  String qrJoinRequestSent(int seatNumber) {
    return 'Seu pedido para entrar no Assento $seatNumber foi enviado.';
  }

  @override
  String get qrJoinDealerApproval =>
      'O dealer definirá seu stack de fichas e aprovará sua entrada.';

  @override
  String get qrJoinCancelRequest => 'Cancelar Pedido';

  @override
  String get qrJoinRequestButton => 'Solicitar para Entrar';

  @override
  String get onboardingSkipTour => 'Pular tour';

  @override
  String get onboardingWelcomeTitle => 'Bem-vindo ao Final Table';

  @override
  String get onboardingWelcomeBody =>
      'Vamos fazer um tour rápido para começar.\n\nVocê sempre pode refazer este tour em\nPerfil → Configurações → Base de Conhecimento.';

  @override
  String get onboardingLetsGo => 'Vamos lá';

  @override
  String get onboardingGotIt => 'Entendi';

  @override
  String get onboardingNext => 'Próximo';

  @override
  String get onboardingStartLoggingTitle => 'Começar Registro';

  @override
  String get onboardingStartLoggingBody =>
      'Toque no botão + para começar a registrar uma mão.';

  @override
  String get onboardingFullModeTitle => 'Modo de Registro Completo';

  @override
  String get onboardingFullModeBody =>
      'Rastreie cada ação de cada jogador em todas as ruas. Perfeito para análise séria.';

  @override
  String get onboardingIndividualModeTitle => 'Modo de Registro Individual';

  @override
  String get onboardingIndividualModeBody =>
      'Rastreamento rápido de lucro/perda para uma única sessão. Agora escolha um modo para continuar!';

  @override
  String get onboardingSessionSetupTitle => 'Configuração da Sessão';

  @override
  String get onboardingSessionSetupBody =>
      'Preencha os detalhes da sessão — nome, buy-in, blinds — e toque em Iniciar Jogo.';

  @override
  String get onboardingTableSetupTitle => 'Configurar Sua Mesa';

  @override
  String get onboardingTableSetupBody =>
      'Toque em qualquer assento para configurar os jogadores. Vamos percorrer o diálogo do assento a seguir.';

  @override
  String get onboardingSeatOpenTitle => 'Assento Aberto';

  @override
  String get onboardingSeatOpenBody =>
      'Alterne para marcar um assento como ocupado ou vazio. Assentos abertos são ignorados durante a mão.';

  @override
  String get onboardingThisIsMySeatTitle => 'Este É Meu Assento';

  @override
  String get onboardingThisIsMySeatBody =>
      'Toque aqui se este é o seu assento. Ele preenche automaticamente seu nome e rastreia suas estatísticas pessoais.';

  @override
  String get onboardingPlayerNameTitle => 'Nome do Jogador';

  @override
  String get onboardingPlayerNameBody =>
      'Digite um nome ou escolha de seus oponentes salvos. Oponentes salvos rastreiam estatísticas entre sessões.';

  @override
  String get onboardingSaveOpponentTitle => 'Salvar Oponente';

  @override
  String get onboardingSaveOpponentBody =>
      'Nome novo? Toque aqui para salvá-lo como oponente. As estatísticas serão rastreadas automaticamente.';

  @override
  String get onboardingDealerButtonTitle => 'Botão do Dealer';

  @override
  String get onboardingDealerButtonBody =>
      'Arraste isso para o assento com a posição do dealer. Isso determina os blinds e a ordem de ação.';

  @override
  String get onboardingViewSessionsTitle => 'Ver Suas Sessões';

  @override
  String get onboardingViewSessionsBody =>
      'Toque em Sessões para ver os resultados da sessão, histórico de mãos e estatísticas.';

  @override
  String get onboardingAllSetTitle => 'Tudo Pronto!';

  @override
  String get onboardingAllSetBody =>
      'Você está pronto para começar a acompanhar suas sessões de poker.';

  @override
  String get onboardingLetsPlay => 'Vamos jogar';

  @override
  String get onboardingUpdateStackTitle => 'Atualizar Stack';

  @override
  String get onboardingUpdateStackBody =>
      'Use isso para atualizar manualmente sua contagem de fichas a qualquer momento sem registrar uma mão completa.';

  @override
  String get onboardingLogAHandTitle => 'Registrar uma Mão';

  @override
  String get onboardingLogAHandBody =>
      'Toque aqui para configurar a mesa e registrar uma mão. Vamos tentar agora!';

  @override
  String get onboardingMarkSeatOpenTitle => 'Marcar Assento como Vazio';

  @override
  String get onboardingMarkSeatOpenBody =>
      'Toque na marca de seleção para alternar um assento entre ocupado e vazio. Assentos vazios são ignorados na mão.';

  @override
  String get onboardingDealerButtonQsuTitle => 'Botão do Dealer';

  @override
  String get onboardingDealerButtonQsuBody =>
      'Toque em \"D\" para atribuir o botão do dealer a qualquer assento. Isso controla as posições dos blinds e a ordem de ação.';

  @override
  String get onboardingAssignPlayerTitle => 'Atribuir um Jogador';

  @override
  String get onboardingAssignPlayerBody =>
      'Toque no nome de um jogador para sentar você mesmo ou um oponente salvo. Seu stack é aplicado automaticamente quando você se senta.';

  @override
  String get onboardingAdjustStackTitle => 'Ajustar Stack';

  @override
  String get onboardingAdjustStackBody =>
      'Arraste o controle deslizante para definir o stack de um oponente em BBs. Toque no valor do stack para digitar um valor exato.';

  @override
  String get onboardingEndSessionTitle => 'Encerrar Sua Sessão';

  @override
  String get onboardingEndSessionBody =>
      'Toque no botão vermelho Parar para salvar os resultados da sessão e voltar à tela inicial.';

  @override
  String onboardingStepOf(int step, int total) {
    return 'Passo $step de $total';
  }

  @override
  String get guidedGestureGuideTitle => 'Guia de Gestos';

  @override
  String get guidedGestureGuideBody =>
      'Toque neste ícone a qualquer momento para ver todos os controles de gesto.';

  @override
  String get guidedSkipButtonTitle => 'Botão Pular';

  @override
  String get guidedSkipButtonBody =>
      'Se você pular uma mão, este botão move o botão do dealer para o próximo jogador. Lembre-se que os stacks ficarão fora de sincronia — você pode atualizá-los em Gerenciar Jogadores.';

  @override
  String get guidedGameMenuTitle => 'Menu do Jogo';

  @override
  String get guidedGameMenuBody =>
      'Este menu tem opções úteis. Vamos ver uma configuração importante.';

  @override
  String get guidedGameSettingsTitle => 'Configurações do Jogo';

  @override
  String get guidedGameSettingsBody =>
      'Aqui você pode alterar os blinds durante a sessão — útil em torneios quando os níveis sobem.';

  @override
  String get guidedEndSessionTitle => 'Encerrar Sua Sessão';

  @override
  String get guidedEndSessionBody =>
      'Toque neste menu e selecione \"Parar Sessão\" para salvar seus resultados.';

  @override
  String get guidedReviewHandTitle => 'Revisar a Mão';

  @override
  String get guidedReviewHandBody =>
      'Insira suas cartas e quaisquer anotações.';

  @override
  String get guidedHandCompleteTitle => 'Mão Concluída!';

  @override
  String get guidedHandCompleteBody =>
      'Ótimo trabalho! Você acabou de registrar sua primeira mão.';

  @override
  String get guidedSkip => 'Pular';

  @override
  String get guidedYourTurn => 'Sua Vez!';

  @override
  String get guidedOpenThePotTitle => 'Abrir o Pot';

  @override
  String get guidedBetOnceBody => 'Toque uma vez para apostar.';

  @override
  String get guidedFoldTitle => 'Fold';

  @override
  String get guidedFoldBody =>
      'Este jogador faz fold. Desenhe uma linha para foldar.';

  @override
  String get guidedCallTitle => 'Call';

  @override
  String get guidedCallBody => 'Este jogador faz call. Desenhe um círculo.';

  @override
  String get guidedCheckTitle => 'Check';

  @override
  String get guidedCheckBody => 'Este jogador faz check. Toque duas vezes.';

  @override
  String get guidedDealFlopTitle => 'Distribuir o Flop';

  @override
  String get guidedDealFlopBody => 'Selecione 3 cartas para o Flop.';

  @override
  String get guidedDealTurnTitle => 'Distribuir o Turn';

  @override
  String get guidedDealTurnBody => 'Selecione 1 carta para o Turn.';

  @override
  String get guidedDealRiverTitle => 'Distribuir o River';

  @override
  String get guidedDealRiverBody => 'Selecione 1 carta para o River.';

  @override
  String get kbStatsTitle => 'Suas Estatísticas';

  @override
  String get kbClubsTitle => 'Clubes e Eventos';

  @override
  String get kbStatsIntro =>
      'Final Table rastreia 7 métricas principais de poker para ajudá-lo a entender e melhorar seu jogo.';

  @override
  String get kbClubsIntro =>
      'Os clubes permitem que você se conecte com sua sala de poker local e acompanhe jogos ao vivo.';

  @override
  String get kbVpipName => 'VPIP';

  @override
  String get kbVpipFullName => 'Voluntarily Put \$ In Pot';

  @override
  String get kbVpipDescription =>
      'Com que frequência você entra voluntariamente em um pot (excluindo postagens de blinds). Um VPIP alto significa que você joga muitas mãos; um VPIP baixo significa que você é seletivo.';

  @override
  String get kbPfrName => 'PFR';

  @override
  String get kbPfrFullName => 'Preflop Raise';

  @override
  String get kbPfrDescription =>
      'Com que frequência você dá raise antes do flop. A diferença entre VPIP e PFR mostra com que frequência você limpa ou faz cold-call.';

  @override
  String get kbThreeBetName => '3-Bet';

  @override
  String get kbThreeBetFullName => 'Three-Bet Percentage';

  @override
  String get kbThreeBetDescription =>
      'Com que frequência você dá re-raise no raise aberto de um oponente pré-flop. Um 3-Bet% mais alto indica um estilo pré-flop agressivo.';

  @override
  String get kbFoldTo3BetName => 'Fold to 3-Bet';

  @override
  String get kbFoldTo3BetFullName => 'Fold to Three-Bet';

  @override
  String get kbFoldTo3BetDescription =>
      'Com que frequência você faz fold após dar um raise e enfrentar um 3-Bet. Se muito alto, os oponentes podem explorar você com 3-Bets leves.';

  @override
  String get kbCBetName => 'C-Bet';

  @override
  String get kbCBetFullName => 'Continuation Bet';

  @override
  String get kbCBetDescription =>
      'Com que frequência você aposta no Flop após ser o último agressor pré-flop. Uma jogada padrão que demonstra força.';

  @override
  String get kbStealName => 'Steal';

  @override
  String get kbStealFullName => 'Blind Steal Attempt';

  @override
  String get kbStealDescription =>
      'Com que frequência você abre com raise de posição tardia (CO, BTN, SB) quando o pot está fechado, visando roubar os blinds.';

  @override
  String get kbCheckRaiseName => 'Check-Raise';

  @override
  String get kbCheckRaiseFullName => 'Flop Check-Raise';

  @override
  String get kbCheckRaiseDescription =>
      'Com que frequência você faz check e depois raise no Flop. Uma jogada enganosa que pode prender oponentes agressivos.';

  @override
  String get kbLiveEventsTitle => 'Eventos ao Vivo';

  @override
  String get kbLiveEventsDescription =>
      'Os gerentes de clube criam eventos com várias mesas. Participe de um evento para fazer parte do ranking ao vivo.';

  @override
  String get kbLiveRankingsTitle => 'Rankings ao Vivo';

  @override
  String get kbLiveRankingsDescription =>
      'Veja sua posição em tempo real durante os eventos. Os rankings são atualizados após cada mão.';

  @override
  String get kbOpponentTrackingTitle => 'Rastreamento de Oponentes';

  @override
  String get kbOpponentTrackingDescription =>
      'Jogadores que você enfrenta no clube são rastreados automaticamente. Salve oponentes para construir perfis detalhados.';

  @override
  String get kbQrSeatTitle => 'Atribuição de Assento por QR';

  @override
  String get kbQrSeatDescription =>
      'Escaneie um código QR na sua mesa para entrar na sessão instantaneamente. Suas mãos são rastreadas automaticamente pelo dealer.';

  @override
  String get kbDealerLoggingTitle => 'Registro Assistido pelo Dealer';

  @override
  String get kbDealerLoggingDescription =>
      'Os dealers usam comandos de voz para registrar ações para toda a mesa. Nenhuma entrada manual é necessária dos jogadores.';

  @override
  String get kbSessionStatsTitle => 'Estatísticas da Sessão';

  @override
  String get kbSessionStatsDescription =>
      'Após cada sessão, veja seu lucro/perda e como suas estatísticas mudaram. Cada mão é registrada.';

  @override
  String get qrJoinTableInfo => 'INFORMAÇÕES DA MESA';

  @override
  String qrJoinSeat(int number) {
    return 'Assento $number';
  }

  @override
  String get qrJoinTableFallback => 'Mesa';

  @override
  String get qrJoinClubLabel => 'Clube';

  @override
  String get qrJoinTableLabel => 'Mesa';

  @override
  String get qrJoinSeatLabel => 'Assento';

  @override
  String get qrJoinStatusLabel => 'Status';

  @override
  String get qrJoinActiveGame => 'Jogo Ativo';

  @override
  String get qrJoinWaitingStatus => 'Aguardando';

  @override
  String dealerQrTablesAssigned(int count) {
    return '$count mesa(s) atribuída(s) a este evento';
  }

  @override
  String dealerQrTableNotAssigned(String tableName) {
    return '$tableName não está atribuída a este evento.';
  }

  @override
  String dealerTablePlayerAdded(String playerName, int seatNumber) {
    return '$playerName adicionado ao Assento $seatNumber';
  }

  @override
  String memberTableSeatedOpen(int seated, int open) {
    return '$seated sentados  •  $open abertos';
  }

  @override
  String get memberTablePlayer => 'Jogador';

  @override
  String get memberTableEmpty => 'Vazio';

  @override
  String get memberTableFallback => 'Mesa';

  @override
  String get homeEventTypeTournament => 'Torneio';

  @override
  String get homeEventTypeCashGame => 'Cash Game';

  @override
  String get homeEventTypeHomeGame => 'Jogo em Casa';

  @override
  String get homeEventTypeOnline => 'Online';

  @override
  String get bankrollSheetTitle => 'Adicionar resultado';

  @override
  String get bankrollSheetEditSection => 'Editar bankroll';

  @override
  String get bankrollSheetGoalLabel => 'Meta de bankroll';

  @override
  String get bankrollSheetCurrentLabel => 'Bankroll atual';

  @override
  String get bankrollSheetGoalUpdated => 'Meta atualizada';

  @override
  String get bankrollSheetBankrollUpdated => 'Bankroll atualizado';

  @override
  String get sessionEndResultTitle => 'Resultado da sessão';

  @override
  String get sessionEndTournamentTitle => 'Resultado do torneio';

  @override
  String get sessionEndProfit => 'Lucro';

  @override
  String get sessionEndLoss => 'Prejuízo';

  @override
  String get sessionEndApply => 'Aplicar';

  @override
  String get sessionEndSkip => 'Pular';

  @override
  String get sessionEndFinishingPosition => 'Posição final';

  @override
  String get sessionEndFieldSize => 'Total de participantes';

  @override
  String get sessionEndPrizeWon => 'Prêmio ganho';

  @override
  String get sessionEndTotalInvested => 'Total investido';

  @override
  String sessionEndCalculatedProfit(String amount) {
    return 'Lucro calculado: $amount';
  }
}
