import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/stage_provider.dart';
import '../../../data/models/couple_goal_item.dart';

/// Full-Screen Milestones & Dreams Screen
class GoalTrackerScreen extends StatefulWidget {
  const GoalTrackerScreen({super.key});

  static void show(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GoalTrackerScreen(),
      ),
    );
  }

  @override
  State<GoalTrackerScreen> createState() => _GoalTrackerScreenState();
}

/// Backwards compatibility alias
typedef GoalTrackerModal = GoalTrackerScreen;

class _GoalTrackerScreenState extends State<GoalTrackerScreen> {
  String _activeTab = 'all'; // 'all', 'firsts', 'future'
  bool _isAddingCustom = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _iconController = TextEditingController(text: '✨');
  String _newCategory = 'firsts';
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              children: [
                // Top Full-Screen App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: isDark ? AppColors.darkInk : AppColors.lightInk,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),

                      // Title & Category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'RELATIONSHIP MILESTONES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: AppColors.terra,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Milestones & Dreams',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Add Quick Goal Action
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: const Icon(Icons.add, size: 18, color: AppColors.terra),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isAddingCustom = !_isAddingCustom);
                        },
                      ),
                    ],
                  ),
                ),

                // Progress Banner Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.sage.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🏆', style: TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completedCount of $totalCount Milestones Celebrated',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: totalCount > 0 ? completedCount / totalCount : 0,
                                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
                                minHeight: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                // Goals Scrollable List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filteredGoals.length,
                    itemBuilder: (context, index) {
                      final goal = filteredGoals[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: goal.isCompleted
                                ? AppColors.sage.withOpacity(0.5)
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: goal.isCompleted ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.darkCard : AppColors.lightCard),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(goal.icon, style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      decoration: goal.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: goal.isCompleted
                                          ? (isDark ? AppColors.darkSoft : AppColors.lightSoft)
                                          : (isDark ? AppColors.darkInk : AppColors.lightInk),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    goal.isCompleted
                                        ? '✦ Completed ${goal.completedDate ?? ""}'
                                        : (goal.targetDate != null
                                            ? 'Target: ${goal.targetDate}'
                                            : (goal.category == 'firsts'
                                                ? 'Couple First'
                                                : 'Future Wish')),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: goal.isCompleted
                                          ? AppColors.sage
                                          : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Check / Complete button
                            IconButton(
                              icon: Icon(
                                goal.isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: goal.isCompleted ? AppColors.sage : (isDark ? AppColors.darkSoft : AppColors.lightSoft),
                                size: 24,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
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
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                stageProvider.deleteGoal(spaceId, goal.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Add Custom Goal Drawer / Sticky Bottom Button
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                  ),
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
                                    child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18, color: AppColors.terra),
                            label: Text(
                              'Add Custom Couple Goal or First',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkInk : AppColors.lightInk,
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() => _isAddingCustom = true);
                            },
                          ),
                        ),
                ),
              ],
            ),

            // Confetti Emitter
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              gravity: 0.1,
              colors: const [
                AppColors.sage,
                AppColors.terra,
                AppColors.rose,
                Colors.amber,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tab, String label, bool isDark) {
    final isSelected = _activeTab == tab;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeTab = tab);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.sage
              : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.sage
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkInk : AppColors.lightInk),
          ),
        ),
      ),
    );
  }
}
