import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/core/services/weather_service.dart';
import 'package:kiwit_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kiwit_app/features/home/presentation/screens/home_screen.dart';
import 'package:kiwit_app/features/home/presentation/widgets/hero_banner_card.dart';
import 'package:kiwit_app/features/notifications/presentation/notification_controller.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'inspection_sync_test.dart' show MemoryLocal, owner;
import 'notification_flow_test.dart' show MemoryNotifications;

WeatherData sampleWeather() => WeatherData.fromJson({
  'current': {
    'wind_speed_10m': 90,
    'temperature_2m': 29,
    'relative_humidity_2m': 80,
    'weather_code': 95,
  },
});

void main() {
  test('missing or malformed weather cannot become invented fair weather', () {
    expect(() => WeatherData.fromJson({}), throwsFormatException);
    expect(
      () => WeatherData.fromJson({
        'current': {'temperature_2m': 25},
      }),
      throwsFormatException,
    );
    expect(
      () => WeatherData.fromJson({
        'current': {
          'wind_speed_10m': double.nan,
          'temperature_2m': 29,
          'relative_humidity_2m': 80,
          'weather_code': 95,
        },
      }),
      throwsFormatException,
    );
    expect(sampleWeather().condition, 'Hujan Badai');
  });

  testWidgets(
    'weather failure shows unavailable; tap retries and details contain timestamp without safe claim',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroBannerCard(
                weatherLoader: () async =>
                    ++calls == 1 ? null : sampleWeather(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cuaca belum tersedia'), findsOneWidget);
      expect(find.text('Angin 18 km/h'), findsNothing);
      await tester.tap(find.text('Cuaca belum tersedia'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.tap(find.text('Angin 90 km/h'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Diperbarui '), findsOneWidget);
      expect(find.textContaining('Hujan Badai'), findsOneWidget);
      expect(find.textContaining('angin aman'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Home refresh and app resume refresh weather alongside inspections',
    (tester) async {
      var calls = 0;
      final source = InspectionController(ownerId: owner, local: MemoryLocal());
      await source.refresh();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            currentUserIdProvider.overrideWithValue(owner),
            userProfileProvider.overrideWith((ref) async => null),
            inspectionControllerProvider.overrideWith((ref) => source),
            notificationStorageProvider.overrideWith(
              (ref) => MemoryNotifications(),
            ),
          ],
          child: MaterialApp(
            home: HomeScreen(
              weatherLoader: () async {
                calls++;
                return sampleWeather();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      final refresh = tester.state<RefreshIndicatorState>(
        find.byType(RefreshIndicator),
      );
      unawaited(refresh.show());
      await tester.pumpAndSettle();
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
