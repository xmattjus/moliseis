import 'dart:async' show unawaited;
import 'dart:core' hide Error;
import 'dart:core' as core show Error;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
import 'package:moliseis/ui/content_submission/widgets/checkbox_form_field.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_asset_list.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Main content submission form screen.
///
/// Composes shared fields, an asset list, and author/contact details into a
/// scrollable form driven by [ContentSubmissionViewModel]. Handles draft
/// restoration, validation, and submission flow including navigation to the
/// progress screen.
class ContentSubmissionScreen extends StatefulWidget {
  const ContentSubmissionScreen({
    required this.viewModel,
    required this.acquireTransition,
    required this.releaseTransition,
    super.key,
  });

  final ContentSubmissionViewModel viewModel;
  final Object? Function() acquireTransition;
  final void Function(Object token) releaseTransition;

  @override
  State<ContentSubmissionScreen> createState() =>
      _ContentSubmissionScreenState();
}

class _ContentSubmissionScreenState extends State<ContentSubmissionScreen> {
  var _form1Key = GlobalKey<FormState>();
  var _form2Key = GlobalKey<FormState>();
  late ContentSubmissionViewModel _owner;
  late String _sessionIdentity;
  Object _ownerGeneration = Object();
  Object? _pendingBoundary;
  var _allowIosExplicitPop = false;

  bool get _boundaryPending => _pendingBoundary != null;

  @override
  void initState() {
    super.initState();
    _owner = widget.viewModel;
    _sessionIdentity = _owner.state.clientSubmissionId;
    _owner.addListener(_handleSessionIdentityChanged);
    _scheduleRecovery();
  }

