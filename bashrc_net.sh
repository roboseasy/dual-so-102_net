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
