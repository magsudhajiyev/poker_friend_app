import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  final String? message;

  const LoadingScreen({Key? key, this.message}) : super(key: key);

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF02050B),
      child: Center(
        child: AnimatedBuilder(
          animation: _flipController,
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_flipController.value * 6.28318),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/logo_chat.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
