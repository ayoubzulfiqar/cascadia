// ignore_for_file: avoid_print
//
// Enforces a minimum line-coverage threshold from coverage/lcov.info.
//
// The audit's central lesson was that a green suite proves nothing if it never
// exercises the code: 48/48 tests passed while the library hung on documented
// input. This gate keeps the suite honest as the package grows.
//
// Usage:
//   dart test --coverage=coverage
//   dart pub global run coverage:format_coverage --lcov --in=coverage \
//       --out=coverage/lcov.info --report-on=lib --check-ignore
//   dart run tool/check_coverage.dart [--min=85]
import 'dart:io';

void main(List<String> args) {
  var minimum = 85.0;
  for (final arg in args) {
    if (arg.startsWith('--min=')) {
      minimum = double.tryParse(arg.substring(6)) ?? minimum;
    }
  }

  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('coverage/lcov.info not found. Generate it with:\n'
        '  dart test --coverage=coverage\n'
        '  dart pub global run coverage:format_coverage --lcov '
        '--in=coverage --out=coverage/lcov.info --report-on=lib '
        '--check-ignore');
    exit(2);
  }

  var total = 0;
  var covered = 0;
  final perFile = <String, List<int>>{};
  String? current;

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/').split('/lib/').last;
      perFile.putIfAbsent(current, () => [0, 0]);
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      final hits = int.tryParse(parts[1]) ?? 0;
      perFile[current]![0] += 1;
      total += 1;
      if (hits > 0) {
        perFile[current]![1] += 1;
        covered += 1;
      }
    }
  }

  if (total == 0) {
    stderr.writeln('No coverage data found in coverage/lcov.info.');
    exit(2);
  }

  final percent = covered * 100 / total;
  final entries = perFile.entries.toList()
    ..sort((a, b) => (a.value[1] / (a.value[0] == 0 ? 1 : a.value[0]))
        .compareTo(b.value[1] / (b.value[0] == 0 ? 1 : b.value[0])));

  for (final e in entries) {
    final lines = e.value[0];
    final hit = e.value[1];
    final pct = lines == 0 ? 100.0 : hit * 100 / lines;
    print('${pct.toStringAsFixed(1).padLeft(6)}%  '
        '${hit.toString().padLeft(4)}/${lines.toString().padRight(5)} ${e.key}');
  }

  print('\nTOTAL $covered/$total = ${percent.toStringAsFixed(1)}% '
      '(minimum ${minimum.toStringAsFixed(1)}%)');

  if (percent < minimum) {
    stderr.writeln('\nCoverage ${percent.toStringAsFixed(1)}% is below the '
        '${minimum.toStringAsFixed(1)}% minimum.');
    exit(1);
  }
  print('Coverage gate passed.');
}
