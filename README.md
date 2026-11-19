Use the following prompt in **GitHub Copilot Agent Mode** from your NAYS mobile project. It instructs Copilot to audit the entire Flutter codebase, make the necessary Windows desktop adaptations, fix compatibility issues, and produce a working Windows release build without damaging the existing Android, iOS, or web applications.

\# NAYS 2.0 — COMPLETE WINDOWS DESKTOP READINESS AUDIT, IMPLEMENTATION & RELEASE BUILD\
\
\*\*Project directory:\*\*\
\`C:\Users\MGTechs\GITHUB\NAYS_2.0.1\nays_mobile\`\
\
\*\*Project:\*\* NAYS 2.0 — National Association of Yungur Students\
\
\*\*Objective:\*\* Thoroughly examine the existing Flutter codebase, ensure the application is fully compatible with Windows desktop, implement all necessary desktop support and fixes, and successfully build a production-ready Windows application.\
\
\## 1. IMPORTANT IMPLEMENTATION RULES\
\
You must work directly inside the existing project.\
\
\- Do not create a separate demo application.\
\- Do not replace the existing application with a new template.\
\- Do not redesign or unnecessarily change the existing UI.\
\- Preserve the existing branding, theme, colors, navigation, screens, business logic, and application identity.\
\- Preserve all existing Android, iOS, and web functionality.\
\- Do not introduce mock data, fake API responses, placeholder functionality, or demo authentication.\
\- Do not remove existing features simply because they have compatibility issues.\
\- Do not claim that something works without testing it.\
\- Make actual code changes, not just recommendations.\
\
The Windows version must be a genuine desktop application, not a mobile application running inside a desktop window.\
\
\## 2. COMPLETE CODEBASE AUDIT\
\
Inspect the entire project before making changes.\
\
Examine:\
\
\- pubspec.yaml and dependency compatibility.\
\- Flutter and Dart SDK requirements.\
\- Existing Windows platform directory.\
\- Application entry point and initialization.\
\- Authentication and Firebase configuration.\
\- Firestore services and security-sensitive operations.\
\- SQLite database and local question-bank storage.\
\- JSON question-bank imports and asset loading.\
\- Offline examination functionality.\
\- User preferences and settings.\
\- Routing and navigation.\
\- File and image handling.\
\- Notifications and external integrations.\
\- Google and Facebook authentication.\
\- Leaderboard and cloud synchronization.\
\- All existing screens and widgets.\
\- Platform-specific dependencies.\
\- Fonts, icons, images, and other bundled assets.\
\
Identify every dependency, API, plugin, or implementation that may fail on Windows.\
\
Create a compatibility report before implementing fixes.\
\
\## 3. WINDOWS DESKTOP PLATFORM CONFIGURATION\
\
Ensure Windows desktop support is correctly configured.\
\
Tasks:\
\
1\. Enable Flutter Windows desktop support.\
2\. Create or repair the Windows platform runner if necessary.\
3\. Configure the Windows application name as NAYS 2.0.\
4\. Configure a proper application icon using the existing NAYS logo.\
5\. Verify the Windows executable and application metadata.\
6\. Configure application startup and initialization.\
7\. Ensure correct asset and font bundling.\
8\. Configure desktop window dimensions and sensible minimum dimensions.\
9\. Ensure the application launches correctly without requiring an Android emulator.\
10\. Configure proper application shutdown and resource disposal.\
\
Do not overwrite valid existing Windows configuration unnecessarily.\
\
\## 4. DESKTOP UI AND RESPONSIVENESS\
\
Adapt the existing UI for desktop screens while preserving the original design identity.\
\
Support:\
\
\- Small desktop windows.\
\- Standard laptop displays.\
\- Full HD displays.\
\- Large monitors.\
\- Resizable application windows.\
\
Ensure:\
\
\- No RenderFlex overflow errors.\
\- No clipped content.\
\- No inaccessible navigation.\
\- No unnecessarily stretched mobile layouts.\
\- Proper content width and spacing.\
\- Appropriate desktop typography.\
\- Consistent branding and colors.\
\- Proper scrolling behavior.\
\
Desktop interaction requirements:\
\
\- Mouse clicks must work.\
\- Keyboard navigation must work where appropriate.\
\- Tab navigation must be accessible.\
\- Enter and Escape keys must behave appropriately.\
\- Buttons must provide proper hover and focus feedback.\
\- Text fields must support desktop keyboard input.\
\- Dialogs and menus must display correctly.\
\- Tables and lists must remain readable.\
\
Preserve the existing mobile UI and introduce responsive desktop adaptations only where necessary.\
\
\## 5. FIREBASE AND AUTHENTICATION COMPATIBILITY\
\
Inspect the current Firebase configuration.\
\
Verify:\
\
\- Firebase Core initialization.\
\- Firebase Authentication.\
\- Email/password authentication.\
\- Email verification.\
\- Google sign-in.\
\- Facebook sign-in.\
\- Firestore connectivity.\
\- User profile synchronization.\
\- Leaderboard synchronization.\
\
Do not assume that Android authentication configurations automatically work on Windows.\
\
For every unsupported authentication provider:\
\
1\. Identify the exact limitation.\
2\. Determine whether a supported Windows implementation exists.\
3\. Implement the appropriate secure desktop authentication flow if feasible.\
4\. Otherwise, provide a clear, honest explanation of the required external configuration.\
\
Never bypass authentication or introduce fake login functionality.\
\
Ensure the application handles Firebase initialization failures gracefully.\
\
\## 6. LOCAL QUESTION BANK AND OFFLINE CBT\
\
The NAYS question bank must remain locally available inside the application.\
\
The existing architecture uses:\
\
\- Bundled JSON question-bank assets.\
\- SQLite local database.\
\- Local question and answer storage.\
\- Offline examination functionality.\
\- Firebase for authentication, cloud profile data, synchronization metadata, and supported cloud features.\
\
Preserve this architecture.\
\
Verify that Windows supports:\
\
\- Importing bundled JSON question banks.\
\- Initializing SQLite.\
\- Importing questions into the local database.\
\- Retrieving questions by subject.\
\- Randomized question selection.\
\- Answer selection and saving.\
\- Examination countdown.\
\- Automatic submission.\
\- Manual submission.\
\- Examination recovery where supported.\
\- Offline practice.\
\- Examination history.\
\- Scoring and result calculations.\
\- Explanation display.\
\
Ensure database files are stored in an appropriate writable Windows application-data directory.\
\
Do not store writable database files inside the installation directory.\
\
Verify that importing the question bank is idempotent and does not create duplicate questions.\
\
Do not generate fake or unreviewed questions to fill missing question-bank requirements.\
\
\## 7. WINDOWS-SPECIFIC FUNCTIONALITY\
\
Implement appropriate desktop behavior.\
\
Where applicable, support:\
\
\- Native file selection.\
\- File opening.\
\- File saving.\
\- Clipboard operations.\
\- Keyboard shortcuts.\
\- Proper window resizing.\
\- Desktop notifications where supported.\
\- Appropriate error messages.\
\- Local data persistence.\
\
Inspect every existing plugin and replace unsupported implementations only when necessary.\
\
Do not compromise existing functionality on other platforms.\
\
\## 8. TESTING AND QUALITY ASSURANCE\
\
Run the following checks:\
\
1\. Flutter dependency resolution.\
2\. Windows compilation checks.\
3\. Dart static analysis.\
4\. Existing unit tests.\
5\. Existing widget tests.\
6\. Database tests.\
7\. Offline CBT tests.\
8\. Authentication initialization tests.\
9\. Responsive layout tests where available.\
10\. Windows release compilation.\
\
Commands:\
\
\`\`\`powershell\
flutter doctor -v\
flutter devices\
flutter pub get\
flutter analyze\
flutter test\
flutter build windows --release\
\`\`\`\
\
Fix all errors introduced by your changes.\
\
Do not delete failing tests to obtain a successful result.\
\
Investigate existing failures and distinguish pre-existing issues from newly introduced problems.\
\
\## 9. BUILD THE WINDOWS RELEASE APPLICATION\
\
Once the audit and implementation are complete, build the actual Windows release application:\
\
\`\`\`powershell\
flutter clean\
flutter pub get\
flutter analyze\
flutter test\
flutter build windows --release\
\`\`\`\
\

flutter clean
flutter pub get
flutter build apk --release


Expected output directory:\
\
\`C:\Users\MGTechs\GITHUB\NAYS_2.0.1\nays_mobile\build\windows\x64\runner\Release\\\`\
\
Verify that the directory contains:\
\
\- NAYS 2.0 executable.\
\- Required Flutter runtime files.\
\- Required plugin DLLs.\
\- Data directory.\
\- Required application assets.\
\- Other necessary runtime dependencies.\
\
Do not provide only the executable if the application requires other files to run.\
\
Test launching the actual release executable.\
\
Check for startup crashes, missing DLLs, missing assets, Firebase initialization failures, and database initialization errors.\
\
\## 10. OPTIONAL WINDOWS INSTALLER\
\
After successfully building and testing the release application, assess whether an installer can be generated.\
\
If feasible, create a Windows installer using an appropriate packaging tool such as Inno Setup.\
\
The installer should:\
\
\- Install NAYS 2.0.\
\- Create Start Menu shortcuts.\
\- Optionally create a desktop shortcut.\
\- Use the NAYS application icon.\
\- Include the complete release bundle.\
\- Support normal uninstall operations.\
\
Do not make installer creation a reason to skip the actual Flutter Windows release build.\
\
\## 11. FINAL ACCEPTANCE REQUIREMENTS\
\
The project should not be declared Windows-ready until:\
\
\- [ ] Windows platform configuration is valid.\
\- [ ] Flutter Windows release compilation succeeds.\
\- [ ] Application launches successfully.\
\- [ ] Existing application branding is preserved.\
\- [ ] Authentication is correctly configured or documented where external setup remains necessary.\
\- [ ] SQLite initializes successfully.\
\- [ ] Local question-bank assets load correctly.\
\- [ ] Offline CBT functionality works.\
\- [ ] Existing core application screens render correctly.\
\- [ ] Desktop navigation works.\
\- [ ] No critical desktop layout overflows remain.\
\- [ ] Existing Android, iOS, and web configurations remain intact.\
\- [ ] Existing tests pass, or outstanding pre-existing failures are documented.\
\- [ ] Release output contains all required runtime dependencies.\
\
\## 12. FINAL IMPLEMENTATION REPORT\
\
When finished, provide a detailed report containing:\
\
1\. Initial Windows compatibility assessment.\
2\. Files inspected.\
3\. Files created.\
4\. Files modified.\
5\. Dependencies added, removed, or updated.\
6\. Windows compatibility issues discovered.\
7\. Fixes implemented.\
8\. Firebase and authentication status.\
9\. SQLite and offline CBT test results.\
10\. Flutter analysis results.\
11\. Flutter test results.\
12\. Windows release build result.\
13\. Exact executable path.\
14\. Exact release folder path.\
15\. Installer location, if successfully generated.\
16\. Remaining limitations and required manual configuration.\
\
\*\*FINAL INSTRUCTION:\*\*\
\
Do not stop after auditing the codebase or generating a list of recommendations. Continue with implementation, testing, and the Windows release build.\
\
Your goal is to deliver a functioning NAYS 2.0 Windows desktop application while preserving the existing mobile application and all supported features.\
\
Be honest about anything that cannot be implemented or verified. Never report a successful test or build unless it actually succeeded.\

## How to execute it

1. Open VS Code.
2. Open the `nays_mobile` project folder.
3. Switch GitHub Copilot to **Agent Mode**.
4. Paste the entire prompt.
5. Allow Copilot to inspect, edit and execute terminal commands.
6. Review its changes before accepting major dependency or platform configuration changes.

**Important:** The Windows release build will be a folder containing the `.exe` and its required supporting files. It is not necessarily a standalone executable.

Your expected executable will be:

```
build\windows\x64\runner\Release\nays_mobile.exe
```

The exact executable name depends on the Windows runner configuration.

**My recommendation:** First get the Windows release build running correctly, then package it into a proper NAYS 2.0 Windows installer (`.exe` installer) for distribution to students, teachers and administrators.
