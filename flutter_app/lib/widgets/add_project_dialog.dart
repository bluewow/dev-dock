import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/project_providers.dart';
import '../theme/app_theme.dart';

class AddProjectDialog extends ConsumerStatefulWidget {
  const AddProjectDialog({super.key});

  @override
  ConsumerState<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends ConsumerState<AddProjectDialog> {
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  String _selectedColor = 'emerald';
  String? _validationMessage;
  bool? _validationResult;
  bool _submitting = false;
  String? _error;

  // .claude 설치 관련 상태
  bool _installClaude = false;
  bool? _hasExistingClaude;
  bool _hasSourceClaude = false;
  String? _installResultMessage;
  bool? _installSuccess;

  static const _colors = ['emerald', 'blue', 'purple', 'amber', 'rose', 'slate'];

  @override
  void initState() {
    super.initState();
    // 소스 .claude 존재 여부 확인
    final service = ref.read(projectServiceProvider);
    _hasSourceClaude = service.hasSourceClaude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '프로젝트 폴더 선택',
    );
    if (result != null) {
      _pathController.text = result;
      _validate();
    }
  }

  void _validate() {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _validationMessage = null;
        _validationResult = null;
        _hasExistingClaude = null;
      });
      return;
    }

    final service = ref.read(projectServiceProvider);
    final result = service.validatePath(path);
    setState(() {
      _validationResult = result.valid;
      _validationMessage = result.message;
      // .claude 존재 여부 감지
      if (result.valid) {
        _hasExistingClaude = service.hasClaudeConfig(path);
      } else {
        _hasExistingClaude = null;
      }
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final path = _pathController.text.trim();

    if (name.isEmpty || path.isEmpty) return;

    // 기존 .claude가 있고 설치를 원하면 최종 확인
    if (_installClaude && _hasExistingClaude == true) {
      final confirmed = await _showOverwriteConfirmDialog();
      if (confirmed != true) return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _installResultMessage = null;
      _installSuccess = null;
    });

    try {
      await ref.read(projectsProvider.notifier).addProject(
            name: name,
            path: path,
            color: _selectedColor,
          );

      // .claude 설치
      if (_installClaude && _hasSourceClaude) {
        final service = ref.read(projectServiceProvider);
        final result = await service.installClaude(
          targetPath: path,
          forceOverwrite: _hasExistingClaude == true,
        );

        if (result.success) {
          // 성공: 가이드 포함한 결과 다이얼로그 표시 후 닫기
          if (mounted) {
            await _showInstallSuccessDialog(result.filesCopied);
            if (mounted) Navigator.of(context).pop(true);
          }
          return;
        } else {
          // 설치 실패: 프로젝트는 이미 등록됨. 에러 표시
          setState(() {
            _installResultMessage = result.error;
            _installSuccess = false;
          });
          if (mounted) Navigator.of(context).pop(true);
          return;
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }

    setState(() => _submitting = false);
  }

  Future<bool?> _showOverwriteConfirmDialog() {
    final sc = semanticColors(context);
    return showDialog<bool>(
      context: context,
      builder: (_) => ContentDialog(
        title: Text(
          '기존 .claude 폴더 삭제',
          style: TextStyle(fontWeight: FontWeight.w700, color: sc.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기존 .claude 폴더를 삭제하고 새로 설치합니다.',
              style: TextStyle(fontSize: 13, color: sc.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(fontSize: 13, color: AppColors.red600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: const ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.red500),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제 후 설치', style: TextStyle(color: Color(0xFFFFFFFF))),
          ),
        ],
      ),
    );
  }

  Future<void> _showInstallSuccessDialog(int filesCopied) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      builder: (_) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 420),
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isDark ? AppColors.emerald400.withValues(alpha: 0.15) : AppColors.emerald50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(FluentIcons.check_mark, size: 12,
                color: isDark ? AppColors.emerald400 : AppColors.emerald700),
            ),
            const SizedBox(width: 8),
            Text(
              '.claude 설치 완료',
              style: TextStyle(fontWeight: FontWeight.w700, color: sc.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$filesCopied개 파일이 설치되었습니다.',
              style: TextStyle(fontSize: 13, color: sc.textSecondary),
            ),
            const SizedBox(height: 12),
            // settings.local.json 가이드
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.amber400.withValues(alpha: 0.1) : const Color(0xFFFFFBEB),
                border: Border.all(
                  color: isDark ? AppColors.amber400.withValues(alpha: 0.3) : const Color(0xFFFDE68A),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings.local.json 생성 필요',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.amber400 : AppColors.amber700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '프로젝트의 .claude/ 폴더에 settings.local.json 파일을 직접 생성하세요:',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.amber400.withValues(alpha: 0.8) : const Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '{\n  "env": {\n    "SLACK_WEBHOOK_URL": "your-webhook-url"\n  }\n}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Consolas',
                        color: sc.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 440),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '새 프로젝트 등록',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: sc.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '로컬 프로젝트 폴더를 등록하세요',
            style: TextStyle(fontSize: 13, color: sc.textTertiary, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            Text(
              '프로젝트 이름',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sc.textTertiary),
            ),
            const SizedBox(height: 6),
            TextBox(
              controller: _nameController,
              placeholder: '예: My Project',
              style: const TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 16),

            // Path
            Text(
              '로컬 경로',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sc.textTertiary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextBox(
                    controller: _pathController,
                    placeholder: r'예: C:\project\my-project',
                    style: const TextStyle(fontSize: 12, fontFamily: 'Consolas'),
                    onChanged: (_) => _validate(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _pickFolder,
                  child: const Text('폴더 선택', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),

            // Validation
            if (_validationMessage != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _validationResult == true ? AppColors.emerald400 : AppColors.red500,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _validationMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: _validationResult == true ? AppColors.emerald700 : AppColors.red600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Color
            Text(
              '카드 컬러',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sc.textTertiary),
            ),
            const SizedBox(height: 6),
            Row(
              children: _colors.map((c) {
                final isSelected = c == _selectedColor;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.dotColor(c),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary600 : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primary200.withValues(alpha: 0.5), blurRadius: 6)]
                            : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // .claude 설치 섹션
            if (_hasSourceClaude && _validationResult == true) ...[
              const SizedBox(height: 16),
              _buildClaudeInstallSection(sc, isDark),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.red600),
              ),
            ],

            if (_installResultMessage != null && _installSuccess == false) ...[
              const SizedBox(height: 12),
              Text(
                _installResultMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.red600),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '등록 중...' : '등록'),
        ),
      ],
    );
  }

  Widget _buildClaudeInstallSection(AppSemanticColors sc, bool isDark) {
    final service = ref.read(projectServiceProvider);
    final isDevdockSelf = service.isDevdockPath(_pathController.text.trim());

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _installClaude ? (isDark ? AppColors.primary500 : AppColors.primary200) : sc.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 아이콘 + 라벨 + 토글
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary500.withValues(alpha: 0.15) : AppColors.primary50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(FluentIcons.settings, size: 12,
                  color: isDark ? AppColors.primary400 : AppColors.primary600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Claude 설정 설치',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDevdockSelf ? sc.textTertiary : sc.textPrimary,
                      ),
                    ),
                    Text(
                      '커맨드, 에이전트, 훅 설정을 프로젝트에 설치',
                      style: TextStyle(fontSize: 9, color: sc.textTertiary),
                    ),
                  ],
                ),
              ),
              ToggleSwitch(
                checked: _installClaude && !isDevdockSelf,
                onChanged: isDevdockSelf
                    ? null
                    : (v) => setState(() => _installClaude = v),
              ),
            ],
          ),

          // Devdock 자체 경로 경고
          if (isDevdockSelf) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Devdock 프로젝트에는 설치할 수 없습니다.',
                style: TextStyle(fontSize: 10, color: sc.textTertiary),
              ),
            ),
          ],

          // 기존 .claude 감지 경고
          if (_installClaude && _hasExistingClaude == true && !isDevdockSelf) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.amber400.withValues(alpha: 0.1) : const Color(0xFFFFFBEB),
                border: Border.all(
                  color: isDark ? AppColors.amber400.withValues(alpha: 0.3) : const Color(0xFFFDE68A),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.amber400.withValues(alpha: 0.2) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.amber400 : AppColors.amber700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '기존 .claude 폴더가 감지되었습니다',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.amber400 : AppColors.amber700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '설치를 진행하면 기존 .claude 폴더를 삭제하고 새로 설치합니다.',
                          style: TextStyle(
                            fontSize: 9,
                            color: isDark ? AppColors.amber400.withValues(alpha: 0.7) : const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 설치 항목 미리보기
          if (_installClaude && !isDevdockSelf) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? sc.hoverBg : AppColors.slate50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildInstallPreview(sc, isDark),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstallPreview(AppSemanticColors sc, bool isDark) {
    final service = ref.read(projectServiceProvider);
    final summary = service.getClaudeInstallSummary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '설치 항목',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc.textTertiary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...summary.folders.map((f) => _previewItem(f, true, sc, isDark)),
            ...summary.rootFiles.map((f) => _previewItem(f, true, sc, isDark)),
            ...summary.excludedFiles.map((f) => _previewItem(f, false, sc, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _previewItem(String name, bool included, AppSemanticColors sc, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          included ? FluentIcons.check_mark : FluentIcons.chrome_close,
          size: 8,
          color: included
              ? (isDark ? AppColors.emerald400 : AppColors.emerald700)
              : sc.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 9,
            color: included ? sc.textSecondary : sc.textTertiary,
            decoration: included ? null : TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}
