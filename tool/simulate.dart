// Parser simulation for upi_link.
//
// Generates thousands of UPI links and checks how UpiLink.parse handles them:
//   1. Round trip: random valid links must survive toString -> parse.
//   2. Real-world variants: QR shapes from common apps plus mutations that
//      real scanners, apps and copy-paste produce. Each case is labelled
//      "should parse" or "should reject", and mismatches are reported.
//   3. Fuzz: random and corrupted strings must only ever throw
//      FormatException, never crash with another error type.
//
// Run from the package root:
//   dart run tool/simulate.dart            (seed 42, 10000 iterations)
//   dart run tool/simulate.dart 7 50000    (custom seed and iterations)
//
// All addresses and names are generated; no real person's data is used.

import 'dart:math';

import 'package:upi_link/upi_link.dart';

void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 42;
  final iterations = args.length > 1 ? int.parse(args[1]) : 10000;
  final rng = Random(seed);
  print('upi_link parser simulation (seed $seed, $iterations iterations)\n');

  final ok = [
    _roundTrip(rng, iterations),
    _realWorld(rng),
    _fuzz(rng, iterations),
  ].every((passed) => passed);

  print(ok ? '\nRESULT: no unexpected behaviour' : '\nRESULT: see failures');
}

// ---------------------------------------------------------------------------
// 1. Round trip
// ---------------------------------------------------------------------------

bool _roundTrip(Random rng, int n) {
  var failures = 0;
  for (var i = 0; i < n; i++) {
    final link = _randomValidLink(rng);
    final text = link.toString();
    try {
      final back = UpiLink.parse(text);
      if (back != link) {
        failures++;
        if (failures <= 5) print('  round-trip mismatch: $text');
      }
    } on Object catch (e) {
      failures++;
      if (failures <= 5) print('  round-trip threw ${e.runtimeType}: $text');
    }
  }
  print('[1] Round trip: ${n - failures}/$n passed');
  return failures == 0;
}

UpiLink _randomValidLink(Random rng) {
  String? maybe(String Function() f) => rng.nextBool() ? f() : null;
  final extras = <String, String>{};
  for (var i = rng.nextInt(4); i > 0; i--) {
    extras[_pick(rng, _vendorKeys)] = _randomText(rng, allowEmpty: true);
  }
  return UpiLink(
    payeeAddress: _randomAddress(rng),
    payeeName: _randomText(rng),
    amount: maybe(() => _randomAmount(rng)),
    transactionNote: maybe(() => _randomText(rng)),
    transactionRef: maybe(() => _randomText(rng)),
    merchantCode: maybe(() => rng.nextInt(10000).toString().padLeft(4, '0')),
    transactionId: maybe(() => _randomText(rng)),
    referenceUrl: rng.nextInt(4) == 0
        ? Uri.parse('https://shop.example/o/${rng.nextInt(9999)}?x=1&y=a b')
        : null,
    extraParameters: extras,
  );
}

// ---------------------------------------------------------------------------
// 2. Real-world variants
// ---------------------------------------------------------------------------

class _Case {
  _Case(this.category, this.name, this.text, {required this.shouldParse});
  final String category;
  final String name;
  final String text;
  final bool shouldParse;
}

bool _realWorld(Random rng) {
  final cases = _realWorldCases(rng);
  final byCategory = <String, List<_Case>>{};
  final unexpected = <_Case, String>{};

  for (final c in cases) {
    byCategory.putIfAbsent(c.category, () => []).add(c);
    String outcome;
    try {
      UpiLink.parse(c.text);
      outcome = 'parsed';
    } on FormatException catch (e) {
      outcome = 'rejected: ${e.message}';
    } on Object catch (e) {
      outcome = 'CRASH ${e.runtimeType}: $e';
    }
    final parsed = outcome == 'parsed';
    if (parsed != c.shouldParse || outcome.startsWith('CRASH')) {
      unexpected[c] = outcome;
    }
  }

  print('[2] Real-world variants: ${cases.length - unexpected.length}'
      '/${cases.length} behaved as expected');
  for (final entry in byCategory.entries) {
    final bad = entry.value.where(unexpected.containsKey).length;
    print('    ${bad == 0 ? 'ok  ' : 'FAIL'} ${entry.key} '
        '(${entry.value.length - bad}/${entry.value.length})');
  }
  if (unexpected.isNotEmpty) {
    print('\n    Unexpected outcomes:');
    for (final entry in unexpected.entries) {
      final c = entry.key;
      print('    - [${c.category}] ${c.name}');
      print('      expected: ${c.shouldParse ? 'parse' : 'reject'}, '
          'got: ${entry.value}');
      print('      input: ${c.text.replaceAll('\n', r'\n')}');
    }
  }
  return unexpected.isEmpty;
}

