import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/tokens.dart';

enum ObservatoryArtworkKind { globe, temperatureHorizon, precipitationHorizon }

/// Supplied AI-generated decoration, never an observation or location image.
/// The parent bounds the artwork; it cannot intercept gestures or add semantics.
class ObservatoryArtwork extends StatelessWidget {
  const ObservatoryArtwork({super.key, required this.kind});

  final ObservatoryArtworkKind kind;

  static const globeAsset = 'assets/observatory/earth_globe.webp';
  static const horizonAsset = 'assets/observatory/earth_horizon.webp';

  // Bounded for primary-text contrast even over a white artwork pixel.
  static const maxHorizonAlpha = 70;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final globe = kind == ObservatoryArtworkKind.globe;
            final rain = kind == ObservatoryArtworkKind.precipitationHorizon;
            final aspect = globe ? 960 / 720 : 1440 / 810;
            final decodeWidth =
                (math.max(
                          constraints.maxWidth,
                          constraints.maxHeight * aspect,
                        ) *
                        MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, globe ? 960 : 1440);
            Widget artwork = Image.asset(
              globe ? globeAsset : horizonAsset,
              fit:
                  globe && constraints.maxWidth / constraints.maxHeight > aspect
                  ? BoxFit.contain
                  : BoxFit.cover,
              alignment: rain ? const Alignment(.6, .12) : Alignment.center,
              cacheWidth: decodeWidth,
              excludeFromSemantics: true,
              filterQuality: FilterQuality.medium,
            );
            if (rain) {
              artwork = ColorFiltered(
                colorFilter: ColorFilter.mode(
                  AppColors.amber.withAlpha(85),
                  BlendMode.srcATop,
                ),
                child: artwork,
              );
            }
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => globe
                  ? const RadialGradient(
                      radius: .5,
                      colors: [Colors.white, Colors.white, Colors.transparent],
                      stops: [0, .7, 1],
                    ).createShader(bounds)
                  : LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withAlpha(rain ? 38 : maxHorizonAlpha),
                        Colors.transparent,
                      ],
                      stops: const [0, .72, 1],
                    ).createShader(bounds),
              child: globe
                  ? artwork
                  : ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0, .2, .8, 1],
                      ).createShader(bounds),
                      child: artwork,
                    ),
            );
          },
        ),
      ),
    ),
  );
}
