import 'package:material_ui/material_ui.dart';

class BankTheme {
  static const green = Color(0xFF163F35);
  static const ink = Color(0xFF1D302A);
  static const muted = Color(0xFF68766F);
  static const canvas = Color(0xFFF4F6F3);
  static const line = Color(0xFFE0E6DF);
  static const pale = Color(0xFFEAF1E9);
  static const lime = Color(0xFFD4EEA0);
  static const amber = Color(0xFF8C5A13);
  static const red = Color(0xFFB13A35);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const ['Roboto', 'Arial'],
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAF7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: green,
          side: const BorderSide(color: line),
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          minimumSize: const Size(44, 44),
        ),
      ),
    );
  }

  static String money(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'R\$ $whole,${parts.last}';
  }

  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
}

class BankBrand extends StatelessWidget {
  const BankBrand({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: light ? BankTheme.lime : BankTheme.green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.account_balance_outlined,
          size: 20,
          color: light ? BankTheme.green : Colors.white,
        ),
      ),
      const SizedBox(width: 10),
      Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: 'ICEI',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const TextSpan(
              text: 'Bank',
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
          ],
        ),
        style: TextStyle(
          fontSize: 21,
          letterSpacing: -.6,
          color: light ? Colors.white : BankTheme.green,
        ),
      ),
    ],
  );
}

class BankSurface extends StatelessWidget {
  const BankSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: BankTheme.line),
    ),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class BankBadge extends StatelessWidget {
  const BankBadge(
    this.label, {
    super.key,
    this.color = BankTheme.green,
    this.background = BankTheme.pale,
  });
  final String label;
  final Color color;
  final Color background;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
