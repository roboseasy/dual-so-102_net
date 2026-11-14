# dualso102_net

Dual SO-102(양팔 로봇) 팔로워 Pi(Raspberry Pi, Ubuntu 24.04)의 **와이파이를 바꾸는 스크립트 모음**이다.
로봇은 두 가지 방식으로 네트워크에 붙는다. 이 폴더의 스크립트가 둘 사이를 오가고, 각 모드의 설정을 고친다.

- **AP 모드** — 로봇이 직접 와이파이를 띄운다. PC를 그 와이파이에 붙여서 `ssh <사용자>@192.168.4.1`로 들어간다.
- **공유기 모드** — 로봇이 집·사무실 공유기에 붙는다. 공유기가 안 보이면 자동으로 AP가 뜬다.

NetworkManager(`nmcli`) 프로필 2개(`dualso102-ap`, `home-wifi`)로 동작한다. `hostapd`·`dnsmasq` 서비스는 쓰지 않는다.
로봇의 `~/dualso102_net`에 두고 쓴다 (**이 경로 그대로** — 앱과 `.bashrc`가 이 경로를 부른다).
유선(`eth0`)은 어떤 스크립트도 건드리지 않는다. 와이파이가 꼬이면 랜선으로 들어와 고친다.

> **원본은 [roboseasy/lekiwi_net](https://github.com/roboseasy/lekiwi_net)** (커밋 `49886a3`)이다. 이름만 바꿔 가져왔다 — [9장](#9-원본lekiwi_net과-맞추기).

**목차**

1. [파일 한눈에](#1-파일-한눈에)
2. [짧은 명령 (.bashrc)](#2-짧은-명령-bashrc)
3. [자주 하는 일](#3-자주-하는-일)
4. [새 Pi에 처음 넣기 (이관)](#4-새-pi에-처음-넣기-이관)
5. [어떻게 안전하게 바꾸나](#5-어떻게-안전하게-바꾸나)
6. [앱이 읽는 출력 줄](#6-앱이-읽는-출력-줄)
7. [환경 변수](#7-환경-변수)
8. [알아둘 점](#8-알아둘-점)
9. [원본(lekiwi_net)과 맞추기](#9-원본lekiwi_net과-맞추기)
10. [시험](#10-시험)

---

## 1. 파일 한눈에

| 파일 | 하는 일 |
|---|---|
| `run_ap.sh` | wlan0를 **AP 모드**로. 재부팅해도 유지. 로봇 IP `192.168.4.1` |
| `run_wifi.sh` | wlan0를 **공유기 모드**로. 인자 없이 = 저장된 공유기로 연결, `SSID PASSWORD` = 새 공유기 저장(DHCP) 후 연결. 연결 실패 시 AP로 복귀 |
| `set_ap.sh` | AP 이름 · 비밀번호 변경. 인자 없이 = 현재 AP 이름 보기 |
| `set_ip.sh` | 공유기 모드의 **고정 IP** 설정: `192.168.0.(200 + 킷 번호)`. 인자 없이 = 현재 설정 보기 |
| `set_dhcp.sh` | 공유기 모드를 **DHCP**로 되돌린다 |
| `_apply_home_ipv4.sh` | `set_ip.sh` · `set_dhcp.sh`가 같이 쓰는 내부 스크립트. 직접 부르지 않는다 |
| `wifi_list.sh` | 주변 와이파이 목록 (SSID · 신호 · 대역 · 보안). `iw`로 스캔하므로 NetworkManager와 무관 |
| `net_status.sh` | 지금 켜진 연결과 IPv4 주소 보기 |
| `nm_kf.py` | NetworkManager 설정 파일(keyfile) 편집기. 위 스크립트가 `nmcli con modify` 대신 쓴다 |
| `bashrc_net.sh` | `.bashrc`에 넣는 짧은 명령 블록 (2장) |
| `setup_ap_mode.sh` | **새 Pi에 처음 넣을 때 실행하는 것** (4장). 아래 `provision_ap_mode.sh`를 감싼다 |
| `provision_ap_mode.sh` · `rollback_ap_mode.sh` | netplan 세대 카드를 이 방식으로 한 번 옮기기 · 되돌리기 (4장) |

원본에 있지만 가져오지 않은 것: `clone_init.sh`(카드 복제 후 초기화 — 호스트 이름 `lekiwiNN` 규칙), `image_ready_check.sh`(양산 이미지 직전 점검).
Dual SO-102 양산 이미지를 뜰 때 원본에서 가져와 이 로봇의 호스트 이름 규칙에 맞춘다.

---

## 2. 짧은 명령 (.bashrc)

`setup_ap_mode.sh`가 `.bashrc` 끝에 `bashrc_net.sh` 블록을 한 번 붙인다 (`# >>> dualso102_net >>>` 표지로 중복을 막는다).

| 짧은 명령 | 실제로 부르는 것 |
|---|---|
| `run_ap` | `~/dualso102_net/run_ap.sh` |
| `run_wifi [SSID PASSWORD]` / `wifi [SSID PASSWORD]` | `~/dualso102_net/run_wifi.sh` |
| `wifi list [인터페이스]` | `~/dualso102_net/wifi_list.sh` |
| `set_ap [SSID PASSWORD]` | `~/dualso102_net/set_ap.sh` |
| `setip [킷번호]` | `~/dualso102_net/set_ip.sh` |
| `setdhcp` / `set_dhcp` | `~/dualso102_net/set_dhcp.sh` |
| `net_status` | `~/dualso102_net/net_status.sh` |

`.bashrc`에 넣지 않았다면 `~/dualso102_net/run_wifi.sh ...`처럼 경로로 부른다.

---

## 3. 자주 하는 일

```bash
net_status                     # 지금 어떻게 붙어 있나

run_ap                         # AP 모드로 (재부팅해도 AP)
# [run_ap] AP 모드 ON -> PC 를 '<AP 이름>' 에 연결 후: ssh <사용자>@192.168.4.1

wifi list                      # 주변 와이파이 확인
run_wifi MyRouter MyPassword   # 공유기 모드: 처음 한 번 저장 + 연결 (DHCP)
run_wifi                       # 이후: 저장된 공유기로 연결

setip                          # 공유기 모드의 IP 설정 보기
setip 3                        # 192.168.0.203 으로 고정 (킷 번호 1~54)
setdhcp                        # 공유기가 주는 주소를 받는다

set_ap                         # 현재 AP 이름 보기
set_ap MyDualArm MyPassword    # AP 이름(1~32바이트) · 비밀번호(8~63자) 변경
```

- **처음 AP는 이름 · 비밀번호 모두 `dualso102`** 이다 (LeKiwi의 `lekiwi01`과 같은 정책: 모든 로봇이 같고 받은 사람이 `set_ap`로 바꾼다).
- 공유기 비밀번호는 8~63자 (WPA2). SSID · 비밀번호 앞뒤에 공백을 둘 수 없다.
- 새 공유기를 저장하면 **고정 IP 설정은 DHCP로 초기화**된다. 고정 IP가 필요하면 이어서 `setip N`.
- 공유기 연결에 실패하면 자동으로 AP 모드로 돌아와서, 로봇에 닿을 길이 끊기지 않는다.
- AP가 켜져 있을 때 `set_ap`로 바꾸면 바로 다시 올라오므로 PC를 새 이름으로 다시 연결해야 한다.

---

## 4. 새 Pi에 처음 넣기 (이관)

netplan + wpa_supplicant로 와이파이를 쓰던 Pi(이 로봇의 처음 이미지)를 한 번 옮긴다. **랜선으로 PC에 붙은 상태에서만** 한다.

```bash
# PC에서: 이 저장소를 로봇의 스테이징 폴더로 (~/dualso102_net 이 아닌 곳 — 스크립트를 그 폴더에 설치하기 때문)
rsync -a --exclude .git --exclude tests --exclude __pycache__ ./ roboseasy@<유선 IP>:dualso102_net_staging/

# 로봇에서 (유선 ssh)
sudo ~/dualso102_net_staging/setup_ap_mode.sh --dry-run --mode ap --dhcp      # 사전 점검만 (아무것도 안 바꾼다)
sudo setsid nohup ~/dualso102_net_staging/setup_ap_mode.sh > ~/ap_setup.log 2>&1 &   # 기본: --mode ap --dhcp --hold-nm
tail -f ~/ap_setup.log                                                        # 마지막 줄 "[setup] 끝 rc=0" 을 기다린다

# 끝난 뒤 180초 안에: 유선 ssh가 살아 있고 AP가 떴으면 되돌림 타이머를 멈춘다 (안 멈추면 자동으로 원래대로 돌아간다)
nmcli -t -f NAME,DEVICE,STATE con show --active      # dualso102-ap:wlan0:activated
sudo systemctl stop dualso102-net-rollback.timer
```

`setup_ap_mode.sh`가 하는 일:

1. 설치하는 동안만 `noble-updates`를 `network-manager` · `libnm0` · `dnsmasq-base`에 한해 연다.
   이 Pi 이미지의 apt 소스에는 `noble-updates`가 없어 그냥 깔면 출시판(1.46.0-1ubuntu2)이 깔린다. 기준 구현(LeKiwi `lekiwi05`)은
   `network-manager 1.46.0-1ubuntu2.8` · `dnsmasq-base 2.91`이다 (출시판과는 방화벽 백엔드 · 자동 재연결 수정이 다르다). 끝나면 닫고 목록을 되돌린다.
2. `provision_ap_mode.sh` (인자 그대로): 백업 → NetworkManager 설치 → 스크립트 · 설정 설치 → 프로필 2개 → **되돌림 타이머 180초** →
   netplan의 `wifis` 삭제 → wlan0을 NetworkManager로 → `run_ap.sh` 또는 `run_wifi.sh` → 옛 도구(`set_wifi.sh`) 막기 → 확인.
3. cloud-init이 네트워크 설정을 다시 쓰지 않게 `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`.

| 인자 | 뜻 |
|---|---|
| `--mode ap` / `--mode wifi` | AP 고정 / 공유기 우선(못 붙으면 AP). 공유기가 근처에 없으면 `--mode wifi`는 실패해 되돌려진다 |
| `--dhcp` / `--kit N` | 공유기 모드에서 DHCP / 고정 `192.168.0.(200+N)` |
| `--ap-ssid NAME` | 처음 AP 이름이자 비밀번호 (기본 `dualso102`, 8~32자 ASCII) |
| `--hold-nm` | `apt-mark hold network-manager` (판이 올라가 동작이 바뀌는 것을 막는다) |
| `--dry-run` | 사전 점검과 할 일 목록만 |

종료 코드: `0` 성공 · 이미 적용됨 / `3` 사전 점검 거절 (안 바뀜) / `4` 바꾼 뒤 실패 (롤백함) / `5` 롤백도 다 되지 않음 (유선으로 들어와 고친다).

되돌리기와 백업:

- **자동 롤백:** 바꾸기 전에 `/var/backups/dualso102_net_<날짜시각>.tar.gz`(root 600, **공유기 비밀번호가 들어 있다**)를 만들고
  180초 뒤 롤백 타이머(`dualso102-net-rollback`)를 건다. 접속을 확인했으면 `sudo systemctl stop dualso102-net-rollback.timer`.
- **손으로 되돌리기:** `sudo ~/dualso102_net_staging/rollback_ap_mode.sh [백업 tar]` — wlan0은 다시 netplan + wpa_supplicant, NetworkManager는 꺼 둔다.
- **백업 파일은 로봇에 남기지 않는다.** 확인이 다 끝나면 PC로 옮겨 sha256을 맞춘 뒤 로봇에서 `sudo shred -u`로 지운다.

---

## 5. 어떻게 안전하게 바꾸나

**`nmcli con modify` · `nmcli con add` · `nmcli dev wifi hotspot`을 쓰지 않는다.** Ubuntu 24.04의 NetworkManager는 netplan 연동 패치 때문에
수정한 프로필을 `/etc/netplan/90-NM-*.yaml`로 옮겨 써서 설정이 사라지거나 두 벌이 된다.
`nm_kf.py`로 keyfile(`/etc/NetworkManager/system-connections/*.nmconnection`)을 직접 고치고 `nmcli con load`로 읽힌다.

```bash
nm_kf.py get NAME SECTION KEY
nm_kf.py set NAME SECTION KEY VALUE [SECTION KEY VALUE ...]
nm_kf.py del NAME SECTION KEY [KEY ...]
```

파일은 임시 파일에 쓴 뒤 권한 `600`으로 교체한다 (쓰다 끊겨도 반쪽 파일이 남지 않는다).

**모드 = `home-wifi`의 `autoconnect` 값.** `true`면 "공유기 우선, 안 보이면 AP", `false`면 "AP 고정". 그래서 재부팅해도 모드가 유지된다.

원격으로 바꾸다 접속이 끊기지 않도록, 실패하면 이전 상태로 되돌린다.

| 스크립트 | 실패했을 때 |
|---|---|
| `run_wifi.sh` | 공유기 연결 실패 → AP 모드로 복귀 |
| `_apply_home_ipv4.sh` (`setip` · `setdhcp`) | 적용한 IP가 안 잡힘 → 이전 설정 복구 → 복구도 실패하면 AP로 전환 |
| `run_ap.sh` | AP 전환 실패 → 공유기 자동 연결 설정을 원래 값으로 되돌리고, 공유기 우선 모드였으면 공유기로 복귀 |

---

## 6. 앱이 읽는 출력 줄

Physical Labs 앱이 `run_wifi.sh` · `set_ip.sh` · `set_dhcp.sh`의 출력을 읽어 결과를 판단한다. **아래 줄의 모양을 바꾸면 앱이 깨진다.**

| 줄 | 의미 |
|---|---|
| `inet <IP>/<prefix> ...` (`ip -4 -o addr show wlan0` 출력) | 연결 성공. 앱이 IP를 여기서 읽는다 |
| `error: ...` | 실패. 앱이 읽는 줄 |

`wifi_list.sh`의 신호 임계값(-55 / -67 / -78 dBm)은 앱이 이 스크립트와 같게 쓴다.

---

## 7. 환경 변수

시험용이다. 평소에는 설정하지 않는다.

| 변수 | 기본값 | 용도 |
|---|---|---|
| `NM_KF_DIR` | `/etc/NetworkManager/system-connections` | keyfile 폴더 |
| `DUALSO102_NET_STATE_DIR` | `/var/lib/dualso102-net` | 이전 설정 사본을 잠깐 두는 폴더 |
| `PROVISION_ROOT` · `PROVISION_USER` · `PROVISION_HOME` | (없음) | 이관 스크립트의 모든 절대 경로 앞에 붙는 가짜 루트 등. **root로는 쓰지 않는다** |

---

## 8. 알아둘 점

- AP 주소는 `192.168.4.1/24`, 채널 6(2.4 GHz), DHCP `192.168.4.10~254`(NetworkManager가 띄우는 `dnsmasq`). 5 GHz AP는 쓰지 않는다.
- 라즈베리파이 내장 무선은 AP와 공유기 연결을 한 채널에서만 같이 쓸 수 있어 **둘 중 하나만** 켠다.
- **공유기 대역은 `192.168.0.0/24`, 게이트웨이는 `192.168.0.1`로 가정**한다 (`_apply_home_ipv4.sh`에 고정). 다른 대역에서는 `setdhcp`를 쓴다.
- 이미 켜진 AP는 공유기가 다시 보여도 스스로 내려가지 않는다. `run_wifi` 또는 재부팅.
- AP에 붙은 기기는 로봇의 유선(eth0) 쪽으로도 나갈 수 있다 (NetworkManager `shared` 모드의 NAT). 처음 비밀번호가 공개값이므로 받은 뒤 `set_ap`로 바꾼다.
- 대부분 `sudo`가 필요하다 (스크립트 안에서 부르므로 따로 붙일 필요는 없다). 앱은 `sudo -n`으로 부른다.

---

## 9. 원본(lekiwi_net)과 맞추기

원본이 바뀌면 같은 규칙으로 다시 가져온다 (파일별로 `sed` 한 줄, 순서가 중요하다).

```bash
sed -e 's/lekiwi7/dualso7/g' -e 's/lekiwi01/dualso102/g' -e 's/LEKIWI/DUALSO102/g' \
    -e 's/MyLeKiwi/MyDualArm/g' -e 's/LeKiwi/Dual SO-102/g' -e 's/lekiwi/dualso102/g'
```

| 원본 | 여기 |
|---|---|
| 폴더 `~/lekiwi_net`, 프로필 `lekiwi-ap` | `~/dualso102_net`, `dualso102-ap` |
| 상태 폴더 `/var/lib/lekiwi-net`, 표지 `/etc/lekiwi-net-provisioned` | `/var/lib/dualso102-net`, `/etc/dualso102-net-provisioned` |
| 백업 `/var/backups/lekiwi_net_*.tar.gz`, 타이머 `lekiwi-net-rollback` | `/var/backups/dualso102_net_*.tar.gz`, `dualso102-net-rollback` |
| 처음 AP `lekiwi01` | `dualso102` |

이 저장소에만 있는 것: `setup_ap_mode.sh`, `tests/test_setup.py`, 이 README. 원본에서 가져온 파일은 손으로 고치지 않는다 (고칠 일이 있으면 원본에서).

---

## 10. 시험

PC에서 돌린다. 이 PC의 네트워크와 `/etc`는 건드리지 않는다 — 가짜 `PATH`의 stub과 임시 폴더에서만 돈다.

```bash
python3 -m pytest -q   # pytest 가 든 파이썬. libnm 시험 하나는 python3-gi 가 있어야 돈다 (없으면 건너뜀)
```
