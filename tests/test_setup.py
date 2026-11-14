"""setup_ap_mode.sh 시험: provision_ap_mode.sh 를 감싸 설치하는 동안만 noble-updates 를 열고, 끝나면 닫는다.

test_provision 의 가짜 로봇 트리(PROVISION_ROOT) · 가짜 PATH 를 그대로 쓴다. 이 PC 는 바뀌지 않는다.
"""

from pathlib import Path

import pytest

from test_provision import RobotTree, ok
from test_robot_net import ROBOT_NET, index_of, tree_state

SETUP = ROBOT_NET / 'setup_ap_mode.sh'
SRC = 'etc/apt/sources.list.d/zz-dualso102-nm-tmp.sources'
PIN = 'etc/apt/preferences.d/zz-dualso102-nm-tmp'
CLOUD = 'etc/cloud/cloud.cfg.d/99-disable-network-config.cfg'
BASE_SOURCES = 'Types: deb\nURIs: http://ports.ubuntu.com/ubuntu-ports/\nSuites: noble\nComponents: main\n'

# apt-get 을 부르는 순간 임시 소스 · 핀이 있었는지 남긴다. FAKE_APT_UPDATE_FAILS=1: update 만 실패.
APT_STUB = f'''src="$PROVISION_ROOT/{SRC}"; pin="$PROVISION_ROOT/{PIN}"
echo "apt-get $* | src: $([ -f "$src" ] && echo yes || echo no) pin: $([ -f "$pin" ] && echo yes || echo no)" >> "$FAKE_LOG"
case " $* " in *' update '*) [ "${{FAKE_APT_UPDATE_FAILS:-0}}" != 1 ] || {{ echo 'E: fake: update failed' >&2; exit 100; }} ;; esac
'''


@pytest.fixture
def tree(tmp_path: Path) -> RobotTree:
	"""이 Pi 이미지 모양: Ubuntu 24.04(noble), apt 소스에 noble-updates 없음, cloud-init 있음."""
	made = RobotTree(tmp_path, {'apt-get': APT_STUB})
	for rel, text in (('etc/os-release', 'NAME="Ubuntu"\nVERSION_CODENAME=noble\n'),
		('etc/apt/sources.list.d/ubuntu.sources', '# noble-updates 는 뺐다\n' + BASE_SOURCES),
		('etc/cloud/cloud.cfg.d/99-fake-cloud.cfg', 'datasource_list: [ NoCloud, None ]\n')):
		path = made.root / rel
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(text)
	return made


def setup(tree: RobotTree, *args: str, **env: str):
	return tree.fake.run([str(SETUP), *args], **tree.env(FAKE_ACTIVE='dualso102-ap', **env))


def apt_calls(tree: RobotTree) -> list[str]:
	return [line for line in tree.calls() if line.startswith('apt-get')]


def test_setup_opens_updates_only_while_installing(tree: RobotTree) -> None:
	"""기본 인자(AP 고정 · DHCP · 판 고정)로 끝까지: 설치 때만 noble-updates 가 열려 있고, 끝나면 흔적이 없다."""
	done = ok(setup(tree))
	calls = apt_calls(tree)
	assert calls[0] == 'apt-get update -qq | src: yes pin: yes'
	install = calls[index_of(calls, 'network-manager dnsmasq-base')]
	assert install.endswith('| src: yes pin: yes')
	assert calls[-1] == 'apt-get update -qq | src: no pin: no'          # 닫은 뒤 목록을 원래대로
	assert not (tree.root / SRC).exists() and not (tree.root / PIN).exists()
	assert tree.text(CLOUD) == 'network: {config: disabled}\n'
	assert tree.keyfile('dualso102-ap').get('wifi', 'ssid') == 'dualso102'
	assert tree.keyfile('home-wifi').get('connection', 'autoconnect') == 'false'     # --mode ap
	assert tree.keyfile('home-wifi').get('ipv4', 'method') == 'auto'                 # --dhcp
	assert 'apt-mark hold network-manager' in tree.calls()                           # --hold-nm
	assert done.stdout.rstrip().splitlines()[-1] == '[setup] 끝 rc=0'


def test_setup_failure_closes_updates_and_keeps_exit_code(tree: RobotTree) -> None:
	"""프로비저닝이 실패(AP 를 못 올림 → 롤백, 종료 4)해도 noble-updates 는 닫고, cloud-init 설정은 쓰지 않는다."""
	done = setup(tree, FAKE_AP_UP_FAILS='1')
	assert done.returncode == 4, done.stdout + done.stderr
	assert not (tree.root / SRC).exists() and not (tree.root / PIN).exists()
	assert apt_calls(tree)[-1] == 'apt-get update -qq | src: no pin: no'
	assert not (tree.root / CLOUD).exists()
	assert done.stdout.rstrip().splitlines()[-1] == '[setup] 끝 rc=4'


def test_setup_refuses_before_any_change_when_updates_unreachable(tree: RobotTree) -> None:
	"""noble-updates 목록을 못 받으면(인터넷 없음) 네트워크 설정을 건드리기 전에 멈춘다."""
	netplan = tree.text('etc/netplan/50-cloud-init.yaml')
	done = setup(tree, FAKE_APT_UPDATE_FAILS='1')
	assert done.returncode == 3, done.stdout + done.stderr
	assert tree.text('etc/netplan/50-cloud-init.yaml') == netplan
	assert not tree.backups()
	assert not (tree.root / SRC).exists() and not (tree.root / PIN).exists()
	assert not [line for line in tree.calls() if line.startswith(('systemctl', 'netplan', 'nmcli con'))]


def test_setup_dry_run_changes_nothing(tree: RobotTree) -> None:
	before = tree_state(tree.root)
	done = ok(setup(tree, '--dry-run', '--mode', 'ap', '--dhcp'))
	assert tree_state(tree.root) == before
	assert not apt_calls(tree)
	assert 'DRY-RUN: 변경 없음' in done.stdout


def test_setup_leaves_sources_alone_when_updates_already_enabled(tree: RobotTree) -> None:
	"""이미 noble-updates 를 쓰는 카드에서는 소스 · 핀을 만들지 않는다 (주석에만 있는 것은 세지 않는다)."""
	(tree.root / 'etc/apt/sources.list.d/ubuntu.sources').write_text(BASE_SOURCES.replace('noble\n', 'noble noble-updates\n'))
	ok(setup(tree))
	assert all(line.endswith('| src: no pin: no') for line in apt_calls(tree))
	assert [line for line in apt_calls(tree) if ' update ' in line] == []
