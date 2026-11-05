import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../models/watch_room_model.dart';

class WatchChatView extends StatefulWidget {
  final List<WatchMessage> messages;
  final String currentUid;
  final int totalCount;
  final String? partnerAvatarUrl;
  final String? userAvatarUrl;
  final Function(String text) onSendMessage;
  final Function(String emoji) onSendReaction;
  final bool isLandscape;
  final VoidCallback? onToggleCollapse;

  const WatchChatView({
    super.key,
    required this.messages,
    required this.currentUid,
    this.totalCount = 0,
    this.partnerAvatarUrl,
    this.userAvatarUrl,
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

  List<String> _reactions = ['❤️', '😂', '😮', '😢', '👏'];

  static const List<String> _availableReactions = [
    '❤️', '😂', '😮', '😢', '👏', '🥰', '🥺', '🍿', '🔥', '💤', '💋', '🫣', '✨', '💐', '🤤', '🎉', '🫶', '👀'
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomReactions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottom();
    });
  }

  Future<void> _loadCustomReactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('watch_custom_reactions');
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() {
          _reactions = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCustomReactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('watch_custom_reactions', _reactions);
    } catch (_) {}
  }

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

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _showEmojiPickerSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark || widget.isLandscape;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Customize Reaction Bar (Pick 5)',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.lightInk,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done', style: TextStyle(color: AppColors.terra, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _availableReactions.map((em) {
                      final isSelected = _reactions.contains(em);
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              if (_reactions.length > 1) _reactions.remove(em);
                            } else {
                              if (_reactions.length < 5) {
                                _reactions.add(em);
                              } else {
                                _reactions[4] = em;
                              }
                            }
                          });
                          setState(() {});
                          _saveCustomReactions();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.terra.withOpacity(0.25)
                                : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.terra : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(em, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
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
        ? Colors.black.withOpacity(0.60)
        : (isDark ? AppColors.darkSurface.withOpacity(0.9) : AppColors.lightSurface.withOpacity(0.95));

    final borderColor = widget.isLandscape
        ? Colors.white.withOpacity(0.12)
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    final displayCount = widget.totalCount > widget.messages.length
        ? widget.totalCount
        : widget.messages.length;

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
                        '$displayCount',
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

          // Message List with Avatars
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.messages[index];
                      final isMe = msg.uid == widget.currentUid;
                      final isReaction = msg.type == 'reaction';
                      final effectiveAvatar = isMe
                          ? widget.userAvatarUrl
                          : (msg.avatarUrl.isNotEmpty ? msg.avatarUrl : widget.partnerAvatarUrl);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0),
                        child: Row(
                          mainAxisAlignment:
                              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Partner Avatar Icon
                            if (!isMe && !isReaction) ...[
                              _buildAvatarBubble(effectiveAvatar, msg.name),
                              const SizedBox(width: 5),
                            ],

                            // Message Bubble
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width *
                                      (widget.isLandscape ? 0.22 : 0.70),
                                ),
                                padding: isReaction
                                    ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                                    : const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
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
                                        style: const TextStyle(fontSize: 22),
                                      )
                                    else
                                      Text(
                                        msg.text,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isMe
                                              ? Colors.white
                                              : (isDark ? AppColors.darkInk : AppColors.lightInk),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Quick Emoji Reaction Bar (Row of 5 Customizable Emojis + Edit Button)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor, width: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._reactions.map((emoji) {
                  return GestureDetector(
                    onTap: () => widget.onSendReaction(emoji),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                }),
                // Edit / Customize Emojis Button
                GestureDetector(
                  onTap: _showEmojiPickerSheet,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: TextField(
                      controller: _textController,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkInk : AppColors.lightInk,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Whisper...',
                        hintStyle: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkSoft : AppColors.lightSoft,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.terra,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.send_rounded,
                      size: 15,
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

  Widget _buildAvatarBubble(String? avatarUrl, String fallbackName) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.terra.withOpacity(0.25),
        border: Border.all(color: AppColors.terra.withOpacity(0.4), width: 0.8),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildFallbackInitial(fallbackName),
              )
            : _buildFallbackInitial(fallbackName),
      ),
    );
  }

  Widget _buildFallbackInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: const TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
