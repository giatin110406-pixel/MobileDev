import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/banner_art.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/contest/contest_widgets.dart';
import 'package:neo_brutalism_locket/features/profile/player_avatar.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/progress/player_error_text.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/features/shop/shop_labels.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';
import 'package:neo_brutalism_locket/core/haptics.dart';

/// What the main button of an item does right now.
enum ShopAction { buy, locked, equip, unequip }

ShopAction shopActionFor(PlayerState state, ShopItem item) {
  if (state.equipped(item.kind) == item.id) return ShopAction.unequip;
  if (state.owns(item.id)) return ShopAction.equip;
  return state.balance >= item.price ? ShopAction.buy : ShopAction.locked;
}

Future<void> openShop(BuildContext context, PlayerStore store) {
  // The shop is a new page, not below the shell: carry the paintings over.
  final art = ContestArtScope.maybeOf(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) {
        final shop = ShopScreen(store: store, contest: art?.repository);
        return art == null ? shop : ContestArtScope(cache: art, child: shop);
      },
    ),
  );
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    required this.store,
    this.contest,
    this.clock = DateTime.now,
  });

  final PlayerStore store;

  /// Where the limited-time banners (the winning paintings) come from (null: the
  /// shop has none).
  final ContestRepository? contest;

  /// What time it is (tests set it).
  final DateTime Function() clock;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  CosmeticKind _kind = CosmeticKind.frame;

  /// The winning paintings that are on sale right now, as banners.
  List<GalleryShopItem> _offers = const [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    final contest = widget.contest;
    if (contest == null) return;
    try {
      final items = await contest.shopItems();
      if (mounted) setState(() => _offers = _stillOn(items));
    } on ContestFailure {
      // The ordinary shop is still there; the offers are just not shown.
    }
  }

  List<GalleryShopItem> _stillOn(List<GalleryShopItem> items) => [
    for (final item in items)
      if (item.endsAt.isAfter(widget.clock())) item,
  ];

  /// An offer's time ran out while the shop was open: it disappears.
  void _offersEnded() {
    if (mounted) setState(() => _offers = _stillOn(_offers));
    _loadOffers();
  }

  @override
  Widget build(BuildContext context) {
    final items = shopCatalog.where((item) => item.kind == _kind).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final state = widget.store.state;
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NeoIconButton(
                        icon: Icons.arrow_back,
                        tooltip: AppLocalizations.of(context).backTooltip,
                        fill: NeoColors.accent,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context).sunbitShop,
                              style: const TextStyle(
                                color: NeoColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              AppLocalizations.of(context).shopDecorate,
                              style: const TextStyle(
                                color: NeoColors.muted,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SunbitBadge(balance: widget.store.balance),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final kind in CosmeticKind.values) ...[
                        Expanded(child: _kindTab(kind)),
                        if (kind != CosmeticKind.values.last)
                          const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: state == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: NeoColors.ink,
                            ),
                          )
                        : CustomScrollView(
                            slivers: [
                              if (_kind == CosmeticKind.banner &&
                                  _offers.isNotEmpty)
                                SliverToBoxAdapter(child: _offerSection(state)),
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                  bottom: 20,
                                  right: 4,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 14,
                                        crossAxisSpacing: 14,
                                        childAspectRatio: 0.72,
                                      ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) =>
                                        _itemCard(state, items[index]),
                                    childCount: items.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _kindTab(CosmeticKind kind) {
    final selected = kind == _kind;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: Haptics.tap(() => setState(() => _kind = kind)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: NeoTheme.panel(
            color: selected ? NeoColors.accent : NeoColors.surface,
          ),
          child: Text(
            AppLocalizations.of(context).shopKindLabel(kind),
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  /// The winning paintings, on sale for a few days: banners in the proportions of a
  /// profile banner, with the time that is left.
  Widget _offerSection(PlayerState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: NeoLabel(
              AppLocalizations.of(context).shopLimitedOffer,
              color: NeoColors.coral,
              icon: Icons.timer_outlined,
            ),
          ),
          const SizedBox(height: 10),
          for (final offer in _offers) ...[
            _offerCard(state, offer),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _offerCard(PlayerState state, GalleryShopItem item) {
    final action = shopActionFor(state, item.toShopItem());
    final vi = Localizations.localeOf(context).languageCode != 'en';
    final l10n = AppLocalizations.of(context);
    final medals = {1: l10n.rank1, 2: l10n.rank2, 3: l10n.rank3};
    return _ShopCard(
      equipped: action == ShopAction.unequip,
      onTap: Haptics.tap(() => _openOffer(item)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: profileBannerAspect,
            child: ProfileBanner(bannerId: item.id, height: double.infinity),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '${medals[item.rank] ?? 'TOP 3'} · ${vi ? item.titleVi : item.titleEn}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NeoColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _OfferCountdown(
                endsAt: item.endsAt,
                clock: widget.clock,
                onEnded: _offersEnded,
              ),
              const Spacer(),
              switch (action) {
                ShopAction.unequip => _StatusPill(
                  inUse: true,
                  text: l10n.shopInUse,
                ),
                ShopAction.equip => _StatusPill(
                  inUse: false,
                  text: l10n.shopOwned,
                ),
                _ => PriceTag(price: item.price),
              },
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openOffer(GalleryShopItem item) async {
    await showShopItemSheet(
      context,
      widget.store,
      item.toShopItem(),
      note: AppLocalizations.of(context).shopRoyaltyNote,
      endsAt: item.endsAt,
      clock: widget.clock,
    );
    if (mounted) _loadOffers();
  }

  Widget _itemCard(PlayerState state, ShopItem item) {
    final action = shopActionFor(state, item);
    return _ShopCard(
      equipped: action == ShopAction.unequip,
      onTap: Haptics.tap(() => showShopItemSheet(context, widget.store, item)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: item.kind == CosmeticKind.frame
                  ? PlayerAvatar(
                      state: state,
                      size: 92,
                      frameId: item.id,
                      previewFrame: true,
                    )
                  : ProfileBanner(bannerId: item.id, height: 74),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).shopItemName(item),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: NeoColors.ink,
              fontSize: 13,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RarityChip(rarity: item.rarity),
                ),
              ),
              const SizedBox(width: 6),
              switch (action) {
                ShopAction.unequip => _StatusPill(
                  inUse: true,
                  text: AppLocalizations.of(context).shopInUse,
                ),
                ShopAction.equip => _StatusPill(
                  inUse: false,
                  text: AppLocalizations.of(context).shopOwned,
                ),
                _ => PriceTag(price: item.price),
              },
            ],
          ),
        ],
      ),
    );
  }
}

/// "LIMITED TIME OFFER · ends in 1d 05:03:09", counting down every second. It says
/// [onEnded] once when the time is up.
class _OfferCountdown extends StatefulWidget {
  const _OfferCountdown({
    required this.endsAt,
    required this.clock,
    this.onEnded,
  });

  final DateTime endsAt;
  final DateTime Function() clock;
  final VoidCallback? onEnded;

  @override
  State<_OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<_OfferCountdown> {
  Timer? _timer;
  int _seconds = 0;
  bool _ended = false;

  Duration get _left => widget.endsAt.difference(widget.clock());

  @override
  void initState() {
    super.initState();
    _seconds = _left.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final seconds = _left.inSeconds;
    if (seconds <= 0 && !_ended) {
      _ended = true;
      widget.onEnded?.call();
    }
    // Only when the shown number changes (a stopped clock stays quiet).
    if (seconds != _seconds && mounted) setState(() => _seconds = seconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final left = _left;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 14, color: NeoColors.coral),
        const SizedBox(width: 4),
        Text(
          left <= Duration.zero
              ? l10n.shopOfferEnded
              : l10n.shopEndsIn(formatCountdown(l10n, left)),
          style: const TextStyle(
            color: NeoColors.ink,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// What a card says about an item you already own: a solid green "IN USE" pill
/// with a tick for the one worn right now, a plain outlined "OWNED" for the rest.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.inUse, required this.text});

  final bool inUse;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: inUse ? NeoColors.accent : NeoColors.surface,
      border: Border.all(color: NeoColors.ink, width: 2),
      borderRadius: BorderRadius.circular(999),
      boxShadow: inUse
          ? const [BoxShadow(color: NeoColors.ink, offset: Offset(2, 2))]
          : null,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inUse) ...[
          const Icon(Icons.check_rounded, size: 12, color: NeoColors.ink),
          const SizedBox(width: 3),
        ],
        Text(
          text,
          style: const TextStyle(
            color: NeoColors.ink,
            fontFamily: NeoFont.display,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

/// A shop card. The item being worn gets a green ground, a thicker outline and a
/// big tick stamped on its corner, so it reads at a glance without any text.
class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.equipped,
    required this.onTap,
    required this.child,
  });

  final bool equipped;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      // The worn item stays pressed in; the others stand proud of the page.
      NeoPress(
        onTap: onTap,
        sunken: equipped,
        builder: (context, pressed) => Container(
          padding: const EdgeInsets.all(10),
          decoration: NeoTheme.panel(
            color: equipped ? const Color(0xFFD9F2DF) : NeoColors.surface,
            borderWidth: equipped ? 3 : 2,
            pressed: pressed,
          ),
          child: child,
        ),
      ),
      if (equipped)
        Positioned(
          // Moves with the card, which sits 4px down and right when pressed in.
          top: -6,
          right: -2,
          child: IgnorePointer(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: NeoColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: NeoColors.ink, width: 3),
                boxShadow: const [
                  BoxShadow(color: NeoColors.ink, offset: Offset(2, 2)),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: NeoColors.ink,
              ),
            ),
          ),
        ),
    ],
  );
}

