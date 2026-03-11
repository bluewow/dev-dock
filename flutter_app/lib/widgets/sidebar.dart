import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/project_providers.dart';
import '../theme/app_theme.dart';

class AppSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onNavigate;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final width = collapsed ? 56.0 : 220.0;
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: sc.sidebarBg,
        border: Border(right: BorderSide(color: sc.border, width: 1)),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : 16,
              vertical: 20,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.primary500 : AppColors.primary600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(FluentIcons.archive, size: 16, color: Color(0xFFFFFFFF)),
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Devdock',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: sc.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Divider(
            style: DividerThemeData(
              horizontalMargin: EdgeInsets.zero,
              decoration: BoxDecoration(color: sc.border),
            ),
          ),

          // Nav items
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 12),
              child: Column(
                children: [
                  _NavItem(
                    icon: FluentIcons.home,
                    label: '대시보드',
                    isActive: currentIndex == 0,
                    collapsed: collapsed,
                    onTap: () => onNavigate(0),
                  ),
                  const SizedBox(height: 4),
                  _NavItem(
                    icon: FluentIcons.help,
                    label: '사용 가이드',
                    isActive: currentIndex == 1,
                    collapsed: collapsed,
                    onTap: () => onNavigate(1),
                  ),
                ],
              ),
            ),
          ),

          // Theme toggle
          Divider(
            style: DividerThemeData(
              horizontalMargin: EdgeInsets.zero,
              decoration: BoxDecoration(color: sc.border),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 8),
            child: _NavItem(
              icon: isDark ? FluentIcons.sunny : FluentIcons.clear_night,
              label: isDark ? '라이트 모드' : '다크 모드',
              isActive: false,
              collapsed: collapsed,
              onTap: () {
                final current = ref.read(themeModeProvider);
                ref.read(themeModeProvider.notifier).state =
                    current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
              iconColor: isDark ? AppColors.amber400 : null,
            ),
          ),

          // Collapse toggle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 8),
            child: _NavItem(
              icon: collapsed ? FluentIcons.chevron_right : FluentIcons.chevron_left,
              label: '접기',
              isActive: false,
              collapsed: collapsed,
              onTap: () => ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;
  final Color? iconColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? AppColors.primary500.withValues(alpha: 0.15) : AppColors.primary50)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor ?? (isActive
                  ? (isDark ? AppColors.primary400 : AppColors.primary700)
                  : sc.textTertiary),
            ),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? (isDark ? AppColors.primary400 : AppColors.primary700)
                      : sc.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
