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
  flutter build ios --simulator --debug --no-codesign
fi