class RarityChip extends StatelessWidget {
  const RarityChip({super.key, required this.rarity});

  final Rarity rarity;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: rarity.color,
      border: Border.all(color: NeoColors.ink, width: 1.5),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      AppLocalizations.of(context).shopRarityLabel(rarity),
      style: const TextStyle(
        color: NeoColors.ink,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}

class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price});

  final int price;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SunbitCoin(size: 14),
      const SizedBox(width: 4),
      Text(
        '$price',
        style: const TextStyle(
          color: NeoColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

/// Item details: a preview on your own avatar or banner, and the one button
/// that buys, equips or takes it off (or shows how much Sunbit is missing).
Future<void> showShopItemSheet(
  BuildContext context,
  PlayerStore store,
  ShopItem item, {
  String? note,
  DateTime? endsAt,
  DateTime Function() clock = DateTime.now,
}) {
  // A sheet is a new page, not below this screen: carry the paintings over.
  final art = ContestArtScope.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final sheet = _ShopItemSheet(
        store: store,
        item: item,
        note: note,
        endsAt: endsAt,
        clock: clock,
      );
      return art == null ? sheet : ContestArtScope(cache: art, child: sheet);
    },
  );
}

class _ShopItemSheet extends StatefulWidget {
  const _ShopItemSheet({
    required this.store,
    required this.item,
    this.note,
    this.endsAt,
    this.clock = DateTime.now,
  });

