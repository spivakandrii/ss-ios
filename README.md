# Sabbath School (Суботня Школа)

Offline Bible study app for **iPad 1st generation (iOS 5.1.1)** — Seventh-day Adventist quarterly lessons with Bible verse popups and translation switcher.

Built with [Theos](https://theos.dev) for jailbroken devices.

## Features

- 📖 Weekly Sabbath School lessons with full text
- 📜 Bible verse popups with multiple translations (synodal, ERV, UBIO for Ukrainian; NTR, VDC for Romanian)
- 🌙 Dark mode (applies to all screens)
- 🔤 Font size & family picker
- 📝 Notes per day (saved locally)
- ✅ Read progress tracking per lesson
- 👆 Swipe between days, fullscreen reading mode
- 🔄 Auto-opens today's lesson on launch
- 🌐 Ukrainian & Romanian languages

## Screenshots

*iPad 1G, iOS 5.1.1*

## Architecture

| File | Description |
|------|-------------|
| `SSAppDelegate.m` | App launch, auto-open today's lesson |
| `SSLanguageVC.m` | Language selection (uk/ro) |
| `SSQuarterliesVC.m` | List of quarterly studies |
| `SSLessonsVC.m` | List of lessons with read progress |
| `SSReadVC.m` | Main reader — UIWebView with HTML content, verse popups, notes, font/theme controls |
| `SSAPIClient.m` | Data loader (offline from bundle or online via TLS 1.2) |
| `SSHTTPClient.m` | HTTP client using CFNetwork + wolfSSL for TLS 1.2 on iOS 5 |
| `download_days.py` | Script to fetch lesson data from API |
| `lib/libwolfssl.a` | wolfSSL static library (armv7) for TLS 1.2 support |

## Data Source

All lesson data comes from the open [Adventech API](https://github.com/Adventech):
```
https://sabbath-school.adventech.io/api/v2
```

Data is pre-downloaded and bundled in `Resources/data/` for offline use.

### Data structure
```
data/{lang}/quarterlies.json                         — list of quarterlies
data/{lang}/{quarter}/lessons.json                   — lessons in a quarter
data/{lang}/{quarter}/{lesson}/index.json            — lesson detail with days
data/{lang}/{quarter}/{lesson}/{day}.json            — day content with Bible verses
```

## Prerequisites

| Tool | Purpose |
|------|---------|
| **WSL** (Windows Subsystem for Linux) | Build environment |
| **Theos** (`~/theos` in WSL) | iOS build system |
| **iPhoneOS 9.3 SDK** | In `~/theos/sdks/` |
| **Python 3** | For downloading lesson data |
| **Jailbroken iPad 1G** | SSH enabled, on same Wi-Fi |

## Build

> **Important:** NTFS gives 777 permissions which breaks dpkg. Always copy to native Linux filesystem first.

```bash
# Copy to Linux fs, fix permissions, build
wsl bash -lc '
  rm -rf /tmp/ss_build &&
  cp -r /mnt/c/Source/ss_ios /tmp/ss_build &&
  cd /tmp/ss_build &&
  chmod 0755 layout/DEBIAN &&
  ~/theos/toolchain/linux/iphone/bin/ranlib lib/libwolfssl.a &&
  export THEOS=~/theos &&
  make clean && make package
'
```

The `.deb` package appears in `/tmp/ss_build/packages/`.

## Deploy to iPad

Default iPad SSH: `root@192.168.1.128`, password: `alpine`

### 1. Create SSH password helper (once per WSL session)

Old iPad requires legacy SSH algorithms. This helper avoids interactive password prompts:

```bash
wsl bash -lc '
  cat > /tmp/sshpw.sh << "EOF"
#!/bin/bash
echo alpine
EOF
  chmod +x /tmp/sshpw.sh
'
```

### 2. Copy, install, sign, respring (one command)

```bash
wsl bash -lc '
  DEB=$(ls -t /tmp/ss_build/packages/*.deb | head -1) &&
  cp "$DEB" /tmp/ss.deb &&
  export SSH_ASKPASS=/tmp/sshpw.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 &&
  SSH_OPTS="-o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa" &&
  scp $SSH_OPTS /tmp/ss.deb root@192.168.1.128:/tmp/ss.deb &&
  ssh $SSH_OPTS root@192.168.1.128 "
    killall SabbathSchool 2>/dev/null;
    dpkg -r com.adventist.sabbathschool;
    dpkg -i /tmp/ss.deb;
    ldid -S /Applications/SabbathSchool.app/SabbathSchool;
    killall SpringBoard
  "
'
```

After SpringBoard respring, the app appears on the home screen.

## Update Lesson Data (New Quarter)

1. Edit `QID` in `download_days.py` (e.g. `2026-02`)
2. Run the download script:
   ```bash
   python3 download_days.py
   ```
3. Copy downloaded data into the app bundle:
   ```bash
   cp -r data/* Resources/data/
   ```
4. Rebuild and deploy (see above)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **No route to host** | iPad is sleeping or not on Wi-Fi. Wake it up |
| **Connection refused** | OpenSSH not running on iPad. Reboot iPad |
| **DEBIAN permissions error** | Building on NTFS. Copy to `/tmp/` first (see Build) |
| **libwolfssl.a: no table of contents** | Run `ranlib lib/libwolfssl.a` before building |
| **White screen on launch** | Data files missing in `Resources/data/`. Run `download_days.py` |

## Tech Stack

- **Language:** Objective-C (ARC)
- **UI:** UIKit + UIWebView (HTML/CSS/JS for lesson content)
- **Build:** Theos, targeting armv7 / iOS 5.0+
- **TLS:** wolfSSL 5.7.6 (static, for TLS 1.2 on iOS 5)
- **Signing:** `ldid -S` (ad-hoc, jailbroken only)
- **Package:** `.deb` via `dpkg`

## License

This project uses lesson data from [Adventech](https://github.com/Adventech) (open API).
