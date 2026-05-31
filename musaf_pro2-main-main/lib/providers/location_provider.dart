import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geocoding/geocoding.dart'; 

import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/zone_repository.dart';
enum TrackingState { initial, loading, tracking, error, connectionLost }

class LocationProvider with ChangeNotifier {
  final ZoneRepository _zoneRepository;
  TrackingState _trackingState = TrackingState.initial;
  TrackingState get trackingState => _trackingState;
  
  LocationProvider(this._zoneRepository);

  // --- الحالة الداخلية (Internal State) ---
  Position? _currentPosition;
  String _status = "جاري الاتصال...";
  bool _isTracking = false;
  String _patientName = "التابع";
  
  final Battery _battery = Battery();
  DateTime? _lastBatteryAlertTime;
  StreamSubscription<Position>? _positionStream;
  DateTime? _lastSignalAlertTime; 
  DateTime? _lastOutsideZoneAlertTime; 
  
  Timer? _signalTimer;
  DateTime? _lastUpdateTime;

  List<LatLng> _routePoints = [];
  List<SafeZone> _safeZones = [];

  String? _currentZoneId; 
  bool? _wasInSafeZone; 

  // --- Getters ---
  Position? get currentPosition => _currentPosition;
  String get status => _status;
  String get patientName => _patientName;
  bool get isTracking => _isTracking;
  List<LatLng> get routePoints => _routePoints;
  List<SafeZone> get safeZones => _safeZones;
  String? get currentZoneId => _currentZoneId;

  // --- إدارة البيانات ---
  Future<void> fetchPatientName(String patientId) async {
    try {
      _patientName = await _zoneRepository.getPatientName(patientId);
      notifyListeners();
    } catch (e) {
      _handleError("خطأ في جلب الاسم", e);
    }
  }

  Stream<List<Map<String, dynamic>>> getAlertsStream(String patientId) {
    return _zoneRepository.getPatientAlertsStream(patientId);
  }

  Future<void> markAsRead(String patientId, String alertId) async {
    await _zoneRepository.markAlertAsRead(patientId, alertId);
  }

  Future<void> clearAllAlerts(String patientId) async {
    await _zoneRepository.deleteAllAlerts(patientId);
  }

  Future<void> removeAlert(String patientId, String alertId) async {
    await _zoneRepository.deleteSingleAlert(patientId, alertId);
  }

  Future<void> loadSafeZones(String patientId) async {
    try {
      final zones = await _zoneRepository.getSafeZones(patientId);
      _safeZones = zones.map((e) => e as SafeZone).toList();
      notifyListeners();
    } catch (e) {
      _handleError("خطأ في تحميل المناطق", e);
    }
  }

  // 📝 دالة مساعدة ذكية لصياغة وتجهيز العناوين والمواقع الأخيرة بشكل مرتب ونظيف
 Future<String> _getFormattedAddress(Position? pos) async {
    if (pos == null) return "الموقع الحالي غير متوفر";

    try {
      // ✅ سطر واحد فقط لتعريف المتغير وجلب الإحداثيات
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude, 
        pos.longitude,
      ).timeout(const Duration(seconds: 4), onTimeout: () => <Placemark>[]);
      
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String> addressParts = [];
        
        if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
        if (place.street != null && place.street!.isNotEmpty && place.street != place.subLocality) addressParts.add(place.street!);
        
        if (addressParts.isNotEmpty) {
          return addressParts.join('، ');
        }
      }
      return "خط عرض: ${pos.latitude.toStringAsFixed(4)} | خط طول: ${pos.longitude.toStringAsFixed(4)}";
    } catch (e) {
      return "خط عرض: ${pos.latitude.toStringAsFixed(4)} | خط طول: ${pos.longitude.toStringAsFixed(4)}";
    }
  }

  // دالة مساعدة للحصول على اسم المنطقة الحالية أو الأخيرة بناءً على الـ ID
  String _getZoneNameById(String? zoneId) {
    if (zoneId == null) return "خارج المناطق المحددة";
    final zone = _safeZones.firstWhere((z) => z.id == zoneId, orElse: () => SafeZone(id: '', name: '', latitude: 0, longitude: 0, radius: 0));
    return zone.name.isNotEmpty ? zone.name : "منطقة غير معروفة";
  }

  // --- محرك التتبع الذكي المطور (Geofencing Engine) ---
