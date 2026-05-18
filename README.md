# Mini MDM Installer 🚀

A lightweight, cross-platform desktop application built with **Flutter** designed for mobile developers, QA engineers, and device lab administrators. This tool simplifies the process of discovering Android and iOS devices over your local wireless network (or USB) and allows you to deploy, manage, or wipe builds across **all connected devices concurrently** with a single click.

No more manual installation scripts or repetitive command-line loops for each separate testing device.

---

## 📸 Screenshots & Demo Interface

Below is a visual walk-through of the utility interface handling wireless network handshakes and parallel deployments:

### 1. Device Ecosystem Management

|                                             🖥️ 1. Active Wireless Discovery UI                                             |                                           📱 2. Connected Device Profile                                            |
| :------------------------------------------------------------------------------------------------------------------------: | :-----------------------------------------------------------------------------------------------------------------: |
| ![Wireless Device Discovery](assets/images/active-devices.png) <br> _Real-time local network scanning and pairing status._ | ![Device Hardware Profile](assets/images/pair-devices.png) <br> _Inspecting system versioning and connection logs._ |

### 2. Deployment Processing & Inventory

|                                                📦 3. Bulk Application Installer                                                |                                                      📱✨ 4. Installed Apps Manager                                                       |
| :----------------------------------------------------------------------------------------------------------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------: |
| ![Bulk APK/IPA Installation](assets/images/bulk-install.png) <br> _Streaming deployment progress to all nodes simultaneously._ | ![Installed Apps Management](assets/images/installed-apps.png) <br> _Viewing, sorting, and batch-managing apps currently on the devices._ |

### 3. iOS Tooling Expansion

|                                                              🍏 5. iOS IPA Deployment Engine                                                               |
| :--------------------------------------------------------------------------------------------------------------------------------------------------------: |
| ![iOS IPA Manager Dashboard](assets/images/05_ipa_manager.png) <br> _Dedicated pipeline for code-signing checks and provisioning iOS hardware over macOS._ |

---

## ✨ Features

- **Wireless Device Discovery:** Automatically scan, pair, and list active Android and iOS devices on your local Wi-Fi network.
- **Parallel Bulk Installation:** Select your mobile application binary (`.apk` or `.ipa`) and push it to every target device simultaneously.
- **Simultaneous Uninstallation:** Instantly wipe pre-existing testing versions across all devices cleanly using the application package/bundle identifier.
- **Local Cross-Platform Execution:** Built to run natively as a lightweight utility on your desktop machine (macOS/Windows).

---

## ⚠️ Current Scope & Limitations

Please keep the following system constraints in mind for the current release of the application:

- **🤖 Android Ecosystem (Fully Stable):** Full support for wireless and wired pairing, bulk installation, and application uninstallation via **Android APKs** across all desktop platforms (macOS & Windows) using the system `adb` pipeline.
- **🍏 iOS Ecosystem (macOS Host Only):** Deployment of **iOS IPAs** is now fully operational, utilizing Xcode's native `xcrun devicectl` engine. _Note: The host machine must be running macOS to deploy IPAs at this time._
- **🪟 iOS Support on Windows (Coming Soon):** Cross-platform iOS deployment from a Windows host (via the `libimobiledevice` toolchain integration) is currently under active development.
- **🌐 Network Dependencies:** Wireless actions require all target mobile hardware and the host computer to be connected to the exact same local Wi-Fi subnet.

---

## 🤝 Contributing

We welcome contributors to help expand the capabilities of this tool! We are explicitly looking for developers to help bridge the gap on the **Windows-to-iOS** deployment pipeline.

### How to Get Involved:

1. **Fork** the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'feat: add some amazing feature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a **Pull Request**.

If you have experience working with `libimobiledevice` or compiling native C-libraries for Windows utilities within a Flutter environment, we would love to see your input!

---

## 🛠️ System Architecture

The tool serves as a visual orchestration layer that directly communicates with native platform SDK toolchains:
[ Mini MDM Installer UI ]
│
┌──────────────┴──────────────┐
▼ ▼
[ Android Tooling ] [ iOS Tooling ]
│ │
(Android SDK `adb`) (macOS: `xcrun devicectl`)
(Windows: `libimobiledevice`)

- **Android:** Executes batch calls directly to the official Android SDK `adb` binary, streaming parallel data loops to handle connected devices.
- **iOS (macOS Host):** Utilizes Xcode's native `xcrun devicectl` utility to handle secure device handshakes, network installations, and container updates.
- **iOS (Windows Host):** Integrates open-source `libimobiledevice` protocols to communicate natively with iOS hardware without requiring an active Xcode environment.

---

## 📋 Prerequisites

To experience seamless wireless deployments, configure your environments as follows:

### Android Testing Pool

1. Enable **Developer Options** and **Wireless Debugging** on all target devices.
2. Ensure the host computer running this app has the Android SDK Platform-Tools (`adb`) installed and configured.
3. Both the host machine and mobile hardware must be on the exact same Wi-Fi subnet.

### iOS Testing Pool

1. Switch your target iOS devices to **Developer Mode** (Settings -> Privacy & Security -> Developer Mode).
2. All `.ipa` binaries **must** be properly code-signed with a development or provisioning profile that explicitly includes the UDIDs of your target hardware.
