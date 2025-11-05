import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme/colors.dart';
import '../app/routes.dart';
import '../app/constants.dart';

/// Splash Screen
/// Premium animated loading screen with Stellar branding
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));
  }

  void _startAnimationSequence() async {
    // Start logo animation
    await _logoController.forward();
    
    // Start text animation after logo
    await _textController.forward();
    
    // Wait for splash duration
    await Future.delayed(const Duration(milliseconds: 1000));
    
    // Navigate to onboarding
    if (mounted) {
      await AppRoutes.pushReplacement(context, AppRoutes.onboarding);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Stellar Logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScale.value,
                      child: Transform.rotate(
                        angle: _logoRotation.value * 0.5,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.textPrimary,
                            size: 60,
                          ),
                        ).animate(delay: 200.ms)
                            .shimmer(duration: 2000.ms, color: AppColors.accentGold.withOpacity(0.3))
                            .then()
                            .shake(hz: 2, curve: Curves.easeInOut),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Animated App Name
                AnimatedBuilder(
                  animation: _textController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textOpacity.value,
                      child: Column(
                        children: [
                          Text(
                            AppConstants.appName,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ).animate(delay: 600.ms)
                              .slideY(begin: 0.3, duration: 600.ms)
                              .fadeIn(duration: 600.ms),
                          
                          const SizedBox(height: 12),
                          
                          Text(
                            AppConstants.appDescription,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ).animate(delay: 800.ms)
                              .slideY(begin: 0.3, duration: 600.ms)
                              .fadeIn(duration: 600.ms),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 60),
                
                // Loading indicator
                Container(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryPurple.withOpacity(0.7),
                    ),
                  ),
                ).animate(delay: 1000.ms)
                    .fadeIn(duration: 600.ms)
                    .scale(begin: const Offset(0.8, 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}