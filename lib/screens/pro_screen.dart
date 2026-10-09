import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/county_pavilion.dart';
import '../theme/stadium_themes.dart';

/// Cricket PRO: Free-vs-Pro comparison, real purchase, restore, and tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final CricketAudio audio;
  final CricketSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  StadiumThemeDef get _t => StadiumThemes.byId(
        widget.settings.stadiumId,
        custom: widget.settings.customStadium,
      );

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: Pavilion.body(15, theme: _t)),
          backgroundColor: _t.ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Pavilion.body(15, theme: _t)),
        backgroundColor: _t.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return GroundBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Cricket PRO', style: Pavilion.display(22, theme: t)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                  _ComparisonCard(theme: t, isPro: s.isPro),
                  const SizedBox(height: 16),
                  _BuyCard(
                    theme: t,
                    settings: s,
                    store: store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 16),
                  _TipsCard(
                    theme: t,
                    store: store,
                    audio: widget.audio,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _ComparisonCard extends StatelessWidget {
  final StadiumThemeDef theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete Cricket game', true, true),
      ('All official slog-overs rules', true, true),
      ('Easy & Medium AI', true, true),
      ('2-player pass-and-play', true, true),
      ('2 & 5 over matches', true, true),
      ('Renameable teams', true, true),
      ('Music & sound effects', true, true),
      ('Stadiums', '4', '12 + creator'),
      ('Team kits', '3', '8 + creator'),
      ('Ball styles', '2', '6 + creator'),
      ('Hard AI difficulty', false, true),
      ('10-over matches', false, true),
      ('Custom ground creator', false, true),
      ('Custom kit & ball creator', false, true),
    ];
    return ScoreboardCard(
      theme: theme,
      title: 'Free vs PRO',
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(flex: 3),
              Expanded(
                  child: Text('Free',
                      style: Pavilion.label(13, theme: theme),
                      textAlign: TextAlign.center)),
              Expanded(
                  child: Text('PRO',
                      style: Pavilion.label(13,
                          theme: theme, color: theme.accentLight),
                      textAlign: TextAlign.center)),
            ],
          ),
          const SizedBox(height: 6),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(r.$1,
                        style: Pavilion.body(13, theme: theme)),
                  ),
                  Expanded(child: _cell(r.$2)),
                  Expanded(child: _cell(r.$3)),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('✦ PRO is active on this device ✦',
                  style: Pavilion.label(14, theme: theme)),
            ),
        ],
      ),
    );
  }

  Widget _cell(Object v) {
    if (v is bool) {
      return Icon(v ? Icons.check_circle : Icons.remove_circle_outline,
          color: v ? const Color(0xFF4E9A42) : Colors.grey, size: 20);
    }
    return Text('$v',
        style: Pavilion.label(13, theme: theme),
        textAlign: TextAlign.center);
  }
}

// ---------------------------------------------------------------------------
class _BuyCard extends StatelessWidget {
  final StadiumThemeDef theme;
  final CricketSettings settings;
  final StoreService store;
  final CricketAudio audio;
  const _BuyCard({
    required this.theme,
    required this.settings,
    required this.store,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final pro = store.proProduct;
    return ScoreboardCard(
      theme: theme,
      title: 'Unlock PRO',
      child: Column(
        children: [
          if (settings.isPro)
            Text('You already own PRO — thank you! 🏏',
                style: Pavilion.body(15, theme: theme),
                textAlign: TextAlign.center)
          else if (!store.storeReady)
            Text(
              'PRO purchases will be available here once the store '
              'products are set up. The full game is free meanwhile!',
              style: Pavilion.body(14, theme: theme),
              textAlign: TextAlign.center,
            )
          else if (pro != null) ...[
            Text(pro.description.isNotEmpty
                ? pro.description
                : 'One-time purchase. Yours forever, on every device.',
                style: Pavilion.body(14, theme: theme),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            PavilionButton(
              label: store.purchaseInProgress.value
                  ? 'Working…'
                  : 'Unlock PRO — ${pro.price}',
              theme: theme,
              width: 260,
              onTap: () {
                audio.click();
                store.buyPro();
              },
            ),
            if (store.purchaseError.value != null) ...[
              const SizedBox(height: 8),
              Text(store.purchaseError.value!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center),
            ],
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              audio.click();
              store.restore();
            },
            child: Text('Restore purchases',
                style: Pavilion.label(14, theme: theme).copyWith(
                    decoration: TextDecoration.underline)),
          ),
          const SizedBox(height: 4),
          Text('Already bought PRO on another device? Tap above.',
              style: Pavilion.body(11,
                  theme: theme,
                  color: theme.cream.withValues(alpha: 0.6)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _TipsCard extends StatelessWidget {
  final StadiumThemeDef theme;
  final StoreService store;
  final CricketAudio audio;
  const _TipsCard(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return ScoreboardCard(
      theme: theme,
      title: 'Tip Jar',
      child: Column(
        children: [
          Text(
            'Cricket is free forever. A tip buys the team a round — thank you!',
            style: Pavilion.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(store.error ?? 'Loading…',
                style: Pavilion.body(13,
                    theme: theme,
                    color: theme.cream.withValues(alpha: 0.6)))
          else if (tips.isEmpty)
            Text('Tips coming soon.',
                style: Pavilion.body(13,
                    theme: theme,
                    color: theme.cream.withValues(alpha: 0.6)))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  GestureDetector(
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.black.withValues(alpha: 0.3),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        p.id == StoreService.chocolateId
                            ? '🍫 ${p.price}'
                            : '☕ ${p.price}',
                        style: Pavilion.label(14, theme: theme),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
