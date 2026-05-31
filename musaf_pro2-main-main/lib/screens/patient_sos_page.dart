// patient_sos_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:permission_handler/permission_handler.dart';
import '../services/fcm_service.dart';

class PatientSOSPage extends StatefulWidget {
  const PatientSOSPage({super.key});
  @override
  State<PatientSOSPage> createState() => _PatientSOSPageState();
}

class _PatientSOSPageState extends State<PatientSOSPage>
    with SingleTickerProviderStateMixin {
  bool _isSending = false;
  bool _isCountingDown = false;
  bool _isAccepted = false;
  String _statusMessage = "";
  String _locationText = "جاري تحديد الموقع...";
  int _countdown = 5;
  Timer? _countdownTimer;
  Timer? _timeoutTimer; // مؤقت الـ 24 ساعة

  GeoPoint? _selectedLocation;

  List<Map<String, dynamic>> _sortedHospitals = [];
  int _currentHospitalIndex = 0;
  String _currentRequestId = "";
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  late AnimationController _pulseController;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isFreeFalling = false;
  DateTime? _freeFallTime;

  // --- ميزة إشعار الأهل الاختياري ---
  bool _notifyFamilyOptional = true;

  // 🚀 متغير لحفظ اسم المريض الحقيقي
  String _patientName = "مريض";
  String _patientAge = "";
  String _patientBloodType = "";
  String _patientGender = "";
  String _patientDiseases = "";
  String _patientAllergies = "";
  String _patientMedications = "";

  @override
  void initState() {
    super.initState();

    // 1. تشغيل الأنيميشن أولاً (لأنه خفيف ولا يسبب تعليق)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 2. تأخير العمليات الثقيلة حتى تكتمل حركة الانتقال للشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _fetchPatientData();(); // 🚀 جلب الاسم الحقيقي
          _fetchLocationOnStartup();

          if (!kIsWeb) {
            _initFallDetection();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    _countdownTimer?.cancel();
    _timeoutTimer?.cancel(); // إيقاف المؤقت عند الخروج
    _pulseController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  // 🚀 دالة لجلب اسم المريض المسجل في حساب Firebase
Future<void> _fetchPatientData() async {
  try {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;

        if (mounted) {
          setState(() {
            _patientName = data['displayName'] ?? 'مريض';
            _patientAge = data['age'] ?? '';
            _patientBloodType = data['bloodType'] ?? '';
            _patientGender = data['gender'] ?? '';
            _patientDiseases = data['chronicDiseases'] ?? '';
            _patientAllergies = data['allergies'] ?? '';
            _patientMedications = data['currentMedications'] ?? '';
          });
        }
      }
    }
  } catch (e) {
    debugPrint("Error fetching patient data: $e");
  }
}
  // --- دالات الموقع مع تحسين استخراج الشارع ---
  Future<void> _updateAddressText(double lat, double lng) async {
    String realAddress = "";
    try {
      if (!kIsWeb) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks.first;
            List<String> parts = [];

            // 1. محاولة جلب اسم الشارع الدقيق
            String? streetName = place.thoroughfare;
            if (streetName == null || streetName.isEmpty || streetName.contains("+") || streetName.toLowerCase().contains("unnamed")) {
              streetName = place.street;
            }

            if (streetName != null && streetName.isNotEmpty && !streetName.contains("+") && !streetName.toLowerCase().contains("unnamed")) {
              if (!streetName.startsWith("شارع") && !streetName.startsWith("طريق")) {
                parts.add("شارع $streetName");
              } else {
                parts.add(streetName);
              }
            }
            
            // 2. جلب الحي
            if (place.subLocality != null && place.subLocality!.isNotEmpty) {
              parts.add(place.subLocality!);
            }
            // 3. جلب المدينة
            if (place.locality != null && place.locality!.isNotEmpty) {
              parts.add(place.locality!);
            }
            // 4. جلب المحافظة / المنطقة
            if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
              parts.add(place.administrativeArea!);
            }

            realAddress = parts.toSet().join('، ');
          }
        } catch (e) {
          debugPrint("Geocoding error: $e");
        }
      }

      // الاعتماد الاحتياطي على OpenStreetMap
      if (realAddress.trim().isEmpty || realAddress.contains("+")) {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=ar');
        
        final response = await http.get(url, headers: {
          'User-Agent': 'com.musaf.app',
        });

        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          
          if (data['address'] != null) {
            var addr = data['address'];
            List<String> parts = [];
            
            String? osmStreet = addr['road'] ?? addr['street'] ?? addr['pedestrian'] ?? addr['footway'] ?? addr['path'] ?? addr['square'];
            
            if (osmStreet != null && osmStreet.isNotEmpty) {
              if (!osmStreet.startsWith("شارع") && !osmStreet.startsWith("طريق")) {
                parts.add("شارع $osmStreet");
              } else {
                parts.add(osmStreet);
              }
            }

            if (addr['neighbourhood'] != null) parts.add(addr['neighbourhood']);
            if (addr['suburb'] != null) parts.add(addr['suburb']);
            if (addr['city'] ?? addr['town'] ?? addr['village'] != null) {
              parts.add(addr['city'] ?? addr['town'] ?? addr['village']);
            }
            if (addr['state'] != null) parts.add(addr['state']);
            
            realAddress = parts.toSet().join('، ').trim();
          }

          if (realAddress.isEmpty && data['display_name'] != null) {
            List<String> nameParts = data['display_name'].toString().split(',');
            realAddress = nameParts.take(4).join('،').trim();
          }
        }
      }

      setState(() {
        _selectedLocation = GeoPoint(lat, lng);
        _locationText = realAddress.isNotEmpty
            ? realAddress
            : "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      });
    } catch (e) {
      debugPrint("Error extracting address: $e");
      setState(() {
        _selectedLocation = GeoPoint(lat, lng);
        _locationText = "${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}";
      });
    }
  }
