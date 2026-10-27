import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final buildGradle = File('android/app/build.gradle').readAsStringSync();
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final appName = File(
    'android/app/src/main/res/values/strings.xml',
  ).readAsStringSync();
  final activity = File(
    'android/app/src/main/kotlin/com/freakinrkb/nutritrack/MainActivity.kt',
  );

  group('Android app identity', () {
    test('uses the personal application id and namespace', () {
      expect(buildGradle, contains('namespace "com.freakinrkb.nutritrack"'));
      expect(
        buildGradle,
        contains('applicationId "com.freakinrkb.nutritrack"'),
      );
      expect(manifest, contains('package="com.freakinrkb.nutritrack"'));
    });

    test('does not keep the upstream application id', () {
      for (final source in [buildGradle, manifest]) {
        expect(source,
            isNot(contains('com.opennutritracker.ont.opennutritracker')));
      }
    });

    test('launches a MainActivity in the personal package', () {
      expect(activity.existsSync(), isTrue);
      expect(
        activity.readAsStringSync(),
        startsWith('package com.freakinrkb.nutritrack'),
      );
    });

    test('labels the full build NutriTrack Personal', () {
      expect(appName,
          contains('<string name="app_name">NutriTrack Personal</string>'));
    });
  });
}
