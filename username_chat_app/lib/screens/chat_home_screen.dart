import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/firebase_service.dart';
import 'chat_room_screen.dart';
import 'username_login_screen.dart';

class ChatHomeScreen extends StatefulWidget {
  final String currentUsername;
  final String currentDisplayName;

  const ChatHomeScreen({
    super.key,
    required this.currentUsername,
    required this.currentDisplayName,
  });

  @override
  State<ChatHomeScreen> createState() => _ChatHomeScreenState();
}

class _ChatHomeScreenState extends State<ChatHomeScreen> {
  final _searchController = TextEditingController();
  late List<ChatThread> _threads;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _threads = List<ChatThread>.from(initialSampleThreads);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }

  void _openChatWithHandle(String rawHandle) {
    final handle = rawHandle.trim().toLowerCase().replaceAll('@', '');
    if (handle.isEmpty) return;

    final existingIndex = _threads.indexWhere((t) => t.username == handle);
    ChatThread target;

    if (existingIndex != -1) {
      target = _threads[existingIndex];
    } else {
      target = ChatThread(
        username: handle,
        displayName: handle,
        bio: 'Connected via @username',
        isOnline: true,
        avatarColorHex: '8B5CF6',
        messages: [],
      );
      setState(() {
        _threads.insert(0, target);
      });
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              currentUsername: widget.currentUsername,
              thread: target,
            ),
          ),
        )
        .then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _threads.where((t) {
      final q = _query.toLowerCase().replaceAll('@', '');
      if (q.isEmpty) return true;
      return t.username.toLowerCase().contains(q) ||
          t.displayName.toLowerCase().contains(q);
    }).toList();

    final cleanQuery = _query.trim().toLowerCase().replaceAll('@', '');
    final showDirectStart = cleanQuery.isNotEmpty &&
        !_threads.any((t) => t.username.toLowerCase() == cleanQuery);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'VibeHandle',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FirebaseChatService.isInitialized
                        ? const Color(0xFF10B981).withValues(alpha: 0.16)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    FirebaseChatService.isInitialized ? 'Firebase Ready' : 'UI Demo',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: FirebaseChatService.isInitialized
                          ? const Color(0xFF34D399)
                          : const Color(0xFFFBBF24),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Signed in as @${widget.currentUsername}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF818CF8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Change @username',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const UsernameLoginScreen()),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _query = val),
              onSubmitted: _openChatWithHandle,
              decoration: InputDecoration(
                hintText: 'Search or enter @username to chat...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF818CF8)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF151C2C),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                ),
              ),
            ),
          ),
          if (showDirectStart)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openChatWithHandle(cleanQuery),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFF6366F1),
                        child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start chat with @$cleanQuery',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              'Tap to open direct message thread',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final thread = filtered[index];
                final accent = _parseColor(thread.avatarColorHex);
                final last = thread.lastMessage;

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              currentUsername: widget.currentUsername,
                              thread: thread,
                            ),
                          ),
                        )
                        .then((_) => setState(() {}));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A29),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: accent.withValues(alpha: 0.22),
                              child: Text(
                                thread.displayName[0].toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (thread.isOnline)
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF131A29),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    thread.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '@${thread.username}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                last?.text ?? thread.bio,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Colors.white38,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
