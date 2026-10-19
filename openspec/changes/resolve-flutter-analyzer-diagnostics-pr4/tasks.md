## 1. Preflight dell'apply e congelamento evidenze

- [x] 1.1 Ottenere autorizzazione separata all'apply dopo la review avversariale del piano; rileggere richiesta, AGENTS.md/istruzioni annidate e i quattro artifact PR4. Verificare che la review non abbia lasciato conflitti su FutureOr, fake P/H, gallery o ownership; riportare i blocker invece di ridisegnare implicitamente.
- [x] 1.2 Registrare branch/HEAD, status completo, index/staged, unstaged/untracked, diff/check e hash preesistenti. Identificare e approvare lo SHA dell'ultimo origin/main verificato contro il remoto al momento dell'apply; il branch PR4 deve discenderne. 142a54fd6659ca76d6a33a252821239934fa6dce e 556c62b0d1e57dbebc24d2fb2e19da1785aeab09 sono riferimenti storici, non basi imposte: riconciliare ogni avanzamento di main su codice/configurazione/analyzer/identità prima degli edit. Con lavoro utente presente preferire un worktree isolato da quella base e trasferire solo gli artifact PR4 approvati, senza contenuti PR3 o rename degli artifact archiviati. Preservare AGENTS.md e ogni lavoro estraneo; vietati reset, clean, force push o checkout distruttivi. Verificare ancestry e diff contro lo SHA base registrato; non creare branch/worktree nella remediation documentale.
- [x] 1.3 Confermare Flutter/Dart effettivi, lockfile, very_good_analysis, analyzer options e OpenSpec. Eseguire flutter analyze --no-pub e salvare output/exit reale e ledger severity/messaggio/file/linea/colonna/regola/molteplicità fuori sorgente. Verificare tutte le 57 identità della matrice e le 125 Command dell'appendice; se cambiano conteggi/identità riconciliare la provenienza e aggiornare il piano prima dell'implementazione interessata, senza espandere scope.

## 2. Caratterizzazioni mirate prima degli await

- [x] 2.1 Caricare le skill test applicabili del design D7 e cercare test/support prima di ogni nuovo helper. Per ogni test nuovo motivare il gap/invariante non già dimostrato, riusando suite e fixture senza duplicare harness, test per riga o dettagli interni; non indebolire assertion esistenti né omettere proprietà necessarie di FutureOr/ownership/concorrenza. In test/utils/result_test.dart aggiungere soltanto i gap R: cinque rami callback con throw sincrono e differito (Exception/StateError), Future pendente, valore/Result e identità, non invocazione ramo opposto asyncFold e casi sync assenti. Verificare che passino sul codice pre-cleanup, con observer errore associati prima di completeError e senza delay arbitrari.
- [x] 2.2 Estendere test/utils/debounceable_test.dart per supersession/argomento, callback avviata pendente, risultato/errore e cancel dopo avvio, usando Completer e tempo virtuale Flutter. Verificare sul codice pre-cleanup che le call cancellate/superate completino null senza callback e quella già avviata completi col suo risultato/errore; mantenere i due test esistenti.
- [x] 2.3 Colmare il gap category con il test widget indicato nel design: bottom sheet e dialog a size class diverse, callback/reset solo dopo chiusura, chiusura dopo unmount senza pubblicazione. Riutilizzare harness/tema/supporto già presenti, caricare mounted-context-safety per eventuali callback toccate e verificare i casi sul codice pre-cleanup senza cambiare guard o routing produttivi.
- [x] 2.4 Estendere gallery_preview_screen_test.dart soltanto per integrazione share/feedback/pending/dispose secondo F1/F3 del design. Riutilizzare FakeCacheManager.streamFactory → getFileStream e lasciare eseguire l'extension getSingleFile reale: FileInfo con file in memoria/path non vuoto per successo, Stream.error o vuoto per un caso di errore cache, StreamController/Completer per pending; nessun mocking diretto/override/shadowing/hook di getSingleFile. Riutilizzare cache_manager_extensions_test.dart senza duplicarne FileInfo/progress/fine stream/errore. Prima di mockare share verificare MethodChannel/piattaforma/versioni risolti e file adeguato; nessun I/O reale non necessario, nuova dipendenza, DI o riassegnazione SharePlus.instance. Caratterizzare baseline per share una volta/path/MIME, log+snackbar su Exception cache/share e unmount con completamento tardivo senza context/feedback. Per il solo StateError verificare prima binding/flutter_test effettivi e osservazione deterministica sulla baseline: il Future non è esposto dal bottone, takeException non è una garanzia. Se gli strumenti esistenti non lo consentono, non aggiungere quel singolo test e documentare limite + audit del catch on Exception invariato; nessun nuovo global error handler, seam, skip o modifica al catch. Registrare e ripristinare handler del canale/temporanei, chiudere controller e risolvere pending/errori prima del teardown, senza interferenze. Conservare gli altri test gallery; fallimenti preesistenti deterministici richiedono riconciliazione, non fix opportunistico.

