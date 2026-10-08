import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/tokens/ft_tokens.g.dart';

/// WCAG 2.2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final themes = {'dark': FtColors.dark, 'light': FtColors.light};

  List<Color> surfaces(FtColors c) => [
        c.bgPrimary,
        c.bgSecondary,
        c.bgTertiary,
        c.bgElevated,
        c.bgElevatedHigh,
      ];

  group('FtColors contrast (WCAG 2.2 AA)', () {
    themes.forEach((name, c) {
      test('$name: text tokens reach 4.5:1 on every surface', () {
        final text = {
          'labelPrimary': c.labelPrimary,
          'labelSecondary': c.labelSecondary,
          'labelTertiary': c.labelTertiary,
          'textAccent': c.textAccent,
          'textLink': c.textLink,
          'textSuccess': c.textSuccess,
          'textDanger': c.textDanger,
          'textfieldPlaceholder': c.textfieldPlaceholder,
        };
        for (final s in surfaces(c)) {
          text.forEach((token, color) {
            expect(contrast(color, s), greaterThanOrEqualTo(4.5),
                reason: '$name $token on $s');
          });
        }
      });

      test('$name: icons, borders and focus ring reach 3:1 on every surface', () {
        final nonText = {
          'iconPrimary': c.iconPrimary,
          'iconSecondary': c.iconSecondary,
          'iconAccent': c.iconAccent,
          'focusRing': c.focusRing,
          'textfieldBorder': c.textfieldBorder,
          'textfieldBorderError': c.textfieldBorderError,
        };
        for (final s in surfaces(c)) {
          nonText.forEach((token, color) {
            expect(contrast(color, s), greaterThanOrEqualTo(3.0),
                reason: '$name $token on $s');
          });
        }
      });

      test('$name: labels on filled buttons reach 4.5:1', () {
        expect(contrast(c.buttonPrimaryLabel, c.buttonPrimaryBg),
            greaterThanOrEqualTo(4.5));
        expect(contrast(c.buttonDestructiveLabel, c.buttonDestructiveBg),
            greaterThanOrEqualTo(4.5));
      });
    });
  });

  group('FtColors theme extension', () {
    test('lerp hits both ends', () {
      expect(FtColors.dark.lerp(FtColors.light, 0).bgPrimary,
          FtColors.dark.bgPrimary);
      expect(FtColors.dark.lerp(FtColors.light, 1).bgPrimary,
          FtColors.light.bgPrimary);
    });

    test('copyWith overrides one token only', () {
      final c = FtColors.dark.copyWith(focusRing: const Color(0xFF123456));
      expect(c.focusRing, const Color(0xFF123456));
      expect(c.labelPrimary, FtColors.dark.labelPrimary);
    });

    testWidgets('of(context) reads the theme and falls back to dark',
        (tester) async {
      late FtColors fromTheme;
      late FtColors fallback;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
        Theme(
          data: ThemeData(extensions: const [FtColors.light]),
          child: Builder(builder: (ctx) {
            fromTheme = ctx.ftColors;
            return const SizedBox();
          }),
        ),
        Builder(builder: (ctx) {
          fallback = FtColors.of(ctx);
          return const SizedBox();
        }),
      ])));
      expect(fromTheme.bgPrimary, FtColors.light.bgPrimary);
      expect(fallback.bgPrimary, FtColors.dark.bgPrimary);
    });
  });

  group('FtTextStyles', () {
    test('every style uses 42dot Sans', () {
      for (final s in [
        FtTextStyles.display,
        FtTextStyles.largeTitle,
        FtTextStyles.body,
        FtTextStyles.footnote,
        FtTextStyles.caption3,
      ]) {
        expect(s.fontFamily, '42dot Sans');
      }
    });

    test('tabular adds tabular figures', () {
      expect(FtTextStyles.body.tabular.fontFeatures,
          contains(const FontFeature.tabularFigures()));
    });
  });

  test('hit target is the 44pt iOS minimum', () {
    expect(FtSize.hitTarget, 44);
  });
}
