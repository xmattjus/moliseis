## Context

Vedere proposal.md per baseline, motivazione ed esclusioni. Audit del 2026-10-18: HEAD `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`, branch PR3, codice identico alla baseline `142a54fd6659ca76d6a33a252821239934fa6dce`. La sola differenza committed è il rename R100 dei quattro artifact PR3 dall'archivio al percorso attivo. Non si trasferiscono o archiviano artifact per uniformare il checkout.

Preflight: solo ` M AGENTS.md`, zero staged/untracked; nessuna istruzione annidata. L'aggiunta GitHub Contribution Workflow è preesistente e vincolante, ma non appartiene alla PR4. `git diff --check` e cached check iniziali: exit 0. Configurazione: include very_good_analysis, `todo: info`, esclusioni generated/platform già presenti, override const e public_member_api_docs false. Lockfile risolve very_good_analysis 11.0.0 e command_it 9.5.2; SDK 3.47.5 / 3.13.4 verificato dal Dart eseguibile e flutter.version.json (framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`). Nessun pub get/upgrade.

OpenSpec 1.12.0; root repo-local rilevato da context, schema configurato spec-driven, nessuna regola aggiuntiva in config.yaml. PR1: 13 cleanup meccanici; PR2: 73 required-named; PR3: 20 diagnostiche comportamentali. I loro artifact e il report PR3 impongono confronto per identità, mantenimento skip upstream e separazione della migrazione Command. La PR3 ha già aggiunto await nella finalizzazione acknowledged dentro try/finally; quel ramo non è un target PR4 e resta invariato. Le specifiche canoniche content-submission-navigation-lifecycle, submit-orchestration, draft-persistence e local-asset-staging sono coerenti con gli invarianti sotto; nessun requisito cambia.

Analyzer effettivamente eseguito: `flutter analyze --no-pub`, exit **1**, 182 info, zero warning/errori; 57 target e 125 deprecazioni Command, nessun'altra regola. Primo avvio sandbox bloccato dalla cache SDK; rerun con autorizzazione riuscito come operazione di analisi. Log/ledger temporanei: `/tmp/pr4-analyze.log`, `/tmp/pr4-diagnostic-ledger.json`. La matrice e l'appendice sotto sono la copia durevole; non dipendere dai file temporanei nell'apply.

### Provenienza per il futuro apply — F2

Applicare la regola della nuova sezione di proposal.md: branch PR4 dall'ultimo origin/main verificato e approvato al preflight, non dal checkout PR3 né da un main locale potenzialmente obsoleto. Congelare SHA della base e verificare che il branch ne discenda; se main avanza, riconciliare codice, analyzer e identità prima degli edit e di nuovo prima della readiness per pubblicazione. Con lavoro utente nel checkout principale preferire un worktree isolato da quella base, senza alterare AGENTS.md o altri file preesistenti. Trasferire soltanto gli artifact PR4 approvati e verificare il diff completo rispetto alla base main: nessuna reintroduzione di commit/modifiche PR3 già integrati né rename degli artifact PR3 archiviati. Non creare branch/worktree in questa remediation; non fare reset, clean, force push o checkout distruttivi.

Riconferma del 2026-10-19: git ls-remote origin refs/heads/main ha restituito `142a54fd6659ca76d6a33a252821239934fa6dce`, uguale al ref origin/main disponibile. Il confronto origin/main ↔ HEAD conferma solo quattro R100 PR3; `lib/`, `test/`, pubspec/lockfile e analysis_options sono identici. Il ref locale main è `6ccc62635d033747159d37c718ad38d961de8376`, quindi obsoleto; il suo diff non va scambiato per drift sopravvenuto sul remoto. Il codice pertinente ai finding è stato riesaminato su origin/main, senza fetch o modifiche ai ref.

## Goals / Non-Goals

Cleanup di 57 occorrenze senza cambiamenti a valori, identità Result, canali d'errore, parametri, side effect, cancellazione, serializzazione e lifecycle. Nessuna rimozione di async proposta: non è dimostrabile l'equivalenza di una delega non-async quando un repository o hook può lanciare prima di restituire il Future. Il fatto che metodi vicini siano già non-async non autorizza ad uniformarli. Identità del Future restituito non è promessa come uguale a quella del Future interno: l'async boundary originale resta presente. Non cambiare contratti Command o introdurre un nuovo modello asincrono.

## Decisions

### D1 — Boundary asincrono e granularità

Preservare async, tipo restituito e ordine di valutazione. Una funzione async già adotta il Future restituito: PR4 non ripara presunti completamenti anticipati. `return await` rende esplicita l'attesa, conserva il canale Future per throw sincroni e non aggiunge catch. Un await dentro try può estendere catch/finally alla conclusione del Future: verificare il contesto di ogni sito, senza trasportare return tra boundary. Nessuna delle 57 espressioni richiede un nuovo catch o modifica del finally.

Strategie applicative per riga:

