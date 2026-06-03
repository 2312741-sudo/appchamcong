# iOS Info.plist Permissions Guide

## Chấm Công Trạm — Required iOS Permission Keys

Add these keys to `ios/Runner/Info.plist` inside the `<dict>` tag.

> [!IMPORTANT]
> All permission descriptions must be provided in Vietnamese (or bilingual). Without them, Apple will reject the app.

---

## Required Keys

```xml
<!-- ── Location ─────────────────────────────────────────────────────── -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Ứng dụng cần quyền truy cập vị trí để xác nhận bạn đang ở trong phạm vi cửa hàng khi chấm công.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Ứng dụng cần quyền truy cập vị trí (luôn luôn) để hỗ trợ chấm công tự động trong nền.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Ứng dụng cần quyền truy cập vị trí để xác nhận vị trí chấm công của bạn.</string>

<!-- ── Camera ────────────────────────────────────────────────────────── -->
<key>NSCameraUsageDescription</key>
<string>Ứng dụng cần quyền truy cập camera để quét mã QR tham gia cửa hàng và chụp ảnh đại diện.</string>

<!-- ── Photo Library ──────────────────────────────────────────────────── -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Ứng dụng cần quyền truy cập thư viện ảnh để chọn ảnh đại diện của bạn.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Ứng dụng cần quyền lưu ảnh vào thư viện.</string>

<!-- ── Local Network (WiFi detection) ────────────────────────────────── -->
<key>NSLocalNetworkUsageDescription</key>
<string>Ứng dụng cần quyền truy cập mạng cục bộ để phát hiện WiFi cửa hàng và hỗ trợ chấm công qua WiFi.</string>
```

---

## Additional Info.plist Settings

```xml
<!-- Firebase Messaging Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>

<!-- Deep Link URL Scheme -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.chamcong.chamCongTram</string>
        </array>
    </dict>
</array>

<!-- Minimum iOS Version (already set in Podfile, but good practice here) -->
<key>MinimumOSVersion</key>
<string>13.0</string>
```

---

## Podfile Minimum Version

Ensure `ios/Podfile` has at minimum:

```ruby
platform :ios, '13.0'
```

---

## Xcode Capabilities to Enable

In Xcode → Target → Signing & Capabilities:
1. **Push Notifications** — for Firebase Cloud Messaging
2. **Background Modes** → check "Remote notifications" and "Background fetch"
3. **Location** — ensure "Allow location access: While Using" or "Always"

---

## GoogleService-Info.plist

After running `flutterfire configure`, you'll have a `GoogleService-Info.plist` file.
Place it at `ios/Runner/GoogleService-Info.plist` and add it to the Xcode project.

> [!CAUTION]
> Never commit `GoogleService-Info.plist` or `google-services.json` to a public repository.
> Add them to `.gitignore`.
