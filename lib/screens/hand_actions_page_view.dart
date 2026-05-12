import 'package:flutter/material.dart';
import 'hand_actions_screen.dart';

/// A PageView wrapper around [HandActionsScreen] that lets the user swipe
/// horizontally between hands in a session.
class HandActionsPageView extends StatefulWidget {
  final List<Map<String, dynamic>> hands;
  final int initialIndex;
  final int? ourSeat;

  const HandActionsPageView({
    Key? key,
    required this.hands,
    this.initialIndex = 0,
    this.ourSeat,
  }) : super(key: key);

  @override
  State<HandActionsPageView> createState() => _HandActionsPageViewState();
}

class _HandActionsPageViewState extends State<HandActionsPageView> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.hands.length,
      onPageChanged: (index) {
        setState(() => _currentIndex = index);
      },
      itemBuilder: (context, index) {
        return HandActionsScreen(
          hand: widget.hands[index],
          ourSeat: widget.ourSeat,
        );
      },
    );
  }
}
