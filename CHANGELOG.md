# Changelog

What changes for people using Dock Divider, by version. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.3.0] - 2026-10-18

### Added

- Failures are written to the system log, so a bug report can include them.

### Fixed

- Without the Accessibility permission, the menu bar icon shows a warning and the menu has **Allow Accessibility Access…**, instead of the lines just not showing.

## [1.2.0] - 2026-10-18

### Added

- The menu is in Brazilian Portuguese when macOS is set to it.
- Translations, bug reports, and pull requests are welcome; see CONTRIBUTING.md.

## [1.1.2] - 2026-10-15

### Fixed

- Dividers match the Dock's own line again in dark mode (1.1.1 drew them too dark).

## [1.1.1] - 2026-10-15

Tagged, not published as a release.

### Fixed

- Dividers take the system separator color, matching the Dock's own line.

## [1.1.0] - 2026-10-15

### Added

- **Open at Login** menu item.
- Install with one Terminal command; see the README.

### Changed

- The app's identifier changed, so macOS asks for the Accessibility permission again after updating from 1.0.0. If Dock Divider does not show up in the list, click **+** and add it from Applications.

### Fixed

- Dividers match the system line in the light theme.
- Dividers work with the Dock on the left or right side.
- Dividers follow the Dock while it shows and hides (auto-hide, full screen) and when it magnifies.

## [1.0.0] - 2026-10-15

### Added

- Menu bar app that draws divider lines over the Dock's native spacers.
- Universal binary (Apple Silicon and Intel), macOS 14 or later.

[Unreleased]: https://github.com/luantedesco/dock-divider/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/luantedesco/dock-divider/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/luantedesco/dock-divider/compare/v1.1.2...v1.2.0
[1.1.2]: https://github.com/luantedesco/dock-divider/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/luantedesco/dock-divider/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/luantedesco/dock-divider/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/luantedesco/dock-divider/releases/tag/v1.0.0
