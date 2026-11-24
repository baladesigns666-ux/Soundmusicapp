import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/firebase_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String currentUsername;
  final ChatThread thread;

  const ChatRoomScreen({
    super.key,
    required this.currentUsername,
    required this.thread,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isPeerTyping = false;
  Timer? _replyTimer;

  @override
  void dispose() {
    _replyTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      widget.thread.messages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderUsername: widget.currentUsername,
          text: text,
          timestamp: DateTime.now(),
          isMe: true,
        ),
      );
      _isPeerTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    if (FirebaseChatService.isInitialized) {
      await FirebaseChatService.sendMessageToFirestore(
        currentUsername: widget.currentUsername,
        peerUsername: widget.thread.username,
        text: text,
      );
    }

    _replyTimer?.cancel();
    _replyTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _isPeerTyping = false;
        widget.thread.messages.add(
          ChatMessage(
            id: '${DateTime.now().millisecondsSinceEpoch}_r',
            senderUsername: widget.thread.username,
            text: 'Got your message on @${widget.thread.username}! 👍',
            timestamp: DateTime.now(),
            isMe: false,
          ),
        );
      });
      _scrollToBottom();
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.thread.messages;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.25),
              child: Text(
                widget.thread.displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.thread.displayName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  _isPeerTyping ? 'typing...' : '@${widget.thread.username}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _isPeerTyping
                        ? const Color(0xFF34D399)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 44,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Say hi to @${widget.thread.username}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return Align(
                        alignment: msg.isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.74,
                          ),
                          decoration: BoxDecoration(
                            color: msg.isMe
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF161E31),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(msg.isMe ? 18 : 4),
                              bottomRight: Radius.circular(msg.isMe ? 4 : 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.38,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(msg.timestamp),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1320),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message @${widget.thread.username}...',
                        filled: true,
                        fillColor: const Color(0xFF172033),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: const Color(0xFF6366F1),
                    child: IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
