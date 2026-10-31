#!/usr/bin/env bash
# Runs every headless test suite in parallel and prints one summary line each.
# Suites that read/write user://savegame.json share one sequential lane so they
# never race on the save file; everything else runs concurrently.
#
#   tools/run_tests.sh              # all suites
#   tools/run_tests.sh player combat # only suites whose name contains these words
#
# Exit code is non-zero if any suite fails, crashes or times out.
set -u
cd "$(dirname "$0")/.."
G="${GODOT:-/d/GODOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
OUT="$(mktemp -d)"
TIMEOUT="${TEST_TIMEOUT:-300}"

# name | scene | extra args | pass regex
SUITES=(
	"player|res://tests/player_test.tscn||PLAYER TESTS: [0-9]+ passed, 0 failed"
	"combat|res://tests/combat_test.tscn|--fixed-fps 60|combat tests: [0-9]+ passed, 0 failed"
	"world|res://tests/world_check.tscn|-- --full|^[^F]*$"
	"audio|res://tests/ui_audio_test.tscn||AUDIO TEST PASSED"
)
# Sequential lane: these share the save file.
SAVE_LANE=(
	"progression|res://tests/progression_tests.tscn||RESULT: [0-9]+ passed, 0 failed"
	"ui_hud|res://tests/ui_hud_test.tscn||UI HUD TEST PASSED"
)
[ -f tests/qa_chapter1.tscn ] && SAVE_LANE+=("qa_chapter1|res://tests/qa_chapter1.tscn|-- --full|QA CHAPTER 1: [0-9]+ passed, 0 failed")

wanted() {  # name [filter words...]: true when no filter given or a word matches
	local n="$1"; shift
	[ $# -eq 0 ] && return 0
	for w in "$@"; do [[ "$n" == *"$w"* ]] && return 0; done
	return 1
}

run_one() {  # name scene args
	local name="$1" scene="$2" args="$3"
	# shellcheck disable=SC2086
	timeout "$TIMEOUT" "$G" --headless --path . "$scene" $args >"$OUT/$name.log" 2>&1
	echo $? >"$OUT/$name.code"
}

FILTER=("$@")
start=$(date +%s)
"$G" --headless --path . --import >/dev/null 2>&1   # refresh class cache once

for s in "${SUITES[@]}"; do
	IFS='|' read -r name scene args _ <<<"$s"
	wanted "$name" "${FILTER[@]}" && run_one "$name" "$scene" "$args" &
done
(
	for s in "${SAVE_LANE[@]}"; do
		IFS='|' read -r name scene args _ <<<"$s"
		wanted "$name" "${FILTER[@]}" && run_one "$name" "$scene" "$args"
	done
) &
wait

fail=0
for s in "${SUITES[@]}" "${SAVE_LANE[@]}"; do
	IFS='|' read -r name _ _ pattern <<<"$s"
	[ -f "$OUT/$name.code" ] || continue
	code=$(cat "$OUT/$name.code")
	summary=$(grep -E "passed|PASSED|FAIL|failed" "$OUT/$name.log" | tail -1)
	errors=$(grep -cE "SCRIPT ERROR|Parse Error" "$OUT/$name.log")
	if [ "$name" = "world" ]; then
		ok=$([ "$code" = 0 ] && ! grep -q "FAIL" "$OUT/$name.log" && echo y || echo n)
		summary="$(grep -cE '^\s*ok ' "$OUT/$name.log") checks ok, $(grep -c FAIL "$OUT/$name.log") failed"
	else
		ok=$(grep -qE "$pattern" "$OUT/$name.log" && [ "$errors" = 0 ] && echo y || echo n)
	fi
	if [ "$code" = 124 ]; then ok=n; summary="TIMEOUT after ${TIMEOUT}s"; fi
	if [ "$ok" = y ]; then printf "  PASS  %-12s %s\n" "$name" "$summary"
	else printf "  FAIL  %-12s %s (exit %s, script errors %s, log %s)\n" "$name" "$summary" "$code" "$errors" "$OUT/$name.log"; fail=1; fi
done
echo "Total wall time: $(( $(date +%s) - start ))s"
exit $fail
