/// Order matters: it is the left-to-right order of the style pill.
enum StyleType { none, pixel8bit, vanGogh }

extension StyleTypeLabel on StyleType {
  String get label => switch (this) {
    StyleType.none => 'NO STYLE',
    StyleType.pixel8bit => '8-BIT',
    StyleType.vanGogh => 'VAN GOGH',
  };
}
