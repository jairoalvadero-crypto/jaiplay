import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:audio_service/audio_service.dart';
import 'package:permission_handler/permission_handler.dart';

import 'cloud.dart';
import 'audio_handler.dart';
import 'downloads.dart';
import 'screens/shell.dart';
import 'settings.dart';
import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => JaiPlayAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.jaiplay.app.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
    ),
  );
  await store.load();
  await appSettings.load();
  await downloads.load();
  await cloud.load();
  cloud.syncNow();
  if (!kIsWeb && await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  runApp(const JaiPlayApp());
}

class JaiPlayApp extends StatelessWidget {
  const JaiPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JaiPlay',
      theme: buildTheme(),
      home: const Shell(),
      builder: (context, child) => NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            switch (notification.direction) {
              case ScrollDirection.reverse:
                miniPlayerVisible.value = false;
              case ScrollDirection.forward:
                miniPlayerVisible.value = true;
              case ScrollDirection.idle:
                break;
            }
          }
          return false;
        },
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
