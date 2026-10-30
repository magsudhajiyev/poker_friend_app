import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('remote flags replace defaults and bump revision', () async {
    expect(FeatureFlagService.modeOf(FeatureFlagService.hardPaywall),
        FlagMode.off);
    final before = FeatureFlagService.revision.value;
    await FeatureFlagService.applyRemote({'hard_paywall': 'on'});
    expect(FeatureFlagService.modeOf(FeatureFlagService.hardPaywall),
        FlagMode.on);
    expect(FeatureFlagService.revision.value, before + 1);
  });
}
