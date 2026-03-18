# Deploy to iPad 1G

## Build (WSL)
```
export THEOS=~/theos
cd ~/ss_ios
make clean && make package
```

## Copy to iPad (WSL)
```
scp -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa ~/ss_ios/packages/*.deb root@192.168.1.128:/tmp/ss.deb
```
Password: alpine

## Install (SSH to iPad)
```
ssh -o HostKeyAlgorithms=+ssh-rsa,ssh-dss -o PubkeyAcceptedAlgorithms=+ssh-rsa root@192.168.1.128
```
Password: alpine

Then run one by one:
```
dpkg -i /tmp/ss.deb
```
```
ldid -S /Applications/SabbathSchool.app/SabbathSchool
```
```
/Applications/SabbathSchool.app/SabbathSchool
```

## Update data
```
python3 download_days.py
```
Then rebuild and redeploy.
