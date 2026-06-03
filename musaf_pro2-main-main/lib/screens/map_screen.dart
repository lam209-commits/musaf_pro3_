import 'dart:io';

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

  bool _hasCentered = false; // 🛑 علم للتأكد من التمركز مرة واحدة

  @override
  void initState() {
    super.initState();
    _initMapData();
  }

  void _initMapData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pro = context.read<LocationProvider>();
      if (!pro.isTracking) {
        pro.loadSafeZones(widget.patientId);
        pro.startPatientTracking(widget.patientId);
      }
    });
  }

  // 🛑 1. إيقاف التتبع عند الخروج لمنع استنزاف الذاكرة والبطارية
  @override
  void dispose() {
    context.read<LocationProvider>().stopTracking();
    super.dispose();
  }

  // 🛑 4. التوجيه الذكي يدعم iOS و Android
  Future<void> _navigateToPatient(double lat, double lng) async {
    try {
      final uriAndroid = Uri.parse("google.navigation:q=$lat,$lng");
      final uriIOS = Uri.parse("https://maps.apple.com/?daddr=$lat,$lng");
      final uriWeb = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");

      if (Platform.isAndroid) {
        if (await canLaunchUrl(uriAndroid)) {
          await launchUrl(uriAndroid, mode: LaunchMode.externalApplication);
          return;
        }
      } else if (Platform.isIOS) {
        if (await canLaunchUrl(uriIOS)) {
          await launchUrl(uriIOS, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      // كحل احتياطي، يفتح المتصفح
      await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Navigation Error: $e");
    }
  }

  void _centerMapOnce(LatLng pos) {
    if (!_hasCentered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(pos, 16.0);
        _hasCentered = true;
      });
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
          
          // 🛑 9. معالجة حالة انتظار الموقع (بدلاً من الإحداثيات الافتراضية)
          if (patientPos == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryPurple),
                  const SizedBox(height: 15),
                  const Text("بانتظار تحديد موقع التابع...", 
                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ),
            );
          }

          final patientLatLng = LatLng(patientPos.latitude, patientPos.longitude);
          _centerMapOnce(patientLatLng); // 🛑 3. التمركز التلقائي

          // 🛑 2. منطق خطر حقيقي يعتمد على الحالة (State) وليس النصوص
          bool isDanger = locProvider.trackingState == TrackingState.connectionLost ||
                          locProvider.currentZoneId == null;

          return Stack(
            children: [
              _buildTrackingMap(locProvider, patientLatLng, isDanger),
              _buildFloatingControls(isDanger, patientLatLng),
              _buildBottomStatusPanel(locProvider.status, isDanger),
            ],
          );
        },
      ),
    );
  }

  // 🛑 10. فصل الخريطة وطبقاتها في دوال لترتيب الهيكل
  Widget _buildTrackingMap(LocationProvider locProvider, LatLng patientLatLng, bool isDanger) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: patientLatLng,
        initialZoom: 16.0,
        onLongPress: (tapPos, point) => _showAddZoneDialog(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.musaif.app',
        ),
        _buildRoutePolyline(locProvider), // 🛑 إضافة طبقة المسار التاريخي
        _buildSafeZonesLayer(locProvider),
        _buildPatientMarkerLayer(patientLatLng, isDanger),
      ],
    );
  }

  // 🛑 رسم مسار المريض التاريخي (Route Points)
  Widget _buildRoutePolyline(LocationProvider locProvider) {
    if (locProvider.routePoints.length < 2) return const SizedBox.shrink();
    return PolylineLayer(
      polylines: [
        Polyline(
          points: locProvider.routePoints,
          strokeWidth: 4.0,
          color: primaryPurple.withOpacity(0.7),
          isDotted: true,
        ),
      ],
    );
  }

  // 🛑 5. تصحيح ألوان المناطق الآمنة
  Widget _buildSafeZonesLayer(LocationProvider locProvider) {
    return CircleLayer(
      circles: locProvider.safeZones.map((zone) {
        final bool isCurrentZone = zone.id == locProvider.currentZoneId;
        
        return CircleMarker(
          point: LatLng(zone.latitude, zone.longitude),
          useRadiusInMeter: true,
          radius: zone.radius,
          color: isCurrentZone 
              ? Colors.green.withOpacity(0.15) 
              : primaryPurple.withOpacity(0.08),
          borderStrokeWidth: 2,
          borderColor: isCurrentZone ? Colors.green : primaryPurple.withOpacity(0.5),
        );
      }).toList(),
    );
  }

  Widget _buildPatientMarkerLayer(LatLng patientLatLng, bool isDanger) {
    return MarkerLayer(
      markers: [
        Marker(
          point: patientLatLng,
          width: 120, height: 120,
          alignment: Alignment.topCenter,
          child: PatientMarker(isDanger: isDanger),
        ),
      ],
    );
  }

  // 🛑 8. الاعتماد على النافذة المنبثقة لإضافة منطقة بدلاً من الإضافة المباشرة
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
      bottom: 140, right: 20,
      child: Column(
        children: [
          if (isDanger)
            FloatingActionButton.extended(
              heroTag: "nav",
              onPressed: () => _navigateToPatient(patientLatLng.latitude, patientLatLng.longitude),
              label: const Text("ملاحة سريعة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.directions_car),
              backgroundColor: Colors.redAccent,
            ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "center",
            backgroundColor: Colors.white,
            onPressed: () => _mapController.move(patientLatLng, 16.0),
            child: Icon(Icons.my_location, color: primaryPurple),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('التتبع اللحظي', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black87)),
      centerTitle: true,
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black87),
    );
  }
}