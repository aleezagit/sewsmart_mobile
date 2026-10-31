// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/payout_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../services/tailor_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
class TailorLiveScreen extends StatefulWidget {
  const TailorLiveScreen({super.key});
  @override
  State<TailorLiveScreen> createState() => _TailorLiveScreenState();
}

enum _Phase { setup, live, ended }

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────
class _TailorLiveScreenState extends State<TailorLiveScreen>
    with TickerProviderStateMixin {

  // ── Phase ─────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.setup;

  // ── Setup form ─────────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  String _category  = 'Bridal Work';
  bool   _giftsOn   = true;
  bool   _frontCam  = true;

  // ── Live stats ─────────────────────────────────────────────────────────────
  int    _viewers    = 0;
  int    _peakView   = 0;
  int    _likes      = 0;
  double _earnings   = 0;
  int    _durSec     = 0;
  bool   _muted      = false;

  // ── Chat ──────────────────────────────────────────────────────────────────
  final List<_Msg> _msgs = [];
  final _chatScroll = ScrollController();

  // ── Gift overlay ──────────────────────────────────────────────────────────
  final List<_GiftPop> _pops = [];
  // How many of each gift arrived during the stream, by gift name.
  final Map<String, int> _giftCounts = {};

  // ── Server state ──────────────────────────────────────────────────────────
  LiveStream? _stream;
  bool _starting = false;
  // The tailor's price list, for pinning an item viewers can order.
  List<GarmentPricing> _garments = [];

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _clockTmr, _pollTmr;

  // ── Animations ────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  static const _kCats = [
    'Bridal Work', 'Stitching Tutorial', 'Design Showcase', 'Q&A Session',
  ];
  static const _kGifts = <_Gift>[
    _Gift('⭐', 'Star',    10,  DarkColors.gold),
    _Gift('🌹', 'Rose',   50,  DarkColors.error),
    _Gift('💎', 'Diamond',100, DarkColors.info),
    _Gift('👑', 'Crown',  500, DarkColors.secondary),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadGarments();
  }

  // Without the price list, the pin sheet says there is nothing to pin.
  Future<void> _loadGarments() async {
    try {
      final garments = await TailorService().getGarments(AuthService().currentUser?.id ?? '');
      if (mounted) setState(() => _garments = garments);
    } catch (_) {}
  }

  String get _initial => initialsOf(AuthService().currentUser?.name ?? '', max: 1);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _chatScroll.dispose();
    _clockTmr?.cancel();
    _pollTmr?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Duration string ───────────────────────────────────────────────────────
  String get _dur {
    final m = _durSec ~/ 60, s = _durSec % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  // ── Start stream ──────────────────────────────────────────────────────────
  Future<void> _startStream() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showMessage(context, 'Please add a stream title', success: false);
      return;
    }
    if (_starting) return;
    setState(() => _starting = true);
    final LiveStream stream;
    try {
      stream = await TailorService().startStream(
        title: _titleCtrl.text, category: _category, giftsEnabled: _giftsOn,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      showError(context, e);
      return;
    }
    if (!mounted) return;
    setState(() {
      _starting = false;
      _phase = _Phase.live;
      _msgs.clear(); _pops.clear();
      _apply(stream);
    });

    // The clock moves every second. The numbers, the chat and new gifts are
    // asked for every few seconds until the API sends live updates
    // (docs/API.md, section 5).
    _clockTmr = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durSec = DateTime.now().difference(_stream!.startedAt).inSeconds);
    });
    _pollTmr = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  // Takes the numbers of [stream] and shows a pop for each gift that arrived
  // since the last look.
  void _apply(LiveStream stream) {
    for (final gift in stream.gifts) {
      final before = _giftCounts[gift.name] ?? 0;
      final kind = _kGifts.where((g) => g.name == gift.name).firstOrNull;
      for (var n = before; n < gift.count && kind != null; n++) {
        _pops.add(_GiftPop('A viewer', kind));
        if (_pops.length > 3) _pops.removeAt(0);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() { if (_pops.isNotEmpty) _pops.removeAt(0); });
        });
      }
      _giftCounts[gift.name] = gift.count;
    }
    _stream = stream;
    _viewers = stream.viewers;
    _peakView = stream.peakViewers;
    _likes = stream.likes;
    _earnings = stream.earnings;
    _durSec = stream.durationSeconds;
  }

  Future<void> _refresh() async {
    final stream = _stream;
    if (stream == null) return;
    final service = TailorService();
    try {
      final results = await Future.wait([service.getStream(stream.id), service.getStreamMessages(stream.id)]);
      if (!mounted || _phase != _Phase.live) return;
      final atEnd = !_chatScroll.hasClients || _chatScroll.position.extentAfter < 40;
      setState(() {
        _apply(results[0] as LiveStream);
        _msgs
          ..clear()
          ..addAll((results[1] as List<LiveMessage>).map((m) => _Msg(m.viewerName, m.text)));
      });
      if (atEnd) {
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
    } catch (_) {
      // The next round tries again.
    }
  }

  // ── End stream ────────────────────────────────────────────────────────────
  Future<void> _endStream() async {
    final stream = _stream;
    if (stream == null) return;
    try {
      final ended = await TailorService().endStream(stream.id);
      _clockTmr?.cancel(); _pollTmr?.cancel();
      if (mounted) setState(() { _apply(ended); _pops.clear(); _phase = _Phase.ended; });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _resetToSetup() {
    setState(() {
      _phase = _Phase.setup;
      _stream = null;
      _viewers = 0; _peakView = 0; _likes = 0;
      _earnings = 0; _durSec = 0; _muted = false;
      _msgs.clear(); _pops.clear(); _giftCounts.clear();
      _titleCtrl.clear();
    });
  }

  // Gift earnings join the available balance when the stream ends. Payouts
  // have a minimum, as the payout screen explains.
  Future<void> _withdraw() async {
    if (_earnings < PayoutService.minimumWithdrawal) {
      showMessage(
        context,
        'The minimum withdrawal is Rs ${PayoutService.minimumWithdrawal.toInt()}. These earnings stay in your balance.',
        success: false,
      );
      return;
    }
    try {
      final withdrawal = await PayoutService().requestWithdrawal(amount: _earnings);
      if (mounted) showMessage(context, 'Rs ${withdrawal.amount.toInt()} withdrawal requested. Payouts are sent on Mondays.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pin(GarmentPricing item) async {
    final stream = _stream;
    if (stream == null) return;
    try {
      final updated = await TailorService().pinStreamItem(stream.id, item.id);
      if (!mounted) return;
      setState(() => _stream = updated);
      showMessage(context, '${item.garment} pinned for viewers!');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // While live, the back button asks before ending the stream instead of
    // closing the screen and dropping the viewers.
    // The live studio keeps the dark look while the light theme is on too.
    return AlwaysDark(
      child: PopScope(
        canPop: _phase != _Phase.live,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmEnd();
        },
        child: switch (_phase) {
          _Phase.setup => _buildSetup(),
          _Phase.live => _buildLive(),
          _Phase.ended => _buildSummary(),
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1 ── SETUP SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSetup() {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      body: AuroraBackground(
        // The live studio keeps the dark look in the light theme too.
        alwaysDark: true,
        orb1: DarkColors.tealOrb,
        orb2: DarkColors.purpleOrb,
        orb3: DarkColors.orangeOrb,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 6),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_rounded,
                          color: DarkColors.textPrimary, size: 20),
                    ),
                    const SizedBox(width: 4),
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Live Stream', style: GoogleFonts.poppins(
                          color: DarkColors.textPrimary,
                          fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('Go live & earn passive income',
                          style: GoogleFonts.poppins(
                              color: DarkColors.textMuted, fontSize: 11)),
                    ]),
                  ]),
                ),

                // ── Camera preview ───────────────────────────────────────────
                Container(
                  height: 196,
                  decoration: BoxDecoration(
                    color: DarkColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: DarkColors.divider),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    // Animated glow ring
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (ctx, child) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 98, height: 98,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: DarkColors.tealLight.withValues(alpha: 0.35),
                                width: 2),
                          ),
                        ),
                      ),
                    ),
                    // Avatar circle
                    Container(
                      width: 72, height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [DarkColors.teal, DarkColors.tealLight]),
                      ),
                      child: Center(
                        child: Text(_initial,
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 38)),
                      ),
                    ),
                    // PREVIEW badge
                    Positioned(top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: DarkColors.error,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('PREVIEW', style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                      ),
                    ),
                    // Flip camera
                    Positioned(top: 8, right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _frontCam = !_frontCam),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.flip_camera_ios_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    // Camera label
                    Positioned(bottom: 10,
                      child: Text(
                        _frontCam ? '📷 Front Camera' : '📷 Back Camera',
                        style: GoogleFonts.poppins(
                            color: DarkColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),

                // ── Title ────────────────────────────────────────────────────
                Text('Stream Title', style: GoogleFonts.poppins(
                    color: DarkColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: DarkColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DarkColors.divider),
                  ),
                  child: TextField(
                    controller: _titleCtrl,
                    style: GoogleFonts.poppins(
                        color: DarkColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. "Bridal Lehenga Live Stitching Session"',
                      hintStyle: GoogleFonts.poppins(
                          color: DarkColors.textMuted, fontSize: 12),
                      prefixIcon: const Icon(Icons.title_rounded,
                          color: DarkColors.tealLight, size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Category ─────────────────────────────────────────────────
                Text('Category', style: GoogleFonts.poppins(
                    color: DarkColors.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _kCats.map((cat) {
                    final sel = _category == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? DarkColors.teal.withValues(alpha: 0.18)
                              : DarkColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? DarkColors.tealLight
                                : DarkColors.divider,
                          ),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.poppins(
                                color: sel
                                    ? DarkColors.tealLight
                                    : DarkColors.textSecondary,
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // ── Gifts toggle ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DarkColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DarkColors.divider),
                  ),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: DarkColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.card_giftcard_rounded,
                          color: DarkColors.gold, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable Gifts & Tips',
                            style: GoogleFonts.poppins(
                                color: DarkColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text('Earn from viewer gifts and donations',
                            style: GoogleFonts.poppins(
                                color: DarkColors.textMuted, fontSize: 11)),
                      ],
                    )),
                    Switch(
                      value: _giftsOn,
                      onChanged: (v) => setState(() => _giftsOn = v),
                      activeTrackColor: DarkColors.teal.withValues(alpha: 0.5),
                      activeColor: DarkColors.tealLight, // ignore: deprecated_member_use
                    ),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Gift types ───────────────────────────────────────────────
                if (_giftsOn) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DarkColors.gold.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: DarkColors.gold.withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.monetization_on_rounded,
                              color: DarkColors.gold, size: 14),
                          const SizedBox(width: 6),
                          Text('Viewer Gift Types',
                              style: GoogleFonts.poppins(
                                  color: DarkColors.gold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ]),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceEvenly,
                          children: _kGifts.map((g) => Column(children: [
                            Text(g.emoji,
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(g.name,
                                style: GoogleFonts.poppins(
                                    color: g.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            Text('Rs ${g.amount}',
                                style: GoogleFonts.poppins(
                                    color: DarkColors.textMuted,
                                    fontSize: 10)),
                          ])).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Tips ─────────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DarkColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: DarkColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.tips_and_updates_rounded,
                            color: DarkColors.primaryLight, size: 14),
                        const SizedBox(width: 6),
                        Text('Tips to Maximise Earnings',
                            style: GoogleFonts.poppins(
                                color: DarkColors.primaryLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ]),
                      const SizedBox(height: 8),
                      ...[
                        'Go live between 6 PM – 10 PM (peak hours)',
                        'Show work-in-progress for higher engagement',
                        'Reply to comments — it attracts more gifts',
                        'Announce your stream on your profile first',
                        'Pin your best design to drive direct orders',
                      ].map((t) => Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded,
                              color: DarkColors.success, size: 12),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(t,
                                style: GoogleFonts.poppins(
                                    color: DarkColors.textSecondary,
                                    fontSize: 11)),
                          ),
                        ]),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // ── GO LIVE button ───────────────────────────────────────────
                GestureDetector(
                  onTap: _startStream,
                  child: Container(
                    width: double.infinity, height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFF87171)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: DarkColors.error.withValues(alpha: 0.45),
                          blurRadius: 18, offset: const Offset(0, 7)),
                      ],
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Text(_starting ? 'STARTING...' : 'GO LIVE',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.4)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2 ── LIVE SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLive() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [

        // ── Dark camera bg ────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF04010F), Color(0xFF080318), Color(0xFF040210)],
            ),
          ),
        ),

        // ── Animated radial glow ──────────────────────────────────────────
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (ctx, child) => Opacity(
            opacity: 0.05 + _pulseAnim.value * 0.06,
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
        ),

        // ── Tailor avatar (centre) ────────────────────────────────────────
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: 0.96 + _pulseAnim.value * 0.04, child: child),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Live ring
              Container(
                width: 114, height: 114,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: DarkColors.error.withValues(alpha: 0.65),
                      width: 2.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [DarkColors.teal, DarkColors.tealLight]),
                    ),
                    child: Center(
                      child: Text(_initial,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 44)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_titleCtrl.text,
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12)),
              ),
            ]),
          ),
        ),

        // ── TOP BAR ──────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              // LIVE
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: DarkColors.error,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('LIVE',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 7),
              // Viewers
              _TopChip(Icons.remove_red_eye_rounded, '$_viewers'),
              const SizedBox(width: 7),
              // Timer
              _TopChip(Icons.timer_rounded, _dur),
              const Spacer(),
              // Earnings
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: DarkColors.success.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.payments_rounded,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  Text('Rs ${_earnings.toInt()}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ]),
              ),
            ]),
          ),
        ),

        // ── RIGHT SIDE ACTIONS ────────────────────────────────────────────
        SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _SideBtn(
                  icon: Icons.favorite_rounded,
                  color: DarkColors.error,
                  label: _likes > 999
                      ? '${(_likes / 1000).toStringAsFixed(1)}k'
                      : '$_likes',
                ),
                const SizedBox(height: 16),
                _SideBtn(
                  icon: Icons.card_giftcard_rounded,
                  color: DarkColors.gold,
                  label: 'Gift',
                ),
                const SizedBox(height: 16),
                _SideBtn(
                  icon: Icons.share_rounded,
                  color: DarkColors.info,
                  label: 'Share',
                ),
              ]),
            ),
          ),
        ),

        // ── GIFT POP-UPS ──────────────────────────────────────────────────
        SafeArea(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 50),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _pops.map((p) => _GiftBubble(pop: p)).toList(),
              ),
            ),
          ),
        ),

        // ── BOTTOM: Chat + Controls ───────────────────────────────────────
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Chat
              SizedBox(
                height: 170,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 68),
                  child: ListView.builder(
                    controller: _chatScroll,
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) {
                      final m = _msgs[i];
                      final colors = [
                        DarkColors.tealLight, DarkColors.primaryLight,
                        DarkColors.gold, DarkColors.error, DarkColors.info,
                      ];
                      final c = colors[m.viewer.length % colors.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: '${m.viewer}  ',
                              style: GoogleFonts.poppins(
                                  color: c,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12),
                            ),
                            TextSpan(
                              text: m.text,
                              style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Controls bar
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute
                    GestureDetector(
                      onTap: () => setState(() => _muted = !_muted),
                      child: _CtrlBtn(
                        icon: _muted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: _muted ? 'Muted' : 'Mic',
                        color: _muted ? DarkColors.error : Colors.white70,
                      ),
                    ),
                    // Flip
                    GestureDetector(
                      onTap: () =>
                          setState(() => _frontCam = !_frontCam),
                      child: const _CtrlBtn(
                          icon: Icons.flip_camera_ios_rounded,
                          label: 'Flip',
                          color: Colors.white70),
                    ),
                    // Showcase
                    GestureDetector(
                      onTap: () => _showShowcase(),
                      child: const _CtrlBtn(
                          icon: Icons.checkroom_rounded,
                          label: 'Showcase',
                          color: DarkColors.tealLight),
                    ),
                    // End live
                    GestureDetector(
                      onTap: _confirmEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                            color: DarkColors.error,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.stop_circle_rounded,
                              color: Colors.white, size: 15),
                          const SizedBox(width: 5),
                          Text('End',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),

      ]),
    );
  }

  // ── Showcase bottom sheet ────────────────────────────────────────────────
  void _showShowcase() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DarkColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (shCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: DarkColors.divider,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('Pin a Design to Showcase',
                style: GoogleFonts.poppins(
                    color: DarkColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Text('Viewers can tap to order directly from the stream',
                style: GoogleFonts.poppins(
                    color: DarkColors.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            if (_garments.isEmpty)
              Text('Add items to your price list on your profile to pin them here.',
                  style: GoogleFonts.poppins(color: DarkColors.textMuted, fontSize: 12)),
            ..._garments.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: DarkColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.id == _stream?.pinnedGarmentId ? Icons.push_pin_rounded : Icons.checkroom_rounded,
                  color: DarkColors.tealLight, size: 20),
              ),
              title: Text(item.garment,
                  style: GoogleFonts.poppins(
                      color: DarkColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              subtitle: Text('Rs ${item.price.toInt()}',
                  style: GoogleFonts.poppins(
                      color: DarkColors.success, fontSize: 12)),
              trailing: GestureDetector(
                onTap: () {
                  Navigator.pop(shCtx);
                  _pin(item);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: DarkColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: DarkColors.tealLight.withValues(alpha: 0.3)),
                  ),
                  child: Text('Pin',
                      style: GoogleFonts.poppins(
                          color: DarkColors.tealLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ── Confirm end dialog ───────────────────────────────────────────────────
  void _confirmEnd() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: DarkColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('End Live Stream?',
            style: GoogleFonts.poppins(
                color: DarkColors.textPrimary,
                fontWeight: FontWeight.bold)),
        content: Text(
          "You've earned Rs ${_earnings.toInt()} so far.\n"
          "Are you sure you want to end?",
          style: GoogleFonts.poppins(
              color: DarkColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Keep Streaming',
                style: GoogleFonts.poppins(color: DarkColors.tealLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dCtx);
              _endStream();
            },
            child: Text('End Stream',
                style: GoogleFonts.poppins(
                    color: DarkColors.error,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3 ── SUMMARY SCREEN
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildSummary() {
    return Scaffold(
      backgroundColor: DarkColors.bg,
      body: AuroraBackground(
        // The live studio keeps the dark look in the light theme too.
        alwaysDark: true,
        orb1: DarkColors.tealOrb,
        orb2: DarkColors.orangeOrb,
        orb3: DarkColors.purpleOrb,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            child: Column(
              children: [

                // ── Trophy ──────────────────────────────────────────────────
                Container(
                  width: 92, height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [DarkColors.gold, DarkColors.warning]),
                    boxShadow: [BoxShadow(
                        color: DarkColors.gold.withValues(alpha: 0.45),
                        blurRadius: 24)],
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 50),
                ),
                const SizedBox(height: 16),
                Text('Stream Ended!',
                    style: GoogleFonts.poppins(
                        color: DarkColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22)),
                Text('Great session — here\'s your summary',
                    style: GoogleFonts.poppins(
                        color: DarkColors.textMuted, fontSize: 12)),
                const SizedBox(height: 24),

                // ── Earnings card ────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      DarkColors.success.withValues(alpha: 0.18),
                      DarkColors.success.withValues(alpha: 0.07),
                    ]),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: DarkColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Column(children: [
                    Text('Total Earnings',
                        style: GoogleFonts.poppins(
                            color: DarkColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('Rs ${_earnings.toInt()}',
                        style: GoogleFonts.poppins(
                            color: DarkColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 38)),
                    Text('from gifts, tips & stream bonuses',
                        style: GoogleFonts.poppins(
                            color: DarkColors.textMuted, fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Stats grid ────────────────────────────────────────────────
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _StatCard('Peak Viewers', '$_peakView',
                        Icons.remove_red_eye_rounded, DarkColors.info),
                    _StatCard('Total Likes', '$_likes',
                        Icons.favorite_rounded, DarkColors.error),
                    _StatCard('Duration', _dur,
                        Icons.timer_rounded, DarkColors.primary),
                    _StatCard('Category', _category.split(' ').first,
                        Icons.category_rounded, DarkColors.teal),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Gift breakdown ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DarkColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DarkColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.card_giftcard_rounded,
                            color: DarkColors.gold, size: 15),
                        const SizedBox(width: 7),
                        Text('Gifts Received',
                            style: GoogleFonts.poppins(
                                color: DarkColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ]),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _kGifts.map((g) {
                          final cnt = _giftCounts[g.name] ?? 0;
                          return Column(children: [
                            Text(g.emoji,
                                style: const TextStyle(fontSize: 26)),
                            const SizedBox(height: 4),
                            Text('×$cnt',
                                style: GoogleFonts.poppins(
                                    color: g.color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text('Rs ${g.amount}',
                                style: GoogleFonts.poppins(
                                    color: DarkColors.textMuted,
                                    fontSize: 10)),
                          ]);
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),

                // ── Withdraw button ───────────────────────────────────────────
                GestureDetector(
                  onTap: _withdraw,
                  child: Container(
                    width: double.infinity, height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [DarkColors.success, Color(0xFF16A34A)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: DarkColors.success.withValues(alpha: 0.38),
                          blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text('Withdraw Rs ${_earnings.toInt()}',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Go live again ─────────────────────────────────────────────
                GestureDetector(
                  onTap: _resetToSetup,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: DarkColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: DarkColors.divider),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.replay_rounded,
                          color: DarkColors.tealLight, size: 18),
                      const SizedBox(width: 8),
                      Text('Go Live Again',
                          style: GoogleFonts.poppins(
                              color: DarkColors.tealLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Back to dashboard ─────────────────────────────────────────
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: DarkColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: DarkColors.divider),
                    ),
                    child: Center(
                      child: Text('Back to Dashboard',
                          style: GoogleFonts.poppins(
                              color: DarkColors.textSecondary,
                              fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TopChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TopChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
        color: Colors.black54, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 13),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _SideBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SideBtn({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, color: color, size: 22),
    ),
    const SizedBox(height: 4),
    Text(label, style: GoogleFonts.poppins(
        color: Colors.white70, fontSize: 10)),
  ]);
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CtrlBtn({required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 3),
      Text(label, style: GoogleFonts.poppins(color: color, fontSize: 10)),
    ],
  );
}

class _GiftBubble extends StatelessWidget {
  final _GiftPop pop;
  const _GiftBubble({required this.pop});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: pop.gift.color.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(pop.gift.emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 5),
      Text('${pop.viewer} sent ${pop.gift.name}!',
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: DarkColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: DarkColors.divider),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const Spacer(),
      Text(value,
          style: GoogleFonts.poppins(
              color: DarkColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18)),
      Text(label,
          style: GoogleFonts.poppins(
              color: DarkColors.textMuted, fontSize: 10)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _Msg {
  final String viewer, text;
  const _Msg(this.viewer, this.text);
}

class _GiftPop {
  final String viewer;
  final _Gift gift;
  const _GiftPop(this.viewer, this.gift);
}

class _Gift {
  final String emoji, name;
  final int amount;
  final Color color;
  const _Gift(this.emoji, this.name, this.amount, this.color);
}


