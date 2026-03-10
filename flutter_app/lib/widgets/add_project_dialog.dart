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

  static const _colors = ['emerald', 'blue', 'purple', 'amber', 'rose', 'slate'];

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
      });
      return;
    }

    final service = ref.read(projectServiceProvider);
    final result = service.validatePath(path);
    setState(() {
      _validationResult = result.valid;
      _validationMessage = result.message;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final path = _pathController.text.trim();

    if (name.isEmpty || path.isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(projectsProvider.notifier).addProject(
            name: name,
            path: path,
            color: _selectedColor,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }

    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 440),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '새 프로젝트 등록',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          SizedBox(height: 4),
          Text(
            '로컬 프로젝트 폴더를 등록하세요',
            style: TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          const Text(
            '프로젝트 이름',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate400),
          ),
          const SizedBox(height: 6),
          TextBox(
            controller: _nameController,
            placeholder: '예: My Project',
            style: const TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 16),

          // Path
          const Text(
            '로컬 경로',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate400),
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
          const Text(
            '카드 컬러',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate400),
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

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.red600),
            ),
          ],
        ],
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
}
