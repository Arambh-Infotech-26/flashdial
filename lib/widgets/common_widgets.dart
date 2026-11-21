part of '../main.dart';

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF3B2028),
    child: ListTile(
      leading: const Icon(Icons.error_outline, color: Color(0xFFFF8A8D)),
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Dismiss',
        onPressed: onDismiss,
        icon: const Icon(Icons.close),
      ),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
