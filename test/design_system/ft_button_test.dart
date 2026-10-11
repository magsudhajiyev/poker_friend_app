import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/design_system/components/v3/ft_button.dart';
import 'package:poker_logger/design_system/tokens/ft_tokens.g.dart';

Widget _host(Widget child, {FtColors colors = FtColors.dark}) => MaterialApp(
      theme: ThemeData(extensions: [colors]),
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration _decoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
      find.descendant(of: find.byType(FtButton), matching: find.byType(AnimatedContainer)));
  return container.decoration! as BoxDecoration;
}

void main() {
  group('FtButton sizes match Figma', () {
    const heights = {
      FtButtonSize.small: 26.0,
      FtButtonSize.medium: 37.0,
      FtButtonSize.large: 50.0,
    };
    heights.forEach((size, height) {
      testWidgets('${size.name} draws $height pt', (tester) async {
        await tester.pumpWidget(_host(FtButton(
          label: 'Button',
          size: size,
          onPressed: () {},
        )));
        expect(
            tester
                .getSize(find.descendant(
                    of: find.byType(FtButton),
                    matching: find.byType(AnimatedContainer)))
                .height,
            closeTo(height, 0.01));
      });
    });

    testWidgets('small keeps a 44pt hit area', (tester) async {
      await tester.pumpWidget(_host(FtButton(
        label: 'Button',
        size: FtButtonSize.small,
        onPressed: () {},
      )));
      expect(tester.getSize(find.byType(FtButton)).height,
          greaterThanOrEqualTo(FtSize.hitTarget));
    });
  });

  group('FtButton colours come from component tokens', () {
    for (final entry in {'dark': FtColors.dark, 'light': FtColors.light}.entries) {
      final c = entry.value;
      testWidgets('${entry.key}: prominent uses button-primary tokens',
          (tester) async {
        await tester.pumpWidget(
            _host(FtButton(label: 'Save', onPressed: () {}), colors: c));
        expect(_decoration(tester).color, c.buttonPrimaryBg);
        final text = tester.widget<Text>(find.text('Save'));
        expect(text.style!.color, c.buttonPrimaryLabel);
      });

      testWidgets('${entry.key}: destructive prominent uses button-destructive',
          (tester) async {
        await tester.pumpWidget(_host(
            FtButton(label: 'Delete', destructive: true, onPressed: () {}),
            colors: c));
        expect(_decoration(tester).color, c.buttonDestructiveBg);
        expect(tester.widget<Text>(find.text('Delete')).style!.color,
            c.buttonDestructiveLabel);
      });
    }

    test('every variant × destructive × enabled resolves without gaps', () {
      for (final v in FtButtonVariant.values) {
        for (final d in [false, true]) {
          for (final e in [false, true]) {
            final r = FtButtonColors.resolve(FtColors.dark,
                variant: v, destructive: d, enabled: e);
            expect(r.label.a, greaterThan(0), reason: '$v d=$d e=$e');
          }
        }
      }
    });

    test('pressed prominent swaps to the pressed background', () {
      final r = FtButtonColors.resolve(FtColors.dark,
          variant: FtButtonVariant.prominent,
          destructive: false,
          enabled: true,
          pressed: true);
      expect(r.background, FtColors.dark.buttonPrimaryBgPressed);
    });
  });

  group('FtButton behaviour', () {
    testWidgets('tap calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(FtButton(label: 'Go', onPressed: () => taps++)));
      await tester.tap(find.byType(FtButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('disabled uses disabled tokens and ignores taps',
        (tester) async {
      await tester.pumpWidget(_host(const FtButton(label: 'Go', onPressed: null)));
      await tester.tap(find.byType(FtButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_decoration(tester).color, FtColors.dark.buttonDisabledBg);
      expect(tester.widget<Text>(find.text('Go')).style!.color,
          FtColors.dark.buttonDisabledLabel);
    });

    testWidgets('icon picks up token colour and size', (tester) async {
      await tester.pumpWidget(_host(FtButton(
        label: 'Add',
        size: FtButtonSize.medium,
        variant: FtButtonVariant.bordered,
        icon: const Icon(Icons.add),
        onPressed: () {},
      )));
      final theme = IconTheme.of(tester.element(find.byIcon(Icons.add)));
      expect(theme.color, FtColors.dark.buttonBorderedIcon);
      expect(theme.size, FtSize.iconSm);
    });

    testWidgets('exposes button semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(FtButton(label: 'Save', onPressed: () {})));
      expect(
        tester.getSemantics(find.byType(FtButton)),
        containsSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
