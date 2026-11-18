#!/bin/sh
# Run on OpenWrt with sing-box installed. Optional arguments point to momo.init and include.sh.
set -e
umask 077
case "$#" in
	0)
		source_dir="$(dirname "$0")/../momo/files"
		set -- "$source_dir/momo.init" "$source_dir/scripts/include.sh"
	;;
	2) ;;
	*) echo "Usage: $0 [momo.init include.sh]" >&2; exit 1 ;;
esac

test -r /etc/rc.common
command -v sing-box >/dev/null
scratch=$(mktemp -d /tmp/momo-rc-lock.XXXXXX)
root="$scratch/root"

cleanup_test() {
	for section in sample cold retry; do
		: > "$scratch/release.$section"
	done
	wait || :
	rm -rf -- "$scratch"
}
trap cleanup_test EXIT

# Keep OpenWrt's real command dispatch and service lock. Redirect all state to scratch.
mkdir -p "$root/lib/functions" "$root/usr/share/libubox" "$root/var/lock" \
	"$root/etc/init.d" "$root/etc/momo/scripts" "$scratch/runtime" "$scratch/subscriptions"
ln -s /lib/functions.sh "$root/lib/functions.sh"
ln -s /lib/functions/service.sh "$root/lib/functions/service.sh"
ln -s /lib/functions/procd.sh "$root/lib/functions/procd.sh"
ln -s /usr/share/libubox/jshn.sh "$root/usr/share/libubox/jshn.sh"
cp "$1" "$root/etc/init.d/momo"
cp "$2" "$scratch/momo-include.sh"

printf '{"outbounds":[{"type":"direct","tag":"old"}]}\n' > "$scratch/old.json"
printf '{"outbounds":[{"type":"direct","tag":"new"}]}\n' > "$scratch/new.json"

cat > "$root/etc/momo/scripts/include.sh" <<'MOCK'
. "$MOMO_TEST_STATE/momo-include.sh"
PROG="$(command -v sing-box)"
TEMP_DIR="$MOMO_TEST_STATE/runtime"
SUBSCRIPTIONS_DIR="$MOMO_TEST_STATE/subscriptions"
CORE_LOG_PATH="$MOMO_TEST_STATE/core.log"

prepare_files() { :; }
config_load() { :; }
config_get() {
	case "$1" in
		subscription_name) subscription_name="$2" ;;
		subscription_url) subscription_url="fixture:$2" ;;
		subscription_info_url) subscription_info_url='' ;;
		subscription_user_agent) subscription_user_agent='sing-box' ;;
	esac
}
uci_set() { printf 'set %s %s=%s\n' "$2" "$3" "$4" >> "$MOMO_TEST_STATE/uci.log"; }
uci_remove() { printf 'remove %s %s\n' "$2" "$3" >> "$MOMO_TEST_STATE/uci.log"; }
uci_commit() { printf 'commit\n' >> "$MOMO_TEST_STATE/uci.log"; }
log() { printf '%s\n' "$2" >> "$MOMO_TEST_STATE/app.log"; }

curl() {
	local header='' body='' section=''
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-D) header="$2"; shift ;;
			-o) body="$2"; shift ;;
			--) section="${2#fixture:}"; break ;;
		esac
		shift
	done
	printf '%s\n' "$section" >> "$MOMO_TEST_STATE/requests.log"
	case "$MOMO_TEST_EVENT" in
		hold|fail-after-hold)
			: > "$MOMO_TEST_STATE/entered.$section"
			local attempts=20
			while [ ! -e "$MOMO_TEST_STATE/release.$section" ]; do
				[ "$attempts" -gt 0 ] || return 28
				sleep 1
				attempts=$((attempts - 1))
			done
		;;
	esac
	[ "$MOMO_TEST_EVENT" != fail-after-hold ] || return 22
	printf 'HTTP/1.1 200 OK\n' > "$header"
	cp "$MOMO_TEST_STATE/new.json" "$body"
}
MOCK

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
wait_until() {
	local attempts=8
	until "$@"; do
		[ "$attempts" -gt 0 ] || fail "condition did not become true: $*"
		sleep 1
		attempts=$((attempts - 1))
	done
}

refresh() {
	local label="$1" section="$2" mode="$3" event="$4" status=0
	IPKG_INSTROOT="$root" MOMO_TEST_STATE="$scratch" MOMO_TEST_EVENT="$event" \
		sh /etc/rc.common "$root/etc/init.d/momo" update_subscription "$section" "$mode" \
		> "$scratch/$label.log" 2>&1 || status=$?
	printf '%s\n' "$status" > "$scratch/$label.exit"
}

expect_status() {
	wait_until test -s "$scratch/$1.exit"
	[ "$(cat "$scratch/$1.exit")" = "$2" ] || fail "unexpected status for $1"
}
count_requests() { awk -v section="$1" '$0 == section { n++ } END { print n+0 }' "$scratch/requests.log"; }

printf 'previous metadata\n' > "$scratch/prev-uci.log"
cp "$scratch/prev-uci.log" "$scratch/uci.log"
cp "$scratch/old.json" "$scratch/subscriptions/sample.json"
refresh holder sample '' hold &
wait_until test -e "$scratch/entered.sample"
refresh duplicate sample '' normal &
refresh cached sample startup normal &
expect_status duplicate 1
expect_status cached 1
[ "$(count_requests sample)" -eq 1 ] || fail 'duplicate made another request'
cmp -s "$scratch/prev-uci.log" "$scratch/uci.log" || fail 'duplicate changed metadata'
cmp -s "$scratch/old.json" "$scratch/subscriptions/sample.json" || fail 'duplicate changed the cached profile'
refresh neighbor neighbor '' normal &
expect_status neighbor 0
[ "$(count_requests neighbor)" -eq 1 ] || fail 'unrelated subscription could not refresh while sample was busy'
: > "$scratch/release.sample"
expect_status holder 0
cmp -s "$scratch/new.json" "$scratch/subscriptions/sample.json" || fail 'holder did not publish its profile'
printf 'PASS real rc.common suppresses duplicates and allows independent refreshes\n'

refresh cold-holder cold '' hold &
wait_until test -e "$scratch/entered.cold"
refresh cold-start cold startup normal &
wait_until grep -Fq 'Subscription refresh already in progress for cold.' "$scratch/app.log"
: > "$scratch/release.cold"
expect_status cold-holder 0
expect_status cold-start 0
[ "$(count_requests cold)" -eq 1 ] || fail 'cold startup fetched an already published profile'
printf 'PASS cold startup reuses the active refresh result\n'

refresh failed-holder retry '' fail-after-hold &
wait_until test -e "$scratch/entered.retry"
refresh retry-start retry startup normal &
wait_until grep -Fq 'Subscription refresh already in progress for retry.' "$scratch/app.log"
: > "$scratch/release.retry"
expect_status failed-holder 1
expect_status retry-start 0
[ "$(count_requests retry)" -eq 2 ] || fail 'cold startup did not retry after the initial failure'
cmp -s "$scratch/new.json" "$scratch/subscriptions/retry.json" || fail 'retry did not publish its profile'
printf 'PASS cold startup retries after a failed active refresh\n'
