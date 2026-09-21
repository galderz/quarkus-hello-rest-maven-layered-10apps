#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$ROOT/micronaut-application-layer/target"
MEASURE_INTERVAL="${MEASURE_INTERVAL:-10}"
COPIES_PER_APP="${COPIES_PER_APP:-1}"
REUSE_APP_BINARIES="${REUSE_APP_BINARIES:-0}"
SUMMARY_ONLY="${SUMMARY_ONLY:-0}"

source "$ROOT/scripts/app-config.sh"
source "$ROOT/scripts/memory-lib.sh"

validate_copies_per_app "$COPIES_PER_APP"

PIDS=()
LOG_FILES=()
BINARY_NAMES=()
CLEANED_UP=0

require_runtime_artifacts() {
    if ! command -v curl >/dev/null 2>&1; then
        echo "Missing required command: curl" >&2
        exit 1
    fi

    if [[ ! -d "$TARGET_DIR" ]]; then
        echo "Missing target directory: $TARGET_DIR" >&2
        echo "Build the layered apps first with ./build-all-apps.sh" >&2
        exit 1
    fi

    if [[ ! -f "$TARGET_DIR/libjavabaselayer.so" ]]; then
        echo "Missing shared base layer: $TARGET_DIR/libjavabaselayer.so" >&2
        echo "Build the layered apps first with ./build-all-apps.sh" >&2
        exit 1
    fi

    for app in "${LANGUAGES[@]}"; do
        image_name="$(image_name_for_app "$app")"
        for ((copy = 1; copy <= COPIES_PER_APP; copy++)); do
            if [[ "$REUSE_APP_BINARIES" -eq 1 ]]; then
                binary_name="$image_name"
            else
                binary_name="$(copy_name_for_image "$image_name" "$copy" "$COPIES_PER_APP")"
            fi
            if [[ ! -x "$TARGET_DIR/$binary_name" ]]; then
                echo "Missing layered app binary: $TARGET_DIR/$binary_name" >&2
                if [[ "$REUSE_APP_BINARIES" -eq 1 ]]; then
                    echo "Build the layered apps first with ./build-all-apps.sh" >&2
                else
                    echo "Build the layered apps first with COPIES_PER_APP=$COPIES_PER_APP ./build-all-apps.sh" >&2
                fi
                exit 1
            fi
        done
    done
}

cleanup() {
    if [[ "$CLEANED_UP" -eq 1 ]]; then
        return
    fi
    CLEANED_UP=1

    echo
    echo "Stopping all apps..."
    for pid in "${PIDS[@]:-}"; do
        kill "$pid" 2>/dev/null || true
    done
    for pid in "${PIDS[@]:-}"; do
        wait "$pid" 2>/dev/null || true
    done
    for log_file in "${LOG_FILES[@]:-}"; do
        rm -f "$log_file"
    done
}

trap cleanup EXIT INT TERM

require_runtime_artifacts

export LD_LIBRARY_PATH="$TARGET_DIR:${LD_LIBRARY_PATH:-}"

TOTAL_APPS=$((${#LANGUAGES[@]} * COPIES_PER_APP))
echo "=== Starting $TOTAL_APPS Micronaut app instances sharing libjavabaselayer.so ==="
echo

for i in "${!LANGUAGES[@]}"; do
    lang="${LANGUAGES[$i]}"
    image_name="$(image_name_for_app "$lang")"

    for ((copy = 1; copy <= COPIES_PER_APP; copy++)); do
        port=$((PORTS[$i] + (copy - 1) * ${#LANGUAGES[@]}))
        if [[ "$REUSE_APP_BINARIES" -eq 1 ]]; then
            binary_name="$image_name"
        else
            binary_name="$(copy_name_for_image "$image_name" "$copy" "$COPIES_PER_APP")"
        fi
        log_file="$(mktemp)"

        "$TARGET_DIR/$binary_name" "--micronaut.server.port=$port" >"$log_file" 2>&1 &
        pid=$!

        PIDS+=("$pid")
        LOG_FILES+=("$log_file")
        BINARY_NAMES+=("$binary_name")
        if [[ "$SUMMARY_ONLY" -ne 1 ]]; then
            echo "  Started $binary_name on port $port (PID $pid)"
        fi
    done
done

echo
echo "Waiting for all endpoints to come up..."
for i in "${!LANGUAGES[@]}"; do
    lang="${LANGUAGES[$i]}"
    for ((copy = 1; copy <= COPIES_PER_APP; copy++)); do
        port=$((PORTS[$i] + (copy - 1) * ${#LANGUAGES[@]}))
        log_index=$((i * COPIES_PER_APP + copy - 1))
        ok=0

        for _ in {1..60}; do
            if curl -fsS "http://127.0.0.1:$port/hello/$lang" >/dev/null 2>&1; then
                ok=1
                break
            fi
            sleep 1
        done

        if [[ "$ok" -ne 1 ]]; then
            echo "ERROR: hello-$lang copy $copy on port $port did not start cleanly." >&2
            tail -n 40 "${LOG_FILES[$log_index]}" >&2 || true
            exit 1
        fi
    done
done

echo
echo "All $TOTAL_APPS app instances are running."
if [[ "$SUMMARY_ONLY" -ne 1 ]]; then
    echo "Endpoints:"
    for i in "${!LANGUAGES[@]}"; do
        lang="${LANGUAGES[$i]}"
        for ((copy = 1; copy <= COPIES_PER_APP; copy++)); do
            port=$((PORTS[$i] + (copy - 1) * ${#LANGUAGES[@]}))
            echo "  curl http://127.0.0.1:$port/hello/$lang"
        done
    done
fi

echo
echo "Memory usage:"

while true; do
    total_rss=0
    total_pss=0
    alive=0

    if [[ "$SUMMARY_ONLY" -ne 1 ]]; then
        printf "  %-16s %8s %8s %s\n" "APP" "RSS" "PSS" "PID"
    fi
    for i in "${!PIDS[@]}"; do
        pid="${PIDS[$i]}"
        binary_name="${BINARY_NAMES[$i]}"

        if kill -0 "$pid" 2>/dev/null; then
            read -r rss pss < <(tree_memory_kb "$pid")
            if [[ "$SUMMARY_ONLY" -ne 1 ]]; then
                printf "  %-16s %5s KB %5s KB  (PID %s)\n" "$binary_name" "$rss" "$pss" "$pid"
            fi
            total_rss=$((total_rss + rss))
            total_pss=$((total_pss + pss))
            alive=$((alive + 1))
        elif [[ "$SUMMARY_ONLY" -ne 1 ]]; then
            printf "  %-16s %8s %8s  (%s)\n" "$binary_name" "dead" "dead" "$pid"
        fi
    done

    total_rss_human="$(human_memory_kb "$total_rss")"
    total_pss_human="$(human_memory_kb "$total_pss")"
    if [[ "$SUMMARY_ONLY" -eq 1 ]]; then
        printf "  TOTAL (%d/%d alive)  RSS: %s  PSS: %s\n" \
            "$alive" "$TOTAL_APPS" "$total_rss_human" "$total_pss_human"
    else
        printf "  TOTAL  RSS: %s  PSS: %s\n" "$total_rss_human" "$total_pss_human"
    fi
    echo
    sleep "$MEASURE_INTERVAL"
done
