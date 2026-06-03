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
  DateTime? _lastSeen; // 👈 إضافة تتبع لآخر ظهور للمريض

  final Battery _battery = Battery();
  int _lastAlertedBatteryLevel = 100; // 👈 تتبع مستوى البطارية لمنع تكرار الإزعاج

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _locationSubscription;

  DateTime? _lastSignalAlertTime;
  Position? _lastAlertedOutsidePosition; // 👈 تتبع آخر موقع تم التنبيه فيه بالخارج (لشرط الـ 10 متر)

  Timer? _signalTimer;
  DateTime? _lastUpdateTime;

  final List<LatLng> _routePoints = [];
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
  DateTime? get lastSeen => _lastSeen;

  // --- إدارة البيانات ---
  Future fetchPatientName(String patientId) async {
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

  Future markAsRead(String patientId, String alertId) async {
    await _zoneRepository.markAlertAsRead(patientId, alertId);
  }

  Future clearAllAlerts(String patientId) async {
    await _zoneRepository.deleteAllAlerts(patientId);
  }

  Future removeAlert(String patientId, String alertId) async {
    await _zoneRepository.deleteSingleAlert(patientId, alertId);
  }

  Future loadSafeZones(String patientId) async {
    try {
      final zones = await _zoneRepository.getSafeZones(patientId);
      _safeZones = zones.map((e) => e).toList();
      notifyListeners();
    } catch (e) {
      _handleError("خطأ في تحميل المناطق", e);
    }
  }

  // 📝 دالة مساعدة ذكية لصياغة وتجهيز العناوين والمواقع
  Future<String> _getFormattedAddress(Position? pos) async {
    if (pos == null) return "الموقع الحالي غير متوفر";
    try {
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

  String _getZoneNameById(String? zoneId) {
    if (zoneId == null) return "خارج المناطق المحددة";
    final zone = _safeZones.firstWhere(
      (z) => z.id == zoneId,
      orElse: () => SafeZone(id: '', name: '', latitude: 0, longitude: 0, radius: 0),
    );
    return zone.name.isNotEmpty ? zone.name : "منطقة غير معروفة";
  }

  // --- محرك التتبع الذكي المطور (Geofencing Engine) ---
  Future startPatientTracking(String patientId) async {
    if (_patientName == "التابع") {
      await fetchPatientName(patientId);
    }

    await _locationSubscription?.cancel();
    _signalTimer?.cancel();

    _isTracking = true;
    _status = "جاري الاتصال بجهاز التابع...";
    _trackingState = TrackingState.loading;
    _lastUpdateTime = DateTime.now();
    _lastSignalAlertTime = null;
    _lastAlertedOutsidePosition = null;
    notifyListeners();

    // 🚀 التعديل الأهم لحل مشكلة الخريطة: الاستماع من مجموعة patients وقراءة الحقول الصحيحة
    _locationSubscription = FirebaseFirestore.instance
        .collection('patients')
        .doc(patientId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          
          // قراءة ذكية لتفادي أي خطأ في تسمية المتغيرات بقاعدة البيانات
          final double lat = (data['latitude'] ?? data['last_latitude'] ?? 0.0).toDouble();
          final double lng = (data['longitude'] ?? data['last_longitude'] ?? 0.0).toDouble();
          
          // تحديث آخر ظهور إذا كان متاحاً
          if (data['lastSeen'] != null && data['lastSeen'] is Timestamp) {
            _lastSeen = (data['lastSeen'] as Timestamp).toDate();
          }

          if (lat == 0.0 && lng == 0.0) return;

          _currentPosition = Position(
            latitude: lat,
            longitude: lng,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
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
      }
    );

    // مؤقت فحص فقدان الإشارة
    _signalTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_lastSeen != null) {
        int minutesSinceLastSeen = DateTime.now().difference(_lastSeen!).inMinutes;

        if (minutesSinceLastSeen >= 3) {
          // حالة: فقدان الاتصال
          _status = "فقدان الاتصال بجهاز $_patientName! 📡";
          _trackingState = TrackingState.connectionLost;
          notifyListeners();

          // المنطق المطلوب:
          // 1. إذا كان المريض ثابتاً: نرسل تنبيهاً واحداً فقط.
          // 2. إذا كان المريض يتحرك: نرسل تنبيهاً كل 5 دقائق.
          
          bool shouldAlert = false;

          if (_lastSignalAlertTime == null) {
            // التنبيه الأول دائماً يرسل
            shouldAlert = true;
          } else {
            // حساب المسافة بين آخر موقع تم التنبيه عنده والموقع الحالي (في حال عاد الاتصال فجأة)
            // إذا كان المريض لا يزال في نفس المكان تقريباً، لا نرسل تنبيهات مكررة
            double dist = Geolocator.distanceBetween(
              _lastAlertedOutsidePosition?.latitude ?? 0, 
              _lastAlertedOutsidePosition?.longitude ?? 0,
              _currentPosition?.latitude ?? 0, 
              _currentPosition?.longitude ?? 0
            );

            // إذا مر 5 دقائق AND (المريض تحرك أكثر من 20 متر)
            if (DateTime.now().difference(_lastSignalAlertTime!).inMinutes >= 5 && dist > 20) {
              shouldAlert = true;
            }
          }

          if (shouldAlert) {
            String lastLocationAddress = await _getFormattedAddress(_currentPosition);
            await _zoneRepository.sendAlert(
              patientId,
              "📡 تنبيه فقدان اتصال مع $_patientName.\n📍 آخر موقع تم رصده: $lastLocationAddress\n⚠️ الجهاز لا يرسل تحديثات منذ $minutesSinceLastSeen دقائق."
            );
            _lastSignalAlertTime = DateTime.now();
            _lastAlertedOutsidePosition = _currentPosition; // تحديث موقع آخر تنبيه
          }
        } 
        // استعادة الحالة إذا عادت الإشارة
        else if (_trackingState == TrackingState.connectionLost) {
             _trackingState = TrackingState.tracking;
             _status = "يتم تتبع $_patientName بنجاح 📍";
             notifyListeners();
        }
      }
    });
  }

  void stopTracking() {
    _locationSubscription?.cancel();
    _signalTimer?.cancel();
    _isTracking = false;
    _status = "تم إيقاف التتبع";
    _trackingState = TrackingState.initial;
    _currentZoneId = null;
    _wasInSafeZone = null;
    _lastAlertedOutsidePosition = null;
    notifyListeners();
  }// 1. معالجة الموقع بشكل دقيق (هذا هو المدخل الرئيسي لتحديثات Firebase)
  void _processLocationUpdate(Position pos, String patientId) async {
    _updateRoutePoints(pos);
    
    SafeZone? activeZone = _findCurrentActiveZone(pos);
    
    if (activeZone != null) {
      // 🟢 المريض داخل منطقة آمنة
      if (_wasInSafeZone == false || _wasInSafeZone == null) {
        // حالة: كان بالخارج وعاد الآن (أو هذه أول قراءة وهو بالداخل)
        _handleReturnToZone(activeZone, patientId);
      } else {
        // حالة: لا يزال بالداخل (تحديث صامت، لا إزعاج)
        _status = "في ${activeZone.name}";
      }
      _currentZoneId = activeZone.id;
      _wasInSafeZone = true;
      _lastAlertedOutsidePosition = null; // تصفير عداد الـ 10 متر
      
    } else {
      // 🔴 المريض خارج كل المناطق الآمنة
      if (_wasInSafeZone == true || _wasInSafeZone == null) {
        // حالة: كان بالداخل وخرج للتو! (تنبيه فوري بالخروج)
        _handleExitFromZone(pos, patientId);
      } else {
        // حالة: هو بالفعل بالخارج ويتحرك (تفعيل منطق الـ 10 متر)
        _checkContinuousOutsideAlert(pos, patientId);
      }
      _currentZoneId = null; // نجعله null لأنه لا ينتمي لأي منطقة الآن
      _wasInSafeZone = false;
    }

    _syncDataToCloud(pos, patientId);
    notifyListeners();
  }

  // 2. دالة العودة للمنطقة
  Future<void> _handleReturnToZone(SafeZone activeZone, String patientId) async {
    _status = "في ${activeZone.name}";
    // لا نرسل اشعار عودة إذا كانت هذه أول قراءة عند فتح التطبيق (لتجنب الإزعاج)
    if (_wasInSafeZone != null) { 
      await _zoneRepository.sendAlert(
        patientId, 
        "✅ عاد $_patientName إلى المنطقة الآمنة (${activeZone.name})"
      );
    }
  }

  // 3. دالة الخروج من المنطقة
  Future<void> _handleExitFromZone(Position pos, String patientId) async {
    _status = "خارج النطاق! ⚠️";
    String locationAddress = await _getFormattedAddress(pos);
    
    // معرفة اسم المنطقة التي كان فيها قبل الخروج
    String leftZoneName = _currentZoneId != null ? _getZoneNameById(_currentZoneId) : "المنطقة الآمنة";
    
    // لا نرسل اشعار خروج إذا فتح التطبيق والمريض أصلاً بالخارج
    if (_wasInSafeZone != null) { 
      await _zoneRepository.sendAlert(
        patientId,
        "🚨 خرج $_patientName من ($leftZoneName).\n📍 الموقع: $locationAddress"
      );
    }
    
    // بدء حساب الـ 10 متر من نقطة الخروج هذه
    _lastAlertedOutsidePosition = pos; 
  }

  // 4. خوارزمية الـ 10 متر
  void _checkContinuousOutsideAlert(Position pos, String patientId) async {
    _status = "خارج النطاق! ⚠️";
    
    if (_lastAlertedOutsidePosition != null) {
      double distanceMoved = Geolocator.distanceBetween(
        _lastAlertedOutsidePosition!.latitude,
        _lastAlertedOutsidePosition!.longitude,
        pos.latitude,
        pos.longitude,
      );

      // 📏 إذا تحرك 10 أمتار أو أكثر وهو لا يزال بالخارج، أرسل تنبيهاً بالموقع الجديد
      if (distanceMoved >= 10.0) {
        String locationAddress = await _getFormattedAddress(pos);
        await _zoneRepository.sendAlert(
          patientId,
          "⏳ لا يزال $_patientName خارج النطاق ويتحرك (تحرك مسافة 10 متر إضافية)\n📍 الموقع الحالي: $locationAddress"
        );
        // تحديث نقطة القياس للتنبيه القادم لتبدأ من هنا
        _lastAlertedOutsidePosition = pos; 
      }
    } else {
      // احتياط: إذا كان null لسبب ما، نجعله الموقع الحالي
      _lastAlertedOutsidePosition = pos;
    }
  }
  void _updateRoutePoints(Position pos) {
    // التأكد من أن الإحداثيات ليست 0.0 (بيانات فارغة من Firebase)
    if (pos.latitude == 0.0 && pos.longitude == 0.0) return;

    LatLng newPoint = LatLng(pos.latitude, pos.longitude);
    
    if (_routePoints.isEmpty) {
      _routePoints.add(newPoint);
    } else {
      // حساب المسافة باستخدام مكتبة latlong2 مباشرة لتجنب تضارب مكتبة geolocator
      final Distance distance = const Distance();
      double dist = distance.as(LengthUnit.Meter, _routePoints.last, newPoint);
      
      if (dist > 10) { // التحديث فقط إذا تحرك أكثر من 10 أمتار
        _routePoints.add(newPoint);
        if (_routePoints.length > 50) _routePoints.removeAt(0);
      }
    }
  }
  SafeZone? _findCurrentActiveZone(Position pos) {
    if (_safeZones.isEmpty) return null;

    final Distance distanceCalculator = const Distance();

    for (var zone in _safeZones) {
      if (zone.isActive) {
        // حساب المسافة بدقة باستخدام LatLng
        final LatLng zoneLocation = LatLng(zone.latitude, zone.longitude);
        final LatLng patientLocation = LatLng(pos.latitude, pos.longitude);
        
        double distance = distanceCalculator.as(LengthUnit.Meter, patientLocation, zoneLocation);
        
        if (distance <= zone.radius) {
          return zone;
        }
      }
    }
    return null;
  }

  Future _syncDataToCloud(Position pos, String patientId) async {
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

  // 🚀 نظام التنبيه الهرمي للبطارية لتجنب التكرار وتصنيف الخطورة
  void _checkBatteryAlert(int level, String patientId) {
    if (level <= 5 && _lastAlertedBatteryLevel > 5) {
      _zoneRepository.sendAlert(patientId, "🛑 [خطورة قصوى]: بطارية $_patientName على وشك الإغلاق ($level%)!");
      _lastAlertedBatteryLevel = level;
    } else if (level <= 10 && _lastAlertedBatteryLevel > 10) {
      _zoneRepository.sendAlert(patientId, "⚠️ [تنبيه حرج]: بطارية $_patientName منخفضة جداً ($level%)!");
      _lastAlertedBatteryLevel = level;
    } else if (level <= 20 && _lastAlertedBatteryLevel > 20) {
      _zoneRepository.sendAlert(patientId, "🔋 [الطاقة]: بطارية $_patientName منخفضة ($level%). يرجى شحن الهاتف.");
      _lastAlertedBatteryLevel = level;
    } else if (level > 20) {
      _lastAlertedBatteryLevel = level; // إعادة تعيين في حال تم شحن الهاتف
    }
  }

 

  void _handleError(String message, dynamic error) {
    debugPrint("$message: $error");
  }

  // --- عمليات CRUD الآمنة والمحدثة للمناطق ---
  Future addNewSafeZone({
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
            latitude, longitude, existingZone.latitude, existingZone.longitude);

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

  Future deleteSafeZone(int index, String patientId) async {
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

  Future toggleZoneStatus(int index, String patientId, bool isActive) async {
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
    _locationSubscription?.cancel();
    _signalTimer?.cancel();
    super.dispose();
  }
}