List<_Case> _realWorldCases(Random rng) {
  final cases = <_Case>[];
  void good(String cat, String name, String text) =>
      cases.add(_Case(cat, name, text, shouldParse: true));
  void bad(String cat, String name, String text) =>
      cases.add(_Case(cat, name, text, shouldParse: false));

  // App QR shapes, each with fresh random values.
  for (var i = 0; i < 20; i++) {
    final phone = '9${rng.nextInt(999999999).toString().padLeft(9, '0')}';
    final name = Uri.encodeComponent(_pick(rng, _names));
    good('App QR shapes', 'PhonePe-style personal',
        'upi://pay?pa=$phone@ybl&pn=$name&mc=0000&mode=02&purpose=00');
    good(
        'App QR shapes',
        'GPay merchant',
        'upi://pay?pa=gpay-1$phone@okbizaxis&mc=5411&pn=$name&oobe=fos123'
            '&qrst=snp&tr=$phone&cu=INR&ver=01&mode=01');
    good(
        'App QR shapes',
        'Paytm merchant',
        'upi://pay?pa=paytmqr$phone@paytm&pn=$name&mc=5499&mode=02'
            '&orgid=000000&paytmqr=$phone&sign=MEUCIQ${rng.nextInt(99999)}');
    good('App QR shapes', 'GPay personal with aid',
        'upi://pay?pa=user.$phone@okhdfcbank&pn=$name&aid=uGICAgICAgA');
    good(
        'App QR shapes',
        'BharatPe merchant',
        'upi://pay?pa=BHARATPE$phone@yesbankltd&pn=$name&cu=INR'
            '&tn=Pay%20to%20$name');
    good(
        'App QR shapes',
        'Signed dynamic QR',
        'upi://pay?pa=shop$i@icici&pn=$name&tr=EZV$phone'
            '&am=${_randomAmount(rng)}&mam=1.00&cu=INR&mode=15');
  }

  const base = 'upi://pay?pa=test.user@okaxis&pn=Test%20User';

  // Scanner and copy-paste artefacts.
  good('Copy-paste artefacts', 'trailing newline', '$base\n');
  good('Copy-paste artefacts', 'leading spaces', '   $base');
  good('Copy-paste artefacts', 'HTML-escaped &amp;',
      'upi://pay?pa=test.user@okaxis&amp;pn=Test%20User&amp;mode=02');
  good('Copy-paste artefacts', 'trailing &', '$base&');
  good('Copy-paste artefacts', 'double &&', '$base&&mode=02');
  good('Copy-paste artefacts', 'trailing slash after pay',
      'upi://pay/?pa=test.user@okaxis&pn=Test%20User');
  good('Copy-paste artefacts', 'spaces as +',
      'upi://pay?pa=test.user@okaxis&pn=Test+User');
  good('Copy-paste artefacts', 'tab and CRLF around', '\t$base\r\n');

  // Casing.
  good('Casing', 'upper-case scheme and host',
      'UPI://PAY?pa=test.user@okaxis&pn=Test');
  good('Casing', 'upper-case keys', 'upi://pay?PA=test.user@okaxis&PN=Test');
  good('Casing', 'lower-case currency', '$base&cu=inr');
  good('Casing', 'upper-case address', 'upi://pay?pa=TEST.USER@OKAXIS&pn=T');

  // Amounts.
  good('Amounts', 'empty am', '$base&am=');
  good('Amounts', 'whole rupees', '$base&am=100');
  good('Amounts', 'one decimal', '$base&am=99.5');
  good('Amounts', 'two decimals', '$base&am=99.50');
  good('Amounts', 'leading zero', '$base&am=0.50');
  bad('Amounts', 'three decimals', '$base&am=1.000');
  bad('Amounts', 'zero amount', '$base&am=0.00');
  bad('Amounts', 'negative', '$base&am=-10');
  bad('Amounts', 'rupee sign', '$base&am=%E2%82%B9100');
  bad('Amounts', 'thousands separator', '$base&am=1,000');
  bad('Amounts', 'trailing space', '$base&am=100%20');

  // Names and notes.
  good('Names and notes', 'double spaces', 'upi://pay?pa=a@ybl&pn=A%20%20B');
  good('Names and notes', 'Hindi name',
      'upi://pay?pa=a@ybl&pn=%E0%A4%B0%E0%A4%BE%E0%A4%AE');
  good('Names and notes', 'emoji in note', '$base&tn=Chai%20%E2%98%95');
  good('Names and notes', 'ampersand encoded', 'upi://pay?pa=a@ybl&pn=A%26B');
  good('Names and notes', 'very long note',
      '$base&tn=${List.filled(500, 'x').join()}');
  bad('Names and notes', 'missing pn', 'upi://pay?pa=test.user@okaxis');
  bad('Names and notes', 'empty pn', 'upi://pay?pa=test.user@okaxis&pn=');
  bad('Names and notes', 'blank pn', 'upi://pay?pa=test.user@okaxis&pn=%20');

  // Addresses.
  good('Addresses', 'hyphen in user', 'upi://pay?pa=gpay-123@okbizaxis&pn=A');
  good('Addresses', 'digits in handle', 'upi://pay?pa=a@axisb2b&pn=A');
  good('Addresses', 'encoded @', 'upi://pay?pa=a%40ybl&pn=A');
  bad('Addresses', 'missing pa', 'upi://pay?pn=A');
  bad('Addresses', 'no @', 'upi://pay?pa=nobank&pn=A');
  bad('Addresses', 'hyphen in handle', 'upi://pay?pa=a@yes-bank&pn=A');
  bad('Addresses', 'two @', 'upi://pay?pa=a@b@ybl&pn=A');
  bad('Addresses', 'plus in user', 'upi://pay?pa=a%2Bb@ybl&pn=A');

  // Keys.
  good('Keys', 'unknown key kept', '$base&mode=02');
  good('Keys', 'leading key without value', 'upi://pay?flag&pa=a@ybl&pn=A');

  // Values a sloppy generator did not encode.
  good('Unencoded values', 'raw & in name', 'upi://pay?pa=a@ybl&pn=A&B%20Co');
  good('Unencoded values', 'raw & in note', '$base&tn=Tea&Snacks&mode=02');
  good('Unencoded values', 'raw space in name', 'upi://pay?pa=a@ybl&pn=A B');
  good('Unencoded values', 'raw Hindi', 'upi://pay?pa=a@ybl&pn=राम');
  // Known limitation: indistinguishable from pn=A plus an extra key B=C,
  // so it parses with the wrong name. Recorded in doc/parser-simulation.md.
  good('Unencoded values', 'raw & followed by = (misread)',
      'upi://pay?pa=a@ybl&pn=A&B=C');
  good('Keys', 'same key twice, same value', '$base&pn=Test%20User');
  good('Keys', 'unknown key twice', '$base&mode=01&mode=02');
  bad('Keys', 'supported key twice, different values', '$base&pn=Other');
  bad('Keys', 'empty key', '$base&=x');

  // Other fields.
  good('Other fields', 'mc 0000', '$base&mc=0000');
  good('Other fields', 'https url', '$base&url=https%3A%2F%2Fshop.example');
  bad('Other fields', 'mc with 5 digits', '$base&mc=54110');
  bad('Other fields', 'url without scheme', '$base&url=www.shop.example');
  bad('Other fields', 'non-INR currency', '$base&cu=USD');

  // Not a UPI pay link.
  bad('Not a pay link', 'mandate link', 'upi://mandate?pa=a@ybl&pn=A');
  bad('Not a pay link', 'https link', 'https://pay?pa=a@ybl&pn=A');
  bad('Not a pay link', 'app-specific scheme', 'phonepe://pay?pa=a@ybl&pn=A');
  bad('Not a pay link', 'tez scheme', 'tez://upi/pay?pa=a@ybl&pn=A');
  bad('Not a pay link', 'empty string', '');
  bad('Not a pay link', 'fragment', '$base#x');

  return cases;
}

