// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get navHome => 'Главная';

  @override
  String get navOpponents => 'Соперники';

  @override
  String get navSessions => 'Сессии';

  @override
  String get navProfile => 'Профиль';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonConfirm => 'Подтвердить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonError => 'Ошибка';

  @override
  String get commonLoading => 'Загрузка...';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonOk => 'ОК';

  @override
  String get commonYes => 'Да';

  @override
  String get commonNo => 'Нет';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonNoData => 'Нет данных';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonNotAvailable => 'Н/Д';

  @override
  String get commonApply => 'Применить';

  @override
  String get commonUpdate => 'Обновить';

  @override
  String get commonClear => 'Очистить';

  @override
  String get commonToday => 'Сегодня';

  @override
  String get statsTitle => 'Статистика';

  @override
  String get statsSubtitle => 'Расширенная аналитика';

  @override
  String get statsHandsPlayed => 'Сыграно рук';

  @override
  String get statsFoldTo3Bet => 'Fold на 3-Bet';

  @override
  String get statsWinRate => 'Винрейт';

  @override
  String get statsSessionStatistics => 'Статистика сессий';

  @override
  String get statsSessions => 'Сессии';

  @override
  String get statsTotalTime => 'Общее время';

  @override
  String get statsAvgSession => 'Ср. сессия';

  @override
  String get statsPlayToSee =>
      'Играйте сессии, чтобы увидеть статистику времени';

  @override
  String get statsGeneral => 'Общее';

  @override
  String get statsCash => 'Кэш';

  @override
  String get statsTournament => 'Турнир';

  @override
  String get statsTotalBuyIn => 'Общий Buy-In';

  @override
  String get statsTotalCashOut => 'Общий Cash-Out';

  @override
  String get statsNetProfit => 'Чистая прибыль';

  @override
  String get statsItm => 'ITM%';

  @override
  String get statsAvgFinish => 'Ср. место';

  @override
  String get statsBestFinish => 'Лучшее место';

  @override
  String get statsRoi => 'ROI%';

  @override
  String get statsFinalTables => 'Финальные столы';

  @override
  String get statsAvgBuyIn => 'Ср. Buy-In';

  @override
  String get statsAvgFieldSize => 'Ср. кол-во игроков';

  @override
  String get statsHourlyRate => 'Почасовая ставка';

  @override
  String get statsHourlyRateNotAvailable =>
      'Доступно после 60 мин отслеживания';

  @override
  String get statsLoadingMessage => 'Загрузка статистики...';

  @override
  String get statsFetchingMessage => 'Получение статистики...';

  @override
  String statsFailedToLoad(String error) {
    return 'Не удалось загрузить статистику: $error';
  }

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSubtitle => 'Выберите язык приложения';

  @override
  String get settingsLanguageSystem => 'Системный';

  @override
  String get settingsCurrency => 'Валюта';

  @override
  String get settingsKnowledgeBase => 'БАЗА ЗНАНИЙ';

  @override
  String get settingsGuidedTour => 'Обучение';

  @override
  String get settingsGuidedTourSubtitle => 'Повторить обучение';

  @override
  String get settingsFullLoggingTour => 'Полное логирование';

  @override
  String get settingsFullLoggingTourSubtitle =>
      'Полный поток отслеживания сессии';

  @override
  String get settingsIndividualLoggingTour => 'Индивидуальное логирование';

  @override
  String get settingsIndividualLoggingTourSubtitle => 'Отслеживание одной руки';

  @override
  String get settingsUnderstandingStats => 'Ваши показатели';

  @override
  String get settingsUnderstandingStatsSubtitle =>
      'Узнайте что означает каждая метрика';

  @override
  String get settingsClubsEvents => 'Клубы и события';

  @override
  String get settingsClubsEventsSubtitle => 'Как работает клубная игра';

  @override
  String get settingsAdmin => 'АДМИН';

  @override
  String get settingsClubRequests => 'Заявки клубов';

  @override
  String get settingsClubRequestsSubtitle =>
      'Управление заявками на регистрацию';

  @override
  String get settingsSupportRequests => 'Обращения в поддержку';

  @override
  String get settingsSupportRequestsSubtitle =>
      'Управление обращениями пользователей';

  @override
  String get settingsNotificationTester => 'Тестер уведомлений';

  @override
  String get settingsNotificationTesterSubtitle =>
      'Предпросмотр всех уведомлений';

  @override
  String get profileUpgrade => 'Улучшить';

  @override
  String get profileUsername => 'Имя пользователя';

  @override
  String get profileNotSet => 'Не задано';

  @override
  String get profileChange => 'Изменить';

  @override
  String get profileSetUsername => 'Задать имя';

  @override
  String get profileUseNicknameInGames => 'Использовать ник в играх';

  @override
  String profileUseNicknameDescription(String username) {
    return 'Показывать @$username вместо вашего имени в событиях и логировании рук';
  }

  @override
  String get profileBankrollGoal => 'Цель банкролла';

  @override
  String get profileUpdateGoal => 'Обновить цель';

  @override
  String get profileCurrentBankroll => 'Текущий банкролл';

  @override
  String get profileUpdateBankroll => 'Обновить банкролл';

  @override
  String get profileAddSessionResult => 'Добавить результат сессии';

  @override
  String get profileSessionResultHint =>
      'Положительное значение для выигрыша, отрицательное для проигрыша';

  @override
  String get profileAddResult => 'Добавить результат';

  @override
  String get profileGoalUpdatedSuccess => 'Цель обновлена!';

  @override
  String get profileErrorUpdatingGoal => 'Ошибка обновления цели';

  @override
  String get profileBankrollUpdatedSuccess => 'Банкролл обновлён!';

  @override
  String get profileErrorUpdatingBankroll => 'Ошибка обновления банкролла';

  @override
  String get profileSessionResultAdded => 'Результат сессии добавлен!';

  @override
  String get profileErrorAddingResult => 'Ошибка добавления результата сессии';

  @override
  String get profilePleaseEnterValidAmount => 'Введите корректную сумму';

  @override
  String get profileLogOut => 'Выйти';

  @override
  String get profileSignOut => 'Выйти';

  @override
  String get profileSignOutConfirmation => 'Вы уверены, что хотите выйти?';

  @override
  String get sessionHistoryTitle => 'История сессий';

  @override
  String get sessionLast30Days => 'Последние 30 дней';

  @override
  String get sessionUpgradeForFullHistory => 'Улучшите для полной истории';

  @override
  String get sessionLoadingMessage => 'Загрузка сессий...';

  @override
  String sessionNoSessions(String gameType) {
    return 'Нет сессий $gameType';
  }

  @override
  String sessionPlayToSee(String gameType) {
    return 'Сыграйте несколько рук $gameType\nчтобы увидеть результаты';
  }

  @override
  String get sessionLive => 'Онлайн';

  @override
  String sessionPlayersCount(int count) {
    return '$count Игроков';
  }

  @override
  String get sessionSyncingToCloud => 'Синхронизация с облаком...';

  @override
  String get sessionClearAllTitle => 'Удалить все сессии?';

  @override
  String get sessionClearAllDescription =>
      'Это навсегда удалит все покерные сессии и руки из Firebase и локального хранилища.';

  @override
  String get sessionClearAllWarning => 'Это действие нельзя отменить!';

  @override
  String get sessionClearAll => 'Удалить всё';

  @override
  String get sessionClearedSuccessfully => 'Все сессии успешно удалены';

  @override
  String sessionHandDetails(int handNumber) {
    return 'Рука #$handNumber — подробности';
  }

  @override
  String get sessionYourCards => 'Ваши карты:';

  @override
  String get sessionBoardCards => 'Карты на столе:';

  @override
  String get sessionPotByStreet => 'Банк по улицам:';

  @override
  String get sessionActions => 'Действия:';

  @override
  String get sessionNoActionsRecorded => 'Нет записанных действий';

  @override
  String get sessionNoCardsRecorded => 'Нет записанных карт';

  @override
  String get sessionFinalPot => 'Итоговый банк:';

  @override
  String sessionChoppedPot(int count) {
    return 'Разделённый банк ($count победителей):';
  }

  @override
  String get sessionWinnerNotAvailable => 'Информация о победителе недоступна';

  @override
  String get opponentsTitle => 'Соперники';

  @override
  String opponentsCountFree(int count, int max) {
    return '$count/$max бесплатно';
  }

  @override
  String opponentsCountPremium(int count) {
    return '$count отслеживаемых игроков';
  }

  @override
  String get opponentsSearchHint => 'Поиск соперников...';

  @override
  String get opponentsLoadingMessage => 'Загрузка соперников...';

  @override
  String get opponentsNoResults => 'Нет результатов';

  @override
  String get opponentsEmptyTitle => 'Нет соперников';

  @override
  String get opponentsEmptySubtitle =>
      'Отслеживайте стили игры и статистику соперников';

  @override
  String get opponentsEmptySearchSubtitle => 'Попробуйте другой запрос';

  @override
  String get opponentsAddButton => 'Добавить соперника';

  @override
  String opponentsLastSeen(String date) {
    return 'Последний раз: $date';
  }

  @override
  String get opponentsHands => 'Руки';

  @override
  String get opponentsEditMenu => 'Редактировать соперника';

  @override
  String get opponentsDeleteMenu => 'Удалить соперника';

  @override
  String get opponentsAddDialogTitle => 'Добавить соперника';

  @override
  String get opponentsEditDialogTitle => 'Редактировать соперника';

  @override
  String get opponentsNameHint => 'Имя соперника';

  @override
  String get opponentsNotesHint => 'Заметки (необязательно)';

  @override
  String get opponentsPickColor => 'Выберите цвет';

  @override
  String get opponentsAddedSuccess => 'Соперник добавлен';

  @override
  String opponentAlreadyExists(String name) {
    return 'Оппонент с именем \"$name\" уже существует';
  }

  @override
  String get opponentsUpdatedSuccess => 'Соперник обновлён';

  @override
  String get opponentsDeleteConfirmTitle => 'Удалить соперника?';

  @override
  String opponentsDeleteConfirmMessage(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?\nЭто действие нельзя отменить';
  }

  @override
  String get opponentsDeletedSuccess => 'Соперник удалён';

  @override
  String get opponentsAnalyticsTitle => 'Аналитика соперников';

  @override
  String get opponentsAnalyticsTotalLabel => 'Всего соперников';

  @override
  String get opponentsAnalyticsHandsTracked => 'Всего отслеженных рук';

  @override
  String get opponentsAnalyticsAverage => 'Среднее рук на соперника';

  @override
  String get opponentsAnalyticsMostPlayed => 'Чаще всего играли против';

  @override
  String get opponentsAnalyticsDistribution => 'Распределение типов игроков:';

  @override
  String get opponentsClearAllTitle => 'Удалить всех соперников?';

  @override
  String get opponentsClearAllMessage =>
      'Это навсегда удалит все данные соперников. Это действие нельзя отменить!';

  @override
  String get opponentsClearAllButton => 'Удалить всё';

  @override
  String get opponentsClearedSuccess => 'Все соперники удалены';

  @override
  String get setupSessionSetup => 'Настройка сессии';

  @override
  String get setupSessionName => 'Название сессии';

  @override
  String get setupSessionNameHint => 'напр., \"Пятничный покер\"';

  @override
  String get setupGameType => 'Тип игры';

  @override
  String get setupCashGame => 'Кэш-игра';

  @override
  String get setupTournament => 'Турнир';

  @override
  String get setupSmallBlind => 'Small Blind';

  @override
  String get setupBigBlind => 'Big Blind';

  @override
  String get setupBuyInAmount => 'Сумма бай-ина';

  @override
  String get setupEnterAmount => 'Введите сумму';

  @override
  String get setupStartingStackEqualsBuyIn =>
      'Начальный стек равен вашему бай-ину.';

  @override
  String get setupStartingStack => 'Начальный стек';

  @override
  String get setupEnterChipStack => 'Введите стек фишек';

  @override
  String setupMustBeAtLeastBigBlind(int bigBlind) {
    return 'Должен быть не менее Big Blind ($bigBlind)';
  }

  @override
  String get setupBbAnte => 'BB Ante';

  @override
  String get setupTableSection => 'СТОЛ';

  @override
  String get setupTableInstructions =>
      'Нажмите на место, чтобы добавить игрока. Перетащите кнопку, чтобы установить дилера.';

  @override
  String get setupStartSession => 'Начать сессию';

  @override
  String get setupMe => 'Я';

  @override
  String setupPlayerSeat(int seatNumber) {
    return 'Игрок $seatNumber';
  }

  @override
  String get setupHero => 'Hero';

  @override
  String get homeLoadingPokerData => 'Загрузка покерных данных...';

  @override
  String get homeWelcomeBack => 'С возвращением';

  @override
  String get homeNoActiveSessions => 'Нет активных сессий';

  @override
  String get homeLiveSessions => 'Живые сессии';

  @override
  String get homeClubNotFound => 'Клуб не найден';

  @override
  String get homeEventNotFound => 'Событие не найдено';

  @override
  String get homeRecentActivity => 'Последняя активность';

  @override
  String get homeWinRate => 'Винрейт';

  @override
  String get homeHours => 'Часы';

  @override
  String get homePlayStyle => 'Стиль игры';

  @override
  String get homePlayStyleTooltip =>
      'Ваш стиль игры будет определён после логирования 50 рук на префлопе.';

  @override
  String get homeBankroll => 'Банкролл';

  @override
  String homeBankrollOfGoal(String current, String goal) {
    return '$current из $goal';
  }

  @override
  String homeAmountLeft(String amount) {
    return 'Осталось $amount';
  }

  @override
  String get homeEarnings => 'Заработок';

  @override
  String homeAvgAmount(String amount) {
    return 'Ср. $amount';
  }

  @override
  String get homeNoEarningsDataYet => 'Нет данных о заработке';

  @override
  String get homeRecentSessions => 'Последние сессии';

  @override
  String get homeViewAll => 'Показать все';

  @override
  String get homeNoRecentSessions => 'Нет последних сессий';

  @override
  String get homeStartFirstSession => 'Начните свою первую покерную сессию!';

  @override
  String get homeAddNew => 'Добавить';

  @override
  String get homeUpcomingEvents => 'Предстоящие события';

  @override
  String get homeNoRecentEvents => 'Нет последних событий';

  @override
  String get homeAddFirstEvent => 'Добавьте своё первое покерное событие!';

  @override
  String homePlayersCount(int count) {
    return '$count Игроков';
  }

  @override
  String homeGoingCount(int count) {
    return '$count идёт';
  }

  @override
  String get homePrivateGame => 'Приватная игра';

  @override
  String get homeHomeGame => 'Домашняя игра';

  @override
  String get homeOnline => 'Онлайн';

  @override
  String get homeEditEvent => 'Редактировать событие';

  @override
  String get homeDeleteEvent => 'Удалить событие';

  @override
  String get homeEventName => 'Название события';

  @override
  String get homeLocationVenue => 'Место проведения';

  @override
  String get homeBuyInAmount => 'Сумма бай-ина';

  @override
  String get homeSelectDate => 'Выберите дату:';

  @override
  String get homeSaveChanges => 'Сохранить изменения';

  @override
  String homeDeleteEventConfirm(String eventName) {
    return 'Удалить $eventName?';
  }

  @override
  String homeDeleteEventDescription(String eventName) {
    return 'Вы уверены, что хотите удалить \"$eventName\"?';
  }

  @override
  String get homeEventDeletedSuccessfully => 'Событие успешно удалено';

  @override
  String get homeClubInvitation => 'Приглашение в клуб';

  @override
  String get homeYouveBeenInvitedToJoin => 'Вас пригласили присоединиться к';

  @override
  String get homeDecline => 'Отклонить';

  @override
  String get homeAccept => 'Принять';

  @override
  String get homeInvitationDeclined => 'Приглашение отклонено';

  @override
  String get homeInvitationAccepted => 'Приглашение принято';

  @override
  String get homeClubInvitations => 'Приглашения в клубы';

  @override
  String get homeLater => 'Позже';

  @override
  String get homeViewInvitations => 'Посмотреть приглашения';

  @override
  String get homeNoEarningsDataTitle => 'Нет данных о заработке';

  @override
  String get homeNoEarningsDataDescription =>
      'Сначала добавьте результаты сессий, чтобы увидеть график заработка. Результаты можно добавить на странице Профиль.';

  @override
  String handHandNumber(int number) {
    return 'Рука #$number';
  }

  @override
  String handFreeCounter(int used, int max) {
    return '$used/$max бесплатно';
  }

  @override
  String get handNextHand => 'Следующая рука';

  @override
  String get handFoldedToMe => 'Сфолдили ко мне';

  @override
  String get handUndoLastAction => 'Отменить последнее действие';

  @override
  String get handAllInHand => 'ALL IN';

  @override
  String get handPot => 'Банк';

  @override
  String get handStack => 'Стек';

  @override
  String get handToAct => 'Ход';

  @override
  String get handToActYou => 'Вы';

  @override
  String get handStopSessionTitle => 'Завершить сессию?';

  @override
  String get handStopSessionMessage =>
      'Вы уверены, что хотите завершить эту сессию? Все руки будут сохранены.';

  @override
  String get handStop => 'Завершить';

  @override
  String get handChangeTable => 'Сменить стол';

  @override
  String get handBlinds => 'Блайнды';

  @override
  String get handTakesEffectNextHand => 'Вступает в силу со следующей руки';

  @override
  String get handLeaveSession => 'Покинуть сессию?';

  @override
  String get handSaveAndExit => 'Сохранить и выйти';

  @override
  String get handDiscardAndExit => 'Отменить и выйти';

  @override
  String get handInProgress => 'Hand in Progress';

  @override
  String get handDiscardCurrentHand =>
      'You have an active hand being logged. Discard it and go back?';

  @override
  String get handDiscardHand => 'Discard Hand';

  @override
  String get handAdjustStack => 'Изменить стек';

  @override
  String get handEnterStackAmount => 'Введите размер стека';

  @override
  String get handGestureGuide => 'Руководство по жестам';

  @override
  String get handManagePlayers => 'Управление игроками';

  @override
  String get handStopSession => 'Завершить сессию';

  @override
  String get handRebuy => 'Ребай';

  @override
  String get handGestures => 'Жесты';

  @override
  String get handGestureTap => 'Нажатие';

  @override
  String get handGestureCheckCall => 'Check / Call';

  @override
  String get handGestureSwipeOut => 'Свайп наружу';

  @override
  String get handGestureSwipeUp => 'Свайп вверх';

  @override
  String get handGestureBetRaise => 'Bet / Raise';

  @override
  String get handStreetComplete => 'Улица завершена';

  @override
  String get handWinsThePot => 'выигрывает банк';

  @override
  String get handHandComplete => 'Рука завершена';

  @override
  String get handTapToContinue => 'Нажмите, чтобы продолжить';

  @override
  String get handRaiseAmount => 'Сумма рейза';

  @override
  String get handBetAmount => 'Сумма ставки';

  @override
  String get handPleaseEnterValidNumber => 'Введите корректное число';

  @override
  String get handConfirmRebuy => 'Подтвердить ребай';

  @override
  String get handRebuyReplaceStack =>
      'Ребай заменит ваш текущий стек. Вы уверены, что хотите продолжить?';

  @override
  String get handProceed => 'Продолжить';

  @override
  String get handEnterRebuyDetails => 'Введите данные ребая для турнира';

  @override
  String get handRebuyAmount => 'Сумма ребая';

  @override
  String get handNewStackSize => 'Новый размер стека';

  @override
  String get handChipCountAfterRebuy => 'Количество фишек после ребая';

  @override
  String get handSessionInfo => 'Информация о сессии';

  @override
  String handTotalInvested(String amount) {
    return 'Всего вложено: $amount';
  }

  @override
  String handRebuysCount(int count) {
    return 'Ребаи: $count';
  }

  @override
  String get handAddRebuy => 'Добавить ребай';

  @override
  String get handPleaseEnterValidAmounts => 'Введите корректные суммы';

  @override
  String get handHandInProgress => 'Рука в процессе';

  @override
  String get handHandInProgressMessage =>
      'Рука в процессе. Переход к следующей руке отменит все действия и восстановит стеки игроков.';

  @override
  String get handMoveToNextHand => 'Перейти к следующей руке';

  @override
  String get handMainPot => 'Основной банк';

  @override
  String handSidePot(int index) {
    return 'Побочный банк $index';
  }

  @override
  String get handPokerSession => 'Покерная сессия';

  @override
  String handActionsHandNumber(String number) {
    return 'Hand #$number';
  }

  @override
  String handActionsPosition(String position) {
    return 'Позиция: $position';
  }

  @override
  String get handActionsShareHand => 'Поделиться Hand';

  @override
  String get handActionsShowHoleCards => 'Показать карты';

  @override
  String get handActionsShowHoleCardsSubtitle =>
      'Ваши карты будут видны по ссылке';

  @override
  String get handActionsHideHoleCards => 'Скрыть карты';

  @override
  String get handActionsHideHoleCardsSubtitle =>
      'Ваши карты будут скрыты в общей ссылке';

  @override
  String get handActionsShareMessage => 'Посмотри эту раздачу в Final Table!';

  @override
  String handActionsShareSubject(String number) {
    return 'Poker Hand #$number';
  }

  @override
  String get handActionsFailedToShareHand => 'Не удалось поделиться раздачей';

  @override
  String get handActionsGeneratingExport => 'Генерация экспорта PokerStars...';

  @override
  String handActionsExportedSuccessfully(String number) {
    return 'Hand #$number экспортирована успешно!';
  }

  @override
  String handActionsFailedToExport(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get handActionsMissingHeroCards => 'Карты Hero отсутствуют';

  @override
  String get handActionsMissingHeroCardsMessage =>
      'Для AI-анализа необходимо записать ваши карты. Эту раздачу невозможно проанализировать, так как карты Hero отсутствуют.';

  @override
  String get handActionsYourCards => 'Ваши карты';

  @override
  String get handActionsOpponentCards => 'Карты оппонента';

  @override
  String handActionsPlayerSeat(int id) {
    return 'Игрок $id';
  }

  @override
  String get handActionsPot => 'POT';

  @override
  String get handActionsBlinds => 'BLINDS';

  @override
  String get handActionsWinner => 'ПОБЕДИТЕЛЬ';

  @override
  String handActionsPlayersCount(int count) {
    return '$count игроков';
  }

  @override
  String get handActionsActionSummary => 'Сводка действий';

  @override
  String get handActionsPreflop => 'PREFLOP';

  @override
  String get handActionsBoard => 'БОРД';

  @override
  String get handActionsPlayer => 'ИГРОК';

  @override
  String get handActionsStack => 'STACK';

  @override
  String get handActionsAction => 'ДЕЙСТВИЕ';

  @override
  String get handActionsAmount => 'СУММА';

  @override
  String get handActionsYou => 'Вы';

  @override
  String get handActionsAllIn => 'ALL IN';

  @override
  String get handActionsNotes => 'Заметки';

  @override
  String get handActionsAnalyzingHand => 'Анализ раздачи...';

  @override
  String get handActionsHeroCardsMissing => 'Карты Hero отсутствуют';

  @override
  String get handActionsUnlockAiAnalysis => 'Разблокировать AI-анализ';

  @override
  String get handActionsAnalysisComplete => 'Анализ завершён';

  @override
  String get handActionsAiAnalyzerBeta => 'AI-анализатор (бета)';

  @override
  String get handActionsAnalysisFailed => 'Ошибка анализа';

  @override
  String get handActionsAiAnalysis => 'AI-анализ';

  @override
  String get handActionsStreetByStreetBreakdown => 'Разбор по улицам';

  @override
  String handActionsAnalysisCompletedIn(String time) {
    return 'Анализ завершён за $time сек.';
  }

  @override
  String get handActionsFailedToUpdateStar => 'Не удалось обновить избранное';

  @override
  String handActionsPotAmount(String amount) {
    return 'Pot: $amount';
  }

  @override
  String opponentDetailHandsTracked(int count) {
    return '$count раздач отслежено';
  }

  @override
  String get opponentDetailNoDataYet => 'Данных пока нет';

  @override
  String get opponentDetailHands => 'Раздачи';

  @override
  String get opponentDetailLastSeen => 'Последний раз:';

  @override
  String get opponentDetailNotes => 'Заметки';

  @override
  String get opponentDetailEditOpponent => 'Редактировать оппонента';

  @override
  String get opponentDetailDeleteOpponent => 'Удалить оппонента';

  @override
  String get opponentDetailStatistics => 'Статистика';

  @override
  String get opponentDetailNoStatisticsAvailable => 'Статистика недоступна';

  @override
  String get opponentDetailAggressionFreq => 'Aggression Freq';

  @override
  String get opponentDetailShowdownPercent => 'Showdown %';

  @override
  String get opponentDetailHandHistory => 'История раздач';

  @override
  String get opponentDetailViewAllHands =>
      'Просмотреть все раздачи с этим оппонентом';

  @override
  String get opponentDetailViewHandHistory => 'Просмотреть историю раздач';

  @override
  String get opponentDetailNoHandsFound => 'Раздачи не найдены';

  @override
  String opponentDetailNoHandsMessage(String name) {
    return 'Вы ещё не играли с \"$name\"';
  }

  @override
  String get opponentDetailOpponentName => 'Имя оппонента';

  @override
  String get opponentDetailNotesOptional => 'Заметки (необязательно)';

  @override
  String get opponentDetailPickColor => 'Выберите цвет';

  @override
  String get opponentDetailColorRed => 'Красный';

  @override
  String get opponentDetailColorLightBlue => 'Голубой';

  @override
  String get opponentDetailColorGreen => 'Зелёный';

  @override
  String get opponentDetailColorOrange => 'Оранжевый';

  @override
  String get opponentDetailColorPurple => 'Фиолетовый';

  @override
  String get opponentDetailColorTeal => 'Бирюзовый';

  @override
  String get opponentDetailColorPink => 'Розовый';

  @override
  String get opponentDetailColorIndigo => 'Индиго';

  @override
  String get opponentDetailUpdatedSuccessfully => 'Оппонент обновлён';

  @override
  String get opponentDetailDeleteConfirmTitle => 'Удалить оппонента?';

  @override
  String opponentDetailDeleteConfirmMessage(String name) {
    return 'Вы уверены, что хотите удалить \"$name\"?\nЭто действие нельзя отменить';
  }

  @override
  String get opponentDetailDeletedSuccessfully => 'Оппонент удалён';

  @override
  String opponentDetailErrorDeleting(String error) {
    return 'Ошибка удаления оппонента: $error';
  }

  @override
  String get individualSessionCreatedLocally =>
      'Сессия создана локально. Синхронизируется с облаком при наличии подключения.';

  @override
  String get individualUpdateCurrentStack => 'Обновить текущий Stack';

  @override
  String get individualCurrentStack => 'Текущий Stack:';

  @override
  String get individualSetNewTotal => 'Установить новый итог';

  @override
  String get individualEnterNewTotalStack => 'Введите новый общий Stack';

  @override
  String get individualAddSubtractAmount => 'Добавить/Вычесть сумму';

  @override
  String get individualAmount => 'Сумма';

  @override
  String get individualSetTotal => 'Установить итог';

  @override
  String get individualNoteLabel => 'Примечание (необязательно)';

  @override
  String get individualNoteHint => 'например выиграл большой банк с AA';

  @override
  String get individualUpdateBlinds => 'Обновить Blinds';

  @override
  String get individualSmallBlind => 'Small Blind';

  @override
  String get individualBigBlind => 'Big Blind';

  @override
  String get individualBbMode => 'Режим BB';

  @override
  String get individualCurrentStackLabel => 'Текущий Stack';

  @override
  String get individualSessionInfo => 'Информация о сессии';

  @override
  String get individualStartingStack => 'Начальный Stack';

  @override
  String get individualInitialBuyIn => 'Начальный Buy-in';

  @override
  String get individualRebuys => 'Rebuys';

  @override
  String get individualTotalInvested => 'Всего вложено';

  @override
  String get individualBlindsLabel => 'Blinds';

  @override
  String get individualHandsLogged => 'Записано раздач';

  @override
  String get individualLogAHand => 'Записать раздачу';

  @override
  String get individualGoBackToHand => 'Вернуться к раздаче';

  @override
  String get individualStackChart => 'График Stack';

  @override
  String get individualCompleteHandToSee =>
      'Завершите раздачу, чтобы увидеть динамику Stack';

  @override
  String get individualStopSessionTitle => 'Остановить сессию?';

  @override
  String get individualStopSessionMessage =>
      'Вы уверены, что хотите остановить эту сессию? Все раздачи будут сохранены.';

  @override
  String get individualStop => 'Остановить';

  @override
  String get individualConfirmRebuy => 'Подтвердить Rebuy';

  @override
  String individualRebuyCurrentStack(String stack) {
    return 'У вас сейчас $stack.';
  }

  @override
  String get individualRebuyReplaceMessage =>
      'При Rebuy ваш текущий Stack будет заменён. Вы уверены, что хотите продолжить?';

  @override
  String get individualProceedWithRebuy => 'Продолжить Rebuy';

  @override
  String get individualAddOn => 'Доп. покупка';

  @override
  String get individualAddOnDescription =>
      'Введите сумму доп. покупки, чтобы увеличить общую инвестицию';

  @override
  String get individualAddOnAmount => 'Сумма Доп. покупки';

  @override
  String get individualAddOnConfirm => 'Добавить';

  @override
  String get individualAddOnDescriptionTournament =>
      'Введите цену доп. покупки и полученные фишки';

  @override
  String get individualAddOnPrice => 'Цена доп. покупки';

  @override
  String get individualAddOnChips => 'Полученные фишки';

  @override
  String get individualRebuy => 'Rebuy';

  @override
  String get individualEnterRebuyAmount =>
      'Введите сумму Rebuy (Stack будет равен сумме Rebuy)';

  @override
  String get individualEnterRebuyAmountAndStack =>
      'Введите сумму Rebuy и новый размер Stack';

  @override
  String get individualRebuyAmount => 'Сумма Rebuy';

  @override
  String get individualNewStackSize => 'Новый размер Stack';

  @override
  String get individualChipCountAfterRebuy => 'Количество фишек после Rebuy';

  @override
  String individualTotalInvestedAmount(String amount) {
    return 'Всего вложено: \$$amount';
  }

  @override
  String individualCurrentStackAmount(String stack) {
    return 'Текущий Stack: $stack';
  }

  @override
  String individualRebuysCount(int count) {
    return 'Rebuys: $count';
  }

  @override
  String get individualAddRebuy => 'Добавить Rebuy';

  @override
  String get individualPleaseEnterValidRebuy =>
      'Введите корректную сумму Rebuy';

  @override
  String get individualPleaseEnterValidStack =>
      'Введите корректный размер Stack';

  @override
  String individualRebuyAddedSimple(String amount) {
    return 'Rebuy добавлен: \$$amount';
  }

  @override
  String individualRebuyAddedWithStack(String amount, String stack) {
    return 'Rebuy добавлен: \$$amount (Stack: $stack)';
  }

  @override
  String get authWelcome => 'Добро пожаловать в Final Table';

  @override
  String get authSignIn => 'Войти';

  @override
  String get authRegister => 'Регистрация';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authDisplayName => 'Отображаемое имя';

  @override
  String get authConfirmPassword => 'Подтвердите пароль';

  @override
  String get authPleaseEnterEmail => 'Пожалуйста, введите email';

  @override
  String get authPleaseEnterValidEmail =>
      'Пожалуйста, введите корректный email';

  @override
  String get authPleaseEnterPassword => 'Пожалуйста, введите пароль';

  @override
  String get authPleaseEnterName => 'Пожалуйста, введите имя';

  @override
  String get authNameMinLength => 'Имя должно содержать минимум 2 символа';

  @override
  String get authPleaseEnterAPassword => 'Пожалуйста, введите пароль';

  @override
  String get authPasswordMinLength =>
      'Пароль должен содержать минимум 6 символов';

  @override
  String get authPleaseConfirmPassword => 'Пожалуйста, подтвердите пароль';

  @override
  String get authPasswordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get authCreateAccount => 'Создать аккаунт';

  @override
  String get authForgotPassword => 'Забыли пароль?';

  @override
  String get authResetPassword => 'Сбросить пароль';

  @override
  String get authResetPasswordMessage =>
      'Введите email для получения ссылки сброса пароля.';

  @override
  String get authSendResetLink => 'Отправить ссылку';

  @override
  String get authPasswordResetSent => 'Письмо для сброса пароля отправлено!';

  @override
  String get paywallRestore => 'Восстановить';

  @override
  String get paywallTitle => 'FINAL TABLE PREMIUM';

  @override
  String paywallUnlockFeature(String featureName) {
    return 'Разблокировать $featureName';
  }

  @override
  String get paywallGoPremium => 'Перейти на Premium';

  @override
  String get paywallFeatureSubtitle =>
      'Эта функция входит в Final Table Premium. Выберите план, который подходит вашей игре.';

  @override
  String get paywallGeneralSubtitle =>
      'Разблокируйте все возможности Final Table. Больше раздач, анализ игры, управление клубом.';

  @override
  String get paywallProTier => 'PRO';

  @override
  String get paywallFreeTrialBadge => '7 дней бесплатно';

  @override
  String get paywallProDescription =>
      'Всё, что нужно для совершенствования игры.';

  @override
  String get paywallUnlimitedHandLogging => 'Неограниченная запись раздач';

  @override
  String get paywallFullSessionHistory => 'Полная история сессий';

  @override
  String get paywallAiHandAnalysis => 'AI-анализ раздач';

  @override
  String get paywallExportHandsCsv => 'Экспорт раздач в CSV';

  @override
  String get paywallProMonthly => '\$19.99/мес.';

  @override
  String get paywallProYearly => '\$199.99/год';

  @override
  String get paywallStartFreeTrial => 'Начать 7-дневный пробный период';

  @override
  String get paywallEliteTier => 'ELITE';

  @override
  String get paywallEliteDescription => 'Поднимите свою игру на новый уровень.';

  @override
  String get paywallEverythingInProElite => 'Всё из Pro';

  @override
  String get paywallEliteFeature1 => 'Продвинутое профилирование оппонентов';

  @override
  String get paywallEliteFeature2 => 'Детальная аналитика сессий';

  @override
  String get paywallEliteFeature3 => 'Приоритетная поддержка';

  @override
  String get paywallEliteMonthly => '\$29.99/мес.';

  @override
  String get paywallEliteYearly => '\$249.99/год';

  @override
  String get paywallGetElite => 'Получить Elite';

  @override
  String get paywallClubTier => 'CLUB';

  @override
  String get paywallClubDescription =>
      'Для домашних игр, клубов и живых площадок.';

  @override
  String get paywallEverythingInPro => 'Всё из Pro';

  @override
  String get paywallClubManagement => 'Управление клубом и роли участников';

  @override
  String get paywallLiveDealerVoice => 'Голосовая запись Dealer';

  @override
  String get paywallMultiTableEvents => 'Мультистоловые турниры с рейтингами';

  @override
  String get paywallClubMonthly => '\$39.99/мес.';

  @override
  String get paywallClubYearly => '\$299.99/год';

  @override
  String get paywallGetClub => 'Получить Club';

  @override
  String get paywallDisclaimer =>
      'Подписки продлеваются автоматически. Отмена возможна в любое время в настройках аккаунта.';

  @override
  String get paywallTerms => 'Условия';

  @override
  String get paywallPrivacy => 'Конфиденциальность';

  @override
  String get paywallPurchasesRestored => 'Покупки восстановлены';

  @override
  String get paywallNoPreviousPurchases => 'Предыдущие покупки не найдены';

  @override
  String paywallComingSoon(String tier) {
    return 'Подписка $tier скоро появится';
  }

  @override
  String trialConfirmTitle(String tier) {
    return 'Первые 7 дней $tier — бесплатно';
  }

  @override
  String get trialConfirmTodayTitle => 'Сегодня';

  @override
  String trialConfirmTodayBody(String tier) {
    return 'Полный доступ ко всем функциям $tier';
  }

  @override
  String get trialConfirmReminderTitle => 'Через 5 дней';

  @override
  String get trialConfirmReminderBody =>
      'Напоминание перед окончанием пробного периода';

  @override
  String get trialConfirmStartTitle => 'Через 7 дней';

  @override
  String get trialConfirmStartBody =>
      'Начнётся подписка, если вы не отмените раньше';

  @override
  String get trialConfirmPriceSummary => 'Попробуйте 7 дней бесплатно, затем';

  @override
  String get trialConfirmStartCta => 'Начать 7-дневный бесплатный период';

  @override
  String get trialConfirmDisclaimer =>
      'Без оплаты. Отмените в любое время в App Store.';

  @override
  String get introGameSetup => 'Настройка игры';

  @override
  String get introConfigureSession => 'Настройте вашу сессию';

  @override
  String get introSmallBlind => 'Small Blind';

  @override
  String get introBigBlind => 'Big Blind';

  @override
  String get introPlayers => 'Игроки';

  @override
  String get introGameType => 'Тип игры';

  @override
  String get introBbAnte => 'BB Ante';

  @override
  String get introBbAnteDescription => 'Включить правило BB Ante';

  @override
  String get introStartGame => 'НАЧАТЬ ИГРУ';

  @override
  String get introStartingSession => 'Запуск покерной сессии...';

  @override
  String introEnterField(String title) {
    return 'Введите $title';
  }

  @override
  String get introEnterAmount => 'Введите сумму';

  @override
  String get introPleaseEnterValidNumber =>
      'Пожалуйста, введите корректное положительное число';

  @override
  String get introRingGame => 'Ring Game';

  @override
  String get introMultiTable => 'Multi-Table';

  @override
  String get invitationTitle => 'Приглашения в клуб';

  @override
  String get invitationNoPending => 'Нет ожидающих приглашений';

  @override
  String get invitationYouWillSeeHere =>
      'Приглашения от клубов будут отображаться здесь';

  @override
  String get invitationGoBack => 'Назад';

  @override
  String invitationFailedToLoad(String error) {
    return 'Не удалось загрузить приглашения: $error';
  }

  @override
  String invitationJoinedAs(String clubName, String role) {
    return 'Вы вступили в $clubName как $role';
  }

  @override
  String invitationFailedToAccept(String error) {
    return 'Не удалось принять приглашение: $error';
  }

  @override
  String get invitationDeclined => 'Приглашение отклонено';

  @override
  String invitationFailedToDecline(String error) {
    return 'Не удалось отклонить приглашение: $error';
  }

  @override
  String get invitationUnknownClub => 'Неизвестный клуб';

  @override
  String invitationInvitedBy(String name) {
    return 'Пригласил: $name';
  }

  @override
  String invitationExpiresDate(String date) {
    return 'Истекает $date';
  }

  @override
  String get invitationExpired => 'Истекло';

  @override
  String invitationExpiresInDays(int days) {
    return 'через $days дн.';
  }

  @override
  String invitationExpiresInHours(int hours) {
    return 'через $hours ч.';
  }

  @override
  String get invitationExpiresSoon => 'скоро';

  @override
  String get invitationDeclineButton => 'Отклонить';

  @override
  String get invitationAcceptButton => 'Принять';

  @override
  String get notificationTitle => 'Уведомления';

  @override
  String get notificationToday => 'Сегодня';

  @override
  String get notificationYesterday => 'Вчера';

  @override
  String get notificationThisWeek => 'На этой неделе';

  @override
  String get notificationEarlier => 'Ранее';

  @override
  String get notificationMarkAllRead => 'Отметить всё как прочитанное';

  @override
  String get notificationMarkAsRead => 'Отметить как прочитанное';

  @override
  String get notificationNoNotifications => 'Нет уведомлений';

  @override
  String get notificationEvents => 'Мероприятия';

  @override
  String get notificationRsvp => 'RSVP';

  @override
  String get notificationClubs => 'Клубы';

  @override
  String get notificationInvitations => 'Приглашения';

  @override
  String get notificationSeats => 'Места';

  @override
  String get notificationSupport => 'Поддержка';

  @override
  String get notificationClubNotFound => 'Клуб не найден';

  @override
  String get notificationEventNotFound => 'Мероприятие не найдено';

  @override
  String notificationError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String notificationErrorLoadingEvent(String error) {
    return 'Ошибка загрузки мероприятия: $error';
  }

  @override
  String notificationFailedToLoadClub(String error) {
    return 'Не удалось загрузить клуб: $error';
  }

  @override
  String get notificationClubInvitation => 'Приглашение в клуб';

  @override
  String get notificationInvitedToJoin => 'Вас пригласили присоединиться';

  @override
  String get notificationInvitationDeclined => 'Приглашение отклонено';

  @override
  String get notificationNotAuthenticated => 'Не авторизован';

  @override
  String get notificationInvitationAccepted => 'Приглашение принято';

  @override
  String notificationAcceptedMessage(String name, String clubName) {
    return '$name принял приглашение в $clubName.';
  }

  @override
  String get notificationInvitationDeclinedTitle => 'Приглашение отклонено';

  @override
  String notificationDeclinedMessage(String name, String clubName) {
    return '$name отклонил приглашение в $clubName.';
  }

  @override
  String get notificationRequestResolved => 'Запрос решён';

  @override
  String get notificationRequestClosed => 'Запрос закрыт';

  @override
  String get notificationResponse => 'Ответ';

  @override
  String get calendarTitle => 'Покерный календарь';

  @override
  String get calendarNewEvent => 'Новое мероприятие';

  @override
  String get calendarEventType => 'Тип мероприятия';

  @override
  String get calendarEventTitle => 'Название';

  @override
  String get calendarLocation => 'Место';

  @override
  String get calendarBuyInAmount => 'Сумма Buy-in';

  @override
  String get calendarEventDateTime => 'Дата и время мероприятия';

  @override
  String get calendarStarts => 'Начало';

  @override
  String get calendarSelectDate => 'Выберите дату:';

  @override
  String get calendarReset => 'Сброс';

  @override
  String get calendarSun => 'ВС';

  @override
  String get calendarMon => 'ПН';

  @override
  String get calendarTue => 'ВТ';

  @override
  String get calendarWed => 'СР';

  @override
  String get calendarThu => 'ЧТ';

  @override
  String get calendarFri => 'ПТ';

  @override
  String get calendarSat => 'СБ';

  @override
  String get calendarNoRecentEvents => 'Нет недавних мероприятий';

  @override
  String get calendarAddFirstEvent =>
      'Добавьте ваше первое покерное мероприятие!';

  @override
  String get calendarAddNewEvent => 'Добавить мероприятие';

  @override
  String get calendarSelectYear => 'Выберите год';

  @override
  String get calendarEditEvent => 'Редактировать мероприятие';

  @override
  String get calendarDeleteEvent => 'Удалить мероприятие';

  @override
  String get calendarTournament => 'Tournament';

  @override
  String get calendarCashGame => 'Cash Game';

  @override
  String get calendarPrivateGame => 'Приватная игра';

  @override
  String get calendarOnline => 'Онлайн';

  @override
  String calendarFailedToCreateEvent(String error) {
    return 'Не удалось создать мероприятие: $error';
  }

  @override
  String calendarFailedToUpdateEvent(String error) {
    return 'Не удалось обновить мероприятие: $error';
  }

  @override
  String get calendarFailedToDeleteEvent => 'Не удалось удалить мероприятие';

  @override
  String get calendarClubNotFound => 'Клуб не найден';

  @override
  String get calendarEventNotFound => 'Мероприятие не найдено';

  @override
  String calendarFailedToLoadEvent(String error) {
    return 'Не удалось загрузить мероприятие: $error';
  }

  @override
  String calendarDeleteConfirmTitle(String title) {
    return 'Удалить $title?';
  }

  @override
  String calendarDeleteConfirmMessage(String title) {
    return 'Вы уверены, что хотите удалить \"$title\"?\nЭто действие нельзя отменить.';
  }

  @override
  String get sessionAnalyticsTitle => 'Аналитика сессии';

  @override
  String sessionAnalyticsHandsLogged(int count) {
    return '$count раздач записано';
  }

  @override
  String get sessionAnalyticsDeleteTitle => 'Удалить сессию?';

  @override
  String get sessionAnalyticsDeleteMessage =>
      'Это навсегда удалит эту сессию, включая всю историю раздач, данные графика Stack и отчёты AI-анализа. Это действие нельзя отменить.';

  @override
  String get sessionAnalyticsDeleted => 'Сессия удалена';

  @override
  String get sessionAnalyticsFailedToDelete => 'Не удалось удалить сессию';

  @override
  String get sessionAnalyticsExportSession => 'Экспорт сессии';

  @override
  String sessionAnalyticsExportConfirm(int count, String email) {
    return 'Экспортировать $count раздач на $email?';
  }

  @override
  String get sessionAnalyticsExport => 'Экспорт';

  @override
  String sessionAnalyticsExportSent(String email) {
    return 'Экспорт отправлен на $email';
  }

  @override
  String sessionAnalyticsExportFailed(String error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get sessionAnalyticsNoEmailFound =>
      'Email не найден. Пожалуйста, войдите с учётной записью email.';

  @override
  String get sessionAnalyticsPokerSession => 'Покерная сессия';

  @override
  String get sessionAnalyticsTotalInvested => 'Всего вложено';

  @override
  String get sessionAnalyticsFinalStack => 'Финальный Stack';

  @override
  String get sessionAnalyticsCashout => 'Выплата';

  @override
  String get sessionAnalyticsProfitLoss => 'Прибыль/Убыток';

  @override
  String get sessionAnalyticsAvgGrowth => 'Средний рост';

  @override
  String get sessionAnalyticsHourlyRate => 'Часовая ставка';

  @override
  String get sessionAnalyticsFinished => 'Место';

  @override
  String get sessionAnalyticsDuration => 'Продолжительность';

  @override
  String get sessionAnalyticsRebuys => 'Rebuys';

  @override
  String get sessionAnalyticsAddons => 'Add-ons';

  @override
  String get sessionAnalyticsStackChart => 'График Stack';

  @override
  String get sessionAnalyticsNoStackHistory => 'История Stack недоступна';

  @override
  String get sessionAnalyticsStackTrackedFuture =>
      'Изменения Stack будут отслеживаться в будущих сессиях';

  @override
  String get sessionAnalyticsViewLoggedHands =>
      'Просмотреть записанные раздачи';

  @override
  String get sessionAnalyticsStart => 'Начало';

  @override
  String get sessionAnalyticsRebuy => 'Rebuy';

  @override
  String get sessionAnalyticsEnd => 'Конец';

  @override
  String get seatSetupTitle => 'Настройка мест';

  @override
  String get seatSetupManagePlayers => 'Управление игроками';

  @override
  String get seatSetupClickToConfig =>
      'Нажмите на место для настройки. Перетащите кнопку для позиции';

  @override
  String get seatSetupButtonLocked =>
      'Кнопка заблокирована — раздача в процессе';

  @override
  String get seatSetupUpdatePlayerInfo => 'Обновить информацию об игроке';

  @override
  String get seatSetupEmpty => 'Пусто';

  @override
  String get seatSetupThisIsMySeat => 'Это моё место';

  @override
  String get seatSetupPlayerName => 'Имя игрока';

  @override
  String get seatSetupBuyInAmount => 'Сумма Buy-in (\$)';

  @override
  String get seatSetupStartingChips => 'Начальные фишки';

  @override
  String seatSetupSaveAsOpponent(String name) {
    return 'Сохранить \"$name\" как оппонента?';
  }

  @override
  String get seatSetupOpponentSaved => 'Оппонент сохранён!';

  @override
  String seatSetupFailedToSave(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get seatSetupNoData => 'Нет данных';

  @override
  String get seatSetupStartSession => 'Начать сессию';

  @override
  String get seatSetupSaveChanges => 'Сохранить изменения';

  @override
  String get seatSetupPleaseSelectSeat => 'Пожалуйста, выберите своё место';

  @override
  String seatSetupSeatNumber(int number) {
    return 'Место $number';
  }

  @override
  String seatSetupPlayerDefault(int number) {
    return 'Игрок $number';
  }

  @override
  String get quickStackTitle => 'Обновить Stack и кнопку';

  @override
  String quickStackBlinds(String blinds) {
    return 'Blinds: $blinds';
  }

  @override
  String get quickStackInstruction =>
      'Нажмите на Stack для редактирования  •  Проведите для корректировки  •  Нажмите D для кнопки';

  @override
  String get quickStackContinue => 'ПРОДОЛЖИТЬ ЗАПИСЬ РАЗДАЧИ';

  @override
  String get quickStackEditStack => 'Редактировать Stack';

  @override
  String get quickStackStackInBb => 'Stack в BB';

  @override
  String quickStackCurrentValue(String bbValue, String chipValue) {
    return 'Текущее: $bbValue BB = $chipValue';
  }

  @override
  String get quickStackValidationError => 'Введите значение от 0 до 1000 BB';

  @override
  String quickStackSeat(int number) {
    return 'Место $number';
  }

  @override
  String get quickStackEmpty => 'Пусто';

  @override
  String quickStackPlayerDefault(int id) {
    return 'Игрок $id';
  }

  @override
  String get handReviewTitle => 'Обзор раздачи';

  @override
  String get handReviewYourHoleCards => 'Ваши карты';

  @override
  String get handReviewOptional => '(необязательно)';

  @override
  String get handReviewQuickTags => 'Быстрые теги';

  @override
  String get handReviewTagBluff => 'Bluff';

  @override
  String get handReviewTagValue => 'Value';

  @override
  String get handReviewTagMistake => 'Ошибка';

  @override
  String get handReviewTagCooler => 'Cooler';

  @override
  String get handReviewTagHeroCall => 'Hero Call';

  @override
  String get handReviewTagExploit => 'Exploit';

  @override
  String get handReviewNotes => 'Заметки';

  @override
  String get handReviewNotesHint => 'Добавить заметку к этой раздаче...';

  @override
  String get handReviewSaveHand => 'Сохранить раздачу';

  @override
  String get handReviewSkip => 'Пропустить';

  @override
  String get handReviewDuplicateCardError =>
      'Нельзя выбрать одну и ту же карту дважды!';

  @override
  String get handReviewSelectBothOrNone =>
      'Выберите обе карты или оставьте обе пустыми';

  @override
  String get holeCardsTitle => 'Ваши карты';

  @override
  String get holeCardsSubtitle => 'Hole Cards';

  @override
  String get holeCardsWinnerBadge => 'ПОБЕДИТЕЛЬ';

  @override
  String get holeCardsSave => 'Сохранить';

  @override
  String get holeCardsSkip => 'Пропустить';

  @override
  String get holeCardsSkipAllRemaining => 'Пропустить все оставшиеся';

  @override
  String get holeCardsDuplicateCardError =>
      'Нельзя выбрать одну и ту же карту дважды!';

  @override
  String get holeCardsSelectBothOrSkip => 'Выберите обе карты или пропустите';

  @override
  String get holeCardsClearAll => 'Очистить всё';

  @override
  String get showdownTitle => 'Showdown';

  @override
  String get showdownEnterOpponentCards =>
      'Введите карты оппонентов на Showdown:';

  @override
  String showdownPlayerLabel(int seatNumber) {
    return 'Игрок $seatNumber';
  }

  @override
  String get showdownCard1 => 'Карта 1';

  @override
  String get showdownCard2 => 'Карта 2';

  @override
  String get showdownClear => 'Очистить';

  @override
  String get showdownWinner => 'Победитель:';

  @override
  String get showdownHandDescriptionLabel => 'Описание руки (необязательно)';

  @override
  String get showdownHandDescriptionHint =>
      'напр., \"Стрит-флеш\", \"Фулл-хаус тузы и короли\"';

  @override
  String get showdownSkip => 'Пропустить';

  @override
  String get showdownSave => 'Сохранить';

  @override
  String get showdownSelectCard => 'Выберите карту';

  @override
  String get tableManagementSectionTitle => 'СТОЛ';

  @override
  String tableManagementPlayersCount(int count) {
    return '$count игроков';
  }

  @override
  String get tableManagementDealerButton => 'Кнопка Dealer';

  @override
  String get tableManagementAddPlayer => 'Добавить игрока';

  @override
  String tableManagementYouSuffix(String name) {
    return '$name (Вы)';
  }

  @override
  String get tableManagementAdjustStack => 'Изменить Stack';

  @override
  String get tableManagementRebuy => 'Rebuy';

  @override
  String get tableManagementRemove => 'Удалить';

  @override
  String get tableManagementAdjustStackTitle => 'Изменить Stack';

  @override
  String get tableManagementEnterStackAmount => 'Введите размер Stack';

  @override
  String get tableManagementRebuyTitle => 'Rebuy';

  @override
  String get tableManagementRebuyAmountHint => 'Сумма Rebuy для добавления';

  @override
  String get tableManagementAdd => 'Добавить';

  @override
  String get tableManagementRemovePlayerTitle => 'Удалить игрока?';

  @override
  String tableManagementRemovePlayerMessage(String playerName) {
    return 'Удалить $playerName со стола?';
  }

  @override
  String tableManagementAddPlayerSeatTitle(int seatNumber) {
    return 'Добавить игрока — Место $seatNumber';
  }

  @override
  String get tableManagementThisIsMe => 'Это я';

  @override
  String get tableManagementNameLabel => 'Имя';

  @override
  String get tableManagementSearchOrEnterName => 'Найти или ввести имя';

  @override
  String tableManagementSaveAsOpponent(String name) {
    return 'Сохранить \"$name\" как оппонента';
  }

  @override
  String tableManagementSavedAsOpponent(String name) {
    return '$name сохранён как оппонент';
  }

  @override
  String get tableManagementStartingStack => 'Начальный Stack';

  @override
  String get tableManagementStackAmountHint => 'Размер Stack';

  @override
  String get tableManagementMoveMeHere => 'Пересадить меня сюда';

  @override
  String tableManagementSeatLabel(int seatNumber) {
    return 'Место $seatNumber';
  }

  @override
  String get seatConfigRemove => 'Удалить';

  @override
  String get seatConfigThisIsMe => 'Это я';

  @override
  String get seatConfigNameLabel => 'Имя';

  @override
  String get seatConfigSearchOrEnterName => 'Найти или ввести имя';

  @override
  String seatConfigSaveAsOpponent(String name) {
    return 'Сохранить \"$name\" как оппонента';
  }

  @override
  String seatConfigSavedAsOpponent(String name) {
    return '$name сохранён как оппонент';
  }

  @override
  String seatConfigSeatTitle(int seatNumber) {
    return 'Место $seatNumber';
  }

  @override
  String get seatConfigStackLabel => 'Stack';

  @override
  String get seatConfigUpdateButton => 'Обновить';

  @override
  String get seatConfigAddPlayerButton => 'Добавить игрока';

  @override
  String get seatManagementSetupSeats => 'Настройка мест';

  @override
  String get seatManagementManagePlayers => 'Управление игроками';

  @override
  String get seatManagementChooseSeatSubtitle =>
      'Выберите своё место и настройте стол';

  @override
  String get seatManagementUpdatePlayerSubtitle =>
      'Обновить информацию об игроке';

  @override
  String get seatManagementButtonPosition => 'Позиция кнопки';

  @override
  String seatManagementSeatLabel(int seatNumber) {
    return 'Место $seatNumber';
  }

  @override
  String get seatManagementEmpty => 'Пусто';

  @override
  String get seatManagementActive => 'Активен';

  @override
  String get seatManagementPlayerNameLabel => 'Имя игрока';

  @override
  String get seatManagementEnterPlayerName => 'Введите имя игрока';

  @override
  String get seatManagementBuyInAmountCash => 'Сумма Buy-in (\$)';

  @override
  String get seatManagementStartingChips => 'Начальные фишки';

  @override
  String get seatManagementSaveOpponentTitle => 'Сохранить оппонента?';

  @override
  String seatManagementSaveOpponentMessage(String name) {
    return 'Хотите сохранить \"$name\" в список оппонентов для отслеживания?';
  }

  @override
  String get seatManagementNotNow => 'Не сейчас';

  @override
  String seatManagementSaveAsOpponentPrompt(String name) {
    return 'Сохранить \"$name\" как оппонента?';
  }

  @override
  String seatManagementOpponentSavedSuccess(String name) {
    return 'Оппонент \"$name\" сохранён!';
  }

  @override
  String seatManagementFailedToSaveOpponent(String error) {
    return 'Не удалось сохранить оппонента: $error';
  }

  @override
  String get seatManagementStartSession => 'Начать сессию';

  @override
  String get seatManagementSaveChanges => 'Сохранить изменения';

  @override
  String get seatManagementSelectYourSeat => 'Пожалуйста, выберите своё место';

  @override
  String get inviteMemberTitle => 'Пригласить участника';

  @override
  String get inviteMemberEmailLabel => 'EMAIL АДРЕС';

  @override
  String get inviteMemberEmailHint => 'Введите email адрес';

  @override
  String get inviteMemberEmailRequired => 'Пожалуйста, введите email адрес';

  @override
  String get inviteMemberEmailInvalid =>
      'Пожалуйста, введите корректный email адрес';

  @override
  String get inviteMemberRoleLabel => 'РОЛЬ';

  @override
  String get inviteMemberRoleDealer => 'Dealer';

  @override
  String get inviteMemberRoleAdmin => 'Администратор';

  @override
  String get inviteMemberSendInvite => 'Отправить приглашение';

  @override
  String inviteMemberAlreadyMember(String displayName, String clubName) {
    return '$displayName уже является участником $clubName';
  }

  @override
  String get inviteMemberAddedNotificationTitle => 'Вас добавили в клуб!';

  @override
  String inviteMemberAddedNotificationBody(
      String inviterName, String clubName, String role) {
    return '$inviterName добавил вас в \"$clubName\" как $role.';
  }

  @override
  String get inviteMemberAddedSuccessTitle => 'Участник добавлен!';

  @override
  String inviteMemberAddedSuccessMessage(
      String displayName, String clubName, String role) {
    return '$displayName добавлен в $clubName как $role.';
  }

  @override
  String get inviteMemberInvitationSentTitle => 'Приглашение отправлено!';

  @override
  String inviteMemberInvitationSentMessage(String email, String clubName) {
    return 'Приглашение отправлено на $email. После регистрации они смогут присоединиться к $clubName.';
  }

  @override
  String inviteMemberError(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get inviteMemberRoleAnAdmin => 'администратор';

  @override
  String get inviteMemberRoleADealer => 'Dealer';

  @override
  String get registerClubTitle => 'Регистрация клуба';

  @override
  String get registerClubNameLabel => 'Название клуба';

  @override
  String get registerClubNamePlaceholder => 'напр., Lucky Aces Poker Club';

  @override
  String get registerClubNameRequired => 'Пожалуйста, введите название клуба';

  @override
  String get registerClubAddressLabel => 'Адрес';

  @override
  String get registerClubAddressPlaceholder => 'напр., ул. Главная, 123, Город';

  @override
  String get registerClubAddressRequired => 'Пожалуйста, введите адрес клуба';

  @override
  String get registerClubPhoneLabel => 'Номер телефона';

  @override
  String get registerClubPhonePlaceholder => 'напр., +7 555-123-4567';

  @override
  String get registerClubPhoneRequired => 'Пожалуйста, введите номер телефона';

  @override
  String get registerClubAdminEmailLabel => 'Email администратора клуба';

  @override
  String get registerClubAdminEmailPlaceholder => 'напр., admin@myclub.com';

  @override
  String get registerClubAdminEmailRequired =>
      'Пожалуйста, введите email администратора';

  @override
  String get registerClubAdminEmailInvalid =>
      'Пожалуйста, введите корректный email';

  @override
  String get registerClubInfoMessage =>
      'Этот человек будет уведомлён, когда клуб будет одобрен, и станет владельцем клуба.';

  @override
  String get registerClubSubmitRequest => 'Отправить запрос';

  @override
  String registerClubFailedToSubmit(String error) {
    return 'Не удалось отправить запрос: $error';
  }

  @override
  String get registerClubSuccessTitle => 'Запрос отправлен!';

  @override
  String registerClubSuccessMessage(String email) {
    return 'Ваш запрос на регистрацию клуба отправлен. Мы уведомим вас на $email после рассмотрения.';
  }

  @override
  String get registerClubGotIt => 'Понятно';

  @override
  String get loggingModeChooseMode => 'Выберите режим';

  @override
  String get loggingModeFullTitle => 'Полная запись';

  @override
  String get loggingModeFullSubtitle => 'Полное отслеживание сессии';

  @override
  String get loggingModeFullFeature1 => 'Многораздачная сессия';

  @override
  String get loggingModeFullFeature2 => 'Статистика в реальном времени';

  @override
  String get loggingModeFullFeature3 => 'Детальная история раздач';

  @override
  String get loggingModeFullFeature4 => 'Аналитика сессии';

  @override
  String get loggingModeIndividualTitle => 'Быстрая сессия';

  @override
  String get loggingModeIndividualSubtitle => 'Запись отдельных раздач';

  @override
  String get loggingModeIndividualFeature1 => 'Фокус на одной раздаче';

  @override
  String get loggingModeIndividualFeature2 => 'Быстрая запись';

  @override
  String get loggingModeIndividualFeature3 => 'Анализ раздачи';

  @override
  String get loggingModeIndividualFeature4 => 'Мгновенные результаты';

  @override
  String get loggingModeFeatures => 'Возможности';

  @override
  String get loggingModeStart => 'Начать';

  @override
  String get earningsChartAllTimeEarnings => 'Доход за всё время';

  @override
  String earningsChartSinceDate(String date) {
    return 'С $date';
  }

  @override
  String get earningsChartTournament => 'Tournament';

  @override
  String get earningsChartCash => 'Cash';

  @override
  String get earningsChartNoData => 'Данных о доходах пока нет';

  @override
  String get earningsChartNoDataSubtitle =>
      'Завершите несколько сессий, чтобы увидеть график доходов';

  @override
  String get earningsChartMtt => 'MTT';

  @override
  String get opponentHandsTitle => 'История раздач';

  @override
  String opponentHandsCount(int count) {
    return '$count раздач';
  }

  @override
  String get opponentHandsLoading => 'Загрузка истории раздач...';

  @override
  String get opponentHandsError => 'Что-то пошло не так';

  @override
  String get opponentHandsRetry => 'Повторить';

  @override
  String get opponentHandsNoHandsTitle => 'Раздачи не найдены';

  @override
  String opponentHandsNoHandsSubtitle(String name) {
    return 'Вы ещё не играли раздач\nс $name.';
  }

  @override
  String get opponentHandsOppWon => 'ОПП ВЫИГРАЛ';

  @override
  String get opponentHandsYou => 'Вы';

  @override
  String opponentHandsPot(String amount) {
    return 'Pot $amount';
  }

  @override
  String get opponentHandsUnknownSession => 'Неизвестная сессия';

  @override
  String get clubDashboardLive => 'Live';

  @override
  String get clubDashboardUpcoming => 'Предстоящие';

  @override
  String get clubDashboardPast => 'Прошедшие';

  @override
  String get clubDashboardNoLiveEvents => 'Нет активных мероприятий';

  @override
  String get clubDashboardNoUpcomingEvents => 'Нет предстоящих мероприятий';

  @override
  String get clubDashboardNoPastEvents => 'Нет прошедших мероприятий';

  @override
  String get clubDashboardAdmin => 'Админ';

  @override
  String get clubDashboardCreateEventHint =>
      'Нажмите кнопку ниже, чтобы создать мероприятие';

  @override
  String get clubDashboardCheckBackLater =>
      'Загляните позже для новых мероприятий';

  @override
  String get clubDashboardEventsWillAppear =>
      'Мероприятия появятся здесь, когда начнутся';

  @override
  String get clubDashboardPastEventsWillAppear =>
      'Завершённые мероприятия появятся здесь';

  @override
  String clubDashboardCashGameStakes(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get clubDashboardCash => 'Cash';

  @override
  String get clubDashboardTables => 'Столы';

  @override
  String get clubDashboardStakes => 'Ставки';

  @override
  String clubDashboardPlayingCount(int count) {
    return '$count играют';
  }

  @override
  String clubDashboardMemberCount(int count) {
    return '$count участников';
  }

  @override
  String get clubSettingsTitle => 'Настройки клуба';

  @override
  String get clubSettingsClubInfo => 'Информация о клубе';

  @override
  String get clubSettingsClubName => 'Название клуба';

  @override
  String get clubSettingsAddress => 'Адрес';

  @override
  String get clubSettingsPhone => 'Телефон';

  @override
  String get clubSettingsDescription => 'Описание';

  @override
  String get clubSettingsSaveChanges => 'Сохранить изменения';

  @override
  String get clubSettingsInfoSaved => 'Информация о клубе сохранена';

  @override
  String clubSettingsErrorSaving(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get clubSettingsNoTablesYet => 'Столов пока нет';

  @override
  String get clubSettingsAddTableHint => 'Добавьте стол, чтобы начать';

  @override
  String clubSettingsErrorLoading(String error) {
    return 'Ошибка загрузки данных: $error';
  }

  @override
  String get eventEditTitle => 'Редактировать мероприятие';

  @override
  String get eventNewTitle => 'Новое мероприятие';

  @override
  String get eventNoTablesAssigned => 'Столы не назначены';

  @override
  String get eventNoTablesAssignedDesc =>
      'Этому мероприятию не назначены столы. Пожалуйста, вернитесь и назначьте столы.';

  @override
  String get eventGoBack => 'Назад';

  @override
  String get eventContinue => 'Продолжить';

  @override
  String get eventNameOptional => 'Название мероприятия (необязательно)';

  @override
  String get eventNameLabel => 'Название мероприятия';

  @override
  String get eventStakesHint => 'Ставки (напр. 1/2)';

  @override
  String get eventBuyInAmount => 'Сумма Buy-in';

  @override
  String get eventMinBuyIn => 'Мин. Buy-in (\$)';

  @override
  String get eventStartingStack => 'Начальный Stack';

  @override
  String get eventGameType => 'Тип игры';

  @override
  String get eventTournament => 'Tournament';

  @override
  String get eventCashGame => 'Cash Game';

  @override
  String get eventDateAndTime => 'Дата и время мероприятия';

  @override
  String get eventStarts => 'Начало';

  @override
  String get eventTables => 'Столы';

  @override
  String get eventDeselectAll => 'Снять выделение';

  @override
  String get eventSelectAll => 'Выбрать все';

  @override
  String get eventAllTablesInUse => 'Все столы заняты текущими мероприятиями';

  @override
  String get eventNoTablesConfigured => 'Столы ещё не настроены';

  @override
  String get eventDescriptionLabel => 'Описание';

  @override
  String get eventNotifyMembers => 'Уведомить участников';

  @override
  String get eventNotifyMembersSubtitle =>
      'Отправить уведомление всем участникам клуба';

  @override
  String get eventDeleteEvent => 'Удалить мероприятие';

  @override
  String get eventDeleteConfirmTitle => 'Удалить мероприятие?';

  @override
  String get eventDeleteConfirmBody =>
      'Это навсегда удалит мероприятие и все связанные данные. Это действие нельзя отменить.';

  @override
  String eventDeleteFailed(String error) {
    return 'Не удалось удалить мероприятие: $error';
  }

  @override
  String get eventAttendeesTitle => 'Участники';

  @override
  String eventAttendeesGoing(int count) {
    return 'Придут ($count)';
  }

  @override
  String eventAttendeesMaybe(int count) {
    return 'Возможно ($count)';
  }

  @override
  String eventAttendeesNo(int count) {
    return 'Нет ($count)';
  }

  @override
  String get eventAttendeesNoConfirmed => 'Пока никто не подтвердил';

  @override
  String get eventAttendeesNoMaybes => 'Нет сомневающихся';

  @override
  String get eventAttendeesNoDeclines => 'Нет отказов';

  @override
  String get eventDetailLiveNow => 'Мероприятие сейчас LIVE!';

  @override
  String get eventDetailEnded => 'Мероприятие завершено';

  @override
  String get eventDetailCancelled => 'Мероприятие отменено';

  @override
  String get eventDetailPaused => 'Мероприятие на паузе';

  @override
  String get eventDetailStatusUpdated => 'Статус мероприятия обновлён';

  @override
  String get eventDetailRemovedFromCalendar =>
      'Мероприятие удалено из вашего календаря';

  @override
  String get eventDetailRsvpGoing => 'Приду';

  @override
  String get eventDetailRsvpMaybe => 'Возможно';

  @override
  String get eventDetailRsvpCantGo => 'Не смогу';

  @override
  String eventDetailRsvpFailed(String error) {
    return 'Не удалось обновить RSVP: $error';
  }

  @override
  String get eventDetailCantStartTitle => 'Невозможно начать мероприятие';

  @override
  String get eventDetailCantStartBody =>
      'Этому мероприятию не назначены столы. Пожалуйста, сначала добавьте столы.';

  @override
  String get eventDetailStarted => 'Мероприятие начато!';

  @override
  String eventDetailStartFailed(String error) {
    return 'Не удалось начать мероприятие: $error';
  }

  @override
  String get eventDetailFinishTitle => 'Завершить мероприятие?';

  @override
  String get eventDetailCancelTitle => 'Отменить мероприятие?';

  @override
  String get eventDetailFinishBody =>
      'Это завершит все активные столы и зафиксирует результаты.';

  @override
  String get eventDetailCancelBody =>
      'Это уведомит всех участников и отменит мероприятие.';

  @override
  String get eventDetailFinishButton => 'Завершить мероприятие';

  @override
  String get eventDetailCancelButton => 'Отменить мероприятие';

  @override
  String get eventDetailKeepEvent => 'Оставить мероприятие';

  @override
  String get eventDetailLiveBadge => 'LIVE';

  @override
  String get eventDetailCancelledBadge => 'ОТМЕНЕНО';

  @override
  String get eventDetailCompletedBadge => 'ЗАВЕРШЕНО';

  @override
  String get eventDetailUpcomingBadge => 'ПРЕДСТОЯЩЕЕ';

  @override
  String get eventDetailLocation => 'Место';

  @override
  String get eventDetailBuyIn => 'Buy-in';

  @override
  String get eventDetailStakes => 'Ставки';

  @override
  String get eventDetailStartingStack => 'Начальный Stack';

  @override
  String get eventDetailAbout => 'О МЕРОПРИЯТИИ';

  @override
  String get eventDetailAddedToCalendar =>
      'Мероприятие добавлено в ваш календарь!';

  @override
  String eventDetailCalendarFailed(String error) {
    return 'Не удалось добавить в календарь: $error';
  }

  @override
  String get eventManagementEventsTitle => 'Мероприятия';

  @override
  String get eventManagementNewEvent => 'Новое мероприятие';

  @override
  String get eventManagementNoEvents => 'Нет мероприятий';

  @override
  String get eventManagementNoEventsSubtitle =>
      'Создайте мероприятие для отслеживания рейтингов в реальном времени';

  @override
  String get eventManagementActiveEvents => 'Активные мероприятия';

  @override
  String get eventManagementPastEvents => 'Прошедшие мероприятия';

  @override
  String eventManagementErrorLoading(String error) {
    return 'Ошибка загрузки мероприятий: $error';
  }

  @override
  String get eventManagementNoTables =>
      'Нет доступных столов. Сначала создайте столы.';

  @override
  String eventManagementCreated(String name) {
    return 'Мероприятие \"$name\" создано';
  }

  @override
  String eventManagementCreateFailed(String error) {
    return 'Не удалось создать мероприятие: $error';
  }

  @override
  String get eventManagementEndEvent => 'Завершить мероприятие';

  @override
  String eventManagementEndConfirm(String name) {
    return 'Вы уверены, что хотите завершить \"$name\"?';
  }

  @override
  String eventManagementEnded(String name) {
    return 'Мероприятие \"$name\" завершено';
  }

  @override
  String eventManagementEndFailed(String error) {
    return 'Не удалось завершить мероприятие: $error';
  }

  @override
  String get eventManagementLinkCopied => 'Ссылка скопирована';

  @override
  String get eventManagementShare => 'Поделиться';

  @override
  String get eventManagementPause => 'Пауза';

  @override
  String get eventManagementResume => 'Возобновить';

  @override
  String get eventManagementEnd => 'Завершить';

  @override
  String get eventManagementCreateEvent => 'Создать мероприятие';

  @override
  String get eventManagementEventNameHint => 'напр., Пятничный турнир';

  @override
  String get eventManagementSelectTables => 'Выбрать столы';

  @override
  String eventManagementTableNumber(int number) {
    return 'Стол $number';
  }

  @override
  String get eventManagementPublicEvent => 'Публичное мероприятие';

  @override
  String get eventManagementPublicSubtitle =>
      'Все могут видеть таблицу лидеров';

  @override
  String get eventManagementAccessCode => 'Код доступа (необязательно)';

  @override
  String get eventManagementAccessCodeSubtitle =>
      'Для обмена с конкретными пользователями';

  @override
  String get eventManagementEnterName =>
      'Пожалуйста, введите название мероприятия';

  @override
  String get eventManagementSelectTable =>
      'Пожалуйста, выберите хотя бы один стол';

  @override
  String get eventManagementPublic => 'Публичное';

  @override
  String get eventManagementPrivate => 'Приватное';

  @override
  String adminEventTablesSummary(int count, int occupied, int open) {
    return '$count столов • $occupied сидят • $open свободных';
  }

  @override
  String get adminEventTablesAddTable => 'Добавить стол';

  @override
  String get adminEventTablesNoTables => 'Нет доступных столов для добавления';

  @override
  String adminEventTablesCloseConfirm(String tableName) {
    return 'Закрыть $tableName?';
  }

  @override
  String adminEventTablesCloseWithPlayers(int count) {
    return 'Это переместит $count игрок(ов) в список ожидания и удалит стол из мероприятия.';
  }

  @override
  String get adminEventTablesCloseEmpty => 'Это удалит стол из мероприятия.';

  @override
  String get adminEventTablesCloseButton => 'Закрыть стол';

  @override
  String adminEventTablesTableAdded(String tableName) {
    return '$tableName добавлен к мероприятию';
  }

  @override
  String adminEventTablesClosedWithWaitlist(String tableName, int count) {
    return '$tableName закрыт. $count игрок(ов) перемещены в список ожидания.';
  }

  @override
  String adminEventTablesClosed(String tableName) {
    return '$tableName закрыт.';
  }

  @override
  String get adminEventTablesNoWaitlist => 'Список ожидания пуст';

  @override
  String adminEventTablesWaitlistCount(int count) {
    return '$count в списке ожидания';
  }

  @override
  String adminEventTablesWaitlistNext(String name) {
    return 'Следующий: $name';
  }

  @override
  String get adminEventTablesWaitlist => 'Список ожидания';

  @override
  String get adminEventTablesNotified => 'Уведомлён';

  @override
  String get adminEventTablesNotify => 'Уведомить';

  @override
  String get adminEventTablesSeat => 'Посадить';

  @override
  String adminEventTablesSeatAt(String tableName, int count) {
    return '$tableName ($count свободных)';
  }

  @override
  String get adminEventTablesNoEmptySeats =>
      'Нет свободных мест за этим столом';

  @override
  String adminEventTablesPlayerSeated(String name, String tableName) {
    return '$name посажен за $tableName';
  }

  @override
  String adminEventTablesPlayerNotified(String name) {
    return '$name уведомлён';
  }

  @override
  String get adminTableSeatPlayer => 'Посадить игрока';

  @override
  String get adminTableFromWaitlist => 'Из списка ожидания';

  @override
  String adminTableWaitlistNextIs(String name) {
    return 'Следующий: $name';
  }

  @override
  String get adminTableClubMember => 'Участник клуба';

  @override
  String get adminTableSearchMembers => 'Поиск среди участников';

  @override
  String get adminTableWalkUpPlayer => 'Новый игрок';

  @override
  String get adminTableAddByName => 'Добавить по имени';

  @override
  String get adminTableSelectMember => 'Выбрать участника';

  @override
  String get adminTableSearch => 'Поиск...';

  @override
  String get adminTablePlayerName => 'Имя игрока';

  @override
  String adminTableWaitingForApproval(int seatNumber) {
    return 'Ожидает одобрения на место #$seatNumber';
  }

  @override
  String get adminTableReject => 'Отклонить';

  @override
  String get adminTableApprove => 'Одобрить';

  @override
  String get adminTableRemove => 'Удалить';

  @override
  String adminTableSeatNumber(int seatNumber) {
    return 'Место #$seatNumber';
  }

  @override
  String get adminTableNoEmptySeats => 'Нет свободных мест';

  @override
  String adminTableSeatPlayerName(String name) {
    return 'Посадить $name';
  }

  @override
  String get adminTableSelectSeat => 'Выберите место:';

  @override
  String adminTablePlayerSeated(String name) {
    return '$name посажен';
  }

  @override
  String adminTableAlreadySeated(String name, String location) {
    return '$name уже сидит за $location';
  }

  @override
  String adminTablePlayerApproved(String name) {
    return '$name одобрен';
  }

  @override
  String get adminTablePlayerRejected => 'Игрок отклонён';

  @override
  String get adminTablePlayerRemoved => 'Игрок удалён';

  @override
  String adminTableWaitlistInCount(int count) {
    return '$count в списке ожидания';
  }

  @override
  String adminTableWaitlistNextName(String name) {
    return 'Следующий: $name';
  }

  @override
  String adminTableNotifiedName(String name) {
    return '$name уведомлён';
  }

  @override
  String clubCashGameStakes(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String clubCashGameTablesSummary(int count, int occupied, int open) {
    return '$count столов · $occupied сидят · $open свободных';
  }

  @override
  String clubCashGameTableNumber(int number) {
    return 'Стол $number';
  }

  @override
  String get clubCashGameNoTables => 'Нет столов в этой группе';

  @override
  String clubCashGameFailedToLoad(String error) {
    return 'Не удалось загрузить столы: $error';
  }

  @override
  String get clubCashGameAlreadySeated => 'Вы уже сидите за столом';

  @override
  String get clubCashGameSeatAvailable =>
      'Для вас есть свободное место, подойдите к регистрации';

  @override
  String clubCashGameJoinedWaitlist(int position) {
    return 'Вы в списке ожидания на позиции #$position';
  }

  @override
  String clubCashGameJoinFailed(String error) {
    return 'Не удалось присоединиться к списку ожидания: $error';
  }

  @override
  String get clubCashGameLeftWaitlist => 'Вы покинули список ожидания';

  @override
  String clubCashGameLeaveFailed(String error) {
    return 'Не удалось покинуть список ожидания: $error';
  }

  @override
  String get clubCashGameViewWaitlist => 'Просмотр списка ожидания';

  @override
  String get clubCashGameInWaitlist => 'В списке ожидания';

  @override
  String clubCashGameInWaitlistPosition(int position) {
    return 'В списке ожидания · #$position';
  }

  @override
  String get clubCashGameJoinWaitlist => 'Встать в очередь';

  @override
  String get clubCashGameLeaveWaitlistConfirm => 'Покинуть список ожидания?';

  @override
  String get clubCashGameLosePosition => 'Вы потеряете текущую позицию.';

  @override
  String get clubCashGameKeep => 'Остаться';

  @override
  String get clubCashGameLeave => 'Покинуть';

  @override
  String clubCashGameRefreshFailed(String error) {
    return 'Не удалось обновить столы: $error';
  }

  @override
  String get clubCashGameWaitlistTitle => 'Список ожидания';

  @override
  String clubCashGameNotified(String name) {
    return '$name уведомлён';
  }

  @override
  String clubCashGameNotifyFailed(String error) {
    return 'Не удалось уведомить: $error';
  }

  @override
  String get clubCashGameCouldNotLoad => 'Не удалось загрузить список ожидания';

  @override
  String get clubCashGameNoOneOnWaitlist => 'Список ожидания пуст';

  @override
  String get clubCashGamePlayer => 'Игрок';

  @override
  String clubCashGameNotifiedStatus(String time) {
    return 'Уведомлён • $time';
  }

  @override
  String clubCashGameJoinedTime(String time) {
    return 'Присоединился $time';
  }

  @override
  String get clubCashGameJustNow => 'только что';

  @override
  String clubCashGameMinutesAgo(int count) {
    return '$count мин. назад';
  }

  @override
  String clubCashGameHoursAgo(int count) {
    return '$count ч. назад';
  }

  @override
  String clubCashGameDaysAgo(int count) {
    return '$count дн. назад';
  }

  @override
  String get clubCashGameAddTable => 'Добавить стол';

  @override
  String get clubCashGameNewTableName =>
      'Название нового стола (необязательно)';

  @override
  String get clubCashGameAdd => 'Добавить';

  @override
  String clubCashGameAddedToGroup(String tableName) {
    return '$tableName добавлен в группу';
  }

  @override
  String clubCashGameAddFailed(String error) {
    return 'Не удалось добавить стол: $error';
  }

  @override
  String clubCashGameAttachFailed(String error) {
    return 'Не удалось прикрепить стол: $error';
  }

  @override
  String get clubCashGameAvailableTables => 'Доступные столы';

  @override
  String get clubCashGameInUseByOther => 'Заняты другими мероприятиями';

  @override
  String get clubCashGameNoOtherTables => 'В этом клубе пока нет других столов';

  @override
  String clubCashGameInUseBy(String eventName) {
    return 'Используется: $eventName';
  }

  @override
  String clubCashGameSeats(int count) {
    return 'Мест: $count';
  }

  @override
  String memberEventTablesSummary(int count, int occupied, int open) {
    return '$count столов • $occupied сидят • $open свободных';
  }

  @override
  String memberEventJoinedWaitlist(int position) {
    return 'Вы в списке ожидания на позиции #$position';
  }

  @override
  String memberEventJoinFailed(String error) {
    return 'Не удалось присоединиться к списку ожидания: $error';
  }

  @override
  String get memberEventLeftWaitlist => 'Вы покинули список ожидания';

  @override
  String memberEventLeaveFailed(String error) {
    return 'Не удалось покинуть список ожидания: $error';
  }

  @override
  String memberEventWaitlistPosition(int position) {
    return 'Позиция #$position в списке ожидания';
  }

  @override
  String memberEventTotalWaiting(int count) {
    return 'Всего ожидают: $count';
  }

  @override
  String get memberEventLeaveWaitlist => 'Покинуть список ожидания';

  @override
  String memberEventJoinWaitlistWithCount(int count) {
    return 'Встать в очередь ($count ожидают)';
  }

  @override
  String get memberEventJoinWaitlist => 'Встать в очередь';

  @override
  String get memberEventAllTablesFull => 'Все столы заняты';

  @override
  String get dealerHomeTitle => 'Режим Dealer';

  @override
  String get dealerHomeNoClubs => 'Клубы не найдены';

  @override
  String get dealerHomeNoClubsOwnerHint =>
      'Создайте свой первый клуб, чтобы начать.';

  @override
  String get dealerHomeNoClubsMemberHint =>
      'Вы ещё не состоите ни в одном клубе.\nПопросите владельца клуба пригласить вас.';

  @override
  String get dealerHomeCreateClub => 'Создать клуб';

  @override
  String get dealerHomeDealer => 'Dealer';

  @override
  String dealerHomeClubCount(int count) {
    return '$count клубов';
  }

  @override
  String get dealerHomeActiveSessions => 'Активные сессии';

  @override
  String get dealerHomeClubs => 'Клубы';

  @override
  String get dealerHomeTables => 'Столы';

  @override
  String get dealerHomeAddTable => 'Добавить стол';

  @override
  String get dealerHomeTableNameLabel => 'Название стола';

  @override
  String get dealerHomeTableNameHint => 'напр., Стол 1, Главный стол';

  @override
  String dealerHomeTableAdded(String name, String clubName) {
    return 'Стол \"$name\" добавлен в $clubName!';
  }

  @override
  String dealerHomeAddTableFailed(String error) {
    return 'Не удалось добавить стол: $error';
  }

  @override
  String get dealerHomeClubName => 'Название клуба';

  @override
  String get dealerHomeCreate => 'Создать';

  @override
  String dealerHomeClubCreated(String name) {
    return 'Клуб \"$name\" создан!';
  }

  @override
  String dealerHomeClubCreateFailed(String error) {
    return 'Не удалось создать клуб: $error';
  }

  @override
  String get dealerHomeNoTables => 'В этом клубе нет столов';

  @override
  String dealerHomeActiveHand(int number) {
    return 'Активен — Hand #$number';
  }

  @override
  String get dealerHomeInactive => 'Неактивен';

  @override
  String get dealerHomeResume => 'Возобновить';

  @override
  String get dealerHomeStart => 'Начать';

  @override
  String get dealerHomeSessionSettings => 'Настройки сессии';

  @override
  String get dealerHomeSmallBlind => 'Small Blind';

  @override
  String get dealerHomeBigBlind => 'Big Blind';

  @override
  String get dealerHomeBBAnte => 'BB Ante';

  @override
  String get dealerHomeGameType => 'Тип игры';

  @override
  String get dealerHomeCash => 'Cash';

  @override
  String get dealerHomeTournament => 'Tournament';

  @override
  String get dealerHomeButtonPosition => 'Позиция кнопки';

  @override
  String get dealerHomeStartSession => 'Начать сессию';

  @override
  String get dealerHomeCouldNotFind => 'Не удалось найти клуб или стол';

  @override
  String dealerHomeStartFailed(String error) {
    return 'Не удалось начать сессию: $error';
  }

  @override
  String dealerHomeErrorLoading(String error) {
    return 'Ошибка загрузки данных: $error';
  }

  @override
  String dealerHomeTableCount(int count) {
    return '$count столов';
  }

  @override
  String dealerTableFailedStartHand(String error) {
    return 'Не удалось начать раздачу: $error';
  }

  @override
  String dealerTableChopSummary(String winners, String amount) {
    return 'Chop: $winners делят $amount';
  }

  @override
  String dealerTableWins(String name, String amount) {
    return '$name выигрывает $amount';
  }

  @override
  String dealerTablePotChopped(String names) {
    return 'Pot разделён между $names';
  }

  @override
  String dealerTableFailedCompleteHand(String error) {
    return 'Не удалось завершить раздачу: $error';
  }

  @override
  String dealerTablePlayerBusted(String name) {
    return '$name выбыл!';
  }

  @override
  String dealerTableNoChipsRemaining(int seatNumber, String amount) {
    return 'У места $seatNumber не осталось фишек.\nСумма Rebuy: $amount';
  }

  @override
  String get dealerTableRemovePlayer => 'Удалить игрока';

  @override
  String get dealerTableRebuy => 'Rebuy';

  @override
  String dealerTableRebuysFor(String name, String amount) {
    return '$name делает Rebuy на $amount';
  }

  @override
  String dealerTableFinishesIn(String name, String position) {
    return '$name финиширует на $position месте';
  }

  @override
  String get dealerTableEndSessionTitle => 'Завершить сессию?';

  @override
  String get dealerTableEndSessionBody =>
      'Вы уверены, что хотите завершить эту сессию?';

  @override
  String get dealerTableEnd => 'Завершить';

  @override
  String get dealerTableDealerChange => 'Смена Dealer';

  @override
  String get dealerTableDealerChangeBody =>
      'Сессия будет поставлена на паузу, и другой Dealer сможет отсканировать QR-код стола, чтобы продолжить.';

  @override
  String get dealerTableDealerChangePreserve =>
      'Все игроки, блайнды и состояние игры будут сохранены.';

  @override
  String get dealerTableDealerChangeResume =>
      'Вы также можете возобновить эту сессию позже.';

  @override
  String get dealerTableHandOff => 'Передать смену';

  @override
  String get dealerTableSessionPaused =>
      'Сессия на паузе. Другой Dealer может продолжить.';

  @override
  String dealerTablePauseFailed(String error) {
    return 'Не удалось поставить сессию на паузу: $error';
  }

  @override
  String get dealerTableEventCancelled => 'Мероприятие отменено';

  @override
  String get dealerTableEventFinished => 'Мероприятие завершено';

  @override
  String get dealerTableEventCancelledBody =>
      'Администратор клуба отменил это мероприятие. Все сессии сохранены.';

  @override
  String get dealerTableEventFinishedBody =>
      'Администратор клуба завершил это мероприятие. Все сессии сохранены.';

  @override
  String get dealerTableSessionEnded => 'Сессия завершена';

  @override
  String get dealerTableSessionEndedBody =>
      'Эта сессия завершена. Все данные сохранены.';

  @override
  String get dealerTableLeaveTitle => 'Покинуть стол Dealer?';

  @override
  String get dealerTableLeaveActiveHand =>
      'Сейчас идёт раздача. Уход может нарушить запись.';

  @override
  String get dealerTableLeaveInactive =>
      'Сессия остаётся активной. Вы можете вернуться в любое время.';

  @override
  String dealerTableAutoCorrection(String detected, String corrected) {
    return 'Автокоррекция \"$detected\" → \"$corrected\"';
  }

  @override
  String dealerTableApprovePlayer(String name) {
    return 'Одобрить $name?';
  }

  @override
  String get dealerTableStartingChipStack => 'Начальный Stack фишек';

  @override
  String dealerTablePlayerRejected(String name) {
    return '$name отклонён';
  }

  @override
  String dealerTableRejectFailed(String error) {
    return 'Не удалось отклонить: $error';
  }

  @override
  String dealerTablePlayerJoined(String name, String amount) {
    return '$name присоединился с $amount';
  }

  @override
  String dealerTableApproveFailed(String error) {
    return 'Не удалось одобрить: $error';
  }

  @override
  String get dealerTableChipStack => 'Stack фишек';

  @override
  String get dealerTableSave => 'Сохранить';

  @override
  String get liveSessionHand => 'HAND';

  @override
  String get liveSessionPot => 'POT';

  @override
  String get liveSessionStatus => 'СТАТУС';

  @override
  String get liveSessionLive => 'LIVE';

  @override
  String get liveSessionWaiting => 'ОЖИДАНИЕ';

  @override
  String liveSessionWinnerSummary(String winner, String amount) {
    return '$winner выигрывает \$$amount';
  }

  @override
  String get liveSessionSessionEnded => 'Сессия завершена';

  @override
  String get liveSessionSessionEndedBody => 'Dealer завершил эту сессию.';

  @override
  String get liveSessionLeaveTitle => 'Покинуть стол?';

  @override
  String get liveSessionLeaveBody => 'Вы уверены, что хотите покинуть стол?';

  @override
  String get liveSessionLeave => 'Покинуть';

  @override
  String liveSessionLeaveFailed(String error) {
    return 'Не удалось покинуть: $error';
  }

  @override
  String get liveSessionLeaveTooltip => 'Покинуть стол';

  @override
  String liveSessionSeat(int number) {
    return 'Место $number';
  }

  @override
  String get liveSessionYourSeat => 'Ваше место';

  @override
  String liveSessionStack(String amount) {
    return 'Stack: $amount';
  }

  @override
  String get liveSessionWaitingForDealer => 'Ожидание Dealer...';

  @override
  String get liveSessionOffline => 'ОФЛАЙН';

  @override
  String get liveSessionRecentActions => 'Последние действия';

  @override
  String get liveSessionWaitingForAction => 'Ожидание действия...';

  @override
  String get liveSessionD => 'D';

  @override
  String get qrScanTitle => 'Сканировать QR стола';

  @override
  String get qrScanInvalidCode =>
      'Недействительный QR-код. Отсканируйте QR-код покерного стола.';

  @override
  String qrScanError(String error) {
    return 'Ошибка обработки QR-кода: $error';
  }

  @override
  String get qrScanInstructions =>
      'Наведите камеру на QR-код на столе, чтобы присоединиться';

  @override
  String get clubRequestsTitle => 'Заявки на клуб';

  @override
  String get clubRequestsAll => 'Все';

  @override
  String get clubRequestsPending => 'Ожидающие';

  @override
  String get clubRequestsApproved => 'Одобренные';

  @override
  String get clubRequestsRejected => 'Отклонённые';

  @override
  String get clubRequestsApproveTitle => 'Одобрить заявку';

  @override
  String clubRequestsApproveBody(String name) {
    return 'Вы уверены, что хотите одобрить \"$name\"? Это создаст новый клуб и добавит вас как администратора.';
  }

  @override
  String get clubRequestsRejectTitle => 'Отклонить заявку';

  @override
  String clubRequestsRejectBody(String name) {
    return 'Укажите причину отклонения \"$name\":';
  }

  @override
  String get clubRequestsRejectHint => 'Причина отклонения...';

  @override
  String get clubRequestsApproveButton => 'Одобрить';

  @override
  String get clubRequestsRejectButton => 'Отклонить';

  @override
  String clubRequestsApproved2(String name) {
    return '\"$name\" одобрен!';
  }

  @override
  String clubRequestsRejected2(String name) {
    return '\"$name\" отклонён.';
  }

  @override
  String get clubRequestsNoRequests => 'Нет заявок';

  @override
  String get clubRequestsPendingBadge => 'ОЖИДАНИЕ';

  @override
  String get clubRequestsApprovedBadge => 'ОДОБРЕНО';

  @override
  String get clubRequestsRejectedBadge => 'ОТКЛОНЕНО';

  @override
  String get clubRequestsAddress => 'Адрес';

  @override
  String get clubRequestsPhone => 'Телефон';

  @override
  String get clubRequestsAdminEmail => 'Email администратора';

  @override
  String get clubRequestsRequestedBy => 'Запрос от';

  @override
  String get clubRequestsRequesterEmail => 'Email заявителя';

  @override
  String get clubRequestsRequestedAt => 'Дата запроса';

  @override
  String get clubRequestsReviewedAt => 'Дата рассмотрения';

  @override
  String get clubRequestsRejectionReason => 'Причина отклонения:';

  @override
  String get supportRequestsTitle => 'Обращения в поддержку';

  @override
  String get supportRequestsAll => 'Все';

  @override
  String get supportRequestsPending => 'Ожидающие';

  @override
  String get supportRequestsClosed => 'Закрытые';

  @override
  String get supportRequestsResolveTitle => 'Решить обращение';

  @override
  String get supportRequestsResolveBody =>
      'Ответ пользователю (необязательно):';

  @override
  String get supportRequestsResponseHint => 'Ответ (необязательно)...';

  @override
  String get supportRequestsResolve => 'Решить';

  @override
  String get supportRequestsResolved => 'Обращение решено';

  @override
  String get supportRequestsRejectTitle => 'Отклонить обращение';

  @override
  String get supportRequestsRejectBody => 'Причина отклонения:';

  @override
  String get supportRequestsRejectHint => 'Причина...';

  @override
  String get supportRequestsReject => 'Отклонить';

  @override
  String get supportRequestsRejected => 'Обращение отклонено';

  @override
  String get supportRequestsNoRequests => 'Нет обращений';

  @override
  String get supportRequestsPendingBadge => 'ОЖИДАНИЕ';

  @override
  String get supportRequestsResolvedBadge => 'РЕШЕНО';

  @override
  String get supportRequestsRejectedBadge => 'ОТКЛОНЕНО';

  @override
  String get supportRequestsCategory => 'Категория';

  @override
  String get supportRequestsUser => 'Пользователь';

  @override
  String get supportRequestsEmail => 'Email';

  @override
  String get supportRequestsSubmitted => 'Отправлено';

  @override
  String get supportRequestsDescription => 'Описание';

  @override
  String get supportRequestsAdminResponse => 'Ответ администратора';

  @override
  String get supportRequestsBugReport => 'Отчёт об ошибке';

  @override
  String get supportRequestsFeatureRequest => 'Запрос функции';

  @override
  String get supportRequestsAccountIssue => 'Проблема с аккаунтом';

  @override
  String get debugHandViewerTitle => 'Просмотр раздач (отладка)';

  @override
  String get debugHandViewerSessionName => 'Название сессии';

  @override
  String get debugHandViewerHandNumbers =>
      'Номера раздач (через запятую, напр., 27,28)';

  @override
  String get debugHandViewerFetchData => 'Загрузить данные';

  @override
  String get debugHandViewerCopied => 'Скопировано';

  @override
  String get debugHandViewerNoData =>
      'Данных пока нет. Введите название сессии и нажмите «Загрузить данные».';

  @override
  String get navDrawerSettings => 'Настройки';

  @override
  String get navDrawerRegisterClub => 'Зарегистрировать клуб';

  @override
  String get navDrawerHelpSupport => 'Помощь и поддержка';

  @override
  String get navDrawerLogOut => 'Выйти';

  @override
  String get navDrawerUpgrade => 'Улучшить';

  @override
  String get navDrawerUserFallback => 'Пользователь';

  @override
  String get navDrawerStatistics => 'Статистика';

  @override
  String get navDrawerEvents => 'События';

  @override
  String get navDrawerBankroll => 'Bankroll';

  @override
  String get navDrawerClubs => 'Клубы';

  @override
  String get navDrawerNoClubsYet => 'Пока нет клубов';

  @override
  String navDrawerMemberCount(int count) {
    return '$count участников';
  }

  @override
  String get navDrawerRoleAdmin => 'Админ';

  @override
  String get navDrawerRoleDealer => 'Dealer';

  @override
  String get navDrawerRoleMember => 'Участник';

  @override
  String get navDrawerVersion => 'Версия 1.0.0';

  @override
  String get navDrawerLastLoginToday => 'Последний вход: Сегодня';

  @override
  String get navDrawerNoEarningsTitle => 'Нет данных о заработке';

  @override
  String get navDrawerNoEarningsBody =>
      'Сначала добавьте результаты сессий, чтобы увидеть график заработка. Результаты можно добавить на странице Профиля.';

  @override
  String get navDrawerSignOutTitle => 'Выход';

  @override
  String get navDrawerSignOutMessage => 'Вы уверены, что хотите выйти?';

  @override
  String get navDrawerSignOut => 'Выйти';

  @override
  String get multiPotMainPot => 'Main Pot';

  @override
  String multiPotSidePot(int index) {
    return 'Side Pot $index';
  }

  @override
  String multiPotPlayerFallback(String id) {
    return 'Игрок $id';
  }

  @override
  String get multiPotMainPotWinner => 'победитель Main Pot';

  @override
  String get multiPotEligibleFromPrevious => 'имеет право из предыдущего Pot';

  @override
  String multiPotAutoAwarded(String name, String reason) {
    return 'Автоматически присуждено $name ($reason)';
  }

  @override
  String get multiPotChoppedPot => 'Chopped Pot';

  @override
  String get multiPotSingleWinner => 'Один победитель';

  @override
  String get multiPotSelectAllWinners => 'Выберите всех победителей:';

  @override
  String get multiPotSelectTheWinner => 'Выберите победителя:';

  @override
  String get multiPotSelectWinnersTitle => 'Выбор победителей';

  @override
  String get multiPotMultiplePots =>
      'Несколько Pot — выберите победителя для каждого';

  @override
  String get winnerSelectionWhoChopped => 'Кто разделил этот Pot?';

  @override
  String get winnerSelectionWhoWon => 'Кто выиграл эту руку?';

  @override
  String get winnerSelectionChoppedPot => 'Chopped Pot';

  @override
  String get winnerSelectionIndividualShares => 'Индивидуальные доли:';

  @override
  String get winnerSelectionSelectAllWinners => 'Выберите всех победителей:';

  @override
  String get winnerSelectionTapTheWinner => 'Нажмите на победителя:';

  @override
  String get winnerSelectionLongPressHint => 'Долгое нажатие для Chopped Pot';

  @override
  String get winnerSelectionConfirmChop => 'Подтвердить Chop';

  @override
  String get winnerSelectionBackToSingle => 'Вернуться к одному победителю';

  @override
  String get boardCardsCards => 'Карты';

  @override
  String get boardCardsCard => 'Карта';

  @override
  String get allInBoardTitle => 'Карты борда при All-in';

  @override
  String get raiseSnapReleaseToType => 'Отпустите на мин., чтобы ввести';

  @override
  String get slidingNotificationHeader => 'УВЕДОМЛЕНИЕ';

  @override
  String get eventSuccessTitle =>
      'Отлично! Ваше событие добавлено в календарь.';

  @override
  String get eventSuccessSubtitle =>
      'Вы можете отредактировать или удалить его в любое время';

  @override
  String get eventSuccessGoToCalendar => 'Перейти в календарь';

  @override
  String get eventSuccessAddAnother => 'Добавить ещё событие';

  @override
  String get stackChartNoData => 'Нет данных';

  @override
  String get stackChartStart => 'Старт';

  @override
  String get stackChartRebuy => 'Rebuy';

  @override
  String get stackChartEnd => 'Конец';

  @override
  String get stackChartTitle => 'График Stack';

  @override
  String get stackChartAvgGrowth => 'Ср. рост';

  @override
  String get stackChartDuration => 'Длительность';

  @override
  String get stackChartProfitLoss => 'П/У';

  @override
  String get actionGridSelectAction => 'Выберите действие';

  @override
  String get pokerTablePlayerFallback => 'Игрок';

  @override
  String get loadingDefault => 'Загрузка...';

  @override
  String get forgotPasswordFailedSendCode =>
      'Не удалось отправить код. Попробуйте снова.';

  @override
  String get forgotPasswordNewCodeSent => 'Новый код отправлен на вашу почту.';

  @override
  String get forgotPasswordFailedResend => 'Не удалось повторно отправить код.';

  @override
  String get forgotPasswordEnterFullCode =>
      'Пожалуйста, введите полный 6-значный код.';

  @override
  String get forgotPasswordInvalidCode =>
      'Недействительный или просроченный код. Попробуйте снова.';

  @override
  String get forgotPasswordResetSuccess =>
      'Пароль успешно сброшен! Пожалуйста, войдите в систему.';

  @override
  String get forgotPasswordResetTitle => 'Сброс пароля';

  @override
  String get forgotPasswordResetSubtitle =>
      'Введите ваш e-mail для получения кода подтверждения';

  @override
  String get forgotPasswordCheckEmail => 'Проверьте вашу почту';

  @override
  String get forgotPasswordSetNewPassword => 'Установить новый пароль';

  @override
  String get forgotPasswordSetNewSubtitle =>
      'Выберите надёжный пароль для вашего аккаунта';

  @override
  String get forgotPasswordEmail => 'E-mail';

  @override
  String get forgotPasswordEnterEmail => 'Пожалуйста, введите e-mail';

  @override
  String get forgotPasswordValidEmail =>
      'Пожалуйста, введите действительный e-mail';

  @override
  String get forgotPasswordSendCode => 'Отправить код';

  @override
  String get forgotPasswordVerifyCode => 'Подтвердить код';

  @override
  String get forgotPasswordResendCode => 'Отправить код повторно';

  @override
  String forgotPasswordResendIn(String time) {
    return 'Повторная отправка через $time';
  }

  @override
  String get forgotPasswordNewPassword => 'Новый пароль';

  @override
  String get forgotPasswordEnterPassword => 'Пожалуйста, введите пароль';

  @override
  String get forgotPasswordMinLength =>
      'Пароль должен содержать минимум 6 символов';

  @override
  String get forgotPasswordConfirm => 'Подтвердите пароль';

  @override
  String get forgotPasswordConfirmRequired => 'Пожалуйста, подтвердите пароль';

  @override
  String get forgotPasswordMismatch => 'Пароли не совпадают';

  @override
  String get forgotPasswordResetButton => 'Сбросить пароль';

  @override
  String get onboardingTrackTitle => 'ОТСЛЕЖИВАЙТЕ\nКАЖДУЮ РУКУ';

  @override
  String get onboardingTrackSubtitle =>
      'Записывайте действия, карты борда и результаты каждой сыгранной руки — в реальном времени или после сессии.';

  @override
  String get onboardingKnowTitle => 'ЗНАЙТЕ СВОЮ\nИГРУ';

  @override
  String get onboardingKnowSubtitle =>
      'VPIP, PFR, 3-Bet, C-Bet и другие — наблюдайте за развитием своей статистики в реальном времени.';

  @override
  String get onboardingClubsTitle => 'ИГРАЙТЕ В\nКЛУБАХ';

  @override
  String get onboardingClubsSubtitle =>
      'Присоединяйтесь к живым событиям, следите за рейтингами и отслеживайте противников между сессиями.';

  @override
  String get dealerTableEnterStartingStack => 'Введите начальный Stack';

  @override
  String get dealerTableNoPendingRequests =>
      'Нет ожидающих запросов на присоединение';

  @override
  String get dealerTablePendingJoinRequests =>
      'Ожидающие запросы на присоединение';

  @override
  String get dealerTableUnknown => 'Неизвестно';

  @override
  String dealerTableSeatNumber(int number) {
    return 'Место $number';
  }

  @override
  String get dealerTableReview => 'Обзор';

  @override
  String get dealerTableSmallBlind => 'Small Blind';

  @override
  String get dealerTableBigBlind => 'Big Blind';

  @override
  String get dealerTableNewBlindsNote =>
      'Новые блайнды будут применены со следующей руки.';

  @override
  String get dealerTableSmallMustBeLess =>
      'Small Blind должен быть меньше Big Blind';

  @override
  String get dealerTableBlindsMustBePositive => 'Блайнды должны быть больше 0';

  @override
  String dealerTableBlindsUpdated(String sb, String bb) {
    return 'Блайнды обновлены на $sb/$bb';
  }

  @override
  String dealerTableFailedUpdateBlinds(String error) {
    return 'Не удалось обновить блайнды: $error';
  }

  @override
  String dealerTableFailedMoveButton(String error) {
    return 'Не удалось переместить BTN: $error';
  }

  @override
  String get dealerTablePending => 'ОЖИДАНИЕ';

  @override
  String get dealerTableConnectionLost => 'Соединение потеряно';

  @override
  String get dealerTableReconnecting => 'Попытка переподключения...';

  @override
  String get dealerTableReconnect => 'Переподключиться';

  @override
  String get dealerTableResetHandTitle => 'Сбросить руку?';

  @override
  String get dealerTableResetHandBody =>
      'Все действия были отменены. Хотите начать новую руку?';

  @override
  String get dealerTableKeepCurrent => 'Оставить текущие';

  @override
  String get dealerTableNewHand => 'Новая рука';

  @override
  String get dealerTableHandReset => 'Рука сброшена — готов к новой руке';

  @override
  String dealerTableAddPlayerToSeat(int number) {
    return 'Добавить игрока на место $number';
  }

  @override
  String get dealerTableSearchUser => 'Найти пользователя';

  @override
  String get dealerTableManualEntry => 'Ручной ввод';

  @override
  String get dealerTableSearchByName => 'Поиск по имени';

  @override
  String get dealerTableTypeToSearch => 'Введите для поиска пользователей...';

  @override
  String get dealerTableNoUsersFound =>
      'Пользователи не найдены. Попробуйте ручной ввод.';

  @override
  String get dealerTablePlayerNameLabel => 'Имя игрока';

  @override
  String get dealerTableEnterPlayerName => 'Введите имя игрока';

  @override
  String get dealerTableAddPlayer => 'Добавить игрока';

  @override
  String get dealerTableEndSession => 'Завершить сессию';

  @override
  String dealerTableUpdatedStack(String name, String amount) {
    return 'Stack $name обновлён на $amount';
  }

  @override
  String dealerTableFailedUpdateStack(String error) {
    return 'Не удалось обновить Stack: $error';
  }

  @override
  String dealerTableSittingAtSeat(int number) {
    return 'Вы теперь играете на месте $number';
  }

  @override
  String dealerTableFailedSitAt(String error) {
    return 'Не удалось сесть за стол: $error';
  }

  @override
  String dealerTableFailedAddPlayer(String error) {
    return 'Не удалось добавить игрока: $error';
  }

  @override
  String dealerTableFailedRemovePlayer(String error) {
    return 'Не удалось удалить игрока: $error';
  }

  @override
  String get eventDetailEventType => 'Тип события';

  @override
  String get eventDetailSeated => 'Усажен';

  @override
  String get eventDetailAreYouGoing => 'ВЫ ИДЁТЕ?';

  @override
  String get eventDetailAddedToCalendarBtn => 'Добавлено в календарь';

  @override
  String get eventDetailAddToCalendarBtn => 'Добавить в календарь';

  @override
  String get eventDetailWhosGoing => 'Кто придёт';

  @override
  String get eventDetailSeeAll => 'Показать все';

  @override
  String get eventDetailStartDealing => 'Начать раздачу';

  @override
  String get eventDetailViewLiveRankings => 'Рейтинг в реальном времени';

  @override
  String get eventDetailNotSeatedAtTable =>
      'Вы сейчас не сидите ни за одним столом';

  @override
  String get eventDetailNotSeatedInEvent => 'Вы не усажены в этом событии';

  @override
  String eventDetailErrorFindingSeat(String error) {
    return 'Ошибка поиска места: $error';
  }

  @override
  String get eventDetailReturnToSeat => 'Вернуться на моё место';

  @override
  String get eventDetailViewFinalStandings => 'Итоговые результаты';

  @override
  String get eventDetailManageTables => 'Управление столами';

  @override
  String get eventDetailManageTable => 'Управление столом';

  @override
  String get eventDetailSeeAvailability => 'Посмотреть наличие мест';

  @override
  String get eventDetailYoureSeated => 'Вы усажены';

  @override
  String get eventDetailNoTablesAssigned =>
      'К этому событию не привязаны столы';

  @override
  String get eventDetailStartEvent => 'Начать событие';

  @override
  String get eventDetailFinish => 'Завершить';

  @override
  String eventDetailFailedFinishCancel(String action, String error) {
    return 'Не удалось $action событие: $error';
  }

  @override
  String homeTableSeatInfo(String table, String seat) {
    return 'Стол $table, Место #$seat';
  }

  @override
  String get homeRequestResolved => 'Запрос решён';

  @override
  String get homeRequestClosed => 'Запрос закрыт';

  @override
  String get homeResponse => 'Ответ';

  @override
  String homeErrorGeneric(String error) {
    return 'Ошибка: $error';
  }

  @override
  String homeErrorLoadingEvent(String error) {
    return 'Ошибка загрузки события: $error';
  }

  @override
  String homeFailedLoadEvent(String error) {
    return 'Не удалось загрузить событие: $error';
  }

  @override
  String homeFailedUpdateEvent(String error) {
    return 'Не удалось обновить событие: $error';
  }

  @override
  String homeErrorDeletingEvent(String error) {
    return 'Ошибка удаления события: $error';
  }

  @override
  String get homeTournament => 'Tournament';

  @override
  String get homeCashGame => 'Cash Game';

  @override
  String commonErrorGeneric(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get commonLeave => 'Покинуть';

  @override
  String get commonAccept => 'Принять';

  @override
  String get commonLoadingHands => 'Загрузка рук...';

  @override
  String sessionHistoryButtonPosition(String position) {
    return 'Позиция BTN: $position';
  }

  @override
  String sessionHistoryPlayerCount(String count) {
    return 'Количество игроков: $count';
  }

  @override
  String sessionHistoryStartTime(String time) {
    return 'Время начала: $time';
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
    return 'Синхронизация не удалась: $error';
  }

  @override
  String sessionHistoryClearFailed(String error) {
    return 'Не удалось очистить сессии: $error';
  }

  @override
  String get notificationsClubNotFound => 'Клуб не найден';

  @override
  String get notificationsAccept => 'Принять';

  @override
  String get notificationsInvitationAccepted => 'Приглашение принято';

  @override
  String get notificationsInvitationDeclined => 'Приглашение отклонено';

  @override
  String get notificationsInvitationDeclinedMsg => 'Приглашение отклонено';

  @override
  String get notificationsEventNotFound => 'Событие не найдено';

  @override
  String notificationsFailedLoadClub(String error) {
    return 'Не удалось загрузить клуб: $error';
  }

  @override
  String notificationsErrorLoadingEvent(String error) {
    return 'Ошибка загрузки события: $error';
  }

  @override
  String invitationsFailedLoad(String error) {
    return 'Не удалось загрузить приглашения: $error';
  }

  @override
  String invitationsFailedAccept(String error) {
    return 'Не удалось принять приглашение: $error';
  }

  @override
  String get invitationsDeclined => 'Приглашение отклонено';

  @override
  String invitationsFailedDecline(String error) {
    return 'Не удалось отклонить приглашение: $error';
  }

  @override
  String get clubSettingsTableAdded => 'Стол добавлен';

  @override
  String get clubSettingsTableDeleted => 'Стол удалён';

  @override
  String get clubSettingsQrRegenerated => 'QR-коды перегенерированы';

  @override
  String clubSettingsErrorPdf(String error) {
    return 'Ошибка генерации PDF: $error';
  }

  @override
  String get clubDashboardActiveDealers => 'Активные Dealer';

  @override
  String get clubDashboardPendingInvitations => 'Ожидающие приглашения';

  @override
  String get clubDashboardDealerEmailHint => 'dealer@example.com';

  @override
  String clubDashboardInvitationSent(String email) {
    return 'Приглашение отправлено на $email';
  }

  @override
  String clubDashboardFailedSendInvite(String error) {
    return 'Не удалось отправить приглашение: $error';
  }

  @override
  String clubDashboardFailedCancelInvite(String error) {
    return 'Не удалось отменить приглашение: $error';
  }

  @override
  String eventManagementClubEvents(String name) {
    return 'События $name';
  }

  @override
  String eventManagementFailedUpdate(String error) {
    return 'Не удалось обновить событие: $error';
  }

  @override
  String get profileCash => 'Cash';

  @override
  String get profileTournament => 'Tournament';

  @override
  String get profileDevTools => 'Инструменты разработчика';

  @override
  String get profilePremiumOverride => 'Переопределение Premium';

  @override
  String profileUsingRealStatus(String status) {
    return 'Реальный статус: $status';
  }

  @override
  String profileOverridden(String status) {
    return 'Переопределено: $status';
  }

  @override
  String get profileResetToReal => 'Сбросить на реальный статус';

  @override
  String get profileVersion => 'Версия 1.0';

  @override
  String profileLastLogin(String date) {
    return 'Последний вход $date';
  }

  @override
  String pokerHandFailedEndSession(String error) {
    return 'Не удалось завершить сессию: $error';
  }

  @override
  String pokerHandFailedSaveSession(String error) {
    return 'Не удалось сохранить сессию: $error';
  }

  @override
  String pokerHandRebuyAdded(String amount, String stack) {
    return 'Rebuy добавлен: \$$amount (Stack: $stack)';
  }

  @override
  String get pokerHandEndSession => 'Завершить сессию';

  @override
  String get pokerHandRebuyAmountDollar => 'Сумма Rebuy (\$)';

  @override
  String get pokerHandRebuyChips => 'Фишки Rebuy';

  @override
  String seatSetupFailedSave(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get seatSetupSelectYourSeat => 'Выберите ваше место';

  @override
  String get authExpLinkGoogleTitle => 'Привязать аккаунт Google';

  @override
  String get authExpPassword => 'Пароль';

  @override
  String get authExpLinkAccount => 'Привязать аккаунт';

  @override
  String get individualSetupSessionNameHint => 'напр. \"Пятничный покер\"';

  @override
  String get individualSetupCashGame => 'Cash Game';

  @override
  String get individualSetupTournament => 'Tournament';

  @override
  String get individualSetupEnterAmount => 'Введите сумму';

  @override
  String get individualSetupEnterChipStack => 'Введите Stack фишек';

  @override
  String get individualSetupSmallBlind => 'Small Blind';

  @override
  String get individualSetupBigBlind => 'Big Blind';

  @override
  String get individualSetupEnterValue => 'Введите значение';

  @override
  String get individualHandSetupNameHint => 'напр. \"AA vs KK Cooler\"';

  @override
  String get individualHandSetupSmallBlind => 'Small Blind';

  @override
  String get individualHandSetupBigBlind => 'Big Blind';

  @override
  String get individualHandSetupPlayers => 'Игроки';

  @override
  String get individualHandSetupGameType => 'Тип игры';

  @override
  String get playerSessionYourHoleCards => 'Ваши Hole Cards';

  @override
  String get playerSessionSeat => 'МЕСТО';

  @override
  String get playerSessionStack => 'STACK';

  @override
  String get playerSessionPot => 'POT';

  @override
  String get playerSessionNotesHint => 'Добавить заметки об этой руке...';

  @override
  String get dealerQrScanInvalidCode =>
      'Недействительный QR-код. Отсканируйте действительный QR-код стола.';

  @override
  String get dealerQrScanWrongClub => 'Этот стол принадлежит другому клубу.';

  @override
  String get dealerQrScanTableNotFound =>
      'Стол не найден. Отсканируйте действительный QR-код стола.';

  @override
  String dealerQrScanError(String error) {
    return 'Ошибка обработки QR-кода: $error';
  }

  @override
  String dealerQrScanFailedStart(String error) {
    return 'Не удалось начать сессию: $error';
  }

  @override
  String dealerQrScanTakingOver(String name) {
    return 'Принимаете смену от $name';
  }

  @override
  String get dealerQrScanHandsPlayed => 'Сыграно рук';

  @override
  String get dealerQrScanBlinds => 'Блайнды';

  @override
  String get dealerQrScanPlayers => 'Игроки';

  @override
  String dealerQrScanFailedResume(String error) {
    return 'Не удалось возобновить сессию: $error';
  }

  @override
  String get usernameSetupLabel => 'Имя пользователя';

  @override
  String get stackChartScreenAvgGrowth => 'Ср. рост';

  @override
  String get stackChartScreenDuration => 'Длительность';

  @override
  String get stackChartScreenProfitLoss => 'П/У';

  @override
  String get stackChartScreenStack => 'Stack';

  @override
  String get quickStackSearchHint => 'Найти или добавить игрока...';

  @override
  String get sessionHandsLoading => 'Загрузка рук...';

  @override
  String createEventDefaultCashGame(String stakes) {
    return 'Cash Game $stakes';
  }

  @override
  String get createEventDefaultCashGameNoStakes => 'Cash Game';

  @override
  String get eventDashboardTvMode => 'Режим ТВ-дисплея';

  @override
  String get tableSelectionTitle => 'Выбор стола';

  @override
  String get tableSelectionAdminSubtitle => 'Выберите стол для управления';

  @override
  String get tableSelectionMemberSubtitle =>
      'Выберите стол для просмотра наличия мест';

  @override
  String get tableSelectionNoTables => 'Нет доступных столов';

  @override
  String tableSelectionOpenSeats(int count) {
    return '$count свободных';
  }

  @override
  String tableSelectionSeated(int occupied) {
    return '$occupied/9 занято';
  }

  @override
  String get monthJan => 'Янв';

  @override
  String get monthFeb => 'Фев';

  @override
  String get monthMar => 'Мар';

  @override
  String get monthApr => 'Апр';

  @override
  String get monthMay => 'Май';

  @override
  String get monthJun => 'Июн';

  @override
  String get monthJul => 'Июл';

  @override
  String get monthAug => 'Авг';

  @override
  String get monthSep => 'Сен';

  @override
  String get monthOct => 'Окт';

  @override
  String get monthNov => 'Ноя';

  @override
  String get monthDec => 'Дек';

  @override
  String get weekdaySun => 'Вс';

  @override
  String get weekdayMon => 'Пн';

  @override
  String get weekdayTue => 'Вт';

  @override
  String get weekdayWed => 'Ср';

  @override
  String get weekdayThu => 'Чт';

  @override
  String get weekdayFri => 'Пт';

  @override
  String get weekdaySat => 'Сб';

  @override
  String opponentsErrorGeneric(String error) {
    return 'Ошибка: $error';
  }

  @override
  String opponentsErrorDeleting(String error) {
    return 'Ошибка удаления противника: $error';
  }

  @override
  String opponentsErrorClearing(String error) {
    return 'Ошибка очистки противников: $error';
  }

  @override
  String get onboardingReadTitle => 'ЧИТАЙ ИГРУ\nКАК PRO';

  @override
  String get onboardingReadSubtitle =>
      'Создайте аккаунт, чтобы начать отслеживать свой покерный путь.';

  @override
  String get onboardingCreateAccount => 'Создать аккаунт';

  @override
  String get onboardingLogIn => 'Войти';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingFinalTable => 'Final Table';

  @override
  String get authExpSignUpTitle => 'Регистрация';

  @override
  String get authExpLogInTitle => 'Войдите в свой аккаунт';

  @override
  String get authExpSignUpSubtitle => 'Создайте аккаунт, чтобы продолжить';

  @override
  String get authExpLogInSubtitle => 'Введите email и пароль для входа';

  @override
  String get authExpName => 'Имя';

  @override
  String get authExpEmail => 'Email';

  @override
  String get authExpEnterName => 'Введите ваше имя';

  @override
  String get authExpNameMinLength => 'Имя должно содержать минимум 2 символа';

  @override
  String get authExpEnterEmail => 'Введите ваш email';

  @override
  String get authExpValidEmail => 'Введите корректный email';

  @override
  String get authExpEnterPassword => 'Введите ваш пароль';

  @override
  String get authExpPasswordMinLength =>
      'Пароль должен содержать минимум 6 символов';

  @override
  String get authExpBySigningUp => 'Регистрируясь, вы принимаете ';

  @override
  String get authExpTermsOfService => 'Условия использования';

  @override
  String get authExpAnd => '\nи ';

  @override
  String get authExpPrivacyPolicy => 'Политику конфиденциальности';

  @override
  String get authExpCreateAccount => 'Создать аккаунт';

  @override
  String get authExpAlreadyHaveAccount => 'Уже есть аккаунт? ';

  @override
  String get authExpSignIn => 'Войти';

  @override
  String get authExpForgotPassword => 'Забыли пароль?';

  @override
  String get authExpDontHaveAccount => 'Нет аккаунта? ';

  @override
  String get authExpSignUp => 'Зарегистрироваться';

  @override
  String get authExpOr => 'или';

  @override
  String get authExpContinueGoogle => 'Продолжить с Google';

  @override
  String authExpLinkGoogleMessage(String email) {
    return 'Аккаунт с адресом $email уже существует. Введите пароль, чтобы привязать аккаунт Google.';
  }

  @override
  String forgotPasswordCodeSubtitle(String email) {
    return 'Введите 6-значный код, отправленный на $email';
  }

  @override
  String get usernameSetupChangeTitle => 'Изменить имя пользователя';

  @override
  String get usernameSetupChooseTitle => 'Выберите имя пользователя';

  @override
  String get usernameSetupSubtitle =>
      'Так вас будут знать другие игроки за столом';

  @override
  String get usernameSetupRequired => 'Имя пользователя обязательно';

  @override
  String get usernameSetupCheckingAvailability => 'Проверка доступности…';

  @override
  String get usernameSetupAvailable => 'Доступно!';

  @override
  String get usernameSetupAlreadyTaken => 'Уже занято';

  @override
  String get usernameSetupCurrentUsername =>
      'Это ваше текущее имя пользователя';

  @override
  String get usernameSetupCouldNotCheck => 'Не удалось проверить доступность';

  @override
  String get usernameSetupJustTaken =>
      'Имя пользователя только что занято. Попробуйте другое.';

  @override
  String get usernameSetupRulesHint =>
      '3–20 символов · буквы, цифры, подчёркивания';

  @override
  String get usernameSetupUpdateButton => 'Обновить имя';

  @override
  String get usernameSetupClaimButton => 'Занять имя';

  @override
  String get usernameSetupSkip => 'Пропустить';

  @override
  String get sessionHandsTitle => 'Сессия';

  @override
  String sessionHandsHandsLogged(int count) {
    return '$count рук записано';
  }

  @override
  String get sessionHandsError => 'Ошибка';

  @override
  String get sessionHandsNoHandsTitle => 'Нет записанных рук';

  @override
  String get sessionHandsNoHandsSubtitle =>
      'В этой сессии пока нет записанных рук.';

  @override
  String get sessionHandsWon => 'ВЫИГРЫШ';

  @override
  String sessionHandsActions(int count) {
    return '$count действий';
  }

  @override
  String get sessionHandsPot => 'Pot';

  @override
  String get stackChartScreenTitle => 'График Stack';

  @override
  String get stackChartScreenPokerSession => 'Покерная сессия';

  @override
  String get notificationsScreenTitle => 'Уведомления';

  @override
  String get notificationsScreenToday => 'Сегодня';

  @override
  String get notificationsScreenMarkAllAsRead => 'Отметить все как прочитанные';

  @override
  String get notificationsScreenMarkAsRead => 'Отметить как прочитанное';

  @override
  String get notificationsScreenNoNotifications => 'Нет уведомлений';

  @override
  String get notificationsScreenClubInvitation => 'Приглашение в клуб';

  @override
  String get notificationsScreenInvitedToJoin =>
      'Вас пригласили присоединиться';

  @override
  String get notificationsScreenDecline => 'Отклонить';

  @override
  String get notificationsScreenNotAuthenticated => 'Не авторизован';

  @override
  String get notificationsScreenRequestResolved => 'Запрос решён';

  @override
  String get notificationsScreenRequestClosed => 'Запрос закрыт';

  @override
  String get notificationsScreenResponse => 'Ответ';

  @override
  String get notificationsScreenEvents => 'События';

  @override
  String get notificationsScreenRsvp => 'RSVP';

  @override
  String get notificationsScreenClubs => 'Клубы';

  @override
  String get notificationsScreenInvitations => 'Приглашения';

  @override
  String get notificationsScreenSeats => 'Места';

  @override
  String get notificationsScreenSupport => 'Поддержка';

  @override
  String notifEventCreatedTitle(String eventName) {
    return 'Новое событие: $eventName';
  }

  @override
  String notifEventCreatedBody(String date) {
    return '$date';
  }

  @override
  String notifEventUpdatedTitle(String eventName) {
    return 'Событие обновлено: $eventName';
  }

  @override
  String notifEventUpdatedBody(String clubName) {
    return '$clubName обновил детали события';
  }

  @override
  String notifEventCancelledTitle(String eventName) {
    return 'Событие отменено: $eventName';
  }

  @override
  String notifEventCancelledBody(String clubName, String date) {
    return '$clubName отменил событие, запланированное на $date';
  }

  @override
  String notifEventStartingTitle(String eventName) {
    return '$eventName начнётся через 1 час!';
  }

  @override
  String notifEventStartingBody(String clubName) {
    return 'Событие $clubName вот-вот начнётся';
  }

  @override
  String notifEventStartedTitle(String eventName) {
    return '$eventName уже в ЭФИРЕ!';
  }

  @override
  String notifEventStartedBody(String clubName) {
    return 'Событие $clubName началось — присоединяйтесь';
  }

  @override
  String notifSeatAvailableTitle(String eventName) {
    return 'Свободное место: $eventName';
  }

  @override
  String notifSeatAvailableBody(String clubName) {
    return 'Место доступно в $clubName! Откройте приложение, чтобы занять его.';
  }

  @override
  String notifMemberRsvpTitle(String memberName) {
    return 'RSVP: $memberName';
  }

  @override
  String notifMemberRsvpBody(
      String memberName, String rsvpStatus, String eventName) {
    return '$memberName ответил \"$rsvpStatus\" на $eventName';
  }

  @override
  String get notifNewClubRequestTitle => 'Новый запрос на клуб';

  @override
  String get notifNewClubRequestBody =>
      'Подана новая заявка на регистрацию клуба';

  @override
  String get notifClubApprovedTitle => 'Клуб одобрен';

  @override
  String get notifClubApprovedBody => 'Ваш клуб одобрен!';

  @override
  String get notifClubRejectedTitle => 'Клуб отклонён';

  @override
  String get notifClubRejectedBody => 'Ваш запрос на клуб отклонён';

  @override
  String get notifMemberInvitedTitle => 'Приглашение в клуб';

  @override
  String get notifMemberInvitedBody => 'Вас пригласили вступить в клуб';

  @override
  String get notifInvitationAcceptedTitle => 'Приглашение принято';

  @override
  String notifInvitationAcceptedBody(String memberName) {
    return '$memberName принял приглашение';
  }

  @override
  String get notifInvitationDeclinedTitle => 'Приглашение отклонено';

  @override
  String notifInvitationDeclinedBody(String memberName) {
    return '$memberName отклонил приглашение';
  }

  @override
  String get notifSupportRequestTitle => 'Запрос в поддержку';

  @override
  String get notifSupportRequestBody => 'Подан новый запрос в поддержку';

  @override
  String get notifSupportUpdatedTitle => 'Обновление поддержки';

  @override
  String get notifSupportUpdatedBody => 'Ваш запрос в поддержку обновлён';

  @override
  String get notifTypeEventCreated => 'Новое событие';

  @override
  String get notifTypeEventUpdated => 'Событие обновлено';

  @override
  String get notifTypeEventCancelled => 'Событие отменено';

  @override
  String get notifTypeEventStarting => 'Событие скоро начнётся';

  @override
  String get notifTypeEventStarted => 'Событие началось';

  @override
  String get notifTypeMemberRsvp => 'RSVP участника';

  @override
  String get notifTypeNewClubRequest => 'Новый запрос на клуб';

  @override
  String get notifTypeClubApproved => 'Клуб одобрен';

  @override
  String get notifTypeClubRejected => 'Клуб отклонён';

  @override
  String get notifTypeMemberInvited => 'Приглашение в клуб';

  @override
  String get notifTypeInvitationAccepted => 'Приглашение принято';

  @override
  String get notifTypeInvitationDeclined => 'Приглашение отклонено';

  @override
  String get notifTypeSeatAvailable => 'Свободное место';

  @override
  String get notifTypeSupportRequest => 'Запрос в поддержку';

  @override
  String get notifTypeSupportUpdated => 'Обновление поддержки';

  @override
  String get invitationsScreenTitle => 'Приглашения в клубы';

  @override
  String get invitationsScreenNoPending => 'Нет ожидающих приглашений';

  @override
  String get invitationsScreenYouWillSee =>
      'Здесь будут отображаться приглашения из клубов';

  @override
  String get invitationsScreenGoBack => 'Назад';

  @override
  String get invitationsScreenUnknownClub => 'Неизвестный клуб';

  @override
  String invitationsScreenInvitedBy(String name) {
    return 'Приглашён $name';
  }

  @override
  String invitationsScreenExpires(String date) {
    return 'Истекает $date';
  }

  @override
  String get invitationsScreenExpired => 'Истекло';

  @override
  String invitationsScreenExpiresInDays(int days) {
    return 'через $days дн.';
  }

  @override
  String invitationsScreenExpiresInHours(int hours) {
    return 'через $hours ч.';
  }

  @override
  String get invitationsScreenExpiresSoon => 'скоро';

  @override
  String get invitationsScreenDecline => 'Отклонить';

  @override
  String get invitationsScreenAccept => 'Принять';

  @override
  String invitationsScreenJoinedAs(String clubName, String role) {
    return 'Вы вступили в $clubName как $role';
  }

  @override
  String get profilePremium => 'Премиум';

  @override
  String get profileFree => 'Бесплатный';

  @override
  String get dealerTableStartNewHand => 'Новая раздача';

  @override
  String get dealerTableStartSessionBtn => 'Начать сессию';

  @override
  String get dealerTableNeedTwoPlayers => 'Нужно минимум 2 игрока для начала';

  @override
  String get dealerTableAddTestPlayers => 'Добавить тестовых игроков';

  @override
  String dealerTableAddedTestPlayers(int count) {
    return 'Добавлено $count тестовых игроков';
  }

  @override
  String dealerTableRolledBack(String street) {
    return 'Откат к $street';
  }

  @override
  String dealerTableUndoneAction(String playerName, String action) {
    return 'Отменено: $playerName $action';
  }

  @override
  String get dealerTableScanToJoin => 'Сканируйте, чтобы занять это место';

  @override
  String get dealerTableOccupiedDot => 'Занято · ';

  @override
  String get dealerTableEmptyLabel => 'Пусто';

  @override
  String get dealerTableOccupiedLabel => 'Занято';

  @override
  String get dealerTableSelectedLabel => 'Выбрано';

  @override
  String get dealerTableSelectSeatLabel => 'ВЫБЕРИТЕ МЕСТО';

  @override
  String get dealerTableBetAmountDialog => 'Сумма Bet';

  @override
  String get dealerTableRaiseToDialog => 'Raise до';

  @override
  String get dealerTablePausedLabel => 'Пауза';

  @override
  String get dealerTableListeningLabel => 'Слушаю';

  @override
  String get dealerTableResumeVoiceTooltip => 'Возобновить голос';

  @override
  String get dealerTablePauseVoiceTooltip => 'Пауза голоса';

  @override
  String get dealerTableVoiceOffLabel => 'Голос выключен';

  @override
  String get dealerTableCalibratingLabel => 'Калибровка...';

  @override
  String get dealerTableCalibrationPrompt =>
      'Скажите: «Стол [номер], Dealer [имя]»';

  @override
  String dealerTableDealerLockedMsg(String name, String table) {
    return 'Dealer закреплён: $name за столом $table';
  }

  @override
  String get dealerTableNoSpeakersMsg => 'Голос не обнаружен — говорите чётче';

  @override
  String get dealerTableSayTableDealerMsg =>
      'Скажите: «Стол [номер], Dealer [имя]»';

  @override
  String get dealerTableConnectionLostRecovery =>
      'Соединение потеряно — попытка восстановления...';

  @override
  String get dealerTableConnectionTimeout =>
      'Тайм-аут соединения — требуется повторная калибровка';

  @override
  String get dealerTableConnectionRecovered => 'Соединение восстановлено!';

  @override
  String get dealerTableActionHeldMsg => 'Действие отложено';

  @override
  String get dealerTableFailedStartStreaming =>
      'Не удалось начать стриминг — проверьте подключение к серверу и микрофон';

  @override
  String dealerTableFailedStartVoice(String error) {
    return 'Не удалось запустить голос: $error';
  }

  @override
  String get dealerTableAddPlayerActionLabel => 'Добавить игрока';

  @override
  String get dealerTableSeatAnotherPlayer => 'Посадить другого игрока сюда';

  @override
  String get dealerTableSitHereLabel => 'Сесть здесь';

  @override
  String get dealerTableJoinAsDealerPlayer =>
      'Присоединиться к игре как Dealer-игрок';

  @override
  String get dealerTableDealerFallback => 'Dealer';

  @override
  String dealerTableUpdatedStackMsg(String name, String amount) {
    return 'Stack $name обновлён до $amount';
  }

  @override
  String dealerTableFailedUpdateStackMsg(String error) {
    return 'Не удалось обновить Stack: $error';
  }

  @override
  String dealerTableSittingAtSeatMsg(int number) {
    return 'Вы теперь играете на месте $number';
  }

  @override
  String dealerTableFailedSitMsg(String error) {
    return 'Не удалось сесть за стол: $error';
  }

  @override
  String dealerTableFailedAddPlayerMsg(String error) {
    return 'Не удалось добавить игрока: $error';
  }

  @override
  String dealerTableRemovedFromSeat(String name, int seat) {
    return '$name удалён с места $seat';
  }

  @override
  String dealerTableFailedRemoveMsg(String error) {
    return 'Не удалось удалить игрока: $error';
  }

  @override
  String get eventDetailDateAndTime => 'Дата и время';

  @override
  String eventDetailTableSeatInfo(String table, int seat) {
    return 'Стол $table, Место #$seat';
  }

  @override
  String get eventDetailYoureSeatedGoodLuck => 'Вы на месте, удачи!';

  @override
  String get eventDetailHomeGame => 'Домашняя игра';

  @override
  String get clubDashboardDateLabel => 'Дата';

  @override
  String get clubDashboardUnknownLabel => 'Неизвестно';

  @override
  String get clubDashboardActiveLabel => 'Активный';

  @override
  String get clubDashboardIdleLabel => 'Неактивный';

  @override
  String clubDashboardInvitedTimeAgo(String time) {
    return 'Приглашён $time';
  }

  @override
  String get clubDashboardPendingLabel => 'Ожидает';

  @override
  String get clubDashboardNoDealersYet => 'Нет Dealerов';

  @override
  String get clubDashboardInviteDealersHint =>
      'Пригласите Dealerов для управления вашими столами';

  @override
  String get clubDashboardInviteDealer => 'Пригласить Dealerа';

  @override
  String get clubDashboardInviteDealerBody =>
      'Введите email Dealerа, которого хотите пригласить.';

  @override
  String get clubDashboardSendInvitationBtn => 'Отправить приглашение';

  @override
  String clubDashboardInvitationSentTo(String email) {
    return 'Приглашение отправлено на $email';
  }

  @override
  String clubDashboardFailedSendInvitationMsg(String error) {
    return 'Не удалось отправить приглашение: $error';
  }

  @override
  String get clubDashboardCancelInvitationTitle => 'Отменить приглашение?';

  @override
  String clubDashboardCancelInvitationBody(String email) {
    return 'Отменить приглашение для $email?';
  }

  @override
  String get clubDashboardKeepBtn => 'Оставить';

  @override
  String get clubDashboardCancelInvitationBtn => 'Отменить приглашение';

  @override
  String clubDashboardFailedCancelMsg(String error) {
    return 'Не удалось отменить приглашение: $error';
  }

  @override
  String clubSettingsMembers(int count) {
    return 'Участники ($count)';
  }

  @override
  String get clubSettingsNoMembersFound => 'Участники не найдены';

  @override
  String get clubSettingsRoleOwner => 'Владелец';

  @override
  String get clubSettingsRoleAdmin => 'Админ';

  @override
  String get clubSettingsRoleDealer => 'Dealer';

  @override
  String get clubSettingsRolePlayer => 'Игрок';

  @override
  String get clubSettingsTableAddedMsg => 'Стол добавлен';

  @override
  String get clubSettingsEditTableTitle => 'Редактировать стол';

  @override
  String get clubSettingsDeleteTableTitle => 'Удалить стол?';

  @override
  String clubSettingsDeleteTableBody(String name) {
    return 'Вы уверены, что хотите удалить «$name»? Это действие нельзя отменить.';
  }

  @override
  String get clubSettingsTableDeletedMsg => 'Стол удалён';

  @override
  String get clubSettingsDealerScanHint =>
      'Dealerы сканируют этот код, чтобы начать сессию за этим столом';

  @override
  String get clubSettingsRegenerateBtn => 'Обновить';

  @override
  String get clubSettingsAppQrCodes => 'QR-коды приложения';

  @override
  String get clubSettingsShareWithPlayers =>
      'Поделитесь с игроками для скачивания приложения';

  @override
  String get clubSettingsDownloadPdf => 'Скачать PDF';

  @override
  String get clubSettingsDownloadFinalTable =>
      'Скачайте приложение Final Table';

  @override
  String get clubSettingsScanQrToGetStarted =>
      'Отсканируйте QR-код для вашего устройства, чтобы начать';

  @override
  String get clubSettingsScanToStartSession =>
      'Отсканируйте этот QR-код, чтобы начать сессию';

  @override
  String get clubSettingsForDealersOnly => 'Только для Dealerов';

  @override
  String clubSettingsTableDefault(int number) {
    return 'Стол $number';
  }

  @override
  String eventManagementFailedUpdateEvent(String error) {
    return 'Не удалось обновить событие: $error';
  }

  @override
  String adminTableThisWillMoveMsg(int count) {
    return 'Это переместит $count игрока(ов) в лист ожидания и удалит стол из этого события.';
  }

  @override
  String get adminTableThisWillRemoveMsg => 'Это удалит стол из этого события.';

  @override
  String adminTableClosedWithWaitlistMsg(String table, int count) {
    return '$table закрыт. $count игрок(ов) перемещено в лист ожидания.';
  }

  @override
  String adminTableClosedMsg(String table) {
    return '$table закрыт.';
  }

  @override
  String get adminTableEmptyLabel => 'Пусто';

  @override
  String get adminTableTableFallback => 'Стол';

  @override
  String adminTableTableNumberLabel(int number) {
    return 'Стол $number';
  }

  @override
  String homePendingInvitationsMsg(int count) {
    return 'У вас $count ожидающих приглашений в клубы.';
  }

  @override
  String get homeEventFallback => 'Событие';

  @override
  String get homePokerFallback => 'Покер';

  @override
  String get homeUserFallback => 'Пользователь';

  @override
  String homeSeatInfoStr(int seat, String chipStack) {
    return 'Место #$seat  •  $chipStack';
  }

  @override
  String get pokerHandYouLabel => 'Вы';

  @override
  String pokerHandMovingToTable(int table, String stack) {
    return 'Переход к столу $table. Ваш Stack ($stack) будет перенесён. Остальные игроки будут удалены.';
  }

  @override
  String pokerHandActiveSessionMsg(int count) {
    return 'У вас активная сессия с $count записанными руками. Что вы хотите сделать?';
  }

  @override
  String get pokerHandUnknownLabel => 'Неизвестно';

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
      'Все игроки All-In — раздаются оставшиеся карты';

  @override
  String get pokerHandWaitingForCards => 'Ожидание раздачи карт';

  @override
  String get pokerHandBettingComplete =>
      'Торговля завершена — готово к следующей улице';

  @override
  String pokerHandSeatFallback(int id) {
    return 'Место $id';
  }

  @override
  String pokerHandPlayerFallback(int id) {
    return 'Игрок $id';
  }

  @override
  String get pokerHandChooseOption => 'Выберите вариант:';

  @override
  String get pokerHandLeaveBtn => 'Уйти';

  @override
  String get pokerHandConfirmBtn => 'Подтвердить';

  @override
  String pokerHandCurrentlyHaveRemaining(String stack) {
    return 'У вас осталось $stack.';
  }

  @override
  String get opponentsColorRed => 'Красный';

  @override
  String get opponentsColorLightBlue => 'Голубой';

  @override
  String get opponentsColorGreen => 'Зелёный';

  @override
  String get opponentsColorOrange => 'Оранжевый';

  @override
  String get opponentsColorPurple => 'Фиолетовый';

  @override
  String get opponentsColorTeal => 'Бирюзовый';

  @override
  String get opponentsColorPink => 'Розовый';

  @override
  String get opponentsColorIndigo => 'Индиго';

  @override
  String opponentsFailedToLoad(String error) {
    return 'Не удалось загрузить оппонентов: $error';
  }

  @override
  String get opponentDetailFoldTo3Bet => 'Fold to 3-Bet';

  @override
  String get opponentDetailStealLabel => 'Steal';

  @override
  String get opponentDetailCheckRaiseLabel => 'Check/Raise';

  @override
  String get individualSetupSessionSetup => 'Настройка сессии';

  @override
  String get individualSetupSessionNameLabel => 'Название сессии';

  @override
  String get individualSetupGameTypeLabel => 'Тип игры';

  @override
  String get individualSetupCashGameLabel => 'Cash Game';

  @override
  String get individualSetupTournamentLabel => 'Tournament';

  @override
  String get individualSetupBuyInAmountLabel => 'Сумма Buy-in';

  @override
  String get individualSetupEnterAmountHint => 'Введите сумму';

  @override
  String get individualSetupCashGameNote =>
      'В Cash Game ваш начальный Stack равен сумме Buy-in.';

  @override
  String get individualSetupStartingStackLabel => 'Начальный Stack';

  @override
  String get individualSetupEnterChipStackHint => 'Введите Stack фишек';

  @override
  String individualSetupStackValidation(int bigBlind) {
    return 'Начальный Stack должен быть не менее Big Blind ($bigBlind)';
  }

  @override
  String get individualSetupStartSessionBtn => 'Начать сессию';

  @override
  String get individualSetupEnterValueHint => 'Введите значение';

  @override
  String get individualHandSetupTitle => 'Отдельная раздача';

  @override
  String get individualHandSetupSubtitle => 'Быстрая запись раздачи';

  @override
  String get individualHandSetupHandNameLabel =>
      'Название раздачи (необязательно)';

  @override
  String get playerSessionBluff => 'Bluff';

  @override
  String get playerSessionValue => 'Value';

  @override
  String get playerSessionMistake => 'Ошибка';

  @override
  String get playerSessionCooler => 'Cooler';

  @override
  String get playerSessionHeroCall => 'Hero Call';

  @override
  String get playerSessionExploit => 'Exploit';

  @override
  String get playerSessionToughSpot => 'Сложная ситуация';

  @override
  String get playerSessionEasyFold => 'Лёгкий Fold';

  @override
  String get playerSessionEndedTitle => 'Сессия завершена';

  @override
  String get playerSessionEndedBody => 'Dealer завершил эту сессию.';

  @override
  String get playerSessionRemovedTitle => 'Удалены со стола';

  @override
  String get playerSessionRemovedBody => 'Вы были удалены со стола Dealerом.';

  @override
  String playerSessionYouWon(String amount) {
    return 'Вы выиграли $amount!';
  }

  @override
  String playerSessionSeatWins(int seat, String amount) {
    return 'Место $seat выигрывает $amount';
  }

  @override
  String get playerSessionYourHoleCardsTitle => 'Ваши Hole Cards';

  @override
  String get playerSessionConnecting => 'Подключение...';

  @override
  String get playerSessionGoBackBtn => 'Назад';

  @override
  String get playerSessionHoleCardsLabel => 'Hole Cards';

  @override
  String get playerSessionEditBtn => 'Редактировать';

  @override
  String get playerSessionAddBtn => 'Добавить';

  @override
  String get playerSessionBoardLabel => 'Board';

  @override
  String get playerSessionNoCardsDealt => 'Карты не розданы';

  @override
  String get playerSessionWaitingForAction => 'Ожидание действия...';

  @override
  String get playerSessionActionsLabel => 'Действия';

  @override
  String get playerSessionYouLabel => 'Вы';

  @override
  String playerSessionSeatFallback(int seat) {
    return 'Место $seat';
  }

  @override
  String get playerSessionNotesHintText =>
      'Добавьте заметки об этой раздаче...';

  @override
  String get playerSessionHandHistoryLabel => 'История раздач';

  @override
  String get playerSessionNoCompletedHands => 'Нет завершённых раздач';

  @override
  String playerSessionWonAmount(String amount) {
    return 'Выигрыш $amount';
  }

  @override
  String get playerSessionLostLabel => 'Проигрыш';

  @override
  String get playerSessionDealerChangeTitle => 'Смена Dealerа';

  @override
  String get playerSessionWaitingForDealer => 'Ожидание нового Dealerа...';

  @override
  String playerSessionHandUpdated(int number) {
    return 'Раздача #$number обновлена';
  }

  @override
  String playerSessionErrorSaving(String error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String playerSessionEditHand(int number) {
    return 'Редактировать раздачу #$number';
  }

  @override
  String get playerSessionViewDetails => 'Подробнее';

  @override
  String get playerSessionTapToAddHoleCards =>
      'Нажмите, чтобы добавить Hole Cards';

  @override
  String get playerSessionSaveChanges => 'Сохранить изменения';

  @override
  String get playerSessionLeaveTableTitle => 'Покинуть стол?';

  @override
  String get playerSessionLeaveTableBody =>
      'Вы уверены, что хотите покинуть этот стол?';

  @override
  String playerSessionFailedLeave(String error) {
    return 'Не удалось выйти: $error';
  }

  @override
  String get playerSessionTableSession => 'Сессия за столом';

  @override
  String playerSessionHandNumber(int number) {
    return 'Раздача #$number';
  }

  @override
  String get playerSessionUnknownDealer => 'Неизвестно';

  @override
  String get playerSessionNotAuthenticated => 'Не авторизован';

  @override
  String get dealerQrScanSessionSettings => 'Настройки сессии';

  @override
  String dealerQrScanTableNameLabel(String name) {
    return 'Стол: $name';
  }

  @override
  String dealerQrScanEventNameLabel(String name) {
    return 'Событие: $name';
  }

  @override
  String get dealerQrScanBlindsLabel => 'Блайнды';

  @override
  String get dealerQrScanSmallBlindLabel => 'Small Blind';

  @override
  String get dealerQrScanBigBlindLabel => 'Big Blind';

  @override
  String get dealerQrScanStartDealingBtn => 'Начать раздачу';

  @override
  String get dealerQrScanResumeSessionTitle => 'Возобновить сессию';

  @override
  String dealerQrScanTakingOverFrom(String name) {
    return 'Смена с $name';
  }

  @override
  String get dealerQrScanHandsPlayedLabel => 'Сыграно раздач';

  @override
  String get dealerQrScanBlindsInfoLabel => 'Блайнды';

  @override
  String get dealerQrScanPlayersLabel => 'Игроки';

  @override
  String get dealerQrScanResumeBtn => 'Возобновить';

  @override
  String get dealerQrScanTableNotAssigned => 'Стол не назначен';

  @override
  String get dealerQrScanEventTablesLabel => 'Столы события:';

  @override
  String get dealerQrScanNoTablesAssigned => 'Нет назначенных столов';

  @override
  String get dealerQrScanThisTableId => 'ID этого стола:';

  @override
  String get dealerQrScanCorrectQrUrl => 'Правильный URL QR-кода:';

  @override
  String get dealerQrScanScanTableQrTitle => 'Сканировать QR стола';

  @override
  String get dealerQrScanScanInstructions =>
      'Отсканируйте QR-код стола, чтобы начать раздачу';

  @override
  String get eventDashboardTournamentOnBreak => 'Tournament на перерыве';

  @override
  String get eventDashboardLiveLabel => 'Онлайн';

  @override
  String get eventDashboardLocalLabel => 'Локально';

  @override
  String get eventDashboardDisconnectedLabel => 'Отключён';

  @override
  String get eventDashboardPlayersLabel => 'Игроки';

  @override
  String get eventDashboardTablesLabel => 'Столы';

  @override
  String get eventDashboardTotalChipsLabel => 'Всего фишек';

  @override
  String get eventDashboardAvgStackLabel => 'Средний Stack';

  @override
  String get eventDashboardChipLeaderLabel => 'Chip Leader';

  @override
  String get eventDashboardNoRankingsYet => 'Нет рейтингов';

  @override
  String get eventDashboardRankingsWillAppear =>
      'Рейтинги появятся, когда игроки присоединятся к столам';

  @override
  String eventDashboardTableSeatLabel(String table, int seat) {
    return '$table - Место $seat';
  }

  @override
  String eventDashboardPlayerFallback(String id) {
    return 'Игрок $id';
  }

  @override
  String get commonNA => 'Н/Д';

  @override
  String sessionHistoryFailedLoad(String error) {
    return 'Не удалось загрузить сессии: $error';
  }

  @override
  String get sessionHistoryCash => 'Cash';

  @override
  String get sessionHistoryTournament => 'Tournament';

  @override
  String sessionHistorySessionId(String id) {
    return 'Сессия $id...';
  }

  @override
  String sessionHistorySeatWithPosition(String seat, String position) {
    return 'Место $seat ($position)';
  }

  @override
  String sessionHistorySeat(String seat) {
    return 'Место $seat';
  }

  @override
  String get sessionHistorySyncCompleted => 'Синхронизация завершена';

  @override
  String get sessionHistoryFullHistory => 'Полная история сессий';

  @override
  String get sessionHandsRetry => 'Повторить';

  @override
  String get stackChartScreenStart => 'Старт';

  @override
  String get stackChartScreenRebuy => 'Rebuy';

  @override
  String get stackChartScreenEnd => 'Конец';

  @override
  String get quickStackSelectPlayer => 'Выбрать игрока';

  @override
  String quickStackAddPlayer(String name) {
    return 'Добавить «$name»';
  }

  @override
  String get quickStackSaveToOpponents => 'Сохранить в список оппонентов';

  @override
  String get quickStackYou => 'Вы';

  @override
  String get quickStackNoPlayersFound => 'Игроки не найдены.';

  @override
  String get seatSetupDone => 'Готово';

  @override
  String get seatSetupCancel => 'Отмена';

  @override
  String get authConnectionIssue => 'Проблема с подключением';

  @override
  String get authConnectionIssueBody =>
      'Не удалось подключиться к нашим серверам.\nПожалуйста, проверьте интернет-соединение\nи попробуйте снова.';

  @override
  String get authTryAgain => 'Попробовать снова';

  @override
  String get redeemInvitationTitle => 'Активировать приглашение';

  @override
  String get redeemEnterCode => 'Введите код приглашения';

  @override
  String get redeemCodeDescription =>
      'Введите 8-значный код, полученный от администратора клуба, чтобы вступить в их клуб.';

  @override
  String get redeemJoinClub => 'Вступить в клуб';

  @override
  String get redeemWelcome => 'Добро пожаловать!';

  @override
  String redeemJoinedAs(String clubName, String role) {
    return 'Вы вступили в $clubName как $role';
  }

  @override
  String get redeemContinue => 'Продолжить';

  @override
  String get supportBugReport => 'Сообщение об ошибке';

  @override
  String get supportFeatureRequest => 'Запрос функции';

  @override
  String get supportAccountIssue => 'Проблема с аккаунтом';

  @override
  String get supportOther => 'Другое';

  @override
  String get supportFillAllFields => 'Пожалуйста, заполните все поля';

  @override
  String get supportSubmitted => 'Запрос в поддержку успешно отправлен';

  @override
  String supportFailedSubmit(String error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String get supportTitle => 'Помощь и поддержка';

  @override
  String get supportSubmitButton => 'Отправить';

  @override
  String get supportCategoryLabel => 'КАТЕГОРИЯ';

  @override
  String get supportSubjectLabel => 'ТЕМА';

  @override
  String get supportDescriptionLabel => 'ОПИСАНИЕ';

  @override
  String get supportSubjectHint => 'Краткое описание проблемы';

  @override
  String get supportDescriptionHint => 'Опишите проблему подробно...';

  @override
  String get calendarEventLocation => 'Местоположение';

  @override
  String get calendarEventBuyIn => 'Сумма бай-ина';

  @override
  String get calendarEventEdit => 'Редактировать';

  @override
  String get calendarEventDelete => 'Удалить событие';

  @override
  String calendarEventDeleteConfirm(String title) {
    return 'Удалить $title?';
  }

  @override
  String calendarEventDeleteBody(String title) {
    return 'Вы уверены, что хотите удалить \"$title\"?\nЭто действие нельзя отменить.';
  }

  @override
  String get calendarEventDeleteButton => 'Удалить';

  @override
  String get clubInfoTitle => 'Информация о клубе';

  @override
  String clubInfoMembersCount(int count) {
    return 'Участники ($count)';
  }

  @override
  String get clubInfoNoMembers => 'Участники не найдены';

  @override
  String get finalStandingsNoData => 'Результаты недоступны';

  @override
  String get finalStandingsNoDataHint =>
      'Это событие могло не записать результаты';

  @override
  String get finalStandingsEmpty => 'Результаты не записаны';

  @override
  String get finalStandingsTitle => 'Итоговые результаты';

  @override
  String get finalStandingsPlayers => 'Игроки';

  @override
  String get finalStandingsCompleted => 'Завершено';

  @override
  String get liveRankingsTitle => 'Живые рейтинги';

  @override
  String get liveRankingsEliminated => 'Выбывшие игроки';

  @override
  String get liveRankingsWaiting => 'Ожидание игроков';

  @override
  String get liveRankingsWaitingHint =>
      'Рейтинги появятся, когда игроки займут места';

  @override
  String get liveRankingsError => 'Ошибка загрузки рейтингов';

  @override
  String get liveRankingsTryAgain => 'Попробовать снова';

  @override
  String get leaderboardPlayers => 'Игроки';

  @override
  String get leaderboardTotalChips => 'Всего фишек';

  @override
  String get leaderboardWaiting => 'Ожидание игроков...';

  @override
  String leaderboardChipLeader(String name) {
    return 'Chip Leader: $name';
  }

  @override
  String get dealerQrScanBbAnte => 'BB Ante';

  @override
  String mainDealerOnClub(String clubName) {
    return 'Теперь вы дилер в $clubName';
  }

  @override
  String get raiseSnapMin => 'Мин';

  @override
  String get raiseSnapPot => 'Банк';

  @override
  String get raiseSnapAllIn => 'All-In';

  @override
  String sessionHistoryPlayerWins(int playerId) {
    return 'Игрок $playerId выигрывает:';
  }

  @override
  String get inviteClubAdminFallback => 'Администратор клуба';

  @override
  String pokerHandBetRange(String min, String max) {
    return 'Мин: $min · Макс: $max';
  }

  @override
  String pokerHandAmountBetween(String min, String max) {
    return 'Сумма должна быть от $min до $max';
  }

  @override
  String get dealerTableBlindsLabel => 'БЛАЙНДЫ';

  @override
  String dealerTableAnteLabel(String amount) {
    return 'АНТЕ $amount';
  }

  @override
  String get dealerTablePotLabel => 'БАНК';

  @override
  String get dealerTableCheckLabel => 'CHECK';

  @override
  String dealerTablePlayerToAct(String playerName, String stack) {
    return '$playerName действует ($stack)';
  }

  @override
  String get eventDashboardOnBreakBadge => 'ПЕРЕРЫВ';

  @override
  String get eventDetailAdminActions => 'ДЕЙСТВИЯ АДМИНИСТРАТОРА';

  @override
  String get playerSessionHandNotesLabel => 'ЗАМЕТКИ К РАЗДАЧЕ';

  @override
  String get playerSessionTagsLabel => 'ТЕГИ';

  @override
  String get playerSessionNotesLabel => 'ЗАМЕТКИ';

  @override
  String get playerSessionHoleCardsUpperLabel => 'КАРМАННЫЕ КАРТЫ';

  @override
  String get qrJoinDeclined => 'Ваш запрос на присоединение был отклонён';

  @override
  String qrJoinFailed(String error) {
    return 'Не удалось присоединиться к месту: $error';
  }

  @override
  String get qrJoinTable => 'Присоединиться к столу';

  @override
  String get qrJoinLoading => 'Загрузка информации о столе...';

  @override
  String get qrJoinError => 'Что-то пошло не так';

  @override
  String get qrJoinGoBack => 'Назад';

  @override
  String get qrJoinSeatOccupied =>
      'Это место может быть уже занято. Присоединение заменит текущего игрока.';

  @override
  String get qrJoinWaitingDealer => 'Ожидание дилера';

  @override
  String qrJoinRequestSent(int seatNumber) {
    return 'Ваш запрос на присоединение к Месту $seatNumber отправлен.';
  }

  @override
  String get qrJoinDealerApproval =>
      'Дилер установит ваш стек фишек и подтвердит присоединение.';

  @override
  String get qrJoinCancelRequest => 'Отменить запрос';

  @override
  String get qrJoinRequestButton => 'Запрос на присоединение';

  @override
  String get onboardingSkipTour => 'Пропустить тур';

  @override
  String get onboardingWelcomeTitle => 'Добро пожаловать в Final Table';

  @override
  String get onboardingWelcomeBody =>
      'Давайте проведём быстрый тур для начала.\n\nВы всегда можете повторить этот тур из\nПрофиль → Настройки → База знаний.';

  @override
  String get onboardingLetsGo => 'Поехали';

  @override
  String get onboardingGotIt => 'Понял';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingStartLoggingTitle => 'Начать запись';

  @override
  String get onboardingStartLoggingBody =>
      'Нажмите кнопку +, чтобы начать запись раздачи.';

  @override
  String get onboardingFullModeTitle => 'Режим полной записи';

  @override
  String get onboardingFullModeBody =>
      'Отслеживайте каждое действие каждого игрока на всех улицах. Идеально для серьёзного анализа.';

  @override
  String get onboardingIndividualModeTitle => 'Режим индивидуальной записи';

  @override
  String get onboardingIndividualModeBody =>
      'Быстрое отслеживание выигрыша/проигрыша за одну сессию. Теперь выберите режим для продолжения!';

  @override
  String get onboardingSessionSetupTitle => 'Настройка сессии';

  @override
  String get onboardingSessionSetupBody =>
      'Заполните данные сессии — название, бай-ин, блайнды — и нажмите «Начать игру».';

  @override
  String get onboardingTableSetupTitle => 'Настройка стола';

  @override
  String get onboardingTableSetupBody =>
      'Нажмите на любое место, чтобы настроить игроков. Давайте пройдём через диалог места далее.';

  @override
  String get onboardingSeatOpenTitle => 'Свободное место';

  @override
  String get onboardingSeatOpenBody =>
      'Переключите, чтобы отметить место как занятое или пустое. Свободные места пропускаются во время раздачи.';

  @override
  String get onboardingThisIsMySeatTitle => 'Это моё место';

  @override
  String get onboardingThisIsMySeatBody =>
      'Нажмите здесь, если это ваше место. Автоматически заполняет ваше имя и отслеживает вашу личную статистику.';

  @override
  String get onboardingPlayerNameTitle => 'Имя игрока';

  @override
  String get onboardingPlayerNameBody =>
      'Введите имя или выберите из сохранённых соперников. Сохранённые соперники отслеживают статистику между сессиями.';

  @override
  String get onboardingSaveOpponentTitle => 'Сохранить соперника';

  @override
  String get onboardingSaveOpponentBody =>
      'Новое имя? Нажмите здесь, чтобы сохранить его как соперника. Его статистика будет отслеживаться автоматически.';

  @override
  String get onboardingDealerButtonTitle => 'Кнопка дилера';

  @override
  String get onboardingDealerButtonBody =>
      'Перетащите это на место с позицией дилера. Это определяет блайнды и порядок действий.';

  @override
  String get onboardingViewSessionsTitle => 'Просмотр сессий';

  @override
  String get onboardingViewSessionsBody =>
      'Нажмите «Сессии», чтобы увидеть результаты сессий, историю раздач и статистику.';

  @override
  String get onboardingAllSetTitle => 'Всё готово!';

  @override
  String get onboardingAllSetBody =>
      'Вы готовы начать отслеживать свои покерные сессии.';

  @override
  String get onboardingLetsPlay => 'Играть';

  @override
  String get onboardingUpdateStackTitle => 'Обновить стек';

  @override
  String get onboardingUpdateStackBody =>
      'Используйте это для ручного обновления количества фишек в любой момент без записи полной раздачи.';

  @override
  String get onboardingLogAHandTitle => 'Записать раздачу';

  @override
  String get onboardingLogAHandBody =>
      'Нажмите здесь, чтобы настроить стол и записать раздачу. Попробуем прямо сейчас!';

  @override
  String get onboardingMarkSeatOpenTitle => 'Отметить место как свободное';

  @override
  String get onboardingMarkSeatOpenBody =>
      'Нажмите на флажок, чтобы переключить место между занятым и пустым. Пустые места пропускаются в раздаче.';

  @override
  String get onboardingDealerButtonQsuTitle => 'Кнопка дилера';

  @override
  String get onboardingDealerButtonQsuBody =>
      'Нажмите «D», чтобы назначить кнопку дилера на любое место. Это управляет позициями блайндов и порядком действий.';

  @override
  String get onboardingAssignPlayerTitle => 'Назначить игрока';

  @override
  String get onboardingAssignPlayerBody =>
      'Нажмите на имя игрока, чтобы посадить себя или сохранённого соперника. Ваш стек применяется автоматически, когда вы садитесь.';

  @override
  String get onboardingAdjustStackTitle => 'Настройка стека';

  @override
  String get onboardingAdjustStackBody =>
      'Перетащите ползунок, чтобы установить стек соперника в BB. Нажмите на значение стека, чтобы ввести точную сумму.';

  @override
  String get onboardingEndSessionTitle => 'Завершить сессию';

  @override
  String get onboardingEndSessionBody =>
      'Нажмите красную кнопку «Стоп», чтобы сохранить результаты сессии и вернуться на главный экран.';

  @override
  String onboardingStepOf(int step, int total) {
    return 'Шаг $step из $total';
  }

  @override
  String get guidedGestureGuideTitle => 'Руководство по жестам';

  @override
  String get guidedGestureGuideBody =>
      'Нажмите на эту иконку в любое время, чтобы увидеть все жесты управления.';

  @override
  String get guidedSkipButtonTitle => 'Кнопка пропуска';

  @override
  String get guidedSkipButtonBody =>
      'Если вы пропускаете раздачу, эта кнопка перемещает кнопку дилера к следующему игроку. Имейте в виду, что стеки могут рассинхронизироваться — вы можете обновить их в разделе «Управление игроками».';

  @override
  String get guidedGameMenuTitle => 'Меню игры';

  @override
  String get guidedGameMenuBody =>
      'В этом меню есть полезные опции. Давайте рассмотрим одну важную настройку.';

  @override
  String get guidedGameSettingsTitle => 'Настройки игры';

  @override
  String get guidedGameSettingsBody =>
      'Здесь вы можете изменить блайнды в ходе сессии — полезно в турнирах при повышении уровней.';

  @override
  String get guidedEndSessionTitle => 'Завершить сессию';

  @override
  String get guidedEndSessionBody =>
      'Нажмите это меню и выберите «Остановить сессию», чтобы сохранить результаты.';

  @override
  String get guidedReviewHandTitle => 'Просмотр раздачи';

  @override
  String get guidedReviewHandBody => 'Введите свои карты и заметки.';

  @override
  String get guidedHandCompleteTitle => 'Раздача завершена!';

  @override
  String get guidedHandCompleteBody =>
      'Отличная работа! Вы только что записали свою первую раздачу.';

  @override
  String get guidedSkip => 'Пропустить';

  @override
  String get guidedYourTurn => 'Ваш ход!';

  @override
  String get guidedOpenThePotTitle => 'Открыть банк';

  @override
  String get guidedBetOnceBody => 'Этот игрок ставит.';

  @override
  String get guidedFoldTitle => 'Fold';

  @override
  String get guidedFoldBody => 'Этот игрок сбрасывает карты.';

  @override
  String get guidedCallTitle => 'Call';

  @override
  String get guidedCallBody => 'Этот игрок делает call.';

  @override
  String get guidedCheckTitle => 'Check';

  @override
  String get guidedCheckBody => 'Этот игрок делает check.';

  @override
  String get guidedGestureFold => 'Свайп влево ←';

  @override
  String get guidedGestureCheck => 'Нажать';

  @override
  String get guidedGestureCall => 'Нажать';

  @override
  String get guidedGestureBet => 'Свайп вверх ↑';

  @override
  String get guidedGestureRaise => 'Свайп вверх ↑';

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
  String get guidedDealFlopTitle => 'Сдать Flop';

  @override
  String get guidedDealFlopBody => 'Выберите 3 карты для Flop.';

  @override
  String get guidedDealTurnTitle => 'Сдать Turn';

  @override
  String get guidedDealTurnBody => 'Выберите 1 карту для Turn.';

  @override
  String get guidedDealRiverTitle => 'Сдать River';

  @override
  String get guidedDealRiverBody => 'Выберите 1 карту для River.';

  @override
  String get kbStatsTitle => 'Ваша статистика';

  @override
  String get kbClubsTitle => 'Клубы и события';

  @override
  String get kbStatsIntro =>
      'Final Table отслеживает 7 ключевых покерных метрик, чтобы помочь вам понять и улучшить свою игру.';

  @override
  String get kbClubsIntro =>
      'Клубы позволяют вам подключиться к местному покерному залу и отслеживать живые игры.';

  @override
  String get kbVpipName => 'VPIP';

  @override
  String get kbVpipFullName => 'Voluntarily Put \$ In Pot';

  @override
  String get kbVpipDescription =>
      'Как часто вы добровольно входите в банк (исключая постинг блайндов). Высокий VPIP означает игру многими руками; низкий VPIP означает избирательность.';

  @override
  String get kbPfrName => 'PFR';

  @override
  String get kbPfrFullName => 'Preflop Raise';

  @override
  String get kbPfrDescription =>
      'Как часто вы рейзите до флопа. Разница между VPIP и PFR показывает, как часто вы лимпуете или холд-коллируете.';

  @override
  String get kbThreeBetName => '3-Bet';

  @override
  String get kbThreeBetFullName => 'Three-Bet Percentage';

  @override
  String get kbThreeBetDescription =>
      'Как часто вы делаете ре-рейз на открытый рейз соперника до флопа. Более высокий процент 3-Bet указывает на агрессивный стиль до флопа.';

  @override
  String get kbFoldTo3BetName => 'Fold to 3-Bet';

  @override
  String get kbFoldTo3BetFullName => 'Fold to Three-Bet';

  @override
  String get kbFoldTo3BetDescription =>
      'Как часто вы сбрасываете карты после рейза, столкнувшись с 3-Bet. Если слишком часто, соперники могут эксплуатировать вас лёгкими 3-Bet.';

  @override
  String get kbCBetName => 'C-Bet';

  @override
  String get kbCBetFullName => 'Continuation Bet';

  @override
  String get kbCBetDescription =>
      'Как часто вы делаете ставку на Flop, будучи последним агрессором до флопа. Стандартный ход, демонстрирующий силу.';

  @override
  String get kbStealName => 'Steal';

  @override
  String get kbStealFullName => 'Blind Steal Attempt';

  @override
  String get kbStealDescription =>
      'Как часто вы открываете рейзом с поздней позиции (CO, BTN, SB), когда банк не вскрыт, стремясь забрать блайнды.';

  @override
  String get kbCheckRaiseName => 'Check-Raise';

  @override
  String get kbCheckRaiseFullName => 'Flop Check-Raise';

  @override
  String get kbCheckRaiseDescription =>
      'Как часто вы делаете check, а затем raise на Flop. Обманный ход, который может поймать агрессивных соперников.';

  @override
  String get kbLiveEventsTitle => 'Живые события';

  @override
  String get kbLiveEventsDescription =>
      'Менеджеры клубов создают события с несколькими столами. Присоединитесь к событию, чтобы участвовать в рейтингах в реальном времени.';

  @override
  String get kbLiveRankingsTitle => 'Живые рейтинги';

  @override
  String get kbLiveRankingsDescription =>
      'Следите за своим местом в рейтинге в реальном времени во время событий. Рейтинги обновляются после каждой раздачи.';

  @override
  String get kbOpponentTrackingTitle => 'Отслеживание соперников';

  @override
  String get kbOpponentTrackingDescription =>
      'Игроки, которых вы встречаете в клубе, отслеживаются автоматически. Сохраняйте соперников для создания подробных профилей.';

  @override
  String get kbQrSeatTitle => 'Назначение места по QR';

  @override
  String get kbQrSeatDescription =>
      'Отсканируйте QR-код за своим столом, чтобы мгновенно присоединиться к сессии. Ваши раздачи автоматически отслеживаются дилером.';

  @override
  String get kbDealerLoggingTitle => 'Запись с помощью дилера';

  @override
  String get kbDealerLoggingDescription =>
      'Дилеры используют голосовые команды для записи действий всего стола. Игрокам не нужно вводить данные вручную.';

  @override
  String get kbSessionStatsTitle => 'Статистика сессии';

  @override
  String get kbSessionStatsDescription =>
      'После каждой сессии смотрите свой выигрыш/проигрыш и как изменилась ваша статистика. Каждая раздача записывается.';

  @override
  String get qrJoinTableInfo => 'ИНФОРМАЦИЯ О СТОЛЕ';

  @override
  String qrJoinSeat(int number) {
    return 'Место $number';
  }

  @override
  String get qrJoinTableFallback => 'Стол';

  @override
  String get qrJoinClubLabel => 'Клуб';

  @override
  String get qrJoinTableLabel => 'Стол';

  @override
  String get qrJoinSeatLabel => 'Место';

  @override
  String get qrJoinStatusLabel => 'Статус';

  @override
  String get qrJoinActiveGame => 'Активная игра';

  @override
  String get qrJoinWaitingStatus => 'Ожидание';

  @override
  String dealerQrTablesAssigned(int count) {
    return '$count стол(ов) назначено для этого события';
  }

  @override
  String dealerQrTableNotAssigned(String tableName) {
    return '$tableName не назначен для этого события.';
  }

  @override
  String dealerTablePlayerAdded(String playerName, int seatNumber) {
    return '$playerName добавлен на Место $seatNumber';
  }

  @override
  String memberTableSeatedOpen(int seated, int open) {
    return '$seated занято  •  $open свободно';
  }

  @override
  String get memberTablePlayer => 'Игрок';

  @override
  String get memberTableEmpty => 'Пустой';

  @override
  String get memberTableFallback => 'Стол';

  @override
  String get homeEventTypeTournament => 'Турнир';

  @override
  String get homeEventTypeCashGame => 'Cash Game';

  @override
  String get homeEventTypeHomeGame => 'Домашняя игра';

  @override
  String get homeEventTypeOnline => 'Онлайн';

  @override
  String get bankrollSheetTitle => 'Добавить результат';

  @override
  String get bankrollSheetEditSection => 'Редактировать банкролл';

  @override
  String get bankrollSheetGoalLabel => 'Цель банкролла';

  @override
  String get bankrollSheetCurrentLabel => 'Текущий банкролл';

  @override
  String get bankrollSheetGoalUpdated => 'Цель обновлена';

  @override
  String get bankrollSheetBankrollUpdated => 'Банкролл обновлён';

  @override
  String get sessionEndResultTitle => 'Результат сессии';

  @override
  String get sessionEndTournamentTitle => 'Результат турнира';

  @override
  String get sessionEndProfit => 'Прибыль';

  @override
  String get sessionEndLoss => 'Убыток';

  @override
  String get sessionEndApply => 'Применить';

  @override
  String get sessionEndSkip => 'Пропустить';

  @override
  String get sessionEndFinishingPosition => 'Итоговая позиция';

  @override
  String get sessionEndFieldSize => 'Количество участников';

  @override
  String get sessionEndPrizeWon => 'Выигранный приз';

  @override
  String get sessionEndTotalInvested => 'Общая инвестиция';

  @override
  String sessionEndCalculatedProfit(String amount) {
    return 'Рассчитанная прибыль: $amount';
  }
}
