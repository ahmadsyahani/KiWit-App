import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/core/services/supabase_service.dart';
import 'package:kiwit_app/features/auth/data/models/user_profile.dart';
import 'package:kiwit_app/features/auth/data/repositories/auth_repository.dart';
import 'package:kiwit_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kiwit_app/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_result_data.dart';

import 'inspection_sync_test.dart' show recordAt;
import 'scan_object_validation_test.dart' show boxes, masks;
import 'package:kiwit_app/core/services/onnx_service.dart';

class LoopbackHttpOverrides extends HttpOverrides {}

class RecoveryController extends AuthController {
  RecoveryController(super.ref, this.succeed);
  final bool succeed;
  String? received;
  int signOutCalls = 0;
  bool signOutSucceeds = true;
  @override
  Future<bool> updatePassword(String password) async {
    received = password;
    return succeed;
  }

  @override
  Future<bool> signOut() async {
    signOutCalls++;
    return signOutSucceeds;
  }
}

void main() {
  test('late readiness changes invalidate the cached provider', () {
    final old = SupabaseService.readiness.value;
    final container = ProviderContainer();
    addTearDown(() {
      container.dispose();
      SupabaseService.readiness.value = old;
    });
    SupabaseService.readiness.value = false;
    expect(container.read(supabaseReadinessProvider), isFalse);
    SupabaseService.readiness.value = true;
    expect(container.read(supabaseReadinessProvider), isTrue);
  });

  test('missing profile fields never invent an NIP or activity totals', () {
    final profile = UserProfile.fromJson({
      'id': 'officer',
      'email': 'officer@example.test',
    });
    expect(profile.nip, isEmpty);
    expect(profile.inspectedTreesCount, 0);
    expect(profile.reportsCount, 0);
  });

  test(
    'different box widths cannot invent cm or change the photo priority',
    () {
      final service = OnnxService();
      YoloSegmentationResult analyze(double width, int classId) =>
          service.processSegmentationOutputs(
            out0Raw: boxes(width: width, classId: classId),
            out1Raw: masks(),
            defaultImpact: EnvironmentalImpact.medium,
          )!;
      final narrow = analyze(120, 1);
      final wide = analyze(480, 1);
      expect(narrow.estimatedDbhCm, 0);
      expect(wide.estimatedDbhCm, 0);
      expect(narrow.failurePotential, wide.failurePotential);
      expect(narrow.riskDecision.riskLevel, wide.riskDecision.riskLevel);
      for (final classId in [0, 1, 2]) {
        final result = analyze(320, classId);
        expect(result.isJamurPelapuk, isFalse);
        expect(result.detectedCondition, isNot(contains('Jamur')));
        expect(result.riskDecision.actionTitle, isNot(contains('Tebang')));
        expect(result.riskDecision.actionTitle, isNot('Aman'));
        if (classId == 0) expect(result.persentaseLuka, 0);
      }
    },
  );

  test(
    'measurement provenance survives storage and legacy estimates stay unverified',
    () {
      final old = recordAt('legacy', DateTime(2026, 10, 19)).data;
      expect(old.hasMeasuredDiameter, isFalse);
      expect(old.hasMeasuredInclination, isFalse);
      expect(old.hasPathologyAssessment, isFalse);
      final measured = old.copyWith(diameter: 44, hasMeasuredDiameter: true);
      final restored = InspectionResultData.fromJson(measured.toJson());
      expect(restored.diameter, 44);
      expect(restored.hasMeasuredDiameter, isTrue);
      expect(restored.hasMeasuredInclination, isFalse);
      final legacy = Map<String, dynamic>.from(measured.toJson())
        ..remove('hasMeasuredDiameter')
        ..remove('hasMeasuredInclination')
        ..remove('hasPathologyAssessment');
      expect(
        InspectionResultData.fromJson(legacy).hasMeasuredDiameter,
        isFalse,
      );
    },
  );

  group('Auth repository with local HTTP responses (no live account)', () {
    late HttpServer server;
    late SupabaseClient client;
    late AuthRepository repository;
    late Map<String, dynamic> user;
    Map<String, dynamic>? recoveryBody;
    Uri? recoveryUri;
    Map<String, dynamic>? signupBody;
    String? updatedPassword;

    setUp(() async {
      recoveryBody = null;
      recoveryUri = null;
      signupBody = null;
      updatedPassword = null;
      user = {
        'id': '11111111-1111-4111-8111-111111111111',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'officer@example.test',
        'created_at': '2026-10-19T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {'full_name': 'Nama lama', 'nip': ''},
      };
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final raw = await utf8.decoder.bind(request).join();
        final body = raw.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
        Object response = {};
        if (request.uri.path.endsWith('/token')) {
          response = {
            'access_token': 'test-access-token',
            'refresh_token': 'test-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          };
        } else if (request.uri.path.endsWith('/user') &&
            request.method == 'PUT') {
          if (body['data'] is Map) {
            user = {
              ...user,
              'user_metadata': {
                ...user['user_metadata'] as Map,
                ...body['data'] as Map,
              },
            };
          }
          updatedPassword = body['password'] as String?;
          response = user;
        } else if (request.uri.path.endsWith('/recover')) {
          recoveryBody = body;
          recoveryUri = request.uri;
        } else if (request.uri.path.endsWith('/signup')) {
          signupBody = body;
          response = user;
        } else if (request.uri.path.endsWith('/profiles') &&
            request.method == 'GET') {
          response = [
            {
              'id': user['id'],
              'full_name': 'Nama lama dari tabel',
              'nip': 'NIP-LAMA',
            },
          ];
        } else if (request.uri.path.endsWith('/profiles')) {
          request.response.statusCode = 403;
          response = {'message': 'Mirror write refused', 'code': '42501'};
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(response));
        await request.response.close();
      });
      // Widget binding substitutes HTTP with 400 responses. Opt out only while
      // constructing this loopback-only client, leaving widget tests isolated.
      client = HttpOverrides.runWithHttpOverrides(
        () => SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'test-key',
          authOptions: const AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.implicit,
          ),
        ),
        LoopbackHttpOverrides(),
      );
      repository = AuthRepository(client);
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    test(
      'metadata update remains visible when the optional DB mirror fails',
      () async {
        await repository.signIn(
          email: 'officer@example.test',
          password: 'test-password',
        );
        final original = await repository.fetchUserProfile();
        await repository.updateUserProfile(
          original!.copyWith(fullName: 'Nama baru', nip: ''),
        );
        final reloaded = await repository.fetchUserProfile();
        expect(reloaded!.fullName, 'Nama baru');
        expect(reloaded.nip, isEmpty);
      },
    );

    test('reset email requests use the registered app callback', () async {
      await repository.sendPasswordResetEmail(' officer@example.test ');
      expect(recoveryBody!['email'], 'officer@example.test');
      expect(
        recoveryUri!.queryParameters['redirect_to'],
        AuthRepository.passwordRecoveryRedirect,
      );
    });

    test('new accounts start with zero activity totals', () async {
      await repository.signUp(
        email: 'officer@example.test',
        password: 'test-password',
        fullName: 'Petugas',
        nip: '',
      );
      final metadata = signupBody!['data'] as Map;
      expect(metadata['inspected_trees_count'], 0);
      expect(metadata['reports_count'], 0);
    });

    test('password update requires a recovery/auth session', () async {
      await expectLater(
        repository.updatePassword('new-password'),
        throwsA(isA<AuthException>()),
      );
    });

    test(
      'password update reaches Auth after a valid session is established',
      () async {
        await repository.signIn(
          email: 'officer@example.test',
          password: 'test-password',
        );
        await repository.updatePassword('new-password');
        expect(updatedPassword, 'new-password');
      },
    );
  });

  for (final succeed in [true, false]) {
    testWidgets(
      'recovery form validates, and handles update success=$succeed',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        late RecoveryController controller;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              passwordRecoveryPendingProvider.overrideWith((ref) => true),
              authControllerProvider.overrideWith(
                (ref) => controller = RecoveryController(ref, succeed),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.6)),
                child: child!,
              ),
              home: const ResetPasswordScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Simpan kata sandi'));
        await tester.tap(find.text('Simpan kata sandi'));
        await tester.pumpAndSettle();
        expect(find.text('Gunakan minimal 8 karakter.'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'new-password',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'mismatch');
        await tester.ensureVisible(find.text('Simpan kata sandi'));
        await tester.tap(find.text('Simpan kata sandi'));
        await tester.pumpAndSettle();
        expect(find.text('Kata sandi belum sama.'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'new-password',
        );
        await tester.ensureVisible(find.text('Simpan kata sandi'));
        await tester.tap(find.text('Simpan kata sandi'));
        await tester.pumpAndSettle();
        expect(controller.received, 'new-password');
        expect(
          find.text('Oke, masuk kembali'),
          succeed ? findsOneWidget : findsNothing,
        );
        expect(controller.signOutCalls, 0);
        if (succeed) {
          controller.signOutSucceeds = false;
          await tester.ensureVisible(find.text('Oke, masuk kembali'));
          await tester.tap(find.text('Oke, masuk kembali'));
          await tester.pumpAndSettle();
          expect(controller.signOutCalls, 1);
          expect(
            ProviderScope.containerOf(
              tester.element(find.byType(ResetPasswordScreen)),
            ).read(passwordRecoveryPendingProvider),
            isTrue,
          );
          expect(
            find.textContaining('sesi belum berhasil diakhiri'),
            findsOneWidget,
          );
          controller.signOutSucceeds = true;
          await tester.ensureVisible(find.text('Oke, masuk kembali'));
          await tester.tap(find.text('Oke, masuk kembali'));
          await tester.pumpAndSettle();
          expect(controller.signOutCalls, 2);
          expect(
            ProviderScope.containerOf(
              tester.element(find.byType(ResetPasswordScreen)),
            ).read(passwordRecoveryPendingProvider),
            isFalse,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'recovery event covers an existing route and stays through userUpdated',
    (tester) async {
      final events = StreamController<AuthState>();
      final container = ProviderContainer(
        overrides: [authStateProvider.overrideWith((ref) => events.stream)],
      );
      addTearDown(() async {
        container.dispose();
        await events.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => AuthRecoveryGuard(child: child!),
            home: const Scaffold(body: Text('Existing route')),
          ),
        ),
      );
      await tester.pump();
      events.add(AuthState(AuthChangeEvent.passwordRecovery, null));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      events.add(AuthState(AuthChangeEvent.userUpdated, null));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      events.add(AuthState(AuthChangeEvent.signedOut, null));
      await tester.pumpAndSettle();
      expect(find.byType(ResetPasswordScreen), findsNothing);
    },
  );
}
