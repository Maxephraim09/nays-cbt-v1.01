# NAYS 2.0 Windows Desktop Compatibility Report

Audit date: 2026-11-11

## Scope and evidence

This report covers the Flutter project in `nays_mobile/`. The Windows runner was absent at the start of this task and has now been generated with Flutter 3.38.9 and project name `nays_mobile`. `flutter pub get` and `flutter analyze` pass. The resolved package graph, startup code, database implementation, Firebase options, and sign-in implementations were inspected. A native release build and live Windows authentication have not yet been verified.

## Findings

| Area | Finding | Impact / action |
| --- | --- | --- |
| Windows runner | The project had no `windows/` directory. A standard Flutter Windows runner now exists, with the NAYS 2.0 title/product metadata, organization name, logo icon, 1280x720 initial size, and 800x600 minimum size. The executable target remains `nays_mobile.exe`. | Runner files are configured; native compilation and launch remain blocked by the build toolchain. |
| Build toolchain | Flutter detects Windows 11 and a Windows desktop device, but Visual Studio Build Tools 2019 is incomplete. Flutter Doctor requires a supported Visual Studio C++ desktop toolchain. | Release compilation is blocked until Visual Studio (with Desktop development with C++) is installed/configured. |
| SQLite | The resolved `sqflite` plugin graph has Android and Apple implementations only. | Implemented: Windows initializes `sqflite_common_ffi` and stores the shared database under `getApplicationSupportDirectory()`. Android/iOS retain their existing factory selection. Windows runtime execution still needs verification on a machine with the build toolchain. |
| Firebase | `firebase_options.dart` throws for Windows. The resolved Firebase Core/Auth/Firestore/Functions packages contain web and platform-interface packages but no Windows plugin implementations. | Firebase initialization and cloud-backed features cannot be claimed as supported on Windows with the currently resolved FlutterFire packages. Windows app registration alone would not add missing native plugin implementations. |
| Google sign-in | The resolved `google_sign_in` graph has Android, iOS, and web implementations, with no Windows implementation. | The current native sign-in call is unsupported on Windows; use a separately designed supported desktop OAuth flow only after validating its security and Firebase credential exchange. |
| Facebook sign-in | `flutter_facebook_auth` resolves `facebook_auth_desktop`. | A desktop implementation is present, but live sign-in still requires correct Facebook app and OAuth configuration and has not been tested. |
| Local question bank | JSON manifest, subject, and question files exist and are declared as Flutter assets. Startup imports them through the existing seeder. | Existing importer and local exam tests pass with SQLite FFI. First-launch import on a Windows release executable remains unverified. |
| App startup | Startup opens and seeds SQLite before Firebase initialization. A database initialization failure prevents the app from reaching its Firebase fallback UI. | Windows SQLite initialization is now platform-aware. Database failure UI behavior remains unchanged and is a residual limitation. |
| Desktop UI | A full interaction/layout pass at multiple desktop sizes has not yet been performed. | No claim is made that every screen is overflow-free or desktop-optimized. Targeted rendering checks remain required. |
| Other platforms | Android, iOS, web, Linux, and macOS project directories exist. | Keep their startup and provider behavior unchanged while adding Windows-specific configuration. |

## Readiness summary

The runner, Windows icon, SQLite FFI setup, and Dart analysis are in place, but the project is not Windows-release-ready. Flutter cannot build because the installed Visual Studio Build Tools 2019 setup is incomplete and unsuitable. Firebase cloud services and Google sign-in have no Windows implementations in the resolved dependency set. Live Windows startup, first-launch question-bank import, authentication, and desktop layout remain unverified. Do not distribute a Windows build as fully functional until these blockers and checks are resolved.

## Checks completed

- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: passed, 56 tests.
- `flutter doctor -v`: Windows detected; Visual Studio C++ toolchain incomplete; Android toolchain check timed out.
- `flutter devices`: Windows desktop, Chrome, and Edge detected.
- `flutter build windows --release`: blocked with “Unable to find suitable Visual Studio toolchain.”
- Windows release launch smoke test and packaged output inspection: not possible because the build did not produce an executable.