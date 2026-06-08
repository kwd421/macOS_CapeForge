# Release Maintenance Notes

This file documents local release credentials and update-signing conventions.
Do not commit exported private keys or Apple passwords.

## Notarization

- `notarytool` keychain profile: `seinel-notary`
- Team ID: `DRUFU8Q688`
- Create or refresh the profile with:

```bash
xcrun notarytool store-credentials seinel-notary
```

The profile stores Apple notarization credentials in the local macOS Keychain.

## Sparkle Update Signing

- Sparkle public key location: `CapeForgeApp/Info.plist` as `SUPublicEDKey`
- Sparkle private key storage: local macOS Keychain
- Sparkle keychain account: `seinel-capeforge`
- Sign updates with:

```bash
.build/artifacts/sparkle/Sparkle/bin/sign_update --account seinel-capeforge dist/CapeForge.zip
```

The private key is intentionally not stored in this repository. The release
script uses the same account and prints the `sparkle:edSignature` and `length`
attributes needed for `appcast.xml`.

## Release Build Script

Run:

```bash
./scripts/build-notarized-release.sh
```

The script builds the Release app, submits the archive for notarization, staples
the result, creates `dist/CapeForge.zip`, and prints Sparkle enclosure
attributes for the appcast.
