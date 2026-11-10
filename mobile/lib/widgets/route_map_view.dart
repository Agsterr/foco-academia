import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/lap_detector_service.dart';

class RoutePointView {
  const RoutePointView({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);
}

class RouteLapView {
  const RouteLapView({
    required this.lapNumber,
    required this.points,
    this.distanceMeters = 0,
  });

  final int lapNumber;
  final List<RoutePointView> points;
  final double distanceMeters;
}

/// Mapa OpenStreetMap com traço da rota, bússola e modo tela cheia.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.laps = const [],
    this.height = 280,
    this.statusMessage,
    this.followUser = true,
    this.liveLatitude,
    this.liveLongitude,
    this.liveAccuracyMeters,
    this.showLapLegend = true,
    this.headingDegrees,
    this.rotateWithHeading = false,
    this.expanded = false,
    this.onToggleExpand,
    this.onToggleCompass,
    this.hud,
  });

  final List<RoutePointView> points;
  final List<RouteLapView> laps;
  final double height;
  final String? statusMessage;
  final bool followUser;
  final double? liveLatitude;
  final double? liveLongitude;

  /// Accuracy do fix ao vivo — com GPS fraco a câmera não persegue jitter.
  final double? liveAccuracyMeters;
  final bool showLapLegend;

  /// Direção atual (0–360). Gira o mapa no modo bússola.
  final double? headingDegrees;

  /// Mapa “para cima” = direção do celular (como na tela de bloqueio).
  final bool rotateWithHeading;

  /// Ocupa a tela inteira (esconde o resto do treino).
  final bool expanded;

  final VoidCallback? onToggleExpand;
  final VoidCallback? onToggleCompass;

  /// Painel flutuante (tempo, km, ritmo…) no modo expandido.
  final Widget? hud;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  static const _fallbackCenter = LatLng(-23.5505, -46.6333);
  static const _mapBg = AppTheme.background;

  /// Gradiente neon da rota: começa azul e termina laranja (início → fim do percurso).
  static const _trailGradient = [AppTheme.cyan, AppTheme.violet, AppTheme.pink, AppTheme.orange];

  /// Inverte as cores do mapa e gira o matiz 180° (ruas claras sobre fundo escuro).
  static const _darkMapFilter = ColorFilter.matrix(<double>[
    0.574, -1.430, -0.144, 0, 255,
    -0.426, -0.430, -0.144, 0, 255,
    -0.426, -1.430, 0.856, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  /// Fundo translúcido dos quadros sobre o mapa (legenda, avisos, botões).
  static const _glass = Color(0xD915142B);

  final _mapController = MapController();
  LatLng? _lastFollowed;
  double? _lastRotation;
  bool _mapReady = false;

  LatLng? get _livePoint {
    final lat = widget.liveLatitude;
    final lng = widget.liveLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  bool get _useLaps =>
      widget.laps.length >= 2 &&
      widget.laps.any((l) => l.points.length >= 2);

  static double _headingDeltaAbs(double a, double b) {
    var d = (b - a).abs() % 360.0;
    if (d > 180) d = 360 - d;
    return d;
  }

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      // Remount/resize: força redesenho dos tiles após o layout.
      _lastFollowed = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) return;
        _forceRefreshAfterResize();
      });
    }
    _syncCamera();
  }

  void _onMapReady() {
    _mapReady = true;
    _syncCamera(force: true);
  }

  void _forceRefreshAfterResize() {
    try {
      final cam = _mapController.camera;
      final target = _livePoint ??
          (widget.points.isNotEmpty ? widget.points.last.latLng : cam.center);
      final heading = widget.headingDegrees;
      final rot = widget.rotateWithHeading && heading != null ? -heading : 0.0;
      _mapController.moveAndRotate(target, cam.zoom.clamp(16.0, 19.0), rot);
    } catch (_) {
      // Controller ainda não anexado — onMapReady cuida.
    }
  }

  void _syncCamera({bool force = false}) {
    if (!widget.followUser || !_mapReady) return;
    final next = _livePoint ??
        (widget.points.isNotEmpty ? widget.points.last.latLng : null);
    if (next == null) return;

    final heading = widget.headingDegrees;
    final wantRot =
        widget.rotateWithHeading && heading != null ? heading : 0.0;

    // Deadband: com GPS fraco (±30 m+) o ponto azul salta e a tela “fica doida”.
    final acc = widget.liveAccuracyMeters;
    final minMoveMeters = acc == null
        ? 3.0
        : acc > 35
            ? math.max(14.0, acc * 0.45)
            : acc > 25
                ? 8.0
                : 3.0;
    final minDeg = minMoveMeters / 111000.0;

    final moved = force ||
        _lastFollowed == null ||
        (_lastFollowed!.latitude - next.latitude).abs() > minDeg ||
        (_lastFollowed!.longitude - next.longitude).abs() > minDeg;
    // Bússola: deadband baixo — heading já vem suavizado (gyro+mag).
    final rotDeadband = widget.rotateWithHeading ? 0.35 : 1.5;
    final rotated = force ||
        _lastRotation == null ||
        _headingDeltaAbs(_lastRotation!, wantRot) > rotDeadband;

    if (!moved && !rotated) return;

    _lastFollowed = next;
    _lastRotation = wantRot;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      double zoom = 18.0;
      try {
        zoom = widget.points.length <= 1
            ? 18.0
            : _mapController.camera.zoom.clamp(16.0, 19.0);
      } catch (_) {
        zoom = 18.0;
      }
      try {
        _mapController.moveAndRotate(next, zoom, -wantRot);
      } catch (_) {
        try {
          _mapController.move(next, zoom);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<Polyline> _buildPolylines(List<LatLng> flat) {
    if (_useLaps) {
      return [
        // Brilho embaixo de cada volta.
        for (final lap in widget.laps)
          if (lap.points.length >= 2)
            Polyline(
              points: lap.points.map((p) => p.latLng).toList(),
              strokeWidth: 16,
              color: Color(LapDetectorService.colorForLap(lap.lapNumber)).withValues(alpha: 0.22),
            ),
        for (final lap in widget.laps)
          if (lap.points.length >= 2)
            Polyline(
              points: lap.points.map((p) => p.latLng).toList(),
              strokeWidth: lap.lapNumber == widget.laps.last.lapNumber ? 6.5 : 5,
              color: Color(LapDetectorService.colorForLap(lap.lapNumber)),
              borderStrokeWidth: 1.5,
              borderColor: const Color(0xCC0B0A1A),
            ),
      ];
    }
    if (flat.length >= 2) {
      return [
        // Brilho neon largo e translúcido, com a linha principal em gradiente por cima.
        Polyline(
          points: flat,
          strokeWidth: 18,
          color: AppTheme.violet.withValues(alpha: 0.18),
        ),
        Polyline(
          points: flat,
          strokeWidth: 10,
          gradientColors: [for (final c in _trailGradient) c.withValues(alpha: 0.35)],
        ),
        Polyline(
          points: flat,
          strokeWidth: 5.5,
          gradientColors: _trailGradient,
          borderStrokeWidth: 1.2,
          borderColor: const Color(0xCC0B0A1A),
        ),
      ];
    }
    // 1 ponto + live: só marcadores (evita “corda” start→atual).
    return const [];
  }

  Marker _buildLiveMarker(LatLng live) {
    final heading = widget.headingDegrees;
    return Marker(
      point: live,
      width: 48,
      height: 48,
      child: Transform.rotate(
        // No modo bússola o mapa já gira com o heading; seta fica “pra cima”.
        // Fora dele, a seta gira no mapa north-up (rumo GPS ou bússola).
        angle: widget.rotateWithHeading
            ? 0
            : ((heading ?? 0) * math.pi / 180.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo em volta da posição atual.
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.cyan.withValues(alpha: 0.45), AppTheme.cyan.withValues(alpha: 0)],
                ),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.cyan, AppTheme.violet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: heading != null
                  ? const Icon(Icons.navigation_rounded, color: Colors.white, size: 15)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latLngs = widget.points.map((p) => p.latLng).toList();
    final live = _livePoint;
    final center = live ?? (latLngs.isNotEmpty ? latLngs.last : _fallbackCenter);
    final status = widget.statusMessage;
    final polylines = _buildPolylines(latLngs);

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: latLngs.isEmpty && live == null ? 13 : 18,
        initialRotation:
            widget.rotateWithHeading && widget.headingDegrees != null
                ? -(widget.headingDegrees!)
                : 0,
        backgroundColor: _mapBg,
        onMapReady: _onMapReady,
        interactionOptions: InteractionOptions(
          flags: widget.expanded
              ? InteractiveFlag.all
              : (InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
      ),
      children: [
        // Mapa escuro (um filtro só sobre a camada inteira, mais leve que filtrar cada bloco):
        // a rota neon chama mais atenção.
        ColorFiltered(
          colorFilter: _darkMapFilter,
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.focodev.academia.aluno',
            maxNativeZoom: 19,
          ),
        ),
        // Leve tom violeta da marca sobre o mapa.
        IgnorePointer(child: ColoredBox(color: AppTheme.brandDeep.withValues(alpha: 0.10))),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(
          markers: [
            if (latLngs.isNotEmpty && latLngs.length >= 2)
              Marker(
                point: latLngs.first,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.freshGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.flag_rounded, color: Colors.white, size: 15),
                ),
              ),
            if (live != null) _buildLiveMarker(live),
            if (live == null && latLngs.isNotEmpty)
              Marker(
                point: latLngs.last,
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: _useLaps
                        ? Color(
                            LapDetectorService.colorForLap(
                              widget.laps.last.lapNumber,
                            ),
                          )
                        : null,
                    gradient: _useLaps ? null : AppTheme.fireGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.sports_score_rounded, color: Colors.white, size: 17),
                ),
              ),
          ],
        ),
      ],
    );

    final stack = Stack(
      fit: StackFit.expand,
      children: [
        // Fundo enquanto os tiles carregam (evita “tela branca”).
        const ColoredBox(color: _mapBg),
        map,
        if (widget.showLapLegend && _useLaps && !widget.expanded)
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: _glass,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.laps.length} volta${widget.laps.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...widget.laps.map((lap) {
                      final color = Color(
                        LapDetectorService.colorForLap(lap.lapNumber),
                      );
                      final km = lap.distanceMeters / 1000.0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white54),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Volta ${lap.lapNumber}'
                              '${km >= 0.05 ? ' · ${km.toStringAsFixed(2)} km' : ''}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          top: widget.expanded ? MediaQuery.paddingOf(context).top + 8 : 8,
          right: 8,
          child: Column(
            children: [
              if (widget.onToggleExpand != null)
                _MapFab(
                  tooltip: widget.expanded
                      ? 'Minimizar mapa'
                      : 'Mapa em tela cheia',
                  icon: widget.expanded
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  onPressed: widget.onToggleExpand!,
                ),
              if (widget.onToggleCompass != null) ...[
                const SizedBox(height: 8),
                _MapFab(
                  tooltip: widget.rotateWithHeading
                      ? 'Norte para cima'
                      : 'Girar com o celular',
                  icon: widget.rotateWithHeading
                      ? Icons.explore
                      : Icons.explore_outlined,
                  active: widget.rotateWithHeading,
                  onPressed: widget.onToggleCompass!,
                ),
              ],
              if (live != null || latLngs.isNotEmpty) ...[
                const SizedBox(height: 8),
                _MapFab(
                  tooltip: 'Centralizar em mim',
                  icon: Icons.my_location,
                  onPressed: () {
                    if (!_mapReady) return;
                    final target = live ?? latLngs.last;
                    const zoom = 18.0;
                    final rot = widget.rotateWithHeading &&
                            widget.headingDegrees != null
                        ? -(widget.headingDegrees!)
                        : 0.0;
                    try {
                      _mapController.moveAndRotate(target, zoom, rot);
                    } catch (_) {
                      try {
                        _mapController.move(target, zoom);
                      } catch (_) {}
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        if (widget.hud != null && widget.expanded)
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
            child: widget.hud!,
          )
        else if (status != null && status.isNotEmpty && !widget.expanded)
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Material(
              color: _glass,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        if (!widget.expanded && widget.onToggleExpand != null)
          Positioned(
            left: 10,
            bottom: status != null && status.isNotEmpty ? 44 : 10,
            child: Material(
              color: _glass,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fullscreen_rounded, color: Colors.white70, size: 14),
                    SizedBox(width: 4),
                    Text('Mapa em tela cheia', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.expanded) {
      return ColoredBox(
        color: _mapBg,
        child: stack,
      );
    }

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.45), width: 1.4),
        color: _mapBg,
      ),
      clipBehavior: Clip.antiAlias,
      child: stack,
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppTheme.brand : _RouteMapViewState._glass,
      shape: const CircleBorder(side: BorderSide(color: Color(0x33FFFFFF))),
      child: IconButton(
        tooltip: tooltip,
        iconSize: 22,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(),
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}
