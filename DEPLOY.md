# Deploy to iPad 1G

iPad 1G (iOS 5.1.1), jailbroken, SSH enabled.

- Host: `192.168.1.128`
- User: `root`
- Password: `alpine`

## Prerequisites

- WSL with Theos installed at `~/theos`
- iPad on the same Wi-Fi network, awake (not sleeping)

## Build

NTFS gives 777 permissions which breaks dpkg. Must copy to native Linux fs first:

```bash
rm -rf /tmp/ss_build && cp -r /mnt/c/Source/ss_ios /tmp/ss_build
cd /tmp/ss_build && chmod 0755 layout/DEBIAN
export THEOS=~/theos && make clean && make package
```

## Deploy

SSH_ASKPASS trick for non-interactive password:

```bash
cat > /tmp/sshpw.sh << 'EOF'
#!/bin/bash
echo alpine
EOF
chmod +x /tmp/sshpw.sh
export SSH_ASKPASS=/tmp/sshpw.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0

SSH_OPTS="-o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa"
IPAD="root@192.168.1.128"
```

### Full sequence
```bash
# Copy deb to iPad
cp /tmp/ss_build/packages/*.deb /tmp/ss.deb
scp $SSH_OPTS /tmp/ss.deb $IPAD:/tmp/ss.deb

# Kill app, remove old, install new, sign, respring
ssh $SSH_OPTS $IPAD "killall SabbathSchool 2>/dev/null; dpkg -r com.adventist.sabbathschool; dpkg -i /tmp/ss.deb; ldid -S /Applications/SabbathSchool.app/SabbathSchool; killall SpringBoard"
```

## Update lesson data
```bash
python3 download_days.py
```
Then rebuild and redeploy.

## Troubleshooting

- **No route to host** — iPad is sleeping or not on Wi-Fi. Wake it up.
- **Connection refused** — OpenSSH not running on iPad. Reboot iPad.
- **DEBIAN permissions error** — building on NTFS. Copy to `/tmp/` first (see Build section).
