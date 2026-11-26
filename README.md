# In.Speed v26.11.26.01

Universal iOS 17+ app, build 3. Open `InSpeed.xcodeproj` and select the shared InSpeed scheme. For a physical device, select your Apple development team under Signing & Capabilities. The app identifier is `au.h-v.in.speed`. The intended Australian price is A$7.99 and is set in App Store Connect.

**Recording.** Start a trip from Speed or Compass. The selected activity determines the speed range and movement thresholds. The range expands when the current trip exceeds the base scale. The bottom-left menu changes the unit system at any time. GPS travel direction takes precedence while moving. At low speeds the compass uses the device heading, with magnetic north as a fallback when true north is unavailable.

**Trip summaries.** Distance, active duration, peak speed and valid altitude extrema are stored in the app’s Application Support directory. Combined average is total distance divided by total recorded duration. Auto-pause excludes stationary time after a short dwell. By default a started trip records in the background. Turning that preference off suspends recording when the app leaves the foreground. A restored checkpoint continues the same trip and excludes the time the app was terminated. Checkpoints are saved every ten seconds and when the app backgrounds. Coordinates live only in memory.

**Source.** LocationService owns Core Location and the active trip across view changes. TripStore atomically saves active and completed records in one file. Models contains unit conversion, trip mathematics, speed plausibility and window layout rules. Instrument draws the dial. ContentView and TripViews present the live controls, history and totals.

**Verification.** The GitHub Actions workflow runs model/storage tests, then builds and runs the UI tests on iPhone and iPad simulators and retains XCTest results and screenshots. Its location permission is granted before the UI tests. For a manual UI test in Xcode, first launch the app once and grant When In Use location access. For field acceptance, check speed and compass on hardware, lock and unlock during a trip, and resize an iPad window while recording.

## GitHub build

Extract this ZIP into the repository root, including the hidden .github/workflows directory, and commit the extracted files. A push starts the “Build In.Speed” workflow. The Actions run produces an unsigned Release device archive and separate XCTest results for iPhone and iPad. The archive is for build verification. Installation on hardware or submission to TestFlight requires Apple signing and provisioning.
