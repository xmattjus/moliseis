import 'dart:async' show unawaited;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_editor_screen.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../support/admin_draft_repositories.dart';
import '../support/command_test_support.dart';
import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/mock_gotrue_client.dart';
import '../support/network_image_harness.dart';
import '../support/post_media_slideshow_harness.dart';
import '../support/sync_harness.dart';
import '../support/test_image_files.dart';

void main() {
  for (final early in [false, true]) {
    testOwnerUI(
      early
          ? 'early navigation result does not admit a second Gallery'
          : 'Gallery removal releases a slideshow with a stranded result',
      (tester) async {
        final fixture = await _PostGalleryFixture.mount(tester);
        await fixture.makeReady();
        final postState = tester.state(fixture.post);
        final slideshowState = tester.state(fixture.slideshow);
        final autoPlay = fixture.pause;
        final visibility = fixture.visibility;
        final photo = fixture.photo;
        final capturedOpen = tester.widget<CardBase>(photo).onPressed!;
        final pager = fixture.pager;
        var originalReturned = false;
        unawaited(
          openSlideshowGallery(tester).then((_) {
            originalReturned = true;
          }),
        );
        await _frames(tester);
        final galleryState = tester.state(fixture.gallery);
        final galleryRoute = ModalRoute.of(tester.element(fixture.gallery));
        final original = fixture.match;
        expect(
          fixture.router.routeInformationProvider.value.state,
          isA<Map<Object?, Object?>>(),
        );
        expect(
          fixture.router.routeInformationProvider.value.uri.path,
          '/home/posts/1',
        );
        expect(fixture.post, findsNothing);
        expect(visibility.value, isTrue);

        fixture.auth
          ..setUser(null)
          ..emit(AuthChangeEvent.signedOut);
        await tester.idle();
        final replacement = fixture.match;
        expect(replacement.pageKey, original.pageKey);
        expect(replacement.completer, isNot(same(original.completer)));
        expect(originalReturned, isFalse);
        expect(
          ModalRoute.of(tester.element(fixture.gallery)),
          same(galleryRoute),
        );

        if (early) {
          // A lower-level pop still exercises Gallery's lifecycle protection
          // when the old Page handles a pop before Navigator reconciliation.
          fixture.router.pop();
          await tester.idle();
          expect(originalReturned, isTrue);
          expect(original.completer.isCompleted, isTrue);
          expect(replacement.completer.isCompleted, isFalse);
          expect(fixture.match, same(replacement));
          await _frames(tester);
          expect(fixture.gallery, findsOneWidget);
          expect(tester.state(fixture.gallery), isNot(same(galleryState)));
          expect(
            ModalRoute.of(tester.element(fixture.gallery)),
            isNot(same(galleryRoute)),
          );
          // Synthetic adversarial invocation of the covered slideshow callback.
          capturedOpen();
          await _frames(tester);
          expect(
            fixture.router.routerDelegate.currentConfiguration.matches
                .whereType<ImperativeRouteMatch>(),
            hasLength(1),
          );
          await _advance(tester);
          expect(pager.page, 0);
          await fixture.back();
          await _frames(tester);
          expect(fixture.gallery, findsNothing);
          expect(tester.state(fixture.post), same(postState));
          expect(tester.state(fixture.slideshow), same(slideshowState));
          await fixture.tapPhoto();
          await _frames(tester);
          expect(fixture.gallery, findsOneWidget);
          expect(fixture.match.pageKey, isNot(original.pageKey));
          return;
        }

        await _frames(tester);
        expect(tester.state(fixture.gallery), same(galleryState));
        expect(
          ModalRoute.of(tester.element(fixture.gallery)),
          same(galleryRoute),
        );
        await fixture.back();
        await _frames(tester);
        expect(replacement.completer.isCompleted, isTrue);
        expect(original.completer.isCompleted, isFalse);
        expect(originalReturned, isFalse);
        expect(fixture.gallery, findsNothing);
        expect(tester.state(fixture.post), same(postState));
        expect(tester.state(fixture.slideshow), same(slideshowState));
        expect(visibility.value, isTrue);
        expect(tester.widget<FilledButton>(autoPlay).onPressed, isNotNull);

        await fixture.tapPhoto();
        await _frames(tester);
        final reopened = fixture.gallery.evaluate().length;
        if (reopened == 1) {
          expect(await tester.binding.handlePopRoute(), isTrue);
          await _frames(tester);
        }
        await _advance(tester);
        expect(
          (pager.page, reopened),
          (1.0, 1),
          reason: 'Autoplay advances and a hit-tested photo reopens Gallery',
        );
        expect(originalReturned, isFalse);
      },
    );
  }

  for (final keyboard in [false, true]) {
    testOwnerUI('Gallery Back rejects a stale push (keyboard: $keyboard)', (
      tester,
    ) async {
      final fixture = await _PostGalleryFixture.mount(tester);
      final postRoute = ModalRoute.of(tester.element(fixture.post));
      await fixture.tapPhoto();
      await _frames(tester);
      final original = fixture.match;
      final shown = ModalRoute.of(tester.element(fixture.gallery));
      final back = find.byType(BackButton);
      TestGesture? press;
      if (keyboard) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        expect(
          find.ancestor(
            of: find.byElementPredicate(
              (element) => identical(element, focused),
            ),
            matching: back,
          ),
          findsOneWidget,
        );
      } else {
        press = await tester.startGesture(tester.getCenter(back));
      }

      fixture.auth
        ..setUser(null)
        ..emit(AuthChangeEvent.signedOut);
      await tester.idle();
      final live = fixture.match;
      expect(live.pageKey, original.pageKey);
      expect(live.completer, isNot(same(original.completer)));
      expect(ModalRoute.of(tester.element(fixture.gallery)), same(shown));

      if (keyboard) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await press!.up();
      }
      await tester.idle();
      expect(original.completer.isCompleted, isFalse);
      expect(live.completer.isCompleted, isFalse);
      expect(fixture.match, same(live));

      await _frames(tester);
      expect(ModalRoute.of(tester.element(fixture.gallery)), same(shown));
      if (keyboard) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await tester.tap(back);
      }
      fixture.router.refresh();
      await _frames(tester);
      expect(fixture.gallery, findsNothing);
      expect(ModalRoute.of(tester.element(fixture.post)), same(postRoute));
      expect(live.completer.isCompleted, isTrue);
      expect(original.completer.isCompleted, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testOwnerUI('normal Gallery return survives coverage and unchanged auth', (
    tester,
  ) async {
    final fixture = await _PostGalleryFixture.mount(tester);
    await fixture.makeReady();
    final source = tester.state(fixture.post);
    final pager = fixture.pager;
    final attemptAgain = tester.widget<CardBase>(fixture.photo).onPressed!;

    await fixture.tapPhoto();
    await _frames(tester);
    final first = fixture.match;
    final gallery = tester.state(fixture.gallery);
    fixture.auth.emit(AuthChangeEvent.tokenRefreshed);
    await _frames(tester);
    expect(fixture.match, same(first));
    expect(tester.state(fixture.gallery), same(gallery));

    showDialog<void>(
      context: tester.element(fixture.gallery),
      builder: (_) => const AlertDialog(content: Text('Covering Gallery')),
    );
    await _frames(tester);
    expect(find.text('Covering Gallery').hitTestable(), findsOneWidget);
    // Synthetic because the actual slideshow is behind Gallery and the dialog.
    attemptAgain();
    await _advance(tester);
    expect(fixture.match, same(first));
    expect(pager.page, 0);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await _frames(tester);
    expect(tester.state(fixture.gallery), same(gallery));
    expect(fixture.match, same(first));

    await fixture.back();
    await tester.idle();
    expect(first.completer.isCompleted, isTrue);
    // Even ordinary result delivery precedes outgoing Route removal.
    attemptAgain();
    await _frames(tester);
    expect(fixture.gallery, findsNothing);
    expect(tester.state(fixture.post), same(source));
    await fixture.tapPhoto();
    await _frames(tester);
    expect(fixture.gallery, findsOneWidget);
    expect(fixture.match.pageKey, isNot(first.pageKey));
    await fixture.back();
    await _frames(tester);
    await _advance(tester);
    expect(pager.page, closeTo(1, 0.01));
  });

  for (final gate in _ReturnGate.values) {
    testOwnerUI('Gallery return respects ${gate.name}', (tester) async {
      final fixture = await _PostGalleryFixture.mount(
        tester,
        mediaCount: gate == _ReturnGate.single ? 1 : 2,
      );
      if (gate != _ReturnGate.pending) {
        await fixture.makeReady(checkControls: gate != _ReturnGate.single);
      }
      final visibility = fixture.visibility;
      final pager = fixture.pager;
      if (gate == _ReturnGate.paused) {
        await tester.tap(fixture.pause.hitTestable());
        await _frames(tester);
      }
      await fixture.tapPhoto();
      await _frames(tester);
      expect(fixture.gallery, findsOneWidget);
      if (gate == _ReturnGate.hidden) visibility.value = false;
      await fixture.back();
      await _frames(tester);
      expect(fixture.gallery, findsNothing);
      await _advance(tester);
      expect(pager.page, 0);

      switch (gate) {
        case _ReturnGate.paused:
          await tester.tap(fixture.pause.hitTestable());
        case _ReturnGate.pending:
          await fixture.makeReady();
        case _ReturnGate.hidden:
          visibility.value = true;
        case _ReturnGate.single:
          expect(fixture.pause, findsNothing);
          return;
      }
      await _advance(tester);
      expect(pager.page, closeTo(1, 0.01));
    });
  }

  testOwnerUI('superseded opening leaves the retained Post reusable', (
    tester,
  ) async {
    final fixture = await _PostGalleryFixture.mount(tester);
    final source = tester.state(fixture.slideshow);
    var returned = false;
    unawaited(openSlideshowGallery(tester).then((_) => returned = true));
    fixture.router.go(_PostGalleryFixture.location);
    await _frames(tester);
    expect(fixture.gallery, findsNothing);
    expect(tester.state(fixture.slideshow), same(source));
    expect(returned, isFalse);

    await fixture.tapPhoto();
    await _frames(tester);
    expect(fixture.gallery, findsOneWidget);
    expect(returned, isFalse);
  });

  testOwnerUI('a committed opening superseded before build frees the Post', (
    tester,
  ) async {
    final fixture = await _PostGalleryFixture.mount(tester);
    final post = tester.state(fixture.post);
    final slideshow = tester.state(fixture.slideshow);
    final opening = openSlideshowGallery(tester);
    unawaited(opening);
    await tester.idle();
    final original = fixture.match;
    expect(fixture.gallery, findsNothing);

    fixture.router.go(_PostGalleryFixture.location);
    await _frames(tester);
    expect(fixture.gallery, findsNothing);
    expect(tester.state(fixture.post), same(post));
    expect(tester.state(fixture.slideshow), same(slideshow));
    expect(original.completer.isCompleted, isFalse);

    await fixture.tapPhoto();
    await _frames(tester);
    expect(fixture.gallery, findsOneWidget);
    expect(fixture.match.pageKey, isNot(original.pageKey));
    expect(original.completer.isCompleted, isFalse);
  });

  testOwnerUI('a push over an unbuilt committed Gallery preserves its owner', (
    tester,
  ) async {
    final fixture = await _PostGalleryFixture.mount(tester);
    final post = tester.state(fixture.post);
    final slideshow = tester.state(fixture.slideshow);
    final attemptAgain = tester.widget<CardBase>(fixture.photo).onPressed!;
    unawaited(openSlideshowGallery(tester));
    await tester.idle();
    final original = fixture.match;
    expect(fixture.gallery, findsNothing);

    // Adversarial scheduling of a normal router API over the unbuilt Gallery.
    unawaited(fixture.router.push<void>('/settings'));
    await tester.idle();
    expect(
      fixture.router.routerDelegate.currentConfiguration.matches,
      contains(same(original)),
    );
    expect(fixture.gallery, findsNothing);
    await _frames(tester);
    final settings = find.byType(SettingsScreen);
    expect(settings, findsOneWidget);
    final gallery = find.byType(GalleryPreviewScreen, skipOffstage: false);
    final route = ModalRoute.of(tester.element(gallery));

    // The covered source cannot receive a hit-tested photo tap.
    attemptAgain();
    await _frames(tester);
    expect(settings, findsOneWidget);
    expect(fixture.match.matches.uri.path, '/settings');
    fixture.router.pop();
    await _frames(tester);
    expect(ModalRoute.of(tester.element(fixture.gallery)), same(route));
    await fixture.back();
    await _frames(tester);
    expect(original.completer.isCompleted, isTrue);
    expect(tester.state(fixture.post), same(post));
    expect(tester.state(fixture.slideshow), same(slideshow));
    await fixture.tapPhoto();
    await _frames(tester);
    expect(fixture.gallery, findsOneWidget);
    expect(fixture.match.pageKey, isNot(original.pageKey));
  });

  testOwnerUI('Sync redirects a Gallery push over a retained Post', (
    tester,
  ) async {
    final fixture = await _PostGalleryFixture.mount(tester);
    final post = tester.state(fixture.post);
    final slideshow = tester.state(fixture.slideshow);
    fixture.sync.viewModel.sync.run(true);
    var returned = false;
    unawaited(openSlideshowGallery(tester).then((_) => returned = true));
    await tester.idle();
    final redirected = fixture.match;
    expect(redirected.matches.uri.path, '/sync');
    expect(redirected.matches.uri.queryParameters['from'], '/gallery');
    expect(fixture.gallery, findsNothing);
    await _frames(tester);
    expect(post.mounted, isTrue);
    expect(slideshow.mounted, isTrue);
    fixture.sync.release();
    await _frames(tester);
    expect(fixture.match.pageKey, redirected.pageKey);
    fixture.router.go(_PostGalleryFixture.location);
    await _frames(tester);
    expect(redirected.completer.isCompleted, isFalse);
    expect(returned, isFalse);
    expect(tester.state(fixture.post), same(post));
    expect(tester.state(fixture.slideshow), same(slideshow));
    await fixture.tapPhoto();
    await _frames(tester);
    expect(fixture.gallery, findsOneWidget);
  });

  testOwnerUI('an occupied Admin exit blocks a retained Post Gallery request', (
    tester,
  ) async {
    final fixture = await _PostGalleryFixture.mount(
      tester,
      auth: ControllableAdminAuth(
        initialUser: makeAuthUser(
          id: AdminDraftSessionHarness.accountA,
          isAdmin: true,
        ),
      ),
    );
    final slideshow = tester.state(fixture.slideshow);
    final attempt = tester.widget<CardBase>(fixture.photo).onPressed!;
    unawaited(fixture.router.push<void>('/admin/submissions/new'));
    await _frames(tester);
    final editor = find.byType(AdminSubmissionEditorScreen);
    final owner = tester.element(editor).read<AdminSubmissionEditorViewModel>();
    owner.setName('Edited draft', activation: owner.activation);
    await _frames(tester);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await _frames(tester);
    expect(find.byType(UnsavedChangesDialog), findsOneWidget);
    expect(slideshow.mounted, isTrue);
    expect(fixture.slideshow, findsNothing);

    // Invoke the covered Post callback synthetically against the real guard.
    final configuration = fixture.router.routerDelegate.currentConfiguration;
    var returned = false;
    final opening = Function.apply(attempt, const []) as Future<void>;
    unawaited(opening.then((_) => returned = true));
    await _frames(tester);
    expect(
      fixture.router.routerDelegate.currentConfiguration,
      same(configuration),
    );
    expect(fixture.gallery, findsNothing);

    await tester.tap(find.text('Annulla'));
    await _frames(tester);
    expect(editor, findsOneWidget);
    expect(
      fixture.router.routerDelegate.currentConfiguration,
      same(configuration),
    );
    expect(returned, isFalse);
    attempt();
    await _frames(tester);
    expect(fixture.gallery, findsOneWidget);
    expect(returned, isFalse);
  });

  for (final reducedMotion in [false, true]) {
    testOwnerUI('repeated stale Back retains the recreated Gallery '
        '(reduced motion: $reducedMotion)', (tester) async {
      if (reducedMotion) {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      final fixture = await _PostGalleryFixture.mount(tester);
      final slideshow = tester.state(fixture.slideshow);
      final attemptAgain = tester.widget<CardBase>(fixture.photo).onPressed!;
      unawaited(openSlideshowGallery(tester));
      await _frames(tester);
      final key = fixture.match.pageKey;
      for (var i = 0; i < 2; i++) {
        final retiring = ModalRoute.of(tester.element(fixture.gallery))!;
        final oldMatch = fixture.match;
        var retired = false;
        unawaited(retiring.completed.then((_) => retired = true));

        fixture.router.refresh();
        await tester.idle();
        final committed = fixture.match;
        expect(committed.pageKey, key);
        expect(committed.completer, isNot(same(oldMatch.completer)));
        expect(ModalRoute.of(tester.element(fixture.gallery)), same(retiring));
        // Request refresh before the popped observer runs. Flutter applies
        // the next Page on the following frame.
        tester.binding.addPostFrameCallback((_) => fixture.router.refresh());
        fixture.router.configuration.navigatorKey.currentState!.pop();
        await tester.idle();
        expect(oldMatch.completer.isCompleted, isTrue);
        expect(committed.completer.isCompleted, isFalse);
        expect(fixture.match, same(committed));

        await tester.pump();
        final recreated = tester
            .elementList(find.byType(GalleryPreviewScreen, skipOffstage: false))
            .map(ModalRoute.of)
            .singleWhere((route) => route!.isCurrent)!;
        expect(recreated, isNot(same(retiring)));
        expect(recreated.animation!.isCompleted, isFalse);
        expect(retired, isFalse);

        final recreatedPage = recreated.settings;
        await tester.idle();
        final reconciled = fixture.match;
        expect(reconciled.pageKey, key);
        expect(reconciled.completer, isNot(same(committed.completer)));
        await _frames(tester);
        expect(retired, isTrue);
        expect(ModalRoute.of(tester.element(fixture.gallery)), same(recreated));
        expect(recreated.settings, isNot(same(recreatedPage)));
        expect(fixture.match, same(reconciled));
        attemptAgain();
        await tester.idle();
        expect(fixture.match, same(reconciled));
      }

      await fixture.back();
      await _frames(tester);
      expect(fixture.gallery, findsNothing);
      expect(tester.state(fixture.slideshow), same(slideshow));
      await fixture.tapPhoto();
      await _frames(tester);
      expect(fixture.gallery, findsOneWidget);
      expect(fixture.match.pageKey, isNot(key));

      await fixture.back();
      await _frames(tester);
      await fixture.tapPhoto();
      await tester.pump();
      final entering = ModalRoute.of(
        tester.element(find.byType(GalleryPreviewScreen, skipOffstage: false)),
      )!;
      expect(entering.animation!.isCompleted, isFalse);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await _frames(tester);
      expect(fixture.gallery, findsNothing);
      expect(tester.state(fixture.slideshow), same(slideshow));
    });
  }

  for (final replacement in _SourceReplacement.values) {
    testOwnerUI('Gallery ownership ends on ${replacement.name}', (
      tester,
    ) async {
      final fixture = await _PostGalleryFixture.mount(tester);
      final source = tester.state(fixture.slideshow);
      final obsolete = tester.widget<CardBase>(fixture.photo).onPressed!;
      final firstPost = tester.state(fixture.post);
      await fixture.tapPhoto();
      await _frames(tester);
      expect(fixture.gallery, findsOneWidget);

      switch (replacement) {
        case _SourceReplacement.route:
          fixture.router.go('/home');
          await _frames(tester);
          expect(fixture.gallery, findsNothing);
          fixture.router.go(_PostGalleryFixture.location);
        case _SourceReplacement.sync:
          fixture.sync.viewModel.sync.run(true);
          await _frames(tester);
          expect(
            fixture.router.routeInformationProvider.value.uri.path,
            '/sync',
          );
          expect(
            fixture
                .router
                .routeInformationProvider
                .value
                .uri
                .queryParameters['from'],
            _PostGalleryFixture.location,
          );
          expect(fixture.gallery, findsNothing);
          fixture.sync.release();
        case _SourceReplacement.restoration:
          final firstRoute = ModalRoute.of(tester.element(fixture.gallery));
          await tester.restartAndRestore();
          await _frames(tester);
          expect(fixture.gallery, findsOneWidget);
          expect(
            ModalRoute.of(tester.element(fixture.gallery)),
            isNot(same(firstRoute)),
          );
          expect(
            tester.widget<GalleryPreviewScreen>(fixture.gallery).data.media,
            [slideshowMedia(1), slideshowMedia(2)],
          );
          await fixture.back();
      }
      await _frames(tester);
      expect(fixture.gallery, findsNothing);
      expect(source.mounted, isFalse);
      expect(firstPost.mounted, isFalse);
      expect(tester.state(fixture.slideshow), isNot(same(source)));
      await fixture.tapPhoto();
      await _frames(tester);
      expect(fixture.gallery, findsOneWidget);
      final current = fixture.match;
      obsolete();
      await _frames(tester);
      expect(fixture.match, same(current));
      expect(tester.takeException(), isNull);
    });
  }
}

enum _ReturnGate { paused, pending, hidden, single }

enum _SourceReplacement { route, sync, restoration }

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 6));
  await tester.pump(const Duration(seconds: 1));
}

