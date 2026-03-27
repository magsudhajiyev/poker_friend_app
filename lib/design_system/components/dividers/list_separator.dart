import 'package:flutter/material.dart';
import '../../constants/colors.dart';

/// Horizontal separator line for lists
/// Matches Figma design (node I393:6764;20:550;20:533)
class ListSeparator extends StatelessWidget {
  final double horizontalPadding;

  const ListSeparator({
    Key? key,
    this.horizontalPadding = 4.0, // Figma: px-4 inside Table-list container
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        height: 1,
        color: AppColors.separatorDark, // #1C1F21
      ),
    );
  }
}
