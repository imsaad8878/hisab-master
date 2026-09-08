# Hisab Master — Setup Guide (বাংলায়)

Ekta **Expense & Income Tracker** app (Flutter + Firebase). Offline kaj kore,
internet ele apun apun sync hoy.

## Stage 0 — Firebase chara app cholbe?
Hya! Firebase configure na korle-o app ta **"demo mode"** e cholbe — shob data
shudhu tomar phone te thakbe. App khulle "Continue in demo mode" chapo.

---

## Stage 1 — Chola (demo mode)
```powershell
cd hisab_master
flutter pub get
flutter run          # phone USB debugging on kore lagao, othoba emulator
```

## Stage 2 — Firebase (Google login + sync) — ekbar korte hobe

### A. Firebase project toiri — **DONE ✓**
- google-services.json already ache `android/app/` e.
- Package name: `com.saad.hisabmaster` (android/ e set kora hoyeche).

### B. Auth enable koro (Firebase console → Authentication → Get started)
1. **Google** provider → Enable → support email dao → Save.
   - Ekhane je **"Web client ID"** dekhabe (`xxxx.apps.googleusercontent.com`)
     sheta copy kore `lib/data/repositories/auth_repository.dart` file e
     `kGoogleServerClientId` constant e bosao.
2. **Email/Password** provider → Enable → Save.

### C. Firestore database
1. Firebase console → Firestore Database → **Create database** →
   production mode → region (e.g. `asia-south1`).
2. Rules deploy koro: project folder e giye
   ```powershell
   firebase login
   firebase deploy --only firestore:rules
   ```
   (Ba console e Firestore → Rules tab e `firestore.rules` er code paste kore Publish.)

### D. Flutter config (Android e optional — google-services.json thaklei cholbe)
`flutter run` korlei Android e Firebase auto-connect hoy (google-services.json theke).
Aro robust/configurable nite chaile:
```powershell
dart pub global activate flutterfire
flutterfire configure --project-id <tomar-project-id>
```
Ei command `lib/firebase_options.dart` ke tomar real config diye replace kore debe
(Android/dui-ta-i kaj korbe). Tarpor **rebuild**: `flutter run`.

Ekhon theke app Firebase mode e cholbe: Google login, email login, ar
Firestore e data save + auto sync (offline persistenceFirestore library te
default on; amra explicitly-o check korechi).

---

## Data kokon kothay thake?
- **Firebase mode**: protita transaction tomar Firebase **UID** er niche
  `users/{uid}/transactions/` e jay. App delete kore abar install kore
  **same account** e login korle 100% data fire pawa jabe.
- **Offline**: net na thakle data Firestore local cache e instant save hoy,
  net aslei auto sync hoy.
- **Satark**: sync howar **age** jodi app delete koro, shei unsynced data
  hoye jabe.

## Common problem
- `No Google provider` / idToken error → Web client ID ta
  `kGoogleServerClientId` te dao, ar Authentication e Google enable ache kina check koro.
- Install er somoy signing error → `flutter run` er somoy `--debug` default thake, problem na.
- Data sync hocche na → Firestore rules deploy hoche kina check koro;
  Profile screen e "Sync status" dekho.
