part of '../main.dart';

class FlashDialApp extends StatelessWidget {
  const FlashDialApp({required this.firebaseReady, super.key});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FlashDial',
    debugShowCheckedModeBanner: false,
    theme: FlashDialTheme.dark(),
    home: AuthGate(firebaseReady: firebaseReady),
  );
}

class FlashDialTheme {
  static ThemeData dark() {
    const navy = Color(0xFF07152E);
    const deep = Color(0xFF030B1A);
    const surface = Color(0xFF101F38);
    const orange = Color(0xFFFF6A00);
    const text = Color(0xFFF5F7FB);
    const muted = Color(0xFFAAB5C5);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deep,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        onPrimary: Colors.white,
        secondary: Color(0xFFFF9D00),
        surface: surface,
        onSurface: text,
        error: Color(0xFFE5484D),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: text,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: muted, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        errorMaxLines: 2,
      ),
    );
  }
}
