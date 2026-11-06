import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass/shared_living_theme_background.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../core/services/relationship_ai_service.dart';
import '../../../data/models/daily_prompt.dart';

class BlindPromptStudioModal extends StatefulWidget {
  final int initialTab;

  const BlindPromptStudioModal({
    super.key,
    this.initialTab = 0,
  });

  static void show(BuildContext context, {int initialTab = 0}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            BlindPromptStudioModal(initialTab: initialTab),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<BlindPromptStudioModal> createState() => _BlindPromptStudioModalState();
}

class _BlindPromptStudioModalState extends State<BlindPromptStudioModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: AI Generator State
  String _selectedStage = 'deep';
  String _selectedMood = 'bold_romance';
  String _selectedBoldness = 'bold';
  final TextEditingController _topicController = TextEditingController();
  List<GeneratedPrompt> _generatedPrompts = [];
  bool _isGenerating = false;

  // Tab 2: Custom Question State
  final TextEditingController _customQuestionController =
      TextEditingController();
  String _customVibeTag = 'Gentle Whisper';

  // Tab 3: Curated Deck State
  String _deckCategoryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicController.dispose();
    _customQuestionController.dispose();
    super.dispose();
  }

  void _generateAiPrompts(String? partnerNickname) async {
    HapticFeedback.mediumImpact();
    setState(() => _isGenerating = true);

    try {
      final results = await RelationshipAiService.generatePromptsLive(
        stage: _selectedStage,
        mood: _selectedMood,
        boldness: _selectedBoldness,
        customTopic: _topicController.text.trim().isNotEmpty
            ? _topicController.text.trim()
            : null,
        customRequest: _topicController.text.trim().isNotEmpty
            ? _topicController.text.trim()
            : null,
        partnerNickname: partnerNickname,
      );

      if (mounted) {
        setState(() {
          _generatedPrompts = results;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  bool _isPinning = false;

  Future<void> _pinPromptToBoard({
    required BuildContext context,
    required String question,
    required String vibeTag,
    required String category,
  }) async {
    if (_isPinning) return;
    _isPinning = true;

    HapticFeedback.mediumImpact();
    final auth = context.read<AuthProvider>();
    final stage = context.read<StageProvider>();
    final spaceId =
        auth.space?.id ?? auth.user?.spaceId ?? stage.activeSpaceId ?? '';

    final messenger = ScaffoldMessenger.of(context);

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Pinned new question to sanctuary board! 💌',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: AppColors.terra,
        duration: const Duration(milliseconds: 2000),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await stage.setCustomDailyPrompt(
        spaceId: spaceId,
        question: question,
        vibeTag: vibeTag,
        category: category,
      );
    } catch (e) {
      debugPrint('Failed to set custom prompt: $e');
    }

    _isPinning = false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final palette = themeProvider.currentPalette;
    final auth = context.watch<AuthProvider>();
    final stage = context.watch<StageProvider>();
    final partner = auth.partner;
    final partnerNickname = partner?.nickname ?? 'Partner';

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SharedLivingThemeBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'BLIND PROMPT STUDIO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: palette.accentColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: palette.accentColor.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Live Groq AI ✦',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: palette.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Intimate Inquiry & Questions for Two',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.lightInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.06),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: palette.accentColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accentColor.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      isDark ? Colors.white60 : Colors.black54,
                  labelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(text: '✨ AI Studio'),
                    Tab(text: '✏️ Custom'),
                    Tab(text: '🗂️ Deck'),
                    Tab(text: '📜 History'),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAiGeneratorTab(isDark, palette, partnerNickname),
                    _buildCustomQuestionTab(isDark, palette),
                    _buildCuratedDeckTab(isDark, palette),
                    _buildHistoryTab(
                        isDark, palette, stage.promptHistory, partnerNickname),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: AI GENERATOR
  // -------------------------------------------------------------
  Widget _buildAiGeneratorTab(
      bool isDark, PaletteTokens palette, String partnerNickname) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stage Selector
          Text(
            '1. RELATIONSHIP CHAPTER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RelationshipAiService.stages.map((st) {
              final isSelected = _selectedStage == st.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedStage = st.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? palette.accentColor.withOpacity(0.20)
                        : (isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.60)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? palette.accentColor : (isDark ? Colors.white12 : Colors.black12),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(st.icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        st.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? palette.accentColor
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // 2. Boldness / Romance Intensity Spectrum Selector
          Row(
            children: [
              Text(
                '2. ROMANCE INTENSITY / BOLDNESS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: palette.accentColor,
                ),
              ),
              const Spacer(),
              Text(
                'SWEET 🍯 ── 😈 WILD',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white38 : Colors.black38,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: RelationshipAiService.boldnessLevels.map((b) {
              final isSelected = _selectedBoldness == b.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedBoldness = b.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? palette.accentColor.withOpacity(0.20)
                          : (isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white.withOpacity(0.60)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? palette.accentColor : (isDark ? Colors.white12 : Colors.black12),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(b.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(
                          b.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? palette.accentColor
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
            child: Text(
              RelationshipAiService.boldnessLevels
                  .firstWhere((b) => b.id == _selectedBoldness,
                      orElse: () => RelationshipAiService.boldnessLevels[2])
                  .subtitle,
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. Desired Vibe Selector
          Text(
            '3. DESIRED VIBE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RelationshipAiService.moods.map((md) {
              final isSelected = _selectedMood == md.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedMood = md.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? palette.accentColor.withOpacity(0.20)
                        : (isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.60)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? palette.accentColor : (isDark ? Colors.white12 : Colors.black12),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(md.icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        md.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? palette.accentColor
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // 4. Custom Request / Exact Vibe
          Row(
            children: [
              Text(
                '4. CUSTOM REQUEST / EXACT VIBE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: palette.accentColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(OPTIONAL)',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type custom instructions or tap an idea below to tailor the AI prompt:',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _topicController,
            builder: (context, val, _) {
              return TextField(
                controller: _topicController,
                minLines: 1,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white : AppColors.lightInk,
                ),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Ask bold physical chemistry questions, midnight bedroom fantasies...',
                  hintStyle: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.70),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: val.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => _topicController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPromptIdeaChip('🍯 Sweet confessions', isDark, palette),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('💋 Flirty tension', isDark, palette),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('🔥 Physical chemistry', isDark, palette),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('😈 Wild midnight fantasies', isDark, palette),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('🗝️ Deepest secrets', isDark, palette),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('✈️ Future adventures', isDark, palette),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating
                  ? null
                  : () => _generateAiPrompts(partnerNickname),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                _isGenerating
                    ? 'Groq AI is crafting questions...'
                    : 'Generate 3 Live AI Questions ✦',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Generated Cards
          if (_generatedPrompts.isNotEmpty) ...[
            Text(
              'TAP A QUESTION TO PIN AS TODAY\'S PROMPT 💌',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: palette.accentColor,
              ),
            ),
            const SizedBox(height: 10),
            ..._generatedPrompts.map((gen) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          gen.vibeTag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: palette.accentColor,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isPinning
                              ? null
                              : () => _pinPromptToBoard(
                                    context: context,
                                    question: gen.question,
                                    vibeTag: gen.vibeTag,
                                    category: gen.category,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.accentColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Use ✦',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '"${gen.question}"',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white : AppColors.lightInk,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: CUSTOM QUESTION
  // -------------------------------------------------------------
  Widget _buildCustomQuestionTab(bool isDark, PaletteTokens palette) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WRITE YOUR OWN INQUIRY QUESTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.accentColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customQuestionController,
            maxLines: 3,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.lightInk,
            ),
            decoration: InputDecoration(
              hintText:
                  'Type an intimate or curious question for both of you to answer blindly...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.70),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Vibe Tag Chooser
          Text(
            'CHOOSE VIBE TAG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.accentColor,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Gentle Whisper',
              'Deep Confession',
              'Playful Banter',
              'Midnight Thought',
              'Sweet Dream',
            ].map((tag) {
              final isSelected = _customVibeTag == tag;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _customVibeTag = tag);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? palette.accentColor.withOpacity(0.20)
                        : (isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.60)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? palette.accentColor
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? palette.accentColor
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Pin Button with ValueListenableBuilder for 0ms lag
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _customQuestionController,
            builder: (context, val, _) {
              final canPin = !_isPinning && val.text.trim().isNotEmpty;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canPin
                      ? () => _pinPromptToBoard(
                            context: context,
                            question: _customQuestionController.text.trim(),
                            vibeTag: _customVibeTag,
                            category: 'custom',
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.white12 : Colors.black12,
                    disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Pin Custom Question to Board ✦',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),

          // Quick Inspiration Starters
          Text(
            'INSPIRATION STARTERS (TAP TO INSERT)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: palette.accentColor,
            ),
          ),
          const SizedBox(height: 8),
          ...RelationshipAiService.quickStarters.map((st) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                _customQuestionController.text = st;
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.white.withOpacity(0.60),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '"$st"',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: palette.accentColor),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: CURATED DECK
  // -------------------------------------------------------------
  Widget _buildCuratedDeckTab(bool isDark, PaletteTokens palette) {
    final filtered = _deckCategoryFilter == 'all'
        ? RelationshipAiService.curatedDeck
        : RelationshipAiService.curatedDeck
            .where((d) => d['category'] == _deckCategoryFilter)
            .toList();

    return Column(
      children: [
        // Category Filter Pills
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildDeckFilterChip('all', 'All Prompts', isDark, palette),
                const SizedBox(width: 6),
                ...RelationshipAiService.moods.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildDeckFilterChip(
                        m.id, '${m.icon} ${m.label}', isDark, palette),
                  );
                }),
              ],
            ),
          ),
        ),

        // Prompts List
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.07)
                      : Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['vibeTag'] ?? '',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: palette.accentColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '"${item['question']}"',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white : AppColors.lightInk,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isPinning
                          ? null
                          : () => _pinPromptToBoard(
                                context: context,
                                question: item['question']!,
                                vibeTag: item['vibeTag']!,
                                category: item['category']!,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Use ✦',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPromptIdeaChip(
      String idea, bool isDark, PaletteTokens palette) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _topicController.text = idea;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        child: Text(
          idea,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildDeckFilterChip(
      String id, String label, bool isDark, PaletteTokens palette) {
    final isSelected = _deckCategoryFilter == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _deckCategoryFilter = id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? palette.accentColor
              : (isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.white.withOpacity(0.60)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? palette.accentColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: HISTORY ARCHIVE
  // -------------------------------------------------------------
  Widget _buildHistoryTab(
    bool isDark,
    PaletteTokens palette,
    List<PromptHistoryItem> history,
    String partnerNickname,
  ) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accentColor.withOpacity(0.14),
                ),
                alignment: Alignment.center,
                child: const Text('📜', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 16),
              Text(
                'No Answer History Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightInk,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'When you and $partnerNickname both answer today\'s prompt, your unsealed envelope will be preserved here in your relationship archive forever 💕',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = history[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.vibeTag.isNotEmpty ? item.vibeTag : 'BLIND INQUIRY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: palette.accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    item.date,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '"${item.question}"',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.lightInk,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              // Answers List
              ...item.answers.entries.map((ans) {
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💌', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ans.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white70 : Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
