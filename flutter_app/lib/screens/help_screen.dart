import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';

class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  int _selectedStep = 0;

  static const _steps = [
    _GuideStep(
      icon: FluentIcons.archive,
      iconColorLight: AppColors.primary600,
      iconColorDark: AppColors.primary400,
      iconBgLight: AppColors.primary50,
      iconBgDark: Color(0x26818CF8), // primary400 @15%
      title: 'Devdock이란?',
      subtitle: '로컬 프로젝트 관리 허브',
      sections: [
        _GuideSection(
          heading: 'Devdock은 무엇을 하는 앱인가요?',
          body:
              'Devdock은 로컬에 있는 여러 개발 프로젝트를 한 곳에서 관리하는 데스크톱 앱입니다.\n'
              'Claude Code와 함께 사용하면, AI가 생성한 기획서·디자인 시안·개발 스펙을 앱 안에서 바로 확인하고 승인/반려할 수 있습니다.',
        ),
        _GuideSection(
          heading: '주요 기능',
          bullets: [
            '프로젝트 등록 — 로컬 폴더를 등록해 대시보드에서 한눈에 관리',
            '산출물 뷰어 — docs/tasks/ 폴더의 HTML 파일을 앱 안에서 바로 열람',
            '이력 추적 — 기획·디자인·개발 단계 진행 이력을 타임라인으로 확인',
          ],
        ),
      ],
    ),
    _GuideStep(
      icon: FluentIcons.add,
      iconColorLight: AppColors.emerald700,
      iconColorDark: AppColors.emerald400,
      iconBgLight: AppColors.emerald50,
      iconBgDark: Color(0x2634D399), // emerald400 @15%
      title: '프로젝트 등록',
      subtitle: '첫 번째로 할 일',
      sections: [
        _GuideSection(
          heading: '어떻게 등록하나요?',
          body:
              '대시보드 우측 상단의 "새 프로젝트" 버튼을 클릭합니다.\n'
              '프로젝트 이름을 입력하고, "폴더 선택" 버튼으로 로컬 경로를 지정합니다.\n'
              '원하는 카드 컬러를 선택한 뒤 "등록" 버튼을 누르면 대시보드에 카드가 생성됩니다.',
        ),
        _GuideSection(
          heading: '경로가 올바른지 확인하는 방법',
          body:
              '경로를 입력하면 즉시 유효성 검사가 실행됩니다.\n'
              '초록 점이 표시되면 유효한 경로, 빨간 점이 표시되면 존재하지 않는 경로입니다.',
        ),
        _GuideSection(
          heading: '프로젝트를 삭제하면 실제 파일도 지워지나요?',
          body: '아니요. 프로젝트를 목록에서 제거할 뿐, 로컬 파일은 전혀 삭제되지 않습니다.',
        ),
      ],
    ),
    _GuideStep(
      icon: FluentIcons.document_set,
      iconColorLight: AppColors.blue700,
      iconColorDark: AppColors.blue400,
      iconBgLight: AppColors.blue50,
      iconBgDark: Color(0x2660A5FA), // blue400 @15%
      title: '산출물 뷰어',
      subtitle: '기획서·디자인 시안 확인',
      sections: [
        _GuideSection(
          heading: '산출물이 보이려면 어떤 구조여야 하나요?',
          body:
              '프로젝트 루트 아래에 docs/tasks/ 폴더를 만들고, 그 안에 태스크 폴더(예: 001-login/)를 생성하세요.\n'
              '태스크 폴더 안에 plan.html, design.html, spec.md 파일을 넣으면 Devdock이 자동으로 감지합니다.',
        ),
        _GuideSection(
          heading: '어떻게 열람하나요?',
          body:
              '대시보드에서 프로젝트 카드를 클릭하면 상세 화면으로 이동합니다.\n'
              '왼쪽 태스크 목록에서 태스크를 선택하면 해당 태스크의 산출물 파일 목록이 나타납니다.\n'
              '파일을 클릭하면 오른쪽 뷰어에 HTML이 렌더링됩니다.',
        ),
        _GuideSection(
          heading: '지원하는 파일 종류',
          bullets: [
            'plan.html — 기획서 (화면 플로우, 데이터 모델)',
            'design.html — 디자인 시안 (Before/After 비교)',
            'spec.md — 개발 스펙 (마크다운)',
            'idea.html — 분석서',
          ],
        ),
      ],
    ),
    _GuideStep(
      icon: FluentIcons.clear_night,
      iconColorLight: AppColors.amber700,
      iconColorDark: AppColors.amber400,
      iconBgLight: AppColors.amber50,
      iconBgDark: Color(0x26FBBF24), // amber400 @15%
      title: '기타 기능',
      subtitle: '다크모드 · 사이드바',
      sections: [
        _GuideSection(
          heading: '다크모드는 어떻게 켜나요?',
          body:
              '사이드바 하단의 달 아이콘을 클릭하면 라이트/다크 모드가 전환됩니다.\n'
              '프로젝트 상세 화면에서는 축소 사이드바 하단의 태양/달 아이콘을 사용하세요.',
        ),
        _GuideSection(
          heading: '사이드바를 접을 수 있나요?',
          body:
              '사이드바 하단의 화살표(←) 버튼을 누르면 사이드바가 56px 너비로 접힙니다.\n'
              '접힌 상태에서는 아이콘만 표시되며, 다시 화살표(→)를 누르면 펼쳐집니다.',
        ),
        _GuideSection(
          heading: '이력은 어디서 볼 수 있나요?',
          body:
              '프로젝트 상세 화면 우측 상단의 "이력 보기" 버튼을 누르면 history.html이 뷰어에 표시됩니다.\n'
              '기획·디자인·승인·개발 단계별 진행 이력을 타임라인으로 확인할 수 있습니다.',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sc = semanticColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary500.withValues(alpha: 0.15)
                      : AppColors.primary50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  FluentIcons.help,
                  size: 20,
                  color: isDark ? AppColors.primary400 : AppColors.primary600,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '사용 가이드',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: sc.textPrimary,
                    ),
                  ),
                  Text(
                    '4단계로 Devdock의 핵심 기능을 파악하세요',
                    style: TextStyle(fontSize: 13, color: sc.textTertiary),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          // 스텝 탭
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_steps.length, (i) {
                final step = _steps[i];
                final isActive = i == _selectedStep;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _StepTab(
                    step: step,
                    index: i,
                    isActive: isActive,
                    isDark: isDark,
                    sc: sc,
                    onTap: () => setState(() => _selectedStep = i),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 24),

          // 본문
          Expanded(
            child: _StepContent(
              step: _steps[_selectedStep],
              isDark: isDark,
              sc: sc,
            ),
          ),

          // 이전/다음 네비게이션
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_selectedStep > 0)
                _NavButton(
                  icon: FluentIcons.chevron_left,
                  label: _steps[_selectedStep - 1].title,
                  isNext: false,
                  sc: sc,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedStep--),
                )
              else
                const SizedBox.shrink(),
              // 진행 점 표시
              Row(
                children: List.generate(_steps.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _selectedStep ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _selectedStep
                          ? (isDark ? AppColors.primary400 : AppColors.primary600)
                          : sc.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              if (_selectedStep < _steps.length - 1)
                _NavButton(
                  icon: FluentIcons.chevron_right,
                  label: _steps[_selectedStep + 1].title,
                  isNext: true,
                  sc: sc,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedStep++),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 스텝 탭 버튼 ──────────────────────────────────────────────────────────────

class _StepTab extends StatelessWidget {
  final _GuideStep step;
  final int index;
  final bool isActive;
  final bool isDark;
  final AppSemanticColors sc;
  final VoidCallback onTap;

  const _StepTab({
    required this.step,
    required this.index,
    required this.isActive,
    required this.isDark,
    required this.sc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDark
        ? AppColors.primary500.withValues(alpha: 0.15)
        : AppColors.primary50;
    final activeText =
        isDark ? AppColors.primary400 : AppColors.primary700;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? (isDark ? AppColors.primary500 : AppColors.primary200)
                  : sc.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark ? step.iconBgDark : step.iconBgLight)
                      : sc.hoverBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  step.icon,
                  size: 11,
                  color: isActive
                      ? (isDark ? step.iconColorDark : step.iconColorLight)
                      : sc.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeText : sc.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 스텝 본문 ────────────────────────────────────────────────────────────────

class _StepContent extends StatelessWidget {
  final _GuideStep step;
  final bool isDark;
  final AppSemanticColors sc;

  const _StepContent({
    required this.step,
    required this.isDark,
    required this.sc,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 스텝 타이틀 헤더 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? step.iconBgDark : step.iconBgLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? step.iconColorDark.withValues(alpha: 0.2)
                    : step.iconColorLight.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? step.iconColorDark.withValues(alpha: 0.2)
                        : step.iconColorLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    step.icon,
                    size: 22,
                    color: isDark ? step.iconColorDark : step.iconColorLight,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? step.iconColorDark : step.iconColorLight,
                      ),
                    ),
                    Text(
                      step.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? step.iconColorDark.withValues(alpha: 0.7)
                            : step.iconColorLight.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 섹션 목록
          ...step.sections.map((section) => _SectionCard(
                section: section,
                isDark: isDark,
                sc: sc,
              )),
        ],
      ),
    );
  }
}

// ─── 섹션 카드 ────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final _GuideSection section;
  final bool isDark;
  final AppSemanticColors sc;

  const _SectionCard({
    required this.section,
    required this.isDark,
    required this.sc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 제목
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary400 : AppColors.primary600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.heading,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sc.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          if (section.body != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                section.body!,
                style: TextStyle(
                  fontSize: 13,
                  color: sc.textSecondary,
                  height: 1.7,
                ),
              ),
            ),
          ],

          if (section.bullets != null && section.bullets!.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...section.bullets!.map(
              (bullet) => Padding(
                padding: const EdgeInsets.only(left: 14, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary400
                              : AppColors.primary600,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bullet,
                        style: TextStyle(
                          fontSize: 13,
                          color: sc.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 이전/다음 버튼 ───────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isNext;
  final AppSemanticColors sc;
  final bool isDark;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isNext,
    required this.sc,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sc.hoverBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sc.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: isNext
                ? [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sc.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(icon, size: 12, color: sc.textTertiary),
                  ]
                : [
                    Icon(icon, size: 12, color: sc.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sc.textSecondary,
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

// ─── 데이터 모델 ──────────────────────────────────────────────────────────────

class _GuideStep {
  final IconData icon;
  final Color iconColorLight;
  final Color iconColorDark;
  final Color iconBgLight;
  final Color iconBgDark;
  final String title;
  final String subtitle;
  final List<_GuideSection> sections;

  const _GuideStep({
    required this.icon,
    required this.iconColorLight,
    required this.iconColorDark,
    required this.iconBgLight,
    required this.iconBgDark,
    required this.title,
    required this.subtitle,
    required this.sections,
  });
}

class _GuideSection {
  final String heading;
  final String? body;
  final List<String>? bullets;

  const _GuideSection({
    required this.heading,
    this.body,
    this.bullets,
  });
}
