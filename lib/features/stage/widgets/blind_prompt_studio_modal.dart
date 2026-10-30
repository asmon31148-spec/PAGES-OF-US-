import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlindPromptStudioModal(initialTab: initialTab),
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
  final TextEditingController _customQuestionController = TextEditingController();
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
        customTopic: _topicController.text.trim().isNotEmpty ? _topicController.text.trim() : null,
        customRequest: _topicController.text.trim().isNotEmpty ? _topicController.text.trim() : null,
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
    final spaceId = auth.space?.id ?? auth.user?.spaceId ?? '';

    // Capture the messenger BEFORE popping to avoid using a deactivated context
    final messenger = ScaffoldMessenger.of(context);

    // Safely dismiss the bottom sheet modal first
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

    if (spaceId.isNotEmpty) {
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
    }

    _isPinning = false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth = context.watch<AuthProvider>();
    final stage = context.watch<StageProvider>();
    final partner = auth.partner;
    final partnerNickname = partner?.nickname ?? 'Partner';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16151E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

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
                          const Text(
                            'BLIND PROMPT STUDIO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: AppColors.terra,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.terra.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Live Groq AI ✦',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.terra,
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
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
              color: isDark ? const Color(0xFF211F2D) : const Color(0xFFF3F2F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.terra,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.terra.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: '✨ AI Studio'),
                Tab(text: '✏️ Custom'),
                Tab(text: '🗂️ Deck'),
                Tab(text: '📜 History'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAiGeneratorTab(isDark, partnerNickname),
                _buildCustomQuestionTab(isDark),
                _buildCuratedDeckTab(isDark),
                _buildHistoryTab(isDark, stage.promptHistory, partnerNickname),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: AI GENERATOR
  // -------------------------------------------------------------
  Widget _buildAiGeneratorTab(bool isDark, String partnerNickname) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stage Selector
          const Text(
            '1. RELATIONSHIP CHAPTER',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.terra,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.terra.withOpacity(0.18)
                        : (isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.terra : Colors.transparent,
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.terra
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
              const Text(
                '2. ROMANCE INTENSITY / BOLDNESS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.terra,
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
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.terra.withOpacity(0.18)
                          : (isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.terra : Colors.transparent,
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
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? AppColors.terra
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
          const Text(
            '3. DESIRED VIBE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.terra,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.sage.withOpacity(0.18)
                        : (isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.sage : Colors.transparent,
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.sage
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
              const Text(
                '4. CUSTOM REQUEST / EXACT VIBE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.terra,
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
          TextField(
            controller: _topicController,
            minLines: 1,
            maxLines: 2,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white : AppColors.lightInk,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Ask bold physical chemistry questions, midnight bedroom fantasies...',
              hintStyle: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              suffixIcon: _topicController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() => _topicController.clear());
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPromptIdeaChip('🍯 Sweet confessions', isDark),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('💋 Flirty tension', isDark),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('🔥 Physical chemistry', isDark),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('😈 Wild midnight fantasies', isDark),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('🗝️ Deepest secrets', isDark),
                const SizedBox(width: 6),
                _buildPromptIdeaChip('✈️ Future adventures', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : () => _generateAiPrompts(partnerNickname),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                _isGenerating ? 'Groq AI is crafting questions...' : 'Generate 3 Live AI Questions ✦',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terra,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Generated Cards
          if (_generatedPrompts.isNotEmpty) ...[
            const Text(
              'TAP A QUESTION TO PIN AS TODAY\'S PROMPT 💌',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.sage,
              ),
            ),
            const SizedBox(height: 10),
            ..._generatedPrompts.map((gen) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9),
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
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.terra,
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
                            backgroundColor: AppColors.sage,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Use ✦', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
  Widget _buildCustomQuestionTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WRITE YOUR OWN INQUIRY QUESTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.terra,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customQuestionController,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.lightInk,
            ),
            decoration: InputDecoration(
              hintText: 'Type an intimate or curious question for both of you to answer blindly...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Vibe Tag Chooser
          const Text(
            'CHOOSE VIBE TAG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.terra,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.terra.withOpacity(0.18)
                        : (isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.terra : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.terra
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Pin Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isPinning || _customQuestionController.text.trim().isEmpty)
                  ? null
                  : () => _pinPromptToBoard(
                        context: context,
                        question: _customQuestionController.text.trim(),
                        vibeTag: _customVibeTag,
                        category: 'custom',
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terra,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Pin Custom Question to Board ✦',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Quick Inspiration Starters
          const Text(
            'INSPIRATION STARTERS (TAP TO INSERT)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.sage,
            ),
          ),
          const SizedBox(height: 8),
          ...RelationshipAiService.quickStarters.map((st) {
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _customQuestionController.text = st);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
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
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.terra),
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
  Widget _buildCuratedDeckTab(bool isDark) {
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
            child: Row(
              children: [
                _buildDeckFilterChip('all', 'All Prompts', isDark),
                const SizedBox(width: 6),
                ...RelationshipAiService.moods.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildDeckFilterChip(m.id, '${m.icon} ${m.label}', isDark),
                  );
                }),
              ],
            ),
          ),
        ),

        // Prompts List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
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
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.terra,
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
                        backgroundColor: AppColors.sage,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Use ✦', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildPromptIdeaChip(String idea, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _topicController.text = idea;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
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

  Widget _buildDeckFilterChip(String id, String label, bool isDark) {
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
              ? AppColors.terra
              : (isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.terra : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
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
                  color: AppColors.terra.withOpacity(0.12),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = history[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF22202E) : const Color(0xFFF5F4F9),
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
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.terra,
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
                    color: isDark ? const Color(0xFF191823) : Colors.white,
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
