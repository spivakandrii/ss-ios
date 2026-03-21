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
| `SSAPIClient.m` | Data loader (offline from bundle, fallback to online via TLS 1.2) |
| `SSHTTPClient.m` | HTTP client using libcurl + OpenSSL for TLS 1.2 on iOS 5 |
| `download_days.py` | Script to fetch lesson data from API |
| `build_openssl.sh` | Cross-compile OpenSSL 1.1.1w for armv7 |
| `build_curl.sh` | Cross-compile libcurl 7.88.1 with OpenSSL for armv7 |
| `lib/libssl.a` | OpenSSL SSL static library (armv7) |
| `lib/libcrypto.a` | OpenSSL Crypto static library (armv7) |
| `lib/libcurl.a` | libcurl static library (armv7, with OpenSSL backend) |

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
  ~/theos/toolchain/linux/iphone/bin/ranlib lib/libcrypto.a 2>/dev/null;
  ~/theos/toolchain/linux/iphone/bin/ranlib lib/libssl.a 2>/dev/null;
  ~/theos/toolchain/linux/iphone/bin/ranlib lib/libcurl.a 2>/dev/null;
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

## Rebuilding TLS Libraries (if needed)

The pre-built `lib/libssl.a`, `lib/libcrypto.a`, and `lib/libcurl.a` are included in the repo. Only rebuild if you need to update versions.

### OpenSSL 1.1.1w

```bash
wsl bash -lc "bash /mnt/c/Source/ss_ios/build_openssl.sh"
```

What it does:
1. Downloads OpenSSL 1.1.1w source
2. Configures with `linux-generic32` target, CC set to Theos clang with `-target arm-apple-darwin11 -arch armv7 -isysroot iPhoneOS9.3.sdk`
3. Generates `opensslconf.h` via perl (must run `make include/openssl/opensslconf.h` before building)
4. Builds `libssl.a` and `libcrypto.a`
5. Copies to `lib/` and headers to `include/openssl/`

Key flags: `no-shared no-dso no-engine no-tests no-asm no-async -DOPENSSL_NO_SECURE_MEMORY`

### libcurl 7.88.1

```bash
wsl bash -lc "bash /mnt/c/Source/ss_ios/build_curl.sh"
```

What it does:
1. Downloads curl 7.88.1 source
2. Creates a manual `curl_config.h` (autotools configure can't cross-compile)
3. Compiles all `.c` files in `lib/`, `lib/vtls/`, `lib/vauth/` with Theos clang
4. Creates `libcurl.a` with `llvm-ar`
5. Copies to `lib/` and headers to `include/curl/`

Disabled protocols: LDAP, DICT, TELNET, TFTP, POP3, IMAP, SMTP, GOPHER, MQTT, RTSP, SMB, FTP, FILE

### Makefile flags

```makefile
SabbathSchool_CFLAGS = ... -Iinclude
SabbathSchool_LDFLAGS = ... -Llib -lcurl -lssl -lcrypto -lz
SabbathSchool_FRAMEWORKS = ... Security
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **No route to host** | iPad is sleeping or not on Wi-Fi. Wake it up |
| **Connection refused** | OpenSSH not running on iPad. Reboot iPad |
| **DEBIAN permissions error** | Building on NTFS. Copy to `/tmp/` first (see Build) |
| **lib*.a: no table of contents** | Run `ranlib` on .a files before building (see Build) |
| **White screen on launch** | Data files missing in `Resources/data/`. Run `download_days.py` |

## Tech Stack

- **Language:** Objective-C (ARC)
- **UI:** UIKit + UIWebView (HTML/CSS/JS for lesson content)
- **Build:** Theos, targeting armv7 / iOS 5.0+
- **TLS:** OpenSSL 1.1.1w + libcurl 7.88.1 (static, for TLS 1.2 on iOS 5)
- **Signing:** `ldid -S` (ad-hoc, jailbroken only)
- **Package:** `.deb` via `dpkg`

## License

This project uses lesson data from [Adventech](https://github.com/Adventech) (open API).