- [x] 2.5 In mapped_use_cases_test.dart aggiungere il solo gap pendingGetAll descritto in U: ExploreUseCase.getAllPlaces mantiene richiesta pendente, count/sort registrati, identità del Result e propagazione dello stesso errore differito; observer associato prima del completeError. Verificare sul codice pre-cleanup senza nuovi fake o delay; conservare test fallback esistenti e dichiarare i limiti pendingCreate/pendingClearSession senza fingere copertura diretta.

## 3. Deleghe dominio e digest — 18 occorrenze

- [x] 3.1 Nei cinque UseCase applicare A alle 17 righe della matrice, conservando async, firme/override, Results, sort/default, id/categorie e coordinate. Verificare il diff delle 17 deleghe e test/domain/use_cases/mapped_use_cases_test.dart; nessuna modifica ai repository contract o ai metodi vicini non diagnosticati.
- [x] 3.2 In _isValidFinal aggiungere await soltanto a _hasDigest; verificare null/tipo/size/ordine/errore invariati e test/data/repositories/content_submission_staged_asset_repository_impl_test.dart verde. Nessuna modifica al digest, persistenza, generatori o backend.

## 4. Result e Content Submission — 10 occorrenze

- [x] 4.1 Applicare R ai cinque target result.dart: await nei due return callback asyncFold e nei soli bracci callback di asyncFlatMap/asyncFlatMapError/asyncGetOrElse. Conservare rami immediati, this e Exception/Result identity senza nuovi catch/wrapper; verificare tutti i test Result e le caratterizzazioni 2.1, incluso nessun throw sincrono esposto dal metodo async.
- [x] 4.2 Applicare A ai cinque target VM (checkpointDraft, restoreCheckpointDraft, _checkpointDraftInsideBoundary, retry _submit, closure _clear). Verificare che _serialize/_lifecycleTail, initialize, acknowledged try/finally PR3, pending/owner/dirty/disposed guard e Command siano identici nel diff; non spostare return oltre i boundary.
- [x] 4.3 Eseguire l'intera suite content_submission_view_model_test.dart e le suite screen/progress del design. Verificare in particolare i test Completer di checkpoint fallito/retry, dirty con picker pendente, clear accodato, ownership, finalizzazione locale pendente/fallita con retry senza secondo remoto e dispose. Registrare risultati reali e nessun nuovo test duplicato per invarianti già dimostrati.

## 5. UI e utility — 5 occorrenze

