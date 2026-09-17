# Cross-Platform Project Starter (Flutter)

Welcome to the team project repository for the Cross-Platform Development course.

## Team Details
* **Student 1**: Mahdi Abbasi ([GitHub Handle])
* **Student 2**: Kenan Sabic ([GitHub Handle])
* **App Name**: [Your App Concept Name]

---

## Environment Setup Requirements

Before running the application, ensure your mobile development tools are configured.

### 1. Android Emulator (Windows / Mac / Linux)
1. Install **Android Studio** and the **Flutter SDK**.
2. Open Android Studio $\rightarrow$ **Virtual Device Manager** (AVD) and create a virtual device (e.g., Pixel 6 with API 34).
3. Ensure `ANDROID_HOME` and Flutter are added to your system `PATH`.

#### Managing Emulators via Terminal:
* **List installed emulators**:
  ```bash
  emulator -list-avds
  ```
* **Start an emulator from command line**:
  ```bash
  emulator -avd <YOUR_AVD_NAME>
  ```
  *(Example: `emulator -avd Pixel_6_API_34`)*

---

### 2. iOS Simulator (Mac Only)
1. Install **Xcode** from the Mac App Store.
2. Open Xcode once to accept the license agreement and install required component tools.
3. Open Simulator via Xcode $\rightarrow$ Open Developer Tool $\rightarrow$ Simulator.

---

## How to Run the App

1. Clone your generated repository and navigate into it:
   ```bash
   git clone <your-team-repo-url>
   cd <your-team-repo-name>
   ```

2. **Generate native platform folders (CRITICAL STEP):**
   Because this repository only contains the pure Dart code, you must generate the native Android/iOS shells before running the app.
   ```bash
   flutter create .
   ```

3. Fetch dependencies:
   ```bash
   flutter pub get
   ```

4. Check your toolchain setup:
   ```bash
   flutter doctor
   ```

5. Launch on target platform:
    * **Start application**:
      ```bash
      flutter run
      ```
      *(If multiple devices/emulators are running, you can specify one using `flutter run -d <device-id>`)*

---

## Troubleshooting

* **No connected devices found**
    * **Fix**: Ensure your Android Emulator or iOS Simulator is running *before* executing `flutter run`.
* **`flutter command not found`**
    * **Fix**: Add your Flutter SDK `bin` folder path to your OS environment variables.
