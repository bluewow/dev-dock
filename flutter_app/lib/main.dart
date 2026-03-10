import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'screens/dashboard_screen.dart';
import 'screens/project_detail_screen.dart';

void main() {
  runApp(const ProviderScope(child: DevdockApp()));
}

class DevdockApp extends StatelessWidget {
  const DevdockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'Devdock',
      theme: buildAppTheme(),
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
    return Row(
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
            },
          )
        else
          // Collapsed sidebar for detail view
          _CollapsedSidebar(
            onHomeTap: () => setState(() => _selectedProjectId = null),
          ),

        // Main content
        Expanded(
          child: _selectedProjectId != null
              ? ProjectDetailScreen(
                  projectId: _selectedProjectId!,
                  onBack: () => setState(() => _selectedProjectId = null),
                )
              : DashboardScreen(
                  onProjectTap: (id) => setState(() => _selectedProjectId = id),
                ),
        ),
      ],
    );
  }
}

class _CollapsedSidebar extends StatelessWidget {
  final VoidCallback onHomeTap;

  const _CollapsedSidebar({required this.onHomeTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.slate200)),
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
                  color: AppColors.primary600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(FluentIcons.archive, size: 16, color: Colors.white),
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
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(FluentIcons.home, size: 14, color: AppColors.slate400),
            ),
          ),
          const SizedBox(height: 8),
          // Current (project detail)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(FluentIcons.archive, size: 14, color: AppColors.primary600),
          ),
        ],
      ),
    );
  }
}
