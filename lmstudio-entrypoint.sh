#!/usr/bin/env bash
# Note: no 'set -e' — lms daemon commands segfault on restart and must not kill the script
set -uo pipefail

LMS_PORT="${LMS_PORT:-1234}"
LMS_SERVER_HOST="${LMS_SERVER_HOST:-0.0.0.0}"

log() { printf '[lmstudio] %s\n' "$*"; }

mkdir -p /data/models /data/conversations

log "Starting LM Studio headless ($(lms --version 2>/dev/null || echo 'unknown version'))"

# Kill stale llmster from previous container run before starting a new daemon
pkill -f llmster 2>/dev/null; sleep 2

# Start daemon with retries (may segfault transiently on first attempt)
for attempt in 1 2 3; do
    lms daemon up 2>&1 && break || true
    log "Daemon start attempt ${attempt} failed, retrying in 3s..."
    sleep 3
done

# Wait for daemon socket to be ready
for _ in $(seq 1 30); do
    lms server status >/dev/null 2>&1 && break || true
    sleep 2
done

lms server start --port "${LMS_PORT}" --bind "${LMS_SERVER_HOST}" --cors || true

log "API listening on ${LMS_SERVER_HOST}:${LMS_PORT}"
log "Models directory: /data/models"

if [ -n "${LMS_PREFETCH:-}" ]; then
    for model in ${LMS_PREFETCH}; do
        log "Prefetching model: ${model}"
        lms get --yes "${model}" || log "WARN: prefetch failed for ${model}"
    done
fi

if [ -n "${LMS_LOAD:-}" ]; then
    LOAD_CMD="lms load ${LMS_LOAD}"
    [ -n "${LMS_CONTEXT_LENGTH:-}" ] && LOAD_CMD="${LOAD_CMD} --context-length ${LMS_CONTEXT_LENGTH}"
    [ -n "${LMS_GPU:-}" ]            && LOAD_CMD="${LOAD_CMD} --gpu ${LMS_GPU}"
    [ -n "${LMS_IDENTIFIER:-}" ]     && LOAD_CMD="${LOAD_CMD} --identifier ${LMS_IDENTIFIER}"
    log "Loading model: ${LOAD_CMD}"
    eval "${LOAD_CMD}" || log "WARN: failed to load ${LMS_LOAD}"
fi

# Stream logs; fall back to infinite sleep so the container stays up even if lms exits
lms log stream || { log "log stream exited, keeping container alive"; exec tail -f /dev/null; }
