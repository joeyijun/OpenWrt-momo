#!/bin/sh
set -e
source_file="${1:-$(dirname "$0")/../momo/files/momo.init}"
functions=$(sed -n '/^tun_link_is_up() {/,/^}/p; /^wait_for_tun() {/,/^}/p' "$source_file")
eval "$functions"

tun_link_is_up lo
if tun_link_is_up momo-test-absent; then exit 1; fi

# Fake readiness and sleep to exercise timeout handling without changing interfaces.
tun_link_is_up() { [ "${ready_after:-99}" -le "$elapsed" ]; }
sleep() {
	elapsed=$((elapsed + $1))
	calls="${calls}:$1"
}

elapsed=0 calls='' ready_after=8
wait_for_tun test 08 03
[ "$calls" = ':3:3:2' ]

elapsed=0 calls='' ready_after=99
if wait_for_tun test 2 0; then exit 1; fi
[ "$calls" = ':1:1' ]

elapsed=0 calls='' ready_after=99
if wait_for_tun test 3 10; then exit 1; fi
[ "$calls" = ':3' ]
printf 'PASS link flag, missing interface, bounded waits, and zero interval\n'
