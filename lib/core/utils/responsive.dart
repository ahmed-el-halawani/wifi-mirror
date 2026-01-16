import 'package:flutter/material.dart';

/// Breakpoints for responsive design
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double largeDesktop = 1800;
}

/// Screen size categories
enum ScreenSize { mobile, tablet, desktop, largeDesktop }

/// Extension on BuildContext for responsive utilities
extension ResponsiveExtension on BuildContext {
  /// Get the current screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Get the current screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Get the current screen size category
  ScreenSize get screenSize {
    final width = screenWidth;
    if (width < Breakpoints.mobile) return ScreenSize.mobile;
    if (width < Breakpoints.tablet) return ScreenSize.tablet;
    if (width < Breakpoints.desktop) return ScreenSize.desktop;
    return ScreenSize.largeDesktop;
  }

  /// Check if the screen is mobile
  bool get isMobile => screenWidth < Breakpoints.mobile;

  /// Check if the screen is tablet
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;

  /// Check if the screen is desktop
  bool get isDesktop =>
      screenWidth >= Breakpoints.tablet && screenWidth < Breakpoints.desktop;

  /// Check if the screen is large desktop
  bool get isLargeDesktop => screenWidth >= Breakpoints.desktop;

  /// Check if the screen is at least tablet size
  bool get isTabletOrLarger => screenWidth >= Breakpoints.mobile;

  /// Check if the screen is at least desktop size
  bool get isDesktopOrLarger => screenWidth >= Breakpoints.tablet;

  /// Get responsive padding based on screen size
  EdgeInsets get responsivePadding {
    if (isMobile) return const EdgeInsets.all(16);
    if (isTablet) return const EdgeInsets.all(24);
    if (isDesktop) return const EdgeInsets.all(32);
    return const EdgeInsets.symmetric(horizontal: 48, vertical: 32);
  }

  /// Get responsive horizontal padding for content centering
  double get responsiveHorizontalPadding {
    if (isMobile) return 16;
    if (isTablet) return 24;
    if (isDesktop) return 48;
    return 64;
  }

  /// Get max content width for large screens
  double get maxContentWidth {
    if (isMobile) return screenWidth;
    if (isTablet) return 600;
    if (isDesktop) return 800;
    return 1000;
  }

  /// Get the number of columns for grid layouts
  int get gridColumns {
    if (isMobile) return 1;
    if (isTablet) return 2;
    if (isDesktop) return 3;
    return 4;
  }
}

/// A widget that builds different layouts based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize size) builder;
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  /// Create a responsive builder with specific widgets for each breakpoint
  const ResponsiveBuilder.widgets({
    super.key,
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  }) : builder = _defaultBuilder;

  static Widget _defaultBuilder(BuildContext context, ScreenSize size) {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final size = context.screenSize;

    // If specific widgets are provided, use them
    if (mobile != null ||
        tablet != null ||
        desktop != null ||
        largeDesktop != null) {
      switch (size) {
        case ScreenSize.mobile:
          return mobile ??
              tablet ??
              desktop ??
              largeDesktop ??
              const SizedBox.shrink();
        case ScreenSize.tablet:
          return tablet ??
              desktop ??
              mobile ??
              largeDesktop ??
              const SizedBox.shrink();
        case ScreenSize.desktop:
          return desktop ??
              tablet ??
              largeDesktop ??
              mobile ??
              const SizedBox.shrink();
        case ScreenSize.largeDesktop:
          return largeDesktop ??
              desktop ??
              tablet ??
              mobile ??
              const SizedBox.shrink();
      }
    }

    return builder(context, size);
  }
}

/// A wrapper that centers content with a max width on large screens
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? context.maxContentWidth;
    final effectivePadding = padding ?? context.responsivePadding;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
  }
}

/// A responsive grid that adjusts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? columns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColumns = columns ?? context.gridColumns;

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (spacing * (effectiveColumns - 1))) /
            effectiveColumns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(width: itemWidth, child: child);
          }).toList(),
        );
      },
    );
  }
}

/// A two-column layout for desktop, single column for mobile
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;
  final double leftFlex;
  final double rightFlex;

  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 24,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isDesktopOrLarger) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex.toInt(), child: left),
          SizedBox(width: spacing),
          Expanded(flex: rightFlex.toInt(), child: right),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        left,
        SizedBox(height: spacing),
        right,
      ],
    );
  }
}