- [x] 5.1 Applicare A ai due return di _showAdaptiveSelectionWidget e G al callback share gallery. Verificare firma callback void-compatible ma async, guard mounted, catch Exception, risultato popup e aggiornamenti post-chiusura invariati; eseguire i test category e gallery esistenti/nuovi di 2.3–2.4.
- [x] 5.2 Applicare A a Debounced.call e AppLogger._addBreadcrumb. Verificare cancel/timer/callback order, log fire-and-forget/unawaited, Sentry flag/filter/data/captureException e assenza di catch aggiuntivi; eseguire debounceable_test.dart e logging/app_logger_test.dart. Conservare log sincrono, unawaited intenzionale, nessun nuovo catch o conversione in Result.error. Riutilizzare RecordingSentryTransport; se addBreadcrumb failure non è osservabile deterministicamente con strumenti esistenti, dichiarare il limite e verificare conservazione strutturale con code review, senza seam produttivo e senza dichiarare testato il failure path non eseguito.

## 6. Fake e callback test — 24 occorrenze

- [x] 6.1 Applicare A al pending di Cloudinary prepare e P a ExternalUrlService.launchGenericUrl. Verificare registrazione call/started signal/queue, URL record, fallback e canale errore invariati; eseguire cloudinary_upload_client_impl_test.dart e content_submission_screen_test.dart, inclusi pending preparation cancel e external boundary.
- [x] 6.2 Applicare A ai sei pending admin (list/create/update/promote/addAsset/deleteAsset). Verificare counters/input/sourceOptions/queue e mancato consumo del fallback durante pending; eseguire suite admin editor/list/dashboard della tabella F-admin, senza fake generici nuovi.
- [x] 6.3 Applicare P/H ai sei target event/place (year/date/setFavouriteEvent/getAll/getFavouritePlaceIds/setFavouritePlace) e H+P a weather. Conservare fallback lazy, handler argomenti, count/date/sort/coordinate registrati prima del primo await e identità Result; eseguire mapped_use_cases, event VM/screen, geo_map VM, favourite VM/button e weather VM/button elencati nel design.
- [x] 6.4 Applicare A al submit fake e acquire, P ai sei target staged/draft (clearSession/reconcileAndLoad/remove/loadDraft/saveDraft/clearDraft), A alla seconda picker call nel test VM. Verificare creazione/consumo/reset dei Completer, snapshot lista, filesystem fallback sync, contatori e osservazione in flight; rieseguire la suite VM sul candidato con tutti i fake modificati, senza eliminare le sospensioni configurabili.

## 7. Validazione integrata e review indipendente

- [x] 7.1 Eseguire dart format con soli path Dart effettivamente modificati nella matrice e nei test/supporto mirati; registrare lista e diff del formatter. Verificare assenza di modifiche a Command, command_it/RestartableCommand, dipendenze/lockfile, analyzer/lint, CI/protection, ObjectBox/generati, backend/Supabase, altre change, AGENTS.md e specifiche canoniche rispetto al preflight.
- [x] 7.2 Sul candidato finale eseguire tutte le suite mirate della tabella D7 e flutter test --no-pub --reporter json completo. Registrare exit/pass/fail/skip reali; verificare che skip preesistenti conservino condizioni/testo e non siano contati come pass. Nessuna nuova esclusione o assert indebolita; motivare i nuovi test con gap reali e verificare invarianti osservabili, senza assertion sul numero di microtask, delay arbitrari o identità del Future interno. Documentare separatamente eventuale omissione autorizzata del solo test gallery StateError (2.4, nessuno skip) e failure path Sentry non eseguito (5.2); diagnosticare ogni regressione senza ampliare il cleanup.
- [x] 7.3 Eseguire flutter analyze --no-pub sul medesimo candidato, acquisendo il vero exit code e nuovo ledger. Verificare zero target, zero errori/warning, nessuna nuova diagnostica e — a baseline invariata — esattamente 125 info Command. Confrontare multiset completi, compresi duplicati, messaggi e colonne; attribuire ogni spostamento alla stessa occorrenza sorgente tramite diff. Exit 1 accettabile soltanto per quelle deprecazioni.
- [x] 7.4 Eseguire git diff --check e git diff --cached --check; audit separato whitespace untracked e confronto hash/status/index rispetto al preflight. Verificare soltanto modifiche PR4 autorizzate e nessun lavoro estraneo perso o incluso; documentare eventuali problemi preesistenti senza correggerli fuori scope. Prima della readiness per pubblicazione riconfermare origin/main remoto e SHA base approvato, ancestry/merge-base del branch PR4 e intero diff rispetto alla corretta base main (non solo modifiche unstaged); se main avanza riconciliare drift e verifiche. Nessun commit esclusivo del vecchio branch PR3 né ripristino/spostamento dei suoi artifact già archiviati deve essere introdotto dalla PR4 rispetto alla base; non reintrodurre modifiche PR3 già integrate.
- [x] 7.5 Riconciliare tutte le 57 righe con diff/test finali, invarianti D1–D7 e artifact. Eseguire openspec validate resolve-flutter-analyzer-diagnostics-pr4 --strict --no-interactive e status/instructions per confermare specs skipped, esattamente quattro artifact e nessuna delta spec.
- [x] 7.6 Ottenere review avversariale indipendente dell'implementazione e del piano, focalizzata su FutureOr, scheduling osservabile, branch fallback dei fake, throw/Result, gallery void callback, coda/ownership/ack retry/dispose e identità delle 125 info. Risolvere findings in scope e ripetere soltanto verifiche giustificate da edit/fallimenti; produrre report motivato di readiness o blocker. Nessun commit/push/PR/merge/sync/archive è autorizzato da questo piano.


