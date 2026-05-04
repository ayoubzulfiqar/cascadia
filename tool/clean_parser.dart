import 'dart:io';

void main() {
  final file = File('lib/src/parser.dart');
  final lines = file.readAsLinesSync();
  // Remove lines 461-639 inclusive (1-indexed => indices 460..638)
  final start = 460; // 0-based index of line 461
  final end = 639; // inclusive, 0-based index of line 639
  final newLines = <String>[];
  for (int i = 0; i < lines.length; i++) {
    if (i >= start && i <= end) continue;
    newLines.add(lines[i]);
  }
  file.writeAsStringSync('${newLines.join('\n')}\n');
  print('Removed lines ${start + 1}-${end + 1}');
}
