# WhyNot for iOS

A Flutter application with iOS as its production platform and the web as a
preview environment for development on Windows.

## Preview on Windows

```powershell
flutter pub get
flutter run -d chrome
```

On the web, the application is centered inside a 402 × 874 px viewport with
rounded corners. This is useful for validating the interface, but it does not
replace the iOS simulator.

## Build for iPhone

On a Mac with Xcode installed:

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
