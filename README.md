# WhyNot for iOS

A Flutter application with iOS as its production platform and the web as a
preview environment for development on Windows.

## Branches

The following branches will be used for the Git workflow:

- **master** as the project's main branch. It contains the production code
  that will be used by the Jenkins, SonarQube, and GitInspector tools.
- **feature** branches are the ones developers will normally work on. They
  use the `feature/` prefix by default, followed by the branch name (e.g.
  `feature/implementBookEntity`). They are created from master and are
  deleted once merged.
- **bugfix** branches are the ones where developers will fix bugs. They use
  the `bugfix/` prefix by default, followed by the name of the feature that
  contains the bug (e.g. `bugfix/implementBookEntity`). They are created
  from master and are deleted once merged.

## Preview on Windows

```powershell
flutter pub get
flutter run -d chrome
```

On the web, the application is centered inside a 402 × 874 px viewport with
rounded corners. This is useful for validating the interface, but it does not
replace the iOS simulator.

## Run on the iOS simulator

Requires a Mac with the full Xcode app (not just the Command Line Tools) and
CocoaPods installed.

```bash
# One-time setup
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
brew install cocoapods

# List available simulators
flutter devices

# Boot a simulator (skip if one is already running)
open -a Simulator

# Run the app
flutter pub get
flutter run -d <device-id-from-flutter-devices>
```

If `flutter run` fails with an error about the iOS platform not being
installed, download it once with:

```bash
xcodebuild -downloadPlatform iOS
```

## Build for iPhone (Literal Build to then run on iOS)

```bash
flutter pub get
flutter build ios
```

The SVG resources used by the application are located in `assets/figma/`.

## Architecture

The code uses a deliberately lightweight **feature-first** organization:

```text
lib/
├── main.dart                 # Application entry point
├── app/                      # Theme, routes, and global configuration
├── features/
│   ├── authentication/       # Login and account creation
│   ├── home/                 # Home feed and recommendations
│   └── profile/              # Profile and password management
└── shared/widgets/           # Widgets shared across features
```

Each feature owns its screens and feature-specific components. A widget is
moved to `shared` only when more than one feature uses it. Form state remains
local because there is currently no API or shared session state. Adding a
domain layer or state-management library at this stage would increase
complexity without addressing an existing requirement.
