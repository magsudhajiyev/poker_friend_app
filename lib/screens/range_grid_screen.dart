import 'package:flutter/material.dart';

import '../design_system/components/headers/top_nav_bar.dart';
import '../design_system/constants/colors.dart';
import '../widgets/range_grid/range_grid_view.dart';

/// Standalone, pushable host for the Range Grid (the grid itself normally
/// lives as a tab inside the Statistics screen). Used by deep links that
/// want the grid pre-filtered on a spot — e.g. "See the hands behind it"
/// on a Leak Detector finding.
class RangeGridScreen extends StatelessWidget {
  final String? initialPosGroup;
  final String? initialScenario;
  final String? initialStackBucket;
  final String initialGameType;

  const RangeGridScreen({
    super.key,
    this.initialPosGroup,
    this.initialScenario,
    this.initialStackBucket,
    this.initialGameType = 'cash',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            TopNavBar(
              title: 'Range Grid',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: RangeGridView(
                initialPosGroup: initialPosGroup,
                initialScenario: initialScenario,
                initialStackBucket: initialStackBucket,
                initialGameType: initialGameType,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
