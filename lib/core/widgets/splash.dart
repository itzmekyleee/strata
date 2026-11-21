import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/strata_palette.dart';
import '../../app/theme/strata_theme.dart';

/// Full-screen branded splash shown while the app finishes booting.
class Splash extends StatelessWidget {
  const Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: StrataTheme.build(Brightness.light),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Logo(),
              SizedBox(height: 20),
              _AppName(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [StrataPalette.accent, StrataPalette.amber],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: StrataPalette.accent.withValues(alpha: .3),
            blurRadius: 30,
            spreadRadius: 6,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'S',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
    ).animate().scale(
          duration: 600.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _AppName extends StatelessWidget {
  const _AppName();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Strata',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: StrataPalette.onBackground,
          ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }
}
