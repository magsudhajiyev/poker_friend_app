import 'package:flutter/material.dart';

import '../design_system/components/v3/v3.dart';
import '../design_system/tokens/ft_tokens.g.dart';

/// Dev-only gallery of the Final Table v3 components (Profile › dev tools ›
/// "Design v3"). Shows every state against the Figma `finaltable_v3` file,
/// in Dark and Light. Copy is placeholder text, so it is not localised.
class DesignV3GalleryScreen extends StatefulWidget {
  const DesignV3GalleryScreen({super.key});

  @override
  State<DesignV3GalleryScreen> createState() => _DesignV3GalleryScreenState();
}

class _DesignV3GalleryScreenState extends State<DesignV3GalleryScreen> {
  bool _light = false;

  @override
  Widget build(BuildContext context) {
    final colors = _light ? FtColors.light : FtColors.dark;
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        brightness: _light ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: colors.bgPrimary,
        extensions: [colors],
      ),
      child: Builder(builder: (context) {
        final c = context.ftColors;
        return Scaffold(
          backgroundColor: c.bgPrimary,
          appBar: AppBar(
            backgroundColor: c.bgPrimary,
            foregroundColor: c.labelPrimary,
            elevation: 0,
            title: Text('Design v3',
                style: FtTextStyles.headline.copyWith(color: c.labelPrimary)),
            actions: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_light ? 'Light' : 'Dark',
                    style: FtTextStyles.footnote
                        .copyWith(color: c.labelSecondary)),
                Switch(
                  value: _light,
                  activeTrackColor: c.toggleTrackOn,
                  onChanged: (v) => setState(() => _light = v),
                ),
              ]),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(FtSpacing.s16),
              children: [
                _section(c, 'Button'),
                for (final size in FtButtonSize.values) ...[
                  _caption(c, size.name),
                  _buttonRow(size, destructive: false, enabled: true),
                  _buttonRow(size, destructive: true, enabled: true),
                  _buttonRow(size, destructive: false, enabled: false),
                  const SizedBox(height: FtSpacing.s16),
                ],
                _caption(c, 'full width'),
                FtButton(
                  label: 'Log a session',
                  icon: const Icon(Icons.add),
                  fullWidth: true,
                  onPressed: () {},
                ),
                const SizedBox(height: FtSpacing.s8),
                FtButton(
                  label: 'Cancel',
                  variant: FtButtonVariant.bordered,
                  fullWidth: true,
                  onPressed: () {},
                ),
                const SizedBox(height: FtSpacing.s40),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buttonRow(FtButtonSize size,
      {required bool destructive, required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FtSpacing.s8),
      child: Wrap(
        spacing: FtSpacing.s8,
        runSpacing: FtSpacing.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final v in FtButtonVariant.values)
            FtButton(
              label: destructive ? 'Delete' : 'Button',
              variant: v,
              size: size,
              destructive: destructive,
              icon: const Icon(Icons.add),
              onPressed: enabled ? () {} : null,
            ),
        ],
      ),
    );
  }

  Widget _section(FtColors c, String title) => Padding(
        padding: const EdgeInsets.only(bottom: FtSpacing.s8),
        child: Text(title,
            style: FtTextStyles.title2Emphasized
                .copyWith(color: c.labelPrimary)),
      );

  Widget _caption(FtColors c, String text) => Padding(
        padding: const EdgeInsets.only(
            top: FtSpacing.s8, bottom: FtSpacing.s8),
        child: Text(text,
            style: FtTextStyles.footnote.copyWith(color: c.labelTertiary)),
      );
}
