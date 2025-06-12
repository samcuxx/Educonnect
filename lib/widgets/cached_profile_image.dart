import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';

class CachedProfileImage extends StatelessWidget {
  final String? imageUrl;
  final String fullName;
  final double radius;
  final bool isLecturer;
  final bool isDark;
  final EdgeInsets? gradientPadding;

  const CachedProfileImage({
    Key? key,
    required this.imageUrl,
    required this.fullName,
    required this.radius,
    required this.isLecturer,
    required this.isDark,
    this.gradientPadding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final padding = gradientPadding ?? const EdgeInsets.all(2);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient:
            isLecturer
                ? AppTheme.secondaryGradient(isDark)
                : AppTheme.primaryGradient(isDark),
        shape: BoxShape.circle,
      ),
      child: Container(
        margin: padding,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - padding.left),
          child:
              imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    width: (radius - padding.left) * 2,
                    height: (radius - padding.left) * 2,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color:
                              isDark
                                  ? AppTheme.darkSurface
                                  : AppTheme.lightSurface,
                          child: Center(
                            child: SizedBox(
                              width: radius * 0.4,
                              height: radius * 0.4,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isLecturer
                                      ? (isDark
                                          ? AppTheme.darkSecondaryStart
                                          : AppTheme.lightSecondaryStart)
                                      : (isDark
                                          ? AppTheme.darkPrimaryStart
                                          : AppTheme.lightPrimaryStart),
                                ),
                              ),
                            ),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => _buildFallbackAvatar(),
                    // Cache configuration for offline support
                    cacheKey: 'profile_${_generateCacheKey(imageUrl!)}',
                    memCacheWidth: ((radius - padding.left) * 2).round(),
                    memCacheHeight: ((radius - padding.left) * 2).round(),
                  )
                  : _buildFallbackAvatar(),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Center(
        child: Text(
          _getInitials(fullName),
          style: GoogleFonts.inter(
            color:
                isLecturer
                    ? (isDark
                        ? AppTheme.darkSecondaryStart
                        : AppTheme.lightSecondaryStart)
                    : (isDark
                        ? AppTheme.darkPrimaryStart
                        : AppTheme.lightPrimaryStart),
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final names = fullName.trim().split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }

  String _generateCacheKey(String url) {
    // Generate a simple cache key from the URL
    return url.hashCode.toString();
  }
}
