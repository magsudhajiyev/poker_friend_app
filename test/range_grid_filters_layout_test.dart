// Regression test: range grid filter bars (Wrap + scale-down groups) must
// lay out without overflow at narrow widths with long (Romanian) labels.
// Mirrors the structure of RangeGridView._buildFilters.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font (Ahem) renders every glyph as fontSize px wide — roughly 2x
// a real proportional font. fontSize 7 here matches the on-screen width of
// the app's 12px IBM Plex labels.
Widget seg(String label) => AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Text(label, style: const TextStyle(fontSize: 7)),
    );

Widget pillRow(List<String> labels, {MainAxisSize size = MainAxisSize.min}) =>
    Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: size,
        children: [for (final l in labels) seg(l)],
      ),
    );

// Mirrors _buildPositionBar: full-width bar with Expanded segments (needs
// bounded width — this is what a FittedBox/horizontal-scroll wrapper broke).
Widget positionBar() => Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF101115),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final p in ['Toate', 'EP', 'MP', 'CO', 'BTN', 'SB', 'BB'])
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(p, style: const TextStyle(fontSize: 7)),
                ),
              ),
            ),
        ],
      ),
    );

Widget filters() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                pillRow(['Cash', 'Turneu']),
                pillRow(['Toate stack-urile']),
              ],
            ),
          ),
          const SizedBox(height: 8),
          positionBar(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                pillRow(['Toate spoturile', 'RFI', 'vs Raise']),
                pillRow(['R', 'C', 'X', 'F']),
              ],
            ),
          ),
        ],
      ),
    );

Widget page() => RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            filters(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 13,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = 0; i < 169; i++)
                    Container(color: Colors.white12),
                ],
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('filters layout at 368px width does not throw', (tester) async {
    await tester.binding.setSurfaceSize(const Size(368, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageView(children: [page(), const SizedBox()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters layout at 320px width does not throw', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageView(children: [page(), const SizedBox()]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
