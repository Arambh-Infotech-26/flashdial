part of '../../main.dart';

class _DialerPage extends StatelessWidget {
  const _DialerPage({
    required this.number,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
  });
  final String number;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;
  static const keys = [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: Text(
                number.isEmpty ? 'Enter a number' : number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: number.isEmpty ? 18 : 30,
                  color: number.isEmpty
                      ? const Color(0xFFAAB5C5)
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (number.isNotEmpty)
              IconButton(
                tooltip: 'Clear number',
                onPressed: onClear,
                icon: const Icon(Icons.backspace_outlined),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: keys.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (_, index) => _DialKey(
          label: keys[index][0],
          sublabel: keys[index][1],
          onPressed: () => onDigit(keys[index][0]),
        ),
      ),
      const SizedBox(height: 22),
      Center(
        child: Semantics(
          button: true,
          label: 'Call ${number.isEmpty ? 'number' : number}',
          child: FloatingActionButton.large(
            onPressed: number.isEmpty ? null : onCall,
            backgroundColor: const Color(0xFFFF6A00),
            child: const Icon(Icons.call_rounded, size: 30),
          ),
        ),
      ),
    ],
  );
}

class _DialKey extends StatelessWidget {
  const _DialKey({
    required this.label,
    required this.sublabel,
    required this.onPressed,
  });
  final String label;
  final String sublabel;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: sublabel.isEmpty ? label : '$label, $sublabel',
    child: Material(
      color: const Color(0xFF101F38),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
            if (sublabel.isNotEmpty)
              Text(
                sublabel,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Color(0xFFAAB5C5),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
