import 'package:flutter/material.dart';

import '../app/tokens.dart';
import 'brand_mark.dart';

/// One top-level destination of the app.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// The four app destinations, in navigation order.
const List<ShellDestination> kShellDestinations = [
  ShellDestination(
    label: 'Overview',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  ShellDestination(
    label: 'Temperature',
    icon: Icons.thermostat_outlined,
    selectedIcon: Icons.thermostat,
  ),
  ShellDestination(
    label: 'Precipitation',
    icon: Icons.water_drop_outlined,
    selectedIcon: Icons.water_drop,
  ),
  ShellDestination(
    label: 'Methodology',
    icon: Icons.science_outlined,
    selectedIcon: Icons.science,
  ),
];

/// Layout class derived from the available width.
enum ShellSize { compact, medium, expanded }

ShellSize shellSizeFor(double width) {
  if (width >= AppBreakpoints.expanded) return ShellSize.expanded;
  if (width >= AppBreakpoints.medium) return ShellSize.medium;
  return ShellSize.compact;
}

/// Observatory application shell: brand, navigation and a scrolling content
/// area. Owns layout only; the selected index and its changes are controlled
/// by the caller.
///
/// - compact  (< 600):   brand header on top, bottom [NavigationBar].
/// - medium   (600–999): slim [NavigationRail] with the brand mark.
/// - expanded (≥ 1000):  extended [NavigationRail] with mark + wordmark.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Page content (placed in a scroll view with responsive padding).
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Reparent content across the phone/rail transition without recreating forms.
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = shellSizeFor(constraints.maxWidth);
        return size == ShellSize.compact
            ? _compact(context)
            : _railLayout(context, size);
      },
    );
  }

  // ── Compact (phone) ───────────────────────────────────────────────────────

  Widget _compact(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _CompactHeader(),
            Expanded(child: _content(ShellSize.compact)),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: AppBorders.subtle)),
        child: NavigationBar(
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: widget.onDestinationSelected,
          destinations: [
            for (final d in kShellDestinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }

  // ── Medium / expanded (tablet, desktop) ───────────────────────────────────

  Widget _railLayout(BuildContext context, ShellSize size) {
    final extended = size == ShellSize.expanded;
    return Scaffold(
      body: Row(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: AppBorders.subtle),
            ),
            child: NavigationRail(
              scrollable: true,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: widget.onDestinationSelected,
              extended: extended,
              minExtendedWidth: 232,
              minWidth: 84,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              groupAlignment: -1,
              leading: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.xl,
                ),
                child: extended
                    ? const _RailBrand()
                    : const BrandMark(size: 36),
              ),
              destinations: [
                for (final d in kShellDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                  ),
              ],
            ),
          ),
          Expanded(child: _content(size)),
        ],
      ),
    );
  }

  // ── Content area ──────────────────────────────────────────────────────────

  Widget _content(ShellSize size) {
    final pad = switch (size) {
      ShellSize.compact => AppSpacing.lg,
      ShellSize.medium => AppSpacing.xl,
      ShellSize.expanded => AppSpacing.xxl,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + AppSpacing.sm),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.contentMaxWidth,
          ),
          // Fill the available width, capped at the content max width.
          child: SizedBox(
            width: double.infinity,
            child: KeyedSubtree(key: _contentKey, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Phone top bar: brand mark + wordmark on a bordered surface strip.
class _CompactHeader extends StatelessWidget {
  const _CompactHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: AppBorders.subtle),
      ),
      child: Row(
        children: [
          const BrandMark(size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Stone to Stars',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(letterSpacing: -0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop rail header: brand mark, wordmark and tagline.
class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        width: 200,
        child: Row(
          children: [
            const BrandMark(size: 40),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Stone to Stars',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.subtitle.copyWith(letterSpacing: -0.1),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'CLIMATE TRENDS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.overline.copyWith(color: AppColors.cyan),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
