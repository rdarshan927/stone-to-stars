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

/// Earth Observatory shell. Selection remains owned by the caller; the keyed
/// content subtree preserves form drafts and details across navigation layouts.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = shellSizeFor(constraints.maxWidth);
      return Scaffold(
        backgroundColor: AppColors.background,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.space),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.atmosphere),
            child: SafeArea(
              bottom: size != ShellSize.compact,
              child: switch (size) {
                ShellSize.compact =>
                  constraints.maxHeight < 500
                      ? _content(size, header: const _BrandHeader())
                      : Column(
                          children: [
                            const _BrandHeader(),
                            Expanded(child: _content(size)),
                          ],
                        ),
                ShellSize.medium => _tablet(size, constraints.maxHeight),
                ShellSize.expanded => Column(
                  children: [
                    _DesktopHeader(
                      selectedIndex: widget.selectedIndex,
                      onSelected: widget.onDestinationSelected,
                    ),
                    Expanded(child: _content(size)),
                  ],
                ),
              },
            ),
          ),
        ),
        bottomNavigationBar: size == ShellSize.compact
            ? _bottomNavigation(context)
            : null,
      );
    },
  );

  Widget _bottomNavigation(BuildContext context) {
    final labelWidth =
        MediaQuery.sizeOf(context).width / 4 -
        AppSpacing.sm -
        AppSpacing.xxs * 2 -
        AppBorders.width * 2;
    var height = 80.0;
    for (final destination in kShellDestinations) {
      final painter = TextPainter(
        text: TextSpan(
          text: destination.label,
          style: AppText.label.copyWith(fontSize: 11, letterSpacing: 0),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: labelWidth);
      final needed =
          painter.height +
          22 +
          AppSpacing.xs +
          AppSpacing.sm * 2 +
          AppBorders.width * 2;
      if (needed > height) height = needed;
      painter.dispose();
    }
    return DecoratedBox(
      decoration: const BoxDecoration(border: Border(top: AppBorders.subtle)),
      child: NavigationBar(
        backgroundColor: AppColors.navigation,
        indicatorColor: Colors.transparent,
        height: height,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onDestinationSelected,
        destinations: [
          for (var i = 0; i < kShellDestinations.length; i++)
            NavigationDestination(
              // Visual labels live in the icon slot so they can wrap. The
              // same complete name is exposed by _BottomLabel semantics.
              label: '',
              tooltip: kShellDestinations[i].label,
              icon: _BottomLabel(
                destination: kShellDestinations[i],
                selected: false,
              ),
              selectedIcon: _BottomLabel(
                destination: kShellDestinations[i],
                selected: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tablet(ShellSize size, double height) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final showLabels = scale <= 1.3 && height >= 500;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.navigation,
            border: Border(right: AppBorders.subtle),
          ),
          child: NavigationRail(
            scrollable: true,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            backgroundColor: Colors.transparent,
            minWidth: 84,
            labelType: showLabels
                ? NavigationRailLabelType.all
                : NavigationRailLabelType.none,
            groupAlignment: -1,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: BrandMark(size: 36),
            ),
            destinations: [
              for (final d in kShellDestinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                ),
            ],
          ),
        ),
        Expanded(child: _content(size)),
      ],
    );
  }

  Widget _content(ShellSize size, {Widget? header}) {
    final pad = switch (size) {
      ShellSize.compact => AppSpacing.lg,
      ShellSize.medium => AppSpacing.xl,
      ShellSize.expanded => AppSpacing.xxl,
    };
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            header,
            const SizedBox(height: AppSpacing.lg),
          ],
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.contentMaxWidth,
              ),
              child: SizedBox(
                width: double.infinity,
                child: KeyedSubtree(key: _contentKey, child: widget.child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: const BoxDecoration(
      color: AppColors.navigation,
      border: Border(bottom: AppBorders.subtle),
    ),
    child: const _Brand(compact: true),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      BrandMark(size: compact ? 32 : 44),
      const SizedBox(width: AppSpacing.md),
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Stone to Stars',
                style: (compact ? AppText.title : AppText.sectionTitle)
                    .copyWith(letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'CLIMATE EXPLORER',
              style: AppText.overline.copyWith(
                color: AppColors.cyan,
                fontSize: compact ? 9 : 10,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BottomLabel extends StatelessWidget {
  const _BottomLabel({required this.destination, required this.selected});
  final ShellDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    label: destination.label,
    excludeSemantics: true,
    child: Container(
      width: MediaQuery.sizeOf(context).width / 4 - AppSpacing.sm,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.cyan.withAlpha(24) : Colors.transparent,
        borderRadius: AppRadii.mdAll,
        border: Border.all(
          color: selected ? AppColors.cyan.withAlpha(95) : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? destination.selectedIcon : destination.icon,
            size: 22,
            color: selected ? AppColors.cyan : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            destination.label,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(
              fontSize: 11,
              letterSpacing: 0,
              color: selected ? AppColors.cyan : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xxl,
      vertical: AppSpacing.lg,
    ),
    decoration: const BoxDecoration(
      color: AppColors.navigation,
      border: Border(bottom: AppBorders.subtle),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.contentMaxWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double measure(String text, TextStyle style) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width;
            }

            final navigationWidth =
                kShellDestinations.fold<double>(
                  0,
                  (sum, d) =>
                      sum +
                      measure(d.label, AppText.body) +
                      24 +
                      AppSpacing.sm +
                      AppSpacing.xl * 2,
                ) +
                AppSpacing.sm * 3;
            final brandWidth =
                measure('Stone to Stars', AppText.sectionTitle) +
                44 +
                AppSpacing.md;
            final inline =
                constraints.maxWidth >=
                brandWidth + AppSpacing.xxl + navigationWidth;
            Widget destination(int i) {
              final d = kShellDestinations[i];
              final selected = i == selectedIndex;
              return MergeSemantics(
                child: Semantics(
                  selected: selected,
                  button: true,
                  child: TextButton.icon(
                    key: ValueKey('observatory_nav_$i'),
                    onPressed: () => onSelected(i),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        kMinInteractiveDimension,
                        kMinInteractiveDimension,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      foregroundColor: selected
                          ? AppColors.cyan
                          : AppColors.textSecondary,
                      backgroundColor: selected
                          ? AppColors.cyan.withAlpha(22)
                          : Colors.transparent,
                      side: BorderSide(
                        color: selected
                            ? AppColors.cyan.withAlpha(120)
                            : Colors.transparent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.pillAll,
                      ),
                    ),
                    icon: Icon(selected ? d.selectedIcon : d.icon, size: 20),
                    label: Text(d.label, textAlign: TextAlign.center),
                  ),
                ),
              );
            }

            if (inline) {
              return Row(
                children: [
                  const Expanded(child: _Brand()),
                  const SizedBox(width: AppSpacing.xxl),
                  for (var i = 0; i < kShellDestinations.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    destination(i),
                  ],
                ],
              );
            }
            final columns = navigationWidth <= constraints.maxWidth ? 4 : 2;
            final itemWidth =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Brand(),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < kShellDestinations.length; i++)
                      SizedBox(width: itemWidth, child: destination(i)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}