  @override
  void didUpdateWidget(covariant ContentSubmissionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.viewModel, widget.viewModel)) return;
    _owner.removeListener(_handleSessionIdentityChanged);
    _owner = widget.viewModel;
    _ownerGeneration = Object();
    _resetPresentation();
    _owner.addListener(_handleSessionIdentityChanged);
    _scheduleRecovery();
  }

  @override
  void dispose() {
    _owner.removeListener(_handleSessionIdentityChanged);
    super.dispose();
  }

  void _resetPresentation() {
    _sessionIdentity = _owner.state.clientSubmissionId;
    _form1Key = GlobalKey<FormState>();
    _form2Key = GlobalKey<FormState>();
    _pendingBoundary = null;
    _allowIosExplicitPop = false;
  }

  /// The Provider check also closes the window before didUpdateWidget rebinds.
  bool _ownsPresentation(ContentSubmissionViewModel owner, Object generation) {
    if (!mounted) return false;
    if (!identical(widget.viewModel, owner) ||
        !identical(_ownerGeneration, generation)) {
      return false;
    }
    final provided = context.read<ContentSubmissionViewModel?>();
    return provided == null || identical(provided, owner);
  }

  bool _isCurrent(
    ContentSubmissionViewModel owner,
    Object generation,
    String identity,
  ) =>
      _ownsPresentation(owner, generation) &&
      owner.state.clientSubmissionId == identity;

  bool get _formRouteIsCurrent {
    if (!mounted) return false;
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  void _reportBoundaryFailure(
    Object error,
    StackTrace stack,
    String description,
  ) {
    if (error is AssertionError) core.Error.throwWithStackTrace(error, stack);
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        context: ErrorDescription(description),
      ),
    );
  }

  void _scheduleRecovery() {
    final owner = _owner;
    final generation = _ownerGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_ownsPresentation(owner, generation)) return;
      owner.requestRetrieveLostAssets();
    });
  }

  /// New keys present authoritative fields without replaying old form edits.
  void _handleSessionIdentityChanged() {
    if (!mounted) return;
    if (_sessionIdentity == _owner.state.clientSubmissionId) return;
    setState(_resetPresentation);
  }

  void _finishBoundary(Object boundary) {
    if (!mounted) return;
    if (!identical(_pendingBoundary, boundary)) return;
    setState(() => _pendingBoundary = null);
  }

  void _requestAppBarBack(
    ContentSubmissionViewModel owner,
    Object generation,
    String identity,
  ) {
    if (!mounted) return;
    if (!_isCurrent(owner, generation, identity) ||
        !_formRouteIsCurrent ||
        _boundaryPending ||
        owner.isSubmitting ||
        owner.submissionFinalizationPending) {
      return;
    }
    final isDirtyIos =
        defaultTargetPlatform == TargetPlatform.iOS && owner.hasUnsavedChanges;
    if (!isDirtyIos) {
      context.pop();
      return;
    }
    setState(() => _allowIosExplicitPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isCurrent(owner, generation, identity)) return;
      if (!_formRouteIsCurrent ||
          _boundaryPending ||
          owner.isSubmitting ||
          owner.submissionFinalizationPending) {
        setState(() => _allowIosExplicitPop = false);
        return;
      }
      context.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_isCurrent(owner, generation, identity)) return;
        setState(() => _allowIosExplicitPop = false);
      });
    });
  }

  Future<void> _openExternalLink(
    ContentSubmissionViewModel owner,
    Object generation,
    String identity,
    Future<bool> Function() open,
  ) async {
    if (!mounted) return;
    if (!_isCurrent(owner, generation, identity) ||
        !_formRouteIsCurrent ||
        _boundaryPending ||
        owner.isSubmitting ||
        owner.submissionFinalizationPending) {
      return;
    }
    final acquire = widget.acquireTransition;
    final release = widget.releaseTransition;
    final token = acquire();
    if (token == null) return;
    final boundary = Object();
    try {
      if (!_isCurrent(owner, generation, identity)) return;
      setState(() => _pendingBoundary = boundary);
      if (owner.hasUnsavedChanges) {
        final checkpoint = await owner.checkpointDraft();
        if (!mounted) return;
        if (!_isCurrent(owner, generation, identity)) return;
        if (checkpoint is Error<void>) {
          showSnackBarGenericError(context: context);
          return;
        }
      }
      if (!_isCurrent(owner, generation, identity) || !_formRouteIsCurrent) {
        return;
      }
      final launched = await open();
      if (!mounted) return;
      if (!_isCurrent(owner, generation, identity)) return;
      if (!launched) showSnackBarGenericError(context: context);
    } on Object catch (error, stack) {
      _reportBoundaryFailure(
        error,
        stack,
        'opening a content submission external link',
      );
      if (!mounted) return;
      if (_isCurrent(owner, generation, identity)) {
        showSnackBarGenericError(context: context);
      }
    } finally {
      release(token);
      _finishBoundary(boundary);
    }
  }

  Future<void> _submit(
    ContentSubmissionViewModel owner,
    Object generation,
    String identity,
  ) async {
    if (!mounted) return;
    if (!_isCurrent(owner, generation, identity) ||
        !_formRouteIsCurrent ||
        _boundaryPending ||
        owner.isSubmitting ||
        owner.submissionFinalizationPending) {
      return;
    }
    final acquire = widget.acquireTransition;
    final release = widget.releaseTransition;
    final form1State = _form1Key.currentState;
    final form2State = _form2Key.currentState;
    final valid1 = form1State?.validate() ?? false;
    final valid2 = form2State?.validate() ?? false;
    final temporalValid = owner.validateEventTimeForSubmission();
    if (!valid1 ||
        !valid2 ||
        !temporalValid ||
        !_isCurrent(owner, generation, identity)) {
      return;
    }
    final token = acquire();
    if (token == null) return;
    final boundary = Object();
    var handedOff = false;
    try {
      if (!_isCurrent(owner, generation, identity)) return;
      setState(() => _pendingBoundary = boundary);
      final checkpoint = await owner.checkpointDraft();
      if (!mounted) return;
      if (!_isCurrent(owner, generation, identity)) return;
      if (checkpoint is Error<void>) {
        showSnackBarGenericError(context: context);
        return;
      }
      if (!_formRouteIsCurrent || !owner.requestSubmit()) return;
      if (!_isCurrent(owner, generation, identity) || !_formRouteIsCurrent) {
        return;
      }
      unawaited(
        context
            .pushNamed(RouteNames.contentSubmissionUploadProgress)
            .then<void>(
              (_) {},
              onError: (Object error, StackTrace stack) {
                _reportBoundaryFailure(
                  error,
                  stack,
                  'navigating to content submission progress',
                );
                if (!mounted) return;
                if (_isCurrent(owner, generation, identity)) {
                  showSnackBarGenericError(context: context);
                }
              },
            ),
      );
      release(token);
      handedOff = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_isCurrent(owner, generation, identity)) return;
        _finishBoundary(boundary);
      });
    } on Object catch (error, stack) {
      _reportBoundaryFailure(
        error,
        stack,
        'submitting a content submission form',
      );
      if (!mounted) return;
      if (_isCurrent(owner, generation, identity)) {
        showSnackBarGenericError(context: context);
      }
    } finally {
      if (!handedOff) {
        release(token);
        _finishBoundary(boundary);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final textStyle = textTheme.bodyLarge;

    final linkTextStyle = context.appTypography.link?.copyWith(
      fontSize: textTheme.bodyMedium?.fontSize,
    );

    return AnnotatedRegion(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.colorScheme.surface,
        systemNavigationBarDividerColor: context.colorScheme.surface,
        systemNavigationBarIconBrightness: context.isDarkTheme
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, child) {
              final viewModel = widget.viewModel;
              final generation = _ownerGeneration;
              final identity = viewModel.state.clientSubmissionId;
              void edit(VoidCallback action) {
                if (!mounted) return;
                if (!_isCurrent(viewModel, generation, identity)) return;
                action();
              }

              if (viewModel.loadState ==
                      ContentSubmissionDraftLoadState.loading ||
                  viewModel.isClearing) {
                return const EmptyView.loading(
                  text: Text('Caricamento in corso...'),
                );
              }

              final isDirty = viewModel.hasUnsavedChanges;
              final blocksIosGesture =
                  defaultTargetPlatform == TargetPlatform.iOS &&
                  (isDirty || _boundaryPending) &&
                  !_allowIosExplicitPop;
              return PopScope<Object?>(
                canPop: !blocksIosGesture,
                child: AbsorbPointer(
                  absorbing: _boundaryPending,
                  child: CustomScrollView(
                    key: const ValueKey('content_submission_scroll'),
                    slivers: <Widget>[
                      SliverAppBar(
                        automaticallyImplyLeading: false,
                        leading: Navigator.canPop(context)
                            ? BackButton(
                                onPressed: () => _requestAppBarBack(
                                  viewModel,
                                  generation,
                                  identity,
                                ),
                              )
                            : null,
                        title: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Suggerimento'),
                            if (isDirty)
                              Semantics(
                                label: 'Modifiche non salvate',
                                child: ExcludeSemantics(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: context
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Modifiche non salvate',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: context
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList.list(
                          children: [
                            ContentSubmissionFields(
                              formKey: _form1Key,
                              category: viewModel.state.category,
                              city: viewModel.state.city,
                              name: viewModel.state.name,
                              description: viewModel.state.description,
                              descriptionDelta:
                                  viewModel.state.descriptionDelta,
                              isEvent: viewModel.isEvent,
                              allDay: viewModel.allDay,
                              onAllDayChanged: (allDay) => edit(
                                () => viewModel.setAllDay(allDay: allDay),
                              ),
                              startCalendarDate: viewModel.startCalendarDate,
                              startClockTime: viewModel.startClockTime,
                              endCalendarDate: viewModel.endCalendarDate,
                              eventTimeIssue: viewModel.eventTimeIssue,
                              onCategorySelected: (value) =>
                                  edit(() => viewModel.setCategory(value)),
                              onCategoryDeleted: () =>
                                  edit(() => viewModel.setCategory(null)),
                              onCityChanged: (value) =>
                                  edit(() => viewModel.setCity(value)),
                              onNameChanged: (value) =>
                                  edit(() => viewModel.setName(value)),
                              onDescriptionChanged:
                                  ({
                                    required description,
                                    required descriptionDelta,
                                  }) => edit(
                                    () => viewModel.setDescription(
                                      description: description,
                                      descriptionDelta: descriptionDelta,
                                    ),
                                  ),
                              onEventChanged: (enabled) => edit(
                                () =>
                                    viewModel.setEventEnabled(enabled: enabled),
                              ),
                              onStartDateChanged: (value) => edit(
                                () => viewModel.setStartCalendarDate(value),
                              ),
                              onStartTimeChanged: (value) => edit(
                                () => viewModel.setStartClockTime(value),
                              ),
                              onEndDateChanged: (value) => edit(
                                () => viewModel.setEndCalendarDate(value),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SliverList.list(
                        children: [
                          ContentSubmissionAssetList(viewModel: viewModel),
                          const SizedBox(height: 32),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 8,
                              children: [
                                Text(
                                  'Il servizio è completamente gratuito',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Il luogo o l'evento da te segnalato verrà "
                                  'pubblicato sulla piattaforma il prima '
                                  'possibile',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Form(
                              key: _form2Key,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SentryMask(
                                    TextFormField(
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      initialValue: viewModel.state.userEmail,
                                      decoration: const InputDecoration(
                                        labelText: 'E-mail',
                                        hintText: 'mario.rossi@gmail.com',
                                      ),
                                      onChanged: (value) => edit(
                                        () => viewModel.setUserEmail(value),
                                      ),
                                      validator: (value) {
                                        if (value != null) {
                                          if (!viewModel.validateEmail(value)) {
                                            return 'Inserisci un '
                                                'indirizzo e-mail valido';
                                          } else if (value.length > 320) {
                                            return "L'indirizzo e-mail "
                                                'inserito è troppo lungo';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SentryMask(
                                    TextFormField(
                                      initialValue: viewModel.state.userName,
                                      decoration: const InputDecoration(
                                        labelText: 'Autore',
                                        hintText: 'Mario Rossi',
                                      ),
                                      onChanged: (value) => edit(
                                        () => viewModel.setUserName(value),
                                      ),
                                      validator: (value) {
                                        if (value != null) {
                                          if (value.isEmpty) {
                                            return 'Inserisci il tuo nome';
                                          } else if (value.length > 100) {
                                            return 'Il nome inserito è troppo '
                                                'lungo.';
                                          }
                                        }
                                        return null;
                                      },
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  CheckboxFormField(
                                    initialValue:
                                        viewModel.state.acceptedTerms ?? false,
                                    onChanged: (value) => edit(
                                      () => viewModel.setAcceptedTerms(
                                        value: value,
                                      ),
                                    ),
                                    title: MergeSemantics(
                                      child: RichText(
                                        text: TextSpan(
                                          style: textStyle,
                                          children: [
                                            const WidgetSpan(
                                              child: Text(
                                                'Inviando il suggerimento, '
                                                'accetti i ',
                                              ),
                                            ),
                                            WidgetSpan(
                                              child: Semantics(
                                                label: 'Termini di Servizio',
                                                excludeSemantics: true,
                                                child: InkWell(
                                                  onTap: () {
                                                    if (!mounted) return;
                                                    if (!_isCurrent(
                                                      viewModel,
                                                      generation,
                                                      identity,
                                                    )) {
                                                      return;
                                                    }
                                                    final urlLaunchService =
                                                        context
                                                            .read<
                                                              UrlLaunchService
                                                            >();
                                                    unawaited(
                                                      _openExternalLink(
                                                        viewModel,
                                                        generation,
                                                        identity,
                                                        urlLaunchService
                                                            .openTermsOfService,
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    'Termini di Servizio',
                                                    style: linkTextStyle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const WidgetSpan(
                                              child: Text(" e l'"),
                                            ),
                                            WidgetSpan(
                                              child: Semantics(
                                                label:
                                                    'Informativa sulla privacy',
                                                excludeSemantics: true,
                                                child: InkWell(
                                                  onTap: () {
                                                    if (!mounted) return;
                                                    if (!_isCurrent(
                                                      viewModel,
                                                      generation,
                                                      identity,
                                                    )) {
                                                      return;
                                                    }
                                                    final urlLaunchService =
                                                        context
                                                            .read<
                                                              UrlLaunchService
                                                            >();
                                                    unawaited(
                                                      _openExternalLink(
                                                        viewModel,
                                                        generation,
                                                        identity,
                                                        urlLaunchService
                                                            .openPrivacyPolicy,
                                                      ),
                                                    );
                                                  },
                                                  child: Text(
                                                    'Informativa sulla privacy',
                                                    style: linkTextStyle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const WidgetSpan(
                                              child: Text(' di Molise Is'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value != true) {
                                        return 'Devi accettare i Termini di '
                                            "Servizio e l'Informativa sulla "
                                            'privacy.';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: 16,
                              ),
                              child: FilledButton.tonalIcon(
                                onPressed: () => unawaited(
                                  _submit(viewModel, generation, identity),
                                ),
                                label: const Text('Invia'),
                                icon: const Icon(Symbols.upload),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
