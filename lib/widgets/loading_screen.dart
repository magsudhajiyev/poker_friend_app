import 'package:flutter/material.dart';
import '../design_system/constants/colors.dart';

class LoadingScreen extends StatelessWidget {
  final String? message;

  const LoadingScreen({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.paper,
    );
  }
}
