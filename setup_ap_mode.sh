#!/bin/bash
# Dual SO-102 Pi(netplan 세대)에 AP 모드를 한 번에 넣는다: provision_ap_mode.sh 를 감싼다.
#   sudo setsid nohup ./setup_ap_mode.sh > ~/ap_setup.log 2>&1 &     (netplan apply 때 유선 ssh가 잠깐 끊길 수 있다)
#   인자는 provision_ap_mode.sh 로 그대로 넘긴다. 없으면 --mode ap --dhcp --hold-nm (AP 고정 · 공유기는 DHCP · 판 고정)
# 감싸는 까닭 두 가지 (provision_ap_mode.sh 는 원본 lekiwi_net 과 이름만 다르게 유지한다):
#  1. 이 Pi 이미지의 apt 소스에는 noble-updates 가 없어 NetworkManager 가 출시판(1.46.0-1ubuntu2)으로 깔린다. 기준 구현(lekiwi05)은
#     network-manager 1.46.0-1ubuntu2.8 · dnsmasq-base 2.91 이므로, 설치하는 동안만 그 패키지에 한해 noble-updates 를 연다.
#  2. cloud-init 이 네트워크 설정을 다시 쓰지 않게 한다 (원본 로봇은 이미지에 이미 들어 있다).
# 종료 코드는 provision_ap_mode.sh 와 같다 (0 · 3 · 4 · 5). 마지막 줄은 늘 "[setup] 끝 rc=N" (PC 쪽이 이 줄로 끝난 것을 안다).
# 시험용 환경변수: PROVISION_ROOT (provision_ap_mode.sh 와 같다)
set -uo pipefail

ROOT="${PROVISION_ROOT:-}"
HERE=$(dirname "$(readlink -f "$0")")
SRC="$ROOT/etc/apt/sources.list.d/zz-dualso102-nm-tmp.sources"
PIN="$ROOT/etc/apt/preferences.d/zz-dualso102-nm-tmp"
OPENED=''
finish() {
	local rc=$?
	trap '' INT TERM HUP
	if [ -n "$OPENED" ]; then     # 연 것은 성공 · 실패와 상관없이 닫는다
		rm -f "$SRC" "$PIN"
		apt-get update -qq || echo "[setup] 경고: apt-get update 실패 (목록에 noble-updates 가 남았을 수 있다: sudo apt-get update)" >&2
	fi
	echo "[setup] 끝 rc=$rc"
	exit "$rc"
}
trap finish EXIT
trap 'exit 130' INT TERM HUP

[ $# -gt 0 ] || set -- --mode ap --dhcp --hold-nm
case " $* " in *' --dry-run '*|*' --help '*|*' -h '*) "$HERE/provision_ap_mode.sh" "$@"; exit ;; esac

if [ -n "$ROOT" ]; then     # 가짜 루트는 시험용: root로 돌면 잘못 붙은 경로가 실제 /etc를 바꿀 수 있다
	[ "$(id -u)" -ne 0 ] || { echo "[setup] 거절: PROVISION_ROOT는 시험용입니다 (root로는 쓰지 않는다)" >&2; exit 3; }
else
	[ "$(id -u)" -eq 0 ] || { echo "[setup] 거절: root로 실행하세요 (sudo)" >&2; exit 3; }
fi

# shortcut: Ubuntu 24.04(noble) · Pi(arm64, ports.ubuntu.com) 전용, 다른 판 · 보드는 설정된 소스의 판을 그대로 깐다 (그때 기준 판을 다시 정한다)
updates_enabled() (     # 주석이 아닌 줄에 noble-updates 가 이미 있는가
	set +o pipefail     # 서브셸 안에서만: 없는 파일(종료 2) · grep -q 의 이른 종료가 "없다"로 읽히지 않게
	grep -rhs -v '^[[:space:]]*#' "$ROOT/etc/apt/sources.list" "$ROOT/etc/apt/sources.list.d" | grep -q 'noble-updates'
)
if [ ! -e "$ROOT/etc/dualso102-net-provisioned" ] && grep -qsx 'VERSION_CODENAME=noble' "$ROOT/etc/os-release" \
	&& ! updates_enabled; then
	install -d -m 755 "${SRC%/*}" "${PIN%/*}"
	OPENED=1
	cat > "$SRC" <<'EOF'
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: noble-updates
Components: main
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
	# 나머지 패키지는 이 이미지가 쓰던 판(noble · noble-security)에 그대로 둔다
	cat > "$PIN" <<'EOF'
Package: *
Pin: release a=noble-updates
Pin-Priority: 100

Package: network-manager libnm0 dnsmasq-base
Pin: release a=noble-updates
Pin-Priority: 990
EOF
	chmod 644 "$SRC" "$PIN"
	apt-get update -qq || { echo "[setup] 거절: noble-updates 목록을 받지 못했습니다 (인터넷 확인) — 네트워크 설정은 바꾸지 않았습니다" >&2; exit 3; }
fi

"$HERE/provision_ap_mode.sh" "$@" || exit

if [ -d "$ROOT/etc/cloud" ]; then
	install -d -m 755 "$ROOT/etc/cloud/cloud.cfg.d"
	echo 'network: {config: disabled}' > "$ROOT/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"
fi
