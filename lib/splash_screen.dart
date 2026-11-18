
import 'dart:async';

import 'package:flutter/material.dart';


class InkoraSplashScreen extends StatefulWidget {
  const InkoraSplashScreen({
    super.key,
    required this.nextScreen,
  });

  final Widget nextScreen;

  @override
  State<InkoraSplashScreen> createState() =>
      _InkoraSplashScreenState();
}

class _InkoraSplashScreenState extends State<InkoraSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  Timer? _navigationTimer;

  static const List<String> _messages = [
    'Preparing your workspace...',
    'Loading app components...',
    'Organizing your tools...',
    'Almost ready...',
  ];

  int _messageIndex = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.addListener(_updateMessage);
    _controller.forward();

    _navigationTimer = Timer(
      const Duration(milliseconds: 4500),
      _openNextScreen,
    );
  }

  void _updateMessage() {
    final progress = _controller.value;

    final newIndex = progress < 0.25
        ? 0
        : progress < 0.50
        ? 1
        : progress < 0.80
        ? 2
        : 3;

    if (newIndex != _messageIndex && mounted) {
      setState(() => _messageIndex = newIndex);
    }
  }

  void _openNextScreen() {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, secondaryAnimation) =>
        widget.nextScreen,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.removeListener(_updateMessage);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    final track = theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.88, end: 1),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          width: 142,
                          height: 142,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stackTrace) => Icon(
                            Icons.auto_awesome_rounded,
                            size: 76,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        'Inkora AI',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Write. Understand. Improve.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: muted,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(flex: 2),
                      AnimatedBuilder(
                        animation: _progress,
                        builder: (context, child) {
                          final percentage = (_progress.value * 100).round();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: LinearProgressIndicator(
                                  value: _progress.value,
                                  minHeight: 5,
                                  backgroundColor: track,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      child: Text(
                                        _messages[_messageIndex],
                                        key: ValueKey(_messageIndex),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$percentage%',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const Spacer(),
                      Text(
                        'Your handwritten notes. Smarter evaluation.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
