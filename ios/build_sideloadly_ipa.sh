#!/bin/zsh
set -euo pipefail

project_dir=${0:A:h}
cd "$project_dir"

if ! xcodebuild -version >/dev/null 2>&1 && [[ -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

xcode_version=$(xcodebuild -version 2>/dev/null)
xcode_major=$(awk '/Xcode / { split($2, parts, "."); print parts[1] }' <<< "$xcode_version")
if [[ -z "$xcode_major" || "$xcode_major" -lt 26 ]]; then
    echo '需要 Xcode 26 或更高版本，才能编译 iOS 26 Liquid Glass App。' >&2
    exit 1
fi

task_build_dir=$(mktemp -d /tmp/hbust-ios26.XXXXXX)
product_dir="$task_build_dir/product"
payload_dir="$task_build_dir/Payload"
output_dir="$project_dir/dist"
output_ipa="$output_dir/湖科电量-iOS26-Sideloadly.ipa"
temporary_ipa="$task_build_dir/湖科电量-iOS26-Sideloadly.ipa"

xcodebuild \
    -quiet \
    -project "$project_dir/HBUSTPowerIOS.xcodeproj" \
    -target '湖科电量' \
    -configuration Release \
    -sdk iphoneos \
    OBJROOT="$task_build_dir/obj" \
    SYMROOT="$task_build_dir/sym" \
    SHARED_PRECOMPS_DIR="$task_build_dir/precompiled" \
    CONFIGURATION_BUILD_DIR="$product_dir" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY='' \
    build

app_path="$product_dir/HBUSTPowerIOS.app"
if [[ ! -d "$app_path" ]]; then
    echo '没有找到编译后的 HBUSTPowerIOS.app。' >&2
    exit 2
fi

mkdir -p "$payload_dir" "$output_dir"
ditto "$app_path" "$payload_dir/HBUSTPowerIOS.app"
(
    cd "$task_build_dir"
    zip -qry "$temporary_ipa" Payload
)
ditto "$temporary_ipa" "$output_ipa"

echo "$output_ipa"
