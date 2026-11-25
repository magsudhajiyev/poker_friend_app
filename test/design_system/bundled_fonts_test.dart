import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('google_fonts files used by AppTypography are bundled as assets', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    final required = <String>[
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) ...[
        'IBMPlexSans-$w',
        'RobotoMono-$w',
        'FamiljenGrotesk-$w',
      ],
    ];
    for (final name in required) {
      expect(assets.contains('assets/google_fonts/$name.ttf'), isTrue,
          reason: '$name.ttf missing from asset manifest');
    }
  });
}
