/// Tidal deformation state for consumables near a black hole.
///
/// Models spaghettification: radial stretch, transverse compression,
/// mass shedding (visual shrink), and fragmentation along the tidal axis.
class TidalDeformState {
  const TidalDeformState({
    required this.intensity,
    required this.angle,
    required this.stretch,
    required this.transverseScale,
    required this.visualScale,
    required this.fragmentLevel,
    required this.disintegrationLevel,
  });

  final double intensity;
  final double angle;
  final double stretch;
  final double transverseScale;
  final double visualScale;
  final double fragmentLevel;
  final double disintegrationLevel;
}
