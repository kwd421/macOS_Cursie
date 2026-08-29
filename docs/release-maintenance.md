# Release Maintenance Notes

This file documents local release credentials and update-signing conventions.
Do not commit exported private keys or Apple passwords.

## Notarization

- `notarytool` keychain profile: `seinel-notary`
- Team ID: `DRUFU8Q688`
- Release signing identity: `A9141ADBA79975DC26BFC317B89E0AFBDB478A44`
  (the long-lived Developer ID certificate; use its SHA-1 because another
  certificate in the login keychain has the same display name)
- Create or refresh the profile with:

```bash
xcrun notarytool store-credentials seinel-notary
```

The profile stores Apple notarization credentials in the local macOS Keychain.

## Sparkle Update Signing

- Sparkle public key location: `CapeForgeApp/Info.plist` as `SUPublicEDKey`
- Sparkle private key storage: local macOS Keychain
- Sparkle keychain account: `seinel-capeforge`
- The keychain account name is legacy from the pre-Cursie name. Keep it unless
  you intentionally rotate the Sparkle signing key and update `SUPublicEDKey`.
- Sign updates with:

```bash
.build/artifacts/sparkle/Sparkle/bin/sign_update --account seinel-capeforge dist/Cursie.zip
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
the result, creates `dist/Cursie.zip` and `dist/Cursie.dmg`, copies `LICENSE`
and `THIRD_PARTY_NOTICES.md` into the app bundle, and prints Sparkle enclosure
attributes for the appcast. It runs `swift test` before building release
artifacts.

The DMG root contains only `Cursie.app` and the `Applications` symlink. During
DMG creation the script writes a Finder layout with 128 px icons so the install
window opens with larger app and Applications icons.

## Legacy Names Kept Intentionally

- `CapeForgeApp/` and `CapeForge.xcodeproj` are source tree names only.
- `com.seinel.capeforge.cursor-agent` remains the LaunchAgent label so existing
  installs do not leave an orphaned helper behind.
- `seinel-capeforge` remains the Sparkle keychain account unless the update
  signing key is intentionally rotated.
