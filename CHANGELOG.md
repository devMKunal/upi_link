## 0.1.1

- Add CI badge to the README. No API changes.
- First release published automatically from GitHub Actions.

## 0.1.0

- Initial release.
- `UpiLink` builds `upi://pay` links from 8 NPCI parameters: `pa`, `pn`, `am`, `tn`, `tr`, `mc`, `tid`, `url`.
- `UpiLink.parse` and `UpiLink.tryParse` read links back, strictly.
- `UpiLinkException` names the field that failed validation.
