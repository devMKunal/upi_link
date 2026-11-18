## 0.1.0

- Initial release.
- `UpiLink` builds `upi://pay` links from 8 NPCI parameters: `pa`, `pn`, `am`, `tn`, `tr`, `mc`, `tid`, `url`.
- `UpiLink.parse` and `UpiLink.tryParse` read links back, strictly.
- `UpiLinkException` names the field that failed validation.