## Apply verification report — 2026-10-19

### A. Worktree isolation e autorizzazione

L'utente ha autorizzato esplicitamente apply e nuovo worktree, dopo review indipendente del piano; le precedenti indicazioni planning-only restano storiche. Nessun commit, push, PR, merge, sync o archive eseguito.

- Checkout originale: `/Users/benitomatteobercini/Developer/Progetti/moliseis_v2`, branch `codex/resolve-flutter-analyzer-diagnostics-pr3`, HEAD `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`. Stato iniziale: AGENTS.md modificato preesistente, quattro artifact PR4 untracked, index vuoto. Snapshot/hash dei 1071 file censiti, status, diff staged/unstaged preservati.
- Eseguito `git fetch origin main`, exit 0; origin/main resta `142a54fd6659ca76d6a33a252821239934fa6dce`, uguale alla baseline storica. Nessun drift del piano. Il main locale PR2 non è stato usato o modificato.
- Creato nuovo worktree `/Users/benitomatteobercini/Developer/Progetti/moliseis-pr4`, branch `codex/resolve-flutter-analyzer-diagnostics-pr4`, HEAD iniziale/finale `142a54fd6659ca76d6a33a252821239934fa6dce`. Nomi liberi, nessun worktree riusato o cancellato. Creazione prima di qualsiasi test/code edit/task check.
- Copiati soltanto i quattro artifact approvati; SHA-256 sorgente/destinazione identici prima/dopo copia. Nessun AGENTS.md locale, artifact PR3, credenziale o altro file importato. Metadata/proposal/design restano byte-identici anche dopo apply; solo questo tasks.md è aggiornato.
- Riconferma finale remota mediante git ls-remote: main ancora a 142a54fd…; merge-base/ancestry e HEAD coincidono con la base. Zero commit del branch PR4 oltre origin/main. Verifica finale del checkout originale: branch/HEAD, index/staged, status, diff e hash file invariati.

Hash degli artifact al trasferimento (tasks.md è successivamente aggiornato come autorizzato):

| File | SHA-256 |
| --- | --- |
| `.openspec.yaml` | `fbeccb8e6385e25552f368fd6265fb9ae44bc41667c902cfb823162523f04f0b` |
| `proposal.md` | `74898d9b23aa50f6d4b114f8450ee20e10d56a16e1d6d899a45035af65c4386e` |
| `design.md` | `78d521e46ccd8fe583e5a47de8b493c5b6e7d0106aa2afc48da5b6a00b6ce867` |
| `tasks.md` | `5e52b4c71f60d0509d42f45c42131a5351716dbfdb99addf4c27d685c75aa422` |

