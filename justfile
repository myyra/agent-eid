set shell := ["bash", "-euo", "pipefail", "-c"]

# Build the signed Release app using the selected Xcode installation.
build:
    xcodebuild -project AgentEID.xcodeproj -scheme AgentEID -configuration Release -destination 'generic/platform=macOS' -allowProvisioningUpdates build

# Replace the installed app and launch it. Override the destination if needed.
install destination="/Applications": build
    #!/usr/bin/env bash
    set -euo pipefail
    build_directory=$(xcodebuild -project AgentEID.xcodeproj -scheme AgentEID -configuration Release -destination 'generic/platform=macOS' -showBuildSettings | awk '
        /^Build settings for .* target / { app = $0 ~ /target AgentEID:$/ }
        app && $1 == "TARGET_BUILD_DIR" { sub(/^[[:space:]]*TARGET_BUILD_DIR = /, ""); print }
    ')
    test -d "$build_directory/AgentEID.app"
    destination={{quote(destination)}}
    app="$destination/AgentEID.app"
    mkdir -p "$destination"
    if pgrep -x AgentEID >/dev/null; then
        killall AgentEID
    fi
    rm -rf "$app"
    ditto "$build_directory/AgentEID.app" "$app"
    open "$app"
