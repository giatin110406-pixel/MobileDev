import 'package:flutter/material.dart';
import 'package:neo_brutalism_locket/core/neo_theme.dart';
import 'package:neo_brutalism_locket/features/contest/banner_art.dart';
import 'package:neo_brutalism_locket/features/contest/contest_repository.dart';
import 'package:neo_brutalism_locket/features/profile/player_avatar.dart';
import 'package:neo_brutalism_locket/features/progress/player_repository.dart';
import 'package:neo_brutalism_locket/features/progress/player_state.dart';
import 'package:neo_brutalism_locket/features/progress/player_store.dart';
import 'package:neo_brutalism_locket/features/shop/cosmetics.dart';
import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/features/wallet/sunbit_badge.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

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
  const ShopScreen({super.key, required this.store, this.contest});

  final PlayerStore store;

  /// Where the winning paintings come from (null: no "Tranh" shelf).
  final ContestRepository? contest;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  CosmeticKind _kind = CosmeticKind.frame;

  /// The "Tranh" shelf (winning paintings) instead of frames and banners.
  bool _paintings = false;
  List<GalleryShopItem>? _paintingItems;
  bool _paintingsFailed = false;

  Future<void> _loadPaintings() async {
    final contest = widget.contest;
    if (contest == null) return;
    setState(() => _paintingsFailed = false);
    try {
      final items = await contest.shopItems();
      if (mounted) setState(() => _paintingItems = items);
    } on ContestFailure {
      if (mounted) setState(() => _paintingsFailed = true);
    }
  }

  void _showPaintings() {
    setState(() => _paintings = true);
    _loadPaintings();
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
                        tooltip: 'Quay lại',
                        fill: NeoColors.yellow,
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
                              'TRANG TRÍ TRANG CÁ NHÂN',
                              style: TextStyle(
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
                        if (kind != CosmeticKind.values.last ||
                            widget.contest != null)
                          const SizedBox(width: 10),
                      ],
                      if (widget.contest != null)
                        Expanded(child: _paintingsTab()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _paintings
                        ? _paintingShelf(state)
                        : state == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: NeoColors.ink,
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.only(
                              bottom: 20,
                              right: 4,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.72,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, index) =>
                                _itemCard(state, items[index]),
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
    final selected = !_paintings && kind == _kind;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => setState(() {
          _kind = kind;
          _paintings = false;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: NeoTheme.panel(
            color: selected ? NeoColors.teal : NeoColors.surface,
          ),
          child: Text(
            kind.label,
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

  Widget _paintingsTab() => Semantics(
    button: true,
    selected: _paintings,
    child: InkWell(
      onTap: _showPaintings,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: NeoTheme.panel(
          color: _paintings ? NeoColors.teal : NeoColors.surface,
        ),
        child: const Text(
          'TRANH',
          style: TextStyle(
            color: NeoColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );

  /// The winning paintings of the weekly contest, as banners.
  Widget _paintingShelf(PlayerState? state) {
    final items = _paintingItems;
    if (state == null || (items == null && !_paintingsFailed)) {
      return const Center(
        child: CircularProgressIndicator(color: NeoColors.ink),
      );
    }
    if (items == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Không tải được tranh đoạt giải.',
              style: TextStyle(
                color: NeoColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            NeoButton(label: 'THỬ LẠI', onPressed: _loadPaintings),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chưa có tranh nào đoạt giải. Ba bài đứng đầu mỗi tuần sẽ được '
            'bán ở đây, làm banner cho trang cá nhân.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: NeoColors.ink,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 20, right: 4),
      itemCount: items.length,
      separatorBuilder: (context, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _paintingCard(state, items[index]),
    );
  }

  Widget _paintingCard(PlayerState state, GalleryShopItem item) {
    final shopItem = item.toShopItem();
    final action = shopActionFor(state, shopItem);
    final vi = Localizations.localeOf(context).languageCode != 'en';
    const medals = {1: 'HẠNG NHẤT', 2: 'HẠNG NHÌ', 3: 'HẠNG BA'};
    return InkWell(
      onTap: () => _openPainting(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: NeoTheme.panel(color: NeoColors.surface),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileBanner(bannerId: item.id, height: 84),
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
                RarityChip(rarity: item.rarity),
                const SizedBox(width: 8),
                if (item.left != null)
                  Text(
                    item.soldOut ? 'HẾT BẢN' : 'CÒN ${item.left} BẢN',
                    style: TextStyle(
                      color: item.soldOut ? NeoColors.pink : NeoColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                const Spacer(),
                switch (action) {
                  ShopAction.unequip => const _StatusText('ĐANG DÙNG'),
                  ShopAction.equip => const _StatusText('ĐÃ CÓ'),
                  _ => PriceTag(price: item.price),
                },
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPainting(GalleryShopItem item) async {
    await showShopItemSheet(
      context,
      widget.store,
      item.toShopItem(),
      note: item.left == null
          ? null
          : 'Bản giới hạn: còn ${item.left} / ${item.stock}. '
                '20% tiền bán chia đều cho nhóm đã vẽ.',
      soldOut: item.soldOut,
    );
    // The copies left may have changed (also because of this purchase).
    if (mounted) _loadPaintings();
  }

  Widget _itemCard(PlayerState state, ShopItem item) {
    final action = shopActionFor(state, item);
    return InkWell(
      onTap: () => showShopItemSheet(context, widget.store, item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: NeoTheme.panel(color: NeoColors.surface),
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
              item.name,
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
                  ShopAction.unequip => const _StatusText('ĐANG DÙNG'),
                  ShopAction.equip => const _StatusText('ĐÃ CÓ'),
                  _ => PriceTag(price: item.price),
                },
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: NeoColors.ink,
      fontSize: 10,
      fontWeight: FontWeight.w900,
    ),
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
      rarity.label,
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
  bool soldOut = false,
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
        soldOut: soldOut,
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
    this.soldOut = false,
  });

  final PlayerStore store;
  final ShopItem item;
  final String? note;

  /// A limited item with no copies left (only matters if you do not own it).
  final bool soldOut;

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
      _error = error.message;
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
                  NeoLabel(item.theme.label, color: NeoColors.purple),
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
                item.name,
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
                    '${item.kind.label} · ',
                    style: const TextStyle(
                      color: NeoColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  PriceTag(price: item.price),
                ],
              ),
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
                  ShopAction.buy when widget.soldOut => 'HẾT BẢN',
                  ShopAction.buy => 'MUA · ${item.price} SUNBIT',
                  ShopAction.locked =>
                    'CÒN THIẾU ${item.price - state.balance} SUNBIT',
                  ShopAction.equip => 'TRANG BỊ',
                  ShopAction.unequip => 'THÁO RA',
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
                        (widget.soldOut && action == ShopAction.buy)
                    ? null
                    : () => _act(action),
              ),
              const SizedBox(height: 10),
              Text(
                _error ??
                    switch (action) {
                      ShopAction.buy => 'Mua một lần, dùng mãi mãi.',
                      ShopAction.locked =>
                        'Hoàn thành nhiệm vụ hằng ngày để kiếm thêm Sunbit.',
                      ShopAction.equip =>
                        'Bạn đã sở hữu món này. Đổi món miễn phí.',
                      ShopAction.unequip => 'Bạn đang dùng món này.',
                    },
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _error == null ? NeoColors.muted : NeoColors.pink,
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
