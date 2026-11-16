import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/audio_controller.dart';
import '../widgets/retro_tactile_button.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _permissionDenied = false;
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _requestPermissionAndLoad();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionAndLoad() async {
    setState(() => _permissionDenied = false);

    PermissionStatus audioStatus = await Permission.audio.request();
    if (!audioStatus.isGranted) {
      audioStatus = await Permission.storage.request();
    }

    if (audioStatus.isGranted) {
      await AudioController.instance.loadLocalSongs();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() => _permissionDenied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFEBEE),
              Color(0xFFFFCDD2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 120.w,
                height: 120.w,
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26.r),
                  border: Border.all(
                    color: const Color(0xFF8E0000),
                    width: 3.w,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8E0000),
                      offset: Offset(5.w, 5.h),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: Image.asset(
                    'assets/LOGO.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SizedBox(height: 28.h),
            Text(
              'SOUND MUSIC',
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: const Color(0xFFB71C1C),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'ANALOG RETRO AUDIO DECK',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: const Color(0xFF616161),
              ),
            ),
            SizedBox(height: 40.h),
            if (_permissionDenied)
              RetroTactileButton(
                onTap: _requestPermissionAndLoad,
                isPrimaryRed: true,
                width: 220.w,
                height: 46.h,
                child: Text(
                  'GRANT AUDIO ACCESS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              )
            else
              SizedBox(
                width: 28.w,
                height: 28.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFD32F2F),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
