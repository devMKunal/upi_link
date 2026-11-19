## 0.1.2

- `UpiLink.parse` now reads real-world QR codes. Keys outside the supported
  fields (`mode`, `purpose`, `orgid`, `sign`, app-specific keys) are kept in the
  new `extraParameters` map instead of causing a `FormatException`.
- Add `UpiLink.extraParameters` and an optional `extraParameters` constructor
  argument. `toString()` writes them after the supported fields.
- `parse` treats empty supported values (`am=`) as absent, matches supported
  keys and `cu=INR` case-insensitively, ignores empty segments and a trailing
  `/` after `pay`, trims whitespace, and reads HTML-escaped `&amp;`.
- A supported key repeated with the same value is accepted; different values
  still throw.

## 0.1.1

- Add CI badge to the README. No API changes.
- First release published automatically from GitHub Actions.

## 0.1.0

- Initial release.
- `UpiLink` builds `upi://pay` links from 8 NPCI parameters: `pa`, `pn`, `am`, `tn`, `tr`, `mc`, `tid`, `url`.
- `UpiLink.parse` and `UpiLink.tryParse` read links back, strictly.
- `UpiLinkException` names the field that failed validation.
