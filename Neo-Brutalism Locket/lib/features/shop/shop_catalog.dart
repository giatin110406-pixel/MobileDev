import 'dart:ui';

import 'package:neo_brutalism_locket/core/neo_theme.dart';

enum CosmeticKind { frame, banner }

enum Rarity { common, rare, legendary }

enum CosmeticTheme { vanGogh, pixel }

extension CosmeticKindLabel on CosmeticKind {
  String get label => switch (this) {
    CosmeticKind.frame => 'KHUNG AVATAR',
    CosmeticKind.banner => 'BANNER',
  };
}

extension RarityLabel on Rarity {
  String get label => switch (this) {
    Rarity.common => 'THƯỜNG',
    Rarity.rare => 'HIẾM',
    Rarity.legendary => 'HUYỀN THOẠI',
  };

  Color get color => switch (this) {
    Rarity.common => NeoColors.surface,
    Rarity.rare => NeoColors.blue,
    Rarity.legendary => NeoColors.yellow,
  };
}

extension CosmeticThemeLabel on CosmeticTheme {
  String get label => switch (this) {
    CosmeticTheme.vanGogh => 'VAN GOGH',
    CosmeticTheme.pixel => '8-BIT',
  };
}

/// Something the shop sells. The look of each item is drawn in code (see
/// cosmetics.dart), keyed by [id].
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.rarity,
    required this.theme,
    required this.price,
  });

  final String id;
  final String name;
  final CosmeticKind kind;
  final Rarity rarity;
  final CosmeticTheme theme;

  /// In Sunbit: common 50-100, rare 150-250, legendary 400-500.
  final int price;
}

/// Ids are stored in the inventory, so never rename one.
const shopCatalog = <ShopItem>[
  ShopItem(
    id: 'frame_sunflower',
    name: 'Khung hoa hướng dương',
    kind: CosmeticKind.frame,
    rarity: Rarity.legendary,
    theme: CosmeticTheme.vanGogh,
    price: 450,
  ),
  ShopItem(
    id: 'frame_brush',
    name: 'Khung nét cọ xoáy',
    kind: CosmeticKind.frame,
    rarity: Rarity.common,
    theme: CosmeticTheme.vanGogh,
    price: 60,
  ),
  ShopItem(
    id: 'frame_pixel',
    name: 'Khung viền pixel',
    kind: CosmeticKind.frame,
    rarity: Rarity.common,
    theme: CosmeticTheme.pixel,
    price: 50,
  ),
  ShopItem(
    id: 'frame_hearts',
    name: 'Khung trái tim 8-bit',
    kind: CosmeticKind.frame,
    rarity: Rarity.rare,
    theme: CosmeticTheme.pixel,
    price: 150,
  ),
  ShopItem(
    id: 'frame_gold_coins',
    name: 'Khung xu vàng',
    kind: CosmeticKind.frame,
    rarity: Rarity.legendary,
    theme: CosmeticTheme.pixel,
    price: 400,
  ),
  ShopItem(
    id: 'banner_starry_night',
    name: 'Banner đêm đầy sao',
    kind: CosmeticKind.banner,
    rarity: Rarity.legendary,
    theme: CosmeticTheme.vanGogh,
    price: 500,
  ),
  ShopItem(
    id: 'banner_wheat_field',
    name: 'Banner đồng lúa mì',
    kind: CosmeticKind.banner,
    rarity: Rarity.rare,
    theme: CosmeticTheme.vanGogh,
    price: 180,
  ),
  ShopItem(
    id: 'banner_almond',
    name: 'Banner hoa hạnh nhân',
    kind: CosmeticKind.banner,
    rarity: Rarity.common,
    theme: CosmeticTheme.vanGogh,
    price: 80,
  ),
  ShopItem(
    id: 'banner_retro_sky',
    name: 'Banner bầu trời game cổ',
    kind: CosmeticKind.banner,
    rarity: Rarity.rare,
    theme: CosmeticTheme.pixel,
    price: 220,
  ),
  ShopItem(
    id: 'banner_space',
    name: 'Banner không gian pixel',
    kind: CosmeticKind.banner,
    rarity: Rarity.common,
    theme: CosmeticTheme.pixel,
    price: 100,
  ),
];

ShopItem? shopItemById(String? id) {
  if (id == null) return null;
  for (final item in shopCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

/// The frame and banner someone shows on their profile.
class Loadout {
  const Loadout({this.frameId, this.bannerId});

  final String? frameId;
  final String? bannerId;

  static const empty = Loadout();
}

/// What the sample friends wear. Friends live only on this device for now,
/// so their cosmetics are fixed here instead of synced from their phones.
const sampleFriendLoadouts = <String, Loadout>{
  'sample-ava': Loadout(
    frameId: 'frame_sunflower',
    bannerId: 'banner_starry_night',
  ),
  'sample-jules': Loadout(frameId: 'frame_pixel', bannerId: 'banner_retro_sky'),
  'sample-remy': Loadout(frameId: 'frame_brush', bannerId: 'banner_almond'),
};
