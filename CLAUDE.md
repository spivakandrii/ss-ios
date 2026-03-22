# Sabbath School iOS — Claude Instructions

## What is this
Offline Sabbath School lesson reader for **iPad 1st gen, iOS 5.1.1, jailbroken**. Built with Theos (Objective-C, UIKit, UIWebView). All lesson data from Adventech API, bundled offline + TLS 1.2 network fallback via statically linked OpenSSL + libcurl.

## Build & Deploy (always do this flow)

Everything runs through **WSL bash**, never Windows cmd.

### 1. Build
```bash
wsl bash -lc '
  rm -rf /tmp/ss_build && cp -r /mnt/c/Source/ss_ios /tmp/ss_build && cd /tmp/ss_build &&
  chmod 0755 layout/DEBIAN &&
  ~/theos/toolchain/linux/iphone/bin/ranlib lib/libcurl.a lib/libssl.a lib/libcrypto.a 2>/dev/null;
  export THEOS=~/theos && make clean 2>&1 && make package 2>&1
'
```
**Why /tmp?** NTFS gives 777 permissions → dpkg fails. Must copy to native Linux fs.

### 2. SSH password helper (recreate if /tmp was cleared)
```bash
wsl bash -lc 'echo "#!/bin/bash" > ~/sshpw.sh && echo "echo alpine" >> ~/sshpw.sh && chmod +x ~/sshpw.sh'
```
Use `~/sshpw.sh` (home dir), NOT `/tmp/sshpw.sh` — /tmp is volatile in WSL.

### 3. Deploy (remove old → copy → install → sign → respring)
```bash
wsl bash -lc '
  export SSH_ASKPASS=~/sshpw.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0
  DEB=$(ls -t /tmp/ss_build/packages/*.deb | head -1) && cp "$DEB" /tmp/ss.deb &&
  SSH="ssh -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa" &&
  scp -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa /tmp/ss.deb root@192.168.1.128:/tmp/ss.deb &&
  $SSH root@192.168.1.128 "killall SabbathSchool 2>/dev/null; dpkg -r com.adventist.sabbathschool; dpkg -i /tmp/ss.deb; ldid -S /Applications/SabbathSchool.app/SabbathSchool; killall SpringBoard"
'
```

**iPad SSH:** `root@192.168.1.128`, password `alpine`. Old iPad needs `-o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa`.

## Key constraints (iOS 5.1.1 / iPad 1G)
- **No TLS 1.2** natively — we use statically linked OpenSSL 1.1.1w + libcurl 7.88.1
- **UIWebView only** — no WKWebView
- **No localStorage** in UIWebView with loadHTMLString — use NSUserDefaults via URL scheme callbacks from JS
- **No modern ObjC** — use `[NSArray arrayWithObjects:..., nil]` not `@[...]` literals sometimes
- **256MB RAM** — keep UI simple, avoid large allocations
- `position:fixed` + `overflow-y:scroll` works poorly — use `-webkit-overflow-scrolling:touch`

## API endpoints (all need /index.json suffix!)
```
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/index.json
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/{qid}/lessons/index.json
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/{qid}/lessons/{lid}/index.json
https://sabbath-school.adventech.io/api/v2/{lang}/quarterlies/{qid}/lessons/{lid}/days/{did}/read/index.json
https://sabbath-school.adventech.io/api/v2/languages/index.json
```
Without `/index.json` the server returns HTML (SPA) instead of JSON!

## Caching strategy
1. Check Documents cache first (previously downloaded data)
2. If cache exists → show immediately, fetch fresh in background silently
3. If no cache → show spinner, fetch from API
4. Save fetched data to Documents for next time
5. Bundle data (Resources/data/) is last fallback

## Architecture
- `SSAPIClient` — data loading with cache → bundle → API fallback
- `SSHTTPClient` — libcurl wrapper for TLS 1.2 HTTPS
- `SSReadVC` — main reader (UIWebView + HTML/CSS/JS)
- `SSLanguageVC` — language picker (uk/ro/en + 91 from API)
- `SSQuarterliesVC` / `SSLessonsVC` — table view controllers
- Themes: light / dark / sepia — stored as `theme` string in NSUserDefaults

## User preferences
- User speaks Ukrainian, communicates in Ukrainian
- Deploy flow: always build → remove old → scp → install → sign → respring (all steps, every time)
- Keep it simple, no over-engineering
- Test on device before committing
