import 'dart:async';
import 'dart:io' show File;

import 'package:moliseis/domain/models/admin_submission_draft.dart';
import 'package:moliseis/domain/models/admin_submission_staged_asset.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/admin_submission_staged_asset_repository.dart';
import 'package:moliseis/utils/result.dart';

/// Whether persistence has established absence or the exact durable owner.
enum AdminDraftDurability { unknown, absent, durable }

/// Immutable runtime facts; only [physicalCheckpoint] is a stored checkpoint.
final class AdminDraftSessionState {
  /// Captures local truth independently of remote readiness and ownership.
  AdminDraftSessionState({
    required this.owner,
    required this.current,
    required this.effective,
    required this.durability,
    this.physicalCheckpoint,
    this.remoteBaseline,
    this.ready = false,
    this.hydrationPending = false,
    this.hydrationError,
    this.acceptedRemoteRevision,
    this.associatedCount,
    List<AdminSubmissionStagedAsset> assets = const [],
  }) : assets = List.unmodifiable(assets);

  /// Account, stable local session and optional remote target.
  final AdminDraftOwner owner;

  /// C: exact editable values, including incomplete input.
  final AdminDraftSnapshot current;

  /// E: comparison baseline; accepting remote state need not write disk.
  final AdminDraftSnapshot effective;

  /// P: exact last loaded/written checkpoint, absent only with known absence.
  final AdminSubmissionDraft? physicalCheckpoint;

  /// R: remote truth supplied by the caller; restored values are historical.
  final AdminRemoteBaseline? remoteBaseline;

  /// Knowledge of the owner, independently of current-field durability.
  final AdminDraftDurability durability;

  /// True only after draft loading and complete asset reconciliation.
  final bool ready;

  /// Whether the latest externally performed hydration is unsettled.
  final bool hydrationPending;

  /// Expected failure of the latest request; never a persistence baseline.
  final Exception? hydrationError;

  /// Runtime identity of accepted detail/assets context, never a server CAS.
  final int? acceptedRemoteRevision;

  /// Count observed with that exact accepted context; null means unknown.
  final int? associatedCount;

  /// Fully reconciled and explicitly ordered exact-owner descriptors.
  final List<AdminSubmissionStagedAsset> assets;

  /// User mutations since the effective baseline, not since the last disk IO.
  bool get hasUncheckpointedChanges => current != effective;

  /// Whether known physical content equals the current editable snapshot.
  bool get currentMatchesDisk =>
      durability == AdminDraftDurability.durable &&
      physicalCheckpoint?.snapshot == current;

  static const _unchanged = Object();

  AdminDraftSessionState _copy({
    AdminDraftOwner? owner,
    AdminDraftSnapshot? current,
    AdminDraftSnapshot? effective,
    Object? physicalCheckpoint = _unchanged,
    Object? remoteBaseline = _unchanged,
    AdminDraftDurability? durability,
    bool? ready,
    bool? hydrationPending,
    Object? hydrationError = _unchanged,
    Object? acceptedRemoteRevision = _unchanged,
    Object? associatedCount = _unchanged,
    List<AdminSubmissionStagedAsset>? assets,
  }) => AdminDraftSessionState(
    owner: owner ?? this.owner,
    current: current ?? this.current,
    effective: effective ?? this.effective,
    physicalCheckpoint: identical(physicalCheckpoint, _unchanged)
        ? this.physicalCheckpoint
        : physicalCheckpoint as AdminSubmissionDraft?,
    remoteBaseline: identical(remoteBaseline, _unchanged)
        ? this.remoteBaseline
        : remoteBaseline as AdminRemoteBaseline?,
    durability: durability ?? this.durability,
    ready: ready ?? this.ready,
    hydrationPending: hydrationPending ?? this.hydrationPending,
    hydrationError: identical(hydrationError, _unchanged)
        ? this.hydrationError
        : hydrationError as Exception?,
    acceptedRemoteRevision: identical(acceptedRemoteRevision, _unchanged)
        ? this.acceptedRemoteRevision
        : acceptedRemoteRevision as int?,
    associatedCount: identical(associatedCount, _unchanged)
        ? this.associatedCount
        : associatedCount as int?,
    assets: assets ?? this.assets,
  );
}

/// Immutable authority captured when an editing context is established.
///
/// Keep this token in that context's callbacks; reading a new token when a
/// delayed callback executes would authorize the replacement context instead.
final class AdminDraftActivation {
  AdminDraftActivation._(this._session, this.owner, this.generation);

  final AdminDraftSession _session;

  /// Exact account, session and target at capture time.
  final AdminDraftOwner owner;

  /// Distinguishes replacement activations even when the owner is unchanged.
  final int generation;
}

/// Captured authority issued synchronously before an external hydration.
final class AdminHydrationToken {
  AdminHydrationToken._(this.owner, this.generation, this.revision);

