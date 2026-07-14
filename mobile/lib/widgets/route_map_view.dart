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

/// Mapa real (OpenStreetMap) com traço da rota, no estilo Strava/Google.
/// Com várias voltas, cada lap ganha uma cor e legenda numerada.
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
    this.showLapLegend = true,
  });

  final List<RoutePointView> points;
  /// Quando preenchido (≥2 voltas), desenha uma polyline colorida por volta.
  final List<RouteLapView> laps;
  final double height;
  final String? statusMessage;
  final bool followUser;
  /// Ponto azul ao vivo (último fix), mesmo antes de entrar na rota.
  final double? liveLatitude;
  final double? liveLongitude;
  final bool showLapLegend;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  static const _fallbackCenter = LatLng(-23.5505, -46.6333);
  static const _trailColor = Color(0xFFFC4C02); // laranja Strava

  final _mapController = MapController();
  LatLng? _lastFollowed;

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
    if (!widget.followUser) return;
    final next = _livePoint ??
        (widget.points.isNotEmpty ? widget.points.last.latLng : null);
    if (next == null) return;
    final prev = _lastFollowed;
    if (prev == null ||
        (prev.latitude - next.latitude).abs() > 0.0000003 ||
        (prev.longitude - next.longitude).abs() > 0.0000003) {
      _lastFollowed = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final zoom = widget.points.length <= 1
            ? 18.0
            : _mapController.camera.zoom;
        _mapController.move(next, zoom.clamp(16.0, 19.0));
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final latLngs = widget.points.map((p) => p.latLng).toList();
    final live = _livePoint;
    final center = live ?? (latLngs.isNotEmpty ? latLngs.last : _fallbackCenter);
    final status = widget.statusMessage;
    final polylines = _buildPolylines(latLngs);

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: latLngs.isEmpty && live == null ? 13 : 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                  // Ponto azul ao vivo (Google-style).
                  if (live != null)
                    Marker(
                      point: live,
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0x334285F4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4285F4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (latLngs.isNotEmpty)
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
          ),
          if (widget.showLapLegend && _useLaps)
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
                        final color =
                            Color(LapDetectorService.colorForLap(lap.lapNumber));
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
          if (status != null && status.isNotEmpty)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Material(
                color: const Color(0xCC0F172A),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ),
          if (live != null || latLngs.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: const Color(0xCC0F172A),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Centralizar em mim',
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final target = live ?? latLngs.last;
                    _mapController.move(target, 18);
                  },
                  icon: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
