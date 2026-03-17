#!/usr/bin/env bash
# Master test runner for PhoenixBoot CLI and TUI test suites.

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

LOG_DIR="$PROJECT_ROOT/out/test-results/cli-tui"
mkdir -p "$LOG_DIR"

SUITES_RUN=0
SUITES_PASSED=0
SUITES_FAILED=0

STOP_ON_FAIL="${PB_TEST_STOP_ON_FAIL:-0}"
JSON_REPORT_PATH="${PB_TEST_JSON_REPORT:-}"
PB_TEST_SUITES_ENV="${PB_TEST_SUITES:-}"
NO_COLOR=0

declare -A SUITE_SCRIPT=(
    [cli]="scripts/testing/test-phoenixboot-cli.sh"
    [tui]="scripts/testing/test-phoenixboot-tui.sh"
    [pf]="scripts/testing/test-pf-tasks.sh"
)

declare -A SUITE_TITLE=(
    [cli]="PhoenixBoot CLI Tests"
    [tui]="PhoenixBoot TUI Tests"
    [pf]="PF Tasks Tests"
)

ALL_SUITES=("cli" "tui" "pf")
SELECTED_SUITES=()

declare -A SUITE_STATUS=()
declare -A SUITE_DURATION=()
declare -A SUITE_LOG=()

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<'EOF'
Usage: ./scripts/testing/test-all-cli-tui.sh [options]

Options:
  --suite <name[,name...]>  Run only selected suite(s): cli,tui,pf
                            Can be passed multiple times.
  --json-report <path>      Write machine-readable JSON summary.
  --stop-on-fail            Stop after first failed suite.
  --list-suites             Print available suites and exit.
  --no-color                Disable ANSI color output.
  -h, --help                Show this help and exit.

Environment variables:
  PB_TEST_SUITES            Comma-separated suite list (cli,tui,pf).
  PB_TEST_JSON_REPORT       Path for JSON report output.
  PB_TEST_STOP_ON_FAIL=1    Stop after first failed suite.
EOF
}

list_suites() {
    echo "Available suites:"
    echo "  cli - ${SUITE_TITLE[cli]}"
    echo "  tui - ${SUITE_TITLE[tui]}"
    echo "  pf  - ${SUITE_TITLE[pf]}"
}

disable_colors_if_needed() {
    if [ "$NO_COLOR" -eq 1 ] || [ ! -t 1 ]; then
        GREEN=''
        RED=''
        YELLOW=''
        BLUE=''
        NC=''
    fi
}

append_suites() {
    local suites_arg="$1"
    local suite
    local -a parsed=()
    IFS=',' read -r -a parsed <<< "$suites_arg"
    for suite in "${parsed[@]}"; do
        case "$suite" in
            cli|tui|pf)
                SELECTED_SUITES+=("$suite")
                ;;
            "")
                ;;
            *)
                echo "ERROR: Unknown suite '$suite'" >&2
                list_suites >&2
                exit 2
                ;;
        esac
    done
}

dedupe_selected_suites() {
    local suite
    local -a unique_suites=()
    declare -A seen=()
    for suite in "${SELECTED_SUITES[@]}"; do
        if [ -z "${seen[$suite]:-}" ]; then
            unique_suites+=("$suite")
            seen["$suite"]=1
        fi
    done
    SELECTED_SUITES=("${unique_suites[@]}")
}

write_json_report() {
    local target_path="$1"
    local suite
    local rows_file
    rows_file="$(mktemp)"
    trap 'rm -f "$rows_file"' RETURN

    for suite in "${SELECTED_SUITES[@]}"; do
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$suite" \
            "${SUITE_STATUS[$suite]:-not-run}" \
            "${SUITE_DURATION[$suite]:-0}" \
            "${SUITE_SCRIPT[$suite]}" \
            "${SUITE_TITLE[$suite]}" \
            "${SUITE_LOG[$suite]:-}" >> "$rows_file"
    done

    mkdir -p "$(dirname "$target_path")"
    python3 - "$target_path" "$rows_file" <<'PY'
import json
import pathlib
import sys
from datetime import datetime, timezone

target_path = pathlib.Path(sys.argv[1])
rows_path = pathlib.Path(sys.argv[2])

suites = []
for line in rows_path.read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    suite_id, status, duration, script, title, log_file = line.split("\t")
    suites.append(
        {
            "id": suite_id,
            "title": title,
            "status": status,
            "duration_seconds": int(duration),
            "script": script,
            "log_file": log_file,
        }
    )

summary = {
    "generated_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "suite_count": len(suites),
    "suites_run": sum(1 for s in suites if s["status"] != "not-run"),
    "suites_passed": sum(1 for s in suites if s["status"] == "passed"),
    "suites_failed": sum(1 for s in suites if s["status"] == "failed"),
}
summary["all_passed"] = summary["suites_failed"] == 0 and summary["suites_run"] > 0

payload = {"summary": summary, "suites": suites}
target_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
}

