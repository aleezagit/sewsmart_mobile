// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/models/app_models.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/app_refresh.dart';
import '../services/customer_service.dart';
import 'browse_tailors_screen.dart';
import 'saved_designs_screen.dart';

class CustomerAiRecommendationsScreen extends StatefulWidget {
  const CustomerAiRecommendationsScreen({super.key});

  @override
  State<CustomerAiRecommendationsScreen> createState() =>
      _CustomerAiRecommendationsScreenState();
}

class _CustomerAiRecommendationsScreenState
    extends State<CustomerAiRecommendationsScreen> {

  // ── State ────────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<_DesignCard> _liveResults = [];
  Timer? _recordTimer;
  Timer? _lookupTimer;
  // Ids of the designs already in the wishlist, so the sheet can say so.
  final Set<String> _savedIds = {};

  // The customer's latest searches, each with designs similar to it.
  List<SearchEntry> _mySearches = [];
  final Map<String, List<_DesignCard>> _similar = {};
  List<TrendingSearch> _trending = [];
  List<_DesignCard> _youMayLike = [];
  bool _loading = true;
  Object? _loadError;

  // How many of the latest searches get their own row.
  static const _searchRows = 5;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _load();
  }

  Future<void> _load() async {
    final service = CustomerService();
    try {
      final results = await Future.wait([
        service.getMySearches(),
        service.getTrendingSearches(),
        service.getRecommendations(),
      ]);
      final searches = _latestUnique(results[0] as List<SearchEntry>);
      final similar = await Future.wait(
        searches.map((s) => service.getRecommendations(query: s.query, limit: 4)),
      );
      if (!mounted) return;
      setState(() {
        _mySearches = searches;
        _similar
          ..clear()
          ..addAll({
            for (var i = 0; i < searches.length; i++)
              searches[i].query: similar[i].map(_DesignCard.new).toList(),
          });
        _trending = results[1] as List<TrendingSearch>;
        _youMayLike = (results[2] as List<DesignModel>).map(_DesignCard.new).toList();
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = e; });
    }
  }

  // The newest search of each text, up to [_searchRows].
  List<SearchEntry> _latestUnique(List<SearchEntry> searches) {
    final seen = <String>{};
    return searches.where((s) => seen.add(s.query.toLowerCase())).take(_searchRows).toList();
  }

  // The wishlist only marks designs as saved, so a failed load is not shown.
  Future<void> _loadSaved() async {
    try {
      final saved = await CustomerService().getWishlist();
      if (!mounted) return;
      setState(() => _savedIds
        ..clear()
        ..addAll(saved.map((d) => d.id)));
    } catch (_) {}
  }

  Future<void> _saveDesign(_DesignCard card) async {
    try {
      await CustomerService().addToWishlist(card.id);
    } catch (e) {
      if (mounted) showError(context, e);
      return;
    }
    AppRefresh.wishlistChanged();
    if (!mounted) return;
    setState(() => _savedIds.add(card.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${card.name} saved to wishlist!', style: GoogleFonts.poppins()),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        // A snack bar with an action stays until it is tapped unless told
        // otherwise. This one should go away on its own.
        persist: false,
        action: SnackBarAction(label: 'VIEW', textColor: Colors.white, onPressed: _openSaved),
      ));
  }

  Future<void> _openSaved() async {
    // VIEW can still be tapped for a moment after this screen is closed.
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedDesignsScreen()));
    _loadSaved();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _lookupTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Current user ─────────────────────────────────────────────────────────────
  UserModel? get _user => AuthService().currentUser;

  // ── Helpers ──────────────────────────────────────────────────────────────────
  String _cap(String s) {
    s = s.trim();
    if (s.isEmpty) return s;
    if (s.length > 24) s = '${s.substring(0, 24)}…';
    return s[0].toUpperCase() + s.substring(1);
  }

  String _timeLabel(DateTime at) {
    final h = DateTime.now().difference(at).inHours;
    if (h == 0) return 'Just now';
    if (h == 1) return '1 hr ago';
    if (h < 24) return '${h}h ago';
    return '${h ~/ 24}d ago';
  }

  Color _catColor(String cat) => switch (cat) {
    'Bridal' => AppColors.secondary,
    'Formal' => AppColors.info,
    'Eastern' => AppColors.teal,
    'Western' => AppColors.primary,
    'Casual' => AppColors.warning,
    _ => AppColors.textMuted,
  };

  // ── Search handler ───────────────────────────────────────────────────────────
  // Results follow the typing after a short pause. The search is saved to the
  // history (3+ letters) when the customer submits or taps a trend, or once
  // typing stops, so "vel", "velv" and "velve" are not saved as separate searches.
  void _onSearch(String q, {bool save = false}) {
    final trimmed = q.trim();

    _recordTimer?.cancel();
    _lookupTimer?.cancel();
    if (trimmed.length >= 3) {
      if (save) {
        _saveSearch(trimmed);
      } else {
        _recordTimer = Timer(const Duration(milliseconds: 1200), () => _saveSearch(trimmed));
      }
    }
    setState(() {
      _searchQuery = trimmed;
      if (trimmed.isEmpty) _liveResults = [];
    });
    if (trimmed.isEmpty) return;
    _lookupTimer = Timer(const Duration(milliseconds: 300), () => _lookUp(trimmed));
  }

  Future<void> _lookUp(String query) async {
    try {
      final designs = await CustomerService().getRecommendations(query: query);
      // Only the answer for what is in the box now is shown.
      if (!mounted || query != _searchQuery) return;
      setState(() => _liveResults = designs.map(_DesignCard.new).toList());
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _saveSearch(String query) async {
    try {
      await CustomerService().recordSearch(query);
      // The history sections read the saved searches, so show the new one.
      if (mounted) await _load();
    } catch (_) {
      // A search that is not saved only means fewer recommendations later.
    }
  }

  void _applyTrending(String term) {
    _searchCtrl.text = term;
    _onSearch(term, save: true);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _lookupTimer?.cancel();
    setState(() {
      _searchQuery = '';
      _liveResults = [];
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mySearches = _mySearches;
    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuroraBackground(
        orb1: AppColors.purpleOrb,
        orb2: AppColors.pinkOrb,
        orb3: AppColors.tealOrb,
        child: SafeArea(
          child: Column(
            children: [
              // ── Fixed header ───────────────────────────────────────────────
              _buildAppBar(),
              _buildSearchBar(),
              // ── Scrollable body ────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isSearching && _loading)
                        Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2)),
                        )
                      else if (!isSearching && _loadError != null)
                        LoadError(error: _loadError!, onRetry: () {
                          setState(() => _loading = true);
                          _load();
                        })
                      else if (!isSearching) ...[
                        _buildBanner(mySearches),
                        _buildTrendingRow(),
                        if (mySearches.isEmpty)
                          _buildEmptyState()
                        else ...[
                          _sectionHead(
                            'Based on Your Searches',
                            Icons.history_rounded,
                            AppColors.primaryLight,
                            top: 20,
                          ),
                          ...mySearches.map((s) => _SearchBlock(
                                search: s,
                                suggestions: _similar[s.query] ?? const [],
                                timeLabel: _timeLabel(s.createdAt),
                                catColor: _catColor(s.category),
                                onCardTap: (card) =>
                                    _showDesignSheet(card),
                              )),
                        ],
                        _sectionHead(
                          'You May Also Like',
                          Icons.auto_awesome_rounded,
                          AppColors.gold,
                          top: 24,
                          bottom: 12,
                        ),
                        _buildGrid(_youMayLike),
                      ] else ...[
                        // ── Live search results ──────────────────────────────
                        _buildSearchResultsSection(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  // ── App Bar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(
              colors: [AppColors.primary, Color(0xFFA855F7)],
            ).createShader(b),
            child: const Icon(Icons.recommend_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Recommendations',
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                Text('Designs tailored just for you',
                    style: GoogleFonts.poppins(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {}),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.refresh_rounded,
                  color: AppColors.primaryLight, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchQuery.isNotEmpty
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [AppColors.primary, Color(0xFFA855F7)],
                ).createShader(b),
                child: const Icon(Icons.search_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                onSubmitted: (q) => _onSearch(q, save: true),
                style: GoogleFonts.poppins(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Search designs — e.g. "bridal lehenga", "anarkali"…',
                  hintStyle: GoogleFonts.poppins(
                      color: AppColors.textMuted, fontSize: 12),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: _clearSearch,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: AppColors.textMuted, size: 14),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('AI',
                      style: GoogleFonts.poppins(
                          color: AppColors.primaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Live Search Results ───────────────────────────────────────────────────────
  Widget _buildSearchResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead(
          'Results for "$_searchQuery"',
          Icons.search_rounded,
          AppColors.primaryLight,
          top: 20,
          bottom: 4,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text('${_liveResults.length} similar designs found',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted, fontSize: 11)),
        ),
        _buildGrid(_liveResults),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BrowseTailorsScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_rounded,
                      color: AppColors.primaryLight, size: 18),
                  const SizedBox(width: 8),
                  Text('Browse All Tailors for this Design',
                      style: GoogleFonts.poppins(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────────
  Widget _buildBanner(List<SearchEntry> searches) {
    final name = _user?.name.split(' ').first ?? 'You';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            const Color(0xFFA855F7).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hey $name! 👋',
                    style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  searches.isEmpty
                      ? 'Search designs above to get personalised recommendations.'
                      : 'We found styles similar to your ${searches.length} recent searches.',
                  style: GoogleFonts.poppins(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.45),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _Pill('${searches.length} Searches',
                      AppColors.primaryLight),
                  const SizedBox(width: 8),
                  _Pill('AI Powered', AppColors.teal),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: [AppColors.primary, Color(0xFFA855F7)],
                ).createShader(b),
                child: const Icon(Icons.recommend_rounded,
                    color: Colors.white, size: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Trending Row ─────────────────────────────────────────────────────────────
  Widget _buildTrendingRow() {
    final trends = _trending;
    if (trends.isEmpty) return const SizedBox.shrink();

    final colors = [
      AppColors.secondary, AppColors.teal, AppColors.primary,
      AppColors.warning,   AppColors.info,  AppColors.success,
      AppColors.orange, AppColors.gold, AppColors.primaryLight, AppColors.tealLight,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHead('Trending This Week',
            Icons.local_fire_department_rounded, AppColors.orange,
            top: 20, bottom: 10),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            itemCount: trends.length,
            itemBuilder: (_, i) {
              final t = trends[i];
              final c = colors[i % colors.length];
              return GestureDetector(
                onTap: () => _applyTrending(t.query),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: c.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_cap(t.query),
                          style: GoogleFonts.poppins(
                              color: c,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${t.count}',
                            style: GoogleFonts.poppins(
                                color: c,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: EmptyState(
        icon: Icons.search_rounded,
        title: 'No searches yet',
        subtitle:
            'Type a design above or explore tailors — we\'ll suggest similar styles here',
      ),
    );
  }

  // ── Design grid ───────────────────────────────────────────────────────────────
  Widget _buildGrid(List<_DesignCard> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => _DesignTile(
          card: cards[i],
          onTap: () => _showDesignSheet(cards[i]),
        ),
      ),
    );
  }

  // ── Section heading ───────────────────────────────────────────────────────────
  Widget _sectionHead(String text, IconData icon, Color color,
      {double top = 0, double bottom = 0}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top, 16, bottom),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.poppins(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      ]),
    );
  }

  // ── Design detail sheet ───────────────────────────────────────────────────────
  void _showDesignSheet(_DesignCard card) {
    final saved = _savedIds.contains(card.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            // The design's picture
            if (card.design.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 240,
                  width: double.infinity,
                  child: NetworkPicture(
                    url: card.design.imageUrl,
                    fallback: Container(color: card.color.withValues(alpha: 0.1), child: Icon(card.icon, color: card.color, size: 40)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Icon + name row
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: card.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(card.icon, color: card.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name,
                          style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: card.color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(card.category,
                              style: GoogleFonts.poppins(
                                  color: card.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ]),
              ),
            ]),
            const SizedBox(height: 18),
            // Price
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card.color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: card.color.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Icon(Icons.payments_outlined,
                    color: card.color, size: 18),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated Price Range',
                          style: GoogleFonts.poppins(
                              color: AppColors.textMuted, fontSize: 11)),
                      Text(card.price,
                          style: GoogleFonts.poppins(
                              color: card.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ]),
              ]),
            ),
            const SizedBox(height: 12),
            // Delivery time
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(children: [
                Icon(Icons.schedule_rounded,
                    color: AppColors.textMuted, size: 16),
                const SizedBox(width: 10),
                Text('Estimated delivery: 3 – 10 days',
                    style: GoogleFonts.poppins(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 22),
            // Find Tailors button
            GradientButton(
              text: 'Find Tailors for this Design',
              colors: [card.color, card.color.withValues(alpha: 0.7)],
              onTap: () {
                Navigator.pop(ctx);
                // Open the tailor list on the design's category. General
                // designs have no tailor category, so show every tailor.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => BrowseTailorsScreen(
                          initialCategory: card.category == 'General'
                              ? 'All'
                              : card.category)),
                );
              },
            ),
            const SizedBox(height: 10),
            // Save button, or a link to the wishlist once the design is saved.
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                if (saved) {
                  _openSaved();
                } else {
                  _saveDesign(card);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: AppColors.success,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(saved ? 'Saved · View Wishlist' : 'Save to Wishlist',
                        style: GoogleFonts.poppins(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SearchBlock — one "Searched X → Similar Y" row
// ══════════════════════════════════════════════════════════════════════════════
class _SearchBlock extends StatelessWidget {
  final SearchEntry search;
  final List<_DesignCard> suggestions;
  final String timeLabel;
  final Color catColor;
  final void Function(_DesignCard) onCardTap;

  const _SearchBlock({
    required this.search,
    required this.suggestions,
    required this.timeLabel,
    required this.catColor,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final query = search.query;
    final cat = search.category;
    final q = query.isEmpty ? query : query[0].toUpperCase() + query.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label row ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(children: [
            Icon(Icons.search_rounded, color: catColor, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(q,
                  style: GoogleFonts.poppins(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: catColor.withValues(alpha: 0.3)),
              ),
              child: Text(cat,
                  style: GoogleFonts.poppins(
                      color: catColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(timeLabel,
                style: GoogleFonts.poppins(
                    color: AppColors.textMuted, fontSize: 10)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, bottom: 8),
          child: Text('Similar designs you might love  ·  Photos by Pexels',
              style: GoogleFonts.poppins(
                  color: AppColors.textMuted, fontSize: 11)),
        ),
        // ── Horizontal card strip ─────────────────────────────────────────────
        SizedBox(
          height: 236,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            itemCount: suggestions.length,
            itemBuilder: (_, i) => _DesignTile(
              card: suggestions[i],
              width: 134,
              onTap: () => onCardTap(suggestions[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DesignTile
// ══════════════════════════════════════════════════════════════════════════════
class _DesignTile extends StatelessWidget {
  final _DesignCard card;
  final double? width;
  final VoidCallback onTap;

  const _DesignTile({
    required this.card,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 10, bottom: 2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              card.color.withValues(alpha: 0.14),
              card.color.withValues(alpha: 0.07),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: card.color.withValues(alpha: 0.38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: NetworkPicture(
                url: card.design.imageUrl,
                fallback: Center(child: Icon(card.icon, color: card.color, size: 30)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name,
                      style: GoogleFonts.poppins(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(card.price,
                      style: GoogleFonts.poppins(
                          color: card.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 10)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: card.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(card.category,
                        style: GoogleFonts.poppins(
                            color: card.color,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
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

// ── Data models ────────────────────────────────────────────────────────────────
// How a catalogue design is drawn: its colour and icon follow its category.
class _DesignCard {
  final DesignModel design;
  const _DesignCard(this.design);

  String get id => design.id;
  String get name => design.name;
  String get category => design.category;
  String get price => 'Rs ${_money(design.priceMin)} – ${_money(design.priceMax)}';

  static String _money(double value) => value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  Color get color => switch (category) {
    'Bridal' => AppColors.secondary,
    'Formal' => AppColors.info,
    'Eastern' => AppColors.teal,
    'Western' => AppColors.primary,
    'Casual' => AppColors.warning,
    _ => AppColors.primaryLight,
  };

  IconData get icon => switch (category) {
    'Bridal' => Icons.diamond_rounded,
    'Formal' => Icons.business_center_rounded,
    'Eastern' => Icons.layers_rounded,
    'Western' => Icons.nightlife_rounded,
    'Casual' => Icons.wb_sunny_rounded,
    _ => Icons.checkroom_rounded,
  };
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 10)),
      );
}
