import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RoutePointView {
  const RoutePointView({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);
}

/// Mapa real (OpenStreetMap) com traço da rota, no estilo Strava.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.height = 280,
    this.statusMessage,
    this.followUser = true,
  });

  final List<RoutePointView> points;
  final double height;
  final String? statusMessage;
  final bool followUser;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  static const _fallbackCenter = LatLng(-23.5505, -46.6333);
  static const _trailColor = Color(0xFFFC4C02); // laranja Strava

  final _mapController = MapController();
  LatLng? _lastFollowed;

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.followUser || widget.points.isEmpty) return;
    final next = widget.points.last.latLng;
    final prev = _lastFollowed;
    if (prev == null ||
        prev.latitude != next.latitude ||
        prev.longitude != next.longitude) {
      _lastFollowed = next;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final zoom = widget.points.length == 1 ? 17.0 : _mapController.camera.zoom;
        _mapController.move(next, zoom.clamp(15.0, 18.0));
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
    final center = latLngs.isNotEmpty ? latLngs.last : _fallbackCenter;
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
              initialZoom: latLngs.isEmpty ? 13 : 17,
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
                ),
              if (latLngs.isNotEmpty)
                MarkerLayer(
                  markers: [
                    if (latLngs.length >= 2)
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
                    Marker(
                      point: latLngs.last,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _trailColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
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
          if (latLngs.isNotEmpty)
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
                    _mapController.move(latLngs.last, 17);
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
