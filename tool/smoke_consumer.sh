#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
if [[ "$platform" != android && "$platform" != ios ]]; then
  echo 'Usage: tool/smoke_consumer.sh android|ios' >&2
  exit 2
fi

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/admobkit-consumer.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
app_dir="$work_dir/consumer"

flutter create --platforms="$platform" --org dev.admobkit.smoke \
  --project-name admobkit_consumer "$app_dir"
cd "$app_dir"
flutter pub add "flutter_admob_kit@{path: $repo_dir}"

cat > lib/main.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:flutter_admob_kit/flutter_admob_kit.dart';

void main() => runApp(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          NativeAdWidget.mediumNative(height: 130),
          NativeAdWidget.bigNative(height: 280),
          BannerAdWidget.large(),
        ]),
      ),
    ));
DART

flutter analyze lib/main.dart

if [[ "$platform" == android ]]; then
  flutter build apk --debug
else
  # google_mobile_ads 9.1.0 cannot compile its private Beta header with
  # use_frameworks!; see upstream issue #1472. The package supports a
  # CocoaPods host without that setting and an SPM host.
  python3 - "$app_dir/ios/Podfile" <<'PY'
from pathlib import Path
import sys

podfile = Path(sys.argv[1])
source = podfile.read_text()
assert '  use_frameworks!\n' in source
podfile.write_text(source.replace('  use_frameworks!\n', ''))
PY
  flutter build ios --simulator --debug --no-codesign
fi
