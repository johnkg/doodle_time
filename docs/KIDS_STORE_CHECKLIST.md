# Kids app store checklist (Doodle Time)

Not legal advice. Store rules change; re-check the linked pages before you submit.
Checked 2026-10-22 against:
- Google Play Families policy: https://support.google.com/googleplay/android-developer/answer/9893335
- Apple Kids page: https://developer.apple.com/kids/ (links to guidelines 1.3 and 5.1.4, not reproduced there)

## Why this app is an easy fit

Doodle Time has **no ads, no accounts, no analytics, no network calls, no in-app purchases, no links out**.
Drawing is saved only on the device. That makes most kids-policy items "not applicable".
Keep it that way: every SDK you add later must be re-checked.

## Google Play (Families)

| Item | Status |
|---|---|
| Choose accurate target age groups in Play Console (Target audience and content) | TODO, you |
| Ads: only Families self-certified ad SDKs, no interest-based ads | N/A (no ads) |
| Do not transmit advertising ID / device identifiers from child-only apps | OK (nothing sent). Re-check any new SDK |
| Child-only apps: don't request location; avoid AD_ID permission on API 33+ | OK. Check merged Android manifest after build |
| SDKs must be approved for child-directed use | `shared_preferences`, `audioplayers` are local-only. Verify they add no network/tracking. `flutter_tts` uses the phone's text-to-speech engine: check which engine/voices your test devices use and whether any send text off-device (some browser or system voices may) |
| Privacy policy accurate and COPPA/GDPR aware | Template in `PRIVACY_POLICY_TEMPLATE.md`, fill in contact info |
| Data safety form + IARC content rating answered accurately | TODO, you. Expected answer: no data collected |

## Apple (Kids Category)

| Item | Status |
|---|---|
| Pick age band in App Store Connect: 5 and under, 6-8, or 9-11 | TODO, you (likely "5 and under") |
| Comply with guidelines 1.3 and 5.1.4 (read both) | TODO, you |
| No PII or device info sent to third parties without parental consent | OK (nothing sent) |
| Parental gate before link-outs, purchases | App has none of these. A gate guards the Grown-ups menu anyway |
| Privacy nutrition label | Expected: Data Not Collected |
| Age rating questionnaire answered accurately | TODO, you |

Apple notes that for pre-literate children a gate should use a voice prompt telling them to get a parent.
The current gate is a text math question; consider adding spoken text before publishing in the Kids Category.

## Before publishing, also

- Add an app icon and screenshots (no real children's photos)
- Test on a real Android phone and an iPhone/iPad; iOS build needs a Mac with Xcode (or a cloud Mac such as Codemagic)
- Mobile "Save picture" is not implemented yet (web only). Hide that menu item on mobile until it is
- Web build: makes no third-party requests when built with `--no-web-resources-cdn` (CanvasKit bundled) and the bundled Noto Color Emoji font (`assets/fonts/`, OFL, web only). Checked 2026-10-24: only same-origin requests. Any emoji or symbol the font lacks would make Flutter fetch a Noto font from Google again
- Read-aloud text is only lesson instructions (no child data), but confirm voices work offline on the devices you target
- Re-run the checklist whenever you add a package
