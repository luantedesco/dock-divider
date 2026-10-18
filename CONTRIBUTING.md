# Contributing

Bug reports, ideas, translations, and pull requests are welcome. For a larger change, open an issue first, so we can agree on the approach before you write it.

## Requirements

- macOS 14 or later
- Xcode, or only the Command Line Tools (`xcode-select --install`)

## Build, test, and lint

```sh
./build.sh                       # builds build/Dock Divider.app
./test.sh                        # runs the tests, translations included
swift format lint -r -s Sources Tests Tools Package.swift
```

Formatting follows `.swift-format`; `swift format -i -r Sources Tests Tools Package.swift` applies it. The same checks run on every pull request.

## Signing certificate

macOS ties the Accessibility permission to the app's signature. Signed ad hoc, each build is a new app to macOS, and the permission has to be granted again after every rebuild. `build.sh` signs with a certificate named **Dock Divider Local Signing** when it is in your Keychain, which keeps the permission across builds. To create it:

1. Open Keychain Access (`open -a "Keychain Access"`).
2. Choose **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Name: `Dock Divider Local Signing`. Identity Type: **Self-Signed Root**. Certificate Type: **Code Signing**. Click **Create**.

The certificate is only for your Mac; it does not need to match the one releases are signed with.

## Code

- Geometry that does not depend on AppKit or Accessibility goes in `Sources/DockDividerCore`, with tests in `Tests/DockDividerCoreTests`. The app itself (menu, Accessibility, windows) is in `Sources/DockDivider/main.swift`.
- Code, comments, and messages are in English.
- Commit messages follow `type(scope): description`, where the description says what changes for the user, for example `fix: dividers follow the Dock's show/hide animation`. Types in use: `feat`, `fix`, `refactor`, `docs`, `chore`.

## Testing

The tests cover the geometry; what depends on the real Dock is checked by hand. Before opening a pull request, run the app you built and check that the lines sit on the spacers:

- with the Dock at the bottom, on the left, and on the right
- with the Dock hidden automatically, while it shows and hides
- with magnification on
- in light and in dark mode
- with more than one display, if you have one
- after **Add Divider**, and after dragging a spacer out of the Dock

## Translations

Menu text lives in `Resources/<language>.lproj/Localizable.strings`, with English in `en.lproj`. To add a language:

1. Copy `Resources/en.lproj` to `Resources/<code>.lproj`, using the code macOS uses for the language (for example `de`, `es`, `fr`, `ja`, `pt-BR`, `zh-Hans`).
2. Translate the text on the right of each `=`; keep the keys on the left as they are. Use the words macOS uses in its own menus where they exist.
3. Run `./test.sh`, then build and open the app in that language:

   ```sh
   ./build.sh
   open "build/Dock Divider.app" --args -AppleLanguages "(<code>)"
   ```

New text in the code goes through `String(localized: "…")`, with the English text as the key, and has to be added to `en.lproj` and to every other language; `./test.sh` fails otherwise.

## Releases

Releases are built and signed by the maintainer, so that the Accessibility permission carries over between versions. Pull requests do not need to change the version number.
