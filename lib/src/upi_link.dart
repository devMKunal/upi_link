import 'upi_link_exception.dart';

/// A UPI payment link (`upi://pay?...`) as defined by NPCI's UPI linking
/// specification.
///
/// Build a link from payment details:
///
/// ```dart
/// final link = UpiLink(
///   payeeAddress: 'chaipoint@okaxis',
///   payeeName: 'Chai Point',
///   amount: '149.50',
/// );
/// print(link); // upi://pay?pa=chaipoint@okaxis&pn=Chai%20Point&am=149.50&cu=INR
/// ```
///
/// Or read one back with [UpiLink.parse] / [UpiLink.tryParse].
///
/// Instances are immutable and compare by value, so
/// `UpiLink.parse(link.toString()) == link` holds for every valid link.
///
/// Real QR codes often carry keys outside the 8 supported fields, such as
/// `mode`, `purpose` or app-specific keys. [parse] keeps those in
/// [extraParameters] instead of rejecting the link.
///
/// The constructor validates every argument and throws a
/// [UpiLinkException] naming the offending field.
final class UpiLink {
  /// Creates a payment link, validating every argument.
  ///
  /// Throws a [UpiLinkException] when:
  /// * [payeeAddress] is not a valid UPI address (`name@handle`),
  /// * [payeeName] is blank,
  /// * [amount] is not a positive number with at most 2 decimal places,
  /// * [merchantCode] is not exactly 4 digits,
  /// * [referenceUrl] is not an absolute `http` or `https` URL,
  /// * any optional text field is an empty string,
  /// * an [extraParameters] key is empty, contains characters other than
  ///   letters, digits, `.`, `_` or `-`, or names a supported field
  ///   (including `cu`).
  UpiLink({
    required this.payeeAddress,
    required this.payeeName,
    this.amount,
    this.transactionNote,
    this.transactionRef,
    this.merchantCode,
    this.transactionId,
    this.referenceUrl,
    Map<String, String> extraParameters = const {},
  }) : extraParameters = Map.unmodifiable(extraParameters) {
    _validate();
  }

