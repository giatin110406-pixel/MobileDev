const pico8Palette = <int>[
  0x000000,
  0x1D2B53,
  0x7E2553,
  0x008751,
  0xAB5236,
  0x5F574F,
  0xC2C3C7,
  0xFFF1E8,
  0xFF004D,
  0xFFA300,
  0xFFEC27,
  0x00E436,
  0x29ADFF,
  0x83769C,
  0xFF77A8,
  0xFFCCAA,
];

/// ENDESGA 32 by ENDESGA (free to use): best skin tones in the palette study
/// against PICO-8 and Sweetie 16 on 14 photos, so it is the engine's palette.
const endesga32Palette = <int>[
  0xBE4A2F,
  0xD77643,
  0xEAD4AA,
  0xE4A672,
  0xB86F50,
  0x733E39,
  0x3E2731,
  0xA22633,
  0xE43B44,
  0xF77622,
  0xFEAE34,
  0xFEE761,
  0x63C74D,
  0x3E8948,
  0x265C42,
  0x193C3E,
  0x124E89,
  0x0099DB,
  0x2CE8F5,
  0xFFFFFF,
  0xC0CBDC,
  0x8B9BB4,
  0x5A6988,
  0x3A4466,
  0x262B44,
  0x181425,
  0xFF0044,
  0x68386C,
  0xB55088,
  0xF6757A,
  0xE8B796,
  0xC28569,
];

const bayer4x4 = <int>[0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

/// Ordered-dither threshold in (0, 1) for pixel (x, y).
double bayerThreshold(int x, int y) =>
    (bayer4x4[(y & 3) * 4 + (x & 3)] + 0.5) / 16;
