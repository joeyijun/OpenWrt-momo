#!/bin/sh
# Run with OpenWrt shell utilities and sing-box. Only scratch files are written.
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

dir=$(mktemp -d /tmp/momo-service-change.XXXXXX)
trap 'rm -rf -- "$dir"' EXIT
IPKG_INSTROOT="$dir/root"
mkdir -p "$IPKG_INSTROOT/etc/momo/scripts" "$IPKG_INSTROOT/usr/share/libubox"
cp "$2" "$IPKG_INSTROOT/etc/momo/scripts/include.sh"
ln -s /usr/share/libubox/jshn.sh "$IPKG_INSTROOT/usr/share/libubox/jshn.sh"
sed "s%/etc/crontabs/root%$dir/crontab%g" "$1" > "$dir/init.sh"
extra_command() { :; }
. "$dir/init.sh"

TEMP_DIR="$dir/tmp"
PROFILES_DIR="$dir/profiles"
RUN_DIR="$dir/run"
RUN_PROFILE_PATH="$RUN_DIR/config.json"
LOG_DIR="$dir/log"
CORE_LOG_PATH="$LOG_DIR/core.log"
APP_LOG_PATH="$LOG_DIR/app.log"
STARTED_FLAG_PATH="$TEMP_DIR/flag"
mkdir -p "$RUN_DIR" "$PROFILES_DIR"
: > "$dir/crontab"

export MOMO_TEST_CORE="$(command -v sing-box)"
export MOMO_TEST_CORE_CALLS="$dir/core-calls"
cat > "$dir/core" <<'CORE'
#!/bin/sh
printf '%s\n' "$*" >> "$MOMO_TEST_CORE_CALLS"
exec "$MOMO_TEST_CORE" "$@"
CORE
chmod 700 "$dir/core"
PROG="$dir/core"

enabled_override=1
load_error=0
active_profile=file:valid.json
config_load() { [ "$load_error" = 0 ]; }
config_get() {
	local test_value="${4:-}"
	case "${2:-}.${3:-}" in
		config.enabled) test_value="$enabled_override" ;;
		config.profile) test_value="$active_profile" ;;
		config.test_profile|config.core_only) test_value=1 ;;
	esac
	export "$1=$test_value"
}
config_get_bool() { config_get "$@"; }
procd_open_instance() { echo activate >> "$dir/events"; }
procd_set_param() { :; }
procd_append_param() { :; }
procd_close_instance() { :; }
cleanup() { echo cleanup >> "$dir/events"; }
stop() { echo stop >> "$dir/events"; }
start() { echo start >> "$dir/events"; start_service; }
fail() { printf 'FAIL %s\n' "$1" >&2; exit 1; }

printf '{"outbounds":[{"type":"direct","tag":"local"}]}\n' > "$PROFILES_DIR/valid.json"
printf '{"outbounds":[{"type":"unknown-fixture-type"}]}\n' > "$PROFILES_DIR/invalid.json"

: > "$dir/events"
: > "$dir/core-calls"
start_service
[ "$(cat "$dir/events")" = activate ] || fail 'initial start did not activate'
[ "$(grep -c ' check$' "$dir/core-calls")" = 1 ] || fail 'initial start check count'
cp "$RUN_PROFILE_PATH" "$dir/previous.json"

for mode in reload_service restart; do
	for bad_profile in file:invalid.json file:missing.json; do
		: > "$dir/events"
		active_profile="$bad_profile"
		if "$mode"; then fail "bad profile accepted by $mode"; fi
		[ ! -s "$dir/events" ] || fail "$mode changed the service after rejecting the profile"
		cmp -s "$RUN_PROFILE_PATH" "$dir/previous.json" || fail "$mode changed the runtime file"
	done

	load_error=1
	if "$mode"; then fail "$mode accepted an unavailable UCI configuration"; fi
	[ ! -s "$dir/events" ] || fail "$mode changed the service without loading UCI"
	load_error=0

	active_profile=file:valid.json
	: > "$dir/events"
	: > "$dir/core-calls"
	"$mode"
	if [ "$mode" = reload_service ]; then
		expected=$(printf 'cleanup\nstart\nactivate')
	else
		expected=$(printf 'stop\nstart\nactivate')
	fi
	[ "$(cat "$dir/events")" = "$expected" ] || fail "valid $mode lifecycle"
	[ "$(grep -c ' check$' "$dir/core-calls")" = 1 ] || fail "$mode checked more or less than once"
done
printf 'PASS reload and restart preflight protect the live profile and validate only once\n'

: > "$dir/events"
: > "$dir/core-calls"
enabled_override=0
active_profile=file:missing.json
reload_service
expected=$(printf 'cleanup\nstart')
[ "$(cat "$dir/events")" = "$expected" ] || fail 'disabled lifecycle'
[ ! -s "$dir/core-calls" ] || fail 'disabled reload tested a file'
printf 'PASS disabling the service still clears the active rules\n'
