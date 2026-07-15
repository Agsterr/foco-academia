import 'dart:math' as math;

import 'package:flutter/material.dart';
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
  static const _trailColor = Color(0xFFFC4C02);

  final _mapController = MapController();
  LatLng? _lastFollowed;
  double? _lastRotation;

  LatLng? get _livePoint {
    final lat = widget.liveLatitude;
    final lng = widget.liveLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  bool get _useLaps =>
      widget.laps.length >= 2 &&
      widget.laps.any((l) => l.points.length >= 2);

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCamera();
  }

  void _syncCamera() {
    if (!widget.followUser) return;
    final next = _livePoint ??
        (widget.points.isNotEmpty ? widget.points.last.latLng : null);
    if (next == null) return;

    final heading = widget.headingDegrees;
    final wantRot =
        widget.rotateWithHeading && heading != null ? heading : 0.0;

    // Deadband: com GPS fraco (±30 m+) o ponto azul salta e a tela “fica doida”.
    // Só recentra a câmera com deslocamento real (não jitter do chip).
    final acc = widget.liveAccuracyMeters;
    final minMoveMeters = acc == null
        ? 3.0
        : acc > 35
            ? math.max(14.0, acc * 0.45)
            : acc > 25
                ? 8.0
                : 3.0;
    // ~1° lat ≈ 111 km → metros ≈ delta * 111000
    final minDeg = minMoveMeters / 111000.0;

    final moved = _lastFollowed == null ||
        (_lastFollowed!.latitude - next.latitude).abs() > minDeg ||
        (_lastFollowed!.longitude - next.longitude).abs() > minDeg;
    final rotated = _lastRotation == null ||
        (_lastRotation! - wantRot).abs() > 1.5;

    if (!moved && !rotated) return;

    _lastFollowed = next;
    _lastRotation = wantRot;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zoom = widget.points.length <= 1
          ? 18.0
          : _mapController.camera.zoom.clamp(16.0, 19.0);
      try {
        _mapController.moveAndRotate(next, zoom, -wantRot);
      } catch (_) {
        _mapController.move(next, zoom);
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
        for (final lap in widget.laps)
          if (lap.points.length >= 2)
            Polyline(
              points: lap.points.map((p) => p.latLng).toList(),
              strokeWidth: lap.lapNumber == widget.laps.last.lapNumber ? 6 : 4.5,
              color: Color(LapDetectorService.colorForLap(lap.lapNumber)),
              borderStrokeWidth: 1.5,
              borderColor: Colors.white,
            ),
      ];
    }
    if (flat.length >= 2) {
      return [
        Polyline(
          points: flat,
          strokeWidth: 5,
          color: _trailColor,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
      ];
    }
    final live = _livePoint;
    if (flat.length == 1 && live != null) {
      return [
        Polyline(
          points: [flat.first, live],
          strokeWidth: 5,
          color: _trailColor,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
      ];
    }
    return const [];
  }

  Marker _buildLiveMarker(LatLng live) {
    final heading = widget.headingDegrees;
    return Marker(
      point: live,
      width: 48,
      height: 48,
      child: Transform.rotate(
        // Seta aponta para frente do celular; no modo bússola o mapa já gira.
        angle: widget.rotateWithHeading
            ? 0
            : ((heading ?? 0) * mathPi / 180.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0x334285F4),
                shape: BoxShape.circle,
              ),
            ),
            if (heading != null)
              const Icon(
                Icons.navigation,
                color: Color(0xFF4285F4),
                size: 28,
              )
            else
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const mathPi = 3.141592653589793;

  @override
  Widget build(BuildContext context) {
    final latLngs = widget.points.map((p) => p.latLng).toList();
    final live = _livePoint;
    final center = live ?? (latLngs.isNotEmpty ? latLngs.last : _fallbackCenter);
    final status = widget.statusMessage;
    final polylines = _buildPolylines(latLngs);
    final mapHeight =
        widget.expanded ? MediaQuery.sizeOf(context).height : widget.height;

    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: latLngs.isEmpty && live == null ? 13 : 18,
        initialRotation: widget.rotateWithHeading && widget.headingDegrees != null
            ? -(widget.headingDegrees!)
            : 0,
        interactionOptions: InteractionOptions(
          flags: widget.expanded
              ? InteractiveFlag.all
              : (InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.focodev.academia.aluno',
          maxNativeZoom: 19,
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        MarkerLayer(
          markers: [
            if (latLngs.isNotEmpty && latLngs.length >= 2)
              Marker(
                point: latLngs.first,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            if (live != null) _buildLiveMarker(live),
            if (live == null && latLngs.isNotEmpty)
              Marker(
                point: latLngs.last,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: _useLaps
                        ? Color(
                            LapDetectorService.colorForLap(
                              widget.laps.last.lapNumber,
                            ),
                          )
                        : _trailColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return Container(
      height: widget.expanded ? mapHeight : widget.height,
      width: double.infinity,
      decoration: widget.expanded
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.expanded ? null : widget.onToggleExpand,
              child: map,
            ),
          ),
          if (widget.showLapLegend && _useLaps && !widget.expanded)
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: const Color(0xCC0F172A),
                borderRadius: BorderRadius.circular(8),
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
          // Controles: bússola, centralizar, expandir/minimizar
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
                      final target = live ?? latLngs.last;
                      final zoom = 18.0;
                      final rot = widget.rotateWithHeading &&
                              widget.headingDegrees != null
                          ? -(widget.headingDegrees!)
                          : 0.0;
                      try {
                        _mapController.moveAndRotate(target, zoom, rot);
                      } catch (_) {
                        _mapController.move(target, zoom);
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
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: widget.hud!,
            )
          else if (status != null && status.isNotEmpty && !widget.expanded)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Material(
                color: const Color(0xCC0F172A),
                borderRadius: BorderRadius.circular(8),
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
                color: const Color(0x990F172A),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Toque para mapa grande',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ),
              ),
            ),
        ],
      ),
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
      color: active ? const Color(0xE02563EB) : const Color(0xCC0F172A),
      shape: const CircleBorder(),
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
