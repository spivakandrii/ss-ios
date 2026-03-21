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
- 🌐 91 languages via Adventech API (Ukrainian, Romanian, English + all others)
- 🔒 TLS 1.2 via statically linked OpenSSL + libcurl (bypasses iOS 5 TLS 1.0 limitation)
- 💾 Smart caching: shows local data instantly, silently refreshes from API in background

## Screenshots

*iPad 1G, iOS 5.1.1*

## Architecture

| File | Description |
|------|-------------|
| `SSAppDelegate.m` | App launch, auto-open today's lesson |
| `SSLanguageVC.m` | Language selection (uk/ro/en + 91 languages from API) |
| `SSQuarterliesVC.m` | List of quarterly studies |
| `SSLessonsVC.m` | List of lessons with read progress |
| `SSReadVC.m` | Main reader — UIWebView with HTML content, verse popups, notes, font/theme controls |
| `SSAPIClient.m` | Data loader: cache (Documents) → bundle → API. Background refresh silently |
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
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/index.json
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/{qid}/lessons/index.json
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/{qid}/lessons/{lid}/index.json
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/{qid}/lessons/{lid}/days/{did}/read/index.json
```

> **Note:** All API endpoints require `/index.json` suffix — without it the server returns HTML (SPA) instead of JSON.

Data is pre-downloaded and bundled in `Resources/data/` for offline use. If local data is missing, the app fetches from the API via TLS 1.2 (libcurl + OpenSSL).

### Data structure
```
data/{lang}/quarterlies.json                         — list of quarterlies
data/{lang}/{quarter}/lessons.json                   — lessons in a quarter
data/{lang}/{quarter}/{lesson}/index.json            — lesson detail with days
data/{lang}/{quarter}/{lesson}/{day}.json            — day content with Bible verses
```

## Prerequisites

| Tool | Purpose | Location |
|------|---------|----------|
| **WSL** (Windows Subsystem for Linux) | Build environment | Windows feature |
| **Theos** | iOS build system | `~/theos` in WSL |
| **Clang 11.1** cross-compiler | Compiles for armv7 | `~/theos/toolchain/linux/iphone/bin/clang` |
| **iPhoneOS 9.3 SDK** | iOS headers & libs | `~/theos/sdks/iPhoneOS9.3.sdk` |
| **ldid** | Ad-hoc code signing | On iPad via Cydia |
| **Python 3** | For downloading lesson data | WSL or Windows |
| **Jailbroken iPad 1G** | Target device, SSH enabled | Same Wi-Fi, IP `192.168.1.128` |

### iPad setup (one-time via Cydia)
- OpenSSH (for SSH/SCP access)
- `ldid` (for code signing)
- Default SSH: `root` / `alpine`

## Build

> **Important:** NTFS gives 777 permissions which breaks dpkg. Always copy to native Linux filesystem (`/tmp/`) first.
>
> **Important:** WSL `/tmp/` is volatile — files disappear between sessions. The SSH password helper must be recreated each session.

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

The pre-built `lib/libssl.a`, `lib/libcrypto.a`, and `lib/libcurl.a` are included in the repo. You do NOT need to rebuild them for normal app development. Only rebuild if you need to update OpenSSL/curl versions.

### Why custom TLS?

iPad 1G (iOS 5.1.1) only supports TLS 1.0 natively via `NSURLConnection`/SecureTransport. Modern servers require TLS 1.2+. We statically link OpenSSL + libcurl to bypass the OS limitation.

### OpenSSL 1.1.1w

```bash
wsl bash -lc "bash /mnt/c/Source/ss_ios/build_openssl.sh"
```

**What it does:**
1. Downloads OpenSSL 1.1.1w source to `~/openssl-build/`
2. Configures with `linux-generic32` target (NOT `ios-cross` — that one breaks with our clang)
3. Sets CC to Theos clang: `-target arm-apple-darwin11 -arch armv7 -isysroot iPhoneOS9.3.sdk`
4. **Must generate headers first** — `make include/openssl/opensslconf.h` (perl-based, fails silently if skipped)
5. Builds `libcrypto.a` (~2.7M) and `libssl.a` (~573K)
6. Copies `.a` files to `lib/` and headers to `include/openssl/`

**Key configure flags:** `no-shared no-dso no-engine no-tests no-asm no-async -DOPENSSL_NO_SECURE_MEMORY`

**Known issues:**
- `ar rcs` flag causes `ranlib: error: Invalid option: '-f'` — use `llvm-ar` or `ar rc` + separate `ranlib`
- Must create `cc` symlink: `ln -sf $TOOLCHAIN/clang $TOOLCHAIN/cc`
- Warnings about "no symbols" in some `.o` files are normal (platform-specific stubs)

### libcurl 7.88.1

```bash
wsl bash -lc "bash /mnt/c/Source/ss_ios/build_curl.sh"
```

**What it does:**
1. Downloads curl 7.88.1 source to `~/curl-build/`
2. **Creates a manual `curl_config.h`** — autotools `./configure` cannot cross-compile (fails at "checking whether we are cross compiling" and can't detect OpenSSL via link test)
3. Compiles all `.c` files in `lib/`, `lib/vtls/`, `lib/vauth/` individually with Theos clang
4. Creates `libcurl.a` (~487K) with `llvm-ar` (standard `ar` has ranlib flag issues)
5. Copies `.a` to `lib/` and headers to `include/curl/`

**Key defines in curl_config.h:**
- `USE_OPENSSL 1` — enables OpenSSL backend
- `HAVE_STDBOOL_H 1` — **required**, without it `bool` type is undefined and nothing compiles
- `CURL_DISABLE_SMB/FTP/FILE/...` — disables unused protocols (SMB missing symbol caused crash!)

**Disabled protocols:** LDAP, DICT, TELNET, TFTP, POP3, IMAP, SMTP, GOPHER, MQTT, RTSP, SMB, FTP, FILE

**Skip list** (files not compiled): `curl_ntlm_core`, `curl_ntlm_wb`, `openldap`, `ldap`, `telnet`, `dict`, `tftp`, `imap`, `pop3`, `smtp`, `gopher`, `mqtt`, `rtsp`, `pingpong`, `bufq`, `bufref`

### Makefile integration

```makefile
SabbathSchool_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Iinclude
SabbathSchool_LDFLAGS = -Wl,-undefined,dynamic_lookup -Wl,-flat_namespace -Llib -lcurl -lssl -lcrypto -lz
SabbathSchool_FRAMEWORKS = UIKit Foundation CoreGraphics Security
```

Link order matters: `-lcurl` before `-lssl` before `-lcrypto`, then `-lz` (system zlib).

### How TLS is used in the app

1. `SSHTTPClient` wraps libcurl C API — single static method `+[SSHTTPClient fetchURL:]`
2. `curl_global_init(CURL_GLOBAL_SSL)` runs once at class load via `+initialize`
3. SSL verification is disabled (`CURLOPT_SSL_VERIFYPEER = 0`) because iOS 5 has no CA bundle accessible to the app
4. `SSAPIClient` tries local bundle first, falls back to `SSHTTPClient` in background thread if file not found
5. API URLs require `/index.json` suffix (e.g. `.../quarterlies/index.json`)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| **No route to host** | iPad is sleeping or not on Wi-Fi. Wake it up |
| **Connection refused** | OpenSSH not running on iPad. Reboot iPad |
| **Permission denied (SSH)** | SSH password helper expired. Recreate `/tmp/sshpw.sh` (see Deploy) |
| **DEBIAN permissions error** | Building on NTFS. Copy to `/tmp/` first (see Build) |
| **lib*.a: no table of contents** | Run `ranlib` on .a files before building (see Build) |
| **Symbol not found: _Curl_handler_*` | Missing `CURL_DISABLE_*` in `curl_config.h`. Add the define and rebuild curl |
| **unknown type name 'bool'** | Missing `HAVE_STDBOOL_H` in `curl_config.h` |
| **opensslconf.h not found** | Run `make include/openssl/opensslconf.h` in OpenSSL source dir before building |
| **White screen on launch** | Data files missing in `Resources/data/`. Run `download_days.py` |
| **App crashes on launch** | Check crash log: `ssh root@iPad "cat /var/mobile/Library/Logs/CrashReporter/LatestCrash-SabbathSchool.plist"` — look for "Symbol not found" |
| **ar: Invalid option '-f'** | Use `llvm-ar` instead of `ar` in build scripts |

## Tech Stack

- **Language:** Objective-C (ARC)
- **UI:** UIKit + UIWebView (HTML/CSS/JS for lesson content)
- **Build:** Theos, targeting armv7 / iOS 5.0+
- **TLS:** OpenSSL 1.1.1w + libcurl 7.88.1 (static, for TLS 1.2 on iOS 5)
- **Signing:** `ldid -S` (ad-hoc, jailbroken only)
- **Package:** `.deb` via `dpkg`

## License

This project uses lesson data from [Adventech](https://github.com/Adventech) (open API).
