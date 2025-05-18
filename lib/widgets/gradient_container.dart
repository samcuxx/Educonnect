import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../providers/theme_provider.dart';
import 'package:provider/provider.dart';

class GradientContainer extends StatefulWidget {
  final Widget child;
  final bool useSecondaryGradient;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool useCardStyle;

  const GradientContainer({
    Key? key,
    required this.child,
    this.useSecondaryGradient = false,
    this.borderRadius = 30.0,
    this.padding = const EdgeInsets.all(20.0),
    this.useCardStyle = true,
  }) : super(key: key);

  @override
  State<GradientContainer> createState() => _GradientContainerState();
}

class _GradientContainerState extends State<GradientContainer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuart,
      ),
    );
    
    // Start animation when widget is inserted into the tree
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    final gradient = widget.useSecondaryGradient
        ? AppTheme.secondaryGradient(isDark)
        : AppTheme.primaryGradient(isDark);
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: widget.useCardStyle
              ? _buildCardStyleContainer(isDark)
              : _buildGradientContainer(gradient, isDark),
        );
      },
    );
  }
  
  Widget _buildCardStyleContainer(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0.2,
          ),
        ],
        border: Border.all(
          color: widget.useSecondaryGradient
              ? (isDark ? AppTheme.darkSecondaryStart : AppTheme.lightSecondaryStart).withOpacity(0.20)
              : (isDark ? AppTheme.darkPrimaryStart : AppTheme.lightPrimaryStart).withOpacity(0.20),
          width: 1.0,
        ),
      ),
      padding: widget.padding,
      child: widget.child,
    );
  }
  
  Widget _buildGradientContainer(Gradient gradient, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0.1,
          ),
        ],
      ),
      padding: widget.padding,
      child: widget.child,
    );
  }
} 