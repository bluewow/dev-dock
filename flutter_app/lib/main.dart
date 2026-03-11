import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'screens/dashboard_screen.dart';
import 'screens/project_detail_screen.dart';
import 'providers/project_providers.dart';

void main() {
  runApp(const ProviderScope(child: DevdockApp()));
}

class DevdockApp extends ConsumerWidget {
  const DevdockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return FluentApp(
      title: 'Devdock',
      theme: buildAppTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _navIndex = 0;
  String? _selectedProjectId;

  @override
  Widget build(BuildContext context) {
    final sc = semanticColors(context);

    return Container(
      color: sc.scaffoldBg,
      child: Row(
      children: [
        // Sidebar (only show full sidebar on dashboard)
        if (_selectedProjectId == null)
          AppSidebar(
            currentIndex: _navIndex,
            onNavigate: (index) {
              setState(() {
                _navIndex = index;
                _selectedProjectId = null;
              });
              // 대시보드로 돌아올 때 스캔 캐시 갱신
              ref.read(scanTriggerProvider.notifier).state++;
            },
          )
        else
          // Collapsed sidebar for detail view
          _CollapsedSidebar(
            onHomeTap: () {
              setState(() => _selectedProjectId = null);
              // 대시보드로 돌아올 때 스캔 캐시 갱신
              ref.read(scanTriggerProvider.notifier).state++;
            },
          ),

        // Main content
        Expanded(
          child: _selectedProjectId != null
              ? ProjectDetailScreen(
                  projectId: _selectedProjectId!,
                  onBack: () {
                    setState(() => _selectedProjectId = null);
                    ref.read(scanTriggerProvider.notifier).state++;
                  },
                )
              : DashboardScreen(
                  onProjectTap: (id) => setState(() => _selectedProjectId = id),
                ),
        ),
      ],
    ),
    );
  }
}

class _CollapsedSidebar extends ConsumerWidget {
  final VoidCallback onHomeTap;

  const _CollapsedSidebar({required this.onHomeTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      width: 56,
      decoration: BoxDecoration(
        color: sc.sidebarBg,
        border: Border(right: BorderSide(color: sc.border)),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: GestureDetector(
              onTap: onHomeTap,
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
          ),
          const SizedBox(height: 8),
          // Home button
          GestureDetector(
            onTap: onHomeTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sc.hoverBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(FluentIcons.home, size: 14, color: sc.textTertiary),
            ),
          ),
          const SizedBox(height: 8),
          // Current (project detail)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.primary500.withValues(alpha: 0.15) : AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(FluentIcons.archive, size: 14, color: isDark ? AppColors.primary400 : AppColors.primary600),
          ),
          const Spacer(),
          // Theme toggle
          GestureDetector(
            onTap: () {
              final current = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: sc.hoverBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDark ? FluentIcons.sunny : FluentIcons.clear_night,
                size: 14,
                color: isDark ? AppColors.amber400 : sc.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
