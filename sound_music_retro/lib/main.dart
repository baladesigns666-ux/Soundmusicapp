import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'services/audio_controller.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.kitesoftwares.soundmusic.channel.audio',
    androidNotificationChannelName: 'Sound Music & FM Playback',
    androidNotificationOngoing: true,
    androidShowNotificationBadge: true,
    androidNotificationIcon: 'mipmap/ic_launcher',
    notificationColor: const Color(0xFFC62828),
  );

  // Lock screen orientation to Portrait Only (Non-Rotate)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await AudioController.instance.init();

  runApp(const SoundMusicApp());
}

class SoundMusicApp extends StatelessWidget {
  const SoundMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFAF3E8),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFC62828),
        primary: const Color(0xFFC62828),
        surface: const Color(0xFFFAF3E8),
      ),
    );

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, child) {
        return MaterialApp(
          title: 'Sound Music',
          debugShowCheckedModeBanner: false,
          theme: baseTheme.copyWith(
            textTheme: GoogleFonts.montserratTextTheme(baseTheme.textTheme).apply(
              fontFamily: GoogleFonts.montserrat().fontFamily,
            ),
          ),
          // Lock System Font Scaling globally
          builder: (context, widget) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: widget!,
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
