import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/core/theme/app_theme.dart';
import 'package:kiwit_app/features/auth/data/models/user_profile.dart';
import 'package:kiwit_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kiwit_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:kiwit_app/features/auth/presentation/screens/login_screen.dart';
import 'package:kiwit_app/features/notifications/presentation/notification_controller.dart';
import 'package:kiwit_app/features/notifications/presentation/notification_screen.dart';
import 'package:kiwit_app/features/notifications/presentation/pending_sync_screen.dart';
import 'package:kiwit_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:kiwit_app/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'inspection_sync_test.dart' show MemoryLocal, owner, recordAt;
import 'notification_flow_test.dart' show MemoryNotifications;

class ProfileTestAuth extends AuthController {
  ProfileTestAuth(super.ref);
  int signOuts = 0;
  @override
  Future<bool> signOut() async {
    signOuts++;
    return true;
  }
}

const previewProfile = UserProfile(
  id: owner,
  email: 'petugas@example.test',
  fullName: 'Petugas Survei KiWit',
  nip: '123456789012345678',
  rayon: 'Rayon 3 - Sukolilo',
  instansi: 'DLH Kota Surabaya',
  jobTitle: 'Petugas lapangan',
);

User profileTestUser() => User(
  id: owner,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-20T00:00:00Z',
  email: previewProfile.email,
);

void main() {
  testWidgets(
    'profile actions open edit, inbox, sync, password recovery, and logout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = InspectionController(
        ownerId: owner,
        local: MemoryLocal([
          recordAt('pending', DateTime(2026), synced: false),
        ]),
      );
      await source.refresh();
      late ProfileTestAuth auth;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(profileTestUser()),
            currentUserIdProvider.overrideWithValue(owner),
            userProfileProvider.overrideWith((ref) async => previewProfile),
            inspectionControllerProvider.overrideWith((ref) => source),
            authControllerProvider.overrideWith(
              (ref) => auth = ProfileTestAuth(ref),
            ),
            notificationStorageProvider.overrideWith(
              (ref) => MemoryNotifications(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(previewProfile.fullName), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Edit profil'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Notifikasi inspeksi'));
      await tester.tap(find.text('Notifikasi inspeksi'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final sync = find.text('1 inspeksi menunggu sinkron');
      await tester.ensureVisible(sync);
      await tester.tap(sync);
      await tester.pumpAndSettle();
      expect(find.byType(PendingSyncScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Atur ulang kata sandi'));
      await tester.tap(find.text('Atur ulang kata sandi'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Kembali ke halaman masuk'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Keluar dari akun'));
      await tester.tap(find.text('Keluar dari akun'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ada 1 inspeksi'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 0);
      await tester.tap(find.text('Keluar dari akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final guest in [false, true]) {
    testWidgets('profile supports 320px and large text; guest=$guest', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = InspectionController(
        ownerId: guest ? 'guest' : owner,
        local: MemoryLocal(),
      );
      await source.refresh();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(
              guest ? null : profileTestUser(),
            ),
            currentUserIdProvider.overrideWithValue(guest ? null : owner),
            userProfileProvider.overrideWith(
              (ref) async => guest
                  ? null
                  : previewProfile.copyWith(
                      fullName:
                          'Petugas inspeksi dengan nama panjang untuk pengujian tampilan',
                    ),
            ),
            inspectionControllerProvider.overrideWith((ref) => source),
            notificationStorageProvider.overrideWith(
              (ref) => MemoryNotifications(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Notifikasi inspeksi'));
      expect(tester.takeException(), isNull);
      if (guest) {
        expect(find.text('Keluar dari akun'), findsNothing);
        expect(find.text('Atur ulang kata sandi'), findsNothing);
        await tester.ensureVisible(find.text('Masuk ke akun'));
        await tester.tap(find.text('Masuk ke akun'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      } else {
        await tester.ensureVisible(find.text('Keluar dari akun'));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
