# Parser simulation and known limitations

`tool/simulate.dart` stress-tests `UpiLink.parse`. Run it before every release
that touches parsing:

```sh
dart run tool/simulate.dart            # seed 42, 10,000 iterations
dart run tool/simulate.dart 7 50000    # custom seed and iteration count
```

It runs three checks:

1. **Round trip.** Random valid links (Unicode names, reserved characters,
   extra keys) must come back equal after `toString()` → `parse()`.
2. **Real-world variants.** 181 cases: QR shapes from GPay, PhonePe-style,
   Paytm, BharatPe and signed dynamic QR codes with random values, plus
   copy-paste artefacts, casing, amounts, names, addresses, keys and links
   that are not UPI pay links. Each case says whether it should parse or be
   rejected, and the script reports any mismatch.
3. **Fuzz.** Mutated and random strings must only ever throw
   `FormatException`, never another error type.

All data is generated. Never commit a real person's UPI ID or name.

## Results for 0.1.2 (2026-11-19)

| Check | Seeds 42, 7, 2026 × 20,000 iterations |
| --- | --- |
| Round trip | 60,000 / 60,000 passed |
| Real-world variants | 181 / 181 behaved as expected |
| Fuzz | 60,000 inputs, 0 crashes |

The first run found one real gap, which is now fixed in 0.1.2: an unencoded
`&` inside a value (`pn=A&B%20Traders`) made the whole link fail. A segment
without `=` is now read as the rest of the previous value.

## Links that still fail or misread

These are known and accepted for 0.1.2. Candidates for a later release are
marked.

| Input | Today | Why | Later? |
| --- | --- | --- | --- |
| No `pn` (`upi://pay?pa=a@ybl`) | Rejected | `payeeName` is a non-nullable `String`; making it optional is a breaking change | 0.2.0 candidate |
| Unencoded `&` followed by `=` in a value (`pn=A&B=C`) | **Parses with the wrong name** (`A`, plus extra `B=C`) | Indistinguishable from a real extra key | No (can't be detected) |
| App-specific schemes (`tez://upi/pay`, `phonepe://pay`, `paytmmp://pay`) | Rejected | Not `upi://pay` | Candidate: accept and normalise |
| Mandate / AutoPay links (`upi://mandate`) | Rejected | Different spec with different keys | Candidate: separate class |
| `am=0.00` or `am=0` | Rejected | Amount must be > 0 | Candidate: read as "no amount" in `parse` only |
| Amount with 3+ decimals, `₹`, `,`, spaces, negative | Rejected | Can't be paid exactly | No |
| Handle with a hyphen (`a@yes-bank`) | Rejected | Not seen in real handles | Revisit if reported |
| `+` in the user part (`a+b@ybl`) | Rejected | Not allowed by the address rule | Revisit if reported |
| `mc` not exactly 4 digits | Rejected | MCC codes are 4 digits | No |
| `url` without `http(s)://` (`www.shop.example`) | Rejected | `referenceUrl` must be absolute | Candidate: keep in `extraParameters` |
| Currency other than INR | Rejected | UPI is INR-only | No |
| A fragment (`#x`) | Rejected | Not part of a pay link | No |
| A supported key twice with different values | Rejected | No safe way to choose | No |