### B. Implementation e corrispondenza con il piano

21 file Dart: 12 produzione, 8 test/supporto esistenti, 1 nuovo test category. Nessuna dipendenza, firma, Result contract, Command, opzione analyzer, workflow/CI, backend, schema/generatore o spec canonica modificata. Tutti i target conservano async.

| Area | Eliminati | Strategia / invarianti |
| --- | ---: | --- |
| Cinque UseCase + digest repository | 18 | A; deleghe/parametri/sort/Result/errori e guard digest invariati |
| Result | 5 | R; await solo callback selezionati, rami immediati/this e errori invariati |
| Content Submission | 5 | A; initialize/coda/_lifecycleTail, owner/ack/finalize/retry/dispose/dirty invariati |
| Category/gallery/debounce/logger | 5 | A/G; dialog/sheet, callback async void-compatible, mounted/on Exception, cancel e unawaited invariati |
| Fake e callback test | 24 | A/P/H; record/count sincroni, consumo pending, handler/fallback lazy e Completer invariati |
| **Totale** | **57** | Nessuna soppressione o rimozione async |

File di produzione:

```text
lib/data/repositories/content_submission_staged_asset_repository_impl.dart
lib/domain/use-cases/category_use_case.dart
lib/domain/use-cases/explore_use_case.dart
lib/domain/use-cases/favourite_get_ids_use_case.dart
lib/domain/use-cases/geo_map_use_case.dart
lib/domain/use-cases/post_use_case.dart
lib/ui/category/widgets/category_content_and_type_selection.dart
lib/ui/content_submission/view_models/content_submission_view_model.dart
lib/ui/gallery/widgets/gallery_preview_modal_overlay.dart
lib/utils/debounceable.dart
lib/utils/logging/app_logger.dart
lib/utils/result.dart
```

Test/supporto modificati o aggiunti:

```text
test/domain/use_cases/mapped_use_cases_test.dart
test/support/fake_cloudinary_upload_preparation_client.dart
test/support/fake_external_url_service.dart
test/support/fake_repositories.dart
test/ui/content_submission/view_models/content_submission_view_model_test.dart
test/ui/gallery/widgets/gallery_preview_screen_test.dart
test/utils/debounceable_test.dart
test/utils/result_test.dart
test/ui/category/widgets/category_content_and_type_selection_test.dart
```

Adattamenti puntuali: aggiunte graffe al ramo retry _submit perché il wrapping dell'await produceva curly_braces_in_flow_control_structures; nessun cambio della condizione. Chiarimento del ledger approvato: la riga 48, baseline fake_repositories.dart:1149:5, nomina FakeContentSubmissionRepository.submit ma appartiene in realtà a **ControllableSubmissionRepository.submit**. Applicato al sito esatto approvato con il medesimo Future/Completer e strategia A; nessuna estensione del perimetro. La matrice storica resta congelata, questa nota ne corregge l'etichetta.

### C. Test, ambiente e limiti

SDK verificato: Flutter 3.47.5 / Dart 3.13.4; very_good_analysis 11.0.0 e command_it 9.5.2 da lockfile. `flutter pub get --enforce-lockfile`: exit 0, lockfile invariato. Nessuna generazione o copia di configurazioni/segreti locali.

Il primo run baseline di otto suite ha prodotto 251 pass e 39 fail, exit 1, per runtime ObjectBox assente nel worktree appena creato (29 repository e 10 VM, con errori setup/teardown). Predisposto solo `lib/libobjectbox.dylib` ignorato da Git: asset ufficiale ObjectBox C 5.3.2 macOS universal, digest dell'archivio verificato contro il digest della release ufficiale GitHub `680c598573ede04b9762565d48d4e161ad286f786f159abb8da89353bfa1d0bc`; SHA-256 dylib estratta `1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751`. Nessun sorgente/dependency cambiato per l'ambiente. Rerun dei due file interessati: 161 pass, 0 fail, exit 0. Altre 15 suite consumer baseline: 424 pass, 0 fail, exit 0. Baseline effettiva verificata prima delle trasformazioni: 23 suite esistenti, 714 casi distinti passati (i rilanci parziali non sono conteggiati due volte).

