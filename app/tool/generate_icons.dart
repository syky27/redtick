// Bakes the opaque, branded app-icon masters that `flutter_launcher_icons`
// fans out to every platform (see flutter_launcher_icons.yaml). Run from `app/`:
//
//   dart run tool/generate_icons.dart
//
// then:
//
//   dart run flutter_launcher_icons
//
// The icon is the theme's beveled brand tile (RedtickTokens.brandTile in
// lib/src/ui/theme.dart) — a radial gradient #C0302A -> #8C1513 with the white
// hourglass glyph on top. The glyph source is the splash glyph; we only own the
// generation here, so the masters stay reproducible without any design tool.
//
// Outputs (all 1024x1024, committed under assets/icon/):
//   icon_master.png              full-bleed opaque tile + glyph  (iOS/Windows/Android-legacy)
//   icon_macos.png               rounded squircle + transparent margin (native macOS look)
//   icon_adaptive_foreground.png transparent, glyph in the adaptive safe zone
//   icon_adaptive_background.png full gradient, no glyph (Android adaptive background)

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

// Brand tile gradient, mirroring RedtickTokens.brandTile:
//   RadialGradient(center: Alignment(-0.4, -0.5), radius: 1.1,
//                  colors: [kBrandTileTop #C0302A, kBrandTileBottom #8C1513],
//                  stops: [0.0, 0.72])
const _topR = 0xC0, _topG = 0x30, _topB = 0x2A; // kBrandTileTop  #C0302A
const _botR = 0x8C, _botG = 0x15, _botB = 0x13; // kBrandTileBottom #8C1513

const _size = 1024;

void main() {
  final glyph = img.decodePng(
      File('assets/splash/redtick_splash_glyph_white.png').readAsBytesSync())!;

  Directory('assets/icon').createSync(recursive: true);

  // 1) Full-bleed opaque master — iOS / Windows / Android-legacy.
  final master = _gradientTile(_size, _size);
  _placeGlyph(master, glyph, 0.62);
  _write('assets/icon/icon_master.png', master);

  // 2) macOS master — rounded squircle + ~100 px transparent margin (the tool
  //    does not add the native rounding itself, so we bake it in here).
  const margin = 100;
  final tileSize = _size - 2 * margin; // 824
  final tile = _gradientTile(tileSize, tileSize);
  _roundCorners(tile, (tileSize * 0.2247).round()); // ~185 px continuous-ish corner
  final macos = img.Image(width: _size, height: _size, numChannels: 4); // transparent
  img.compositeImage(macos, tile, dstX: margin, dstY: margin);
  _placeGlyph(macos, glyph, 0.50);
  _write('assets/icon/icon_macos.png', macos);

  // 3) Android adaptive foreground — transparent, glyph kept small so launcher
  //    masks (circle/squircle/rounded) never clip the hourglass.
  final fg = img.Image(width: _size, height: _size, numChannels: 4);
  _placeGlyph(fg, glyph, 0.48);
  _write('assets/icon/icon_adaptive_foreground.png', fg);

  // 4) Android adaptive background — the full gradient, no glyph.
  _write('assets/icon/icon_adaptive_background.png', _gradientTile(_size, _size));
}

/// An opaque [w]×[h] tile filled with the brand radial gradient.
img.Image _gradientTile(int w, int h) {
  final im = img.Image(width: w, height: h, numChannels: 4);
  final cx = 0.30 * w; // Alignment(-0.4, ..) -> (x+1)/2 = 0.30
  final cy = 0.25 * h; // Alignment(.., -0.5) -> (y+1)/2 = 0.25
  final radiusPx = 1.1 * math.min(w, h); // radius is a fraction of the shortest side
  const stop = 0.72; // the bottom colour stop
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final dx = x - cx, dy = y - cy;
      var t = (math.sqrt(dx * dx + dy * dy) / radiusPx) / stop;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
      im.setPixelRgba(
        x,
        y,
        (_topR + (_botR - _topR) * t).round(),
        (_topG + (_botG - _topG) * t).round(),
        (_topB + (_botB - _topB) * t).round(),
        255,
      );
    }
  }
  return im;
}

/// Composite [glyph] centred onto [base] at [scale] of the base width.
void _placeGlyph(img.Image base, img.Image glyph, double scale) {
  final target = (base.width * scale).round();
  final g = img.copyResize(glyph,
      width: target, height: target, interpolation: img.Interpolation.cubic);
  img.compositeImage(base, g,
      dstX: (base.width - target) ~/ 2, dstY: (base.height - target) ~/ 2);
}

/// Zero the alpha outside a rounded rectangle of corner radius [r] (1 px AA edge).
void _roundCorners(img.Image im, int r) {
  final w = im.width, h = im.height;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      double? ddx, ddy;
      if (x < r) {
        ddx = (r - x).toDouble();
      } else if (x >= w - r) {
        ddx = (x - (w - r) + 1).toDouble();
      }
      if (y < r) {
        ddy = (r - y).toDouble();
      } else if (y >= h - r) {
        ddy = (y - (h - r) + 1).toDouble();
      }
      if (ddx == null || ddy == null) continue; // not in a corner region
      final dist = math.sqrt(ddx * ddx + ddy * ddy);
      if (dist <= r - 1) continue;
      final p = im.getPixel(x, y);
      if (dist >= r) {
        p.a = 0;
      } else {
        p.a = (p.a * (r - dist)).round().clamp(0, 255);
      }
    }
  }
}

void _write(String path, img.Image im) {
  File(path).writeAsBytesSync(img.encodePng(im));
  stdout.writeln('wrote $path (${im.width}x${im.height})');
}
