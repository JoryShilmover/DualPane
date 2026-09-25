#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jory Shilmover
#
# Records the README GIFs from the demo app's tours (see DemoTour.swift) on an iPad simulator.
# Needs Xcode and ffmpeg. Usage: record-gifs.sh [simulator UDID]
# Without a UDID, uses the first available "iPad Pro" simulator. Output goes to .github/media.
set -euo pipefail
cd "$(dirname "$0")"
repo=$(git rev-parse --show-toplevel)
out="$repo/.github/media"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

udid=${1:-$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"].values()
print(next(d["udid"] for group in devices for d in group if d["name"].startswith("iPad Pro")))')}

xcodebuild build -project DualPaneDemo.xcodeproj -scheme DualPaneDemo \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$work/build" CODE_SIGNING_ALLOWED=NO -quiet
xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl install "$udid" "$work/build/Build/Products/Debug-iphonesimulator/DualPaneDemo.app"

mkdir -p "$out"
for tour in fold hinge resize; do
    xcrun simctl launch --terminate-running-process "$udid" io.github.joryshilmover.DualPaneDemo -tour "$tour" >/dev/null
    sleep 2
    xcrun simctl io "$udid" recordVideo --codec=h264 --force "$work/$tour.mp4" >/dev/null 2>&1 &
    recorder=$!
    sleep 10
    kill -INT "$recorder"
    wait "$recorder" || true

    # The tour stage is 800 × 700 pt, centred on screen; iPads render at 2x.
    IFS=, read -r width height < <(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
        -of csv=p=0 "$work/$tour.mp4")
    crop="crop=1600:1400:$(( (width - 1600) / 2 )):$(( (height - 1400) / 2 ))"
    # One tour period (8 s) so the GIF loops seamlessly; kept small because every package clone downloads it.
    ffmpeg -v error -y -ss 1 -t 8 -i "$work/$tour.mp4" -vf "$crop,fps=12,scale=560:-1:flags=lanczos,split[a][b];\
[a]palettegen=max_colors=48:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle" "$out/$tour.gif"
    echo "$out/$tour.gif"
done
xcrun simctl terminate "$udid" io.github.joryshilmover.DualPaneDemo 2>/dev/null || true