  final PlayerStore store;
  final ShopItem item;
  final String? note;

  /// When a limited-time offer ends (null: always on sale).
  final DateTime? endsAt;
  final DateTime Function() clock;

  @override
  State<_ShopItemSheet> createState() => _ShopItemSheetState();
}

class _ShopItemSheetState extends State<_ShopItemSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _act(ShopAction action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (action) {
        case ShopAction.buy:
          await widget.store.buy(widget.item);
        case ShopAction.equip:
          await widget.store.equip(widget.item);
        case ShopAction.unequip:
          await widget.store.unequip(widget.item.kind);
        case ShopAction.locked:
          break;
      }
    } on PlayerException catch (error) {
      if (mounted) {
        _error = playerErrorText(AppLocalizations.of(context), error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.state;
        if (state == null) return const SizedBox.shrink();
        final action = shopActionFor(state, item);
        final endsAt = widget.endsAt;
        final ended = endsAt != null && !widget.clock().isBefore(endsAt);
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: NeoTheme.panel(color: NeoColors.surface, radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NeoLabel(item.theme.label, color: NeoColors.accent),
                  const SizedBox(width: 8),
                  RarityChip(rarity: item.rarity),
                  const Spacer(),
                  SunbitBadge(balance: state.balance),
                ],
              ),
              const SizedBox(height: 16),
              _preview(state),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).shopItemName(item),
                style: const TextStyle(
                  fontFamily: NeoFont.display,
                  color: NeoColors.ink,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${AppLocalizations.of(context).shopKindLabel(item.kind)} · ',
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  PriceTag(price: item.price),
                ],
              ),
              if (endsAt != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NeoLabel(
                      AppLocalizations.of(context).shopLimitedOffer,
                      color: NeoColors.coral,
                    ),
                    _OfferCountdown(
                      endsAt: endsAt,
                      clock: widget.clock,
                      onEnded: () {
                        if (mounted) setState(() {});
                      },
                    ),
                  ],
                ),
              ],
              if (widget.note != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.note!,
                  style: const TextStyle(
                    color: NeoColors.muted,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              NeoButton(
                expand: true,
                label: switch (action) {
                  ShopAction.buy when ended => AppLocalizations.of(
                    context,
                  ).shopOfferEnded,
                  ShopAction.buy => AppLocalizations.of(
                    context,
                  ).shopBuy(item.price),
                  ShopAction.locked => AppLocalizations.of(
                    context,
                  ).shopShort(item.price - state.balance),
                  ShopAction.equip => AppLocalizations.of(context).shopEquip,
                  ShopAction.unequip => AppLocalizations.of(
                    context,
                  ).shopUnequip,
                },
                icon: switch (action) {
                  ShopAction.buy => Icons.shopping_bag_outlined,
                  ShopAction.locked => Icons.lock_outline,
                  ShopAction.equip => Icons.check_circle_outline,
                  ShopAction.unequip => Icons.remove_circle_outline,
                },
                variant: switch (action) {
                  ShopAction.buy => NeoButtonVariant.primary,
                  ShopAction.locked => NeoButtonVariant.outline,
                  ShopAction.equip => NeoButtonVariant.accent,
                  ShopAction.unequip => NeoButtonVariant.outline,
                },
                onPressed:
                    action == ShopAction.locked ||
                        _busy ||
                        (ended && action == ShopAction.buy)
                    ? null
                    : () => _act(action),
              ),
              const SizedBox(height: 10),
              Text(
                _error ??
                    switch (action) {
                      ShopAction.buy => AppLocalizations.of(
                        context,
                      ).shopHintBuy,
                      ShopAction.locked => AppLocalizations.of(
                        context,
                      ).shopHintLocked,
                      ShopAction.equip => AppLocalizations.of(
                        context,
                      ).shopHintEquip,
                      ShopAction.unequip => AppLocalizations.of(
                        context,
                      ).shopHintUnequip,
                    },
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error == null ? NeoColors.muted : NeoColors.coral,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The item on your own profile: a frame on your avatar, a banner above it.
  Widget _preview(PlayerState state) {
    final item = widget.item;
    if (item.kind == CosmeticKind.frame) {
      return Center(
        child: PlayerAvatar(
          state: state,
          size: 160,
          frameId: item.id,
          previewFrame: true,
        ),
      );
    }
    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          ProfileBanner(bannerId: item.id, height: 120),
          Positioned(
            left: 14,
            bottom: 0,
            child: PlayerAvatar(state: state, size: 64),
          ),
        ],
      ),
    );
  }
}