// ---------------------------------------------------------------------------
// 3. Fuzz
// ---------------------------------------------------------------------------

bool _fuzz(Random rng, int n) {
  var crashes = 0;
  var parsed = 0;
  final seen = <String>{};
  for (var i = 0; i < n; i++) {
    final input = i.isEven
        ? _mutate(rng, _randomValidLink(rng).toString())
        : _garbage(rng);
    try {
      UpiLink.parse(input);
      parsed++;
    } on FormatException {
      // Expected for bad input.
    } on Object catch (e) {
      crashes++;
      final key = e.runtimeType.toString();
      if (seen.add(key)) {
        print('  CRASH ${e.runtimeType}: $e\n    input: $input');
      }
    }
  }
  print('[3] Fuzz: $n inputs, $parsed parsed, ${n - parsed - crashes} '
      'rejected with FormatException, $crashes crashed');
  return crashes == 0;
}

String _mutate(Random rng, String s) {
  final chars = s.split('');
  for (var i = rng.nextInt(4) + 1; i > 0; i--) {
    final pos = rng.nextInt(chars.length);
    switch (rng.nextInt(4)) {
      case 0:
        chars.removeAt(pos);
      case 1:
        chars.insert(pos, _pick(rng, ['%', '&', '=', '?', '#', '@', ' ', '/']));
      case 2:
        chars[pos] = String.fromCharCode(rng.nextInt(0x3000));
      default:
        chars.insert(pos, chars[pos]);
    }
    if (chars.isEmpty) break;
  }
  return chars.join();
}

