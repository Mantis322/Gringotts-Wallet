import 'package:flutter/material.dart';
import '../app/theme/colors.dart';

/// Premium Custom Button Component
/// Highly customizable button with gradient, glass effects and animations
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonType type;
  final CustomButtonSize size;
  final Widget? icon;
  final bool isLoading;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final BorderRadius? borderRadius;
  final List<Color>? gradientColors;
  final Color? textColor;
  final double? elevation;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CustomButtonType.primary,
    this.size = CustomButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.padding,
    this.width,
    this.borderRadius,
    this.gradientColors,
    this.textColor,
    this.elevation,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled && !widget.isLoading) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enabled && !widget.isLoading) {
      _animationController.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.enabled && !widget.isLoading) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonConfig = _getButtonConfig();
    final isDisabled = !widget.enabled || widget.isLoading;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: isDisabled ? null : widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.width ?? double.infinity,
              height: buttonConfig.height,
              padding: widget.padding ?? buttonConfig.padding,
              decoration: BoxDecoration(
                gradient: isDisabled 
                    ? LinearGradient(
                        colors: [
                          AppColors.textTertiary.withOpacity(0.3),
                          AppColors.textTertiary.withOpacity(0.2),
                        ],
                      )
                    : buttonConfig.gradient,
                borderRadius: widget.borderRadius ?? buttonConfig.borderRadius,
                border: buttonConfig.border,
                boxShadow: isDisabled 
                    ? null 
                    : [
                        BoxShadow(
                          color: buttonConfig.shadowColor,
                          blurRadius: widget.elevation ?? buttonConfig.elevation,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: _buildButtonContent(buttonConfig, isDisabled),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonContent(ButtonConfig config, bool isDisabled) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: config.loadingSize,
          height: config.loadingSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.textColor ?? config.textColor,
            ),
          ),
        ),
      );
    }

    final textStyle = config.textStyle.copyWith(
      color: isDisabled 
          ? AppColors.textTertiary 
          : (widget.textColor ?? config.textColor),
    );

    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
            data: IconThemeData(
              color: textStyle.color,
              size: config.iconSize,
            ),
            child: widget.icon!,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.text, 
              style: textStyle,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Center(
      child: Text(widget.text, style: textStyle),
    );
  }

  ButtonConfig _getButtonConfig() {
    switch (widget.type) {
      case CustomButtonType.primary:
        return ButtonConfig(
          height: widget.size.height,
          padding: widget.size.padding,
          gradient: widget.gradientColors != null
              ? LinearGradient(
                  colors: widget.gradientColors!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          textStyle: widget.size.textStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textColor: AppColors.textPrimary,
          shadowColor: AppColors.primaryPurple.withOpacity(0.3),
          elevation: 8,
          loadingSize: widget.size.loadingSize,
          iconSize: widget.size.iconSize,
        );

      case CustomButtonType.secondary:
        return ButtonConfig(
          height: widget.size.height,
          padding: widget.size.padding,
          gradient: const LinearGradient(
            colors: [AppColors.surfaceCard, AppColors.surfaceElevated],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderMedium),
          textStyle: widget.size.textStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textColor: AppColors.textPrimary,
          shadowColor: AppColors.shadowMedium,
          elevation: 4,
          loadingSize: widget.size.loadingSize,
          iconSize: widget.size.iconSize,
        );

      case CustomButtonType.outlined:
        return ButtonConfig(
          height: widget.size.height,
          padding: widget.size.padding,
          gradient: const LinearGradient(
            colors: [Colors.transparent, Colors.transparent],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryPurple, width: 1.5),
          textStyle: widget.size.textStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textColor: AppColors.primaryPurple,
          shadowColor: Colors.transparent,
          elevation: 0,
          loadingSize: widget.size.loadingSize,
          iconSize: widget.size.iconSize,
        );

      case CustomButtonType.ghost:
        return ButtonConfig(
          height: widget.size.height,
          padding: widget.size.padding,
          gradient: const LinearGradient(
            colors: [Colors.transparent, Colors.transparent],
          ),
          borderRadius: BorderRadius.circular(12),
          textStyle: widget.size.textStyle.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textColor: AppColors.primaryPurple,
          shadowColor: Colors.transparent,
          elevation: 0,
          loadingSize: widget.size.loadingSize,
          iconSize: widget.size.iconSize,
        );

      case CustomButtonType.glass:
        return ButtonConfig(
          height: widget.size.height,
          padding: widget.size.padding,
          gradient: LinearGradient(
            colors: [
              AppColors.glassLight,
              AppColors.glassLight.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          textStyle: widget.size.textStyle.copyWith(
            fontWeight: FontWeight.w500,
          ),
          textColor: AppColors.textPrimary,
          shadowColor: AppColors.shadowLight,
          elevation: 2,
          loadingSize: widget.size.loadingSize,
          iconSize: widget.size.iconSize,
        );
    }
  }
}

/// Button Configuration
class ButtonConfig {
  final double height;
  final EdgeInsetsGeometry padding;
  final LinearGradient gradient;
  final BorderRadius borderRadius;
  final Border? border;
  final TextStyle textStyle;
  final Color textColor;
  final Color shadowColor;
  final double elevation;
  final double loadingSize;
  final double iconSize;

  const ButtonConfig({
    required this.height,
    required this.padding,
    required this.gradient,
    required this.borderRadius,
    this.border,
    required this.textStyle,
    required this.textColor,
    required this.shadowColor,
    required this.elevation,
    required this.loadingSize,
    required this.iconSize,
  });
}

/// Button Types
enum CustomButtonType {
  primary,
  secondary,
  outlined,
  ghost,
  glass,
}

/// Button Sizes
enum CustomButtonSize {
  small(
    height: 40,
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    textStyle: TextStyle(fontSize: 14),
    loadingSize: 16,
    iconSize: 16,
  ),
  medium(
    height: 48,
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    textStyle: TextStyle(fontSize: 16),
    loadingSize: 20,
    iconSize: 18,
  ),
  large(
    height: 56,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    textStyle: TextStyle(fontSize: 16),
    loadingSize: 24,
    iconSize: 20,
  );

  const CustomButtonSize({
    required this.height,
    required this.padding,
    required this.textStyle,
    required this.loadingSize,
    required this.iconSize,
  });

  final double height;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final double loadingSize;
  final double iconSize;
}