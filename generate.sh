#!/usr/bin/env bash
# NRL Studios · image generation with Higgsfield CLI + Nano Banana 2
# Images are compressed before they go in the repo.
#
#   ./generate.sh              generate every image that doesn't exist yet
#   ./generate.sh hero-lair    (re)generate just one image
#   FORCE=1 ./generate.sh      regenerate everything
#   refs/<name>.jpg            optional reference photo for that image (your desk, gear, etc.)
#
# Needs: higgsfield CLI logged in (higgsfield auth login), curl, and macOS sips (built in).

set -u
cd "$(dirname "$0")"

MODEL="nano_banana_2"
LOOK="${LOOK:-}"   # optional: LOOK=mixed ./generate.sh  (uses looks/<LOOK>/ and saves there, site untouched)
RES="2k"
STYLE=", neo-noir cyberpunk, low life high tech, gritty and cluttered yet sleek, glowing neon edge-light lines on matte black surfaces, phosphor-amber as the main light with accents of hot magenta and electric cyan, subtle iridescent psychedelic color shifts, deep ink-violet shadows, wet reflective surfaces, cinematic, photorealistic, sharp detail, subtle film grain, full-bleed image with no border or frame, no people, no text, no letters, no numbers, no signs with writing, no logos, no brand badges, no watermark"

PROMPTS="prompts.tsv"; IMG="images"
if [ -n "$LOOK" ]; then
  [ -d "looks/$LOOK" ] || { echo "no such look: looks/$LOOK"; exit 1; }
  PROMPTS="looks/$LOOK/prompts.tsv"; IMG="looks/$LOOK/images"
  STYLE="$(cat "looks/$LOOK/style.txt")"
  echo "look: $LOOK  (saving to $IMG, the live site images are not touched)"
fi
mkdir -p "$IMG/raw"
ONLY="${1:-}"

optimize () {  # raw png -> web jpg, long edge 2400px, quality 82
  local in="$1" out="$2"
  if command -v sips >/dev/null 2>&1; then
    sips -Z 2400 -s format jpeg -s formatOptions 82 "$in" --out "$out" >/dev/null
  elif command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -loglevel error -y -i "$in" -vf "scale='min(2400,iw)':-2" -q:v 3 "$out"
  else
    echo "  ! no sips or ffmpeg found, copying raw file (large!)"; cp "$in" "${out%.jpg}.png"
  fi
}

while IFS=$'\t' read -r NAME ASPECT PROMPT <&3; do
  case "$NAME" in ''|\#*) continue ;; esac
  [ -n "$ONLY" ] && [ "$NAME" != "$ONLY" ] && continue
  OUT="$IMG/$NAME.jpg"
  if [ -f "$OUT" ] && [ -z "${FORCE:-}" ] && [ -z "$ONLY" ]; then
    echo "skip  $NAME (exists)"; continue
  fi

  echo "gen   $NAME  [$ASPECT]"
  LOG="$IMG/raw/$NAME.log"
  # Optional: drop your own photo at refs/<name>.jpg (or .png) to guide this image
  REF=""
  for ext in jpg jpeg png webp; do [ -f "refs/$NAME.$ext" ] && REF="refs/$NAME.$ext" && break; done
  if [ -n "$REF" ]; then
    echo "      using reference $REF"
    higgsfield generate create "$MODEL" --prompt "$PROMPT$STYLE" --image "$REF" \
      --aspect_ratio "$ASPECT" --resolution "$RES" --wait > "$LOG" 2>&1 < /dev/null
  else
    higgsfield generate create "$MODEL" --prompt "$PROMPT$STYLE" \
      --aspect_ratio "$ASPECT" --resolution "$RES" --wait > "$LOG" 2>&1 < /dev/null
  fi

  URL=$(grep -Eo 'https://[^"[:space:]]+' "$LOG" | grep -Ei '\.(png|jpe?g|webp)' | head -1)
  [ -z "$URL" ] && URL=$(grep -Eo 'https://[^"[:space:]]+' "$LOG" | head -1)
  if [ -z "$URL" ]; then
    echo "  ! no result URL, see $LOG"; continue
  fi

  RAW="$IMG/raw/$NAME.png"
  curl -fsSL "$URL" -o "$RAW" || { echo "  ! download failed: $URL"; continue; }
  optimize "$RAW" "$OUT"
  echo "  ok  $OUT  ($(du -h "$OUT" | cut -f1))"
done 3< "$PROMPTS"

# Social share card (1200x630) cropped from the hero
if [ -z "$LOOK" ] && [ -f images/hero-lair.jpg ] && command -v sips >/dev/null 2>&1; then
  sips --resampleWidth 1200 images/hero-lair.jpg --out images/og.jpg >/dev/null
  sips --cropToHeightWidth 630 1200 images/og.jpg >/dev/null
  echo "ok    images/og.jpg"
fi

echo "done. raw PNGs stay in images/raw/ (git-ignored)."