- **A**: aggiungere await soltanto all'espressione Future già restituita (`return await …` oppure `async => await …`). Nei return condizionali mantenere guard/fallback immediato e side effect prima dell'await.
- **R**: asyncFold attende solo il callback del ramo selezionato. Negli altri tre switch aggiungere await **nel solo braccio callback**, non davanti all'intero switch: `Success => await mapper(value)` / `Error => await mapper(error)` / `Error => await defaultValue()`. I rami immediati rimangono identici. Segue il pattern locale di asyncMap/asyncMapError; nessun nuovo helper.
- **P**: per `pending?.future ?? immediateResult`, conservare il capture locale già presente (e l'azzeramento del campo), poi `if (pending != null) return await pending.future; return immediateResult;`. Se manca un capture, acquisire il pending una volta immediatamente dopo gli effetti già esistenti. Non attendere il fallback immediato, non cambiare consumo/reset dei pending.
- **H**: catturare l'handler una volta nel punto dell'attuale invocazione dopo i side effect; se non null `return await handler(argomenti identici);`, altrimenti restituire l'immediato già configurato. Per weather: handler → pending → result → errore configurazione, stesso ordine lazy; attendere solo i primi due rami, nessuna valutazione anticipata del fallback.
- **G**: callback `() async => await _onSharePressed(context)` conservando la firma Flutter void Function() del consumer. Non sostituire con blocco void che scarta un Future. Non modificare helper, catch o guard mounted.

Non è una sostituzione globale: A distingue Future certi, R callback FutureOr, P/H le alternative immediate dei fake, G il callback Flutter. Rimozione async, Future.sync/value/microtask aggiunti, catch generici, `.then` o wrapper sono alternative respinte: possono cambiare errore sincrono, identità, ordine o ampliare inutilmente il diff. La skill Result locale contiene una regola blanket 'Never throw across layer boundaries': qui prevalgono richiesta esplicita e AGENTS.md, che esigono preservare i throw inattesi; non convertire in Result.error per il lint. Il catch Object già presente in _serialize è comportamento esistente: non aggiungerlo, rimuoverlo o estenderlo.

È stata consultata anche la skill locale molise-is-result-pattern per confrontare i contratti, applicando la precedenza di richiesta e AGENTS.md descritta sopra.

Riferimenti semantici: [Dart async](https://dart.dev/language/async) e [Future error handling](https://dart.dev/libraries/async/futures-error-handling); firme effettive verificate nel checkout/SDK e pacchetti risolti. Il probe del planning su Dart 3.13.4 osservò lo stesso ordine per valore immediato, Future.value e throw sincrono; questo resta un risultato circoscritto, non una garanzia temporale. **N1:** `return future` e `return await future` non garantiscono identica sequenza di microtask né identità del Future. PR4 preserva i contratti applicativi osservabili: ordine degli effetti, stato, completion/errori, ownership, cancellazione e race rilevanti. Test temporali solo se deterministici e motivati da questi invarianti; vietate assertion sul numero esatto di microtask, delay arbitrari o presunta identità con il Future interno. Le identità Result richieste restano distinte dall'identità del Future. Le strategie A/R/P/H/G restano invariate.

### D2 — UseCase e repository

17 deleghe nei **cinque** UseCase (Category 2, Explore 3, Favourite 2, GeoMap 6, Post 4), più _isValidFinal. Preservare oggetto Result/error, sottotipi covarianti (GeoMap/Post espongono ContentBase ma ricevono Event/Place), ordinamento sort/default byName, categorie, id e coordinate `[latitude, longitude]`. Nessun mapping aggiuntivo. Il digest resta SHA-1 su stream dopo validazione null/tipo senza seguire symlink/limite dimensione: nessuna modifica ai filesystem boundary o alla gestione errori esterna.

### D3 — Result FutureOr

Cinque diagnostiche in quattro metodi. Entrambi i rami di asyncFold possono invocare callback sync/pending/throwing; i tre switch hanno un ramo callback e un ramo immediato. Applicare R senza chiamare mai il ramo opposto, senza ricostruire Result prodotti dal callback, conservando `this` sul Success di asyncFlatMapError e l'Exception originale sul ramo Error di asyncFlatMap. asyncGetOrElse deve restituire il valore anche quando T ammette un Future come valore: non introdurre introspezione `is Future` o wrapping generico per correggere il lint. Mantenere il flattening previsto dalla firma async corrente.

### D4 — Content Submission, coda e ownership

`initialize()` memoizza _initializationFuture; _initialize carica il draft, riconcilia staged asset e pubblica soltanto se live. Stato persistito sconosciuto resta quarantinato. checkpoint/restore attendono initialize, ripetono disposed guard e chiamano _serialize. Quest'ultimo cattura la precedente _lifecycleTail e installa release.future **prima** di attendere la precedente operazione; attende action e rilascia nel finally. Non riscrivere coda, catch o generazione del release.

_checkpointDraftInsideBoundary cattura _state per _checkpointDraftSnapshotInsideBoundary; save durevole precede il cambio del checkpoint. Restore cambia soltanto campi draft/eventTimeIssue, non membership asset; dirty resta `_state != _checkpointedDraft`.

_prepareSubmissionAttempt serializza validazione/checkpoint e claim dell'owner prima che un clear accodato possa procedere. _submit carica/valida, esegue upload e remoto una volta. Dopo ack imposta pending + acknowledged e attende finalizzazione dentro il try; finalmente rilascia owner solo se non acknowledged. Il target 748 è il **retry precedente al try**, che deve attendere solo _finalizeSubmittedSession, senza remoto/upload. Nessun early release e nessun secondo submit al retry.

_finalizeSubmittedSession serializza controllo di identità/pending e retirement, libera pending/owner soltanto dopo successo. _clear serializza rifiuto con owner attivo e _retireCurrentSessionInsideBoundary. Retirement è persistence-first: clear draft, poi staged cleanup (reconcile null per persisted unknown), nuova identità solo se non disposed. Cleanup durevole può terminare post-dispose, senza notify/reset di stato incompatibile. Non alterare gestione esistente di errori/Result o Command legacy; i cinque await restano nelle posizioni della matrice.

### D5 — Utility e UI

Debounced.call attende timer.future, controlla timer.isCancelled, poi attende function(parameter). cancel/supersession risolvono null solo prima della callback; non cancellano callback già avviata. Nessun cambio di Timer, durata, argomento o ordine.

_addBreadcrumb attende Sentry.addBreadcrumb, che nel sorgente risolto `sentry-10.0.0-rc.2/lib/src/sentry.dart:310` restituisce Future<void>. log resta sincrono/fire-and-forget con unawaited; Talker, minLevel, flag Sentry, debug exclusion, captureException, merged data e routing degli errori restano invariati. Non fare affidamento su unawaited per assorbire errori; non aggiungere catch o cambiare policy Sentry. **N3:** non rendere log asincrono e non convertire errori inattesi in Result.error; riutilizzare app_logger_test e RecordingSentryTransport. Se il fallimento asincrono di addBreadcrumb non è osservabile deterministicamente con gli strumenti esistenti, documentare il limite e verificare per code review la conservazione strutturale di log/unawaited, filtri, breadcrumb e captureException. Nessun seam produttivo aggiunto soltanto per forzare quel failure path e nessuna dichiarazione di test superato per un percorso non eseguito.

Category mantiene scelta bottom sheet/dialog per window size, Future<T?>, builder/valore di pop e aggiornamenti post-chiusura dei due caller protetti da mounted. Gallery mantiene await cache, context.mounted, await share, catch di sole Exception con logger/snackbar; Error inattesi restano non assorbiti. Il part consumer è void Function()? e inoltra alla callback del bottone: conservare callback async con await, nessun Future scartato nuovo. Nessun nuovo seam di produzione per testare queste operazioni.

### D6 — Fake e callback test

24 target: 23 nei tre support file (1+1+21), più 1 callback FakeImagePicker nel quarto file. La descrizione storica 'quattro file di test/supporto' include il test VM, non un quarto support file. Mantenere effetti osservabili alla chiamata prima del primo await, count/record/copie liste, started signal, comportamento dei pending riusati oppure consumati e fallback lazy. Non trasformare fake submit in risposta pronta né spostare la creazione del Completer dopo un await. La callback picker deve lasciare pendente la seconda invocazione fino al secondPickerResult, mantenendo la prima lista immediata. Nessuna nuova infrastruttura generica.

### D7 — Test per invarianti, non per riga

**N2:** prima di aggiungere ogni test esplicitare l'invariante scoperto e la motivazione del gap rispetto a Result, Content Submission, fake repository, gallery/extension, debounce e Sentry già esistenti. Preferire pochi casi deterministici ad alto valore di regressione: nessun test obbligatorio per ciascuna delle 57 righe, nessun harness/fake duplicato o assertion sui soli dettagli interni. Non alterare o indebolire assertion preesistenti. Questa selezione non autorizza a omettere nuove proprietà reali di FutureOr, ownership e concorrenza; i gap necessari sotto restano vincolanti, salvo la sola prova StateError condizionata da F3.

I codici della matrice rinviano alla strategia di test sotto. Eseguire test mirati dopo la relativa modifica, poi suite completa una volta sul candidato finale. Riutilizzare supporto esistente; prima di future modifiche ai test caricare dart-add-unit-test e molise-is-test-support-reuse, flutter-add-widget-test per widget; ObjectBox test-store se si toccano test repository; mounted-context-safety prima di cambiare callback/State. Nessuna modifica ai test in questa fase di planning.

## Matrice esaustiva

Ogni riga è una diagnostica distinta, severità info, regola `async_return_with_no_await`, messaggio esatto: `Returning a 'Future' without 'await'. Try adding an 'await' or making the body non-async`. Posizioni effettive del checkout, non quelle storiche. Tipo = tipo dell'espressione restituita (FutureOr indica anche alternativa immediata); la firma del metodo resta invariata. Per tutte le righe A/P/H/R/G rimuovere async rischia di cambiare canale dei throw sincroni/completamento: nessuna tale rimozione è autorizzata dal design. Effetti/contesto e test per riga completano questa differenza semantica comune.

### Repository e deleghe dominio

| ID | File:linea:colonna | Funzione | Return expression | Tipo effettivo | Contesto / effetti | Strategia | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 01 | `lib/data/repositories/content_submission_staged_asset_repository_impl.dart:458:5` | `_isValidFinal` | `_hasDigest(file, expectedDigest)` | `Future<bool>` | Prima: null, tipo senza symlink, size sync; nessun catch locale | A | S |
| 02 | `lib/domain/use-cases/category_use_case.dart:20:11` | `CategoryUseCase.getEventsByCategories` | `_eventRepository.getByCategories(categories)` | `Future<Result<List<Event>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 03 | `lib/domain/use-cases/category_use_case.dart:24:11` | `CategoryUseCase.getPlacesByCategories` | `_placeRepository.getByCategories(categories)` | `Future<Result<List<Place>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 04 | `lib/domain/use-cases/explore_use_case.dart:25:52` | `ExploreUseCase.getAllEvents` | `_eventRepository.getByCurrentYear()` | `Future<Result<List<Event>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 05 | `lib/domain/use-cases/explore_use_case.dart:33:12` | `ExploreUseCase.getAllPlaces` | `_placeRepository.getAll(sort: sort)` | `Future<Result<List<Place>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 06 | `lib/domain/use-cases/explore_use_case.dart:39:47` | `ExploreUseCase.getById` | `_placeRepository.getById(id)` | `Future<Result<Place>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 07 | `lib/domain/use-cases/favourite_get_ids_use_case.dart:23:52` | `FavouriteGetIdsUseCase.getEventById` | `_eventRepository.getById(id)` | `Future<Result<Event>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 08 | `lib/domain/use-cases/favourite_get_ids_use_case.dart:26:52` | `FavouriteGetIdsUseCase.getPlaceById` | `_placeRepository.getById(id)` | `Future<Result<Place>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 09 | `lib/domain/use-cases/geo_map_use_case.dart:25:52` | `GeoMapUseCase.getAllEvents` | `_eventRepository.getByCurrentYear()` | `Future<Result<List<Event>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 10 | `lib/domain/use-cases/geo_map_use_case.dart:33:12` | `GeoMapUseCase.getAllPlaces` | `_placeRepository.getAll(sort: sort)` | `Future<Result<List<Place>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 11 | `lib/domain/use-cases/geo_map_use_case.dart:38:58` | `GeoMapUseCase.getEventById` | `_eventRepository.getById(id)` | `Future<Result<Event>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 12 | `lib/domain/use-cases/geo_map_use_case.dart:44:58` | `GeoMapUseCase.getPlaceById` | `_placeRepository.getById(id)` | `Future<Result<Place>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 13 | `lib/domain/use-cases/geo_map_use_case.dart:53:11` | `GeoMapUseCase.getNearEventsByCoords` | `_eventRepository.getByCoordinates([latitude, longitude])` | `Future<Result<List<Event>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 14 | `lib/domain/use-cases/geo_map_use_case.dart:61:11` | `GeoMapUseCase.getNearPlacesByCoords` | `_placeRepository.getByCoordinates([latitude, longitude])` | `Future<Result<List<Place>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 15 | `lib/domain/use-cases/post_use_case.dart:22:58` | `PostUseCase.getEventById` | `_eventRepository.getById(id)` | `Future<Result<Event>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 16 | `lib/domain/use-cases/post_use_case.dart:28:58` | `PostUseCase.getPlaceById` | `_placeRepository.getById(id)` | `Future<Result<Place>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 17 | `lib/domain/use-cases/post_use_case.dart:37:11` | `PostUseCase.getNearEventsByCoords` | `_eventRepository.getByCoordinates([latitude, longitude])` | `Future<Result<List<Event>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |
| 18 | `lib/domain/use-cases/post_use_case.dart:45:11` | `PostUseCase.getNearPlacesByCoords` | `_placeRepository.getByCoordinates([latitude, longitude])` | `Future<Result<List<Place>>>` | Delega; nessun try/catch/finally o side effect locale | A | U |

### Result

| ID | File:linea:colonna | Funzione | Return expression | Tipo effettivo | Contesto / effetti | Strategia | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 29 | `lib/utils/result.dart:87:9` | `asyncFold Success` | `onSuccess(value)` | `FutureOr<R>` | Callback selettivo; nessun catch/finally; rami immediati espliciti | R | R |
| 30 | `lib/utils/result.dart:89:9` | `asyncFold Error` | `onError(error)` | `FutureOr<R>` | Callback selettivo; nessun catch/finally; rami immediati espliciti | R | R |
| 31 | `lib/utils/result.dart:109:5` | `asyncFlatMap` | `switch: Success → mapper(value); Error → Result.error(error)` | `FutureOr<Result<R>>` | Callback selettivo; nessun catch/finally; rami immediati espliciti | R | R |
| 32 | `lib/utils/result.dart:134:5` | `asyncFlatMapError` | `switch: Success → this; Error → mapper(error)` | `FutureOr<Result<T>>` | Callback selettivo; nessun catch/finally; rami immediati espliciti | R | R |
| 33 | `lib/utils/result.dart:143:5` | `asyncGetOrElse` | `switch: Success → value; Error → defaultValue()` | `FutureOr<T>` | Callback selettivo; nessun catch/finally; rami immediati espliciti | R | R |

### Content Submission

| ID | File:linea:colonna | Funzione | Return expression | Tipo effettivo | Contesto / effetti | Strategia | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 21 | `lib/ui/content_submission/view_models/content_submission_view_model.dart:543:5` | `checkpointDraft` | `_serialize(_checkpointDraftInsideBoundary)` | `Future<Result<void>>` | Dopo initialize e guard disposed | A | V |
| 22 | `lib/ui/content_submission/view_models/content_submission_view_model.dart:554:5` | `restoreCheckpointDraft` | `_serialize(() async { … })` | `Future<Result<void>>` | Guard, closure muta campi/notifica solo live; Results immediati nella closure | A | V |
| 23 | `lib/ui/content_submission/view_models/content_submission_view_model.dart:573:5` | `_checkpointDraftInsideBoundary` | `_checkpointDraftSnapshotInsideBoundary(_state)` | `Future<Result<void>>` | Snapshot dentro coda; nessun catch locale | A | V |
| 24 | `lib/ui/content_submission/view_models/content_submission_view_model.dart:748:41` | `_submit retry` | `_finalizeSubmittedSession()` | `Future<Result<void>>` | Dopo initialize; ramo prima del try/finally di primo submit | A | V |
| 25 | `lib/ui/content_submission/view_models/content_submission_view_model.dart:902:7` | `_clear → closure _serialize` | `_retireCurrentSessionInsideBoundary()` | `Future<Result<void>>` | Guard owner nella closure; outer await, errore e notify live | A | V |

### UI e utility

| ID | File:linea:colonna | Funzione | Return expression | Tipo effettivo | Contesto / effetti | Strategia | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 19 | `lib/ui/category/widgets/category_content_and_type_selection.dart:164:7` | `_showAdaptiveSelectionWidget<T>` | `_showGenericSelectionBottomSheet<T>(title: title, children: children)` | `Future<T?>` | Branch size class; context prima chiamata; caller await e mounted dopo chiusura | A | C |
| 20 | `lib/ui/category/widgets/category_content_and_type_selection.dart:169:7` | `_showAdaptiveSelectionWidget<T>` | `showDialog<T?>(context: context, builder: …)` | `Future<T?>` | Branch size class; context prima chiamata; caller await e mounted dopo chiusura | A | C |
| 26 | `lib/ui/gallery/widgets/gallery_preview_modal_overlay.dart:75:36` | `build → onSharePressed callback` | `_onSharePressed(context)` | `Future<void>` | Callback async assegnata a void Function(); helper catch Exception e mounted | G | G |
| 27 | `lib/utils/debounceable.dart:65:5` | `Debounced.call` | `function(parameter)` | `Future<S?>` | Dopo await timer.future e cancellazione; nessun catch locale | A | D |
| 28 | `lib/utils/logging/app_logger.dart:82:11` | `AppLogger._addBreadcrumb` | `Sentry.addBreadcrumb(Breadcrumb(…))` | `Future<void>` | log() usa unawaited; costruzione Breadcrumb/mapping; nessun catch | A | L |

### Fake e test

| ID | File:linea:colonna | Funzione | Return expression | Tipo effettivo | Contesto / effetti | Strategia | Test |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 34 | `test/support/fake_cloudinary_upload_preparation_client.dart:37:30` | `FakeCloudinaryUploadPreparationClient.prepare` | `_pending.removeFirst().future` | `Future<Result<CloudinaryUploadPreparation>>` | Registra call e completa started prima; solo ramo pending consuma queue | A | F-cloud |
| 35 | `test/support/fake_external_url_service.dart:17:5` | `FakeExternalUrlService.launchGenericUrl` | `pendingLaunch?.future ?? result` | `FutureOr<Result<void>>` | launchedUrls.add(url) prima; pending non consumato | P | F-url |
| 36 | `test/support/fake_repositories.dart:236:26` | `FakeAdminContentSubmissionRepository.list` | `pending.future` | `Future<Result<List<AdminSubmission>>>` | listCallCount++; nessun try/catch/finally | A | F-admin |
| 37 | `test/support/fake_repositories.dart:251:26` | `FakeAdminContentSubmissionRepository.create` | `pending.future` | `Future<Result<AdminSubmission>>` | createInputs.add(input); nessun try/catch/finally | A | F-admin |
| 38 | `test/support/fake_repositories.dart:263:26` | `FakeAdminContentSubmissionRepository.update` | `pending.future` | `Future<Result<AdminSubmission>>` | updateIds e updateInputs; nessun try/catch/finally | A | F-admin |
| 39 | `test/support/fake_repositories.dart:304:26` | `FakeAdminContentSubmissionRepository.promote` | `pending.future` | `Future<Result<AdminSubmissionPromotion>>` | promoteCalls/sourceOptions; fallback queue non consumata se pending; nessun try/catch/finally | A | F-admin |
| 40 | `test/support/fake_repositories.dart:409:26` | `FakeAdminContentSubmissionRepository.addAsset` | `pending.future` | `Future<Result<AdminSubmissionAsset>>` | addAssetCalls; nessun try/catch/finally | A | F-admin |
| 41 | `test/support/fake_repositories.dart:417:26` | `FakeAdminContentSubmissionRepository.deleteAsset` | `pending.future` | `Future<Result<void>>` | deleteAssetCalls; nessun try/catch/finally | A | F-admin |
| 42 | `test/support/fake_repositories.dart:557:5` | `FakeEventRepository.getByCurrentYear` | `pendingGetByCurrentYear?.future ?? getByCurrentYearResult` | `FutureOr<Result<List<Event>>>` | counter++; nessun try/catch/finally | P | F-event |
| 43 | `test/support/fake_repositories.dart:564:5` | `FakeEventRepository.getByDate` | `pendingGetByDate?.future ?? getByDateResult` | `FutureOr<Result<List<Event>>>` | counter++, lastGetByDate; nessun try/catch/finally | P | F-event |
| 44 | `test/support/fake_repositories.dart:627:5` | `FakeEventRepository.setFavouriteEvent` | `setFavouriteEventHandler?.call(id, save: save) ?? setFavouriteEventResult` | `FutureOr<Result<void>>` | record (id,save) prima handler; nessun try/catch/finally | H | F-favourite |
| 45 | `test/support/fake_repositories.dart:856:5` | `FakePlaceRepository.getAll` | `pendingGetAll?.future ?? getAllResult` | `FutureOr<Result<List<Place>>>` | counter++, lastGetAllSort; nessun try/catch/finally | P | U |
| 46 | `test/support/fake_repositories.dart:886:58` | `FakePlaceRepository.getFavouritePlaceIds` | `getFavouritePlaceIdsHandler?.call() ?? getFavouritePlaceIdsResult` | `FutureOr<Result<List<int>>>` | handler opzionale; nessun catch; nessun try/catch/finally | H | F-favourite |
| 47 | `test/support/fake_repositories.dart:905:5` | `FakePlaceRepository.setFavouritePlace` | `setFavouritePlaceHandler?.call(id, save: save) ?? setFavouritePlaceResult` | `FutureOr<Result<void>>` | record (id,save) prima handler; nessun try/catch/finally | H | F-favourite |
| 48 | `test/support/fake_repositories.dart:1149:5` | `FakeContentSubmissionRepository.submit` | `_pending!.future` | `Future<Result<void>>` | counter/argomenti e snapshot lista, crea Completer per chiamata; nessun try/catch/finally | A | V |
| 49 | `test/support/fake_repositories.dart:1220:26` | `FakeContentSubmissionStagedAssetRepository.acquire` | `pending.future` | `Future<Result<ContentSubmissionStagedAsset>>` | record, consuma pendingAcquire; fallback copia file sync; nessun try/catch/finally | A | V |
| 50 | `test/support/fake_repositories.dart:1242:5` | `FakeContentSubmissionStagedAssetRepository.clearSession` | `pending?.future ?? clearSessionResult` | `FutureOr<Result<void>>` | record, pendingClearSession=null prima ritorno; nessun try/catch/finally | P | V |
| 51 | `test/support/fake_repositories.dart:1252:5` | `FakeContentSubmissionStagedAssetRepository.reconcileAndLoad` | `pending?.future ?? reconcileResult` | `FutureOr<Result<List<ContentSubmissionStagedAsset>>>` | counter++, pendingReconcile=null; nessun try/catch/finally | P | V |
| 52 | `test/support/fake_repositories.dart:1263:5` | `FakeContentSubmissionStagedAssetRepository.remove` | `pending?.future ?? removeResult` | `FutureOr<Result<void>>` | record, pendingRemove=null; nessun try/catch/finally | P | V |
| 53 | `test/support/fake_repositories.dart:1315:5` | `FakeContentSubmissionDraftRepository.loadDraft` | `pending?.future ?? loadDraftResult` | `FutureOr<Result<ContentSubmissionDraft?>>` | counter++, pendingLoadDraft=null; nessun try/catch/finally | P | V |
| 54 | `test/support/fake_repositories.dart:1325:5` | `FakeContentSubmissionDraftRepository.saveDraft` | `pending?.future ?? saveDraftResult` | `FutureOr<Result<void>>` | called/count/lastSavedState; pendingSaveDraft=null; nessun try/catch/finally | P | V |
| 55 | `test/support/fake_repositories.dart:1334:5` | `FakeContentSubmissionDraftRepository.clearDraft` | `pending?.future ?? clearDraftResult` | `FutureOr<Result<void>>` | called/count; pendingClearDraft=null; nessun try/catch/finally | P | V |
| 56 | `test/support/fake_repositories.dart:1426:5` | `FakeWeatherApiClient.getCombinedWeatherForecast` | `combinedForecastHandler?.call(latitude, longitude) ?? pendingCombinedForecast?.future ?? result ?? Result.error(…)` | `FutureOr<Result<CombinedWeatherForecastResponse>>` | counter/coordinate prima handler; fallback lazy; nessun try/catch/finally | H+P | F-weather |
| 57 | `test/ui/content_submission/view_models/content_submission_view_model_test.dart:3158:17` | `FakeImagePicker.onPickMultipleMedia callback` | `secondPickerResult.future` | `Future<List<XFile>>` | Seconda invocazione: incremento/segnale pickerInvocation prima; prima restituisce lista immediata | A | V |

### Distribuzione verificata

| File | Info target |
| --- | ---: |
| `lib/data/repositories/content_submission_staged_asset_repository_impl.dart` | 1 |
| `lib/domain/use-cases/category_use_case.dart` | 2 |
| `lib/domain/use-cases/explore_use_case.dart` | 3 |
| `lib/domain/use-cases/favourite_get_ids_use_case.dart` | 2 |
| `lib/domain/use-cases/geo_map_use_case.dart` | 6 |
| `lib/domain/use-cases/post_use_case.dart` | 4 |
| `lib/ui/category/widgets/category_content_and_type_selection.dart` | 2 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 5 |
| `lib/ui/gallery/widgets/gallery_preview_modal_overlay.dart` | 1 |
| `lib/utils/debounceable.dart` | 1 |
| `lib/utils/logging/app_logger.dart` | 1 |
| `lib/utils/result.dart` | 5 |
| `test/support/fake_cloudinary_upload_preparation_client.dart` | 1 |
| `test/support/fake_external_url_service.dart` | 1 |
| `test/support/fake_repositories.dart` | 21 |
| `test/ui/content_submission/view_models/content_submission_view_model_test.dart` | 1 |
| **Totale** | **57** |

## Test strategy e copertura dimostrata

I test sono stati letti, **non eseguiti in questo planning**. I risultati verdi riportati nell'archivio PR3 sono evidenza storica e non verificano PR4. Le nuove caratterizzazioni vanno fatte passare anche sulla sorgente prima degli await, per distinguere preservazione da cambiamento di comportamento; aggiungerle prima delle modifiche produttive nel futuro apply.

| Codice | Suite esistente / evidenza | Gap reale e azione futura |
| --- | --- | --- |
| U | `test/domain/use_cases/mapped_use_cases_test.dart`: tutti i cinque UseCase, success/error, forward sort/id/coordinate | Il pendingGetAll del fake condiviso non è configurato da alcun test esistente: aggiungere in questa suite un solo caso ExploreUseCase.getAllPlaces con pendingGetAll, verificando count/sort alla chiamata, risultato ancora pendente, stessa identità Result dopo complete ed errore differito invariato; riutilizzare le prove fallback già presenti. Nessun test per ogni delega. Il canale di throw sync non è esplicitamente asserito: conservarlo per costruzione lasciando async; non promettere copertura esistente su quel punto. |
| S | `test/data/repositories/content_submission_staged_asset_repository_impl_test.dart`: digest valido/errato, size, restore/acquire, symlink | Nessun test nuovo per il solo await del digest. Riutilizzare store/fixture reali esistenti, nessuna modifica storage. |
| R | `test/utils/result_test.dart`: gruppi asyncFold, asyncFlatMap, asyncFlatMapError, asyncGetOrElse. Già provati valori sync e Future.value, molti rami opposti, fallback once, Exception originale ricevuta da mapper | Completare i gap descritti sotto con Completer, same e contatori. Non duplicare le prove sync di fold/getOrElse già presenti. |
| V | `test/ui/content_submission/view_models/content_submission_view_model_test.dart`: `keeps submit running through local finalization and retires once`, `retries failed local finalization without resending remote content`, `claims ownership before a clear queued behind preparation can run`, pending Cloudinary/final request, throw Object pre-ack, checkpoint failure/retry, unknown persisted state, init/clear/picker dispose | Completer/barriere sufficienti sugli invarianti di ownership: nessun nuovo test duplicato. Il campo staged pendingClearSession non risulta configurato nei test: non affermare copertura diretta di ogni hook; i pending draft/reconcile/remove e il confronto sorgente coprono il pattern P condiviso senza una suite fake-per-metodo. Riutilizzare `keeps dirty state scoped to draft fields across asset mutations`, che sospende la seconda picker call con Completer e osserva pickerInvocation; mantenere pending/error control dei fake. |
| C | `test/ui/category/view_models/category_view_model_test.dart` verifica VM, non dialog/bottom sheet; ricerca non trova test del widget target | Aggiungere `test/ui/category/widgets/category_content_and_type_selection_test.dart`: due size class (bottom sheet e dialog), selezione locale e callback solo dopo chiusura, reset del set vuoto al default; una chiusura dopo unmount senza callback/pubblicazione. Riutilizzare harness app/tema esistente in test/support, senza framework nuovo. Nessuna modifica ai mounted guard. |
| G | `test/ui/gallery/widgets/gallery_preview_screen_test.dart`: metadata/page e chrome, nessuna condivisione; `test/utils/extensions/cache_manager_extensions_test.dart` già prova FileInfo, progress prima del file, fine stream senza file ed errore stream | Estendere soltanto integrazione bottone/cache/share/feedback/pending/dispose usando streamFactory e la vera extension; non duplicare le quattro prove della extension. StateError condizionato alla verifica deterministica F3 sotto. |
| D | `test/utils/debounceable_test.dart`: cancel prima timer e cancel idempotente senza pending | Aggiungere supersession (prima call null, callback solo ultima e parametro), callback avviata ancora pending, risultato/errore osservabile, cancel dopo avvio non abortisce callback. Usare testWidgets/pump con tempo virtuale e Completer; non aggiungere package fake_async o delay reali. |
| L | `test/utils/logging/app_logger_test.dart`: Talker/minLevel, flag/debug, breadcrumb info/warning/data, captureException error/critical, runtime Sentry flag; usa `test/support/recording_sentry_transport.dart` e settleCaptures | Riutilizzare. Non è provato routing di un breadcrumb deliberatamente fallito: nessun nuovo seam/pacchetto per forzarlo. Conservazione sostenuta da async + assenza di catch + unawaited invariato; riportare questo limite, non affermare che unawaited assorba l'errore. |
| F-admin | `test/ui/admin/submissions/view_models/admin_submission_editor_view_model_test.dart`, `admin_submissions_view_model_test.dart`; widget editor e dashboard | Usano pending update/promote/add/delete/list; eseguire anche fallback/create dalla suite editor. pendingCreate non ha un consumer test configurato: dichiarare questo limite; il solo await nel ramo già guardato A non giustifica un test fake-per-metodo nuovo. |
| F-event | `test/ui/event/view_models/event_view_model_test.dart`, `test/ui/event/widgets/events_screen_test.dart`; `test/ui/geo_map/view_models/geo_map_view_model_test.dart` | Pending year/date e fallback in flight già esercitati; conservare counters/date e ordine di richiesta. |
| F-favourite | `test/ui/favourite/view_models/favourite_view_model_test.dart`, `test/ui/favourite/widgets/favourite_button_test.dart` | Handler pendingWrite/pendingPlaceIds, rollback/ottimismo e identità esistenti; nessun nuovo harness. |
| F-weather | `test/ui/weather/view_models/weather_view_model_test.dart`, `test/ui/weather/widgets/weather_forecast_button_test.dart` | Pending forecast, handler e coordinate; riutilizzare. |
| F-cloud | `test/data/services/api/cloudinary/cloudinary_upload_client_impl_test.dart` | `cancellation while preparation is pending skips upload` usa whenPreparationStarted e pending; verifica calls e nessuna richiesta server. |
| F-url | `test/ui/content_submission/widgets/content_submission_screen_test.dart` | `blocks native pop while a checkpointed external boundary is pending` usa pendingLaunch e launchedUrls; copre osservazione in flight e integrazione con checkpoint. |

### Nuove prove Result, delimitate

Nel file esistente aggiungere casi tabellari locali, senza una nuova infrastruttura generica:

1. Per i **cinque rami callback** (fold Success/Error, flatMap Success, flatMapError Error, getOrElse Error), callback che lancia sincronicamente un oggetto noto: invocazione del metodo restituisce normalmente un Future; il Future fallisce con `same(error)` e non con Result.error. Ripetere con Exception e StateError per non limitare la garanzia alle Exception.
2. Negli stessi rami, callback registra invocazione e restituisce Completer.future; prima di complete il risultato resta pendente, dopo complete restituisce il valore/Result esatto. Associare l'observer di errore **prima** di completeError; per l'errore differito verificare same(error), nessuna conversione o doppia chiamata. Non usare timeout/delay come prova di pending: usare segnale callback e flush/pump controllato, senza un numero magico di microtask.
3. Rafforzare le prove esistenti: `same(originalSuccess)` nel Success di asyncFlatMapError, `same(callbackResult)` per Result immediato e pending di entrambi flatMap, originale Exception nel ramo Error di asyncFlatMap. Non pretendere same(originalErrorResult) dove l'implementazione costruisce già un nuovo Result.error.
4. asyncFold: aggiungere contatore/throw nel callback opposto (oggi i test verificano il valore ma non la non invocazione); per sync Error fold e sync flatMap/flatMapError aggiungere solo i casi assenti. getOrElse già prova fallback sync, once e soppressione: riutilizzarli.

### Condivisione gallery: prova osservabile senza refactoring

Il helper è privato; guidare `Condividi` nel widget pubblico GalleryPreviewModalOverlay, ospitato dall'app/Scaffold di test nella suite gallery esistente. È sufficiente l'overlay per verificare l'integrazione share: non occorre avviare il caricamento immagini del resto della gallery o duplicare harness. Riutilizzare FakeCacheManager, MockLogger e fixture Media; prima di nuovi helper cercare in test/support.

**F1 — percorso reale.** `lib/utils/extensions/cache_manager_extensions.dart` definisce getSingleFile come extension su CacheManager: attende getFileStream, restituisce response.file al primo FileInfo e lancia Exception se lo stream termina senza file. In gallery la variabile è staticamente CacheManager; un metodo omonimo sul fake non intercetta questa extension. Riutilizzare **senza nuovi hook** il `streamFactory` già presente in `test/support/fake_cache_manager.dart`, che alimenta getFileStream, e lasciare eseguire l'extension reale. Per il successo emettere FileInfo; per errori usare Stream.error, per fine senza file Stream.empty, per attesa/unmount un StreamController con segnale di sottoscrizione/Completer ove utile. Chiudere controller e completare le operazioni in flight nei teardown, senza subscription/errori pendenti tra test. Vietati mocking diretto, override fittizi o shadowing di getSingleFile, wrapper produttivi e DI dedicata.

La suite `test/utils/extensions/cache_manager_extensions_test.dart` già prova FileInfo, progress event prima del file, fine stream senza FileInfo ed errore propagato. Riutilizzarla; non ripetere questi casi nella gallery per dimostrare lo stesso algoritmo. I nuovi test verificano soltanto proprietà d'integrazione mancanti: cache pendente impedisce share; FileInfo porta a un solo share con file/MIME correnti; un caso di Exception dalla cache (Stream.error **oppure** stream vuoto, non entrambi senza un nuovo invariante) e PlatformException da share producono ImageSharingFailed + snackbar; unmount durante cache e success/error tardivo non avvia share né pubblica feedback/context use; share già pendente fallito dopo unmount non pubblica feedback. Raggruppare i casi compatibili senza moltiplicare le prove per riga diagnosticata.

**SharePlus e file.** Le versioni risolte sono share_plus 13.3.1 e share_plus_platform_interface 7.2.0 (lockfile/package_config e sorgenti locali verificati). Il singleton SharePlus.instance cattura SharePlatform; il default MethodChannelShare usa `dev.fluttercommunity.plus/share`, metodo `share`. Nel futuro preflight ricontrollare versioni/implementazione/platform effettivi prima di prescrivere il mock handler. Usare il test messenger Flutter esistente, nessuna riassegnazione del singleton, DI produttiva, dipendenza o import diretto di nuovi pacchetti transitivi. Registrare l'handler soltanto per il test, ripristinare quello eventualmente preesistente oppure rimuovere quello installato in teardown, e risolvere i pending prima della pulizia.

Per i casi che raggiungono share emettere FileInfo con un file in MemoryFileSystem già usato dai test della extension (package:file è già una dev dependency), percorso non vuoto e coerente con la piattaforma VM di test. Nel MethodChannelShare risolto, _getFile restituisce un XFile con path non vuoto senza leggere bytes o interrogare il filesystem; _toPlatformMap inoltra paths/mimeTypes al canale mockato. Quindi basta quel file in memoria: nessuna rete, scrittura temporanea nativa o share sheet reale necessaria. Verificare path/MIME ricevuti dal mock; non affermare che il plugin nativo abbia letto il file in memoria. Se nel futuro apply piattaforma/package richiedono davvero bytes o I/O, riconciliare il test con il sorgente risolto prima di aggiungere fixture: nessun filesystem reale non necessario.

**F3 — Error inatteso: contratto distinto dalla sua osservabilità nel test.** Il catch produttivo rimane `on Exception`: StateError e altri Error non devono essere assorbiti. Il bottone inoltra però una callback void-compatible e non espone il Future: una normale assertion sul Future non è disponibile. Prima di aggiungere questo singolo caso, verificare binding/flutter_test effettivi e caratterizzarne il comportamento sul codice baseline, prima del cleanup. Nel sorgente Flutter 3.47.5 esaminato, takeException raccoglie le eccezioni riportate al framework, mentre il percorso di zona handleUncaughtError può terminare il test come fallito: la sola esistenza di takeException non prova che intercetti questa callback.

Usare soltanto strumenti di raccolta errori già disponibili in flutter_test/supporto se consentono osservazione deterministica, consumo completo dell'errore e nessuna interferenza. Ogni handler temporaneo ammesso dalle infrastrutture esistenti deve essere registrato nel perimetro del test e rigorosamente ripristinato, senza errori asincroni residui; non introdurre un nuovo global error handler, seam produttivo o DI per StateError. Non modificare catch né aggiungere delay o skip artificiali. **Se questa caratterizzazione non consente una prova deterministica, è autorizzato non aggiungere soltanto quel test**: conservare `on Exception`, verificare il diff produttivo e documentare il limite della copertura. Gli altri test gallery restano richiesti; nessun failure path non eseguito va dichiarato testato e questo caso fragile non è un gate obbligatorio dell'apply.

### Esecuzione futura

Dopo le caratterizzazioni e le modifiche, eseguire con `flutter test --no-pub` tutte le suite della tabella, inclusa cache_manager_extensions_test.dart come riuso delle prove della extension: i path abbreviati di F-admin sono rispettivamente sotto `test/ui/admin/submissions/view_models/` e `test/ui/admin/submissions/widgets/` (`admin_submission_editor_screen_test.dart`, `admin_dashboard_screen_test.dart`). Includere inoltre `test/ui/content_submission/widgets/content_submission_progress_screen_test.dart` per il completamento percepito del submit. Eseguire il nuovo test category esplicitamente. Il full gate è `flutter test --no-pub --reporter json` sul candidato finale, con exit/pass/fail/skip registrati. Nessuna garanzia di pass data in planning.

Gli skip preesistenti PR3 includono due opt-in integration (external_event_token/all_day), tre StateError upstream command_it e un upstream routing geo map: ricontarli sull'apply reale, conservando condizioni e testi. Skip non significa pass; nessun enable artificiale, nuovo skip o assert indebolito per nascondere regressioni.

## Diagnostic comparison e acceptance della futura implementazione

Preflight apply: prima verificare la base Git F2 approvata su origin/main e riconciliare ogni drift; poi salvare stdout/stderr completi e vero exit code di `flutter analyze --no-pub` prima degli edit. Derivare ledger con severity, messaggio completo, file, linea, colonna, regola e molteplicità; conservare duplicati (alcune deprecazioni hanno stessa posizione/messaggio due volte). Congelare anche SDK, lockfile, analyzer options, status/diff/index/untracked e hash dei file preesistenti. Rifare esattamente il comando sul candidato finale dopo format/test. Non nascondere exit con pipe/tee: acquisire lo status del processo analyzer.

Criteri:

1. Zero async_return_with_no_await in tutto il repository analizzato; zero errori, zero warning, nessuna nuova diagnostica. Su baseline invariata: esattamente 125 info e soltanto deprecated_member_use_from_same_package legacy Command; nessuna modifica ai Command.
2. Match multiset dei 125 residui su regola, severity, messaggio, file e posizione. File intatti: stessa linea/colonna; file toccati: mappare gli spostamenti al **diff effettivo** e all'occorrenza sorgente identica. Ogni unmatched va spiegato; confronto di soli conteggi o eliminazione delle posizioni è insufficiente.
3. Analyzer exit riportato realmente: atteso 1 esclusivamente per le deprecazioni preesistenti. Un errore tool/cache, regola aggiuntiva o warning non è un successo. Drift indipendente va riconciliato prima dell'apply, senza ampliare implicitamente il perimetro.
4. `dart format` con elenco esplicito dei soli file Dart modificati (12+4 diagnostici, eventuali test/supporto indicati sopra); nessun format di directory o dart fix globale. Audit formatter e nessuna modifica estranea.
5. Test mirati e full Flutter verdi, skip preesistenti separati dai pass. Nessun nuovo skip/asserzione indebolita; contatori, Results, Future pendenti, retry e lifecycle invariati. Motivare ogni nuovo test con un gap reale (N2), senza contare microtask o presumere identità del Future (N1). La sola prova gallery StateError può essere omessa alle condizioni F3 documentate, senza skip; il failure path Sentry non eseguito resta un limite esplicito verificato strutturalmente (N3).
6. Provenienza del branch verificata rispetto allo SHA origin/main approvato e diff completo rispetto alla corretta base main, senza contenuti/rename PR3; riconciliare un eventuale avanzamento prima della readiness per pubblicazione. `git diff --check` e `git diff --cached --check`, con attribuzione alle snapshot preflight; validare separatamente whitespace degli untracked perché Git diff non li include. Zero problemi introdotti da PR4; preesistenze estranee documentate e preservate.
7. OpenSpec validate strict, specs skipped, nessun canonical/delta spec cambiato; review avversariale indipendente del codice e di questi artifact prima di dichiarare l'implementazione pronta. Questa consegna termina prima della review separata del piano.

## Risks / Trade-offs

- Rimozione async espone sync throw o restituisce direttamente il Future interno → mantenere async in tutti i 57 siti, senza assumere identità del Future.
- Await dell'intero switch o del fallback cambia rami immediati inutilmente → R nel braccio callback; P/H attendono soltanto il ramo Future e preservano fallback lazy.
- Estensione involontaria di catch/finally → nessuno spostamento di return e nessun cambio di boundary; PR3 acknowledged branch resta intatto.
- Ownership rilasciata durante finalizzazione o clear sorpassa checkpoint → mantenere _serialize e flag/guard/notify originali, usare test con Completer già esistenti.
- Fake consumato troppo presto/tardi, counter registrato dopo await → confronto sorgente per ogni riga, test in flight dei consumer. Non cambiare consumo pending nulled rispetto ai pending persistenti.
- Test gallery/tempi rivelano errore preesistente estraneo → caratterizzazioni prima del cleanup e confronto baseline; non correggere silenziosamente produzione, fermare il punto in conflitto e riportarlo.
- Controlli di tipo/callback generici superflui → nessun helper nuovo; piccoli branch espliciti secondo P/H. Il diff leggermente maggiore evita di sospendere fallback immediati e resta locale ai fake.
- Copertura incompleta Sentry/native UI/scheduling arbitrario → limiti espliciti, test dei contratti osservabili e source review. Non affermare equivalenza universale sulla base del probe o dei test storici.

## Migration Plan e rollback

Nessuna migrazione, deploy, dipendenza o dato da convertire. Apply solo dopo autorizzazione separata e review del piano. Partire dalla base origin/main verificata e approvata secondo F2, preferendo un worktree isolato con lavoro utente presente; nessuna creazione in questa remediation. Caratterizzare, modificare per gruppi della matrice, verificare mirato, format, full suite/analyzer, confronto identità, review indipendente e ancestry/diff completo contro main prima della readiness per pubblicazione. Eventuale rollback ripristina soltanto gli edit PR4 attribuiti dal diff, preservando lavoro altrui; nessun reset, clean, force push o checkout distruttivo. Non ripristinare/rinominare gli artifact PR3 già archiviati. Nessuna pubblicazione o operazione Git remota autorizzata qui.

## Autoreview del planning e readiness

Tutte le 57 posizioni correnti rappresentate una volta, totali 18 repository/dominio + 5 Result + 5 VM + 5 UI/utility + 24 fake/test. Verificata distinzione tra espressione repository Event/Place e firma ContentBase; distinzione tra retry pre-try PR4 e ack nel try PR3; P/H conservano call-time effects e fallback senza async removal. Nessuna decisione architetturale rimandata all'apply.

Assunzioni da riverificare nel preflight, non blocker attuali: baseline/SDK/distribuzione possono cambiare, i file temporanei non persistono, le nuove caratterizzazioni non sono ancora eseguite. La semantica completa di ogni microtask interleaving non è provata: evitare affermazioni più forti degli invarianti applicativi. Il test logging non forza il fallimento del breadcrumb e i test gallery esistenti non coprono sharing: copertura e gap sono dichiarati, non nascosti. Nessun requisito prodotto nuovo; skip_specs è appropriato.

Stato del piano: **READY FOR ADVERSARIAL REVIEW**, non review superata né implementazione autorizzata. Nessun blocker materiale noto dopo la riconciliazione del checkout. La review separata dovrà contestare in particolare FutureOr, branch P/H, singleton share e ownership prima di apply. Tutti i task futuri restano non completati.

## Appendice — identità delle 125 info Command residue

Ledger baseline durevole, tutte severity `info`, rule `deprecated_member_use_from_same_package`. Messaggio parametrizzato esatto per simbolo S: `'S' is deprecated and shouldn't be used. Legacy compatibility command. Do not use in new code. Use createResultCommand/createResultCommandNoParam for ordinary single-flight actions, or RestartableCommand when newer intent must supersede older work. Try replacing the use of the deprecated member with the replacement, if a replacement is specified`. S è Command, Command0 o Command1 nella tabella. Ripetizioni esplicite nella colonna n conservano la molteplicità.

| File:linea:colonna | Simbolo S | n |
| --- | --- | ---: |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart:23:13` | `Command1` | 2 |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart:24:14` | `Command0` | 2 |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart:39:8` | `Command1` | 1 |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart:42:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:43:12` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:44:12` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:45:14` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:46:15` | `Command1` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:49:12` | `Command1` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:50:15` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:51:22` | `Command1` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:52:13` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:53:19` | `Command1` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:54:16` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:55:19` | `Command1` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:88:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:91:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:94:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:97:8` | `Command1` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:100:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:103:8` | `Command1` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:108:8` | `Command1` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:113:8` | `Command1` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:149:8` | `Command1` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:152:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart:155:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:17:12` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:18:19` | `Command0` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:19:16` | `Command1` | 2 |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:33:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:36:8` | `Command1` | 1 |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart:51:8` | `Command0` | 1 |
| `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart:99:35` | `Command` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:22:12` | `Command0` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:23:29` | `Command1` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:24:15` | `Command1` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:25:24` | `Command1` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:35:8` | `Command0` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:36:8` | `Command1` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:37:8` | `Command1` | 1 |
| `lib/ui/category/view_models/category_view_model.dart:38:8` | `Command1` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:99:16` | `Command0` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:100:21` | `Command1` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:101:14` | `Command0` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:102:13` | `Command0` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:103:26` | `Command0` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:189:8` | `Command0` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:191:8` | `Command1` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:192:8` | `Command0` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:195:8` | `Command0` | 1 |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart:201:8` | `Command0` | 1 |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart:16:24` | `Command` | 1 |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart:131:46` | `Command` | 1 |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart:139:5` | `Command` | 1 |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart:154:21` | `Command` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:19:15` | `Command0` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:21:18` | `Command1` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:22:19` | `Command1` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:23:16` | `Command1` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:30:8` | `Command0` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:31:8` | `Command1` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:34:8` | `Command1` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:37:8` | `Command1` | 1 |
| `lib/ui/event/view_models/event_view_model.dart:221:32` | `Command` | 1 |
| `lib/ui/explore/view_models/explore_view_model.dart:15:18` | `Command0` | 1 |
| `lib/ui/explore/view_models/explore_view_model.dart:21:8` | `Command0` | 1 |
| `lib/ui/explore/view_models/suggestion_view_model.dart:13:12` | `Command0` | 1 |
| `lib/ui/explore/view_models/suggestion_view_model.dart:21:8` | `Command0` | 1 |
| `lib/ui/favourite/view_models/favourite_view_model.dart:20:12` | `Command0` | 1 |
| `lib/ui/favourite/view_models/favourite_view_model.dart:29:14` | `Command0` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:44:18` | `Command0` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:44:25` | `Command0` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:51:18` | `Command0` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:51:25` | `Command0` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:53:29` | `Command1` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:53:36` | `Command1` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:54:24` | `Command1` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:54:31` | `Command1` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:77:15` | `Command0` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:80:15` | `Command0` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:81:15` | `Command1` | 1 |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:82:15` | `Command1` | 1 |
| `lib/ui/post/view_models/post_view_model.dart:13:17` | `Command1` | 1 |
| `lib/ui/post/view_models/post_view_model.dart:14:23` | `Command1` | 1 |
| `lib/ui/post/view_models/post_view_model.dart:15:17` | `Command1` | 1 |
| `lib/ui/post/view_models/post_view_model.dart:21:8` | `Command1` | 1 |
| `lib/ui/post/view_models/post_view_model.dart:22:8` | `Command1` | 1 |
| `lib/ui/post/view_models/post_view_model.dart:23:8` | `Command1` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:23:25` | `Command1` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:23:32` | `Command1` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:24:24` | `Command0` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:24:31` | `Command0` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:31:30` | `Command1` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:31:37` | `Command1` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:56:15` | `Command1` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:61:15` | `Command0` | 1 |
| `lib/ui/search/view_models/search_view_model.dart:72:15` | `Command1` | 1 |
| `lib/ui/settings/view_models/settings_view_model.dart:13:25` | `Command1` | 1 |
| `lib/ui/settings/view_models/settings_view_model.dart:21:8` | `Command1` | 1 |
| `lib/ui/settings/view_models/theme_view_model.dart:11:26` | `Command1` | 1 |
| `lib/ui/settings/view_models/theme_view_model.dart:12:20` | `Command1` | 1 |
| `lib/ui/settings/view_models/theme_view_model.dart:25:8` | `Command1` | 1 |
| `lib/ui/settings/view_models/theme_view_model.dart:27:8` | `Command1` | 1 |
| `lib/ui/sync/view_models/sync_view_model.dart:15:12` | `Command1` | 1 |
| `lib/ui/sync/view_models/sync_view_model.dart:37:8` | `Command1` | 1 |
| `test/support/fake_repositories.dart:43:51` | `Command` | 1 |
| `test/support/fake_repositories.dart:638:17` | `Command` | 1 |
| `test/support/fake_repositories.dart:1108:13` | `Command` | 1 |
| `test/ui/event/widgets/components/events_calendar_test.dart:234:30` | `Command` | 1 |
| **Totale** | | **125** |

## Verifica finale del planning — 2026-10-18

`openspec validate resolve-flutter-analyzer-diagnostics-pr4 --strict --no-interactive`: exit 0, change valid; messaggio esplicito che skip_specs accetta zero delta. Status: proposal/design/tasks done come artifact presenti, specs skipped; ciò non completa alcun task implementativo. Controllo automatico: 57 identità esatte e uniche contro il ledger analyzer, 125 residui con molteplicità, esattamente quattro file, tutti i task unchecked, nessun trailing whitespace e newline finale presente. `git diff --check` e cached check: exit 0.

HEAD/branch invariati. Working tree finale: ` M AGENTS.md` preesistente, hash invariato durante il planning, più soltanto i quattro nuovi artifact PR4 untracked; zero staged. Nessuna modifica a produzione/test/configurazioni o altre change. Autoreview: corretta l'iniziale tentazione di classificare come coperti tutti gli hook dei fake; pendingGetAll richiede una caratterizzazione mirata, mentre pendingCreate/pendingClearSession restano limiti di copertura dichiarati, senza nuovi test ridondanti per ogni riga. Review avversariale separata ancora da svolgere.

## Remediation della review e autoreview finale — 2026-10-19

Le sezioni del 18 ottobre registrano evidenza/readiness del planning originario: allora la review era ancora successiva e la strategia gallery conteneva l'errore rilevato in F1. Questa nota registra la remediation documentale della review fornita dall'utente, senza attribuire retroattivamente le correzioni al planning originario. Non sono stati eseguiti analyzer, test applicativi o prove runtime del binding in questa remediation; i risultati del 18 ottobre restano storici.

| Punto | Stato | Correzione e riferimento | Evidenza / limite residuo |
| --- | --- | --- | --- |
| F1 | CLOSED | Sezione gallery, riga G della strategia test, task 2.4: streamFactory → getFileStream → extension reale, FileInfo/stream controllati; eliminato l'hook fittizio | Extension e quattro test cache_manager_extensions_test letti su codice identico a origin/main. MethodChannelShare 7.2.0 verificato: path non vuoto passa al canale senza I/O, file in memoria sufficiente al test mockato; non è una prova di condivisione nativa. |
| F2 | CLOSED | Proposal base futura, design preflight/rollback/acceptance, task 1.2 e 7.4: origine dall'ultimo origin/main verificato/approvato, drift riconciliato, preferenza worktree isolato e audit ancestry/diff | Remoto e origin/main a 142a54fd…, checkout a 556c62b…, solo quattro R100 PR3; main locale fermo a PR2. La base va riverificata nell'apply; nessun branch/worktree creato ora. |
| F3 | CLOSED | Gallery e task 2.4/7.2: caratterizzazione binding sulla baseline, prova StateError solo se deterministica con strumenti esistenti, handler ripuliti; omissione motivata del solo test se non osservabile | Binding Flutter distingue takeException e handleUncaughtError; callback void non espone il Future. Nessuna prova runtime eseguita qui: il limite può restare documentato, con audit del catch invariato e altri test gallery richiesti. |
| N1 | CLOSED | D1, acceptance e task 7.2: contratti applicativi, nessuna promessa universale di scheduling/identità del Future | Il probe originario è evidenza circoscritta; vietate assertion su numero microtask, delay arbitrari o Future interno. Strategie immutate. |
| N2 | CLOSED | D7, test gallery/extension, acceptance e task 2.1/7.2: motivare ogni gap e riusare suite/supporti | Nessuna espansione per singola diagnostica o duplicazione dei quattro test extension; restano necessari i gap semantici FutureOr/ownership/concorrenza, senza assertion indebolite. |
| N3 | CLOSED | D5, limite L già dichiarato, acceptance e task 5.2/7.2: log sincrono/unawaited, assenza di nuovi catch o Result.error, transport riusato e code review strutturale | Failure asincrono addBreadcrumb non forzato nei test esistenti; non dichiararlo testato, nessun seam produttivo per simularlo. |

Nuova validazione: `openspec validate resolve-flutter-analyzer-diagnostics-pr4 --strict --no-interactive` exit 0, con skip_specs riconosciuto e zero delta accettati. `git diff --check` e `git diff --cached --check` exit 0. Audit esplicito dei quattro file untracked: nessun trailing whitespace, newline finale presente; 25 task/ID invariati e tutti unchecked. Confronto con snapshot pre-remediation: matrice/distribuzione 57, appendice 125, blocco strategie A/R/P/H/G e byte .openspec.yaml identici. Su 1071 file preesistenti censiti risultano modificati soltanto proposal.md, design.md e tasks.md; AGENTS.md, index e ogni altro file preservati, nessuna creazione/rimozione. Status finale conserva gli stessi path iniziali: AGENTS.md modificato preesistente e quattro artifact PR4 untracked.

Autoreview avversariale del diff: eliminata la prescrizione irraggiungibile getSingleFile; verificata la catena reale fino al canale share senza sovrascrivere il singleton; distinto lo StateError non awaitable dai casi Exception osservabili; evitato il main locale obsoleto come base e la reintroduzione degli artifact PR3; controllata coerenza dei task con le eccezioni di copertura F3/N3 e con N1/N2. Nessuna decisione architetturale nuova o modifica alle 57 strategie. Non restano finding aperti o contraddizioni materiali note. **READY FOR APPLY** è readiness documentale dopo remediation/autoreview: non costituisce autorizzazione all'implementazione né una verifica indipendente della remediation. Il piano corretto è consegnato per la successiva verifica indipendente richiesta.
