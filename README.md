Siii 💗 acá va TODO dentro de una sola caja de código `.md`, para copiar y pegar directo en tu `README.md`:

````md
# WhyNot for iOS

A Flutter application with iOS as its production platform and the web as a preview environment for development on Windows and macOS.

WhyNot uses Firebase as its serverless backend. Firebase Authentication handles user accounts and sessions, while Cloud Firestore stores application data such as user profiles, wishlists, products, categories, and purchase status.

---

## Branches

The following branches will be used for the Git workflow:

- **`master`** is the project's main branch. It contains the production code that will be used by Jenkins, SonarQube, and GitInspector.

- **`feature/`** branches are the branches developers normally work on. They use the `feature/` prefix followed by the branch name (e.g. `feature/implementBookEntity`). They are created from `master` and are deleted once merged.

- **`bugfix/`** branches are used to fix bugs. They use the `bugfix/` prefix followed by the name of the affected feature (e.g. `bugfix/implementBookEntity`). They are created from `master` and are deleted once merged.

- **`integration/`** branches may be used temporarily when integrating cross-cutting services or large changes, such as Firebase, before merging them into `master`.

---

## Firebase Backend

WhyNot uses a shared Firebase project as its backend.

### Firebase project

```text
Project name: WhyNot
Project ID: whynot-f4ae6
```

All team members must use this same Firebase project. Do not create a separate Firebase project for local development.

The application currently uses:

- **Firebase Authentication**
  - Email/password account creation
  - Email/password login
  - User sessions
  - Password changes with reauthentication

- **Cloud Firestore**
  - User profiles
  - Categories
  - Wishlists
  - Products
  - Purchase state

Firebase Storage is currently **not used**. Product and wishlist images are stored as external image URLs.

There is also no custom REST API or application server. Flutter communicates directly with Firebase using the Firebase Flutter SDK.

---

## Firebase Packages

The Flutter application currently uses:

```yaml
firebase_core
firebase_auth
cloud_firestore
```

After cloning the repository, install all Flutter dependencies with:

```bash
flutter pub get
```

---

## Firebase Configuration

Firebase is initialized in:

```text
lib/main.dart
```

using the generated configuration located in:

```text
lib/firebase_options.dart
```

The application initializes Firebase before starting the Flutter UI:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

Do not manually create Firebase configuration values inside screens or features.

All Firebase configuration should continue using:

```text
lib/firebase_options.dart
```

---

## First-Time Firebase Setup

The Firebase project has already been created and configured.

A developer normally only needs to clone the repository and run:

```bash
flutter pub get
```

If FlutterFire needs to be configured again, or a new platform must be added, install the Firebase and FlutterFire CLIs.

### Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

Check that the shared project is visible:

```bash
firebase projects:list
```

You should see:

```text
whynot-f4ae6
```

### FlutterFire CLI

Install FlutterFire:

```bash
dart pub global activate flutterfire_cli
```

If the `flutterfire` command is not found on macOS/Linux, add the Dart global executables folder to the current terminal session:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

Then verify:

```bash
flutterfire --version
```

---

## Adding or Reconfiguring a Platform

The project is currently configured for:

- Web
- iOS

If another platform needs to be added, such as Android, run:

```bash
flutterfire configure --project=whynot-f4ae6
```

Select the required platform without creating a new Firebase project.

Running FlutterFire configuration generates or updates:

```text
lib/firebase_options.dart
```

Platform-specific Firebase configuration files may also be generated when required.

Team members adding Android support should configure **Android inside the same Firebase project**.

---

## Firebase Authentication

WhyNot currently uses Firebase Email/Password Authentication.

Email/password authentication is already enabled in the shared Firebase project.

The main authentication flow is:

```text
Create Account
      ↓
Firebase Authentication creates the account
      ↓
User profile is stored in Firestore
      ↓
Home
```

Login works as follows:

```text
Login
   ↓
Firebase Authentication
   ↓
Authenticated session
   ↓
Home
```

Passwords are **never stored in Firestore**.

Password changes are also handled directly through Firebase Authentication.

The user must provide the current password before Firebase allows the password to be replaced.

---

## Firestore Collections

The current database uses the following main collections:

```text
categories/
users/
wishlists/
products/
```

### `users`

Each authenticated user has a Firestore document:

```text
users/{uid}
```

Example fields:

```text
name
email
gender
age
preferredCategoryId
createdAt
updatedAt
```

The document ID corresponds to the Firebase Authentication user ID.

---

### `categories`

Categories are predefined in Firestore.

Current categories include:

```text
fashion
beauty
technology
home
accessories
travel
gifts
other
```

Users select from these categories instead of creating arbitrary category names.

---

### `wishlists`

Each wishlist belongs to one authenticated user.

