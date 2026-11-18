# dualso102_net

Dual SO-102(양팔 로봇) 팔로워 Pi(Raspberry Pi, Ubuntu 24.04)의 **와이파이를 바꾸는 스크립트 모음**이다.
로봇은 두 가지 방식으로 네트워크에 붙는다. 이 폴더의 스크립트가 둘 사이를 오가고, 각 모드의 설정을 고친다.

- **AP 모드** — 로봇이 직접 와이파이를 띄운다. PC를 그 와이파이에 붙여서 `ssh <사용자>@192.168.4.1`로 들어간다.
- **공유기 모드** — 로봇이 집·사무실 공유기에 붙는다. 공유기가 안 보이면 자동으로 AP가 뜬다.

NetworkManager(`nmcli`)를 쓰는 카드용이다. 로봇의 `~/dualso102_net`에 두고 쓴다 (**이 경로 그대로** — 앱과 `.bashrc`가 이 경로를 부른다).

> **LeKiwi의 [roboseasy/lekiwi_net](https://github.com/roboseasy/lekiwi_net)과 같은 스크립트다.** 대부분의 파일을 `sync_from_lekiwi.sh`가 이름만 바꿔 만든다.
> 쓰는 법도 LeKiwi와 같다. 다른 점은 이름 · 고정 IP 범위뿐이다 ([10장](#10-원본lekiwi_net과-맞추기)).

**목차**

1. [파일 한눈에](#1-파일-한눈에)
2. [짧은 명령 (.bashrc)](#2-짧은-명령-bashrc)
3. [자주 하는 일](#3-자주-하는-일)
4. [새 카드 복제 후 초기화](#4-새-카드-복제-후-초기화)
5. [어떻게 안전하게 바꾸나](#5-어떻게-안전하게-바꾸나)
6. [앱이 기대하는 것](#6-앱이-기대하는-것)
7. [환경 변수](#7-환경-변수)
8. [알아둘 점](#8-알아둘-점)
9. [관련 저장소](#9-관련-저장소)
10. [원본(lekiwi_net)과 맞추기](#10-원본lekiwi_net과-맞추기)
11. [이관 · 점검 도구와 시험](#11-이관--점검-도구와-시험)
12. [설치 기록](#12-설치-기록)

---

## 1. 파일 한눈에

| 파일 | 하는 일 |
|---|---|
| `run_ap.sh` | wlan0를 **AP 모드**로. 재부팅해도 유지. 로봇 IP `192.168.4.1` |
| `run_wifi.sh` | wlan0를 **공유기 모드**로. 인자 없이 = 저장된 공유기로 연결, `SSID PASSWORD` = 새 공유기 저장(DHCP) 후 연결. 연결 실패 시 AP로 복귀 |
| `set_ap.sh` | AP 이름 · 비밀번호 변경. 인자 없이 = 현재 AP 이름 보기 |
| `set_ip.sh` | 공유기 모드의 **고정 IP** 설정: `192.168.0.(100 + 킷 번호)`. 인자 없이 = 현재 설정 보기 |
| `set_dhcp.sh` | 공유기 모드를 **DHCP**로 되돌린다 |
| `_apply_home_ipv4.sh` | `set_ip.sh` · `set_dhcp.sh`가 같이 쓰는 내부 스크립트. 직접 부르지 않는다 |
| `wifi_list.sh` | 주변 와이파이 목록 (SSID · 신호 · 대역 · 보안). `iw`로 스캔하므로 NetworkManager와 무관 |
| `net_status.sh` | 지금 켜진 연결과 IPv4 주소 보기 |
| `clone_init.sh` | 복제한 카드마다 **한 번**: 호스트 이름 · 킷 번호 · AP 채널 · 공유기 고정 IP 설정 (4장) |
| `nm_kf.py` | NetworkManager 설정 파일(keyfile) 편집기. 위 스크립트가 `nmcli con modify` 대신 쓴다 |
| `bashrc_net.sh` | `.bashrc`에 넣는 짧은 명령 블록 (2장) |
| `image_ready_check.sh` | 이미지를 뜨기 직전 골든 카드 점검 (읽기만, 11장) |
| `setup_ap_mode.sh` | **netplan 세대 Pi에 처음 넣을 때 실행하는 것** (11장). 아래 `provision_ap_mode.sh`를 감싼다. 이 저장소에만 있다 |
| `provision_ap_mode.sh` · `rollback_ap_mode.sh` | netplan 세대 카드를 이 방식으로 한 번 옮기기 · 되돌리기 (11장) |
| `sync_from_lekiwi.sh` · `LEKIWI_NET_SYNCED` | PC에서 lekiwi_net으로부터 위 파일들을 다시 만든다 · 마지막으로 맞춘 원본 커밋 (10장) |

---

## 2. 짧은 명령 (.bashrc)

이미지에는 `.bashrc`에 짧은 이름이 들어 있다 (정의는 이 저장소의 `bashrc_net.sh`).
이 문서와 스크립트 주석의 명령 이름은 아래 표를 따른다.

| 짧은 명령 | 실제로 부르는 것 |
|---|---|
| `run_ap` | `~/dualso102_net/run_ap.sh` |
| `run_wifi [SSID PASSWORD]` / `wifi [SSID PASSWORD]` | `~/dualso102_net/run_wifi.sh` |
| `wifi list [인터페이스]` | `~/dualso102_net/wifi_list.sh` |
| `set_ap [SSID PASSWORD]` | `~/dualso102_net/set_ap.sh` |
| `setip [킷번호]` | `~/dualso102_net/set_ip.sh` |
| `setdhcp` / `set_dhcp` | `~/dualso102_net/set_dhcp.sh` |
| `net_status` | `~/dualso102_net/net_status.sh` |

### `.bashrc`에 넣는 방법

로봇의 `~/.bashrc`에 짧은 명령이 아직 없을 때만 한다 (이미지와 `setup_ap_mode.sh`로 옮긴 카드에는 이미 들어 있다). 먼저 확인:

```bash
grep -c 'dualso102_net >>>' ~/.bashrc   # 1 이상이면 이미 있다 — 아래를 또 붙이지 않는다
```

없으면 파일을 열어서 **맨 아래에** `bashrc_net.sh`의 내용을 통째로 붙여넣는다.

```bash
cd ~
nano ~/.bashrc
```

```bash
# >>> dualso102_net >>>
# 와이파이 전환 단축 명령: wifi <SSID> <비밀번호>  (= run_wifi, 저장된 공유기면 인자 없이 wifi)
#   wifi list [인터페이스]  → 주변 와이파이 목록
wifi() {
	if [ "${1:-}" = "list" ]; then
		"$HOME/dualso102_net/wifi_list.sh" "${2:-}"
	else
		"$HOME/dualso102_net/run_wifi.sh" "$@"
	fi
}

# 킷 고정 IP 변경 단축 명령: setip <킷번호>
setip() {
	"$HOME/dualso102_net/set_ip.sh" "$@"
}

# wlan0 DHCP 전환 단축 명령: setdhcp / set_dhcp (고정 IP 복귀는 setip N)
setdhcp() {
	"$HOME/dualso102_net/set_dhcp.sh" "$@"
}
alias set_dhcp=setdhcp

# Dual SO-102 네트워크 모드 전환 (~/dualso102_net)
alias run_ap="~/dualso102_net/run_ap.sh"
alias run_wifi="~/dualso102_net/run_wifi.sh"
alias set_ap="~/dualso102_net/set_ap.sh"
alias net_status="~/dualso102_net/net_status.sh"
# <<< dualso102_net <<<
```

저장하고 나온 뒤(`Ctrl+O` → `Enter` → `Ctrl+X`) 지금 터미널에 적용한다.

```bash
source ~/.bashrc
```

`# >>> dualso102_net >>>` · `# <<< dualso102_net <<<` 줄은 지우지 않는다. 설치 스크립트(`provision_ap_mode.sh`)가 `# >>> dualso102_net >>>` 줄로 "이미 들어 있나"를 확인하고, 있으면 다시 붙이지 않는다.

`.bashrc`에 넣지 않았다면 `~/dualso102_net/run_wifi.sh ...`처럼 경로로 부른다.

---

## 3. 자주 하는 일

### 지금 어떻게 붙어 있나

```bash
net_status
```

켜진 연결 이름 · 장치 · 상태와 IPv4 주소를 보여준다.

### AP 모드로 (로봇에 직접 붙기)

```bash
run_ap
# [run_ap] AP 모드 ON -> PC 를 '<AP 이름>' 에 연결 후: ssh <사용자>@192.168.4.1
```

공유기 프로필의 자동 연결을 꺼서, 재부팅해도 AP로 뜬다.

### 공유기 모드로

```bash
wifi list                      # 주변 와이파이 확인
run_wifi MyRouter MyPassword   # 처음 한 번: 저장 + 연결 (DHCP)
run_wifi                       # 이후: 저장된 공유기로 연결
```

- 비밀번호는 8~63자 (WPA2). SSID · 비밀번호 앞뒤에 공백을 둘 수 없다.
- 새 공유기를 저장하면 **고정 IP 설정은 DHCP로 초기화**된다. 고정 IP가 필요하면 이어서 `setip N`.
- 연결에 실패하면 자동으로 AP 모드로 돌아와서, 로봇에 닿을 길이 끊기지 않는다.

### 공유기 모드의 IP 바꾸기

```bash
setip          # 현재 설정 보기
setip 3        # 192.168.0.103 으로 고정 (킷 번호 1~54)
setdhcp        # 공유기가 주는 주소를 받는다
```

적용 방식은 [5장](#5-어떻게-안전하게-바꾸나) 참고. AP 모드일 때는 **저장만** 하고, 다음 `run_wifi` 때 적용된다.

### AP 이름 · 비밀번호 바꾸기

```bash
set_ap                         # 현재 AP 이름 보기
set_ap MyDualArm MyPassword    # 변경 (이름 1~32바이트, 비밀번호 8~63자)
```

- **처음 AP는 이름 · 비밀번호 모두 `dualso102-01`** 이다. 모든 로봇이 같고, 받은 사람이 바꾼다 (LeKiwi의 `lekiwi01`과 같은 정책).
- AP가 켜져 있으면 바로 다시 올라오므로 PC를 새 이름으로 다시 연결해야 한다.

---

## 4. 새 카드 복제 후 초기화

이미지를 구운 카드마다 **한 번** 실행한다. 호스트 이름은 `dualso102-%02d(킷 번호)`여야 한다.

```bash
sudo ~/dualso102_net/clone_init.sh dualso102-07 7
sudo ~/dualso102_net/clone_init.sh dualso102-07 7 --ap-ssid NAME --ap-password PW   # AP 이름 · 비밀번호도 정할 때
sudo reboot
```

| 항목 | 규칙 |
|---|---|
| 호스트 이름 | `dualso102-07` — 킷 번호와 맞지 않으면 거절 |
| 킷 번호 | 1~54. `/etc/kit-number`에도 저장 |
| AP 채널 | `(1, 6, 11)[킷 번호 % 3]` — 옆 카드와 채널이 겹치지 않게 |
| AP 이름 · 비밀번호 | 옵션을 줄 때만 바꾼다. 처음 값은 모든 로봇이 같고 고객이 바꾼다 |
| 공유기 고정 IP | `home-wifi` 프로필이 있을 때만 `192.168.0.(100 + 킷 번호)` |

종료 코드: `0` 성공 / `1` 인자 오류 또는 실패한 단계.
SSH 호스트키 · machine-id는 이미지의 첫 부팅 서비스가 새로 만든다 (여기서는 하지 않는다).

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

**원격으로 바꾸다 접속이 끊기지 않도록**, 실패하면 이전 상태로 되돌리는 단계를 둔다.

| 스크립트 | 실패했을 때 |
|---|---|
| `run_wifi.sh` | 공유기 연결 실패 → AP 모드로 복귀 |
| `_apply_home_ipv4.sh` (`setip` · `setdhcp`) | 적용한 IP가 안 잡힘 → 이전 설정 복구 → 복구도 실패하면 AP로 전환 |
| `run_ap.sh` | AP 전환 실패 → 공유기 자동 연결 설정을 원래 값으로 되돌리고, 공유기 우선 모드였으면 공유기로 복귀 |

**비밀번호가 흔적으로 남지 않게 한다.** `_apply_home_ipv4.sh`는 이전 설정 사본(공유기 비밀번호 포함)을 쓴 뒤 항상 지운다.
`clone_init.sh`는 AP 비밀번호가 `sudo` 명령줄(`auth.log`)에 남지 않도록 `nm_kf.py`를 직접 부른다.

---

## 6. 앱이 기대하는 것

Physical Labs 앱이 이 폴더를 찾아 스크립트를 부르고 출력을 읽는다. **아래를 바꾸면 앱이 이 로봇을 못 찾거나 결과를 잘못 읽는다.**

- **폴더 · 프로필 이름:** 앱은 `~/lekiwi_net` · `~/dualso102_net` 중 `run_wifi.sh` · `run_ap.sh`가 실행 가능한 폴더를 쓰고,
  AP 프로필 이름을 폴더 이름에서 만든다 (`dualso102_net` → `dualso102-ap`).
- **출력 줄:** `run_wifi.sh` · `set_ip.sh` · `set_dhcp.sh`의 아래 줄.

| 줄 | 의미 |
|---|---|
| `inet <IP>/<prefix> ...` (`ip -4 -o addr show wlan0` 출력) | 연결 성공. 앱이 IP를 여기서 읽는다 |
| `error: ...` | 실패. 앱이 읽는 줄 |

`wifi_list.sh`의 신호 임계값(-55 / -67 / -78 dBm)은 앱이 이 스크립트와 같게 쓴다.

앱이 로봇에 까는 SSH 키의 주석은 제품과 상관없이 `physical-labs-lekiwi`다. `image_ready_check.sh`는 이 주석으로 앱 키와 개인 키를 나눈다.

---

## 7. 환경 변수

시험용이다. 평소에는 설정하지 않는다.

| 변수 | 기본값 | 용도 |
|---|---|---|
| `NM_KF_DIR` | `/etc/NetworkManager/system-connections` | keyfile 폴더 |
| `DUALSO102_NET_STATE_DIR` | `/var/lib/dualso102-net` | 이전 설정 사본을 잠깐 두는 폴더 |
| `CLONE_ROOT` | (없음) | `clone_init.sh`의 모든 절대 경로 앞에 붙는다 |
| `CHECK_ROOT` · `CHECK_HOME` · `CHECK_BOOT_DEVICE` | (없음) | `image_ready_check.sh`의 가짜 루트 · 홈 · 부트 파티션 장치 |
| `PROVISION_ROOT` · `PROVISION_USER` · `PROVISION_HOME` | (없음) | `setup_ap_mode.sh` · `provision_ap_mode.sh` · `rollback_ap_mode.sh`의 가짜 루트 등 |

가짜 루트(`*_ROOT`)는 **root로는 쓰지 않는다** (스크립트가 거절한다).

---

## 8. 알아둘 점

- **공유기 대역은 `192.168.0.0/24`, 게이트웨이는 `192.168.0.1`로 가정**한다 (`_apply_home_ipv4.sh`에 고정). 다른 대역 공유기에서는 `setip`이 맞지 않는다. 그럴 땐 `setdhcp`를 쓴다.
- 고정 IP는 킷 번호 1~54만 된다 (`.101`~`.154`). LeKiwi는 `.201`~`.254`라 같은 공유기에 같이 붙어도 겹치지 않는다.
  다만 공유기가 DHCP로 나눠 주는 범위 안이면 다른 기기와 겹칠 수 있다. 그럴 땐 공유기의 DHCP 범위를 줄이거나 `setdhcp`.
- DHCP로 쓸 때 DNS는 공유기가 주는 값을 따르고, 고정 IP일 때만 `8.8.8.8` · `1.1.1.1`을 쓴다.
- 이미지 직후 카드에는 `home-wifi` 프로필이 없다. 이때 `run_wifi`(인자 없이) · `setip N` · `setdhcp`는 "먼저 `run_wifi SSID PW`"라고 안내하고 끝난다.
- AP 주소는 `192.168.4.1/24`, 2.4 GHz, DHCP `192.168.4.10~254`(NetworkManager가 띄우는 `dnsmasq`). 5 GHz AP는 쓰지 않는다.
- 라즈베리파이 내장 무선은 AP와 공유기 연결을 **둘 중 하나만** 켠다. 이미 켜진 AP는 공유기가 다시 보여도 스스로 내려가지 않는다 (`run_wifi` 또는 재부팅).
- AP가 비정상 종료되어 `192.168.4.1`을 `dnsmasq`가 붙잡고 있으면 `run_ap`가 정리하고 다시 올린다.
- AP에 붙은 기기는 로봇의 유선(eth0) 쪽으로도 나갈 수 있다 (NetworkManager `shared` 모드의 NAT). 처음 비밀번호가 공개값이므로 받은 뒤 `set_ap`로 바꾼다.
- 대부분 `sudo`가 필요하다 (스크립트 안에서 부르므로 따로 붙일 필요는 없다. `clone_init.sh` · `image_ready_check.sh` · 이관 도구만 `sudo`로 실행). 앱은 `sudo -n`으로 부른다.

---

## 9. 관련 저장소

| 위치 | 저장소 | 하는 일 |
|---|---|---|
| 로봇 `~/dualso102_net` | [roboseasy/dualso102_net](https://github.com/roboseasy/dualso102_net) (이 저장소) | 와이파이 · AP 전환 |
| 로봇 `~/workspace/lerobot` | [huggingface/lerobot](https://github.com/huggingface/lerobot) | 팔 구동 (팔로워 호스트) |
| 로봇 `~/workspace/dual_a-ba_edu` | [roboseasy-members/dual_a-ba_edu](https://github.com/roboseasy-members/dual_a-ba_edu) | 교육용 양팔 코드 |
| PC (원본) | [roboseasy/lekiwi_net](https://github.com/roboseasy/lekiwi_net) | 이 저장소 스크립트의 원본 (LeKiwi) |

로봇에 받는 법 (공개 저장소라 인증이 필요 없다):

```bash
git clone https://github.com/roboseasy/dualso102_net ~/dualso102_net
cd ~/dualso102_net && git pull   # 나중에 갱신
```

---

## 10. 원본(lekiwi_net)과 맞추기

원본이 바뀌면 PC에서 `sync_from_lekiwi.sh`로 다시 만든다. 원본 커밋은 `LEKIWI_NET_SYNCED`에 적힌다.

```bash
./sync_from_lekiwi.sh [lekiwi_net 경로]           # 기본 ~/workspace/lekiwi-repo/lekiwi_net
git diff                                          # 바뀐 줄 확인
python3 -m pytest -q
./sync_from_lekiwi.sh --check                     # 생성물을 손으로 고쳤는지 확인 (다르면 종료 1)
```

- 이름 치환표(`RENAME`)와 치환만으로는 맞지 않는 곳의 덮어쓰기(`fix`)는 스크립트 안에 있다.
  원본이 바뀌어 덮어쓰기가 맞지 않거나, 치환 뒤 `lekiwi`가 남으면 멈춘다.
- **생성한 파일은 손으로 고치지 않는다** (다음 동기화 때 덮인다). 고칠 일이 있으면 원본(lekiwi_net)에서 고치거나 `fix`를 더한다.
- 이 저장소에서 손으로 관리하는 파일: `README.md`, `setup_ap_mode.sh`, `tests/test_setup.py`, `sync_from_lekiwi.sh`.

| 원본 | 여기 |
|---|---|
| 폴더 `~/lekiwi_net`, 프로필 `lekiwi-ap` | `~/dualso102_net`, `dualso102-ap` |
| 상태 폴더 `/var/lib/lekiwi-net`, 표지 `/etc/lekiwi-net-provisioned` | `/var/lib/dualso102-net`, `/etc/dualso102-net-provisioned` |
| 백업 `/var/backups/lekiwi_net_*.tar.gz`, 타이머 `lekiwi-net-rollback` | `/var/backups/dualso102_net_*.tar.gz`, `dualso102-net-rollback` |
| 호스트 이름 `lekiwiNN`, 처음 AP `lekiwi01` | `dualso102-NN`, `dualso102-01` |
| 공유기 고정 IP `192.168.0.(200+N)` (`.201`~`.254`) | `192.168.0.(100+N)` (`.101`~`.154`) |
| `image_ready_check.sh`: ROS 워크스페이스(`~/lekiwi_ws`) 검사, 제외 폴더 `~/lerobot060_venv` | ROS 검사 없음, 제외 폴더 `~/venv`, 개발 도구 흔적에 `~/.copilot` 추가 |

---

## 11. 이관 · 점검 도구와 시험

### 이미지 뜨기 전 점검

```bash
sudo ~/dualso102_net/image_ready_check.sh
```

골든 카드에서 이미지를 뜨기 직전에 돌린다. 읽기만 한다. 한 줄에 `[OK|WARN|FAIL] 항목`, 끝에 `요약: FAIL n · WARN m`, FAIL이 있으면 종료 1.
공유기 비밀번호(줄 모양과 실제 값) · 남은 개인키 · `authorized_keys` · 셸 기록 · 옛 위치 파일 · 부트 파티션 · NetworkManager 상태를 본다.
비밀번호 · 키는 값이 아니라 파일 이름만 보인다.

### netplan 세대 Pi에 처음 넣기 (이관)

netplan + wpa_supplicant로 와이파이를 쓰던 Pi(이 로봇의 처음 이미지)를 한 번 옮긴다. **랜선으로 PC에 붙은 상태에서만** 한다.
이미지에서 구운 카드는 이미 옮겨져 있으므로 하지 않는다.

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
   이 Pi 이미지의 apt 소스에는 `noble-updates`가 없어 그냥 깔면 출시판(1.46.0-1ubuntu2)이 깔린다. 기준 구현(LeKiwi 로봇)은
   `network-manager 1.46.0-1ubuntu2.8` · `dnsmasq-base 2.91`이다 (출시판과는 방화벽 백엔드 · 자동 재연결 수정이 다르다). 끝나면 닫고 목록을 되돌린다.
2. `provision_ap_mode.sh` (인자 그대로): 백업 → NetworkManager 설치 → 스크립트 · 설정 설치 → 프로필 2개 → **되돌림 타이머 180초** →
   netplan의 `wifis` 삭제 → wlan0을 NetworkManager로 → `run_ap.sh` 또는 `run_wifi.sh` → 옛 도구(`set_wifi.sh`) 막기 → 확인.
3. cloud-init이 네트워크 설정을 다시 쓰지 않게 `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`.

| 인자 | 뜻 |
|---|---|
| `--mode ap` / `--mode wifi` | AP 고정 / 공유기 우선(못 붙으면 AP). 공유기가 근처에 없으면 `--mode wifi`는 실패해 되돌려진다 |
| `--dhcp` / `--kit N` | 공유기 모드에서 DHCP / 고정 `192.168.0.(100+N)` |
| `--ap-ssid NAME` | 처음 AP 이름이자 비밀번호 (기본 `dualso102-01`, 8~32자 ASCII) |
| `--hold-nm` | `apt-mark hold network-manager` (판이 올라가 동작이 바뀌는 것을 막는다) |
| `--dry-run` | 사전 점검과 할 일 목록만 |

종료 코드: `0` 성공 · 이미 적용됨 / `3` 사전 점검 거절 (안 바뀜) / `4` 바꾼 뒤 실패 (롤백함) / `5` 롤백도 다 되지 않음 (유선으로 들어와 고친다).

복구:

- **유선이 늘 길이다.** 어떤 스크립트도 `eth0`의 설정 · 주소를 바꾸지 않는다. 와이파이 설정이 꼬여도 랜선으로 들어와 고친다.
  다만 이관 · 롤백의 `netplan apply`가 eth0 DHCP를 다시 해 유선 ssh가 잠깐 끊길 수 있어 `setsid nohup … &`로 돌린다.
- **자동 롤백:** 바꾸기 전에 `/var/backups/dualso102_net_<날짜시각>.tar.gz`(root 600, **공유기 비밀번호가 들어 있다**)를 만들고
  180초 뒤 롤백 타이머(`dualso102-net-rollback`)를 건다. 접속을 확인했으면 `sudo systemctl stop dualso102-net-rollback.timer`.
- **손으로 되돌리기:** `sudo ~/dualso102_net_staging/rollback_ap_mode.sh [백업 tar]` — wlan0은 다시 netplan + wpa_supplicant, NetworkManager는 꺼 둔다.
- **백업 파일은 로봇에 남기지 않는다.** PC로 옮겨 sha256을 맞춘 뒤 로봇에서 `sudo shred -u`로 지운다 (이미지에 공유기 비밀번호가 실리지 않게).

### 시험

PC에서 돌린다. 이 PC의 네트워크와 `/etc`는 건드리지 않는다 — 가짜 `PATH`의 stub과 임시 폴더에서만 돈다.

```bash
python3 -m pytest -q   # pytest 가 든 파이썬. libnm 시험 하나는 python3-gi 가 있어야 돈다 (없으면 건너뜀)
```

---

## 12. 설치 기록

| 날짜 | 로봇 | 결과 |
|---|---|---|
| 2026-11-14 | `roboseasy-pi01` (Dual SO-102 팔로워, Ubuntu 24.04) | `setup_ap_mode.sh` (기본 인자: AP 고정 · DHCP · NM hold) → 종료 0. NetworkManager `1.46.0-1ubuntu2.8`(hold) · dnsmasq-base `2.91`. 로봇 쪽 확인 20항목 PASS — 설치 직후 · 재부팅 뒤 · 앱의 [AP 모드 켜기] 뒤. PC 무선 스캔으로 채널 6 · WPA2 확인, `run_wifi`(공유기 범위 밖) 실패 → AP 복귀 확인. |
| 2026-11-18 | `roboseasy-pi01` | `image_ready_check.sh` 읽기 전용 실행: FAIL 20 · WARN 14 (개발 카드라 정상 — 셸 기록 · cloud-init 사본 · 로그의 공유기 비밀번호, `.vscode-server` · `.copilot`). |

- 앱 계약 (2026-11-15): Physical Labs 앱이 보내는 스크립트(상태 읽기 · sudo 확인 · 와이파이 상태 · 스캔 · AP 켜기 · 로그 읽기)를
  이 로봇에서 그대로 실행해 앱의 파서로 읽었다 — 세대 `nm` · 모드 `ap` · AP 이름 `dualso102`(당시 처음 값) · `192.168.4.1/24`.
- 사람이 해야 하는 확인: 폰 · PC 를 AP 에 붙여 `ssh <사용자>@192.168.4.1`, 맞는 비밀번호로 공유기 모드, 공유기를 끈 채 부팅.
