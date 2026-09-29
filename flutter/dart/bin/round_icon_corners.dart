// Bake iOS's rounded-square mask into a PNG's alpha, for the one place that cannot clip: a launch screen storyboard's image view.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

/// Apple's own icon corner ratio — the radius is this share of the side.
const double _defaultRadiusRatio = 0.2237;

/// Coverage samples per axis inside one pixel. Four is enough to keep the curve from stepping, and cheap on an image this small.
const int _samples = 4;

void main(List<String> args) {
  final List<String> positional = args
      .where((String a) => !a.startsWith('--'))
      .toList();

  if (positional.length != 3) {
    stderr.writeln(
      'usage: dart run <script-tools>/flutter/dart/bin/round_icon_corners.dart <src.png> <out.png> <size> '
      '[--radius-ratio 0.2237]',
    );
    exitCode = 64;

    return;
  }

  final int size = int.parse(positional[2]);
  final double ratio = _flag(args, '--radius-ratio') ?? _defaultRadiusRatio;
  final Image? source = decodePng(File(positional[0]).readAsBytesSync());

  if (source == null) {
    stderr.writeln('not a png: ${positional[0]}');
    exitCode = 65;

    return;
  }

  final Image square = copyResize(
    source.numChannels == 4 ? source : source.convert(numChannels: 4),
    width: size,
    height: size,
    interpolation: Interpolation.cubic,
  );

  _mask(square, size * ratio);
  File(positional[1]).writeAsBytesSync(encodePng(square));
  stdout.writeln('${positional[1]}  ${size}px  r=${(size * ratio).round()}');
}

/// Multiplies each pixel's alpha by how much of it falls inside the rounded square.
void _mask(Image image, double radius) {
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final double coverage = _coverage(x, y, image.width, radius);

      if (coverage >= 1) continue;

      final Pixel pixel = image.getPixel(x, y);

      image.setPixelRgba(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        (pixel.a * coverage).round(),
      );
    }
  }
}

/// The share of pixel [x],[y] inside the rounded square, by supersampling — a hard in/out test leaves the curve visibly stepped.
double _coverage(int x, int y, int side, double radius) {
  int inside = 0;

  for (int sy = 0; sy < _samples; sy++) {
    for (int sx = 0; sx < _samples; sx++) {
      final double px = x + (sx + 0.5) / _samples;
      final double py = y + (sy + 0.5) / _samples;

      if (_isInside(px, py, side.toDouble(), radius)) inside++;
    }
  }

  return inside / (_samples * _samples);
}

/// Outside the corner boxes every point is in; inside one, it is in when it falls within the corner's circle.
bool _isInside(double x, double y, double side, double radius) {
  final double cx = x < radius
      ? radius
      : (x > side - radius ? side - radius : x);
  final double cy = y < radius
      ? radius
      : (y > side - radius ? side - radius : y);

  if (cx == x || cy == y) return true;

  final double dx = x - cx;
  final double dy = y - cy;

  return math.sqrt(dx * dx + dy * dy) <= radius;
}

double? _flag(List<String> args, String name) {
  final int at = args.indexOf(name);

  return at == -1 || at + 1 >= args.length ? null : double.parse(args[at + 1]);
}
