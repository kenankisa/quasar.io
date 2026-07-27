import 'package:flutter/material.dart';

import '../../game/config/universe_card_photo.dart';
import '../../game/config/universe_palette.dart';
import '../../game/room_type.dart';

/// NASA deep-space photography — darkened, desaturated, tier-scaled void mood.
class UniverseCardPhotoBackground extends StatelessWidget {
  const UniverseCardPhotoBackground({
    super.key,
    required this.roomType,
    required this.locked,
    this.infernoTint = false,
    this.fullBleed = false,
  });

  final RoomType roomType;
  final bool locked;
  final bool infernoTint;

  /// Wide banner cards — photo covers edge-to-edge; card supplies its own gradients.
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final photo = UniverseCardPhoto.forRoom(roomType);
    final backdrop = UniverseCardPhoto.fallbackGradient(roomType);
    final lockedDarken = locked ? 0.18 : 0.0;
    final darkness = (photo.darkness + lockedDarken).clamp(0.0, 0.85);
    final imageAlignment = fullBleed
        ? (photo.bannerAlignment ?? photo.alignment)
        : photo.alignment;
    final crushScale = fullBleed
        ? switch (roomType) {
            RoomType.unique => 0.68,
            RoomType.simple => 0.66,
            _ => 0.38,
          }
        : 0.5;
    final crushAlpha = darkness * crushScale;

    Widget photoImage = Image.asset(
      photo.assetPath,
      fit: BoxFit.cover,
      alignment: imageAlignment,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backdrop,
          ),
        ),
      ),
    );
    if (photo.imageDarken > 0) {
      photoImage = ColorFiltered(
        colorFilter: ColorFilter.matrix(
          UniverseCardPhoto.brightnessMatrix(photo.imageDarken),
        ),
        child: photoImage,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.matrix(
              UniverseCardPhoto.saturationMatrix(photo.desaturate),
            ),
            child: photoImage,
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: crushAlpha),
          ),
        ),
        if (photo.tintAlpha > 0)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: fullBleed
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          photo.tint.withValues(
                            alpha: photo.tintAlpha * 0.65,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.52],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          photo.tint.withValues(alpha: photo.tintAlpha),
                          Colors.transparent,
                          photo.tint.withValues(alpha: photo.tintAlpha * 0.6),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
              ),
            ),
          ),
        if (!fullBleed)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.04),
                  ],
                  stops: const [0.0, 0.4, 0.75],
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(
                    alpha: fullBleed
                        ? switch (roomType) {
                            RoomType.unique => 0.26,
                            RoomType.simple => 0.26,
                            _ => 0.08,
                          }
                        : 0.14,
                  ),
                  Colors.transparent,
                  Colors.black.withValues(
                    alpha: fullBleed
                        ? switch (roomType) {
                            RoomType.unique => 0.46,
                            RoomType.simple => 0.44,
                            _ => UniversePalette.vignetteAlpha(roomType) * 0.28,
                          }
                        : UniversePalette.vignetteAlpha(roomType) * 0.3,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!fullBleed)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.08, 0.45),
                  radius: 0.95,
                  colors: [
                    Colors.black.withValues(alpha: 0.08 + darkness * 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        if (infernoTint || photo.warmEdge > 0)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    const Color(0xFF8A1808).withValues(
                      alpha: infernoTint
                          ? (fullBleed
                              ? photo.warmEdge * 0.55
                              : photo.warmEdge + 0.08)
                          : photo.warmEdge,
                    ),
                    Colors.transparent,
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
        if (locked)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.28),
            ),
          ),
      ],
    );
  }
}
