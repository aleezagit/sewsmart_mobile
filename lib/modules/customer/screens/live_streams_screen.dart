import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../services/customer_service.dart';
import 'live_viewer_screen.dart';

// Tailors who are live right now. Tapping one opens the stream.
class LiveStreamsScreen extends StatefulWidget {
  const LiveStreamsScreen({super.key});

  @override
  State<LiveStreamsScreen> createState() => _LiveStreamsScreenState();
}

class _LiveStreamsScreenState extends State<LiveStreamsScreen> {
  List<LiveStream> _streams = [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final streams = await CustomerService().getLiveStreams();
      if (mounted) setState(() { _streams = streams; _loading = false; _loadError = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  Future<void> _open(LiveStream stream) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveViewerScreen(stream: stream)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.pinkOrb,
        orb2: AppColors.purpleOrb,
        child: SafeArea(
          child: Column(
            children: [
              const SewAppBar(title: 'Live Now', subtitle: 'Watch tailors stitch and show their designs'),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2),
                      )
                    : _loadError != null
                    ? LoadError(error: _loadError!, onRetry: () {
                        setState(() => _loading = true);
                        _load();
                      })
                    : RefreshIndicator(
                        color: AppColors.primaryLight,
                        backgroundColor: AppColors.card,
                        onRefresh: _load,
                        child: _streams.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 120),
                                  EmptyState(
                                    icon: Icons.live_tv_rounded,
                                    title: 'No one is live right now',
                                    subtitle: 'Pull down to check again',
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                itemCount: _streams.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 14),
                                itemBuilder: (_, i) => LiveStreamCard(
                                  stream: _streams[i],
                                  onTap: () => _open(_streams[i]),
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// One live stream: a dark preview with the tailor's initial, the LIVE badge
// and the viewer count, then the title and the tailor. [compact] is the
// smaller card in the home screen's row.
class LiveStreamCard extends StatelessWidget {
  final LiveStream stream;
  final VoidCallback onTap;
  final bool compact;
  const LiveStreamCard({super.key, required this.stream, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final name = stream.tailorName.isEmpty ? 'Tailor' : stream.tailorName;
    final minutes = DateTime.now().difference(stream.startedAt).inMinutes;
    final avatar = compact ? 46.0 : 64.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: compact ? 230 : double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: compact ? 96 : 150,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A0B2E), Color(0xFF0B1A2A)],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: avatar,
                      height: avatar,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.7), width: 2),
                        gradient: LinearGradient(colors: [AppColors.teal, AppColors.tealLight]),
                      ),
                      child: Center(
                        child: Text(
                          initialsOf(name, max: 1),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: compact ? 18 : 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(top: 10, left: 10, child: LiveBadge()),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _OverlayChip(icon: Icons.remove_red_eye_rounded, text: compactCount(stream.viewers)),
                  ),
                  if (!compact)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: _OverlayChip(icon: Icons.timer_outlined, text: 'Live for $minutes min'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, compact ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stream.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 12 : 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$name · ${stream.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The red LIVE label used on stream cards and on the viewer screen.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              'LIVE',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
      );
}

class _OverlayChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _OverlayChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 12),
            const SizedBox(width: 4),
            Text(text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// 1240 as "1.2k", for viewer and like counts.
String compactCount(int value) {
  if (value < 1000) return '$value';
  final thousands = value / 1000;
  return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}k';
}