run_test_suite() {
    local suite="$1"
    local script_path="${SUITE_SCRIPT[$suite]}"
    local suite_title="${SUITE_TITLE[$suite]}"
    local log_path="$LOG_DIR/${suite}.log"
    local started_at
    local ended_at
    local duration
    local exit_code

    echo
    echo -e "${BLUE}-------------------------------------------------------${NC}"
    echo -e "${BLUE}Running suite: ${suite_title} (${suite})${NC}"
    echo -e "${BLUE}Log file: ${log_path}${NC}"
    echo -e "${BLUE}-------------------------------------------------------${NC}"

    if [ ! -f "$script_path" ]; then
        echo -e "${RED}FAIL: Test script not found: ${script_path}${NC}"
        SUITE_STATUS["$suite"]="failed"
        SUITE_DURATION["$suite"]=0
        SUITE_LOG["$suite"]="$log_path"
        return 1
    fi

    started_at="$(date +%s)"
    bash "$script_path" 2>&1 | tee "$log_path"
    exit_code="${PIPESTATUS[0]}"
    ended_at="$(date +%s)"
    duration=$((ended_at - started_at))

    SUITE_DURATION["$suite"]="$duration"
    SUITE_LOG["$suite"]="$log_path"
    if [ "$exit_code" -eq 0 ]; then
        SUITE_STATUS["$suite"]="passed"
        echo -e "${GREEN}PASS: ${suite_title} (${duration}s)${NC}"
        return 0
    fi

    SUITE_STATUS["$suite"]="failed"
    echo -e "${RED}FAIL: ${suite_title} (${duration}s)${NC}"
    return 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --suite)
            shift
            if [ "$#" -eq 0 ]; then
                echo "ERROR: --suite requires a value" >&2
                exit 2
            fi
            append_suites "$1"
            ;;
        --json-report)
            shift
            if [ "$#" -eq 0 ]; then
                echo "ERROR: --json-report requires a path" >&2
                exit 2
            fi
            JSON_REPORT_PATH="$1"
            ;;
        --stop-on-fail)
            STOP_ON_FAIL=1
            ;;
        --list-suites)
            list_suites
            exit 0
            ;;
        --no-color)
            NO_COLOR=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ -n "$PB_TEST_SUITES_ENV" ] && [ "${#SELECTED_SUITES[@]}" -eq 0 ]; then
    append_suites "$PB_TEST_SUITES_ENV"
fi

if [ "${#SELECTED_SUITES[@]}" -eq 0 ]; then
    SELECTED_SUITES=("${ALL_SUITES[@]}")
fi

dedupe_selected_suites
disable_colors_if_needed

echo "======================================================="
echo "PhoenixBoot CLI/TUI Test Runner"
echo "======================================================="
echo "Suites selected: ${SELECTED_SUITES[*]}"
echo "Log directory: ${LOG_DIR}"
if [ -n "$JSON_REPORT_PATH" ]; then
    echo "JSON report: ${JSON_REPORT_PATH}"
fi
echo

for suite in "${SELECTED_SUITES[@]}"; do
    SUITES_RUN=$((SUITES_RUN + 1))
    if run_test_suite "$suite"; then
        SUITES_PASSED=$((SUITES_PASSED + 1))
    else
        SUITES_FAILED=$((SUITES_FAILED + 1))
        if [ "$STOP_ON_FAIL" -eq 1 ]; then
            echo -e "${YELLOW}STOP: --stop-on-fail requested${NC}"
            break
        fi
    fi
done

if [ -n "$JSON_REPORT_PATH" ]; then
    write_json_report "$JSON_REPORT_PATH"
fi

echo
echo -e "${BLUE}====================== Final Summary ====================${NC}"
for suite in "${SELECTED_SUITES[@]}"; do
    echo "Suite: ${suite}"
    echo "  Name: ${SUITE_TITLE[$suite]}"
    echo "  Status: ${SUITE_STATUS[$suite]:-not-run}"
    echo "  Duration: ${SUITE_DURATION[$suite]:-0}s"
    echo "  Log: ${SUITE_LOG[$suite]:-(no log)}"
done
echo
echo "Suites selected: ${#SELECTED_SUITES[@]}"
echo "Suites run:      ${SUITES_RUN}"
echo -e "${GREEN}Suites passed:   ${SUITES_PASSED}${NC}"
echo -e "${RED}Suites failed:   ${SUITES_FAILED}${NC}"

if [ "$SUITES_FAILED" -eq 0 ] && [ "$SUITES_RUN" -gt 0 ]; then
    echo -e "${GREEN}RESULT: ALL REQUESTED SUITES PASSED${NC}"
    exit 0
fi

echo -e "${RED}RESULT: ONE OR MORE SUITES FAILED${NC}"
exit 1
