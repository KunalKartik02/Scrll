# Install Tidyroll on your iPhone for free

You don't need a Mac or a paid Apple Developer account. CI builds an unsigned app file
(`.ipa`). A free sideloading tool signs it with your normal Apple ID and installs it.

**Free Apple ID limits (set by Apple):** the app keeps working for **7 days**, then
needs a re-sign, which takes one click in the tools below. You can have up to 3
sideloaded apps at a time.

## 1. Download the app file

1. Open the repository on GitHub → **Actions** → the latest green **iOS build & test**
   run.
2. Under **Artifacts**, download **Tidyroll-unsigned-ipa**. You must be signed in to
   GitHub.
3. Unzip it to get `Tidyroll-unsigned.ipa`.

## 2a. Install with Sideloadly (Windows or Mac)

1. Install **iTunes** and **iCloud** from apple.com, not the Microsoft Store versions
   (Windows only). Then install **Sideloadly** from sideloadly.io.
2. Connect the iPhone with a USB cable, unlock it, and tap **Trust This Computer**.
3. Open Sideloadly and drag `Tidyroll-unsigned.ipa` into it.
4. Enter your Apple ID email and click **Start**. Enter your Apple ID password and, if
   asked, the two-factor code. The password goes only to Apple.
5. When it says **Done**, continue with step 3 below.

## 2b. Or install with AltStore (Windows or Mac, refreshes over Wi-Fi)

1. Install **AltServer** from altstore.io on the computer. On Windows, also install
   iTunes and iCloud from apple.com.
2. Use AltServer → **Install AltStore** → choose your iPhone, and sign in with your
   Apple ID.
3. Copy `Tidyroll-unsigned.ipa` to the iPhone, for example through AirDrop, iCloud
   Drive or the Files app.
4. Open **AltStore** on the iPhone → **My Apps** → **+** → pick the `.ipa`.
5. AltStore can renew the 7-day signature automatically. It does this while the iPhone
   and the computer running AltServer are on the same Wi-Fi.

## 3. First launch on the iPhone

1. **Settings → Privacy & Security → Developer Mode** → turn it on, then restart. iOS
   asks you to confirm after the restart. The switch appears only after a sideloaded app
   is installed.
2. **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
3. Open **Tidyroll** and allow photo access.

## Renewing after 7 days

If the app stops opening, run Sideloadly again with the same `.ipa`, or tap
**Refresh All** in AltStore. Your review progress is kept.

## Testing without a phone

Every CI run also tests the whole app in an iPhone simulator, using sample photos:
- the library and photo viewer
- a duplicate scan
- creating an album
- a swipe review that deletes a photo
- Settings

The run's **screenshots** artifact has a picture of each step.
