# Enterprise Distribution Guide

This guide covers distributing the Cyberdeck Login app without using the App Store.

## Distribution Options

### Option 1: Apple Developer Enterprise Program (Recommended for organizations)
- Requires Apple Developer Enterprise Program membership ($299/year)
- Can distribute to unlimited devices within your organization
- No App Store review required

### Option 2: Ad Hoc Distribution (Up to 100 devices)
- Requires standard Apple Developer Program ($99/year)
- Limited to 100 registered devices per year
- Good for small teams or personal use

### Option 3: TestFlight (Up to 10,000 testers)
- Requires standard Apple Developer Program
- App review required (but lighter than App Store)
- Good for beta testing

## Ad Hoc Distribution Setup

### 1. Register Devices

Collect UDIDs from all target devices:

```bash
# On Mac with device connected:
system_profiler SPUSBDataType | grep -A 11 "iPhone\|iPad"

# Or use Apple Configurator 2
# Or: Settings → General → About → tap Serial Number until UDID appears
```

Register devices in Apple Developer Portal:
1. Go to https://developer.apple.com/account/resources/devices/list
2. Click (+) to add device
3. Enter device name and UDID

### 2. Create Distribution Certificate

1. On your Mac, open Keychain Access
2. Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
3. Enter email, select "Saved to disk"
4. Go to Apple Developer Portal → Certificates
5. Create new certificate: **Apple Distribution**
6. Upload the CSR file
7. Download and double-click to install

### 3. Create Provisioning Profile

1. Go to Apple Developer Portal → Profiles
2. Click (+) to create new profile
3. Select **Ad Hoc** distribution
4. Select your App ID (or create one: `com.yourcompany.CyberdeckLogin`)
5. Select your Distribution Certificate
6. Select all devices that should be able to install
7. Name it: `CyberdeckLogin AdHoc`
8. Download the `.mobileprovision` file

### 4. Configure Xcode Project

1. Open project in Xcode
2. Select the project → Signing & Capabilities
3. Uncheck "Automatically manage signing"
4. For **Release** configuration:
   - Import the provisioning profile (drag to Xcode or double-click)
   - Select the profile in "Provisioning Profile" dropdown
   - Select the distribution certificate

### 5. Archive and Export

1. Select **Any iOS Device** as build target
2. Product → Archive
3. When archive completes, click **Distribute App**
4. Select **Ad Hoc**
5. Choose options:
   - App Thinning: None (or All compatible device variants)
   - Include manifest for over-the-air installation: ✓ (optional)
6. Select your distribution certificate
7. Click **Export**

### 6. Distribution Methods

#### A. Direct Installation via Xcode
1. Connect device to Mac
2. Window → Devices and Simulators
3. Drag .ipa file onto device

#### B. Apple Configurator 2
1. Open Apple Configurator 2
2. Connect device
3. Add → Apps → Choose the .ipa file

#### C. Over-the-Air (OTA) Installation
Requires a web server with HTTPS.

1. During export, check "Include manifest for over-the-air installation"
2. Enter the URLs where files will be hosted:
   - IPA URL: `https://yourserver.com/apps/CyberdeckLogin.ipa`
   - Display Image URL: `https://yourserver.com/apps/icon-57.png`
   - Full Size Image URL: `https://yourserver.com/apps/icon-512.png`

3. Upload to your server:
   - `CyberdeckLogin.ipa`
   - `manifest.plist`
   - Icon images

4. Create an HTML page with install link:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Install Cyberdeck Login</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
    <h1>Cyberdeck Login</h1>
    <a href="itms-services://?action=download-manifest&url=https://yourserver.com/apps/manifest.plist">
        Install App
    </a>
</body>
</html>
```

5. Users visit the page on their iOS device and tap to install

**Note:** The server must use HTTPS with a valid certificate.

#### D. MDM (Mobile Device Management)
For larger organizations, use an MDM solution like:
- Jamf
- Microsoft Intune
- Kandji
- Mosyle

## Watch App Distribution

The Watch app is bundled with the iPhone app automatically:

1. Ensure Watch target is included in the archive
2. The .ipa will contain both iPhone and Watch apps
3. When user installs iPhone app, Watch app is available in Watch app on iPhone

## Updating the App

For Ad Hoc distribution, you need to:
1. Increment the version/build number in Xcode
2. Create a new archive
3. Export with the same provisioning profile
4. Distribute the new .ipa

Users will need to install the new version manually (OTA link or direct install).

## Troubleshooting

### "Unable to Install" Error
- Device UDID not in provisioning profile
- Provisioning profile expired
- App was built for different architecture

### Profile Expired
- Provisioning profiles expire after 1 year
- Create new profile and re-export

### Device Limit Reached
- Ad Hoc is limited to 100 devices per year
- Devices cannot be removed until membership renewal
- Consider Enterprise program for more devices

## Automation with fastlane

For automated builds, use fastlane:

```ruby
# Fastfile
default_platform(:ios)

platform :ios do
  desc "Build and export Ad Hoc IPA"
  lane :adhoc do
    # Increment build number
    increment_build_number
    
    # Build
    build_app(
      scheme: "CyberdeckLogin",
      export_method: "ad-hoc",
      output_directory: "./build",
      output_name: "CyberdeckLogin.ipa"
    )
    
    # Optional: Upload to distribution server
    # scp("./build/CyberdeckLogin.ipa", "user@server:/var/www/apps/")
  end
end
```

Run with:
```bash
fastlane adhoc
```
