import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import '../../../../support/fake_cache_manager.dart';
import '../../../../support/mock_logger.dart';

Widget _buildTestApp({
  required CacheManager cacheManager,
  Logger? logger,
  bool fullResolution = false,
  double width = 200,
  double height = 200,
  void Function(bool isLoading)? onImageLoading,
}) {
  return MultiProvider(
    providers: [
      Provider<CacheManager>.value(value: cacheManager),
      Provider<Logger?>.value(value: logger),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: fullResolution
          ? AppNetworkImage.fullResolution(
              url: 'https://example.com/image.jpg',
              imageWidth: 100,
              imageHeight: 100,
              onImageLoading: onImageLoading,
            )
          : AppNetworkImage(
              url: 'https://example.com/image.jpg',
              imageWidth: 100,
              imageHeight: 100,
              width: width,
              height: height,
              onImageLoading: onImageLoading,
            ),
    ),
  );
}

void main() {
  group('AppNetworkImage', () {
    FakeCacheManager? cacheManager;

    tearDown(() async {
      await cacheManager?.dispose();
      cacheManager = null;
    });

    testWidgets(
      'throws ProviderNotFoundException when CacheManager is missing',
      (tester) async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: AppNetworkImage(
              url: 'https://example.com/image.jpg',
              imageWidth: 100,
              imageHeight: 100,
              width: 200,
              height: 200,
            ),
          ),
        );

        expect(tester.takeException(), isA<ProviderNotFoundException>());
      },
    );

    testWidgets('renders error view when image fails to load', (tester) async {
      cacheManager = FakeCacheManager(
        streamFactory: () {
          final controller = StreamController<FileResponse>();
          scheduleMicrotask(() {
            controller.addError(Exception('Test image load failure'));
            unawaited(controller.close());
          });
          return controller.stream;
        },
      );

      await tester.pumpWidget(
        _buildTestApp(cacheManager: cacheManager!),
      );

      await tester.pump();

      expect(find.byType(EmptyView), findsOneWidget);
      expect(find.byIcon(Symbols.image_not_supported), findsOneWidget);
    });

    testWidgets('errorBuilder logs ImageLoadFailed to Logger', (
      tester,
    ) async {
      final logger = MockLogger();

      cacheManager = FakeCacheManager(
        streamFactory: () {
          final controller = StreamController<FileResponse>();
          scheduleMicrotask(() {
            controller.addError(Exception('Test image load failure'));
            unawaited(controller.close());
          });
          return controller.stream;
        },
      );

      await tester.pumpWidget(
        _buildTestApp(
          cacheManager: cacheManager!,
          logger: logger,
        ),
      );

      await tester.pump();

      expect(logger.containsEvent<ImageLoadFailed>(), isTrue);
    });

    testWidgets(
      'normal constructor sets explicit width and height on Image',
      (tester) async {
        cacheManager = FakeCacheManager(
          streamFactory: () {
            final controller = StreamController<FileResponse>();
            scheduleMicrotask(() {
              controller.addError(Exception('Test image load failure'));
              unawaited(controller.close());
            });
            return controller.stream;
          },
        );

        await tester.pumpWidget(
          _buildTestApp(
            cacheManager: cacheManager!,
            width: 300,
            height: 250,
          ),
        );

        await tester.pump();

        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.width, 300);
        expect(imageWidget.height, 250);
      },
    );

    testWidgets('assert fails for non-finite dimensions', (tester) async {
      cacheManager = FakeCacheManager();

      await tester.pumpWidget(
        _buildTestApp(
          cacheManager: cacheManager!,
          width: double.nan,
        ),
      );

      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('AppNetworkImage.fullResolution constructor', () {
    test('sets width and height to zero', () {
      const widget = AppNetworkImage.fullResolution(
        url: 'https://example.com/image.jpg',
        imageWidth: 100,
        imageHeight: 100,
      );

      expect(widget.width, 0);
      expect(widget.height, 0);
    });

    test('does not throw on construction', () {
      expect(
        () => const AppNetworkImage.fullResolution(
          url: 'https://example.com/image.jpg',
          imageWidth: 100,
          imageHeight: 100,
        ),
        returnsNormally,
      );
    });
  });
}
