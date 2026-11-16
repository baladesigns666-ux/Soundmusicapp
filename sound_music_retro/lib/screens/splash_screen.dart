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

class _SplashScreenState extends State<SplashScreen> {
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
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
            // Retro Cassette Emblem
            Container(
              width: 112.w,
              height: 112.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24.r),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.album_rounded,
                    color: Colors.white,
                    size: 52.sp,
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'HI-FI 90s',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                  ),
                ],
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
