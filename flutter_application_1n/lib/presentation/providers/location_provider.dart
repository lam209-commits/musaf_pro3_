import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geocoding/geocoding.dart'; // 👈 استيراد مكتبة الترميز الجغرافي لترجمة الإحداثيات إلى أسماء

import '../../domain/entities/safe_zone.dart';
import '../../domain/repositories/zone_repository.dart';

class LocationProvider with ChangeNotifier {
  final ZoneRepository _zoneRepository;
  
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
  DateTime? _lastOutsideZoneAlertTime; // متغير لتتبع وقت آخر تنبيه دوري خارج النطاق
  
  // مؤقتات ومتغيرات لفحص جودة الإشارة
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
      _safeZones = await _zoneRepository.getSafeZones(patientId);
      notifyListeners();
    } catch (e) {
      _handleError("خطأ في تحميل المناطق", e);
    }
  }

  // --- محرك التتبع الذكي المطور (Geofencing Engine) ---
  Future<void> startPatientTracking(String patientId) async {
    if (!await _checkLocationPermissions()) return;

    await _positionStream?.cancel();
    _signalTimer?.cancel();
    
    _isTracking = true;
    _status = "جاري التحديد...";
    _lastUpdateTime = DateTime.now();
    _lastSignalAlertTime = null; 
    _lastOutsideZoneAlertTime = null; // تصفير مؤقت تنبيهات الخروج الدوري
    notifyListeners();

    // فحص دوري كل دقيقة للتأكد من عدم انقطاع الإشارة
    _signalTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (_lastUpdateTime != null) {
        int minutesSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!).inMinutes;

        // إذا انقطع التحديث لأكثر من 3 دقائق
        if (minutesSinceLastUpdate >= 3) {
_status = "فقدان الاتصال بجهاز $_patientName! 📡";          notifyListeners();

          if (_lastSignalAlertTime == null || 
              DateTime.now().difference(_lastSignalAlertTime!).inMinutes >= 5) {
            
            String lastLocationText = "غير معروف بعد";

            // 👈 التحقق والترجمة الجغرافية العكسية لتحويل الأرقام إلى اسم مكان حقيقي
            if (_currentPosition != null) {
              try {
                List<Placemark> placemarks = await placemarkFromCoordinates(
                  _currentPosition!.latitude, 
                  _currentPosition!.longitude
                );
                
                if (placemarks.isNotEmpty) {
                  Placemark place = placemarks.first;
                  lastLocationText = "${place.subLocality ?? ''}، ${place.street ?? ''}";
                  
                  // ضمان عدم إرسال نص فارغ في حال لم ترجع الأسماء من السيرفر
                  if (lastLocationText.trim() == "،") {
                    lastLocationText = "خط العرض: ${_currentPosition!.latitude}, خط الطول: ${_currentPosition!.longitude}";
                  }
                }
              } catch (e) {
                lastLocationText = "خط العرض: ${_currentPosition!.latitude}, خط الطول: ${_currentPosition!.longitude}";
              }
            }
            await _zoneRepository.sendAlert(
              patientId, 
              "تحذير: تم فقدان الاتصال بنظام تحديد المواقع (GPS) لهاتف $_patientName! الموقع الأخير المسجل: ($lastLocationText)"
            );
            
            _lastSignalAlertTime = DateTime.now(); 
          }
        }
      }
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // التتبع الحركي: يرسل إحداثية ويحدث الخريطة والسحاب تلقائياً كل 10 أمتار
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        _lastUpdateTime = DateTime.now(); 
        _lastSignalAlertTime = null;      
        _processLocationUpdate(position, patientId);
      },
      onError: (error) {
        _status = "خطأ في المستشعر ⚠️";
        _zoneRepository.sendAlert(patientId, "تحذير: حدث خطأ في مستشعر الموقع بالجهاز: $error");
        notifyListeners();
      }
    );
  }

  void stopTracking() {
    _positionStream?.cancel();
    _signalTimer?.cancel();
    _isTracking = false;
    _status = "تم إيقاف التتبع"; 
    _currentZoneId = null;
    _wasInSafeZone = null;
    _lastOutsideZoneAlertTime = null;
    notifyListeners();
  }

  void _processLocationUpdate(Position pos, String patientId) async {
    _updateRoutePoints(pos);

    SafeZone? activeZone = _findCurrentActiveZone(pos);
    String? foundZoneId = activeZone?.id;

    // معالجة الانتقال وتغير الحالة
    if (_currentZoneId != foundZoneId) {
      await _handleZoneTransition(foundZoneId, activeZone, patientId, pos);
    } else if (_currentZoneId == null) {
      // إذا كان لا يزال خارج النطاق ولم تتغير المنطقة، نفحص شرط الـ 10 دقائق لإعادة إرسال الموقع الحالي
      _checkContinuousOutsideAlert(pos, patientId);
    }

    _syncDataToCloud(pos, patientId);
  }

  // --- وظائف مساعدة ---
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

  // منطق التنبيهات الذكي (الخروج والعودة) مع ترجمة العنوان النصي مخصصاً لـ "سائدة"
  Future<void> _handleZoneTransition(String? foundZoneId, SafeZone? activeZone, String patientId, Position pos) async {
    _currentZoneId = foundZoneId;
    bool currentlyInSafe = _currentZoneId != null;

    if (currentlyInSafe && activeZone != null) {
      _status = "في ${activeZone.name}";
      _lastOutsideZoneAlertTime = null; // تصفير مؤقت التنبيهات الدورية بمجرد العودة للأمان
      
      if (_wasInSafeZone == false) {
        await _zoneRepository.sendAlert(patientId, "تنبيه: عاد $_patientName إلى النطاق الآمن (${activeZone.name})");
      }
    } else {
      _status = "خارج النطاق! ";
      
      if (_wasInSafeZone == true || _wasInSafeZone == null) {
        String locationAddress = "جاري تحديد العنوان...";

        try {
          // استخراج اسم المكان الفعلي من خطوط الطول والعرض
          List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            locationAddress = "${place.subLocality ?? ''}، ${place.street ?? ''}";
            // تأكيد تصفير النصوص الفارغة في حال عدم رجوعها من خادم الخرائط
            if (locationAddress.trim() == "،") {
              locationAddress = "خط العرض: ${pos.latitude}, خط الطول: ${pos.longitude}";
            }
          }
        } catch (e) {
          // في حال فشل الاتصال بخادم الخرائط، نعتمد على الإحداثيات الرقمية كخيار احتياطي آمن
          locationAddress = "خط العرض: ${pos.latitude}, خط الطول: ${pos.longitude}";
        }

        // إرسال التنبيه الفوري متضمناً اسم التابع النصي وموقعه المترجم لغوياً بالكامل
        await _zoneRepository.sendAlert(
          patientId, 
          "تنبيه طوارئ: خرج $_patientName من النطاق الآمن! الموقع الحالي: ($locationAddress)"
        );
        _lastOutsideZoneAlertTime = DateTime.now(); // تسجيل وقت أول تنبيه خروج
      }
    }
    
    _wasInSafeZone = currentlyInSafe;
    notifyListeners();
  }

  // دالة فحص البقاء خارج النطاق لإرسال تنبيه بالموقع النصي كل 10 دقائق
  void _checkContinuousOutsideAlert(Position pos, String patientId) async {
    if (_lastOutsideZoneAlertTime != null && 
        DateTime.now().difference(_lastOutsideZoneAlertTime!).inMinutes >= 10) {
      
      String locationAddress = "جاري تحديد العنوان...";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          locationAddress = "${place.subLocality ?? ''}، ${place.street ?? ''}";
          if (locationAddress.trim() == "،") {
            locationAddress = "خط العرض: ${pos.latitude}, خط الطول: ${pos.longitude}";
          }
        }
      } catch (e) {
        locationAddress = "خط العرض: ${pos.latitude}, خط الطول: ${pos.longitude}";
      }

      _zoneRepository.sendAlert(
        patientId, 
        "تذكير: لا يزال $_patientName خارج النطاق الآمن! الموقع الحالي المحدث: ($locationAddress)"
      );
      
      _lastOutsideZoneAlertTime = DateTime.now(); // تحديث المؤقت ليفحص الـ 10 دقائق القادمة
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
        _zoneRepository.sendAlert(patientId, ": بطارية هاتف $_patientName منخفضة ($level%)");
        _lastBatteryAlertTime = DateTime.now();
      }
    }
  }

  Future<bool> _checkLocationPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.deniedForever && permission != LocationPermission.denied;
  }

  void _handleError(String message, dynamic error) {
    debugPrint("$message: $error");
  }
