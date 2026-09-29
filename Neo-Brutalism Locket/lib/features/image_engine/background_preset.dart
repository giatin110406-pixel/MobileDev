class ImageBackgroundPreset {
  const ImageBackgroundPreset({required this.label, required this.rgbHex});

  final String label;
  final int rgbHex;

  int get colorValue => 0xFF000000 | rgbHex;

  List<int> get rgb => [
    (rgbHex >> 16) & 0xFF,
    (rgbHex >> 8) & 0xFF,
    rgbHex & 0xFF,
  ];
}

const imageBackgroundPresets = <ImageBackgroundPreset>[
  ImageBackgroundPreset(label: 'TEAL', rgbHex: 0x4ECDC4),
  ImageBackgroundPreset(label: 'YELLOW', rgbHex: 0xFFE66D),
  ImageBackgroundPreset(label: 'PINK', rgbHex: 0xFF6B6B),
  ImageBackgroundPreset(label: 'BLUE', rgbHex: 0x45B7D1),
  ImageBackgroundPreset(label: 'ORANGE', rgbHex: 0xF7A072),
];
