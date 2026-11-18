#!/bin/bash
# lekiwi_net 의 공통 파일을 이름만 바꿔 이 저장소에 다시 만든다 (PC 에서 쓴다, 로봇에서는 쓰지 않는다)
#   ./sync_from_lekiwi.sh [lekiwi_net 경로]           생성하고 LEKIWI_NET_SYNCED 에 원본 커밋을 적는다
#   ./sync_from_lekiwi.sh --check [lekiwi_net 경로]   생성 결과가 지금 파일과 같은지만 본다 (다르면 종료 1)
# 경로 기본값: ~/workspace/lekiwi-repo/lekiwi_net. 생성한 뒤 시험한다: python3 -m pytest -q
# 아래 FILES 는 생성물이라 손으로 고치지 않는다 (다음 동기화 때 덮인다). dual 만의 차이는 RENAME · fix 에 적는다.
# 손으로 관리하는 파일: README.md · setup_ap_mode.sh · tests/test_setup.py · 이 파일
set -euo pipefail

D=$(dirname "$(readlink -f "$0")")
CHECK=''
[ "${1:-}" != --check ] || { CHECK=1; shift; }
SRC=$(readlink -f "${1:-$HOME/workspace/lekiwi-repo/lekiwi_net}")

FILES=(_apply_home_ipv4.sh net_status.sh nm_kf.py run_ap.sh run_wifi.sh set_ap.sh set_dhcp.sh set_ip.sh wifi_list.sh
	bashrc_net.sh clone_init.sh image_ready_check.sh provision_ap_mode.sh rollback_ap_mode.sh pytest.ini .gitignore
	tests/test_robot_net.py tests/test_wifi_list.py tests/test_provision.py tests/test_clone_init.py tests/test_image_ready.py)

# 위에서 아래 순서로 (긴 이름부터). 호스트 이름 · 처음 AP 값: lekiwiNN → dualso102-NN
# 공유기 고정 IP: lekiwi 192.168.0.(200+N) → dual 192.168.0.(100+N). 같은 공유기에 둘이 붙어도 겹치지 않게
# 앱이 모든 로봇에 까는 SSH 키의 주석 physical-labs-lekiwi 는 제품 이름이 아니라 앱의 이름표라 그대로 둔다
APP_KEY=physical-labs-lekiwi
RENAME=(
	-e "s/$APP_KEY/@APP_KEY@/g"
	-e 's/LEKIWI_NET/DUALSO102_NET/g'
	-e 's/lekiwi_net/dualso102_net/g'
	-e 's/lekiwi-net/dualso102-net/g'
	-e 's/lekiwi-ap/dualso102-ap/g'
	-e 's/lekiwi%02d/dualso102-%02d/g'
	-e 's/lekiwiNN/dualso102-NN/g'
	-e 's/lekiwi\([0-9]\)/dualso102-\1/g'
	-e 's/lekiwi{/dualso102-{/g'
	-e 's/lekiwi\[0-9\]/dualso102-[0-9]/g'
	-e 's/LeKiwi/Dual SO-102/g'
	-e 's/lekiwi/dualso102/g'
	-e 's/200 + /100 + /g'
	-e 's/(200+/(100+/g'
	-e 's/192\.168\.0\.2\([0-5][0-9]\)/192.168.0.1\1/g'
	-e 's/lerobot060_venv/venv/g'
	-e "s/@APP_KEY@/$APP_KEY/g"
)

bad() { echo "error: $*" >&2; exit 1; }

[ -d "$SRC" ] || bad "lekiwi_net 이 없습니다: $SRC"
for f in "${FILES[@]}"; do [ -f "$SRC/$f" ] || bad "원본에 $f 가 없습니다 (lekiwi_net 에서 이름이 바뀌었으면 FILES 를 고친다)"; done
# 커밋되지 않은 원본으로 만들면 LEKIWI_NET_SYNCED 의 커밋과 내용이 어긋난다
[ -z "$(git -C "$SRC" status --porcelain -- "${FILES[@]}")" ] || bad "$SRC 에 커밋하지 않은 변경이 있습니다"
REV=$(git -C "$SRC" rev-parse HEAD)

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
mkdir -p "$OUT/tests"
for f in "${FILES[@]}"; do
	sed "${RENAME[@]}" "$SRC/$f" > "$OUT/$f"
	chmod "$(stat -c %a "$SRC/$f")" "$OUT/$f"
done

# 치환만으로 뜻이 바뀌는 곳. 원본이 바뀌어 더 맞지 않으면 멈춘다 (조용히 넘어가지 않게)
fix() {
	local f="$OUT/$1" before
	before=$(md5sum < "$f")
	sed -i "$2" "$f"
	[ "$(md5sum < "$f")" != "$before" ] || bad "$1: 고칠 곳을 못 찾았습니다 ($2) — 원본이 바뀌었는지 보고 fix 를 고친다"
}
# AP 이름이자 비밀번호라 8자 미만이면 거절해야 한다: lekiwi7(7자)이 치환으로 dualso102-7(11자)이 되어 통과해 버린다
fix tests/test_provision.py "s/('--ap-ssid', 'dualso102-7')/('--ap-ssid', 'dual-07')/"
# 함수 이름에 - 를 쓸 수 없다
fix tests/test_provision.py 's/^def test_provision_default_ap_is_dualso102-01(/def test_provision_default_ap_is_dualso102_01(/'
# 이 로봇에는 ROS 워크스페이스가 없다: ~/lekiwi_ws/install 깨진 링크 검사는 빼고 (없으면 FAIL 이 된다), 그 시험도 뺀다
fix image_ready_check.sh '/^if \[ -d "\$H\/dualso102_ws\/install" \]; then$/,/^fi$/d'
fix tests/test_image_ready.py '/^def test_broken_install_symlink_fails(/,/^@pytest\.mark\.parametrize/{/^@pytest/!d}'
# Copilot CLI 상태 폴더도 개발 도구 흔적이다 (이 Pi 에 있었다). shortcut: lekiwi_net 에 올리면 이 두 줄을 지운다
fix image_ready_check.sh 's|existing "\$H/\.vscode-server" "\$H"/\.claude\* |existing "$H/.vscode-server" "$H"/.claude* "$H/.copilot" |'
fix tests/test_image_ready.py "s|^\t(f'{H}/\.claude\.json', f'{HOME}/\.claude\.json'),\$|&\n\t(f'{H}/.copilot/config.json', f'{HOME}/.copilot'),|"

if sed "s/$APP_KEY//g" "${FILES[@]/#/$OUT/}" | grep -n -i lekiwi; then bad "치환 뒤에도 lekiwi 가 남았습니다 (위 줄). RENAME 에 규칙을 더한다"; fi

if [ -n "$CHECK" ]; then
	RC=0
	for f in "${FILES[@]}"; do
		cmp -s "$OUT/$f" "$D/$f" || { echo "다름: $f"; RC=1; }
	done
	[ "$(cat "$D/LEKIWI_NET_SYNCED" 2>/dev/null)" = "$REV" ] || { echo "다름: LEKIWI_NET_SYNCED (원본은 $REV)"; RC=1; }
	[ "$RC" -ne 0 ] || echo "[sync] 같음 (lekiwi_net $REV)"
	exit "$RC"
fi

for f in "${FILES[@]}"; do cp -p "$OUT/$f" "$D/$f"; done
echo "$REV" > "$D/LEKIWI_NET_SYNCED"
echo "[sync] lekiwi_net $REV 에서 ${#FILES[@]}개 생성. 다음: git diff 확인 → python3 -m pytest -q"
