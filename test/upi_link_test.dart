import 'package:test/test.dart';
import 'package:upi_link/upi_link.dart';

void main() {
  UpiLink minimal() =>
      UpiLink(payeeAddress: 'chaipoint@okaxis', payeeName: 'Chai Point');

  UpiLink full() => UpiLink(
        payeeAddress: 'chaipoint@okaxis',
        payeeName: 'Chai Point',
        amount: '149.50',
        transactionNote: 'Order 42',
        transactionRef: 'ORD-42',
        merchantCode: '5812',
        transactionId: 'TID-9f3a',
        referenceUrl: Uri.parse('https://chaipoint.in/o/42'),
      );

  group('toString', () {
    test('writes required params and currency', () {
      expect(
        minimal().toString(),
        'upi://pay?pa=chaipoint@okaxis&pn=Chai%20Point&cu=INR',
      );
    });

    test('writes all params in spec order', () {
      expect(
        full().toString(),
        'upi://pay?pa=chaipoint@okaxis&pn=Chai%20Point&am=149.50&cu=INR'
        '&tn=Order%2042&tr=ORD-42&mc=5812&tid=TID-9f3a'
        '&url=https%3A%2F%2Fchaipoint.in%2Fo%2F42',
      );
    });

    test('encodes spaces as %20, never +', () {
      final s = minimal().toString();
      expect(s, contains('Chai%20Point'));
      expect(s, isNot(contains('+')));
    });

    test('escapes reserved characters in values', () {
      final link = UpiLink(
        payeeAddress: 'a.b@ybl',
        payeeName: 'A & B = C+D',
        transactionNote: 'चाय',
      );
      expect(link.toString(), contains('pn=A%20%26%20B%20%3D%20C%2BD'));
      expect(link.toString(), contains('tn=%E0%A4%9A%E0%A4%BE%E0%A4%AF'));
    });

    test('keeps amount exactly as given', () {
      final link =
          UpiLink(payeeAddress: 'a@ybl', payeeName: 'A', amount: '149.5');
      expect(link.toString(), contains('am=149.5&'));
    });
  });

  group('toUri', () {
    test('returns an equivalent Uri', () {
      final uri = full().toUri();
      expect(uri.scheme, 'upi');
      expect(uri.host, 'pay');
      expect(uri.toString(), full().toString());
    });
  });

  group('constructor validation', () {
    void expectInvalid(String field, UpiLink Function() build) {
      expect(
        build,
        throwsA(isA<UpiLinkException>().having((e) => e.field, 'field', field)),
      );
    }

    for (final address in [
      '',
      'noatsign',
      'a@',
      '@bank',
      'a b@bank',
      'a@ba-nk',
      'x@y'
    ]) {
      test('rejects payeeAddress "$address"', () {
        expectInvalid('payeeAddress',
            () => UpiLink(payeeAddress: address, payeeName: 'A'));
      });
    }

    test('accepts common address shapes', () {
      for (final address in [
        '9876543210@ybl',
        'first.last-1_x@okhdfcbank',
        'ab@upi'
      ]) {
        expect(() => UpiLink(payeeAddress: address, payeeName: 'A'),
            returnsNormally);
      }
    });

    test('rejects blank payeeName', () {
      expectInvalid(
          'payeeName', () => UpiLink(payeeAddress: 'a@ybl', payeeName: '  '));
    });

    for (final amount in [
      '',
      '149.505',
      '-1',
      '1e3',
      '1,000',
      '.5',
      '5.',
      '0',
      '0.00',
      ' 1'
    ]) {
      test('rejects amount "$amount"', () {
        expectInvalid(
          'amount',
          () => UpiLink(payeeAddress: 'a@ybl', payeeName: 'A', amount: amount),
        );
      });
    }

    test('accepts valid amounts', () {
      for (final amount in [
        '1',
        '149',
        '149.5',
        '149.50',
        '0.01',
        '100000.00'
      ]) {
        expect(
          () => UpiLink(payeeAddress: 'a@ybl', payeeName: 'A', amount: amount),
          returnsNormally,
        );
      }
    });

    test('rejects blank optional text fields', () {
      expectInvalid(
          'transactionNote',
          () => UpiLink(
              payeeAddress: 'a@ybl', payeeName: 'A', transactionNote: ''));
      expectInvalid(
          'transactionRef',
          () => UpiLink(
              payeeAddress: 'a@ybl', payeeName: 'A', transactionRef: ' '));
      expectInvalid(
          'transactionId',
          () => UpiLink(
              payeeAddress: 'a@ybl', payeeName: 'A', transactionId: ''));
    });

    for (final mc in ['581', '58120', 'abcd']) {
      test('rejects merchantCode "$mc"', () {
        expectInvalid(
          'merchantCode',
          () =>
              UpiLink(payeeAddress: 'a@ybl', payeeName: 'A', merchantCode: mc),
        );
      });
    }

    for (final url in ['/relative', 'ftp://x.in/a', 'mailto:a@b.in']) {
      test('rejects referenceUrl "$url"', () {
        expectInvalid(
          'referenceUrl',
          () => UpiLink(
              payeeAddress: 'a@ybl',
              payeeName: 'A',
              referenceUrl: Uri.parse(url)),
        );
      });
    }

    test('exception toString names the field', () {
      expect(
        const UpiLinkException('amount', 'bad').toString(),
        'UpiLinkException(amount): bad',
      );
    });
  });

  group('parse', () {
    test('round-trips every valid link', () {
      expect(UpiLink.parse(minimal().toString()), minimal());
      expect(UpiLink.parse(full().toString()), full());
    });

    test('reads values', () {
      final link = UpiLink.parse(
        'upi://pay?pa=chaipoint@okaxis&pn=Chai%20Point&am=149.50&cu=INR',
      );
      expect(link.payeeAddress, 'chaipoint@okaxis');
      expect(link.payeeName, 'Chai Point');
      expect(link.amount, '149.50');
      expect(link.transactionNote, isNull);
    });

    test('accepts + as a space and %40 for @', () {
      final link = UpiLink.parse('upi://pay?pa=a%40ybl&pn=Chai+Point');
      expect(link.payeeAddress, 'a@ybl');
      expect(link.payeeName, 'Chai Point');
    });

    test('accepts upper-case scheme and host', () {
      expect(UpiLink.parse('UPI://PAY?pa=a@ybl&pn=A').payeeName, 'A');
    });

    test('accepts missing cu', () {
      expect(UpiLink.parse('upi://pay?pa=a@ybl&pn=A&am=1').amount, '1');
    });

    final invalid = {
      'stray %': 'upi://pay?pa=a@ybl&pn=A%',
      'invalid UTF-8': 'upi://pay?pa=a@ybl&pn=A%FF',
      'not a URI': 'upi://pay:x?pa=a@ybl&pn=A',
      'wrong scheme': 'https://pay?pa=a@ybl&pn=A',
      'wrong host': 'upi://mandate?pa=a@ybl&pn=A',
      'has path': 'upi://pay/x?pa=a@ybl&pn=A',
      'has fragment': 'upi://pay?pa=a@ybl&pn=A#f',
      'has port': 'upi://pay:80?pa=a@ybl&pn=A',
      'has user info': 'upi://u@pay?pa=a@ybl&pn=A',
      'no query': 'upi://pay',
      'empty query': 'upi://pay?',
      'pn without a value': 'upi://pay?pa=a@ybl&pn',
      'empty pa': 'upi://pay?pa=&pn=A',
      'empty key': 'upi://pay?pa=a@ybl&pn=A&=x',
      'bad characters in a key': 'upi://pay?pa=a@ybl&pn=A&mo%20de=1',
      'conflicting duplicate key': 'upi://pay?pa=a@ybl&pn=A&pn=B',
      'lower-case non-INR currency': 'upi://pay?pa=a@ybl&pn=A&cu=usd',
      'missing pa': 'upi://pay?pn=A',
      'missing pn': 'upi://pay?pa=a@ybl',
      'non-INR currency': 'upi://pay?pa=a@ybl&pn=A&cu=USD',
      'bad amount': 'upi://pay?pa=a@ybl&pn=A&am=1.234',
      'bad address': 'upi://pay?pa=nobank&pn=A',
      'relative url': 'upi://pay?pa=a@ybl&pn=A&url=%2Fx',
      'unparsable url': 'upi://pay?pa=a@ybl&pn=A&url=http%3A%2F%2F%5B',
    };

    invalid.forEach((name, source) {
      test('rejects $name', () {
        expect(() => UpiLink.parse(source), throwsFormatException);
        expect(UpiLink.tryParse(source), isNull);
      });
    });

    test('tryParse returns the link on valid input', () {
      expect(UpiLink.tryParse(full().toString()), full());
    });
  });

  group('real-world QR codes', () {
    // Shapes copied from QR codes produced by common UPI apps.
    // All addresses, names and ids below are made up.
    final fixtures = {
      'personal QR with mode and purpose':
          'upi://pay?pa=9876543210@axl&pn=TEST%20%20USER&mc=0000&mode=02&purpose=00',
      'GPay merchant QR with vendor keys':
          'upi://pay?pa=gpay-11111111111@okbizaxis&mc=5411&pn=Test%20Merchant'
              '&oobe=fos123&qrst=snp&tr=1111111111&cu=INR&ver=01&mode=01',
      'Paytm-style QR with orgid and sign':
          'upi://pay?pa=paytmqr1111@paytm&pn=Test%20Shop&mc=5499&mode=02'
              '&orgid=000000&paytmqr=1111ABCD&sign=MEUCIQ',
      'GPay personal QR with aid':
          'upi://pay?pa=test.user@okhdfcbank&pn=Test%20User&aid=uGICAgICAgA',
      'signed dynamic QR with mam':
          'upi://pay?pa=shop@icici&pn=Shop&tr=EZV2024&am=250.00&mam=250.00&cu=INR&mode=15',
      'minimal Paytm QR': 'upi://pay?pa=paytm.test123@pty&pn=Paytm',
    };

    fixtures.forEach((name, source) {
      test('parses $name', () {
        expect(UpiLink.tryParse(source), isNotNull);
      });
    });

    test('keeps unknown keys in order', () {
      final link =
          UpiLink.parse(fixtures['GPay merchant QR with vendor keys']!);
      expect(
          link.extraParameters.keys.toList(), ['oobe', 'qrst', 'ver', 'mode']);
      expect(link.extraParameters['mode'], '01');
      expect(link.merchantCode, '5411');
      expect(link.transactionRef, '1111111111');
    });

    test('round-trips links that carry extra keys', () {
      for (final source in fixtures.values) {
        final link = UpiLink.parse(source);
        expect(UpiLink.parse(link.toString()), link);
      }
    });

    test('writes extra keys after the supported ones', () {
      final link = UpiLink.parse('upi://pay?mode=02&pa=a@ybl&pn=A');
      expect(link.toString(), 'upi://pay?pa=a@ybl&pn=A&cu=INR&mode=02');
    });

    test('treats an empty supported value as absent', () {
      final link = UpiLink.parse('upi://pay?pa=a@ybl&pn=A&am=&tn=&cu=INR');
      expect(link.amount, isNull);
      expect(link.transactionNote, isNull);
    });

    test('keeps an extra key without a value', () {
      final link = UpiLink.parse('upi://pay?pa=a@ybl&pn=A&flag');
      expect(link.extraParameters, {'flag': ''});
    });

    test('first value wins for a repeated extra key', () {
      final link = UpiLink.parse('upi://pay?pa=a@ybl&pn=A&mode=01&mode=02');
      expect(link.extraParameters, {'mode': '01'});
    });

    test('accepts a repeated supported key with the same value', () {
      expect(UpiLink.parse('upi://pay?pa=a@ybl&pn=A&pn=A').payeeName, 'A');
    });

    test('matches supported keys case-insensitively', () {
      final link = UpiLink.parse('upi://pay?PA=a@ybl&Pn=A&AM=10&cu=inr');
      expect(link.payeeAddress, 'a@ybl');
      expect(link.amount, '10');
      expect(link.extraParameters, isEmpty);
    });

    test('ignores empty segments, a trailing slash and whitespace', () {
      expect(UpiLink.parse('upi://pay?pa=a@ybl&&pn=A&').payeeName, 'A');
      expect(UpiLink.parse('upi://pay/?pa=a@ybl&pn=A').payeeName, 'A');
      expect(UpiLink.parse('  upi://pay?pa=a@ybl&pn=A\n').payeeName, 'A');
    });

    test('reads HTML-escaped separators', () {
      final link = UpiLink.parse('upi://pay?pa=a@ybl&amp;pn=A&amp;mode=02');
      expect(link.payeeName, 'A');
      expect(link.extraParameters, {'mode': '02'});
    });
  });

  group('extraParameters', () {
    test('defaults to empty and is unmodifiable', () {
      expect(minimal().extraParameters, isEmpty);
      final link = UpiLink(
        payeeAddress: 'a@ybl',
        payeeName: 'A',
        extraParameters: {'mode': '02'},
      );
      expect(() => link.extraParameters['x'] = 'y', throwsUnsupportedError);
    });

    test('is copied, so later changes to the source map have no effect', () {
      final source = {'mode': '02'};
      final link = UpiLink(
          payeeAddress: 'a@ybl', payeeName: 'A', extraParameters: source);
      source['mode'] = '99';
      expect(link.extraParameters['mode'], '02');
    });

    test('encodes values', () {
      final link = UpiLink(
        payeeAddress: 'a@ybl',
        payeeName: 'A',
        extraParameters: {'note2': 'a b&c'},
      );
      expect(link.toString(), endsWith('&note2=a%20b%26c'));
    });

    for (final key in ['', 'a b', 'x=y', 'pa', 'PN', 'cu']) {
      test('rejects key "$key"', () {
        expect(
          () => UpiLink(
            payeeAddress: 'a@ybl',
            payeeName: 'A',
            extraParameters: {key: '1'},
          ),
          throwsA(isA<UpiLinkException>()
              .having((e) => e.field, 'field', 'extraParameters')),
        );
      });
    }

    test('takes part in equality, ignoring order', () {
      UpiLink withExtras(Map<String, String> extras) => UpiLink(
          payeeAddress: 'a@ybl', payeeName: 'A', extraParameters: extras);
      expect(
          withExtras({'a': '1', 'b': '2'}), withExtras({'b': '2', 'a': '1'}));
      expect(withExtras({'a': '1', 'b': '2'}).hashCode,
          withExtras({'b': '2', 'a': '1'}).hashCode);
      expect(withExtras({'a': '1'}), isNot(withExtras({'a': '2'})));
      expect(withExtras({'a': '1'}), isNot(withExtras({'a': '1', 'b': '2'})));
    });
  });

  group('equality', () {
    test('equal links have equal hashCodes', () {
      expect(full(), full());
      expect(full().hashCode, full().hashCode);
    });

    test('different values are not equal', () {
      expect(minimal(), isNot(full()));
      final a = UpiLink(payeeAddress: 'a@ybl', payeeName: 'A', amount: '1.5');
      final b = UpiLink(payeeAddress: 'a@ybl', payeeName: 'A', amount: '1.50');
      expect(a, isNot(b));
    });
  });
}
