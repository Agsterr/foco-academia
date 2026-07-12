import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RoutePointView {
  const RoutePointView({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);
}

/// Mapa real (OpenStreetMap) com traço da rota, no estilo Strava/Google.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.height = 280,
    this.statusMessage,
    this.followUser = true,
    this.liveLatitude,
    this.liveLongitude,
  });

  final List<RoutePointView> points;
  final double height;
  final String? statusMessage;
  final bool followUser;
  /// Ponto azul ao vivo (último fix), mesmo antes de entrar na rota.
  final double? liveLatitude;
  final double? liveLongitude;

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

  @override
  Widget build(BuildContext context) {
    final latLngs = widget.points.map((p) => p.latLng).toList();
    final live = _livePoint;
    final center = live ?? (latLngs.isNotEmpty ? latLngs.last : _fallbackCenter);
    final status = widget.statusMessage;

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
              if (latLngs.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: latLngs,
                      strokeWidth: 5,
                      color: _trailColor,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                )
              else if (latLngs.length == 1 && live != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [latLngs.first, live],
                      strokeWidth: 5,
                      color: _trailColor,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
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
                            decoration: BoxDecoration(
                              color: const Color(0x334285F4),
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
                          color: _trailColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
            ],
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
