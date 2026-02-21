import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================================
// CUSTOM CARD
// ============================================================================
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final GestureTapCallback? onTap;
  final bool elevated;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.onTap,
    this.elevated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: AppTheme.dividerColor, width: 1),
        boxShadow: boxShadow ?? (elevated ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ] : []),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: card,
        ),
      );
    }

    return card;
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final EdgeInsets padding;

  const SectionTitle({
    Key? key,
    required this.title,
    this.subtitle,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppTheme.primaryGreen),
                const SizedBox(width: 10),
              ],
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// PRIMARY BUTTON (Elevated)
// ============================================================================
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;

  const PrimaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  backgroundColor ?? AppTheme.primaryGreen,
                ),
              ),
            )
          : Icon(icon ?? Icons.check),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppTheme.primaryGreen,
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

// ============================================================================
// SECONDARY BUTTON (Outlined)
// ============================================================================
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isFullWidth;

  const SecondaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isFullWidth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.info_outline),
      label: Text(label),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

// ============================================================================
// GRADIENT HERO SECTION
// ============================================================================
class GradientHeroSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onActionPressed;
  final String actionLabel;

  const GradientHeroSection({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onActionPressed,
    this.actionLabel = 'Start Assessment',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: AppTheme.primaryGreen,
      border: null,
      boxShadow: [
        BoxShadow(
          color: AppTheme.primaryGreen.withOpacity(0.3),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.lightGreen,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(16),
            child: Icon(
              icon,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STATUS CHIP
// ============================================================================
class StatusChip extends StatelessWidget {
  final String label;
  final bool isSuccess;
  final IconData? icon;

  const StatusChip({
    Key? key,
    required this.label,
    this.isSuccess = true,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppTheme.lowRiskGreen : AppTheme.highRiskRed;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? (isSuccess ? Icons.check_circle_outline : Icons.error_outline),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RISK CARD
// ============================================================================
class RiskCard extends StatefulWidget {
  final String riskLevel;
  final double confidence;
  final String explanation;

  const RiskCard({
    Key? key,
    required this.riskLevel,
    required this.confidence,
    required this.explanation,
  }) : super(key: key);

  @override
  State<RiskCard> createState() => _RiskCardState();
}

class _RiskCardState extends State<RiskCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getRiskColor() {
    switch (widget.riskLevel.toLowerCase()) {
      case 'high':
        return AppTheme.highRiskRed;
      case 'medium':
        return AppTheme.mediumRiskOrange;
      default:
        return AppTheme.lowRiskGreen;
    }
  }

  IconData _getRiskIcon() {
    switch (widget.riskLevel.toLowerCase()) {
      case 'high':
        return Icons.warning_amber_rounded;
      case 'medium':
        return Icons.report_problem_rounded;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRiskColor();
    final icon = _getRiskIcon();

    return ScaleTransition(
      scale: _scaleAnimation,
      child: CustomCard(
        backgroundColor: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(60),
              ),
              padding: const EdgeInsets.all(16),
              child: Icon(icon, size: 56, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              widget.riskLevel.toUpperCase(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Confidence: ${(widget.confidence * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: widget.confidence,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.explanation,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FEATURE IMPORTANCE BAR
// ============================================================================
class FeatureImportanceBar extends StatelessWidget {
  final String featureName;
  final double importance;
  final IconData icon;

  const FeatureImportanceBar({
    Key? key,
    required this.featureName,
    required this.importance,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                featureName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${(importance * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: importance,
            minHeight: 12,
            backgroundColor: AppTheme.dividerColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PROBABILITY CARD
// ============================================================================
class ProbabilityCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const ProbabilityCard({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CustomCard(
        backgroundColor: color.withOpacity(0.08),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INFO SECTION
// ============================================================================
class InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const InfoSection({
    Key? key,
    required this.icon,
    required this.title,
    required this.content,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: backgroundColor,
      border: borderColor != null ? Border.all(color: borderColor!, width: 1) : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryGreen).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              color: iconColor ?? AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(content, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOADING OVERLAY
// ============================================================================
class LoadingOverlay extends StatelessWidget {
  final String message;
  final bool isVisible;

  const LoadingOverlay({
    Key? key,
    this.message = 'Loading...',
    this.isVisible = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
