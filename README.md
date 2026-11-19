# upi_link

[![pub package](https://img.shields.io/pub/v/upi_link.svg)](https://pub.dev/packages/upi_link)
[![CI](https://github.com/devMKunal/upi_link/actions/workflows/ci.yml/badge.svg)](https://github.com/devMKunal/upi_link/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Build and parse UPI payment links (`upi://pay?...`) in pure Dart.

`upi_link` turns payment details into a spec-correct UPI link and reads one
back. It has no dependencies and no Flutter requirement, so it works in Flutter
apps, Dart backends that generate payment links, and CLI tools.

## Features

- **Build** a `upi://pay` link from typed, named parameters.
- **Parse** a link (from a QR code or deep link) back into a `UpiLink`.
- **Round-trip safe:** `UpiLink.parse(link.toString()) == link`.
- **Exact amounts:** amounts are decimal strings with at most 2 places, never
  `double`, so no rounding error can reach a payment.
- **Spec-correct encoding:** spaces become `%20`, not `+`. Dart's
  `Uri(queryParameters: ...)` writes `+`, which some UPI apps display literally.
- **Fails early:** invalid input throws when you build the link, naming the
  field, instead of failing inside the payer's UPI app.

## Install

```sh
dart pub add upi_link
```

## Usage

### Build a link

```dart
import 'package:upi_link/upi_link.dart';

final link = UpiLink(
  payeeAddress: 'chaipoint@okaxis',
  payeeName: 'Chai Point',
  amount: '149.50',
  transactionNote: 'Order 42',
  transactionRef: 'ORD-42',
);

print(link);
// upi://pay?pa=chaipoint@okaxis&pn=Chai%20Point&am=149.50&cu=INR&tn=Order%2042&tr=ORD-42
```

Pass `link.toString()` to a QR code widget, or `link.toUri()` to
[`url_launcher`](https://pub.dev/packages/url_launcher) to open the payer's UPI
app.

### Parse a link

```dart
final link = UpiLink.parse(scannedText); // throws FormatException if invalid
print(link.payeeName);
print(link.amount);

final maybe = UpiLink.tryParse(scannedText); // null if invalid
```

### Handle invalid input

```dart
try {
  UpiLink(payeeAddress: 'chaipoint', payeeName: 'Chai Point');
} on UpiLinkException catch (e) {
  print(e.field);   // payeeAddress
  print(e.message); // Expected a UPI address like "name@bank", got "chaipoint"
}
```

## Supported parameters

| Dart field        | Spec key | Rules                                           |
| ----------------- | -------- | ----------------------------------------------- |
| `payeeAddress`    | `pa`     | Required. `name@handle`                         |
| `payeeName`       | `pn`     | Required. Not blank                             |
| `amount`          | `am`     | Positive, at most 2 decimal places, e.g. `'149.50'` |
| `transactionNote` | `tn`     | Not blank when given                            |
| `transactionRef`  | `tr`     | Not blank when given                            |
| `merchantCode`    | `mc`     | Exactly 4 digits                                |
| `transactionId`   | `tid`    | Not blank when given                            |
| `referenceUrl`    | `url`    | Absolute `http`/`https` URL                     |

`cu=INR` is always written. When parsing, `cu` may be absent but must be `INR`
if present.

## Parsing real QR codes

QR codes from UPI apps often carry keys beyond the 8 supported fields, such as
`mode`, `purpose`, `orgid`, `sign`, or app-specific keys. `UpiLink.parse` keeps
those in `extraParameters` instead of rejecting the link, and writes them back
out in `toString()`, so a scanned link can be re-shared without losing data.

```dart
final link = UpiLink.parse(
  'upi://pay?pa=9876543210@axl&pn=Test%20User&mc=0000&mode=02&purpose=00',
);
print(link.payeeName);       // Test User
print(link.extraParameters); // {mode: 02, purpose: 00}
```

`parse` also tolerates other things real apps and copy-paste produce:

| Input | How it is read |
| --- | --- |
| `am=` (empty value) | As if `am` were absent |
| `PA=`, `Pn=` | Same as `pa`, `pn` |
| `cu=inr` | Same as `cu=INR` |
| `&&` or a trailing `&` | Ignored |
| `upi://pay/?...` | Same as `upi://pay?...` |
| `&amp;` (copied from HTML) | Read as `&` |
| `pn=A&B%20Co` (unencoded `&`) | Name `A&B Co` |
| Leading/trailing whitespace | Trimmed |

It still throws a `FormatException` for links it cannot read safely: a missing
`pa` or `pn`, a currency other than INR, a supported key repeated with different
values, malformed percent-encoding, or an invalid address, amount, merchant
code or URL.

Known limitations, and the simulation that finds them, are listed in
[doc/parser-simulation.md](doc/parser-simulation.md).

## How it compares

Most UPI packages on pub.dev are Flutter plugins that launch UPI apps. They need
Flutter and platform code. `upi_link` only builds and parses the link, so you
can use it on its own or together with any of them.

## Contributing

Issues and pull requests are welcome at
[github.com/devMKunal/upi_link](https://github.com/devMKunal/upi_link/issues).

## License

MIT. See [LICENSE](LICENSE).
