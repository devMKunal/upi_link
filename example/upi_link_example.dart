import 'package:upi_link/upi_link.dart';

void main() {
  // Build a link, for a QR code, url_launcher or a share sheet.
  final link = UpiLink(
    payeeAddress: 'chaipoint@okaxis',
    payeeName: 'Chai Point',
    amount: '149.50',
    transactionNote: 'Order 42',
    transactionRef: 'ORD-42',
  );
  print(link);
  // upi://pay?pa=chaipoint@okaxis&pn=Chai%20Point&am=149.50&cu=INR&tn=Order%2042&tr=ORD-42

  // Read one back, for example from a scanned QR code.
  final scanned = UpiLink.parse(link.toString());
  print('${scanned.payeeName} asks for ₹${scanned.amount}');

  // Invalid input fails early, naming the field.
  try {
    UpiLink(payeeAddress: 'chaipoint', payeeName: 'Chai Point');
  } on UpiLinkException catch (e) {
    print(e); // UpiLinkException(payeeAddress): Expected a UPI address ...
  }

  // tryParse returns null instead of throwing.
  print(UpiLink.tryParse('https://example.com')); // null
}