String _garbage(Random rng) {
  const alphabet = 'upi:/?&=%@.pay aAzZ09-_#+₹र';
  final len = rng.nextInt(60);
  return List.generate(len, (_) => alphabet[rng.nextInt(alphabet.length)])
      .join();
}

// ---------------------------------------------------------------------------
// Random data
// ---------------------------------------------------------------------------

const _handles = [
  'ybl',
  'okaxis',
  'oksbi',
  'okhdfcbank',
  'paytm',
  'ibl',
  'axl',
  'upi',
  'icici',
  'pty',
  'okbizaxis',
  'yesbankltd'
];
const _names = [
  'Test User',
  'Asha Rao',
  'Chai Point',
  'Ravi  Kumar',
  'R K Stores',
  'राम',
  'Café Uno',
  'A&B Traders',
  'Mr. X/Y'
];
const _vendorKeys = [
  'mode',
  'purpose',
  'orgid',
  'sign',
  'mam',
  'aid',
  'ver',
  'qrst',
  'oobe',
  'paytmqr',
  'mid',
  'msid',
  'mtid'
];

T _pick<T>(Random rng, List<T> list) => list[rng.nextInt(list.length)];

String _randomAddress(Random rng) {
  const userChars = 'abcdefghijklmnopqrstuvwxyz0123456789._-';
  final user = List.generate(
    rng.nextInt(20) + 1,
    (_) => userChars[rng.nextInt(userChars.length)],
  ).join();
  return '$user@${_pick(rng, _handles)}';
}

String _randomAmount(Random rng) {
  final rupees = rng.nextInt(100000) + 1;
  return switch (rng.nextInt(3)) {
    0 => '$rupees',
    1 => '$rupees.${rng.nextInt(10)}',
    _ => '$rupees.${rng.nextInt(100).toString().padLeft(2, '0')}',
  };
}

String _randomText(Random rng, {bool allowEmpty = false}) {
  if (allowEmpty && rng.nextInt(5) == 0) return '';
  const extra = ' &=?#%+/@:;,\'"<>₹☕é';
  final base = _pick(rng, _names);
  final noise = List.generate(
    rng.nextInt(4),
    (_) => extra[rng.nextInt(extra.length)],
  ).join();
  return '$base$noise';
}
