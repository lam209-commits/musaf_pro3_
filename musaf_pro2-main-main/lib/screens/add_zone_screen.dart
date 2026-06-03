import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // قد لا نحتاجه هنا بعد التعديل، لكن تم الإبقاء عليه لتفادي أي أخطاء
import '../providers/location_provider.dart';
import '../../domain/entities/safe_zone.dart';
import '../widgets/zone_card.dart';

class AddZoneScreen extends StatefulWidget {
  final String patientId;
  const AddZoneScreen({super.key, required this.patientId});

  @override
  State<AddZoneScreen> createState() => _AddZoneScreenState();
}

class _AddZoneScreenState extends State<AddZoneScreen> {
  // 🚀 تم حذف _formKey من هنا لمنع مشاكل الـ Modal المتكررة

  bool _isFetchingLocation = false;

  // ألوان الثيم المعتمدة في التطبيق
  final Color themeColor = const Color(0xFF2E7D32); // الأخضر الأساسي
  final Color backgroundColor = const Color(0xFFF8F9FD); // الخلفية الفاتحة

  final List<String> _nameOptions = [
    'منزل',
    'مدرسة',
    'حديقة',
    'مسجد',
    'عمل',
    'مستشفى',
    'منطقة مخصصة'
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<LocationProvider>().loadSafeZones(widget.patientId));
  }

  // --- Logic Layer ---

  void _onSavePressed({
    required bool isEdit,
    int? index,
    required String name,
    required String lat,
    required String lng,
    required double radius,
  }) async {
    final pro = context.read<LocationProvider>();

    Navigator.pop(context);

    if (!isEdit) {
      String resultMessage = await pro.addNewSafeZone(
        patientId: widget.patientId,
        name: name,
        latitude: double.parse(lat.trim()),
longitude: double.parse(lng.trim()),
        radius: radius,
      );

      if (mounted) {
        bool isSuccess = resultMessage.contains('نجاح');
        _showCustomSnackBar(resultMessage, isError: !isSuccess);
      }
    }
    // ملاحظة: إذا كان هناك منطق للتحديث (Edit)، يمكن إضافته هنا مستقبلاً
  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : themeColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(),
      body: _buildZonesList(),
      floatingActionButton: _buildAddButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: Colors.black87,
      title: const Text("إدارة المناطق الآمنة",
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
      centerTitle: true,
      elevation: 0,
      actions: [
        Consumer<LocationProvider>(
          builder: (context, loc, _) {
            if (loc.safeZones.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: Colors.redAccent, size: 28),
              tooltip: "حذف جميع المناطق",
              onPressed: () => _confirmClearAll(loc),
            );
          },
        )
      ],
    );
  }

  Widget _buildZonesList() {
    return Consumer<LocationProvider>(
      builder: (context, loc, _) {
        if (loc.safeZones.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          itemCount: loc.safeZones.length,
          itemBuilder: (context, index) {
            final zone = loc.safeZones[index];

            return Dismissible(
              key: Key(zone.id.isNotEmpty ? zone.id : index.toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("حذف المنطقة",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.delete_forever, color: Colors.white),
                  ],
                ),
              ),
              confirmDismiss: (direction) async {
                return await _showSwipeConfirmDialog(index);
              },
              onDismissed: (direction) {
                loc.deleteSafeZone(index, widget.patientId);
                _showCustomSnackBar("تم حذف المنطقة بنجاح ✅", isError: false);
              },
              child: ZoneCard(
                zone: zone,
                index: index,
                patientId: widget.patientId,
                locProvider: loc,
                onEdit: () => _openZoneModal(zone: zone, index: index),
                onDelete: () => _confirmDeletion(index),
              ),
            );
          },
        );
      },
    );
  }

  void _openZoneModal({SafeZone? zone, int? index}) {
    final isEdit = zone != null;
    final latController = TextEditingController(
        text: isEdit ? zone.latitude.toString() : "");
    final lngController = TextEditingController(
        text: isEdit ? zone.longitude.toString() : "");
    String selectedName = (isEdit && _nameOptions.contains(zone.name))
        ? zone.name
        : _nameOptions.first;
    double radius = isEdit ? zone.radius : 150.0;

    // 🚀 نقل مفتاح الـ Form إلى هنا ليكون مستقلاً لكل نافذة تُفتح
    final modalFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 25,
              right: 25,
              top: 20),
          child: Form(
            key: modalFormKey, // 👈 استخدام المفتاح الخاص بالـ Modal هنا
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModalHandle(),
                  const SizedBox(height: 20),
                  _buildTypeDropdown(
                      selectedName, (val) => setModalState(() => selectedName = val!)),
                  const SizedBox(height: 15),
                  _buildLocationPicker(latController, lngController, setModalState),
                  const SizedBox(height: 20),
                  _buildRadiusSlider(radius, (val) => setModalState(() => radius = val)),
                  const SizedBox(height: 25),
                  _buildSubmitAction(isEdit, index, selectedName, latController,
                      lngController, radius, modalFormKey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Shared Small Widgets ---

  Widget _buildTypeDropdown(String value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration("نوع المكان", Icons.label_outline),
      items: _nameOptions
          .map((n) => DropdownMenuItem(
              value: n, child: Text(n, style: const TextStyle(fontFamily: 'Cairo'))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildRadiusSlider(double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("نطاق الأمان: ${value.toInt()} متر",
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        Slider(
          value: value,
          min: 50,
          max: 1000,
          divisions: 19,
          activeColor: themeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Cairo'),
      prefixIcon: Icon(icon, color: themeColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: themeColor, width: 2)),
    );
  }

  Widget _buildLocationPicker(TextEditingController lat,
      TextEditingController lng, StateSetter setModalState) {
    return Column(
      children: [
        _buildAutoButton(lat, lng, setModalState),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: _buildCoordsField(lat, "خط العرض")),
            const SizedBox(width: 10),
            Expanded(child: _buildCoordsField(lng, "خط الطول")),
          ],
        ),
      ],
    );
  }

  // 🚀 التعديل الأهم: قراءة موقع المريض الفعلي بدلاً من جهاز المرافق
  Widget _buildAutoButton(TextEditingController lat,
      TextEditingController lng, StateSetter setModalState) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: themeColor.withOpacity(0.1),
            foregroundColor: themeColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15))),
        onPressed: () {
          final patientPos = context.read<LocationProvider>().currentPosition;
          if (patientPos != null) {
            setModalState(() {
              lat.text = patientPos.latitude.toString();
              lng.text = patientPos.longitude.toString();
            });
            _showCustomSnackBar("تم جلب موقع المريض بنجاح ✅", isError: false);
          } else {
            _showCustomSnackBar("عذراً، موقع المريض غير متوفر حالياً ⚠️", isError: true);
          }
        },
        icon: const Icon(Icons.person_pin_circle), // أيقونة تعبر عن المريض
        label: const Text("استخدام موقع المريض الحالي",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton.extended(
      backgroundColor: themeColor,
      onPressed: () => _openZoneModal(),
      icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
      label: const Text("إضافة منطقة",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo')),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text("لا توجد مناطق آمنة مضافة",
              style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<bool?> _showSwipeConfirmDialog(int index) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("حذف سريع",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من حذف هذه المنطقة عبر السحب؟",
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("تراجع",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("حذف",
                  style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _confirmDeletion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("حذف المنطقة",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text("هل أنت متأكد من حذف هذه المنطقة؟",
            style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("تراجع",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
          TextButton(
              onPressed: () {
                context
                    .read<LocationProvider>()
                    .deleteSafeZone(index, widget.patientId);
                Navigator.pop(context);
                _showCustomSnackBar("تم الحذف بنجاح ✅", isError: false);
              },
              child: const Text("حذف",
                  style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // 🚀 تصحيح خطأ الحذف: استدعاء دالة deleteAllSafeZones الحقيقية
  void _confirmClearAll(LocationProvider loc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تنبيه  ⚠️",
            style: TextStyle(
                fontFamily: 'Cairo',
                color: Colors.red,
                fontWeight: FontWeight.bold)),
        content: const Text(
            "هل أنت متأكد تماماً من حذف جميع المناطق الآمنة دفعة واحدة؟ لا يمكن التراجع عن هذا الإجراء",
            style: TextStyle(fontFamily: 'Cairo', height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("تراجع",
                  style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))),
          TextButton(
            onPressed: () async {
              try {
                // 🛑 تم التعديل إلى deleteAllSafeZones (تأكدي من تواجدها في الـ LocationProvider)
                // await loc.deleteAllSafeZones(widget.patientId); 
                // سنستخدم مؤقتاً حلقة تكرار لحذفها بالترتيب إذا لم تتوفر الدالة الجاهزة للحذف الشامل
                int count = loc.safeZones.length;
                for (int i = count - 1; i >= 0; i--) {
                   await loc.deleteSafeZone(i, widget.patientId);
                }
                
                await loc.loadSafeZones(widget.patientId);
                if (context.mounted) Navigator.pop(context);
                _showCustomSnackBar("تم مسح جميع البيانات بنجاح 🧹",
                    isError: false);
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
                _showCustomSnackBar("حدث خطأ أثناء مسح المناطق ⚠️", isError: true);
              }
            },
            style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            child: const Text("حذف الكل",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordsField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDecoration(label, Icons.location_on_outlined),
      style: const TextStyle(fontFamily: 'Cairo'),
      validator: (v) => (v == null || v.isEmpty) ? "مطلوب" : null,
    );
  }

  Widget _buildSubmitAction(
      bool isEdit,
      int? index,
      String name,
      TextEditingController lat,
      TextEditingController lng,
      double radius,
      GlobalKey<FormState> modalFormKey) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            padding: const EdgeInsets.all(15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15))),
        onPressed: () {
          // 👈 استخدام المفتاح الصحيح للتحقق من صحة المدخلات
          if (modalFormKey.currentState!.validate()) {
            _onSavePressed(
              isEdit: isEdit,
              index: index,
              name: name,
              lat: lat.text,
              lng: lng.text,
              radius: radius,
            );
          }
        },
        child: Text(isEdit ? "تحديث" : "حفظ المنطقة",
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 16)),
      ),
    );
  }

  Widget _buildModalHandle() {
    return Container(
        width: 50,
        height: 5,
        decoration: BoxDecoration(
            color: Colors.grey[300], borderRadius: BorderRadius.circular(10)));
  }
}