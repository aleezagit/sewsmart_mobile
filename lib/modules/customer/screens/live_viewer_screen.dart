import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/live_video.dart';
import '../../support/screens/report_content_sheet.dart';
import '../services/customer_service.dart';
import 'live_streams_screen.dart';
import 'place_order_screen.dart';

// A customer watching a tailor's live stream: chat, likes, gifts and the
// garment the tailor pinned. The tailor's video comes through LiveKit; their
// avatar shows until it arrives.
class LiveViewerScreen extends StatefulWidget {
  final LiveStream stream;
  const LiveViewerScreen({super.key, required this.stream});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> with SingleTickerProviderStateMixin {
  static const _gifts = <_Gift>[
    _Gift('⭐', 'Star', 10, DarkColors.gold),
    _Gift('🌹', 'Rose', 50, DarkColors.error),
    _Gift('💎', 'Diamond', 100, DarkColors.info),
    _Gift('👑', 'Crown', 500, DarkColors.secondary),
  ];
  static const _nameColors = [
    DarkColors.tealLight,
    DarkColors.primaryLight,
    DarkColors.info,
    DarkColors.success,
    Color(0xFFF472B6),
  ];
  late LiveStream _stream = widget.stream;
  late int _viewers = widget.stream.viewers;
  late int _likes = widget.stream.likes;
  final List<_ChatLine> _chat = [];
  // The gifts this viewer sent, shown in the chat.
  final List<_ChatLine> _giftLines = [];
  List<GarmentPricing> _garments = [];
  final List<_Gift> _giftPops = [];
  final List<int> _hearts = [];
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  GarmentPricing? _pinned;
  TailorModel? _tailor;
  bool _joined = false;
  final LiveVideo _video = LiveVideo();
  bool _ended = false;
  bool _sendingGift = false;
  int _nextHeart = 0;
  Timer? _clock, _poll;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  String get _tailorName {
    if (_stream.tailorName.isNotEmpty) return _stream.tailorName;
    return _tailor?.name ?? 'Tailor';
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _ended = widget.stream.status != 'live';
    _join();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _poll?.cancel();
    _pulseCtrl.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _video.close();
    if (_joined) CustomerService().leaveStream(_stream.id).catchError((_) {});
    super.dispose();
  }

  Future<void> _join() async {
    final service = CustomerService();
    try {
      final joined = await service.joinStream(widget.stream.id);
      final results = await Future.wait([
        service.getStreamMessages(joined.id),
        service.getTailorGarments(joined.tailorId),
        service.getTailorById(joined.tailorId),
      ]);
      if (!mounted) return;
      final garments = results[1] as List<GarmentPricing>;
      setState(() {
        _joined = true;
        _garments = garments;
        _tailor = results[2] as TailorModel;
        _apply(joined, results[0] as List<LiveMessage>);
      });
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    if (_stream.status != 'live') {
      _endLocally();
    } else {
      _startTimers();
      _watch();
    }
    _scrollChatToEnd();
  }

  // Connects to the tailor's video. The chat and gifts work without it.
  Future<void> _watch() async {
    try {
      await _video.watch(_stream.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // Takes the stream's numbers and chat from the server. The gifts this viewer
  // sent stay in the chat between the server's lines.
  void _apply(LiveStream stream, List<LiveMessage> messages) {
    final me = AuthService().currentUser?.name;
    _stream = stream;
    _viewers = stream.viewers;
    _likes = stream.likes;
    _pinned = _garments.where((g) => g.id == stream.pinnedGarmentId).firstOrNull;
    final lines = [
      ...messages.map((m) => _ChatLine(m.viewerName, m.text, m.createdAt, mine: m.viewerName == me)),
      ..._giftLines,
    ]..sort((a, b) => a.at.compareTo(b.at));
    _chat
      ..clear()
      ..addAll(lines.length > 60 ? lines.sublist(lines.length - 60) : lines);
  }

  // The clock moves every second. The numbers and the chat are asked for
  // again every few seconds until the API sends live updates (docs/API.md, section 5).
  void _startTimers() {
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final service = CustomerService();
    try {
      final results = await Future.wait([service.getStream(_stream.id), service.getStreamMessages(_stream.id)]);
      if (!mounted) return;
      final atEnd = !_chatScroll.hasClients || _chatScroll.position.extentAfter < 40;
      setState(() => _apply(results[0] as LiveStream, results[1] as List<LiveMessage>));
      if (_stream.status != 'live') _endLocally();
      if (atEnd) _scrollChatToEnd();
    } catch (_) {
      // The next round tries again.
    }
  }

  void _endLocally() {
    _clock?.cancel();
    _poll?.cancel();
    _video.close();
    if (mounted) setState(() => _ended = true);
  }

  String get _duration {
    final elapsed = DateTime.now().difference(_stream.startedAt);
    String two(int value) => value.toString().padLeft(2, '0');
    final minutes = two(elapsed.inMinutes % 60);
    final seconds = two(elapsed.inSeconds % 60);
    return elapsed.inHours > 0 ? '${elapsed.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }

  void _addChat(_ChatLine line) {
    setState(() {
      _chat.add(line);
      if (_chat.length > 60) _chat.removeAt(0);
    });
    _scrollChatToEnd();
  }

  void _scrollChatToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _ended) return;
    _chatCtrl.clear();
    try {
      final sent = await CustomerService().sendStreamMessage(_stream.id, text);
      if (mounted) _addChat(_ChatLine(sent.viewerName, sent.text, sent.createdAt, mine: true));
    } catch (e) {
      if (!mounted) return;
      _chatCtrl.text = text;
      showError(context, e);
    }
  }

  void _like() {
    if (_ended) return;
    final id = _nextHeart++;
    setState(() {
      _likes++;
      _hearts.add(id);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _hearts.remove(id));
    });
    CustomerService().likeStream(_stream.id).catchError((_) {});
  }

  void _openGifts() {
    if (_ended || _sendingGift) return;
    if (!_stream.giftsEnabled) {
      showMessage(context, '$_tailorName turned off gifts for this stream', success: false);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: DarkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: DarkColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send a Gift',
              style: GoogleFonts.poppins(color: DarkColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Gifts go to $_tailorName and are paid from your wallet.',
              style: GoogleFonts.poppins(color: DarkColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: _gifts
                  .map((gift) => Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(sheetCtx);
                            _confirmGift(gift);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: gift.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: gift.color.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                Text(gift.emoji, style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 4),
                                Text(
                                  gift.name,
                                  style: GoogleFonts.poppins(color: DarkColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                                Text(
                                  'Rs ${gift.amount}',
                                  style: GoogleFonts.poppins(color: gift.color, fontWeight: FontWeight.w600, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmGift(_Gift gift) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DarkColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Send a ${gift.name}?',
          style: GoogleFonts.poppins(color: DarkColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Rs ${gift.amount} will be taken from your wallet and sent to $_tailorName.',
          style: GoogleFonts.poppins(color: DarkColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: DarkColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Send Rs ${gift.amount}',
              style: GoogleFonts.poppins(color: DarkColors.primaryLight, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _sendingGift = true);
    try {
      await CustomerService().sendGift(_stream.id, gift.name);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingGift = false);
      showError(context, e);
      return;
    }
    if (!mounted) return;
    setState(() => _sendingGift = false);
    final line = _ChatLine('You', 'sent a ${gift.name} ${gift.emoji}', DateTime.now(), mine: true, gift: true);
    _giftLines.add(line);
    _addChat(line);
    setState(() => _giftPops.add(gift));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _giftPops.isNotEmpty) setState(() => _giftPops.removeAt(0));
    });
  }

  void _orderPinned(GarmentPricing item) {
    final tailor = _tailor;
    if (tailor == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlaceOrderScreen(tailor: tailor, initialGarment: item.garment)),
    );
  }

  void _report() {
    showReportContentSheet(
      context,
      targetType: 'profile',
      targetId: _stream.tailorId,
      itemLabel: '$_tailorName, live stream "${_stream.title}"',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _pinned;
    return AlwaysDark(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF04010F), Color(0xFF080318), Color(0xFF040210)],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Opacity(opacity: 0.05 + _pulse.value * 0.06, child: child),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.2, -0.4),
                    radius: 0.9,
                    colors: [DarkColors.teal, Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(child: _buildStage()),
            Positioned.fill(
              child: LiveVideoView(video: _video, placeholder: const SizedBox.shrink()),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
                child: _buildTopBar(),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLikeButton(),
                      const SizedBox(height: 16),
                      _SideAction(
                        icon: Icons.card_giftcard_rounded,
                        color: DarkColors.gold,
                        label: _sendingGift ? 'Sending' : 'Gift',
                        onTap: _openGifts,
                      ),
                      const SizedBox(height: 16),
                      _SideAction(
                        icon: Icons.share_rounded,
                        color: DarkColors.info,
                        label: 'Share',
                        onTap: () => showComingSoon(context, 'Sharing live streams'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _giftPops.map(_buildGiftBubble).toList(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pinned != null && !_ended) _buildPinned(pinned),
                    SizedBox(
                      height: 170,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 68),
                        child: ListView.builder(
                          controller: _chatScroll,
                          itemCount: _chat.length,
                          itemBuilder: (_, i) => _buildChatLine(_chat[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildInputBar(),
                  ],
                ),
              ),
            ),
            if (_ended) _buildEndedOverlay(),
          ],
        ),
      ),
    );
  }

  // The tailor's avatar, shown until their video arrives.
  Widget _buildStage() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(scale: 0.96 + _pulse.value * 0.04, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 114,
            height: 114,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: DarkColors.error.withValues(alpha: 0.65), width: 2.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [DarkColors.teal, DarkColors.tealLight]),
                ),
                child: Center(
                  child: Text(
                    initialsOf(_tailorName, max: 1),
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 44),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Text(
              _stream.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [DarkColors.teal, DarkColors.tealLight]),
              ),
              child: Center(
                child: Text(
                  initialsOf(_tailorName, max: 1),
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tailorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Text(
                    _stream.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _report,
              tooltip: 'Report',
              icon: const Icon(Icons.flag_outlined, color: Colors.white70, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LiveBadge(),
            const SizedBox(width: 7),
            _TopChip(icon: Icons.remove_red_eye_rounded, text: compactCount(_viewers)),
            const SizedBox(width: 7),
            _TopChip(icon: Icons.timer_rounded, text: _duration),
          ],
        ),
      ],
    );
  }

  Widget _buildLikeButton() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        _SideAction(
          icon: Icons.favorite_rounded,
          color: DarkColors.error,
          label: compactCount(_likes),
          onTap: _like,
        ),
        // Hearts float up from the button for every tap.
        ..._hearts.map((id) => Positioned(
              top: 0,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<int>(id),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  builder: (_, t, child) => Transform.translate(
                    offset: Offset((id % 3 - 1) * 12.0 * t, -110 * t),
                    child: Opacity(opacity: 1 - t, child: child),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: DarkColors.error, size: 26),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildGiftBubble(_Gift gift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: gift.color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'You sent a ${gift.name} ${gift.emoji}',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildPinned(GarmentPricing item) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 68, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DarkColors.tealLight.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: DarkColors.teal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.push_pin_rounded, color: DarkColors.tealLight, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pinned by $_tailorName', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10)),
                Text(
                  item.garment,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  'Rs ${item.price.toInt()} · ${item.estimatedTime}',
                  style: GoogleFonts.poppins(color: DarkColors.tealLight, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_tailor != null)
            GestureDetector(
              onTap: () => _orderPinned(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [DarkColors.teal, DarkColors.tealLight]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Order',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatLine(_ChatLine line) {
    final nameColor = line.mine ? DarkColors.gold : _nameColors[line.name.length % _nameColors.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${line.name}  ',
              style: GoogleFonts.poppins(color: nameColor, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            TextSpan(
              text: line.text,
              style: GoogleFonts.poppins(
                color: line.gift ? DarkColors.gold : Colors.white.withValues(alpha: 0.88),
                fontWeight: line.gift ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              enabled: !_ended,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: _ended ? 'Chat is closed' : 'Say something...',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send_rounded, color: DarkColors.primaryLight, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.live_tv_rounded, color: Colors.white54, size: 56),
                const SizedBox(height: 14),
                Text(
                  'This live stream has ended',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thanks for watching $_tailorName.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 24),
                GradientButton(text: 'Back', width: 180, onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _SideAction({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _TopChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TopChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Text(text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _ChatLine {
  final String name, text;
  final DateTime at;
  final bool mine, gift;
  const _ChatLine(this.name, this.text, this.at, {this.mine = false, this.gift = false});
}

class _Gift {
  final String emoji, name;
  final int amount;
  final Color color;
  const _Gift(this.emoji, this.name, this.amount, this.color);
}