// --- عمليات CRUD للمناطق الآمنة بعد حل مشكلة عدم الاستجابة ---
// --- دالة الإضافة المطورة مع فصل الحالات الإدارية عن الـ status الحركي ---
  Future<String> addNewSafeZone({
    required String patientId,
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      // 1. صمام الأمان الأول: منع الأسماء الفارغة
      if (name.trim().isEmpty) {
        return "يرجى إدخل اسم صالح للمنطقة! ⚠️"; // نرجع النص للشاشة مباشرة
      }

      // 2. صمام الأمان الثاني: منع إحداثيات الصفر الوهمية
      if (latitude == 0.0 && longitude == 0.0) {
        return "إحداثيات غير صالحة! يرجى تحديد موقع على الخريطة ⚠️";
      }

      // 3. صمام الأمان الثالث: التحقق من الحدود الجغرافية العالمية الأرضية
      if (latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        return "الإحداثيات الجغرافية المحددة خارج نطاق كوكب الأرض! ⚠️";
      }

      // 4. صمام الأمان الرابع: فحص التكرار والتداخل مع المناطق السابقة
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

      // 5. إذا اجتازت كل الفحوصات بنجاح، يتم الرفع إلى Firebase
      final newZone = SafeZone(
        id: '', 
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        isActive: true,
      );
      
      await _zoneRepository.addSafeZone(patientId, newZone);
      await loadSafeZones(patientId); // إعادة جلب القائمة لتحديث الشاشة
      
      return "تم إضافة المنطقة بنجاح ✅"; // نرجع نص النجاح الصافي
      
    } catch (e) {
      _handleError("خطأ في إضافة منطقة جديدة", e);
      return "حدث خطأ غير متوقع أثناء الحفظ ⚠️";
    }
  }
  Future<void> deleteSafeZone(int index, String patientId) async {
    if (index >= 0 && index < _safeZones.length) {
      try {
        await _zoneRepository.deleteSafeZone(patientId, _safeZones[index].id);
        _safeZones.removeAt(index);
        notifyListeners(); // إشعار فوري بحذف العنصر هندسياً
      } catch (e) {
        _handleError("خطأ في حذف المنطقة", e);
      }
    }
  }

  Future<void> toggleZoneStatus(int index, String patientId, bool isActive) async {
    try {
      if (index >= 0 && index < _safeZones.length) {
        final zone = _safeZones[index];
        
        // 1. تحديث الحالة في السيرفر السحابي (Firebase) لضمان الحفظ
        await _zoneRepository.updateZoneStatus(patientId, zone.id, isActive);
        
        // 2. التحديث المباشر: تعديل القيمة محلياً فوراً (يعمل الآن بنجاح لأنكِ أزلتِ final من الـ Entity)
        zone.isActive = isActive; 

        // 3. التحقق الذكي من النطاق الجغرافي الحالي للتابع
        if (!isActive && _currentZoneId == zone.id) {
          _currentZoneId = null;
          _status = "خارج النطاق! ";
        }

        // 4. إشعار الواجهات لإعادة البناء الفوري وتغيير وضع زر الـ Switch أمام مقدم الرعاية
        notifyListeners(); 
      }
    } catch (e) {
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