Example:

```text
wishlists/{wishlistId}
```

Fields:

```text
ownerId
categoryId
imageUrl
createdAt
updatedAt
```

The application currently prevents the same user from creating multiple wishlists for the same category.

Different users can still have wishlists using the same category.

---

### `products`

Products are stored in:

```text
products/{productId}
```

Fields:

```text
ownerId
wishlistId
categoryId
name
brand
price
imageUrl
productUrl
purchased
createdAt
updatedAt
```

Example:

```text
name: "Chaqueta punto manga ancha"
brand: "ZARA"
price: 279000
categoryId: "fashion"
purchased: false
```

`purchased` is a Boolean:

```text
false = saved in a wishlist but not purchased
true  = purchased
```

Changing the Purchased state in Product Detail updates this value directly in Firestore.

The Purchases screen displays products whose:

```text
ownerId == current user
purchased == true
```

---

## Product Creation

Products are currently added manually.

The user provides:

```text
Name
Brand
Price
Picture link
Product link
Wishlist
```

WhyNot does not currently scrape product websites or automatically extract product information.

Images are saved as external URLs:

```text
imageUrl: "https://..."
```

No images are uploaded to Firebase Storage.

Every newly created product starts with:

```text
purchased: false
```

---

## Real-Time Firestore Updates

Several screens use Firestore streams.

This means changes can appear automatically without manually refreshing the screen.

For example:

```text
Product marked as purchased
        ↓
Firestore updates purchased = true
        ↓
Purchases screen updates automatically
```

The same applies to:

- Wishlist products
- Wishlist item counts
- Product details
- Product edits
- Product deletion
- User profile information

---

## Current Firebase-Connected Features

The following functionality currently uses real Firebase data:

```text
Authentication
├── Create account
├── Login
└── Change password

Profile
├── Read profile
└── Edit profile

Wishlists
├── Create wishlist
├── Read wishlists
├── Show real item counts
└── Open wishlist details

Products
├── Create
├── Read
├── Edit
├── Delete
└── Mark/unmark as purchased

Purchases
├── Show purchased products
├── Order price low → high
└── Order price high → low

Wishlist Detail
├── Order price low → high
├── Order price high → low
└── Show only unpurchased

Home
├── Show authenticated user's name
├── Show real wishlists
└── Show real wishlist item counts
```

Location-based recommendations and personalized product recommendations are planned features and are not currently connected to backend logic.

---

## Preview on Windows

```powershell
flutter pub get
flutter run -d chrome
```

On the web, the application is centered inside a 402 × 874 px viewport with rounded corners.

This is useful for validating the interface, but it does not replace the iOS simulator.

The web version uses the same Firebase project and Firestore data as the iOS version.

---

## Run on the iOS Simulator

Requires a Mac with the full Xcode app (not just the Command Line Tools) and CocoaPods installed.

```bash
# One-time setup

sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

sudo xcodebuild -runFirstLaunch

brew install cocoapods

# Install Flutter dependencies

flutter pub get

# List available simulators

flutter devices

# Boot a simulator (skip if one is already running)

open -a Simulator

# Run the app

flutter run -d <device-id-from-flutter-devices>
```

If `flutter run` fails with an error about the iOS platform not being installed, download it once with:

```bash
xcodebuild -downloadPlatform iOS
```

---

## Build for iPhone

```bash
flutter pub get

flutter build ios
```

The SVG resources used by the application are located in:

```text
assets/figma/
```

---

## Architecture

The code uses a deliberately lightweight **feature-first** organization:

```text
lib/
├── main.dart
├── firebase_options.dart
│
├── app/
│   ├── app_routes.dart
│   ├── app_dependencies.dart
│   ├── dependencies_scope.dart
│   ├── whynot_app.dart
│   └── whynot_theme.dart
│
├── features/
│   ├── authentication/
│   ├── home/
│   ├── wishlists/
│   ├── products/
│   ├── purchases/
│   ├── profile/
│   └── admin/
│
└── shared/
    ├── domain/
    └── widgets/
```

Data-backed features own `domain/`, `data/`, `application/`, and
`presentation/` layers. Domain models and repository contracts are typed and
Firebase-free. Firebase implementations live under `data/`; controllers in
`application/` translate screen intents into repository operations.

A widget is moved to `shared` only when more than one feature uses it.

Firebase provides the shared backend and authenticated user session, while
screen-specific UI state remains local to each feature.

Screens do not call Firebase directly. `AppDependencies` wires the Firebase
repositories and controllers once at the application boundary, and
`DependenciesScope` makes them available to routes. Tests replace those
repositories with in-memory fakes.

No Provider/Riverpod/Bloc dependency is used; widgets continue to own local UI
state with `StatefulWidget` and `setState`.
````