Future<void> _fetchLocationOnStartup() async {
  // 1. تحديث الحالة
  if (mounted) setState(() => _locationText = "جاري تحديد موقعك...");

  try {
    // 2. طلب إذن الوصول للموقع باستخدام permission_handler
    var status = await Permission.location.request();

    if (status.isGranted) {
      // 3. إذا تم السماح، جلب الإحداثيات بدقة عالية
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      if (mounted) {
        await _updateAddressText(pos.latitude, pos.longitude);
      }
    } else if (status.isPermanentlyDenied) {
      // 4. إذا رفض المستخدم نهائياً، نوجهه للإعدادات
      if (mounted) {
        setState(() => _locationText = "تم رفض إذن الموقع نهائياً");
        await openAppSettings();
      }
    } else {
      // 5. إذا تم رفض الإذن
      if (mounted) setState(() => _locationText = "لم يتم منح إذن الموقع");
    }
  } catch (e) {
    if (mounted) setState(() => _locationText = "خطأ في تحديد الموقع: $e");
  }
}

  Future<void> _searchAddressManually(String typedAddress) async {
    if (typedAddress.trim().isEmpty) return;
    setState(() => _locationText = "جاري البحث عن الموقع...");
    try {
      double lat = 0.0;
      double lng = 0.0;

      if (kIsWeb) {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$typedAddress&format=json&limit=1&accept-language=ar');
        final response = await http.get(url, headers: {'User-Agent': 'com.musaf.app'});
        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          if (data.isNotEmpty) {
            lat = double.parse(data[0]['lat']);
            lng = double.parse(data[0]['lon']);
          } else {
            throw "Not found";
          }
        }
      } else {
        List<Location> locations = await locationFromAddress(typedAddress);
        if (locations.isNotEmpty) {
          lat = locations.first.latitude;
          lng = locations.first.longitude;
        } else {
          throw "Not found";
        }
      }

      setState(() {
        _selectedLocation = GeoPoint(lat, lng);
        _locationText = typedAddress;
      });
    } catch (e) {
      setState(() => _locationText = "فشل تغيير الموقع");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("لم نتمكن من العثور على هذا العنوان")));
      }
    }
  }

  Future<void> _pickLocationFromMap() async {
    if (_selectedLocation == null) return;

    final GeoPoint? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLocation: GeoPoint(
              _selectedLocation!.latitude, _selectedLocation!.longitude),
        ),
      ),
    );

    if (result != null) {
      await _updateAddressText(result.latitude, result.longitude);
    }
  }

  void _showChangeLocationOptions() {
    TextEditingController addressController = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          return Directionality( // 🚀 ضمان اتجاه من اليمين لليسار للنافذة
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 25,
                  left: 20,
                  right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("تغيير موقع الطوارئ",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal')),
                  const SizedBox(height: 20),
                  TextField(
                    controller: addressController,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.right, // محاذاة النص لليمين
                    decoration: InputDecoration(
                        hintText: "ابحث عن شارع، معلم، أو مدينة...",
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFFB22222), size: 20),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15)),
                        suffixIcon: IconButton(
                          icon:
                              const Icon(Icons.check_circle, color: Colors.green, size: 22),
                          onPressed: () {
                            Navigator.pop(context);
                            _searchAddressManually(addressController.text);
                          },
                        )),
                    onSubmitted: (val) {
                      Navigator.pop(context);
                      _searchAddressManually(val);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text("أو اختر من التالي",
                        style: TextStyle(
                            color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _fetchLocationOnStartup();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB22222),
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.my_location, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text("استخدام موقعي الحالي",
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Tajawal',
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickLocationFromMap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      minimumSize: const Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                         Icon(Icons.map, color: Colors.white, size: 20),
                         SizedBox(width: 8),
                         Text("تحديد دقيق من الخريطة",
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Tajawal',
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        });
  }

  Future<void> _openMap() async {
    try {
      if (_selectedLocation == null) throw 'لا يوجد موقع';
      final String googleMapsUrl =
          "https://www.google.com/maps/search/?api=1&query=${_selectedLocation!.latitude},${_selectedLocation!.longitude}";
      final Uri url = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'error';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("تعذر فتح الخريطة")));
      }
    }
  }

  // --- السقوط ---
  void _initFallDetection() {
    _accelerometerSubscription =
        accelerometerEventStream().listen((AccelerometerEvent event) {
      double magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude < 2.0) {
        _isFreeFalling = true;
        _freeFallTime = DateTime.now();
      }
      if (magnitude > 25.0 && _isFreeFalling) {
        if (_freeFallTime != null &&
            DateTime.now().difference(_freeFallTime!).inMilliseconds < 1500) {
          _handleFallDetected();
        }
        _isFreeFalling = false;
      }
      if (_isFreeFalling &&
          _freeFallTime != null &&
          DateTime.now().difference(_freeFallTime!).inMilliseconds > 2000) {
        _isFreeFalling = false;
      }
    });
  }

  void _handleFallDetected() {
    if (_isSending) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ تم اكتشاف سقوط! جاري إرسال تنبيه...', style: TextStyle(fontSize: 13)),
        backgroundColor: Colors.red));
    _notifyFamily('fall_detection', '🚨 حالة طارئة! تم اكتشاف سقوط للمريض $_patientName.');
  }
  Future<void> _notifyFamily(String type, String message) async {
    try {
      // 1. تحديد موقع المريض بدقة
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 2. جلب معرف المريض الحالي لربط الإشعار بعائلته
      String? patientId = FirebaseAuth.instance.currentUser?.uid;

      if (patientId != null) {
        // 3. 🚨 التعديل هنا: حفظ التنبيه في المسار الصحيح (داخل ملف المريض) لكي يقرأه تطبيق الأهل
        DocumentReference alertRef = FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .collection('alerts')
            .doc();

        await alertRef.set({
          'id': alertRef.id, // ضروري عشان ميزة الحذف (Swipe to delete) عند الأهل
          'patientId': patientId,
          'patientName': _patientName,
          'location': GeoPoint(pos.latitude, pos.longitude),
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'type': type,
          'is_read': false,
        });

        // 4. جلب التوكن الخاص بالأهل لإرسال الإشعار الفوري
        DocumentSnapshot patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .get();

        if (patientDoc.exists && patientDoc.data() != null) {
          var data = patientDoc.data() as Map<String, dynamic>;

          // محاولة جلب التوكن
          String? familyFcmToken = data['familyFcmToken'] ?? data['fcmToken'];

          if (familyFcmToken != null) {
            // إرسال الإشعار المباشر
            await FcmService.sendPushMessage(
              familyToken: familyFcmToken,
              title: type == 'fall_detection'
                  ? '⚠️ تنبيه سقوط مريض!'
                  : '🚨 نداء استغاثة عاجل',
              body: message,
              type: type,
            );
          } else {
            debugPrint(
              "⚠️ تحذير: لم يتم العثور على توكن الأهل في مستند المريض.",
            );
          }
        }
      }

      // تحديث واجهة المستخدم في حال كانت الحالة اكتشاف سقوط
      if (type == 'fall_detection') {
        setState(() {
          _statusMessage = "تم الإرسال للعائلة بنجاح ✅";
          _isSending = false;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _statusMessage = "");
        });
      }
    } catch (e) {
      debugPrint("❌ خطأ في دالة _notifyFamily: $e");
      if (type == 'fall_detection') {
        setState(() {
          _statusMessage = "حدث خطأ في الإرسال للعائلة";
          _isSending = false;
        });
      }
    }
  }
  // --- SOS ---
  void _startSOSCountdown() {
    if (_selectedLocation == null) return;
    setState(() {
      _isCountingDown = true;
      _isAccepted = false;
      _countdown = 5;
      _statusMessage = "";
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _confirmAndSendSOS();
      }
    });
  }

  void _confirmAndSendSOS() {
    _countdownTimer?.cancel();
    setState(() => _isCountingDown = false);
    _sendSOS();
  }

  void _cancelSOS() {
    _countdownTimer?.cancel();
    _timeoutTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _isSending = false;
      _statusMessage = "تم إلغاء الطلب";
    });

    if (_currentRequestId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('emergency_requests')
          .doc(_currentRequestId)
          .update({'status': 'cancelled'});
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _statusMessage = "");
    });
  }

  void _start24HourTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(hours: 24), () async {
      if (!_isAccepted && _currentRequestId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('emergency_requests')
            .doc(_currentRequestId)
            .update({'status': 'timeout'});

        if (mounted) {
          setState(() {
            _isSending = false;
            _statusMessage =
                "تم إلغاء الطلب تلقائياً لمرور 24 ساعة دون استجابة.";
          });
        }
      }
    });
  }

  Future<void> _sendSOS() async {
    setState(() {
      _isSending = true;
      _statusMessage = "جاري البحث عن أقرب مستشفى...";
    });

    if (_notifyFamilyOptional) {
      _notifyFamily(
          'sos_alert', '🚨 طلب استغاثة عاجل! المريض $_patientName أرسل نداء طوارئ للمستشفى.');
    }

    try {
      final lat = _selectedLocation!.latitude;
      final lng = _selectedLocation!.longitude;

      var hospitalSnapshot =
          await FirebaseFirestore.instance.collection('hospitals').get();
      _sortedHospitals.clear();
      for (var doc in hospitalSnapshot.docs) {
        if (doc['availableBeds'] > 0) {
          GeoPoint hLoc = doc['location'];
          double dist = Geolocator.distanceBetween(
              lat, lng, hLoc.latitude, hLoc.longitude);
          _sortedHospitals
              .add({'id': doc.id, 'name': doc['name'], 'distance': dist});
        }
      }
      if (_sortedHospitals.isEmpty) throw "لا توجد مستشفيات متاحة حالياً";
      _sortedHospitals.sort((a, b) => a['distance'].compareTo(b['distance']));
      _currentHospitalIndex = 0;
      await _sendRequestToCurrentTarget();

      _start24HourTimeoutTimer();
    } catch (e) {
      setState(() {
        _statusMessage = "خطأ: $e";
        _isSending = false;
      });
    }
  }
  Future<void> _sendRequestToCurrentTarget() async {
  var targetHospital = _sortedHospitals[_currentHospitalIndex];
  DocumentReference docRef = await FirebaseFirestore.instance.collection('emergency_requests')
          .add({
    'patientName': _patientName,
    'patientAge': _patientAge,
    'bloodType': _patientBloodType,
    'gender': _patientGender,
    'chronicDiseases': _patientDiseases,
    'allergies': _patientAllergies,
    'currentMedications': _patientMedications,

    'location': _selectedLocation,
    'locationAddress': _locationText,
    'targetHospitalId': targetHospital['id'],
    'targetHospitalName': targetHospital['name'],
    'status': 'pending',
    'timestamp': FieldValue.serverTimestamp(),
  });

  _currentRequestId = docRef.id;

  setState(() {
    _statusMessage =
        "بانتظار تأكيد ${targetHospital['name']}...";
  });

  _listenToHospitalResponse();
}

  void _listenToHospitalResponse() {
    _requestSubscription?.cancel();
    _requestSubscription = FirebaseFirestore.instance
        .collection('emergency_requests')
        .doc(_currentRequestId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        String status = snapshot['status'];
        if (status == 'accepted') {
          _timeoutTimer?.cancel();
          setState(() {
            _isAccepted = true;
            _isSending = false;
            _statusMessage =
                "الإسعاف يتجه إليك من ${snapshot['targetHospitalName']}";
          });
          _requestSubscription?.cancel();
        } else if (status == 'rejected') {
          _currentHospitalIndex++;
          if (_currentHospitalIndex < _sortedHospitals.length) {
            _sendRequestToCurrentTarget();
          } else {
            _timeoutTimer?.cancel();
            setState(() {
              _statusMessage = "عذراً، جميع المستشفيات ممتلئة";
              _isSending = false;
            });
          }
        }
      }
    });
  }

  // --- الواجهة ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🚀 إضافة Directionality لضمان اتجاه التطبيق من اليمين لليسار
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                child: Lottie.asset('assets/animations/blue_map.json',
                    fit: BoxFit.cover,
                    repeat: true,
                    errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.public,
                            size: 200, color: Colors.black12))),
                opacity: 0.3,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  const Spacer(),
                  _buildMainArea(),
                  const Spacer(),
                  if (!_isSending && !_isCountingDown && !_isAccepted)
                    _buildFamilyNotificationToggle(),
                  if (_statusMessage.isNotEmpty && !_isCountingDown)
                    _buildStatusText(),
                  _buildLocationCard(),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart, 
        child: IconButton(
          // 🚀 استخدام أيقونة السهم المتوافقة مع اتجاه اللغة (RTL/LTR)
          icon: const Icon(
            Icons.arrow_back_ios_new, 
            color: Color(0xFFB22222), 
            size: 28,
          ),
          onPressed: () {
            Navigator.pop(context); 
          },
        ),
      ),
    );
  }

  Widget _buildMainArea() {
    if (_isAccepted) return _buildSuccessUI();
    if (_isCountingDown) return _buildCountdownUI();
    if (_isSending) {
      return Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFFB22222)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _cancelSOS,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              shape: const StadiumBorder(),
            ),
            child: const Text("إلغاء الطلب",
                style: TextStyle(color: Colors.white, fontSize: 13)),
          )
        ],
      );
    }

    return Column(
      children: [
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(
              parent: _pulseController, curve: Curves.easeInOut)),
          child: GestureDetector(
            onTap: _startSOSCountdown,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFB22222).withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 8)
                  ]),
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [Color(0xFFE74C3C), Color(0xFFB22222)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter)),
                child: const Center(
                    child: Text("طلب\nمساعدة",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.3))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 🚀 التعديل المطلوب: عكس اتجاه العناصر في كارد إشعار العائلة
  Widget _buildFamilyNotificationToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black12)),
      child: Row(
        // ترتيب العناصر من اليمين لليسار
        children: [
          const Icon(Icons.people_alt_outlined,
              color: Color(0xFF2C3E50), size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "إرسال إشعار طوارئ للعائلة تلقائياً",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right, // محاذاة النص لليمين
            ),
          ),
          Switch(
            value: _notifyFamilyOptional,
            activeColor: const Color(0xFFB22222),
            onChanged: (bool value) {
              setState(() {
                _notifyFamilyOptional = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // 🚀 التعديل المطلوب: عكس اتجاه العناصر في كارد الموقع
  Widget _buildLocationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 35),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Row(
        // ترتيب العناصر من اليمين لليسار
        children: [
          const Icon(Icons.location_on, color: Color(0xFFB22222), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _openMap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // يبدأ من اليمين بسبب الـ Directionality
                children: [
                  const Text("الموقع الحالي",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF2C3E50))),
                  const SizedBox(height: 2),
                  Text(_locationText,
                      style: const TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right), // محاذاة النص لليمين
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: _showChangeLocationOptions,
            style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(40, 25),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text("تغيير",
                style: TextStyle(
                    color: Color(0xFFB22222),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
Widget _buildStatusText() {
  // 🚀 التعديل: إذا تم قبول الطلب، لا تعرض النص في الأسفل
  if (_isAccepted) {
    return const SizedBox.shrink();
  }

  // في الحالات العادية (جاري البحث، خطأ، إلخ)، اعرض النص كالمعتاد
  return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 15, right: 15),
      child: Text(
        _statusMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Color(0xFFB22222),
            fontWeight: FontWeight.bold,
            fontSize: 13),
      ));
}

  Widget _buildCountdownUI() {
    return Column(
      children: [
        Text("يتم التأكيد خلال $_countdown ثوانٍ",
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB22222))),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: _cancelSOS,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                shape: const StadiumBorder()),
            child: const Text("إلغاء الطلب",
                style: TextStyle(color: Colors.white, fontSize: 13)))
      ],
    );
  }

  Widget _buildSuccessUI() {
    return Column(
      children: [
        const Icon(Icons.check_circle, size: 70, color: Colors.green),
        const SizedBox(height: 12),
        const Text("تم الإرسال بنجاح",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green)),
        const SizedBox(height: 8),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14))),
        const SizedBox(height: 20),
        TextButton(
            onPressed: () => setState(() => _isAccepted = false),
            child:
                const Text("رجوع", style: TextStyle(color: Color(0xFFB22222), fontSize: 14))),
      ],
    );
  }
}

