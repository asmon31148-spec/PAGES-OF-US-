import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/watch_room_model.dart';

class WatchChatView extends StatefulWidget {
  final List<WatchMessage> messages;
  final String currentUid;
  final Function(String text) onSendMessage;
  final Function(String emoji) onSendReaction;
  final bool isLandscape;
  final VoidCallback? onToggleCollapse;

  const WatchChatView({
    super.key,
    required this.messages,
    required this.currentUid,
    required this.onSendMessage,
    required this.onSendReaction,
    this.isLandscape = false,
    this.onToggleCollapse,
  });

  @override
  State<WatchChatView> createState() => _WatchChatViewState();
}

class _WatchChatViewState extends State<WatchChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _reactions = ['❤️', '😂', '😮', '😢', '👏'];

  @override
  void didUpdateWidget(covariant WatchChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isLandscape;

    final containerBg = widget.isLandscape
        ? Colors.black.withOpacity(0.55)
        : (isDark ? AppColors.darkSurface.withOpacity(0.9) : AppColors.lightSurface.withOpacity(0.95));

    final borderColor = widget.isLandscape
        ? Colors.white.withOpacity(0.12)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Container(
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: widget.isLandscape
            ? const BorderRadius.horizontal(left: Radius.circular(16))
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        children: [
          // Header / Collapse bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 15,
                      color: AppColors.terra,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live Chat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.terra.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.messages.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.terra,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.onToggleCollapse != null)
                  GestureDetector(
                    onTap: widget.onToggleCollapse,
                    child: Icon(
                      widget.isLandscape
                          ? Icons.chevron_right_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Text(
                      'Movie started! Send a love note or reaction ❤️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.messages[index];
                      final isMe = msg.uid == widget.currentUid;
                      final isReaction = msg.type == 'reaction';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width *
                                  (widget.isLandscape ? 0.28 : 0.75),
                            ),
                            padding: isReaction
                                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
                                : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isReaction
                                  ? Colors.transparent
                                  : (isMe
                                      ? AppColors.terra.withOpacity(0.85)
                                      : (isDark
                                          ? Colors.white.withOpacity(0.12)
                                          : Colors.black.withOpacity(0.06))),
                              borderRadius: BorderRadius.circular(14),
                              border: isReaction
                                  ? null
                                  : Border.all(
                                      color: isMe
                                          ? AppColors.terra.withOpacity(0.3)
                                          : Colors.white.withOpacity(0.08),
                                    ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe && !isReaction)
                                  Text(
                                    msg.name,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                                    ),
                                  ),
                                if (isReaction)
                                  Text(
                                    msg.text,
                                    style: const TextStyle(fontSize: 24),
                                  )
                                else
                                  Text(
                                    msg.text,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isMe
                                          ? Colors.white
                                          : (isDark ? AppColors.darkInk : AppColors.lightInk),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Quick Emoji Reaction Bar (Row of 5 Emojis)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _reactions.map((emoji) {
                return GestureDetector(
                  onTap: () => widget.onSendReaction(emoji),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Whisper a thought...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.terra,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
