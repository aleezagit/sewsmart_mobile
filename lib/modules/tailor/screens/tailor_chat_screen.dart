import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/shared_widgets.dart';

// The chat for one order. Customers and tailors both open this screen, so a
// message counts as "mine" when it comes from the signed-in user's side.
class TailorChatScreen extends StatefulWidget {
  // The other person in the chat: the tailor for a customer, the customer for a tailor.
  final String contactName;
  final String orderId;
  const TailorChatScreen({
    super.key,
    required this.contactName,
    required this.orderId,
  });

  @override
  State<TailorChatScreen> createState() => _TailorChatScreenState();
}

class _TailorChatScreenState extends State<TailorChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<MessageModel> _messages = [];
  bool _loading = true;
  Object? _loadError;
  bool _sending = false;
  Timer? _poll;

  final UserModel? _me = AuthService().currentUser;
  bool _isMine(MessageModel m) => m.senderId == _me?.id;

  @override
  void initState() {
    super.initState();
    _load(scroll: true);
    // New messages are asked for every few seconds until the API sends live
    // updates (docs/API.md, section 5).
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool scroll = false}) async {
    final service = ChatService();
    try {
      final messages = await service.getMessages(widget.orderId);
      if (!mounted) return;
      final grew = messages.length != _messages.length;
      setState(() { _messages = messages; _loading = false; _loadError = null; });
      if (messages.any((m) => !m.isRead && m.receiverId == _me?.id)) {
        await service.markMessagesRead(widget.orderId);
      }
      if (scroll || grew) _scrollToEnd();
    } catch (e) {
      // A failed refresh keeps the messages already shown.
      if (mounted && _loading) setState(() { _loading = false; _loadError = e; });
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await ChatService().sendMessage(widget.orderId, text);
      if (!mounted) return;
      setState(() {
        _messages.add(message);
        _msgCtrl.clear();
      });
      _scrollToEnd();
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.tealOrb,
        orb2: AppColors.purpleOrb,
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildMessageList()),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
            ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.teal]),
            ),
            child: Center(
              child: Text(
                initialsOf(widget.contactName, max: 1),
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Order: ${widget.orderId}',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.tealLight, strokeWidth: 2));
    }
    if (_loadError != null) {
      return LoadError(error: _loadError!, onRetry: () {
        setState(() => _loading = true);
        _load(scroll: true);
      });
    }
    if (_messages.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        subtitle: 'Say hello to ${widget.contactName} about order ${widget.orderId}',
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(
        message: _messages[i],
        isMe: _isMine(_messages[i]),
        initial: _isMine(_messages[i])
            ? initialsOf(_me?.name ?? '', max: 1)
            : initialsOf(widget.contactName, max: 1),
        timeStr: _formatTime(_messages[i].time),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => showComingSoon(context, 'Sending photos in chat'),
            child: Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Icon(Icons.attach_file_rounded, color: AppColors.textMuted, size: 18),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.divider),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.poppins(color: AppColors.textPrimary, fontSize: 13),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  // The avatar letter of whoever sent this message.
  final String initial;
  final String timeStr;
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.initial,
    required this.timeStr,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.teal]),
              ),
              child: Center(
                child: Text(initial, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.70,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? LinearGradient(colors: [AppColors.teal, AppColors.tealLight])
                        : null,
                    color: isMe ? null : AppColors.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.poppins(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timeStr,
                  style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
              ),
              child: Center(
                child: Text(initial, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
