# Deploy to iPad 1G

iPad 1G (iOS 5.1.1), jailbroken, SSH enabled.

- Host: `192.168.1.128`
- User: `root`
- Password: `alpine`

## Prerequisites

- WSL with Theos installed at `~/theos`
- iPad on the same Wi-Fi network, awake (not sleeping)
- **All commands below run via WSL** (`wsl bash -lc '...'`), not native Windows

## Build

NTFS gives 777 permissions which breaks dpkg. Must copy to native Linux fs first:

```bash
wsl bash -lc 'rm -rf /tmp/ss_build && cp -r /mnt/c/Source/ss_ios /tmp/ss_build && cd /tmp/ss_build && chmod 0755 layout/DEBIAN && rm -rf packages && export THEOS=~/theos && make clean && make package'
```

The .deb appears in `/tmp/ss_build/packages/`.

## Deploy

### 1. Create SSH_ASKPASS helper (once per WSL session)

```bash
wsl bash -lc 'cat > /tmp/sshpw.sh << "SEOF"
#!/bin/bash
echo alpine
SEOF
chmod +x /tmp/sshpw.sh'
```

### 2. Copy .deb to iPad

```bash
wsl bash -lc 'DEB=$(ls -t /tmp/ss_build/packages/*.deb | head -1) && cp "$DEB" /tmp/ss.deb && export SSH_ASKPASS=/tmp/sshpw.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 && scp -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa /tmp/ss.deb root@192.168.1.128:/tmp/ss.deb'
```

### 3. Remove old, install new, sign, respring

```bash
wsl bash -lc 'export SSH_ASKPASS=/tmp/sshpw.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 && ssh -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa root@192.168.1.128 "killall SabbathSchool 2>/dev/null; dpkg -r com.adventist.sabbathschool; dpkg -i /tmp/ss.deb; ldid -S /Applications/SabbathSchool.app/SabbathSchool; killall SpringBoard"'
```

## Notes

- Old iPad SSH requires legacy algorithms: `HostKeyAlgorithms=+ssh-rsa,ssh-dss`, `PubkeyAcceptedAlgorithms=+ssh-rsa`
- `SSH_ASKPASS` with `DISPLAY=:0` avoids interactive password prompts
- `rm -rf packages` before build ensures only one .deb exists

## Update lesson data
```bash
python3 download_days.py
```
Then rebuild and redeploy.

## Troubleshooting

- **No route to host** — iPad is sleeping or not on Wi-Fi. Wake it up.
- **Connection refused** — OpenSSH not running on iPad. Reboot iPad.
- **DEBIAN permissions error** — building on NTFS. Copy to `/tmp/` first (see Build section).
