import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/brevis_bridge.dart';
import 'state/config_controller.dart';
import 'state/model_controller.dart';
import 'state/theme_controller.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const BrevisApp());
}

class BrevisApp extends StatefulWidget {
  const BrevisApp({super.key});

  @override
  State<BrevisApp> createState() => _BrevisAppState();
}

class _BrevisAppState extends State<BrevisApp> {
  late final ConfigController _configController;
  late final ModelController _modelController;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _configController = ConfigController(BrevisBridge.instance);
    _modelController = ModelController(BrevisBridge.instance)..init();
    _themeController = ThemeController()..load();
  }

  @override
  void dispose() {
    _configController.dispose();
    _modelController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Brevis',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeController.mode,
          home: HomeScreen(
            controller: _configController,
            modelController: _modelController,
            themeController: _themeController,
          ),
        );
      },
    );
  }
}
