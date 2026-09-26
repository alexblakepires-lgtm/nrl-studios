#!/usr/bin/env bash
# Put one look's images on the site:  ./use-look.sh mixed
set -e; cd "$(dirname "$0")"
L="${1:?usage: ./use-look.sh quiet|cyber|mixed}"
[ -d "looks/$L/images" ] || { echo "no looks/$L/images"; exit 1; }
cp looks/$L/images/*.jpg images/
cp "looks/$L/prompts.tsv" prompts.tsv
echo "site now uses the $L look ($(ls looks/$L/images/*.jpg | wc -l | tr -d ' ') images). Refresh the preview."
if command -v sips >/dev/null 2>&1 && [ -f images/hero-lair.jpg ]; then
  sips --resampleWidth 1200 images/hero-lair.jpg --out images/og.jpg >/dev/null
  sips --cropToHeightWidth 630 1200 images/og.jpg >/dev/null
fi
