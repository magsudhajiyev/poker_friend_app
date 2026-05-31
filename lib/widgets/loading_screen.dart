import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  final String? message;

  const LoadingScreen({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF02050B),
    );
  }
}
