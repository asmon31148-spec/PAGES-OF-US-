import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../data/models/couple_goal_item.dart';

class GoalTrackerModal extends StatefulWidget {
  const GoalTrackerModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GoalTrackerModal(),
    );
  }

  @override
  State<GoalTrackerModal> createState() => _GoalTrackerModalState();
}

class _GoalTrackerModalState extends State<GoalTrackerModal> {
  String _activeTab = 'all'; // 'all', 'firsts', 'future'
  bool _isAddingCustom = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _iconController = TextEditingController(text: '✨');
  String _newCategory = 'firsts';
  DateTime? _targetDate;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _titleController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final stageProvider = context.watch<StageProvider>();
    final authProvider = context.watch<AuthProvider>();
    final spaceId = authProvider.space?.id ?? 'default_space';
    final nickname = authProvider.user?.nickname ?? 'You';

    final filteredGoals = stageProvider.goals.where((g) {
      if (_activeTab == 'firsts') return g.category == 'firsts';
      if (_activeTab == 'future') return g.category == 'future';
      return true;
    }).toList();

    final completedCount = stageProvider.goals.where((g) => g.isCompleted).length;
    final totalCount = stageProvider.goals.length;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Top Header Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RELATIONSHIP MILESTONES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: AppColors.terra,
                            ),
                          ),
                          Text(
                            'Milestones & Dreams',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkInk : AppColors.lightInk,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Progress Banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🏆', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completedCount of $totalCount Milestones Celebrated',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalCount > 0 ? completedCount / totalCount : 0,
                                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      _buildTabButton('all', 'All (${stageProvider.goals.length})', isDark),
                      const SizedBox(width: 8),
                      _buildTabButton('firsts', 'Couple Firsts 🌸', isDark),
                      const SizedBox(width: 8),
                      _buildTabButton('future', 'Future Dreams ✨', isDark),
                    ],
                  ),
                ),

                // Goals List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: filteredGoals.length,
                    itemBuilder: (context, index) {
                      final goal = filteredGoals[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: goal.isCompleted
                                ? AppColors.sage.withOpacity(0.5)
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(goal.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: goal.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                    ),
                                  ),
                                  Text(
                                    goal.isCompleted
                                        ? '✦ Completed ${goal.completedDate ?? ""}'
                                        : (goal.targetDate != null
                                            ? 'Target: ${goal.targetDate}'
                                            : (goal.category == 'firsts'
                                                ? 'Couple First'
                                                : 'Future Wish')),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: goal.isCompleted
                                          ? AppColors.sage
                                          : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Check button
                            IconButton(
                              icon: Icon(
                                goal.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: goal.isCompleted ? AppColors.sage : AppColors.lightSoft,
                                size: 22,
                              ),
                              onPressed: () {
                                final willComplete = !goal.isCompleted;
                                if (willComplete) {
                                  _confettiController.play();
                                }
                                stageProvider.toggleGoal(
                                  spaceId,
                                  goal.id,
                                  willComplete,
                                  nickname,
                                );
                              },
                            ),
                            // Delete button
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                              ),
                              onPressed: () => stageProvider.deleteGoal(spaceId, goal.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Add Custom Goal Drawer / Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _isAddingCustom
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.sage.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 48,
                                    child: TextField(
                                      controller: _iconController,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                        contentPadding: const EdgeInsets.all(8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _titleController,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'e.g. Vacation to Japan, Cook dinner...',
                                        hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                        ),
                                        filled: true,
                                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _newCategory,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(value: 'firsts', child: Text('Couple First 🌸', style: TextStyle(fontSize: 12))),
                                        DropdownMenuItem(value: 'future', child: Text('Future Dream ✨', style: TextStyle(fontSize: 12))),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _newCategory = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() => _isAddingCustom = false),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.sage,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () {
                                      if (_titleController.text.trim().isNotEmpty) {
                                        stageProvider.addGoal(
                                          spaceId,
                                          CoupleGoalItem(
                                            id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
                                            title: _titleController.text.trim(),
                                            icon: _iconController.text.trim().isNotEmpty ? _iconController.text.trim() : '✨',
                                            category: _newCategory,
                                          ),
                                        );
                                        _titleController.clear();
                                        setState(() => _isAddingCustom = false);
                                      }
                                    },
                                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              side: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                style: BorderStyle.solid,
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18, color: AppColors.terra),
                            label: Text(
                              'Add Custom Couple Goal or First',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                            onPressed: () => setState(() => _isAddingCustom = true),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        // Confetti Emitter
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 25,
          gravity: 0.1,
          colors: const [
            AppColors.sage,
            AppColors.terra,
            AppColors.rose,
            Colors.amber,
          ],
        ),
      ],
    );
  }

  Widget _buildTabButton(String tab, String label, bool isDark) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.sage
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkInk : AppColors.lightInk),
          ),
        ),
      ),
    );
  }
}
