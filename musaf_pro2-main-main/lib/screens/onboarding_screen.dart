import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 ضروري لحفظ حالة المشاهدة

// 🚀 استدعاء ملف الزر المخصص
import 'package:musaf_pro/widgets/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  // متغيرات التحكم في الأنيميشن
  bool showFloatingImage = false;
  bool showAnalysisElements = false;
  bool showSafeZoneElements = false;

  @override
  void initState() {
    super.initState();
    // تشغيل أنيميشن الصفحة الأولى
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => showFloatingImage = true);
    });
  }

  // 🚀 دالة لحفظ حالة إنهاء الـ Onboarding والانتقال
  Future<void> _finishOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true); // حفظ الحالة في الجهاز
    
    if (context.mounted) {
      // توجيه جذري لشاشة تسجيل الدخول لمنع العودة لهذه الشاشة
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // قسم المحتوى المتحرك (الصور والنصوص)
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => isLastPage = index == 2);

                  // إعادة ضبط وتشغيل الأنيميشن عند الانتقال بين الصفحات
                  if (index == 1) {
                    setState(() => showAnalysisElements = false);
                    Timer(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => showAnalysisElements = true);
                    });
                  } else if (index == 2) {
                    setState(() => showSafeZoneElements = false);
                    Timer(const Duration(milliseconds: 400), () {
                      if (mounted) setState(() => showSafeZoneElements = true);
                    });
                  }
                },
                children: [
                  buildPage(
                    context,
                    image: 'assets/images/Hero Section.png',
                    title: 'وضع الطوارئ بلمسة واحدة',
                    desc: 'فعل حالة الطوارئ فوراً بضغطة زر ، وسنقوم بمشاركة موقعك المباشر مع عائلتك فوراً.',
                    isFirst: true,
                  ),
                  buildAnimatedStepPage(
                    context,
                    bgImage: 'assets/images/Main Image Container.png',
                    topCard: 'assets/images/Floating Results Card.png',
                    bottomCard: 'assets/images/Status Alert.png',
                    title: 'تحليل الجروح بالذكاء الاصطناعي',
                    desc: 'احصل على تحليل فوري لإصابتك من خلال الكاميرا، مع إرشادات إسعافية ذكية وتفاعلية لضمان سلامتك.',
                    isVisible: showAnalysisElements,
                  ),
                  buildAnimatedStepPage(
                    context,
                    bgImage: 'assets/images/SafeZone_Main.png',
                    topCard: 'assets/images/SafeZone_Top.png',
                    bottomCard: 'assets/images/SafeZone_Bottom.png',
                    title: 'نطاقات آمنة لعائلتك',
                    desc: 'حدد مناطق آمنة على الخريطة وسنصلك بتنبيه فوري عند خروج المريض منها أو دخوله إليها.',
                    isVisible: showSafeZoneElements,
                  ),
                ],
              ),
            ),

            // قسم التحكم (المؤشر والأزرار)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: 15,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // المؤشر (يبقى LTR ليتوافق مع سحب الصفحة)
                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: const ExpandingDotsEffect(
                      activeDotColor: Color(0xFFB71C1C),
                      dotHeight: 6,
                      dotWidth: 6,
                      expansionFactor: 4,
                      spacing: 8,
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // الأزرار مغلفة بـ Directionality لعرض النصوص العربية بشكل صحيح
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      children: [
                        // 🚀 استخدام دالة الحفظ عند إنهاء الترحيب
                        CustomButton(
                          text: isLastPage ? 'ابدأ الآن' : 'التالي',
                          isPrimary: true, // زر أساسي بخلفية حمراء
                          onPressed: () {
                            if (isLastPage) {
                              _finishOnboarding(context); // 👈 هنا
                            } else {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),

                        if (!isLastPage)
                          // 🚀 استخدام دالة الحفظ عند التخطي
                          CustomButton(
                            text: 'تخطي',
                            isPrimary: false, // زر شفاف بدون خلفية
                            onPressed: () => _finishOnboarding(context), // 👈 وهنا
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // الصفحات المتحركة (2 و 3)
  Widget buildAnimatedStepPage(
    BuildContext context, {
    required String bgImage,
    required String topCard,
    required String bottomCard,
    required String title,
    required String desc,
    required bool isVisible,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(bgImage, fit: BoxFit.contain),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  top: isVisible ? screenWidth * 0.18 : screenWidth * 0.05,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: isVisible ? 1.0 : 0.0,
                    child: Image.asset(topCard, width: screenWidth * 0.55),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  bottom: isVisible ? screenWidth * 0.22 : screenWidth * 0.05,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: isVisible ? 1.0 : 0.0,
                    child: Image.asset(bottomCard, width: screenWidth * 0.6),
                  ),
                ),
              ],
            ),
          ),
          buildTextSection(screenWidth, title, desc),
        ],
      ),
    );
  }

  // الصفحة الأولى
  Widget buildPage(
    BuildContext context, {
    required String image,
    required String title,
    required String desc,
    bool isFirst = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Image.asset(image, fit: BoxFit.contain),
                if (isFirst)
                  Positioned(
                    top: screenWidth * 0.45,
                    right: screenWidth * 0.05,
                    child: AnimatedOpacity(
                      opacity: showFloatingImage ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: Image.asset(
                        'assets/images/Floating .png',
                        width: screenWidth * 0.45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          buildTextSection(screenWidth, title, desc),
        ],
      ),
    );
  }

  // قسم النصوص مع دعم RTL
  Widget buildTextSection(double screenWidth, String title, String desc) {
    return Expanded(
      flex: 2,
      child: Directionality(
        textDirection: TextDirection.rtl, // لضمان ظهور النصوص العربية بشكل صحيح
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.052,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.038,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}