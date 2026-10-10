import 'package:neo_brutalism_locket/features/shop/shop_catalog.dart';
import 'package:neo_brutalism_locket/l10n/app_localizations.dart';

/// Shop words in the app's language. The catalog keeps ids and prices; the
/// names people read live in the language files.
extension ShopLabels on AppLocalizations {
  String shopKindLabel(CosmeticKind kind) => switch (kind) {
    CosmeticKind.frame => kindFrame,
    CosmeticKind.banner => kindBanner,
  };

  String shopRarityLabel(Rarity rarity) => switch (rarity) {
    Rarity.common => rarityCommon,
    Rarity.rare => rarityRare,
    Rarity.legendary => rarityLegendary,
  };

  /// The item's name, or the catalog's own name for an id we have no text for.
  String shopItemName(ShopItem item) => switch (item.id) {
    'frame_sunflower' => itemFrameSunflower,
    'frame_brush' => itemFrameBrush,
    'frame_pixel' => itemFramePixel,
    'frame_hearts' => itemFrameHearts,
    'frame_gold_coins' => itemFrameGoldCoins,
    'banner_starry_night' => itemBannerStarryNight,
    'banner_wheat_field' => itemBannerWheatField,
    'banner_almond' => itemBannerAlmond,
    'banner_retro_sky' => itemBannerRetroSky,
    'banner_space' => itemBannerSpace,
    _ => item.name,
  };
}