43 nuovi casi: Result 28 (cinque rami FutureOr pending, throw sincrono/differito Exception/StateError, selezione ramo e identità), UseCase 1 (getAll pendente/count/sort/Result/error identity), debounce 3 (supersession, pending/cancel/result/error), category 5 (due form factor e due selezioni, close/reset, unmount), gallery 6 (cache pending→FileInfo→share una volta/path/MIME, error feedback cache/share, completamenti dopo unmount). Nessun helper/fake generico nuovo; supporti riusati e assertion esistenti soltanto rafforzate.

Nuove caratterizzazioni sulla produzione ancora invariata: Result/UseCase 125 pass e UI/debounce/extension 22 pass, entrambi exit 0. I primi tentativi UI falliti riguardavano setup GoRouter/ScaffoldMessenger e coordinamento fake/real event queue; un tentativo con barriera non raggiunta è stato interrotto (exit 130). Corretti esclusivamente i test: uso di tester.runAsync e segnali osservabili di cancellazione stream/ingresso channel, senza delay o conteggio microtask. Nessuna modifica produttiva per adattarla ai test, nessuna assertion indebolita o nuovo skip.

Verifiche dopo le modifiche: gruppo Result/domain/repository 154 pass; gruppo VM/screen/progress/logger 226 pass; UI finale 22 pass; tutti exit 0. Sul candidato finale formato e congelato:

| Gate | Pass | Fail | Skip | Exit |
| --- | ---: | ---: | ---: | ---: |
| 24 suite mirate integrate | 757 | 0 | 0 | 0 |
| Suite autonoma completa, 145 file | 2256 | 0 | 4 | 0 |

