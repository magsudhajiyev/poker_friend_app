import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/widgets/poker_table_widget.dart';

/// Table surface smoke tests: after the neon redesign the oval is rendered
/// from PNG assets (table_neon / table_neon_clean) via Image.asset, NOT the
/// old Table.svg. These assert the correct asset is wired for each showLogo
/// state and that seat positioning math is untouched.
void main() {
  AssetImage surfaceImage(WidgetTester tester) {
    // The table surface is the only Image in the widget (dealer button is
    // off here). Grab its provider to assert the asset path.
    final image = tester.widget<Image>(find.byType(Image).first);
    return image.image as AssetImage;
  }

  testWidgets('renders neon logo asset when showLogo is true',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PokerTableWidget(
            activeSeatMap: const {1: true, 5: true},
            showDealerButton: false,
            // Custom seat builder bypasses the localized default-seat path
            // (needs AppLocalizations). The drill/hand screens use a builder
            // too — this mirrors real usage.
            seatBuilder: (seat, active) => const SizedBox(width: 24, height: 24),
          ),
        ),
      ),
    );
    expect(surfaceImage(tester).assetName, 'assets/icons/table_neon.png');
  });

  testWidgets('renders clean neon asset when showLogo is false',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PokerTableWidget(
            activeSeatMap: const {1: true, 5: true},
            showLogo: false,
            showDealerButton: false,
            seatBuilder: (seat, active) => const SizedBox(width: 24, height: 24),
          ),
        ),
      ),
    );
    expect(surfaceImage(tester).assetName, 'assets/icons/table_neon_clean.png');
  });

  test('seat positions remain area-fraction based (unchanged by asset swap)', () {
    // A 300x414 area at the table ratio; seat 5 is bottom-center of the oval.
    const area = Size(300, 414);
    final seat5 = PokerTableWidget.getSeatPosition(5, area);
    // Centered horizontally (within a small tolerance) and in the lower half.
    expect((seat5.dx - area.width / 2).abs(), lessThan(area.width * 0.1));
    expect(seat5.dy, greaterThan(area.height / 2));
  });

  testWidgets('dead button: chip renders on an EMPTY seat without crashing',
      (tester) async {
    // Seat 3 is empty (its player busted) but still holds the button.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PokerTableWidget(
            activeSeatMap: const {1: true, 2: true, 4: true, 5: true},
            buttonPosition: 3,
            seatBuilder: (seat, active) => const SizedBox(width: 24, height: 24),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
