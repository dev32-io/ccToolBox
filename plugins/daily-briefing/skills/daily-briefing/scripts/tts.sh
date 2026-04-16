#!/bin/bash
set -euo pipefail

TEXT_FILE="${1:?Usage: tts.sh <text_file> <output_path> [voice]}"
OUTPUT_PATH="${2:?Usage: tts.sh <text_file> <output_path> [voice]}"
VOICE="${3:-en-US-AvaMultilingualNeural}"
CONTAINER_NAME="daily-briefing-tts"
PORT=5050
MAX_WAIT=30

# Validate input
if [ ! -f "$TEXT_FILE" ]; then
    echo "Error: Text file not found: $TEXT_FILE" >&2
    exit 1
fi

TEXT_CONTENT=$(cat "$TEXT_FILE")

# Kill stale container from previous run if it exists
if docker ps -aq --filter "name=$CONTAINER_NAME" | grep -q .; then
    echo "Removing stale TTS container..." >&2
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# Cleanup function to ensure container is always removed
cleanup() {
    if docker ps -q --filter "name=$CONTAINER_NAME" | grep -q .; then
        echo "Stopping TTS container..." >&2
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

# Start container
echo "Starting TTS container..." >&2
docker run -d --rm -p "$PORT:$PORT" --name "$CONTAINER_NAME" \
    -e REQUIRE_API_KEY=false \
    travisvn/openai-edge-tts:latest-ffmpeg >/dev/null

# Wait for container to be ready
echo "Waiting for TTS service..." >&2
WAITED=0
until curl -s -o /dev/null -w '' "http://localhost:$PORT" 2>/dev/null; do
    sleep 1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        echo "Error: TTS service did not start within ${MAX_WAIT}s" >&2
        exit 1
    fi
done
echo "TTS service ready." >&2

# Generate speech (retry up to 2 times on 5xx errors)
MAX_RETRIES=2
ATTEMPT=0
while true; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "Generating audio (attempt $ATTEMPT)..." >&2
    HTTP_CODE=$(curl -s -X POST "http://localhost:$PORT/v1/audio/speech" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg text "$TEXT_CONTENT" --arg voice "$VOICE" '{
            input: $text,
            voice: $voice,
            model: "tts-1",
            response_format: "mp3"
        }')" \
        -o "$OUTPUT_PATH" \
        -w "%{http_code}")

    if [ "$HTTP_CODE" -eq 200 ]; then
        break
    fi

    if [ "$HTTP_CODE" -ge 500 ] && [ "$ATTEMPT" -le "$MAX_RETRIES" ]; then
        echo "Warning: TTS returned HTTP $HTTP_CODE, retrying in 3s..." >&2
        rm -f "$OUTPUT_PATH"
        sleep 3
        continue
    fi

    echo "Error: TTS request failed with HTTP $HTTP_CODE" >&2
    rm -f "$OUTPUT_PATH"
    exit 1
done

echo "Audio saved to $OUTPUT_PATH" >&2
