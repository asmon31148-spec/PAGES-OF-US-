import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/services/support_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

class SupportBotScreen extends StatefulWidget {
  const SupportBotScreen({super.key});

  @override
  State<SupportBotScreen> createState() => _SupportBotScreenState();
}

class _SupportBotScreenState extends State<SupportBotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  final List<String> _quickSuggestions = [
    '🐞 Report a glitch or bug',
    '🔗 Pairing with partner help',
    '💡 Feature suggestion',
    '🔐 Vault PIN or privacy question',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    final name = user?.nickname ?? 'Partner';

    _messages.add(
      ChatMessage(
        text:
            'Hello $name 🌿 I am your Sanctuary Concierge.\n\n'
            'How can I assist you and your partner today? If you encountered a glitch, have a question about pairing, or have feedback to share, please tell me below. I will personally forward your message to our care team.',
        isUser: false,
        time: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage(text: clean, isUser: true, time: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    final user = context.read<AuthProvider>().user;
    final space = context.read<AuthProvider>().space;
    final userId = user?.id ?? 'anonymous';
    final userEmail = user?.email ?? 'no-email@pagesofus.app';
    final userNickname = user?.nickname ?? 'Partner';

    // 1. Dispatch complaint/ticket to Firestore, Supabase, and Admin Email in background
    SupportService.sendTicket(
      userId: userId,
      userEmail: userEmail,
      userNickname: userNickname,
      spaceId: space?.id,
      message: clean,
    );

    // 2. Simulated warm concierge response
    await Future.delayed(const Duration(milliseconds: 1100));

    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(
          text:
              'Thank you for letting us know, $userNickname 🤍\n\n'
              'Our team has received your message with high priority. We will review this right away and reach out to your registered email ($userEmail) shortly.\n\n'
              'Your experience in Pages of Us is everything to us. Is there anything else I can note down for you?',
          isUser: false,
          time: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final soft = isDark ? AppColors.darkSoft : AppColors.lightSoft;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.sage, AppColors.forest],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sanctuary Concierge',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                Text(
                  'Always here to listen & help',
                  style: TextStyle(fontSize: 10, color: soft),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat message list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) {
                  final msg = _messages[i];
                  return _buildMessageBubble(msg, isDark);
                },
              ),
            ),

            // Typing indicator
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      'Sanctuary Concierge is listening...',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: soft),
                    ),
                  ],
                ),
              ),

            // Quick suggestion chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final text = _quickSuggestions[index];
                  return ActionChip(
                    label: Text(text, style: TextStyle(fontSize: 11, color: ink)),
                    backgroundColor: cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    onPressed: () => _sendMessage(text),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Input bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(fontSize: 13, color: ink),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Share your issue or thought...',
                        hintStyle: TextStyle(fontSize: 12, color: soft),
                        filled: true,
                        fillColor: cardBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sage,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.isUser;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sage,
              ),
              child: const Center(child: Text('🌿', style: TextStyle(fontSize: 13))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.sage : cardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isUser ? Colors.white : ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