  /// Exact owner at admission.
  final AdminDraftOwner owner;

  /// Activation identity, including returning to the same durable session.
  final int generation;

  /// Latest-request ordering within the activation.
  final int revision;
}

/// Caller-carried admission context; validated again at local action entry.
typedef AdminAssetCapacityContext = ({
  AdminDraftOwner owner,
  int generation,
  int associatedCount,
  int? acceptedRemoteRevision,
});

/// Local draft/file arbitration, deliberately unregistered in the application.
///
/// Callers own authentication and remote/platform work. No operation here
/// retires a durable owner. Revocation removes runtime authority immediately;
/// already-started commits can finish only under their original retained owner.
final class AdminDraftSession {
  /// Composes only domain-facing local repositories.
  AdminDraftSession({
    required AdminSubmissionDraftRepository draftRepository,
    required AdminSubmissionStagedAssetRepository stagedAssetRepository,
  }) : _drafts = draftRepository,
       _staged = stagedAssetRepository;

  final AdminSubmissionDraftRepository _drafts;
  final AdminSubmissionStagedAssetRepository _staged;
  AdminDraftSessionState? _state;
  Future<void> _tail = Future.value();
  Future<Result<void>>? _initializing;
  int _generation = 0;
  int _hydrationRevision = 0;
  AdminHydrationToken? _activeHydration;
  int _pending = 0;

  /// Current private local context, or null following explicit revocation.
  AdminDraftSessionState? get state => _state;

  /// Captures a new activation after refusing abandonment of unsaved work.
  Future<Result<void>> activate(
    AdminDraftOwner provisionalOwner, {
    AdminDraftSnapshot? freshSnapshot,
  }) {
    final previous = _state;
    if (previous != null &&
        previous.owner.lookupKey == provisionalOwner.lookupKey) {
      return initialize();
    }
    if (previous != null &&
        (previous.hasUncheckpointedChanges ||
            _pending != 0 ||
            previous.hydrationPending)) {
      return Future.value(
        _unavailable('Local work must settle before switching.'),
      );
    }
    _generation++;
    _hydrationRevision = 0;
    _activeHydration = null;
    _initializing = null;
    final fresh = freshSnapshot ?? AdminDraftSnapshot();
    _state = AdminDraftSessionState(
      owner: provisionalOwner,
      current: fresh,
      effective: fresh,
      durability: AdminDraftDurability.unknown,
    );
    return initialize();
  }