Future<void> startPatientTracking(String patientId) async {
    // 1. لا نحتاج هنا لفحص صلاحيات الموقع الخاصة بالهاتف (لأننا نجلب البيانات من السحابة)
    
    if (_patientName == "التابع") {
      await fetchPatientName(patientId);
    }

    // إلغاء أي اشتراكات سابقة
    await _positionStream?.cancel();
    _signalTimer?.cancel();

    _isTracking = true;
    _status = "جاري الاتصال بجهاز التابع...";
    _trackingState = TrackingState.loading;
    _lastUpdateTime = DateTime.now();
    _lastSignalAlertTime = null;
    _lastOutsideZoneAlertTime = null;
    notifyListeners();

    // 2. الاستماع إلى تحديثات الموقع من Firebase (موقع التابع)
   _positionStream = FirebaseFirestore.instance
    .collection('patients')
    .doc(patientId)
    .snapshots()
    .listen(
  (snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data() as Map<String, dynamic>;
      
      final double lat = (data['latitude'] ?? 0.0).toDouble();
      final double lng = (data['longitude'] ?? 0.0).toDouble();

      // هذا الـ Constructor مصمم للإصدارات الحديثة من geolocator
      _currentPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        // هذه الحقول مطلوبة في الإصدارات الأخيرة من مكتبة geolocator:
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );

      _lastUpdateTime = DateTime.now();
      _trackingState = TrackingState.tracking;
      _status = "يتم تتبع $_patientName بنجاح 📍";
      
      _processLocationUpdate(_currentPosition!, patientId);
      notifyListeners();
    }
  },
  onError: (error) {
    debugPrint("Firebase Stream Error: $error");
    _status = "خطأ في الاتصال بجهاز التابع ⚠️";
    _trackingState = TrackingState.error;
    notifyListeners();
  },
) as StreamSubscription<Position>?;
    // 3. مؤقت فحص فقدان الإشارة (كما هو)
    _signalTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_lastUpdateTime != null) {
        int minutesSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!).inMinutes;

        if (minutesSinceLastUpdate >= 3) {
          _status = "فقدان الاتصال بجهاز $_patientName! 📡";
          _trackingState = TrackingState.connectionLost;
          notifyListeners();

          if (_lastSignalAlertTime == null || 
              DateTime.now().difference(_lastSignalAlertTime!).inMinutes >= 5) {
            
            String lastLocationAddress = await _getFormattedAddress(_currentPosition);
            String lastKnownZone = _getZoneNameById(_currentZoneId);

            await _zoneRepository.sendAlert(
              patientId, 
              "$_patientName 📡 تم فقدان الاتصال \n📌 آخر منطقة: $lastKnownZone\n📍 آخر موقع: $lastLocationAddress"
            );
            
            _lastSignalAlertTime = DateTime.now();
          }
        }
      }
    });
  

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, 
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        _lastUpdateTime = DateTime.now(); 
        _lastSignalAlertTime = null;
        
        if (_trackingState != TrackingState.tracking) {
          _trackingState = TrackingState.tracking; // 👈 إضافة: حالة التتبع النشط بنجاح
          notifyListeners();
        }
        
        _processLocationUpdate(position, patientId);
      },
      onError: (error) {
        _status = "خطأ في المستشعر ⚠️";
        _trackingState = TrackingState.error; // 👈 إضافة: حالة الخطأ
        _zoneRepository.sendAlert(patientId, "⚠️ [خطأ في النظام]: حدثت مشكلة في مستشعر الـ GPS الخاص بجهاز التابع: $error");
        notifyListeners();
      }
    );
  }

  void stopTracking() {
    _positionStream?.cancel();
    _signalTimer?.cancel();
    _isTracking = false;
    _status = "تم إيقاف التتبع"; 
    _trackingState = TrackingState.initial; // 👈 إضافة: العودة للحالة الابتدائية
    _currentZoneId = null;
    _wasInSafeZone = null;
    _lastOutsideZoneAlertTime = null;
    notifyListeners();
  }

  void _processLocationUpdate(Position pos, String patientId) async {
    _updateRoutePoints(pos);

    SafeZone? activeZone = _findCurrentActiveZone(pos);
    String? foundZoneId = activeZone?.id;

    if (_currentZoneId != foundZoneId) {
      await _handleZoneTransition(foundZoneId, activeZone, patientId, pos);
    } else if (_currentZoneId == null) {
      _checkContinuousOutsideAlert(pos, patientId);
    }

    _syncDataToCloud(pos, patientId);
  }

  void _updateRoutePoints(Position pos) {
    LatLng newPoint = LatLng(pos.latitude, pos.longitude);
    if (_routePoints.isEmpty || 
        Geolocator.distanceBetween(_routePoints.last.latitude, _routePoints.last.longitude, pos.latitude, pos.longitude) > 10) {
      _routePoints.add(newPoint);
      if (_routePoints.length > 50) _routePoints.removeAt(0);
    }
  }

  SafeZone? _findCurrentActiveZone(Position pos) {
    for (var zone in _safeZones) {
      if (zone.isActive) {
        double distance = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, zone.latitude, zone.longitude);
        if (distance <= zone.radius) return zone;
      }
    }
    return null;
  }

  Future<void> _handleZoneTransition(String? foundZoneId, SafeZone? activeZone, String patientId, Position pos) async {
    bool currentlyInSafe = foundZoneId != null;

    if (currentlyInSafe && activeZone != null) {
      _status = "في ${activeZone.name}";
      _lastOutsideZoneAlertTime = null; 
      
      if (_wasInSafeZone == false) {
        // الصياغة الجديدة لرسائل الأمان الفورية عند العودة للمنطقة الآمنة
        await _zoneRepository.sendAlert(patientId, "✅ عاد $_patientName إلى المنطقة الآمنة (${activeZone.name})");
      }
    } else {
      _status = "خارج النطاق! ";
      
      if (_wasInSafeZone == true || _wasInSafeZone == null) {
        String locationAddress = await _getFormattedAddress(pos);
        String leftZoneName = _getZoneNameById(_currentZoneId);

        // الصياغة الهندسية الجديدة لتنبيهات الخروج الفورية من النطاق
        await _zoneRepository.sendAlert(
          patientId, 
"🚨 خرج  $_patientName من النطاق الآمن ($leftZoneName).\n📍 الموقع: $locationAddress" );
_lastOutsideZoneAlertTime = DateTime.now();
      }
    }
    
    _currentZoneId = foundZoneId;
    _wasInSafeZone = currentlyInSafe;
    notifyListeners();
  }

  void _checkContinuousOutsideAlert(Position pos, String patientId) async {
    if (_lastOutsideZoneAlertTime != null && 
        DateTime.now().difference(_lastOutsideZoneAlertTime!).inMinutes >= 10) {
      
      String locationAddress = await _getFormattedAddress(pos);

      // الصياغة الخاصة بالتذكير التتابعي المستمر
      _zoneRepository.sendAlert(
        patientId, 
        "⏳ لا يزال $_patientName خارج المنطقة الآمنة \n📍 الموقع الحالي: $locationAddress"      );
      
      _lastOutsideZoneAlertTime = DateTime.now(); 
    }
  }

  Future<void> _syncDataToCloud(Position pos, String patientId) async {
    try {
      int batteryLevel = await _battery.batteryLevel;
      
      await _zoneRepository.updatePatientStatus(
        patientId: patientId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        batteryLevel: batteryLevel,
        isSafe: _currentZoneId != null,
        statusText: _status,
      );

      _checkBatteryAlert(batteryLevel, patientId);
    } catch (e) {
      _handleError("خطأ في المزامنة", e);
    }
  }

  void _checkBatteryAlert(int level, String patientId) {
    if (level < 20) {
      if (_lastBatteryAlertTime == null || 
          DateTime.now().difference(_lastBatteryAlertTime!).inMinutes > 15) {
        // الصياغة المحدثة لتنبيه البطارية الحرجة
        _zoneRepository.sendAlert(patientId, "🔋 [تحذير طاقة]: بطارية جهاز المريض ($_patientName) منخفضة جداً ووشكت على النفاد ($level%) يرجى شحن الهاتف فوراً لضمان استمرار التتبع");
        _lastBatteryAlertTime = DateTime.now();
      }
    }
  }

  Future<bool> _checkLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _status = "خدمات الموقع معطلة ⚠️";
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _status = "تم رفض صلاحية الموقع ⚠️";
        notifyListeners();
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _status = "الصلاحية مرفوضة نهائياً ⚠️";
      notifyListeners();
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        _status = "يتطلب صلاحية 'السماح طوال الوقت' 📡";
        notifyListeners();
        return false;
      }
    }

    return permission == LocationPermission.always;
  }

  void _handleError(String message, dynamic error) {
    debugPrint("$message: $error");
  }

  // --- عمليات CRUD الآمنة والمحدثة للمناطق ---
  Future<String> addNewSafeZone({
    required String patientId,
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      if (name.trim().isEmpty) {
        return "يرجى إدخال اسم صالح للمنطقة! ⚠️"; 
      }

      if (latitude == 0.0 && longitude == 0.0) {
        return "إحداثيات غير صالحة! يرجى تحديد موقع على الخريطة ⚠️";
      }

      if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        return "الإحداثيات الجغرافية المحددة خارج نطاق كوكب الأرض! ⚠️";
      }

      bool isZoneAlreadyExists = false;
      bool isOverlapping = false;

      for (var existingZone in _safeZones) {
        double distance = Geolocator.distanceBetween(
          latitude, 
          longitude, 
          existingZone.latitude, 
          existingZone.longitude
        );

        if (distance < 1.0) {
          isZoneAlreadyExists = true;
          break;
        }

        if (distance < (radius + existingZone.radius)) {
          isOverlapping = true;
        }
      }

      if (isZoneAlreadyExists) {
        return "هذه المنطقة مضافة بالفعل في حساب التابع! ⚠️"; 
      }

      if (isOverlapping) {
        return "خطأ: النطاق يتداخل مع منطقة آمنة أخرى! ⚠️"; 
      }

      final newZone = SafeZone(
        id: '', 
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        isActive: true,
      );
      
      await _zoneRepository.addSafeZone(patientId, newZone);
      await loadSafeZones(patientId); 
      
      return "تم إضافة المنطقة بنجاح ✅"; 
      
    } catch (e) {
      _handleError("خطأ في إضافة منطقة جديدة", e);
      return "حدث خطأ غير متوقع أثناء الحفظ ⚠️";
    }
  }

  Future<void> deleteSafeZone(int index, String patientId) async {
    if (index >= 0 && index < _safeZones.length) {
      try {
        final zoneId = _safeZones[index].id;
        await _zoneRepository.deleteSafeZone(patientId, zoneId);
        
        if (_currentZoneId == zoneId) {
          _currentZoneId = null;
          _status = "خارج النطاق! ";
        }

        await loadSafeZones(patientId);
      } catch (e) {
        _handleError("خطأ في حذف المنطقة", e);
      }
    }
  }

  Future<void> toggleZoneStatus(int index, String patientId, bool isActive) async {
    if (index < 0 || index >= _safeZones.length) return;
    
    final zone = _safeZones[index];

    try {
      _safeZones = List<SafeZone>.from(_safeZones);

      _safeZones[index] = zone.copyWith(isActive: isActive);
      notifyListeners();

      if (!isActive && _currentZoneId == zone.id) {
        _currentZoneId = null;
        _status = "خارج النطاق! ";
        notifyListeners();
      }

      await _zoneRepository.updateZoneStatus(patientId, zone.id, isActive);

    } catch (e) {
      _safeZones = List<SafeZone>.from(_safeZones);
      _safeZones[index] = zone.copyWith(isActive: !isActive);
      notifyListeners();
      _handleError("خطأ في تحديث حالة المنطقة", e);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _signalTimer?.cancel();
    super.dispose();
  }
}