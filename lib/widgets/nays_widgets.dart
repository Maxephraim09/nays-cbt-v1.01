import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 42, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .25),
    child: Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(size * .04),
      child: Image.asset('assets/images/nays_logo.webp', fit: BoxFit.contain),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 19),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.forest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    super.key,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: TextStyle(
          color: AppTheme.brand(context),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 7),
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      if (subtitle != null) ...[
        const SizedBox(height: 7),
        Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ],
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {this.action, this.onAction, super.key});
  final String label;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.color,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .12),
      ),
    ),
    child: child,
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.value,
    required this.label,
    required this.icon,
    super.key,
  });
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.brand(context), size: 20),
        const SizedBox(height: 13),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
        ),
      ],
    ),
  );
}

void showDemoMessage(BuildContext context, String title, String detail) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
