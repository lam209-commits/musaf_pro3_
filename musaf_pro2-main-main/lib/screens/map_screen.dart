import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/location_provider.dart';
import '../widgets/location_status_panel.dart';
import '../widgets/patient_marker.dart';
import '../widgets/add_zone_dialog.dart';

class MapScreen extends StatefulWidget {
  final String patientId;
  const MapScreen({super.key, required this.patientId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final Color primaryPurple = const Color(0xFF6C63FF);

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  void _initMapData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = context.read<LocationProvider>();
      pro.loadSafeZones(widget.patientId);
      pro.startPatientTracking(widget.patientId);
    });
  }

  Future<void> _navigateToPatient(double lat, double lng) async {
    final String googleMapsUrl = "google.navigation:q=$lat,$lng";
    final Uri uri = Uri.parse(googleMapsUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final String webUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Consumer<LocationProvider>(
        builder: (context, locProvider, child) {
          final patientPos = locProvider.currentPosition;
          LatLng? patientLatLng = patientPos != null 
              ? LatLng(patientPos.latitude, patientPos.longitude) 
              : null;

          bool isDanger = locProvider.status.contains("خارج") || locProvider.status.contains("⚠️");

          return Stack(
            children: [
              _buildMap(locProvider, patientLatLng, isDanger),
              if (patientLatLng != null) _buildFloatingControls(isDanger, patientLatLng),
              _buildBottomStatusPanel(locProvider.status, isDanger),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(LocationProvider locProvider, LatLng? patientLatLng, bool isDanger) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: patientLatLng ?? const LatLng(21.4225, 39.8262),
        initialZoom: 15.0,
        onLongPress: (tapPos, point) => _showAddZoneDialog(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.musaif.app',
        ),
        _buildSafeZonesLayer(locProvider, isDanger),
        _buildMarkersLayer(patientLatLng, isDanger),
      ],
    );
  }

  Widget _buildSafeZonesLayer(LocationProvider locProvider, bool isDanger) {
    return CircleLayer(
      circles: locProvider.safeZones.map((zone) => CircleMarker(
        point: LatLng(zone.latitude, zone.longitude),
        color: zone.isActive 
            ? (isDanger ? Colors.red.withOpacity(0.1) : primaryPurple.withOpacity(0.05))
            : Colors.grey.withOpacity(0.1),
        borderStrokeWidth: 2,
        borderColor: zone.isActive 
            ? (isDanger ? Colors.redAccent : primaryPurple.withOpacity(0.3))
            : Colors.grey,
        useRadiusInMeter: true,
        radius: zone.radius,
      )).toList(),
    );
  }

  Widget _buildMarkersLayer(LatLng? patientLatLng, bool isDanger) {
    return MarkerLayer(
      markers: [
        if (patientLatLng != null)
          Marker(
            point: patientLatLng,
            width: 120, height: 120,
            alignment: Alignment.topCenter,
            child: PatientMarker(isDanger: isDanger),
          ),
      ],
    );
  }
  
  void _showAddZoneDialog(LatLng point) {
    showDialog(
      context: context,
      builder: (ctx) => AddZoneDialog(point: point, patientId: widget.patientId),
    );
  }

  Widget _buildBottomStatusPanel(String status, bool isDanger) {
    return Positioned(
      bottom: 30, left: 15, right: 15,
      child: LocationStatusPanel(status: status, isDanger: isDanger),
    );
  }

  Widget _buildFloatingControls(bool isDanger, LatLng patientLatLng) {
    return Positioned(
      bottom: 150, right: 20,
      child: Column(
        children: [
          if (isDanger)
            FloatingActionButton.extended(
              heroTag: "nav",
              onPressed: () => _navigateToPatient(patientLatLng.latitude, patientLatLng.longitude),
              label: const Text("ملاحة سريعة", style: TextStyle(fontFamily: 'Cairo')),
              icon: const Icon(Icons.directions_car),
              backgroundColor: Colors.redAccent,
            ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "center",
            backgroundColor: Colors.white,
            onPressed: () => _mapController.move(patientLatLng, 17.0),
            child: Icon(Icons.center_focus_strong, color: primaryPurple),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('التتبع اللحظي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      centerTitle: true,
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
    );
  }
}