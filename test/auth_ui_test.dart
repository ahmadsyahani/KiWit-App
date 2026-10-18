import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/constants/app_colors.dart';
import 'package:kiwit_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kiwit_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:kiwit_app/features/auth/presentation/screens/login_screen.dart';
import 'package:kiwit_app/features/auth/presentation/screens/register_screen.dart';

class BusyAuthController extends AuthController {
  BusyAuthController(super.ref) {
    state = const AsyncValue.loading();
  }
}

Future<void> openAuth(
  WidgetTester tester, {
  Widget screen = const LoginScreen(),
  Size size = const Size(320, 640),
  double scale = 1.4,
  double keyboard = 0,
  bool busy = false,
  GlobalKey? previewKey,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(null),
        if (busy)
          authControllerProvider.overrideWith((ref) => BusyAuthController(ref)),
      ],
      child: RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily:
                const bool.fromEnvironment('AUTH_PREVIEWS') &&
                    Platform.isWindows
                ? 'AuthPreview'
                : null,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ),
  );
  if (busy) {
    await tester.pump(const Duration(milliseconds: 200));
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('AUTH_PREVIEWS')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final directory = await Directory(
      'build/auth-previews',
    ).create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('AUTH_PREVIEWS') || !Platform.isWindows) {
      return;
    }
    // Host-only readable previews. Standard tests keep deterministic test fonts.
    final text = FontLoader('AuthPreview')
      ..addFont(
        File(
          'C:/Windows/Fonts/segoeui.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await Future.wait([text.load(), material.load(), lucide.load()]);
  });
  testWidgets(
    'login validates empty input and allows password visibility on a narrow screen',
    (tester) async {
      await openAuth(tester);
      expect(find.text('Masuk ke akun'), findsOneWidget);
      final logo = tester.widget<Image>(find.byType(Image));
      expect(
        (logo.image as AssetImage).assetName,
        'assets/branding/kiwit-launcher-preview.png',
      );
      final submit = find.widgetWithText(FilledButton, 'Masuk');
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Masukkan email yang terdaftar.'), findsOneWidget);
      expect(find.text('Masukkan kata sandi.'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await reveal(tester, fields.at(1));
      await tester.enterText(fields.at(1), 'password-test');
      final toggle = find.byTooltip('Tampilkan kata sandi');
      await reveal(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: fields.at(1),
                matching: find.byType(TextField),
              ),
            )
            .obscureText,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login navigates to register and validates matching passwords without sending data',
    (tester) async {
      await openAuth(tester);
      final signup = find.widgetWithText(TextButton, 'Daftar petugas');
      await reveal(tester, signup);
      await tester.tap(signup);
      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Identitas petugas'), findsOneWidget);
      final fields = find.byType(TextFormField);
      final inputs = [
        'Petugas Uji',
        '123456',
        'petugas@example.test',
        'password-test',
        'different-password',
      ];
      for (var i = 0; i < inputs.length; i++) {
        await reveal(tester, fields.at(i));
        await tester.enterText(fields.at(i), inputs[i]);
      }
      final submit = find.widgetWithText(FilledButton, 'Buat akun petugas');
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Kata sandi belum sama.'), findsOneWidget);
      expect(find.text('Pendaftaran berhasil'), findsNothing);
      expect(tester.takeException(), isNull);
      final back = find.byTooltip('Kembali ke halaman masuk');
      await reveal(tester, back);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets(
    'keyboard compacts header and leaves submit reachable on a short screen',
    (tester) async {
      await openAuth(tester, size: const Size(320, 568), keyboard: 220);
      expect(find.text('Selamat datang\nkembali.'), findsNothing);
      expect(find.text('Masuk ke akun'), findsOneWidget);
      final submit = find.widgetWithText(FilledButton, 'Masuk');
      await reveal(tester, submit);
      expect(submit.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'register supports large text and keyboard without clipping its dropdown or form',
    (tester) async {
      await openAuth(
        tester,
        screen: const RegisterScreen(),
        size: const Size(320, 568),
        scale: 1.8,
        keyboard: 200,
      );
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await reveal(tester, dropdown);
      expect(tester.takeException(), isNull);
      final submit = find.widgetWithText(FilledButton, 'Buat akun petugas');
      await reveal(tester, submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Masukkan nama lengkap.'), findsOneWidget);
      expect(find.text('Masukkan NIP atau ID petugas.'), findsOneWidget);
      expect(find.text('Masukkan email aktif.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading locks fields and navigation against duplicate submissions',
    (tester) async {
      await openAuth(tester, busy: true);
      for (final field in tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      )) {
        expect(field.enabled, isFalse);
      }
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Daftar petugas'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('password recovery remains reachable and validates its email', (
    tester,
  ) async {
    await openAuth(tester);
    final recovery = find.text('Lupa kata sandi?');
    await reveal(tester, recovery);
    await tester.tap(recovery);
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    final submit = find.widgetWithText(FilledButton, 'Kirim tautan pemulihan');
    await reveal(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Masukkan email yang terdaftar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth previews render the logo and layout at phone size', (
    tester,
  ) async {
    final key = GlobalKey();
    await openAuth(
      tester,
      size: const Size(390, 844),
      scale: 1,
      previewKey: key,
    );
    await capture(tester, key, 'login');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    final registerKey = GlobalKey();
    await openAuth(
      tester,
      screen: const RegisterScreen(),
      size: const Size(390, 844),
      scale: 1,
      previewKey: registerKey,
    );
    await capture(tester, registerKey, 'register');
    expect(tester.takeException(), isNull);
  });
}
