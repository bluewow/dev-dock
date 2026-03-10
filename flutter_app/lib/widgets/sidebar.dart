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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.slate200, width: 1)),
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
                      color: AppColors.primary600,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(FluentIcons.archive, size: 16, color: Colors.white),
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  const Text(
                    'Devdock',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.slate800,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.zero)),

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
                ],
              ),
            ),
          ),

          // Bottom: collapse toggle
          const Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.zero)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 12),
            child: _NavItem(
              icon: collapsed ? FluentIcons.chevron_right : FluentIcons.chevron_left,
              label: '접기',
              isActive: false,
              collapsed: collapsed,
              onTap: () => ref.read(sidebarCollapsedProvider.notifier).state = !collapsed,
            ),
          ),
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? 0 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary50 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? AppColors.primary700 : AppColors.slate400,
            ),
            if (!collapsed) ...[
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive ? AppColors.primary700 : AppColors.slate500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
