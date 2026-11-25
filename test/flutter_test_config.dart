import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Runs before every test file. The google_fonts files are bundled as assets
/// (assets/google_fonts/), so google_fonts loads them from the bundle. A font
/// that finishes loading inside a widget test sends a "system fonts changed"
/// message, which schedules a frame after the tree is disposed and fails the
/// test. Load every bundled family and weight once here, before any test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const weights = [
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ];
  for (final w in weights) {
    GoogleFonts.ibmPlexSans(fontWeight: w);
    GoogleFonts.ibmPlexMono(fontWeight: w);
    GoogleFonts.robotoMono(fontWeight: w);
    GoogleFonts.familjenGrotesk(fontWeight: w);
    GoogleFonts.inter(fontWeight: w);
  }
  try {
    await GoogleFonts.pendingFonts();
  } catch (_) {
    // A missing weight must not stop the suite; bundled_fonts_test checks
    // the files that AppTypography needs.
  }
  // Let the font-change platform messages drain before the first test.
  await Future<void>.delayed(Duration.zero);

  await testMain();
}