  /// Parses a `upi://pay` link, such as the text of a scanned QR code.
  ///
  /// Parsing accepts what real UPI apps produce:
  /// * keys outside the supported fields (for example `mode`, `purpose`,
  ///   `orgid`, `sign`) are kept in [extraParameters], in their original
  ///   order,
  /// * a supported key with an empty value (`am=`) is treated as absent,
  /// * supported keys match case-insensitively (`PA=` reads as `pa`),
  /// * `cu` matches `INR` case-insensitively,
  /// * empty segments (`&&`, a trailing `&`) and a trailing `/` after
  ///   `pay` are ignored, and surrounding whitespace is trimmed,
  /// * HTML-escaped separators (`&amp;`), common when a link is copied
  ///   from a web page, are read as `&`,
  /// * values may encode spaces as `%20` or `+`.
  ///
  /// Throws a [FormatException] when:
  /// * the scheme is not `upi` or the host is not `pay`,
  /// * the link has another path, a fragment, user info or a port,
  /// * the percent-encoding is malformed,
  /// * a key is empty or contains characters other than letters, digits,
  ///   `.`, `_` or `-`,
  /// * a supported key appears twice with different values,
  /// * `pa` or `pn` is missing or empty,
  /// * `cu` is present and is not `INR`,
  /// * a supported value fails the validation described on [UpiLink.new].
  ///
  /// When an unsupported key appears more than once, the first value wins.
  static UpiLink parse(String source) {
    final input = source.trim().replaceAll('&amp;', '&');
    if (_badPercent.hasMatch(input)) {
      throw FormatException('Malformed percent-encoding', source);
    }
    final uri = Uri.tryParse(input);
    if (uri == null) {
      throw FormatException('Not a valid URI', source);
    }
    if (uri.scheme != 'upi') {
      throw FormatException('Scheme must be "upi"', source);
    }
    if (uri.host != 'pay') {
      throw FormatException('Host must be "pay"', source);
    }
    if ((uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      throw FormatException(
        'Link must have no path, fragment, user info or port',
        source,
      );
    }

    final values = <String, String>{};
    final extras = <String, String>{};
    if (uri.hasQuery) {
      for (final segment in uri.query.split('&')) {
        if (segment.isEmpty) continue;
        final eq = segment.indexOf('=');
        final rawKey = eq < 0 ? segment : segment.substring(0, eq);
        final rawValue = eq < 0 ? '' : segment.substring(eq + 1);
        if (!_keyPattern.hasMatch(rawKey)) {
          throw FormatException('Malformed parameter name "$rawKey"', source);
        }
        final String value;
        try {
          value = Uri.decodeQueryComponent(rawValue);
        } on FormatException {
          throw FormatException('Bad percent-encoding in "$rawKey"', source);
        }

        final key = rawKey.toLowerCase();
        if (_knownKeys.contains(key)) {
          final previous = values[key];
          if (previous != null && previous != value) {
            throw FormatException('Conflicting values for "$key"', source);
          }
          if (value.isNotEmpty) values[key] = value;
        } else {
          extras.putIfAbsent(rawKey, () => value);
        }
      }
    }

    final pa = values['pa'];
    final pn = values['pn'];
    if (pa == null) throw FormatException('Missing "pa"', source);
    if (pn == null) throw FormatException('Missing "pn"', source);
    final cu = values['cu'];
    if (cu != null && cu.toUpperCase() != _currency) {
      throw FormatException('Currency must be INR, got "$cu"', source);
    }

    final url = values['url'];
    final referenceUrl = url == null ? null : Uri.tryParse(url);
    if (url != null && referenceUrl == null) {
      throw FormatException('Invalid "url" value', source);
    }

    try {
      return UpiLink(
        payeeAddress: pa,
        payeeName: pn,
        amount: values['am'],
        transactionNote: values['tn'],
        transactionRef: values['tr'],
        merchantCode: values['mc'],
        transactionId: values['tid'],
        referenceUrl: referenceUrl,
        extraParameters: extras,
      );
    } on UpiLinkException catch (e) {
      throw FormatException('Invalid ${e.field}: ${e.message}', source);
    }
  }

  /// Like [parse], but returns `null` instead of throwing on invalid input.
  static UpiLink? tryParse(String source) {
    try {
      return parse(source);
    } on FormatException {
      return null;
    }
  }

  /// The payee's UPI address (VPA), for example `chaipoint@okaxis`.
  ///
  /// Spec key: `pa`. Required.
  final String payeeAddress;

  /// The payee's display name, for example `Chai Point`.
  ///
  /// Spec key: `pn`. Required.
  final String payeeName;

  /// The amount in rupees, as a decimal string with at most 2 decimal
  /// places, for example `'149'`, `'149.5'` or `'149.50'`.
  ///
  /// Kept as a string so no floating-point rounding can reach a payment.
  /// It is written into the link exactly as given, so `'149.5'` and
  /// `'149.50'` produce different links.
  ///
  /// Spec key: `am`. When `null`, the payer enters the amount.
  final String? amount;

  /// A note shown to the payer, for example `Order 42`.
  ///
  /// Spec key: `tn`.
  final String? transactionNote;

  /// The merchant's reference for this payment, such as an order id.
  ///
  /// Spec key: `tr`.
  final String? transactionRef;

  /// The 4-digit merchant category code, for example `5812`.
  ///
  /// Spec key: `mc`.
  final String? merchantCode;

  /// A transaction id generated by the payee's app.
  ///
  /// Spec key: `tid`.
  final String? transactionId;

  /// An absolute `http`/`https` URL with details about the payment,
  /// such as an invoice page.
  ///
  /// Spec key: `url`.
  final Uri? referenceUrl;

  /// Parameters outside the supported fields, such as `mode` or `purpose`,
  /// in the order they appeared.
  ///
  /// [parse] fills this from real QR codes so nothing is lost, and
  /// [toString] writes these after the supported fields. The map is
  /// unmodifiable. Empty when there are none.
  final Map<String, String> extraParameters;

  /// Returns this link as a [Uri].
  Uri toUri() => Uri.parse(toString());

  /// Returns the link as a string, for example
  /// `upi://pay?pa=chaipoint@okaxis&pn=Chai%20Point&am=149.50&cu=INR`.
  ///
  /// Supported parameters are always written in the order
  /// `pa, pn, am, cu, tn, tr, mc, tid, url`, followed by
  /// [extraParameters] in their original order. Spaces are encoded as `%20`
  /// (not `+`), because some UPI apps display a `+` literally.
  @override
  String toString() {
    final params = <String, String?>{
      'pa': payeeAddress,
      'pn': payeeName,
      'am': amount,
      'cu': _currency,
      'tn': transactionNote,
      'tr': transactionRef,
      'mc': merchantCode,
      'tid': transactionId,
      'url': referenceUrl?.toString(),
      ...extraParameters,
    };
    final query = params.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${_encode(e.value!)}')
        .join('&');
    return 'upi://pay?$query';
  }

  @override
  bool operator ==(Object other) =>
      other is UpiLink &&
      other.payeeAddress == payeeAddress &&
      other.payeeName == payeeName &&
      other.amount == amount &&
      other.transactionNote == transactionNote &&
      other.transactionRef == transactionRef &&
      other.merchantCode == merchantCode &&
      other.transactionId == transactionId &&
      other.referenceUrl == referenceUrl &&
      _mapEquals(other.extraParameters, extraParameters);

  @override
  int get hashCode => Object.hash(
        payeeAddress,
        payeeName,
        amount,
        transactionNote,
        transactionRef,
        merchantCode,
        transactionId,
        referenceUrl,
        Object.hashAllUnordered(
          extraParameters.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static const _currency = 'INR';

  static const _knownKeys = {
    'pa',
    'pn',
    'am',
    'cu',
    'tn',
    'tr',
    'mc',
    'tid',
    'url',
  };

  static final _addressPattern =
      RegExp(r'^[a-zA-Z0-9._-]{1,256}@[a-zA-Z0-9]{2,64}$');
  static final _keyPattern = RegExp(r'^[A-Za-z0-9._-]+$');
  static final _badPercent = RegExp('%(?![0-9A-Fa-f]{2})');
  static final _amountPattern = RegExp(r'^\d+(\.\d{1,2})?$');
  static final _merchantCodePattern = RegExp(r'^\d{4}$');

  /// Percent-encodes [value] for a query, leaving `@` readable because
  /// UPI addresses are conventionally written unencoded.
  static String _encode(String value) =>
      Uri.encodeComponent(value).replaceAll('%40', '@');

  void _validate() {
    if (!_addressPattern.hasMatch(payeeAddress)) {
      throw UpiLinkException(
        'payeeAddress',
        'Expected a UPI address like "name@bank", got "$payeeAddress"',
      );
    }
    if (payeeName.trim().isEmpty) {
      throw const UpiLinkException('payeeName', 'Must not be blank');
    }
    final amount = this.amount;
    if (amount != null) {
      if (!_amountPattern.hasMatch(amount)) {
        throw UpiLinkException(
          'amount',
          'Expected digits with at most 2 decimal places, got "$amount"',
        );
      }
      if (!amount.contains(RegExp('[1-9]'))) {
        throw const UpiLinkException('amount', 'Must be greater than zero');
      }
    }
    _checkNotEmpty('transactionNote', transactionNote);
    _checkNotEmpty('transactionRef', transactionRef);
    _checkNotEmpty('transactionId', transactionId);
    final merchantCode = this.merchantCode;
    if (merchantCode != null && !_merchantCodePattern.hasMatch(merchantCode)) {
      throw UpiLinkException(
        'merchantCode',
        'Expected 4 digits, got "$merchantCode"',
      );
    }
    final url = referenceUrl;
    if (url != null &&
        (!url.isAbsolute || !(url.scheme == 'http' || url.scheme == 'https'))) {
      throw UpiLinkException(
        'referenceUrl',
        'Expected an absolute http(s) URL, got "$url"',
      );
    }
    for (final key in extraParameters.keys) {
      if (!_keyPattern.hasMatch(key)) {
        throw UpiLinkException(
          'extraParameters',
          'Keys may only contain letters, digits, ".", "_" or "-", got "$key"',
        );
      }
      if (_knownKeys.contains(key.toLowerCase())) {
        throw UpiLinkException(
          'extraParameters',
          '"$key" is a supported field; pass it as a named argument instead',
        );
      }
    }
  }

  static void _checkNotEmpty(String field, String? value) {
    if (value != null && value.trim().isEmpty) {
      throw UpiLinkException(field, 'Must not be blank when provided');
    }
  }
}
