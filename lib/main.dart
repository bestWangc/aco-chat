import 'package:aco_chat/core/theme/aco_typography.dart';
import 'package:aco_chat/features/design/presentation/aco_design_shell.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

void main() {
  runApp(const AcoApp());
}

class AcoApp extends StatelessWidget {
  const AcoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFA6FF00);
    return shad.ShadApp.custom(
      theme: shad.ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: shad.ShadSlateColorScheme.dark(),
      ),
      appBuilder: (_) => CupertinoApp(
        title: 'Aco',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: const CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: accent,
          scaffoldBackgroundColor: Color(0xFF050505),
          textTheme: CupertinoTextThemeData(
            textStyle: TextStyle(
              fontFamily: 'PingFang',
              fontSize: AcoTypography.body,
            ),
          ),
        ),
        home: const AcoDesignShell(),
      ),
    );
  }
}