  /// Shares one complete loading/reconciliation attempt; failure permits retry.
  Future<Result<void>> initialize() {
    if (_state == null) return Future.value(_unavailable());
    if (_state!.ready) return Future.value(const Result.success(null));
    if (_initializing != null) return _initializing!;
    final generation = _generation;
    final owner = _state!.owner;
    final attempt = _serialize<void>(() async {
      if (!_matches(owner, generation)) return _unavailable();
      if (_state!.durability == AdminDraftDurability.durable) {
        final reconciled = await _staged.reconcileAndLoad(owner);
        if (!_matches(owner, generation)) return _unavailable();
        if (reconciled case Error<List<AdminSubmissionStagedAsset>>(
          :final error,
        )) {
          return Result.error(error);
        }
        _state = _state!._copy(
          ready: true,
          assets:
              (reconciled as Success<List<AdminSubmissionStagedAsset>>).value,
        );
        return const Result.success(null);
      }
      final loaded = await _drafts.loadDraft(
        accountId: owner.accountId,
        submissionId: owner.submissionId,
      );
      if (!_matches(owner, generation)) return _unavailable();
      if (loaded case Error<AdminSubmissionDraft?>(:final error)) {
        return Result.error(error);
      }
      final draft = (loaded as Success<AdminSubmissionDraft?>).value;
      if (draft == null) {
        _state = _state!._copy(
          durability: AdminDraftDurability.absent,
          ready: true,
        );
        return const Result.success(null);
      }
      final restored = await _staged.reconcileAndLoad(draft.owner);
      if (!_matches(owner, generation)) return _unavailable();
      if (restored case Error<List<AdminSubmissionStagedAsset>>(:final error)) {
        return Result.error(error);
      }
      _state = AdminDraftSessionState(
        owner: draft.owner,
        current: draft.snapshot,
        effective: draft.snapshot,
        physicalCheckpoint: draft,
        remoteBaseline: draft.remoteBaseline,
        durability: AdminDraftDurability.durable,
        ready: true,
        assets: (restored as Success<List<AdminSubmissionStagedAsset>>).value,
      );
      return const Result.success(null);
    });
    _initializing = attempt;
    // Clear only this attempt; an obsolete completion cannot clear a new one.
    unawaited(
      attempt.then<void>(
        (_) {
          if (identical(_initializing, attempt)) _initializing = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_initializing, attempt)) _initializing = null;
        },
      ),
    );
    return attempt;
  }

  /// Captures the caller's editing context without granting durable ownership.
  ///
  /// Normally capture after activation/restoration completes. A provisional
  /// token becomes stale if restoration supplies a different session owner.
  /// Capture once for the editing context, never inside a delayed callback.
  AdminDraftActivation? captureActivation() {
    final owner = _state?.owner;
    return owner == null
        ? null
        : AdminDraftActivation._(this, owner, _generation);
  }

  /// Replaces immutable C only for the caller's captured activation.
  ///
  /// Stale or foreign authority returns an error without changing any state.
  /// Ordinary typing neither rotates this authority nor implicitly persists.
  Result<void> setSnapshot(
    AdminDraftSnapshot snapshot, {
    required AdminDraftActivation activation,
  }) {
    if (!identical(activation._session, this) ||
        !_matches(activation.owner, activation.generation) ||
        _state?.ready != true) {
      return _unavailable();
    }
    _state = _state!._copy(current: snapshot);
    return const Result.success(null);
  }

  /// Removes runtime authority without deleting any persisted session or file.
  void revoke() {
    _generation++;
    _hydrationRevision = 0;
    _activeHydration = null;
    _state = null;
    _initializing = null;
  }

  /// Explicitly persists a captured snapshot; ownership can force first write.
  Future<Result<void>> checkpoint({bool requireDurableOwner = false}) async {
    final generation = _generation;
    final owner = _state?.owner;
    if (owner == null) return _unavailable();
    final initialized = await initialize();
    if (initialized case Error<void>()) return initialized;
    // Restoration may replace a provisional session ID, never account/target.
    if (_generation != generation) return _unavailable();
    final restoredOwner = _state!.owner;
    return await _serialize(
      () => _checkpoint(
        restoredOwner,
        generation,
        requireDurableOwner: requireDurableOwner,
      ),
    );
  }

  Future<Result<void>> _checkpoint(
    AdminDraftOwner owner,
    int generation, {
    required bool requireDurableOwner,
  }) async {
    if (!_matches(owner, generation) || !_state!.ready) return _unavailable();
    final captured = _state!;
    if (captured.durability == AdminDraftDurability.unknown) {
      return _unavailable();
    }
    if (captured.durability == AdminDraftDurability.absent &&
        captured.remoteBaseline == null &&
        !captured.hasUncheckpointedChanges &&
        !requireDurableOwner) {
      return const Result.success(null);
    }
    final draft = AdminSubmissionDraft(
      owner: owner,
      snapshot: captured.current,
      remoteBaseline: captured.remoteBaseline,
    );
    if (captured.durability == AdminDraftDurability.durable &&
        captured.physicalCheckpoint == draft) {
      _state = _state!._copy(effective: captured.current);
      return const Result.success(null);
    }
    final saved = await _drafts.saveDraft(draft);
    if (saved is Success<void> && _matches(owner, generation)) {
      _state = _state!._copy(
        physicalCheckpoint: draft,
        effective: captured.current,
        durability: AdminDraftDurability.durable,
      );
    }
    return saved;
  }

  /// Supersedes older remote requests immediately, without fetching anything.
  AdminHydrationToken? admitHydration() {
    final current = _state;
    if (current == null ||
        !current.ready ||
        current.owner.submissionId == null) {
      return null;
    }
    final token = AdminHydrationToken._(
      current.owner,
      _generation,
      ++_hydrationRevision,
    );
    _activeHydration = token;
    _state = current._copy(hydrationPending: true, hydrationError: null);
    return token;
  }

  bool _authoritative(AdminHydrationToken token) =>
      identical(_activeHydration, token) &&
      _matches(token.owner, token.generation) &&
      token.revision == _hydrationRevision;

  /// Publishes only the latest supplied response when local intent is safe.
  Future<Result<bool>> acceptHydration(
    AdminHydrationToken token,
    AdminRemoteBaseline baseline, {
    required int associatedCount,
  }) => _serialize(() async {
    if (!_authoritative(token)) return const Result.success(false);
    if (associatedCount < 0 || associatedCount > 5) {
      _state = _state!._copy(
        hydrationPending: false,
        hydrationError: Exception('Unavailable associated capacity.'),
      );
      return Result.error(Exception('Unavailable associated capacity.'));
    }
    final current = _state!;
    if (current.hasUncheckpointedChanges) {
      _state = current._copy(hydrationPending: false);
      return const Result.success(false);
    }
    final physical = current.physicalCheckpoint;
    final previous = current.remoteBaseline;
    final savedRemote = physical?.remoteBaseline;
    final unconfirmed =
        physical != null &&
        (savedRemote == null ||
            !physical.snapshot.fieldsEqualTo(
              savedRemote.snapshot,
              semanticCoordinates: true,
            ));
    if (unconfirmed &&
        !current.current.fieldsEqualTo(
          baseline.snapshot,
          semanticCoordinates: true,
        )) {
      if (previous == null ||
          !previous.snapshot.fieldsEqualTo(
            baseline.snapshot,
            semanticCoordinates: true,
          )) {
        _state = current._copy(hydrationPending: false);
        return const Result.success(false);
      }
      // Remote metadata refreshed compatibly; retain checkpointed local edits.
      _state = current._copy(
        remoteBaseline: baseline,
        hydrationPending: false,
        hydrationError: null,
        acceptedRemoteRevision: token.revision,
        associatedCount: associatedCount,
      );
    } else {
      _state = current._copy(
        current: baseline.snapshot,
        effective: baseline.snapshot,
        remoteBaseline: baseline,
        hydrationPending: false,
        hydrationError: null,
        acceptedRemoteRevision: token.revision,
        associatedCount: associatedCount,
      );
    }
    return const Result.success(true);
  });

  /// Records a current failure; older tokens are never revived by it.
  Future<Result<bool>> rejectHydration(
    AdminHydrationToken token,
    Exception error,
  ) => _serialize(() async {
    if (!_authoritative(token)) return const Result.success(false);
    _state = _state!._copy(hydrationPending: false, hydrationError: error);
    return const Result.success(true);
  });

  /// Captures qualified local admission; historical restored R is insufficient.
  AdminAssetCapacityContext? get capacityContext {
    final current = _state;
    if (current == null || !current.ready) return null;
    if (current.owner.submissionId == null) {
      return (
        owner: current.owner,
        generation: _generation,
        associatedCount: 0,
        acceptedRemoteRevision: null,
      );
    }
    if (current.acceptedRemoteRevision == null ||
        current.associatedCount == null) {
      return null;
    }
    return (
      owner: current.owner,
      generation: _generation,
      associatedCount: current.associatedCount!,
      acceptedRemoteRevision: current.acceptedRemoteRevision,
    );
  }

  /// Acquires already-attributed bytes without picker, upload or remote calls.
  Future<Result<AdminSubmissionStagedAsset>> acquire(
    File source, {
    required AdminAssetCapacityContext? capacity,
  }) {
    final owner = _state?.owner;
    final generation = _generation;
    return _serialize(() async {
      if (owner == null ||
          !_matches(owner, generation) ||
          !_state!.ready ||
          capacity == null ||
          capacity != capacityContext) {
        return Result.error(Exception('Unavailable associated capacity.'));
      }
      final checkpointed = await _checkpoint(
        owner,
        generation,
        requireDurableOwner: true,
      );
      if (checkpointed case Error<void>(:final error)) {
        return Result.error(error);
      }
      if (!_matches(owner, generation)) {
        return Result.error(Exception('Owner revoked.'));
      }
      final acquired = await _staged.acquire(
        owner: owner,
        source: source,
        associatedCount: capacity.associatedCount,
      );
      if (_matches(owner, generation)) {
        // Intake can repair stale descriptors even when this candidate fails.
        // Publish the complete durable survivor list instead of stale RAM.
        final reconciled = await _staged.reconcileAndLoad(owner);
        if (_matches(owner, generation)) {
          if (reconciled case Success<List<AdminSubmissionStagedAsset>>(
            :final value,
          )) {
            _state = _state!._copy(assets: value);
          } else {
            _state = _state!._copy(ready: false, assets: const []);
            if (acquired is Success<AdminSubmissionStagedAsset>) {
              return Result.error(
                (reconciled as Error<List<AdminSubmissionStagedAsset>>).error,
              );
            }
          }
        }
      }
      return acquired;
    });
  }

  /// Removes a captured exact descriptor, retaining its durable parent.
  Future<Result<void>> remove(AdminSubmissionStagedAsset asset) {
    final generation = _generation;
    return _serialize(() async {
      if (!_matches(asset.owner, generation) || !_state!.ready) {
        return _unavailable();
      }
      if (!_state!.assets.contains(asset)) return const Result.success(null);
      final removed = await _staged.remove(
        owner: asset.owner,
        digest: asset.digest,
      );
      if (removed is Success<void> && _matches(asset.owner, generation)) {
        _state = _state!._copy(
          assets: _state!.assets
              .where((entry) => entry.digest != asset.digest)
              .toList(),
        );
      }
      return removed;
    });
  }

  bool _matches(AdminDraftOwner owner, int generation) =>
      _generation == generation && _state?.owner == owner;

  Result<void> _unavailable([String message = 'Local owner is unavailable.']) =>
      Result.error(Exception(message));

  Future<Result<T>> _serialize<T>(Future<Result<T>> Function() action) async {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    _pending++;
    await previous;
    try {
      return await action();
    } finally {
      _pending--;
      released.complete();
    }
  }
}
