import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:file/memory.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal_overlay.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:swipe_image_gallery/widget/gallery.dart';

import '../../../support/fake_cache_manager.dart';
import '../../../support/mock_logger.dart';

void main() {
  testWidgets('shows the requested page and updates metadata on swipe', (
    tester,
  ) async {
    final cacheManager = FakeCacheManager();
    addTearDown(cacheManager.dispose);
    final media = <Media>[
      _buildMedia(id: 1, title: 'First'),
      _buildMedia(id: 2, title: 'Second'),
    ];

    await tester.pumpWidget(
      Provider<CacheManager>.value(
        value: cacheManager,
        child: MaterialApp(
          home: GalleryPreviewScreen(
            data: GalleryPreviewRouteData(media: media, initialIndex: 1),
          ),
        ),
      ),
    );
    await tester.pump();

    var overlay = tester.widget<GalleryPreviewModalOverlay>(
      find.byType(GalleryPreviewModalOverlay),
    );
    expect(overlay.media, media[1]);
    expect(overlay.index, 1);

    final gallery = tester.widget<Gallery>(find.byType(Gallery));
    gallery.controller!.jumpToPage(0);
    await tester.pump();

    overlay = tester.widget<GalleryPreviewModalOverlay>(
      find.byType(GalleryPreviewModalOverlay),
    );
    expect(overlay.media, media[0]);
    expect(overlay.index, 0);
  });

  testWidgets('tapping the image toggles gallery chrome', (tester) async {
    final cacheManager = FakeCacheManager();
    addTearDown(cacheManager.dispose);

    await tester.pumpWidget(
      Provider<CacheManager>.value(
        value: cacheManager,
        child: MaterialApp(
          home: GalleryPreviewScreen(
            data: GalleryPreviewRouteData(
              media: [_buildMedia(id: 1, title: 'Image')],
              initialIndex: 0,
            ),
          ),
        ),
      ),
    );

    IgnorePointer overlayPointer() => tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('galleryPreviewOverlay')),
    );

    expect(overlayPointer().ignoring, isFalse);
    await tester.tapAt(tester.getCenter(find.byType(Gallery)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(overlayPointer().ignoring, isTrue);

    await tester.tapAt(tester.getCenter(find.byType(Gallery)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(overlayPointer().ignoring, isFalse);
  });

  group('share integration', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    const errorMessage =
        'Si è verificato un errore durante la condivisione, riprova più tardi';

    testWidgets('waits for cache then shares the current file once', (
      tester,
    ) async {
      final cacheCancelled = Completer<void>();
      final cache = StreamController<FileResponse>(
        onCancel: cacheCancelled.complete,
      );
      addTearDown(cache.close);
      final cacheManager = FakeCacheManager(streamFactory: () => cache.stream);
      addTearDown(cacheManager.dispose);
      final calls = <MethodCall>[];
      final channelCalled = Completer<void>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      expect(messenger.checkMockMessageHandler(channel.name, null), isTrue);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        channelCalled.complete();
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        Provider<CacheManager>.value(
          value: cacheManager,
          child: MaterialApp(
            scaffoldMessengerKey: $scaffoldMessengerKey,
            home: Scaffold(
              body: GalleryPreviewModalOverlay(
                media: _buildMedia(id: 1, title: 'Image'),
                index: 0,
                itemCount: 1,
              ),
            ),
          ),
        ),
      );
      // Use the real async zone for the stream/platform round trip.
      await tester.runAsync(() => tester.tap(find.text('Condividi')));
      await tester.pumpAndSettle();
      expect(cache.hasListener, isTrue);
      expect(calls, isEmpty);
      final file = MemoryFileSystem().file('/share.jpg');
      await tester.runAsync(() async {
        cache.add(
          FileInfo(
            file,
            FileSource.Cache,
            DateTime.utc(2027),
            'https://example.com/1.jpg',
          ),
        );
      });
      await tester.runAsync(() => channelCalled.future);
      await tester.pumpAndSettle();
      expect(cacheCancelled.isCompleted, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'share');
      expect(calls.single.arguments, containsPair('paths', ['/share.jpg']));
      expect(calls.single.arguments, containsPair('mimeTypes', ['image/*']));
      expect(tester.takeException(), isNull);
    });

    for (final cacheFailure in [true, false]) {
      testWidgets(
        '${cacheFailure ? 'cache' : 'share'} Exception logs and shows feedback',
        (tester) async {
          final logger = MockLogger();
          final failure = PlatformException(code: 'share-failed');
          final cacheManager = FakeCacheManager(
            streamFactory: () => cacheFailure
                ? Stream.error(failure)
                : Stream.value(
                    FileInfo(
                      MemoryFileSystem().file('/share.jpg'),
                      FileSource.Cache,
                      DateTime.utc(2027),
                      'https://example.com/1.jpg',
                    ),
                  ),
          );
          addTearDown(cacheManager.dispose);
          final calls = <MethodCall>[];
          final channelCalled = Completer<void>();
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          expect(messenger.checkMockMessageHandler(channel.name, null), isTrue);
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            channelCalled.complete();
            throw failure;
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          await tester.pumpWidget(
            Provider<CacheManager>.value(
              value: cacheManager,
              child: Provider<Logger>.value(
                value: logger,
                child: MaterialApp(
                  scaffoldMessengerKey: $scaffoldMessengerKey,
                  home: Scaffold(
                    body: GalleryPreviewModalOverlay(
                      media: _buildMedia(id: 1, title: 'Image'),
                      index: 0,
                      itemCount: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() => tester.tap(find.text('Condividi')));
          if (!cacheFailure) {
            await tester.runAsync(() => channelCalled.future);
          }
          await tester.pumpAndSettle();
          expect(calls, hasLength(cacheFailure ? 0 : 1));
          expect(logger.eventsOfType<ImageSharingFailed>(), hasLength(1));
          expect(
            logger.firstCallOfType<ImageSharingFailed>()!.error,
            isA<PlatformException>(),
          );
          expect(find.text(errorMessage), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final failAfterUnmount in [false, true]) {
      testWidgets(
        'cache ${failAfterUnmount ? 'error' : 'success'} after unmount '
        'does not share or publish feedback',
        (tester) async {
          final cache = StreamController<FileResponse>();
          addTearDown(cache.close);
          final cacheManager = FakeCacheManager(
            streamFactory: () => cache.stream,
          );
          addTearDown(cacheManager.dispose);
          final logger = MockLogger();
          final calls = <MethodCall>[];
          final channelCalled = Completer<void>();
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          expect(messenger.checkMockMessageHandler(channel.name, null), isTrue);
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            channelCalled.complete();
            return 'dev.fluttercommunity.plus/share/unavailable';
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          await tester.pumpWidget(
            Provider<CacheManager>.value(
              value: cacheManager,
              child: Provider<Logger>.value(
                value: logger,
                child: MaterialApp(
                  scaffoldMessengerKey: $scaffoldMessengerKey,
                  home: Scaffold(
                    body: GalleryPreviewModalOverlay(
                      media: _buildMedia(id: 1, title: 'Image'),
                      index: 0,
                      itemCount: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(() => tester.tap(find.text('Condividi')));
          await tester.pumpAndSettle();
          expect(cache.hasListener, isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
          if (failAfterUnmount) {
            cache.addError(Exception('late cache failure'));
          } else {
            cache.add(
              FileInfo(
                MemoryFileSystem().file('/share.jpg'),
                FileSource.Cache,
                DateTime.utc(2027),
                'https://example.com/1.jpg',
              ),
            );
          }
          await tester.pumpAndSettle();
          expect(calls, isEmpty);
          expect(logger.calls, isEmpty);
          expect(find.text(errorMessage), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'share already pending may fail after unmount without feedback',
      (tester) async {
        final cacheManager = FakeCacheManager(
          streamFactory: () => Stream.value(
            FileInfo(
              MemoryFileSystem().file('/share.jpg'),
              FileSource.Cache,
              DateTime.utc(2027),
              'https://example.com/1.jpg',
            ),
          ),
        );
        addTearDown(cacheManager.dispose);
        final logger = MockLogger();
        final pending = Completer<String?>();
        var calls = 0;
        final channelCalled = Completer<void>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        expect(messenger.checkMockMessageHandler(channel.name, null), isTrue);
        messenger.setMockMethodCallHandler(channel, (call) {
          calls++;
          channelCalled.complete();
          return pending.future;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        await tester.pumpWidget(
          Provider<CacheManager>.value(
            value: cacheManager,
            child: Provider<Logger>.value(
              value: logger,
              child: MaterialApp(
                scaffoldMessengerKey: $scaffoldMessengerKey,
                home: Scaffold(
                  body: GalleryPreviewModalOverlay(
                    media: _buildMedia(id: 1, title: 'Image'),
                    index: 0,
                    itemCount: 1,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() => tester.tap(find.text('Condividi')));
        await tester.runAsync(() => channelCalled.future);
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(pending.isCompleted, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        pending.completeError(PlatformException(code: 'late-share-failure'));
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(logger.calls, isEmpty);
        expect(find.text(errorMessage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Media _buildMedia({required int id, required String title}) => Media(
  remoteId: id,
  title: title,
  url: 'https://example.com/$id.jpg',
  width: 800,
  height: 600,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  areaName: 'Event',
  cityName: 'Molise',
);