final class _PostGalleryFixture {
  _PostGalleryFixture(
    this.tester,
    this.router,
    this.cache,
    this.files,
    this.auth,
    this.sync,
  );

  final WidgetTester tester;
  final GoRouter router;
  final ControlledImageCacheManager cache;
  final TestImageFiles files;
  final ControllableAdminAuth auth;
  final SyncHarness sync;

  static const location = '/home/posts/1?type=event';

  static Future<_PostGalleryFixture> mount(
    WidgetTester tester, {
    int mediaCount = 2,
    ControllableAdminAuth? auth,
  }) async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    final cache = ControlledImageCacheManager();
    final files = TestImageFiles.create();
    addTearDown(cache.dispose);
    addTearDown(files.dispose);
    final sample = makeEvent(
      description: List.filled(
        20,
        'Keep the map preview below the viewport.',
      ).join('\n\n'),
    );
    final event = Event(
      category: sample.category,
      city: sample.city,
      coordinates: sample.coordinates,
      createdAt: sample.createdAt,
      description: sample.description,
      media: [for (var i = 1; i <= mediaCount; i++) slideshowMedia(i)],
      modifiedAt: sample.modifiedAt,
      name: sample.name,
      remoteId: sample.remoteId,
      startDate: sample.startDate,
      isSaved: sample.isSaved,
    );
    final sync = SyncHarness();
    final fixture = buildSyncRouterApp(
      sync,
      auth: auth,
      localizationsDelegates: const [FlutterQuillLocalizations.delegate],
      cacheManager: cache,
      restorationScopeId: 'app',
      eventRepository: FakeEventRepository(
        getByIdResults: {1: Result.success(event)},
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fixture.router.go(location);
    await tester.pumpWidget(fixture.app);
    await _frames(tester);
    return _PostGalleryFixture(
      tester,
      fixture.router,
      cache,
      files,
      fixture.auth,
      sync,
    );
  }

  Finder get post => find.byType(PostScreen);
  Finder get slideshow => find.byType(PostMediaSlideshow);
  Finder get gallery => find.byType(GalleryPreviewScreen);
  Finder get photo =>
      find.descendant(of: slideshow, matching: find.byType(CardBase)).first;
  Finder get pause =>
      find.descendant(of: slideshow, matching: find.byType(FilledButton));
  PageController get pager => tester
      .widget<PageView>(
        find.descendant(of: slideshow, matching: find.byType(PageView)),
      )
      .controller!;
  ValueNotifier<bool> get visibility =>
      tester.widget<PostMediaSlideshow>(slideshow).visibilityNotifier;
  ImperativeRouteMatch get match =>
      router.routerDelegate.currentConfiguration.last as ImperativeRouteMatch;

  Future<void> makeReady({bool checkControls = true}) async {
    await tester.idle();
    final url = slideshowMedia(1).url;
    final request = cache.requests.indexWhere((item) => item.url == url);
    expect(request, greaterThanOrEqualTo(0));
    final bytes = files.createSizedPng(800, 600).readAsBytesSync();
    await completeSlideshowImage(tester, cache, request, bytes);
    if (checkControls) {
      expect(tester.widget<FilledButton>(pause).onPressed, isNotNull);
    }
  }

  Future<void> tapPhoto() => tester.tap(
    find
        .descendant(of: slideshow, matching: find.byType(CardBase))
        .hitTestable()
        .first,
  );
  Future<void> back() => tester.tap(find.byType(BackButton));
}
