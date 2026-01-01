#!/usr/bin/env bash
# A script to hard-burn subtitles into a movie. I use it for streaming a movie with chromecast because that terrible application does not support .srt subitles
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <input_video.mp4> <subtitles.srt> <output_video.mp4>"
    exit 1
fi

INPUT_VIDEO="$1"
SUBS="$2"
OUTPUT_VIDEO="$3"

ffmpeg -i "$INPUT_VIDEO" \
    -vf "subtitles='${SUBS}':force_style='FontSize=22,Outline=1,Shadow=1'" \
    -c:a copy \
    "$OUTPUT_VIDEO"