Entrambi con `TZ=Europe/Rome flutter test --no-pub --reporter json`; manifest espliciti conservati con i log. La selezione autonoma replica `.github/workflows/pull-request.yml` e `.github/CI.md`: include tutti i test/**/*_test.dart **esclusa test/integration/**. I due test di servizi locali non sono stati eseguiti e non sono contati come skip/pass. Non è uno smoke test parziale; nessun altro file escluso.

Quattro skip upstream preesistenti, dichiarazioni/condizioni/testi invariati:

- test/routing/geo_map_route_test.dart: NAV-01, upstream #188018 inactive Post branch Back.
- test/utils/command_it_disposal_behavior_test.dart: A upstream-like StateError dopo dispose.
- stesso file: B runAsync StateError dopo dispose.
- stesso file: E Molise reporting StateError dopo dispose.

Limiti approvati: test gallery StateError non aggiunto (F3), perché callback void non espone Future e binding.dart:1815 handleUncaughtError termina il test; nessun handler globale introdotto, on Exception invariato e revisionato. AppLogger non forza un failure asincrono addBreadcrumb (N3): log sincrono/unawaited/filtri/captureException invariati, transport esistente riusato, code review strutturale senza dichiarare testato quel failure path. SharePlus verificato sul MethodChannel effettivo con FileInfo/MemoryFileSystem, senza condivisione nativa, rete o filesystem reale non necessario. Non dichiarata equivalenza universale del microtask scheduling o identità del Future interno.

### D. Analyzer e ledger

`flutter analyze --no-pub` baseline: exit 1, 182 info = 57 async_return_with_no_await + 125 deprecated_member_use_from_same_package; zero errori/warning/altri info. Tutte le posizioni target e le 125 identità/molteplicità corrispondono alla matrice/appendice approvate.

Candidato intermedio: exit 1, 126 info =125 Command +1 curly_braces_in_flow_control_structures causata dal formatter; corretta aggiungendo le graffe nel solo ramo retry. Finale: exit **1**, **125 info Command**, zero target, zero errori/warning/nuove diagnostiche. Nessuna modifica ai lint o ai Command.

Confronto strutturato multiset completo: rule/severity/messaggio/file/linea/colonna e duplicati. 125 residui coincidono, zero missing/extra. 123 posizioni identiche; due spostamenti dimostrati dal diff in fake_repositories.dart: **638:17→643:17** e **1108:13→1119:13**, medesime righe Dartdoc con riferimento Command e testo invariato. Il reviewer indipendente ha riprodotto il confronto sul ledger finale. L'exit 1 non è presentato come analyzer verde: è accettato soltanto per le deprecazioni legacy preesistenti.

### E. OpenSpec e stato dei task

Tutti i task vengono completati soltanto dopo le rispettive verifiche: caratterizzazioni prima degli await, gruppi mirati, format, suite autonoma, analyzer/identità, diff audit e review indipendente. Nessuna delta spec, sincronizzazione o archiviazione. Metadata/proposal/design congelati; questo tasks.md contiene checkbox e report dell'apply autorizzato, mantenendo i 25 ID originari.

`openspec validate resolve-flutter-analyzer-diagnostics-pr4 --strict --no-interactive`: exit 0; specs skipped per skip_specs:true, zero delta accettati. Validazione ripetuta sul report finale; nessuna nuova regola di prodotto.

### F. Diff audit

`dart format` limitato ai 21 Dart modificati; verifica finale `--output=none --set-exit-if-changed`: exit 0, zero cambi. Hash dei 21 file congelati prima dei gate finali e ricontrollati invariati durante/dopo test e analyzer. git diff --check e git diff --cached --check: exit 0. Whitespace/newline degli untracked controllati esplicitamente, poiché git diff li omette.

Status finale del nuovo worktree (index vuoto):

```text
 M lib/data/repositories/content_submission_staged_asset_repository_impl.dart
 M lib/domain/use-cases/category_use_case.dart
 M lib/domain/use-cases/explore_use_case.dart
 M lib/domain/use-cases/favourite_get_ids_use_case.dart
 M lib/domain/use-cases/geo_map_use_case.dart
 M lib/domain/use-cases/post_use_case.dart
 M lib/ui/category/widgets/category_content_and_type_selection.dart
 M lib/ui/content_submission/view_models/content_submission_view_model.dart
 M lib/ui/gallery/widgets/gallery_preview_modal_overlay.dart
 M lib/utils/debounceable.dart
 M lib/utils/logging/app_logger.dart
 M lib/utils/result.dart
 M test/domain/use_cases/mapped_use_cases_test.dart
 M test/support/fake_cloudinary_upload_preparation_client.dart
 M test/support/fake_external_url_service.dart
 M test/support/fake_repositories.dart
 M test/ui/content_submission/view_models/content_submission_view_model_test.dart
 M test/ui/gallery/widgets/gallery_preview_screen_test.dart
 M test/utils/debounceable_test.dart
 M test/utils/result_test.dart
?? openspec/changes/resolve-flutter-analyzer-diagnostics-pr4/.openspec.yaml
?? openspec/changes/resolve-flutter-analyzer-diagnostics-pr4/design.md
?? openspec/changes/resolve-flutter-analyzer-diagnostics-pr4/proposal.md
?? openspec/changes/resolve-flutter-analyzer-diagnostics-pr4/tasks.md
?? test/ui/category/widgets/category_content_and_type_selection_test.dart
```

Diffstat tracked (il test category e i quattro artifact untracked non sono inclusi):

```text
 ...nt_submission_staged_asset_repository_impl.dart |   2 +-
 lib/domain/use-cases/category_use_case.dart        |   4 +-
 lib/domain/use-cases/explore_use_case.dart         |   7 +-
 .../use-cases/favourite_get_ids_use_case.dart      |   4 +-
 lib/domain/use-cases/geo_map_use_case.dart         |  12 +-
 lib/domain/use-cases/post_use_case.dart            |   8 +-
 .../category_content_and_type_selection.dart       |   4 +-
 .../view_models/content_submission_view_model.dart |  12 +-
 .../widgets/gallery_preview_modal_overlay.dart     |   2 +-
 lib/utils/debounceable.dart                        |   2 +-
 lib/utils/logging/app_logger.dart                  |   2 +-
 lib/utils/result.dart                              |  10 +-
 test/domain/use_cases/mapped_use_cases_test.dart   |  37 +++
 .../fake_cloudinary_upload_preparation_client.dart |   2 +-
 test/support/fake_external_url_service.dart        |   4 +-
 test/support/fake_repositories.dart                |  71 ++++--
 .../content_submission_view_model_test.dart        |   2 +-
 .../widgets/gallery_preview_screen_test.dart       | 266 +++++++++++++++++++++
 test/utils/debounceable_test.dart                  |  72 ++++++
 test/utils/result_test.dart                        | 148 +++++++++++-
 20 files changed, 605 insertions(+), 66 deletions(-)
```

Nuovo test category: 130 righe, audit separato. I quattro artifact PR4 sono gli unici altri untracked. Runtime ObjectBox ignorato e file tool/build locali esclusi dalla consegna; nessun altro file non ignorato creato o rimosso. Nessun AGENTS.md, artifact PR3, Command/RestartableCommand, config/dependency/CI, generated/ObjectBox schema, backend o canonical spec modificato. Confronto contro origin/main oltre al diff locale: provenienza corretta, nessuna importazione del branch PR3.

### G. Adversarial self-review e review indipendente

| Finding osservato | Severità / natura | Correzione e verifica |
| --- | --- | --- |
| Runtime ObjectBox mancante nel nuovo worktree | Prerequisito ambiente, non regressione PR4 | Asset ufficiale/hash verificato, file ignorato; 39 baseline fail risolti, suite finale completa verde |
| Setup/zone coordination dei nuovi test gallery/category | Difetto test, LOW | Router/key corretti e segnali runAsync/stream/channel; caratterizzazioni baseline e candidato finale verdi, zero handler globali |
| Nuove info meccaniche nei test durante stesura | LOW | Const, typing di throw e observer atteso corretti senza ignore; analisi mirate e analyzer finale senza nuove diagnostiche |
| Ramo retry multilinea senza graffe dopo format | LOW | Graffe locali, condizione/return invariati; analyzer finale125 e test ownership/retry verdi |
| Etichetta inesatta riga48 della matrice storica | LOW, documentale | Target effettivo ControllableSubmissionRepository.submit identificato qui; medesima posizione 1149/Future/Completer/strategia A, nessun cambio di scope |

Autoreview sul diff effettivo: nessuna rimozione async, catch/wrapper/error conversion nuovo, firma o guard mutato; Results e errori conservati, P/H lazy con record sincroni, nessun Future perso, _serialize/ownership/ack retry/dispose invariati. Test non basati su numero microtask o sleep arbitrari. Nessuna assertion preesistente indebolita, nessun nuovo skip, nessuna modifica estranea.

Reviewer indipendente read-only ha esaminato tutti i 21 Dart, nuovo category, artifact e call path VM/cache/share; verificato autonomamente 757 mirati, 2256+4 skip full, analyzer 125/exit1, hash congelati e confronto completo delle 125 identità. Nessun finding materiale rimasto; nessun file modificato dal reviewer. I limiti F3/N3 e native share restano espliciti, non blocker nascosti.

### H. Readiness e limiti della consegna

Tutti i gate autorizzati sono osservati e superati, con analyzer intenzionalmente exit1 per le 125 deprecazioni conservate. Nessun blocker materiale residuo. Nessuna esecuzione di servizi locali/device/native share o dei failure path intenzionalmente non coperti dichiarata come pass. Tutte le modifiche restano non committate nel worktree PR4, checkout originale invariato.

**READY FOR INDEPENDENT IMPLEMENTATION REVIEW**
