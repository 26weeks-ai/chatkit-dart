import 'package:chatkit_flutter/chatkit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpGallery(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(944, 1600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatKitGallery(brightness: brightness),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ChatKit gallery light theme', (tester) async {
    await pumpGallery(tester, Brightness.light);
    await expectLater(
      find.byType(ChatKitGallery),
      matchesGoldenFile('goldens/chatkit_gallery_light.png'),
    );
  });

  testWidgets('ChatKit gallery dark theme', (tester) async {
    await pumpGallery(tester, Brightness.dark);
    await expectLater(
      find.byType(ChatKitGallery),
      matchesGoldenFile('goldens/chatkit_gallery_dark.png'),
    );
  });
}