// ==========================================
// 🗺️ الشاشة الجديدة لاختيار الموقع
// ==========================================
class MapPickerPage extends StatefulWidget {
  final GeoPoint initialLocation;
  const MapPickerPage({super.key, required this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late latLng.LatLng _pickedLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pickedLocation = latLng.LatLng(
        widget.initialLocation.latitude, widget.initialLocation.longitude);
  }

  Future<void> _goToCurrentLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final newLoc = latLng.LatLng(pos.latitude, pos.longitude);
      _mapController.move(newLoc, 16.0);
      setState(() {
        _pickedLocation = newLoc;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("تعذر جلب موقعك الحالي", style: TextStyle(fontSize: 13))));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 إضافة Directionality هنا أيضاً لصفحة الخريطة
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("حدد موقع الإصابة بدقة",
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
          backgroundColor: const Color(0xFFB22222),
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pickedLocation,
                initialZoom: 16.0,
                onPositionChanged: (position, hasGesture) {
                  if (position.center != null) {
                    setState(() {
                      _pickedLocation = position.center!;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.musaf.app',
                ),
              ],
            ),
            const Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 35),
                child:
                    Icon(Icons.location_pin, size: 45, color: Color(0xFFB22222)),
              ),
            ),
            Positioned(
              bottom: 100,
              right: 20, // الزر يبقى يمين الشاشة
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                onPressed: _goToCurrentLocation,
                child: const Icon(Icons.my_location, color: Color(0xFF2C3E50)),
              ),
            ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                      context,
                      GeoPoint(
                          _pickedLocation.latitude, _pickedLocation.longitude));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB22222),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("تأكيد هذا الموقع",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}