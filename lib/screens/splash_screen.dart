import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Heart pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Particle rotation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Navigate after delay
    Future.delayed(const Duration(seconds: 3), _navigateToAuth);
  }

  Future<void> _navigateToAuth() async {
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Particles
          ...List.generate(10, (index) {
            return _buildParticle(index, theme.colorScheme.primary);
          }),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric Circles
                    _buildCircle(
                      200,
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ),
                    _buildCircle(
                      160,
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    _buildCircle(
                      120,
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),

                    // Pulsing Heart
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.shield_rounded,
                          size: 50,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // App Name
                Text(
                  'SafeGuardian',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Tagline
                Text(
                  'Stay Safe, Stay Strong',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Loading Indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildParticle(int index, Color color) {
    final random = math.Random(index);
    final size = 10.0 + random.nextDouble() * 20.0;
    final radius = 100.0 + random.nextDouble() * 150.0;
    final startAngle = random.nextDouble() * 2 * math.pi;

    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final angle = startAngle + _particleController.value * 2 * math.pi;
        final x = math.cos(angle) * radius;
        final y = math.sin(angle) * radius;

        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + x - size / 2,
          top: MediaQuery.of(context).size.height / 2 + y - size / 2,
          child: Opacity(
            opacity:
                0.3 +
                math.sin(_particleController.value * 2 * math.pi + index) * 0.2,
            child: Icon(
              Icons.favorite,
              size: size,
              color: color.withValues(alpha: 0.4),
            ),
          ),
        );
      },
    );
  }
}
