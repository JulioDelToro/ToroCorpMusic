import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_video_screen.dart';
import 'features/studio/presentation/studio_recording_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ToroMusicApp());
}

class ToroMusicApp extends StatefulWidget {
  final bool showSplash;

  const ToroMusicApp({super.key, this.showSplash = true});

  @override
  State<ToroMusicApp> createState() => _ToroMusicAppState();
}

class _ToroMusicAppState extends State<ToroMusicApp> {
  late bool _splashFinished;

  @override
  void initState() {
    super.initState();
    _splashFinished = !widget.showSplash;
  }

  void _onSplashFinished() {
    setState(() {
      _splashFinished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toro Music Teleprompter',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: AppTheme.darkOledTheme,
      darkTheme: AppTheme.darkOledTheme,
      home: _splashFinished
          ? const StudioRecordingScreen()
          : SplashVideoScreen(onFinished: _onSplashFinished),
    );
  }
}
