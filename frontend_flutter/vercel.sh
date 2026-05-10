#!/bin/bash

echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable

echo "Setting up PATH..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Running Flutter Pub Get..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release
