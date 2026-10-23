# Design

## Context

Vedere proposal.md per motivazione. **VERIFICATO** indica sorgente o comando letto/eseguito su questa baseline; **PROPOSTO** indica il contratto da implementare dopo review; **INFERENZA** indica la conseguenza motivata del sorgente, ancora da provare con i test futuri. Nessun risultato di apply è rivendicato.

### B0 — Preflight e provenienza, 2026-10-21

- Repository: `xmattjus/moliseis`; origin fetch/push `https://github.com/xmattjus/moliseis.git`.
- Checkpoint autorizzato e HEAD del worktree dedicato: `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, parent OpenSpec 1 `9d17d224d5094c5b043128113d9aba6a1ce69f0a`; commit OpenSpec 2 `refactor(category): migrate legacy commands to command_it`.
- Checkout iniziale `/Users/benitomatteobercini/Developer/Progetti/moliseis_v2`: branch main, HEAD `ee60777c7fdfc5c16daa1151050c134fbb7cde29`, status pulito, index senza diff. Anche il ref locale origin/main è a questo SHA. Non è stato fatto fetch, reset o checkout: main non contiene i due checkpoint e non è sostituibile alla base richiesta.
- Riutilizzato `/private/tmp/moliseis-openspec3`, già registrato da Git, detached esattamente sul checkpoint autorizzato, status iniziale pulito e index vuoto. Non esisteva la nuova change. L’isolamento è un checkout distinto, non una copia o un symlink del worktree Category.
- Inventario iniziale degli altri worktree: `.codex/worktrees/27f4/moliseis_v2` a ee60777 detached; `moliseis-worktrees/migrate-category-view-model-commands` a e3d9d891 sul branch `codex/plan-migrate-category-view-model-commands`; `moliseis-worktrees/migrate-simple-view-model-commands` a 9d17d224 sul branch omonimo. Non sono stati modificati né riutilizzati. Nessuna operazione distruttiva necessaria.
- Verifica remota read-only tramite connector GitHub: [PR #12](https://github.com/xmattjus/moliseis/pull/12) aperta, Draft, non merged; head `codex/migrate-legacy-commands` e3d9d891, base main ee60777. Corpo PR documenta 2/7 migrazioni pubblicate e gate ancora pending; non è una prova nuova di suite verde o di approvazione automatica.
- Root OpenSpec risolta da `openspec list --json` e `openspec context --json`: `/private/tmp/moliseis-openspec3`, nearest/repo-local; schema `spec-driven`, config senza context aggiuntivo. Scaffold `.openspec.yaml` creato dal CLI, senza skip_specs. Nessun AGENTS annidato rilevato per le superfici interessate.
- Letti AGENTS.md, proposal/design/tasks/delta di OpenSpec 1/2 e archivio foundation `2026-10-12-adopt-command-it-restartable-foundation` (design/audit evidence), confrontati con produzione effettiva e test. Le sezioni storiche sono distinte dalle remediation finali: D5 di OpenSpec 1 e D8 di OpenSpec 2 sono il pattern lifecycle corrente; la MODIFIED di OpenSpec 1 autorizza continuazioni ordinary vive, inclusa la pubblicazione progressiva. Nessun conflitto Nearby richiede nuovi payload/infrastructure.

### B0.1 — Relocation persistente verificata, remediation F4

Il B0 sopra e il closeout originale sotto sono evidenze storiche del planning in `/private/tmp`; non sono istruzioni operative correnti. Preflight remediation: worktree temporaneo realmente registrato, detached su `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, tracked diff e index vuoti, inventario completo con esattamente i sei artifact attesi untracked. Destinazione assente e non registrata, branch locale destinazione assente; nessun drift rispetto al manifest approvato. PR #12 riconfermata aperta/Draft, head e3d9d891 e base ee60777.

Comandi realmente eseguiti, entrambi exit 0:

```text
git worktree move /private/tmp/moliseis-openspec3 /Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-content-view-model-commands
git switch -c codex/plan-migrate-content-view-model-commands
```

Il primo comando è stato eseguito dal checkout principale, il secondo dal worktree trasferito. Nessuna ricreazione/copia, symlink, remove/prune, reset/clean/rebase/cherry-pick o commit. HEAD iniziale e finale invariato e3d9d891; ancestry 0 commit aggiuntivi. Nuovo percorso registrato, vecchio percorso non più registrato. Branch locale non pubblicato; index ancora vuoto. Hash di ciascun artifact **prima = immediatamente dopo il trasferimento, prima degli edit di remediation**:

| Artifact relativo alla change | SHA-256 identico pre/post move |
| --- | --- |
| .openspec.yaml | `30cfdee007123f96b2ab27ca107e406084602caf445d6b7cd2130ab329668ed3` |
| design.md | `9471379962a56c3d97586aae3a469a4c72b36e0f088c52741a55921d61f68e5c` |
| proposal.md | `891ada5f0592179e65846982e065250585f175e5d18f43eaf7e469b41c7f63a6` |
| specs/command-execution-concurrency/spec.md | `54554baab4f6745ca275d02edd269cbe0d23892c40218bc08c1aff36f03cc94f` |
| specs/home-ongoing-events/spec.md | `6147360877bb34697fe70a2e30c9c780f09f03d4dfa504da8f6b141ca1b06a03` |
| tasks.md | `dcccd65e6f4c67dd331b2400b233f9b9e10439f148167715d02955f1d434814d` |

Tutti i quattro altri worktree conservano gli stessi path, branch/detached, HEAD e status acquisiti prima del move: checkout principale main ee60777; worktree 27f4 detached ee60777; Category branch codex/plan-migrate-category-view-model-commands e3d9d891; Simple branch migrate-simple-view-model-commands 9d17d224; tutti puliti. PR letta soltanto, nessun suo aggiornamento.

**Stato operativo corrente:** `/Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-content-view-model-commands`, branch `codex/plan-migrate-content-view-model-commands`. Tutti i futuri comandi OpenSpec/apply/preflight devono partire qui. I path temporanei nei B0/B1 storici documentano provenienza e run passati, non sono prerequisiti persistenti. Gli hash di proposal/design/tasks/delta concurrency cambiano dopo gli edit autorizzati F1–F3; `.openspec.yaml` e delta Home restano byte-identici anche dopo remediation.

### B1 — Baseline diagnostica riconfermata

Nuova esecuzione realmente completata, non riuso del ledger storico: **105 INFO, zero WARNING, zero ERROR; exit grezzo Dart 0; stderr vuoto**. Tutte le righe sono `LINT|DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`. SDK diretto Dart **3.13.4 stable macos_arm64**; Flutter metadata **3.47.5**. Lockfile e configurazione risolta esistente confermano command_it **9.5.2**, listen_it **6.0.0**; nessun pub get/upgrade/generazione.

Comando misurato, cwd `/private/tmp/moliseis-openspec3`:

```text
/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/moliseis-os3-analyzer-baseline
```

Preparazione non mutativa del codice: `git archive HEAD` estratto in una directory temporanea distinta; copiato il package_config risolto del checkout principale nello snapshot `.dart_tool`, risolti rootUri relativi rispetto alla configurazione originale e impostato soltanto moliseis alla URI assoluta reale dello snapshot. Ogni package root esiste. Nessun metadata o file di produzione scritto nel worktree di planning. L’iniziale tentativo di estrazione con parametro Python `filter` non supportato è fallito prima dell’analyzer; il replay usa l’API disponibile ed è il run qui documentato. Log effimeri `/private/tmp/os3-analyzer.{stdout,stderr,json}`; SHA256 stdout `4555c585ada165fc65c09ccd530bc45a93950be265c02e477da0b0a958c2d545`. Questi file sono evidenze riproducibili, non prerequisiti permanenti.

Identità target riconfermate (linea:colonna, simbolo; una occorrenza per posizione):

| File | Identità baseline | Totale |
| --- | --- | ---: |
| lib/ui/event/view_models/event_view_model.dart | 19:15 Command0; 21:18, 22:19, 23:16 Command1; 30:8 Command0; 31:8, 34:8, 37:8 Command1; 221:32 Command | 9 |
| lib/ui/post/view_models/post_view_model.dart | 13:17, 14:23, 15:17 costruzioni Command1; 21:8, 22:8, 23:8 dichiarazioni Command1 | 6 |
| lib/ui/sync/view_models/sync_view_model.dart | 15:12 costruzione e 37:8 dichiarazione Command1 | 2 |
| test/ui/event/widgets/components/events_calendar_test.dart | 234:30 Command nell’helper di attesa | 1 |

Target futuro **87 INFO**, zero warning/errori e zero nuove identità. Confrontare Counter normalizzato per path/regola/messaggio-simbolo/contesto/molteplicità, non solo il saldo; le linee possono spostarsi. Le restanti 87 identità si ricavano riproducendo il run sullo SHA e sottraendo le 18 sopra. Non nascondere lint con ignore/exclusion/config. Il Dart diretto non rende fatal le INFO per default; nessun `flutter analyze` eseguito qui e il suo exit non si deduce dal Dart. Se eseguito in apply, registrarne separatamente argv/exit, anche nonzero per INFO residue.

### A0 — Audit dei sorgenti e consumer

Letti integralmente i sei file richiesti. Riferimenti di seguito sono relativi alla baseline e vanno ricontrollati se si spostano durante apply.

| Superficie | Evidenza verificata e consumer effettivi |
| --- | --- |
| Event VM | `lib/ui/event/view_models/event_view_model.dart:11–55,94–150,159–250`: quattro Command, autoload annuale, cache anno/giorno, discovery e waiter. |
| Event UI/route | `lib/routing/router.dart:300–337,422–445`: Home e Events hanno owner distinti; Home avvia refresh, Events richiede subito il giorno corrente prima che Provider installi listener. `events_screen.dart:66–88` seleziona giorno; `components/events_calendar.dart:58–97` osserva annuale/marker/retry; `events_modal.dart:60–87` osserva giorno e legge byMonth; `explore_screen.dart:68–104,222–267,275+` osserva ongoing/next e richiede refresh su ritorno/retry. Il menu refresh a :409 forza Sync. |
| Post VM | `lib/ui/post/view_models/post_view_model.dart:10–87`: **tre** Command; due dettaglio e Nearby events→places; late content; guard disposed presenti ma nessun disposal dei Command. |
| Post route/UI | `core_routes.dart:84–170`: valida categoria ereditata/id positivo/type, chiavi Provider e screen `(id,type)`, bootstrap di una sola lane. `post_screen.dart:45–99,124–229`: listener dettaglio/Weather, contenuto solo dopo completed, Nearby loadKey/ownership/coordinate; failure dettaglio oggi resta spinner. Componenti `post/widgets/components/` mantengono rendering e navigazione; `post_section_nearby_content.dart` delega al widget condiviso. |
| Nearby condiviso | `lib/ui/core/ui/content/nearby_content_horizontal_list.dart:17–75,99–180`: presentation record pending/items/error, scheduling post-frame per key e listenable, error/empty/list/partial-error, retry opzionale. Post fornisce items soltanto su successo: il VM conserva partial ma la UI Post oggi li nasconde su aggregate failure. Preservare questa proiezione e onRetry null; non estendere automaticamente la UX partial del componente a Post. |
| Sync VM/UI | `sync_view_model.dart:14–50`: **un** Command, bootstrap se due, force/schedule, fatal soltanto su Result.error senza lastSyncedAt, mai resettato. `sync_screen.dart:19–127`: listener di errore, latch post-frame, fatal retry/loader/EmptyBox; cattura late final owner, da rendere consapevole di replacement. |
| Sync router/DI | `router.dart:83–93,539–595`: refresh su Command value legacy e admin auth; running→syncFor(uri), fatal resta, altrimenti `_validatedFrom`/Home. `dependencies.dart:211–225`: SyncUseCase e SyncViewModel app-scoped; nessun cambiamento scope necessario. |
| Foundation | `lib/utils/command.dart:75–107`: running inline, result null a ogni start, duplicate drop, action inline, catch Object→Result.error + FlutterError.reportError originale. `result_command.dart`: typedef/factory/snapshot; `restartable_command.dart`: envelope autoritativo, switchMap e child settlement privato. `command_configuration.dart`: global handler privacy-aware, reportAllExceptions=false, nessun logging parametri. |

Contratti canonici letti: `command-execution-concurrency/spec.md` (neutral/domain/runtime/assertion, immediate revocation, reporting e cleanup); `canonical-app-routing/spec.md` (id/type e parametri validati, deep links); `main-navigation-shell/spec.md` (branch ancestry, owner retention, predictive back, restoration); `event-temporal-integrity/spec.md` (overlap annuale/giorno, UTC snapshot per next, 30 giorni civili Rome); `home-ongoing-events/spec.md:81–178` (classificazione, snapshot unico, errori/retention, ritorni e coalescing); `local-content-retrieval/spec.md` (materializzazione diretta, atomica, query semantics feature-owned). Non esiste una capability canonical autonoma Sync/Nearby da inventare: il redirect è contrattualizzato dal router/test, Home cita Sync. Per questo i nuovi requisiti Sync/Post sono aggiunti alla capability di concorrenza esistente; nessuna nuova architettura routing.

`SyncUseCase.sync` è stato letto integralmente: cursor server prima dei fetch; lower bound C−24h; quattro prepare concorrenti, anche U=C; commit city/place/event/media in una transazione atomica; soltanto dopo commit salva server cursor e completion timestamp in Settings; errore Settings lascia contenuti committati e cursor precedente per replay; finally chiude la transaction di tracing. La disposizione del VM **non deve interrompere** queste fasi interne già avviate. Nessun edit UseCase, repository, coordinatore o backend.

### A1 — Semantiche effettive command_it 9.5.2

Sorgente locale autoritativo `~/.pub-cache/hosted/pub.dev/command_it-9.5.2/lib/command_it.dart`, `async_command.dart`, e notifier listen_it risolto. `pubspec.lock` vincola questa versione; nessuna deduzione da README/latest.

| API/fatto | Evidenza ed effetto di progetto |
| --- | --- |
| run :312–349 | void async; rifiuta disposed/restricted/busy, mette isRunningSync=true e results loading inline, poi attende zero-delay prima dell’action. Admission immediata, I/O differito. |
| runAsync :859–870 | crea un completer, o restituisce quello già attivo; chiamata concorrente può joinare il lavoro altrui. Se run è rifiutato senza esecuzione attiva, non garantisce un terminale proprio. Mai usarlo come prova di admission. |
| success :369–386 | results terminale **prima** di isRunningSync=false e notifica Command value; completa Future col Result. Command.value può conservare successo vecchio durante running/runtime error. |
| errors :420–446,920–1024 | AssertionError rethrow prima dei filtri; handled error pubblica results terminale prima del global handler e del false nel finally. Factories globalHandler: Result.error è un valore e non viene reportato; raw throw resta Object+stack e il Future runAsync completaError. Nessun secondo report manuale. |
| notifier :249–251,775–779 | results e Command value usano notifier sincroni; soltanto isRunning UI è differito. Restartable espone invece results/isRunning differiti propri. Non generalizzare “snapshot differiti” alle lane ordinary. L’interfaccia osservabile resta results/ResultCommandSnapshot. |
| dispose :799–825 | marca disposing subito e distrugge notifier dopo 50ms; runAsync pendente può completare con value corrente, non con outcome fisico. Raw throw tardivo dopo teardown può fallire sui notifier prima del reporting. False sync/terminale/Future completato isolati non provano fine dispatch. |

Test foundation letti: `test/utils/{result_command_test,restartable_command_test,command_configuration_test,command_it_disposal_behavior_test}.dart`; gli skip upstream che documentano il difetto non sono una soluzione per questi owner. D5 ordinary e wrapper restartable esistenti sono i rimedi già approvati. Non introdurre execute compatibility shim o cambiare foundation.

## Goals / Non-Goals

**Goals:** sette lane ordinary, una sola latest-intent; responsabilità business/orchestrazione nei VM, risultato e admission nel Command, rendering/feedback nelle View. Prove osservabili di identità route/giorno, esclusione sync, retention, terminale e revoca prima di teardown.

**Non-Goals:** nuova UX retry Post/Nearby (invariata); il solo retry manuale Event day F1 è invece in scope. Altre quattro migrazioni, rimozione command.dart, Weather Command, nuova foundation Nearby, nuove route/URI/Provider scope, backend/persistenza/temporality policy, retry automatico, cancellazione fisica, periodic refresh, nuovi package/controller globali/scheduler/adapter, counter di generation duplicati, sync canonical, archive e pubblicazione PR. Nessun edit Dart/test in questo planning. I file di test/support potranno cambiare soltanto dopo apply autorizzato e con le skill di test/lifecycle previste dal repository.

## Decisions

### D1 — Matrice degli otto Command

Legenda comune, parte integrante di ogni riga: **L** attuale legacy = admission/action inline, single-flight/drop per lane, result precedente azzerato al nuovo start; domain error conserva Exception, runtime Object viene impropriamente proiettato in Result.error e reportato con FlutterError originale; nessun disposal delle lane. **O** proposto ordinary = ResultCommand, admission inline/action differita, single-flight/drop senza queue; snapshots non trattengono vecchio data durante loading/error, Command.value non è esito; domain originale distinto da unexpectedError e reporting globale una volta, assertion fail-loud. **R** proposto restartable = nuova authority immediata anche per parametri uguali, retrieval puro e commit nel solo observer vivo; stale runtime resta reportabile senza pubblicazione. **CL** cleanup D5 qui sotto vale per tutte le sette O, con wrapper già responsabile dei child R. Dati VM e Result precedente sono concetti distinti.

| Command / responsabilità | Attuale verificato: consumer, stato, retention, concorrenza e problemi | Proposta / cambiamento desiderato / test discriminanti |
| --- | --- | --- |
| Event.loadAll / bootstrap annuale e marker | L; ctor, calendar/retry e test; VM all + byMonth/selectedDate e command running/completed. Success incrementa yearlyRevision/recompute giorno; failure conserva dati e revisioni. Può correre insieme al giorno. Guard dopo await, assente prima ingresso; Command non disposto. | O<void,void>; autoload run una volta dopo inizializzare le lane/observer; ingresso guarded. Stessa retention; annuale ribasa giorno D2 per non lasciare terminali vecchi. E1/E3/E5, C/L. Nessuna ragione latest-intent per reload annuali sovrapposti. |
| Event.loadByDate / giorno selezionato e fallback | L; route Events, EventsScreen, modal/test. Aggiorna selezione dentro action, cache date+revision evita query, cache annuale nonempty vince; empty fallback success cacheabile, failure retryabile. Durante A le tap B sono scartate. Mancano guard dispose dopo query; con overlap futuro equality A→B→A non basta. Retention su errore: annual-derived giorno (anche []), non contenuti del giorno precedente. | R<Request,DayResult> + metodo VM sincrono selectDate; request immutabile con identità propria date/revision/candidate D2, dati solo nel completion observer; modal completo error/retry e barriera anti-stale F1. Nuovi intent non persi e vecchio A revocato. Annual revision rimane necessaria cross-lane, niente day generation. E2/E3/E4/E5, L. |
| Event.loadOngoing / classificati in corso | L; coordinator, sezioni Explore e test diretti; running/completed/error e ongoing. Success lista atomica in ordine repository; error conserva precedente; lane indipendente da next, singolo pass attende entrambe. Guard prima/dopo await ma lane non disposta. | O<DateTime,void>; stesso snapshot e retention, coalescing nel VM, non restartable. Runtime terminale distinto non deve abortire next. E6/E7/E8, C/L. |
| Event.loadNext / classificati futuri | L; coordinator, sezioni Explore/test; come ongoing sulla lista next; riceve istante caller e non lo ricattura. | O<DateTime,void>; lane separata, ordinata dal coordinator D3. Nessuna latest-intent: ogni pass deve risolvere entrambi i lati. E6–E8, C/L. |
| Post.loadEvent / dettaglio Event | L; core_routes avvia, PostScreen osserva completion per body/Weather, test. Success assegna late content, error non assegna; UI failure resta spinner. Single-flight soltanto propria lane, teoricamente può correre con loadPlace ma nessun consumer reale lo fa; route nuova crea owner. Guard prima/dopo await, no lane disposal. | O<int,void>; preservare lane e route key senza nuovo controller latest-intent. UI hasFailure terminale D4, mai late read, Weather dopo Success reale. P1/P2/P3, C/L. |
| Post.loadPlace / dettaglio Place | L; identica responsabilità su altra route type e stessa proprietà content; stesso rischio teorico cross-lane senza caller. Nessun contenuto precedente trasferito al nuovo VM. | O<int,void>; stessa decisione di loadEvent. Non generalizzare retarget stesso owner; id/type cambia owner. P1/P2/P3, C/L. |
| Post.loadNearContent / dati vicini | L; PostScreen/shared Nearby widget osservano running/completed/error; clear all a ogni action accettata, events→places anche se events Result.error, append lati riusciti, primo errore. Partial list disponibile nel VM, nascosta su failure dalla proiezione Post; onRetry null. Dopo dispose non avvia places. | O<LatLng,void>; continuazioni ordinary vive come delta OpenSpec 1, nessun nuovo outcome wrapper. Clear e partial retention originali; runtime interrompe action e resta unexpected (non avvia fase successiva dopo throw). Proiezione/retry attuali preservati D4. P4/P5/P6, C/L. |
| Sync.sync / protocollo use case e availability routing | L; ctor se due, Explore menu/pull, SyncScreen retry, router refresh; force bool, result + running + fatalError. Duplicate drop; fatal impostato solo true su domain/no timestamp, mai reset; nessun guard/dispose VM. Runtime convertito legacy non aggiorna fatal e può lasciare redirect incoerente. | O<bool,void>; niente restartable per write/transazione. Admission prima frame, force e schedule invariati, fatal corrente per entrambi i canali failure senza confonderli D6; router async wake dopo false sync. S1–S8, C/L; protocollo UseCase invariato anche dopo dispose. |

Reentrancy: run rientrante della stessa lane ordinary mentre true è rifiutato; listener terminale può vedere ancora true e non va usato per lanciare un retry inline. UI retry avviene in callback successivo. Per R, un observer può selezionare B o disporre owner: ogni passo dopo notify deve ricontrollare owner e non effettuare altre assegnazioni di A. CL non dispone inline neppure quando risultano idle. Gli otto comandi non diventano otto nuovi controller di coordinamento.

### D2 — Event: selezione, annuale e revisioni

PROPOSTO: introdurre `selectDate(EventCalendarDate)` come ingresso di orchestrazione sincrono, usato da route e consumer. `loadByDate` resta l’unica R osservata, senza API execute mascherata. La request feature-local immutabile contiene giorno, yearlyRevision e candidato annuale opzionale/cacheable. Per F1 usare una piccola classe payload con identità d’istanza, senza override equality: un record di soli valori non distingue due intent A con parametri uguali. Il VM conserva il riferimento alla **request effettivamente ammessa** (`currentDayRequest`), non un nuovo flag UI/generation counter/controller. L’outcome può restare un record con la request originale e i dati. `_loadedDate`, `_loadedDateRevision`, `_yearlyRevision` mantengono la validità cross-lane, non sostituiscono l’identità dell’intent.

**F5 — Cache singola del giorno, prima di qualsiasi derivazione.** Nel codice baseline `event_view_model.dart:117–150`, `_loadByDate` verifica loadedDate/revision e ritorna **prima** di assegnare `_byDate = getEventsOnDay(date)`. Questo preserva un fallback riuscito con X assente da `_all`. La precedente frase del piano sul candidato derivato dall’annuale non autorizza a ricostruire `_byDate` su un cache hit: confondere questi rami cancellerebbe X anche senza refetch. `_byDate` è il risultato autoritativo del giorno corrente se è stato committato da una request corrente riuscita (annuale oppure getByDate) e la coppia loadedDate/loadedDateRevision è valida. Non è sempre una proiezione di `_all`.

**Ordine esatto di selezione/ammissione F1/F5:** se disposed, no-op. **Prima** di creare request, cambiare selezione, invalidare marker, notificare o derivare dati annuali, verificare insieme: date == selectedDate == loadedDate, loadedDateRevision == yearlyRevision, nessun intent pending (`!isRunningSync`), snapshot corrente completed e request del terminale identica a currentDayRequest con giorno/revisione correnti. Se vero, è cache hit: **return senza alcuna mutazione**, nessuna nuova admission/query/notifica VM, nessuna sostituzione di currentDayRequest o dello snapshot terminale e nessuna nuova sequenza pending. Lasciare intatti `_byDate`, anche se deriva da un fallback nonempty non presente in `_all`, oppure da getByDate Success([]). La UI mantiene grid X o empty terminale; non può diventare skeleton né empty derivato erroneamente da `_all`.

È una cache di **una sola selezione corrente**, non una cache multi-giorno. Se date differisce, la revisione è cambiata o il terminale corrente non è un successo valido, il ramo di hit non è applicabile, anche se un vecchio marker ha valori uguali alla data richiesta. In A→B→A con B ammesso, B ha revocato A: il ritorno ad A crea una nuova request autoritativa, non riesuma il terminale A originale. Negli altri casi, in un’unica sezione sincrona senza await o notify intermedie:

1. Soltanto dopo aver escluso il cache hit, calcolare una volta il candidato annuale in una variabile locale (senza ancora toccare `_byDate`), preparare la nuova request immutabile con quel candidato e assegnarla come currentDayRequest: la vecchia request perde subito l’autorità di commit/proiezione grazie al confronto per identità.
2. Sul ramo **miss/nuovo intent**, invalidare i vecchi `_loadedDate`/`_loadedDateRevision` prima di sostituire `_byDate`, aggiornare selectedDate e assegnare a `_byDate` il candidato annuale locale già calcolato per quel giorno. I marker non possono continuare ad attestare A mentre `_byDate` contiene il candidato di B. Questa derivazione non viene mai eseguita dal ramo cache hit; nessun dato del vecchio giorno rappresenta il nuovo.
3. Chiamare `loadByDate.run(request)`: la foundation revoca atomicamente il proprio vecchio envelope e ammette il nuovo, ponendo isRunningSync=true prima del ritorno. Non chiamare invalidate separatamente: creerebbe una pubblicazione neutral superflua. La revoca applicativa al punto 1 e la revoca foundation al punto 3 sono nella stessa sezione non interrompibile, senza pubblicazioni fra loro.
4. Notificare il VM per ultimo, se vivo; dopo notify non effettuare altre assegnazioni di quell’intent (il listener può rientrare con B o dispose).
5. La R pubblica loading/terminale in modo differito soltanto dall’envelope autoritativo. Il completion observer VM installato prima dei consumer committa il successo e notifica; il rendering usa la proiezione sotto.

**Barriera e identità non sono equivalenti:** isRunningSync è immediato; isRunning e results della R sono differiti. Dopo B ammesso, results può contenere ancora il terminale A. Inoltre la R abbassa isRunningSync prima di pubblicare il nuovo terminale: un controllo del solo false non prova che il terminale pubblico sia già quello corrente. Modal e observer accettano un terminale soltanto se `identical(snapshot.paramData, currentDayRequest)` e giorno/revisione correnti coincidono. In A→B→A la classe payload distingue il primo A dall’ultimo, anche con identiche date/revisioni. Nessuna action R muta VM dopo await. Solo sul ramo miss un candidato annuale nonempty viene risolto come nuovo Success senza repository; il ramo cache hit invece non esegue action o run e preserva l’intero risultato `_byDate` precedente, nonempty oppure empty. Il fast path non può mantenere B autoritativo quando si torna ad A.

**Proiezione EventsModal F1 (ordine dei rami vincolante):** osservare direttamente `Listenable.merge([viewModel, loadByDate.results])`, con rebind del listenable al cambio owner; leggere selectedDate dal VM corrente anche per il titolo, non dal vecchio argomento catturato dal parent. Prima controllare admission sync, poi identità della request/validità dello snapshot, poi gli esiti ResultCommandSnapshot. Nel build leggere i campi VM soltanto sotto queste guardie; il titolo segue il giorno corrente indipendentemente dal terminale precedente. La UI non si iscrive al notifier sincrono e non usa un nuovo loading flag.

| Stato effettivo | Presentazione |
| --- | --- |
| Neutral, nessun giorno risolto | Skeleton |
| Nuovo intent ammesso, isRunningSync true | Skeleton anche se results contiene ancora un precedente terminale |
| Snapshot non corrente per request/date/revision | Skeleton; mai grid, empty o error di A sotto B |
| Snapshot corrente isRunning o idle | Skeleton |
| Snapshot corrente completed, lista nonempty | Grid degli eventi correnti committati |
| Snapshot corrente completed, lista empty | EmptyView “Nessun evento trovato per questa data.” |
| Snapshot corrente domainError | EmptyView.error, messaggio generico e “Riprova”; Exception originale nel Command, zero report globale |
| Snapshot corrente unexpectedError gestito | Stessa error surface e retry; Object/stack originali nel canale runtime e reporting globale una volta, nessuna conversione a Result.error |

Il retry usa una callback dell’owner ancora corrente che legge **in quel momento** `viewModel.selectedDate` e invoca `selectDate` con quel valore. Nessuna data catturata dalla costruzione del vecchio errore, nessun reload annuale, nuovo owner o retry automatico. Failure noncacheabile → nuovo intent/query; success empty/items distinto. Se la callback sopravvive a owner replacement/unmount, deve essere revocata o verificare mounted/current owner prima di accedere allo State; la guard VM rifiuta owner disposto. Post e Nearby non acquisiscono retry UI.

**EventsCalendar F1:** l’attuale ListenableBuilder osserva solo loadAll, mentre il parent EventsScreen usa anche child conservati negli AnimatedBuilder. Osservare direttamente VM + loadAll.results nella porzione che calcola selectedDate e i marker: l’evidenziazione cambia con la notifica di admission, prima dell’action entry, senza dipendere dal Consumer/genitore. Non iscriversi a isRunningSync, non riscrivere calendario/package/marker o temporalità. Modal titolo e body devono avere la stessa selezione VM osservata.

Action: nessun I/O se disposed prima dell’ingresso; candidato fornito → Result.success(outcome); altrimenti un solo getByDate, con revision della request, senza rileggere la selezione per costruire la richiesta. Observer results installato prima di ogni run e dei consumer, ignora loading/failure, committa Success solo se owner vivo e request identica a currentDayRequest, giorno selezionato e revision attuale corrispondono. La foundation garantisce identità dell’intent anche quando le date tornano uguali. Prima della notifica aggiornare insieme byMonth/cache marker. Failure mantiene il candidato già derivato sul ramo miss, lascia i marker invalidi e resta un errore terminale noncacheabile; una tap uguale o Riprova ritenta. Success da getByDate assegna l’intera lista a `_byDate` e marca insieme date/revision anche per Success([]), distinta da failure. Il completion observer committa e notifica soltanto dopo controllo identità request + giorno + revisione, prima che la UI usi quel terminale. Non usare command.value come risultato o modificare la policy temporale.

Annuale: O autoload una volta; soltanto un nuovo Success sostituisce all, incrementa yearlyRevision e invalida la cache della revisione precedente, compresa una lista fallback X assente dall’annuale. Quindi ricostruisce `_byDate` dall’annuale per **l’attuale** selectedDate: non riusa il fallback precedente come cache della nuova revisione. Nonempty marca date/revision; empty azzera entrambi. Se una selezione giorno è già stata richiesta (snapshot non neutro oppure admission R attiva), sostituire currentDayRequest e ammettere nella stessa operazione VM, con l’ordine F1 sopra, un nuovo intent di risoluzione con candidato annuale **anche empty** alla nuova revisione, senza nuova query implicita. Questo revoca qualsiasi fallback precedente, compreso il terminale fallito, e termina la presentazione con il dataset annuale corrente. Empty annuale produce Success empty ma non marca loadedDate: una successiva selezione esplicita può effettuare fallback, come oggi. La richiesta con candidato empty va distinta da “nessun candidato, effettua query”; un campo bool cacheable nel payload locale basta, nessun nuovo dominio Result. Il rebase è un cambiamento intenzionale di outcome della lane giorno per evitare spinner/failure legati a dati già superati; il modal usa la barriera durante il rebase e poi mostra success-items/success-empty senza aspettare il fallback fisico obsoleto; non introduce retry automatico né una seconda query iniziale. Home senza alcuna selezione giorno non avvia la lane giorno a causa dell’annuale.

Concorrenza anno/giorno: in entrambi gli ordini di completamento l’annuale più recente invalida il vecchio dataset; la guard revision resta anche nel commit R. Su annual failure non incrementare revision e non invalidare né derivare nuovamente una cache fallback valida: `_all`, `_byDate` e marker restano invariati. Rientranza da notify annuale può selezionare un altro giorno: fare rebase prima della notifica e non avviare altre richieste dopo notify senza ricontrollo. Il giorno corrente è ricavato via EventTimePolicy Europe/Rome; nessuna data UTC/device reinterpretata come giorno civile. All/day inclusivi e sort startDate/remoteId invariati. Midnight non causa autorefresh: currentCalendarDate usa il clock al momento della richiesta; la passata Home resta legata al proprio istante.

### D3 — Event: refresh Home e settlement

Mantenere nel VM `_homeRefresh`, pending bit e registro di finish temporanei. `refreshHomeDiscovery` non async, così richieste concorrenti ricevono **lo stesso Future**; ogni batch durante una passata richiede una passata successiva, senza una passata per caller. Una richiesta durante la passata successiva può richiederne un’altra: coalescing non è limite globale di due passate.

Sostituire il waiter legacy tipizzato Command con un helper locale sulle lane ResultCommand<DateTime,void>. La condizione coordinativa è `isRunningSync`; le UI osservano results. Installare listener prima della verifica finale e rimuoverlo exactly-once su settlement/revoca, evitando lost wakeup fra check e subscribe. L’attesa è di fine lane, **non** prova di risultato riuscito o del proprio run. Non introdurre runAsync né una catch Object→Result per attendere e assorbire throws.

Algoritmo: prima di iniziare una passata attendere che entrambe le lane siano libere, ricontrollando entrambe dopo ogni attesa e owner prima di I/O. Soltanto allora catturare `_nowUtc().toUtc()` una volta; passare lo stesso DateTime a ongoing, attendere il suo terminale/false, poi a next. Se una chiamata diretta occupa next dopo la cattura, attendere e ammettere il next della passata con **lo stesso** istante. Fare check libero+run nella stessa sezione sincrona, senza await intermedio; una run rifiutata non vale come passata eseguita. Nessun fairness globale fra caller arbitrari promessa; i consumer Home entrano soltanto dal coordinator.

Result.error o handled runtime terminale ongoing non interrompono next; ciascun Command espone il proprio failure/retention e upstream reporta il runtime una volta. Nessun catch del runtime per convertirlo e nessun secondo log nel coordinator. Assert fail-loud non è un normale terminale: il false sync permette rilascio waiter/cleanup, senza falsificare successo della lane. Coordinare non equivale ad attestare successo di entrambi.

Alla revoca: pending=false, staccare/chiudere tutti i waiter anche se la lane fisica è pending, rilasciare il Future pubblico di refresh, senza nuova query; il runner ricontrolla disposed a ogni ripresa. Proteggere completer con isCompleted e identity del proprio `_homeRefresh`, così un finish duplicato non completa due volte né cancella un refresh successivo. Nessuna attesa di physical Future nel dispose. Le liste ongoing/next sono sostituite solo su Success vivo, in ordine repository, error conserva ciascun lato, empty success svuota. Ogni nuova passata ricattura il clock solo all’inizio, non mentre aspetta o passa da ongoing a next. Test su Rome midnight, DST e finestra next continuano a usare la policy/repository; nessuna classificazione correttiva nella View.

### D4 — Post: detail, Weather, Nearby

Mantenere tre O, chiavi `(id,type)`, validazione e bootstrap in core_routes con `run(id)` della sola lane selezionata. Admission prima di restituire il Provider; query differita. Route unchanged non reseed/refetch; route identity diversa sostituisce owner, dunque non serve un’altra lane R. I due detail action mantengono commit ordinario guarded prima/dopo await, prima di notify. Nessun consumer reale retargetta entrambe le lane sullo stesso owner: non introdurre una nuova API generalized content selection per prevenire quel caso teorico.

PostScreen osserva i results della lane selezionata, cattura uno snapshot per decisione; neutral/running → loader; completed → solo allora legge content e rende sezioni; hasFailure → EmptyView.error con testo generico esistente, senza leggere content e senza nuova route/snackbar o pulsante retry. Questa è la correzione intenzionale del loading infinito. Nessun dettaglio stack nella UI; outcome resta accessibile nel Command. Un nuovo tentativo accettato via VM/nuovo owner può recuperare; non si aggiunge una UX retry assente oggi.

Binding Weather: staccare listener results vecchio e cancellare target al cambio Post owner/type/Weather owner; bind soltanto dopo Success reale della lane corrente, con id/type/coordinate del content assegnato prima del terminale. Pending/failure/owner replacement → null target. In init leggere snapshot già terminale se l’owner arriva completato. Stesso owner/target su rebuild non produce refetch; nuova istanza Weather riceve il target attuale. Non migrare Weather command o spostare weather I/O nel Post VM.

Nearby: mantenere `_nearContent.clear()` all’ingresso accettato, events→places, append di lati riusciti e precedence del primo Result.error. Restituire Result<void> originale coerente, nessun payload aggiuntivo richiesto: la MODIFIED ordinary di OpenSpec 1 permette continuazioni progressive vive e risolve la tensione con la canonical ancora non consolidata. Guard dopo events evita places dopo dispose; guard dopo places evita append/notify; dopo un runtime throw non continuare il secondo lato, il failure resta unexpected. Nessuna rollback della lista o nuova cache di risultati. Retry programmatico rimane ammesso a lane libera e riparte con clear; la UI Post mantiene onRetry null.

Consumer Nearby osserva `loadNearContent.results`, proietta pending da idle/isRunning e error da domainError ?? unexpectedError. Conservare items solo quando completed: i dati parziali restano leggibili nel VM ma la proiezione Post oggi li nasconde in aggregate failure; **non** cambiare la shared presentation per mostrarli. Mantiene loadKey `(owner,remoteId,type,coordinates)`, guard ownsContent e coordinates.isValid, scheduling post-frame del componente condiviso senza riscriverlo. Un callback vecchio non legge widget dopo unmount per verificare ownership: mounted prima, poi owner/content corrente; mai query dopo dispose o passaggio al nuovo detail. Nessun edit a NearbyContentHorizontalList necessario salvo contraddizione dimostrata e review del piano.

### D5 — Lifecycle comune, locale e già approvato

Applicare esattamente il pattern ordinary già implementato in Explore/Theme e Category.setSort: `_disposed` idempotente immediato; staccare commit/public forwarder/router-owned observation; super.dispose VM fuori dispatch via microtask. Guard action entry, dopo await, dopo ogni notify rientrante e prima di qualsiasi mutazione/notifica/fase owner-controlled. Se disposed prima entry, nessun I/O e Result.error locale di owner unavailable, senza presentazione. Se I/O avviato, conservare outcome originale senza commit; Post non avvia places, Event non avvia lato/passata successiva. SyncUseCase già invocato è un’unica fase posseduta dal dominio: nessuna cancellazione delle sue fasi interne.

Per ogni O trattenere Command attivo privatamente; dopo owner revoke resta soltanto listener privato isRunningSync per cleanup. Never-run/idle richiedono comunque cleanup differito. Coalescere controllo in microtask→event callback, invalidare barriera su ogni nuova transizione sync; al callback ricontrollare non-running/released/barriera valida. Se ancora running attendere prossimo false senza polling; se barriera invalidata rinnovarla per quella transizione. Rimuovere listener e marcare released **prima** dell’unico command.dispose. Non disporre nelle results/value/VM dispatch, nel finally action o in seguito al solo Future runAsync. Il timer upstream 50ms è teardown, non settlement; non copiarlo nel codice owner. R riusa il proprio cleanup child, detach observer VM prima di dispose wrapper, senza tracker parallelo.

Questa policy mantiene late StateError/TypeError originale al global handler dopo owner dispose una volta, senza disposed-notifier secondario. Assertion mantiene rethrow policy e cleanup privato su sync false, senza terminale UI inventato. Future non terminante può trattenere command/closure privata indefinitamente: limite noto deliberato. Niente nuovo helper generalizzato, gerarchia, reference counting, timeout, logging globale o nuovi package. Test support può parameterizzare le nuove lane dove il contratto è realmente comune, senza otto copie o wrapper generalizzato di produzione.

### D6 — Sync: admission, outcome e refresh routing

Creare `ResultCommand<bool,void>` e installare classificazione results prima dell’autoload. Se `_useCase.isSyncRequired`, `sync.run(false)` nel costruttore: isRunningSync già true prima del primo frame, sebbene l’action non abbia ancora chiamato UseCase. `_sync(force)` controlla disposed all’ingresso, poi force||due nel momento in cui entra; true forza, false non-due ritorna Success senza UseCase. Duplicate run è drop, mai queue/coalesce/latest-intent. Un accepted usecase.sync è indivisibile per il VM e prosegue privatamente se owner revocato.

**Disponibilità e errore sono assi diversi.** Observer results del VM aggiorna fatalError sincronicamente per la corrente esecuzione: loading/neutral/Success → false; terminale domainError **o** unexpectedError → `lastSyncedAt == null`. Nessuna conversione raw Object→Result.error e nessun report nel VM; assertion non attraversa questo terminale normale. Il testo fatal per runtime deve essere generico di impossibilità di aggiornamento, senza affermare che uno StateError sia sicuramente un problema di rete; riusare layout/retry esistenti. Questo corregge intenzionalmente fatal sticky e il crash senza cache che legacy non classificava. Non diagnostica presenza fisica di dati: mantiene `lastSyncedAt` come proxy esistente. In particolare errore Settings dopo primo commit può lasciare dati pur senza timestamp; rimane conservativamente fatal. Correggere tale criterio o esporre cache health richiederebbe un altro contratto dominio ed è fuori scope.

Precisazione verificata durante apply: il confine conserva l’oggetto e lo stack ricevuti da SyncUseCase, senza conversioni o unwrapping nel VM. Il `.wait` della tupla delle quattro prepare nel UseCase esistente può produrre ParallelWaitError per un throw asincrono di una prepare; la causa originale resta nell’AsyncError del relativo slot. Quel wrapper è l’errore runtime effettivo del confine e viene riportato una volta. Cursor/commit throw diretti possono invece giungere come StateError/TypeError originali. I test distinguono entrambi i percorsi; non si modifica il protocollo dominio o la policy assertion del Command.

Router: sostituire nella merge il legacy Command value con `sync.results` **e** `sync.isRunning` differito; mantenere adminAuthViewModel. `_redirectForSync` legge sempre `sync.isRunningSync.value` per admission e `sync.results.value.hasFailure` per terminale; non usa upstream isSuccess, value o il solo isRunning differito. La prima notifica terminale results può avvenire mentre sync true, quindi non basta da sola: isRunning differito garantisce un successivo refresh quando sync false. La classificazione fatal VM installata prima di router/Screen è aggiornata prima del wake terminale; il refresh differito legge comunque lo snapshot corrente. Nessun listener UI sul sync notifier o nuovo loading flag. Testare che il redirect non parta in anticipo né rimanga bloccato dopo success o failure.

Semantica URI invariata: running fuori sync→RoutePaths.syncFor(state.uri); running già su sync rimane, conservando from senza sovrascriverlo. Non-running fatal failure su sync rimane per retry; tutti gli altri stati non-running su sync, incluso neutral di restoration, passano da `_validatedFrom` e fallback Home. URI completa conservata, query id/type/q/categoria, admin auth guard e branch ancestry invariati. Nessun side effect nel redirect.

**F2 — Feedback corrente prima del normale return.** Il test reale `test/routing/sync_redirect_test.dart:146–175` richiede ritorno Home **e snackbar visibile dopo il ritorno**. Il precedente piano che sopprimeva ogni callback dopo unmount contraddiceva questo gate ed è sostituito dalla decisione seguente. SyncScreen resta proprietario del feedback; router e VM non mostrano snackbar né coordinano notifiche.

Il listener SyncScreen su `sync.results` vede il terminale ordinary sincronicamente mentre isRunningSync può essere ancora true. Distingue `snapshot.isRunning` dal fatto che il runtime stia ancora ultimando il settlement. Verifica prima State mounted, poi route Sync ancora corrente (`ModalRoute.of(context)?.isCurrent == true`), owner ancora fornito dal Provider, snapshot identico a `owner.sync.results.value`, hasFailure e !fatalError già classificato dal VM. **Non richiede !isRunningSync per autorizzare un terminale corrente:** quel controllo perderebbe la finestra prima del return. Non aspettare `sync.isRunning` differito o un post-frame per il percorso normale.

Quando il listener riceve il terminale normale dell’action async (entry già differita da command_it), la continuazione avviene fuori dalla costruzione sincrona del frame. Segnare la coppia owner/snapshot come autorizzata **prima** della chiamata, poi invocare immediatamente `showSnackBar(context: context, ...)` con il testo di aggiornamento esistente. È consegna all’infrastruttura globale nello stesso stack, non soltanto permesso per una closure successiva. Soltanto dopo proseguono il reporting runtime originale e il false sync/finally upstream; il wake router differito può rimuovere SyncScreen e restituire from. L’ordine relativo fra i listener results router/Screen non importa: finché sync true il redirect resta su /sync. Non modificare il redirect per ritardare artificialmente il return.

**Compatibilità verificata snackbar:** `lib/ui/core/ui/custom_snack_bar.dart:60–99` usa `$scaffoldMessengerKey.currentState`, ma `_buildSnackBar` legge subito `context.appColors` e `context.appShapes` (:122–140 e shape finale); i rami logging leggono `context.read<Logger?>()`. Il Builder del contenuto legge poi Theme/MediaQuery/Localizations dal **proprio** context del messenger, non dallo State smontato. `lib/main.dart:197` e `test/support/sync_harness.dart:146,267` installano lo stesso messenger globale. Quindi la chiamata deve avvenire con context valido; una volta costruito/accodato lo snackbar nel messenger globale, il normale smontaggio della route Sync non deve rimuoverlo o cancellarlo retroattivamente. Nessuna closure cattura context/widget/Provider da usare dopo dispose, nessuna modifica al helper globale o nuovo servizio richiesto.

**Percorsi differiti e obsolescenza:** Flutter `ScaffoldMessengerState.showSnackBar` (`scaffold.dart:314–380`) aggiorna stato e vieta chiamate durante build. La riconciliazione di un owner già terminale ricevuto in didChangeDependencies, o una consegna durante `SchedulerPhase.persistentCallbacks`, deve quindi registrare una sola callback post-frame **ancora non autorizzata**. Non chiamare showSnackBar da build/didChangeDependencies né catturare un context da usare dopo unmount. Al callback: prima mounted, poi route Sync ancora corrente, owner di binding e `context.read<SyncViewModel>()` identici al catturato, snapshot terminale ancora identico, !fatalError e nessuna nuova admission (`!isRunningSync` in questo percorso di riconciliazione, non nel listener terminale normale). Se validi, segnare autorizzato e chiamare l’helper con context corrente; altrimenti scartare senza effetto. Questo percorso non sostituisce la consegna immediata del terminale corrente: il normale return non deve dipendere dalla sopravvivenza di un post-frame callback. Il rebind a B già terminale riconcilia subito la UI e, se il consumer rimane vivo, al più una consegna differita del failure nonfatal di B; non invoca sync per ottenere una notifica.

Una nuova loading publication di un tentativo accettato invalida il pending snapshot; una richiesta rifiutata busy non cambia snapshot e non rinnova dedup. Staccare un owner o smontare lo State invalida ogni callback non ancora autorizzata. Unmount estraneo prima dell’autorizzazione → zero feedback/azioni; unmount per normale return **dopo consegna globale** → feedback preservato. Non chiamare clearAppSnackBars nel dispose/rebind e non tentare di ritirare un messaggio già consegnato; non rappresentarlo come una nuova azione dello State dopo dispose.

**Dedup F2:** usare identità della coppia owner/snapshot terminale, con un riferimento al pending snapshot e all’ultimo autorizzato dell’owner osservato, marcato prima della consegna per resistere a rientranza. Non equality della Exception né `CommandResult ==` come chiave di tentativo. Ogni nuovo tentativo produce un loading e un nuovo terminale: due failure osservati con la stessa Exception producono due feedback, ciascuno una volta; un rebuild/notify ripetuto dello stesso snapshot non ne produce altri. Le osservazioni già autorizzate non vengono azzerate su un didChangeDependencies innocuo. Il contratto riguarda il consumer corrente della route, senza replay storico globale né nuovi controller. Fatal failure non entra nel percorso snackbar nonfatal.

**F3 — Dipendenza Provider e ownership dello State.** L’attuale `late final owner = context.read` in initState non è reattivo; il Consumer annidato aggiorna il body ma non il listener posseduto dallo State. In didChangeDependencies usare vincolantemente `final currentOwner = Provider.of<SyncViewModel>(context);` con listen=true implicito. Provider **6.1.5+1** risolto (`provider.dart:296–335`) registra dependOnInheritedWidgetOfExactType e quindi attiva didChangeDependencies anche quando il valore Provider cambia preservando lo stesso State. Una read non-listening in questo metodo non è una soluzione. L’eventuale `context.read` nel controllo puntuale di un callback serve soltanto a verificare identità, non a stabilire il rebind.

Su owner identico: nessun detach/attach, nessun reset della dedup, nessun nuovo feedback/schedule per il solo rebuild. Su owner diverso: (1) detach listener results/running da A; (2) invalidare callback non autorizzati di A; (3) assegnare il campo State mutabile a B; (4) attach una sola volta i listener B; (5) riconciliare snapshot B già disponibile, usando proiezione current e percorso build-safe sopra senza mutare B; (6) lasciare il rebuild di dipendenza aggiornare la UI; (7) in dispose detach dall’owner effettivamente attaccato e invalidare pending prima di super.dispose. Non resettare dedup semplicemente a ogni notify Provider. Callback A verifica anche Provider corrente, così viene scartata anche se la sostituzione è già avvenuta ma il rebind State non è stato ancora consegnato. La proiezione resta admission sync→spinner, fatal hasFailure→error/retry, altrimenti EmptyBox durante uscita. Scope Provider/DI invariato.

**F6 — Due ownership distinte, nessun rebind implicito del router.** Verifica baseline: `_MoliseIsAppState.didChangeDependencies` in `lib/main.dart:174–181` crea `_router ??= buildAppRouter(syncViewModel: context.read<SyncViewModel>(), ...)` una sola volta per State; i rebuild Theme riusano il router e dispose lo rilascia. In `lib/routing/router.dart:58–95`, refreshListenable e closure redirect mantengono l’argomento syncViewModel passato alla costruzione. Il Provider.of reattivo di SyncScreen aggiorna **soltanto** l’owner dei listener/body/feedback di quel consumer, non l’argomento già catturato dal router.

Il contratto F3.1–F3.5 è locale: sullo stesso State schermata A→B deve staccare A, invalidare pending non autorizzato, osservare/rendere B già terminale senza avviare sync e staccare B a dispose. Non prova redirect guidato da B quando il router esistente conserva A. Non costruire una regressione end-to-end con Provider B/router A pretendendo che questo scenario artificiale sia supportato.

Nel normale lifecycle produttivo l’owner Sync è app-scoped (`config/dependencies.dart:211–225`): il router riceve esattamente lo stesso oggetto che il Provider espone a SyncScreen. Bootstrap, redirect, fatal/retry/completion e feedback di quel percorso fanno riferimento a quell’owner. Per una nuova sessione/restoration con owner B, il lifecycle completo app/router deve essere coerentemente ricreato con B; non basta sostituire un Provider mantenendo `_MoliseIsAppState` e `_router` vecchi. Questo piano non introduce un meccanismo di sostituzione dinamica dell’owner nel router né modifica MoliseIsApp/buildAppRouter per supportarlo. Rimane in scope soltanto l’adattamento dei listenable/snapshot del router allo stesso owner già passato (D6 sopra).

Evidenza harness: `test/support/sync_harness.dart:126–151,167–230` passa harness.viewModel sia a buildAppRouter sia al Provider; `buildRealSyncApp` usa MoliseIsApp per provare il lifecycle root reale. `SyncRestorationFixture:234–276` costruisce un router nuovo con il proprio harness/owner nuovo e fornisce gli stessi Provider. Riutilizzare questi entrypoint e `sync_redirect_test.dart` (bootstrap, fatal/retry, preserved URI, restoration e test Theme-router identity), senza shadow router o nuova DI.

### D7 — Alternative e tradeoff

| Alternativa | Decisione motivata |
| --- | --- |
| execute→run meccanico | Scartata: run void/action differita, UI e waiter legacy incompatibili; dettaglio failure e sync refresh rimangono sbagliati. |
| Restartable per tutti gli otto | Scartata: Sync persiste, Nearby/annuale e due lati Home richiedono single-flight; Post ha owner route già sufficiente. |
| Day single-flight con drop | Scartata: B non selezionato e rapid A→B→A perde intent. |
| Day single-flight + latest desired + rilancio | Possibile ma scartata: duplica scheduling/authority, attende vecchio lavoro e richiede più coordinamento della R esistente. |
| Day generation counter oltre R | Scartata: duplicazione; basta l’identità della request effettivamente ammessa per associare results alla selezione, mentre yearlyRevision invalida dataset cross-lane. |
| Annual rebase via nuova query automatica | Scartata: query extra/retry implicito; risolvere dal dataset appena caricato, anche empty noncacheable, basta e termina loading. |
| runAsync coordinator e catch Object→Result | Scartata: join non prova propria admission e fabbrica domain failure dai crash; waiter sync locale conserva failure indipendenti. |
| Unificare detail Post event/place in una nuova R | Scartata: nessun retarget stesso owner reale, chiavi route già isolano; maggiore scope e nuovi payload senza bisogno. |
| Nuovo Nearby outcome per includere partial in Error | Scartata: ordinary allowance di OpenSpec 1 già consente partial nel VM; UI corrente non mostra partial su failure. |
| Aggiungere retry button Post/Nearby o not-found redirect | Scartata: cambia UX/navigazione oltre alla correzione richiesta del terminale detail. |
| Feedback sempre post-frame e cancellato a ogni unmount | Scartata F2: perde lo snackbar sul normale return; consegna immediata con context vivo nella finestra terminale, messenger globale conserva il messaggio. Soltanto il pending non autorizzato è revocabile. |
| Rebind con context.read in didChangeDependencies | Scartata F3: non stabilisce dipendenza e può lasciare listener A; Provider.of listening + controllo identità garantisce rebind senza duplicare osservatori. |
| Cache hit risolta ricostruendo da _all | Scartata F5: perde fallback X o cambia uno stato terminale valido. Il ramo hit ritorna prima di qualsiasi mutazione; la derivazione annuale appartiene solo a miss o nuovo rebase. |
| Provider B implica router B sul router esistente | Scartata F6: router cattura A alla costruzione; rebind Screen è locale. Nuovo owner applicativo richiede lifecycle app/router coerente, senza nuova infrastruttura qui. |
| UI day basata sul solo completed o isRunning differito | Scartata F1: skeleton infinito su failure o grid A sotto B; usare admission sync, request corrente e matrice terminale/retry. |
| Router osserva solo results o Command.value | Scartata: terminale results precede false sync; value può non notificare runtime error. results+isRunning differito coprono entrambi. |
| Runtime Sync sempre nonfatal o convertito in domain | Scartata: senza timestamp abbandonerebbe bootstrap fallito o perderebbe natura del crash. Availability gate e unexpected outcome restano separati. |
| Interrompere SyncUseCase al dispose | Scartata: può violare atomicità/cursor/save; il VM revoca solo presentazione e nuove invocazioni. |
| Helper lifecycle globalizzato per queste lane | Scartata: user richiede riuso dei pattern esistenti, non ulteriore foundation; local cleanup verificabile sufficiente. |

### D8 — Coerenza delta e consolidamento futuro

Nuovi requisiti ADDED con nomi distinti nella capability command-execution-concurrency e Home. Non riscrivere ancora `Only authoritative completion can commit asynchronous data`: la MODIFIED OpenSpec 1 resta l’unica definizione cumulativa da consolidare. Event day rispetta retrieval puro/commit autoritativo; ordinary rispettano la deroga feature-owned approvata, incluso Nearby partial. Search/Map/Category non cambiano. Le canonical temporali, routing/shell e local retrieval restano vincolanti, senza delta perché non cambia la loro policy. Nessun sync/archive in questa fase. Integrazione cumulativa futura resta nella PR #12 con checkpoint indipendente per change; questo piano non autorizza commit/push/merge o update PR.

## Regression plan

Tutti i casi seguenti sono **gate futuri**, non test appena eseguiti. Completer controllati, FakeRepository e clock iniettati; testWidgets/fake clock per timer/dispatch e reporting reale. Nessun sleep reale, polling o aspettativa su conteggio di microtask. I test osservano esecuzioni, stato selezionato, contenuto, feedback, URI e release; `pumpCommandTurns` è supporto per guidare runtime, non un contratto prodotto.

### Supporti e suite da riutilizzare

- `test/support/{fake_repositories,fixtures,command_test_support,events_harness,sync_harness,ordinary_view_model_lifecycle_support,sync_use_case_test_support}.dart`; pending handlers e recorder già presenti. Esaminare i membri effettivi prima di estendere, nessuna duplicazione locale di fake/store/router.
- `test/ui/event/view_models/event_view_model_test.dart`: annual/day/revision, order e retention Home, midnight, pending batch, manual lane waiter e dispose. `test/ui/event/widgets/components/events_calendar_test.dart` (helper legacy a :234), test modal/screen pertinenti; `test/routing/{events_route_test,home_event_discovery_test}.dart` per owner e reload reale.
- `test/ui/post/view_models/post_view_model_test.dart`: success/error dei due detail, dispose fra Nearby fasi, ordine e partial/error precedence. `test/ui/post/widgets/post_screen_test.dart`: Weather owner replacement/pending, invalid coords, no-retry Nearby, stale callback.
- `test/ui/sync/{view_models/sync_view_model_test,widgets/sync_screen_test}.dart`; `test/routing/sync_redirect_test.dart` per bootstrap/force/menu/pull, query retention, invalid from/admin/home reload. `test/domain/use_cases/sync_use_case_test.dart` caratterizza protocollo invariato (nessun nuovo mock del protocollo nel VM).
- `test/ui/ordinary_view_model_lifecycle_test.dart`, fixture/probe FlutterMemoryAllocations per identity disposal, reporting install/restoration; foundation utils citati A1. `test/routing/{route_ownership_test,main_navigation_restoration_test,back_navigation_integration_test}.dart` e test shell per NAV-07, branch retention, predictive back e restore.
- Prima di edit test caricare dart-add-unit-test, test-support-reuse e widget/integration skill applicabile; prima di edit State/callback caricare async-mounted-context-safety. Planning non modifica questi file né richiede nuovi helper produttivi.

### Matrice dei test discriminanti

| ID | Caso deterministico e osservabile |
| --- | --- |
| C1 | Su ciascuna lane O reale: never-run neutro, run ammette inline e I/O zero prima entry; running, Success<void>(null), domainError originale, StateError/TypeError unexpected con stack/report una volta; nessuna equivalenza value/completed. |
| C2 | Due run pending sulla stessa lane O: una action, parametro iniziale rispettato, nessuna queue; re-admission dopo terminale; test foundation runAsync join riusato, nessun waiter scambiato per proprio successo. Lane indipendenti non si escludono accidentalmente. |
| E1 | Autoload annuale una volta per owner, success/error/retry, success empty, duplicate pending drop; retenzione all/revision su failure; calendario marker ordinato e Rome day corretto. |
| E2 | selectDate cambia selezione prima pump, cache hit senza query; A avviato→B avviato→A avviato, completare vecchio A per primo/ultimo e B dopo ultimo A: solo finale A committa/outcome; variant stesso turno può non avviare intent superseded. Mai asserire che ogni intento scartato prima entry debba fare I/O. |
| E3 | Annual/day entrambi pending in ciascun ordine; annuale cambia revisione e rebase candidato nonempty/empty; vecchio fallback non sovrascrive né rimane loading, zero query aggiuntiva dal rebase; stessa selezione dopo annual empty effettua fallback esplicito; Home annuale da solo non avvia giorno. |
| E4 | Fallback Success empty cacheabile, repeat no query; Result.error/handled runtime non cacheabile, tap uguale ritenta; cambia giorno non mostra vecchio giorno; anno fallito non invalida cache buona. |
| E5 | Day stale Result.error ignora UI, stale runtime una volta report; dispose prima entry/durante query/da notify non committa né notifica. Selezione rientrante B da notifica A mantiene B autoritativo. |
| E6 | Shared Future identico per richieste concorrenti, una passata aggiuntiva per batch; clock recorder una sola lettura per passata e nuovo istante soltanto dopo lane esterne libere; due query ricevono stesso snapshot anche attraversando Rome midnight/DST. |
| E7 | ongoing domain/runtime error non salta next; errori nei due versi e insieme, retention indipendente e empty clears; manual ongoing/next pendenti prima passata e next occupata dopo snapshot attendono senza perdere query né ricatturare clock. |
| E8 | Dispose durante manual-wait, ongoing o next, pending coalesced: refresh Future rilasciato senza completion fisica, no passata/lato successivo, listener temporanei rimossi; late Result/throw si regolano privatamente. Riutilizzare test Home ritorni da tab/detail/search/category/settings e no reload da popup/rebuild. |
| P1 | Event/Place route valida ammette solo lookup selezionato prima frame, I/O differito; rebuild stesso owner non refetch; invalid id/type/categoria ereditata non crea query. content mai letto prima completed. |
| P2 | Detail Result.error e runtime error → error surface, niente spinner persistente/Weather/Nearby query, report solo runtime; nuovo tentativo accettato success → content e target correnti una volta; nessun retry UI aggiunto. |
| P3 | Owner A pending→B event/place, includere stesso id/type diverso; A late success/domain/runtime non contamina B. Weather owner diverso per stesso content riceve target una volta; pending/failure clearing, stale source listener detach. NAV-07/predictive back/restoration reali conservati. |
| P4 | Nearby events→places success, events failure+places success, events success+places failure, entrambi failure (primo Object Exception originale); partial lista VM e proiezione UI/no Riprova preservati. Retry programmatico clear/reload ammesso a fine lane. |
| P5 | Coordinate invalide zero query; loadKey uguale rebuild zero query; owner/content/coordinate cambia prima post-frame callback solo target attuale; captured old onLoad non invoca vecchio owner. Shared widget suite invariata. |
| P6 | Dispose durante events vieta places; durante places vieta commit/notify; runtime events non inizia places, runtime places mantiene natura unexpected; partial già pubblicato non viene impropriamente trasferito a nuovo owner. |
| S1 | Costruttore due ammette sync prima primo frame e prima usecase entry; non-due rimane neutral; force true invoca, false non-due skip, false due invoca, schedule cambia prima entry è ricontrollato. |
| S2 | Force true/false concorrenti durante admission e I/O: una sola sync senza passata pending; risultato/fatal dell’esecuzione ammessa, nessun feedback dal rifiuto. |
| S3 | Nessun timestamp: domain e runtime terminale restano su /sync con retry; timestamp presente: entrambi nonfatal ritornano; fatal→retry loading→Success/reset→destinazione. Same Exception su due tentativi non rompe dedup. |
| S4 | Probe ordine terminale results mentre sync true, poi refresh differito con sync false: nessun ritorno prematuro e nessun blocco; primo router frame auto-sync corretto, nessun listener UI sync. |
| S5 | sync_redirect_test esteso: /sync?from URI detail/search completa, forced menu/pull, malformed/external/network/recursive/unmatched from→Home, restored idle /sync, admin return guard; shell/back/restoration regressioni verdi. |
| S6 | Applicare integralmente F2.1–F2.8 e F3.1–F3.5 sotto: consegna corrente prima return e visibilità dopo, pending obsoleto revocato, identity dedup e Provider realmente reattivo. Il normale unmount dopo consegna non revoca il feedback globale. |
| S7 | Dispose prima entry zero UseCase; durante UseCase late Success/Result.error non cambia fatal/notify o route del vecchio owner; raw late throw riportato once anche oltre 50ms virtuali, nessun errore secondario. Protocollo domain già avviato completa senza interventi VM. |
| S8 | SyncUseCase suite esistente verde per cursor prima fetch, prepare paralleli, commit atomico/rollback, settings-after-commit, overlap/replay; nessun test VM riduce le garanzie a quattro write imitate o cancella fasi dopo dispose. |
| L1 | Tutte le sette O e R: dispose before entry/during action/before terminal, success/domain/StateError/TypeError, dup dispose; nessun commit/notify/fase nuova, late error originale e stack global una volta, expected zero global; R stale runtime continua reporting. |
| L2 | Dispose da results terminale, value listener già idle, VM.notify, never-run, completed; settlement e disposal nello stesso turno in entrambi gli ordini e nuova transizione durante barriera già accodata; probe release identità exactly-once dopo settlement, niente release durante dispatch/pending. |
| L3 | Assertion upstream originale fail-loud e cleanup, senza abbassare assertionsAlwaysThrow; pending Future non terminante perde autorità senza timeout/polling. Statics e handler sempre ripristinati; nessun nuovo skip. |

### Gate aggiuntivi della remediation F1/F2/F3/F5/F6

Questi casi sono futuri test con foundation reale, Completer controllati e clock virtuale, senza sleep o conteggi microtask. Riutilizzare suite/supporti sopra: EventsModal/EventsCalendar reali e vero SyncScreen StatefulWidget; non basta un test isolato del VM. Mantenere invariata l’asserzione snackbar dopo return nel test sync_redirect_test.dart citato D6.

| Gate | Verifica discriminante futura |
| --- | --- |
| F1.1 | A completed→select B: prima action entry B, selectedDate B, calendario evidenzia B tramite propria osservazione VM, titolo B/modal pending e nessuna grid A. Pompare i consumer direttamente senza Consumer parent come fonte accidentale di rebuild. |
| F1.2 | B Result.error: skeleton rimosso, EmptyView.error/Riprova, Exception originale domainError, zero global report e nessun vecchio dato come corrente. |
| F1.3 | B StateError/TypeError: stessa error surface, unexpectedError e Object/stack global una volta, nessuna conversione a Result.error o skeleton persistente. |
| F1.4 | Retry dopo failure B legge selectedDate corrente; provocare cambio selezione prima di un callback errore trattenuto e assicurare che non ripristini B vecchio. Nuovo intent della data corrente, una query se necessaria, pending poi success-empty/items, zero annual reload o owner recreation. |
| F1.5 | A→B→A con A iniziale già completato e con vecchie query pendenti; completamenti in ordini inversi. Durante ogni admission nessun terminale obsoleto visibile; solo ultima request A può committare/proiettare anche a parametri uguali. |
| F1.6 | Annual rebase nonempty/empty revoca fallback pending e termina rispettivamente grid/empty dal nuovo dataset senza attendere vecchio Future e senza query extra. |
| F1.7 | Modal/owner disposed prima entry/durante query/prima terminale: late success/domain/runtime non aggiorna widget o VM, reporting originale once e nessun notifier post-dispose. |
| F2.1 | Conservare test nonfatal→URI originale (Home e dettaglio) con snackbar **effettivamente visibile dopo return**, una sola consegna. Vietato eliminare quell’asserzione per ottenere verde. |
| F2.2 | Runtime nonfatal: stessa navigazione/snackbar dopo return, Object/stack global once e unexpectedError distinto. |
| F2.3 | Due tentativi ammessi e osservati dallo Screen corrente falliscono con medesima Exception; riaprire sync per il secondo quando necessario: una consegna per tentativo, dedup per snapshot identity e nessuna nuova esecuzione da richiesta busy. |
| F2.4 | Rebuild innocui/notify ripetute/same-owner didChangeDependencies non duplicano listener, pending o snackbar. |
| F2.5 | Dove esiste pending build-safe non autorizzato (owner già terminale riconciliato), ammettere retry prima del post-frame: vecchio feedback zero, nuovo terminale ancora notificabile. Il terminale normale ha invece consegna immediata, senza dipendere da quel callback. |
| F2.6 | A→B con pending A non autorizzato: callback A scartato anche prima del didChangeDependencies tardivo; B può notificare il proprio esito, nessuna lettura context A dopo unmount. |
| F2.7 | Navigazione/unmount estraneo prima dell’autorizzazione: zero nuove azioni/letture State.context/widget/Provider dal callback vecchio; normale return dopo autorizzazione conserva invece lo snackbar già nel messenger. |
| F2.8 | Fatal domain/runtime: resta /sync con error view/Riprova, zero snackbar nonfatal. |
| F3.1 | Gate locale schermata, senza claim sul router (F6.1): montare SyncScreen con Provider.value A e sostituire B preservando **stessa identità State**: listen dependency causa detach A/attach B e notifiche tardive A ignorate. |
| F3.2 | B già terminale success/fatal/nonfatal: body proiettato correttamente senza run B; eventuale riconciliazione feedback nonfatal build-safe al più una volta se ancora corrente/mounted. |
| F3.3 | Rebuild e cambi dipendenze innocui con stesso owner: nessun reset attempt dedup, doppio attach o nuovo feedback. |
| F3.4 | Provider A→B prima del callback A pending: nessun feedback A; snapshot corrente B è l’unica autorità di presentazione. |
| F3.5 | Unmount vero State: tutti i suoi listener staccati dall’ultimo owner, callback pending invalidati; risultati tardivi nessun effetto, senza rimuovere feedback già consegnato per normale return. |

### F5 — Test cache: stato, ordine, Future e proiezione

Questi cinque casi estendono i test Event VM/modal esistenti con command reali, Completer distinti per annuale/fallback e clock virtuale. Non basta contare query: osservare contenuti byMonth, marker/selectedDate tramite contratti VM, sequenza results e grid/empty/error del vero modal. Nessuna nuova API test-only richiesta in produzione; i marker possono essere verificati attraverso il comportamento cache/refetch e revisioni attraversate.

| Gate | Setup e ordine controllato | Risultato e notifiche osservabili / discriminante |
| --- | --- | --- |
| F5.1 fallback nonempty | Completare bootstrap annuale con Success([]); selezionare A, trattenere getByDate(A) nel Completer D1, poi rilasciare Success([X]) con X appartenente ad A. Attendere il terminale corrente e rilevare VM/results/UI; selezionare ancora A alla stessa revisione. | Dopo D1 byMonth=[X], terminale completed e grid X; seconda A preserva X, stessa request/snapshot terminale, nessuna nuova query/admission/notifica VM e nessun nuovo pending. Fallisce un’implementazione che conti una sola query ma sovrascriva `_byDate` con [] derivato da `_all`. |
| F5.2 fallback empty | Stesso bootstrap []; A con D1 pending→Success([]); osservare terminale e riselezionare A senza nuovo anno. | Prima skeleton, poi EmptyView corrente e completed; success-empty cacheabile, seconda A resta empty senza refetch/notifiche o nuova sequenza loading. Non è errore né neutral/skeleton. |
| F5.3 rebase annuale | Stabilire F5.1 [X] fallback alla revisione r; avviare loadAll successivo con Completer Y2. Durante Y2 riselezionare A: conserva [X]/cache r. Rilasciare Y2 con Success([Y]) per A, poi variante Success([]); variante separata Y2 Result.error. | Success crea r+1 e sostituisce X con Y/grid oppure []/empty senza fallback aggiuntivo dal rebase; terminale giorno riferito alla request r+1, marker ricostruiti solo se nonempty. Dopo annual empty success un tap A esplicito può interrogare di nuovo; dopo annual nonempty il tap conserva Y senza query. Annual failure mantiene [X] e cache r, no nuova derivazione. Verifica notifica VM su commit/rebase e nessun restore X come se fosse valido per r+1. |
| F5.4 completamento obsoleto | Tenere D_old(A,r) pending; ammettere B e ultimo A con D_new controllato e rilasciare D_new→[X], poi D_old→[OLD]. Variante cross-lane: annuale r+1→[Y] prima di rilasciare D_old; ripetere con vecchio domain error/runtime. | Vecchio completamento non cambia contenuti, marker comportamentali, current request/terminale, selezione o grid/empty/error correnti e non notifica VM dal vecchio commit. Runtime vecchio reporta una volta senza UI stale. La successiva stessa selezione conserva X/Y validi senza usare OLD; A→B→A resta identity-based. |
| F5.5 failure/retry | Annuale []; A con D1→Result.error(E), poi stessa selezione o bottone Riprova corrente avvia D2 controllato. Prima di D2, nessun cache hit derivato dall’errore; rilasciare D2 Success([X]) e variante Success([]). Variante D1 runtime gestito. | Error surface con E originale/nessun report domain; retry nuovo intent, skeleton con query nuova e nessun reload annuale, poi grid X oppure empty terminale. Solo Success di D2 marca cache: ulteriore A non refetch né perde dati. Runtime distinto/report once. Controllare sequenza error→pending→success, non soltanto numero chiamate. |

### F6 — Test ownership: locale ed end-to-end separati

- **F6.1, locale (precisa F3.1–F3.5):** usare il vero SyncScreen e l’harness widget già esistente con Provider A→B, mantenendo stessa identità State; non usare un router che conserva A per affermare proprietà di B. Preparare owner non-due/azioni con Completer controllati, notifiche tardive A e snapshot B già terminale. Verificare detach A/attach B una volta, UI B, zero sync da rebind, pending A invalidato, nessuno snackbar stale/duplicato e detach finale. Uno Scaffold/MaterialApp del test widget è sufficiente; nessuna seconda implementazione delle route. Queste asserzioni non dimostrano rebind di refresh/redirect del router.
- **F6.2, end-to-end coerente:** riusare buildSyncRouterApp/buildRealSyncApp/SyncRestorationFixture e suite sync_redirect_test. Un’unica istanza A deve essere passata sia al router reale sia al Provider: con Future controllate verificare bootstrap→/sync, fatal senza cache→retry, force/schedule/duplicate e completion→from valida, insieme al feedback corrente dopo return. Il test Theme conserva router/owner A sui rebuild innocui. Per restoration/nuova sessione staccare e disporre il vecchio app/router lifecycle, poi creare fixture/router B con Provider B: bootstrap/fatal/retry/return devono essere guidati da B, e terminali tardivi di A non possono muovere la nuova URI o produrre UI/feedback in B. Non mutare MoliseIsApp o implementare router dinamico per ottenere questo gate.

Nuovi test mirati provano differenze osservabili e failure mode, non il numero di timer usati internamente. Il wrapper testOwnerUI si usa soltanto per owner reali che richiedono cleanup virtuale; non convertirne indiscriminatamente tutte le suite.

## Risks / Trade-offs

- [Event snapshot pubblico differito] → barriera isRunningSync + identità della request, matrice terminale e retry F1, VM/results osservati direttamente da modal/calendario; solo la barriera non copre la finestra false-prima-terminale.
- [Cache fallback cancellata da annual-derived empty] → ramo hit prima di ogni mutazione conserva `_byDate` anche con `_all` vuoto; marker invalidati su miss/revisione nuova e commit stale vietati. F5 verifica dati e UI oltre al refetch.
- [Event cache data race] → R risolve A→B→A, revision conserva invalidazione cross-lane; test annuale con rebase empty/nonempty nei due ordini. Il risultato di una query fisica obsoleta non implica rilascio della cache attuale.
- [Coalescing e listener leak] → waiter registrato prima check finale, finish idempotente e revoca; Future pubblico si rilascia anche con lavoro fisico bloccato. Nessuna promessa di starvation-freedom per caller diretti arbitrari.
- [Post late content e falso successo] → success projection soltanto per leggere content e Weather; errore terminale esplicito. Due detail lane restano indipendenti sullo stesso owner, ma il route contract ne usa una: retarget arbitrario cross-lane rimane fuori scope.
- [Nearby partial vs UI] → preservare separatamente dati VM, esito aggregato e proiezione Post. Non sfruttare la capacità partial del widget condiviso per cambiare UX incidentalmente.
- [Feedback Sync perso sul return] → autorizzare/consegnare nel terminale corrente con context vivo prima del false; messenger globale conserva dopo redirect. Pending build-safe revocabile, nessuna chiamata post-unmount. F2.1 esistente resta gate.
- [Confusione owner Screen/router] → F3 è lifecycle locale; F6 separa widget rebind da harness end-to-end con identico owner router/Provider. Nessun supporto implicito Provider B/router A o refactor main.
- [Provider owner non osservato] → Provider.of listening in didChangeDependencies e identity attach/detach; Consumer body/read da soli non bastano. F3 esercita stesso State.
- [Sync routing ordinato male] → results + isRunning differito come wake, isRunningSync come fatto di admission, fatal classificato prima dei consumer. Coprire startup senza pump e terminale prima false.
- [Sync runtime senza cache] → availability fatal non normalizza errore; testo generico e retry conservano recuperabilità, global reporting una volta. Timestamp è proxy conservativa, non certificazione cache fisica.
- [Sync disposal e persistenza] → nessuna nuova invocazione dopo revoke, ma UseCase già avviato completa proprio protocollo; VM non garantisce cancellation/rollback remoto.
- [command_it 9.5.2 late throw] → niente disposal precoce; CL e wrapper mantengono private settlement. Future infinito può conservare risorse, limite già approvato.
- [Piani cumulativi non consolidati] → leggere delta OpenSpec 1/2 insieme alla canonical; nessun merge concorrente o riscrittura di requirement. La validazione strict non prova correttezza del design né approva apply.

## Migration Plan

Futuro apply soltanto dopo review indipendente e nuova autorizzazione. Operare esclusivamente dal worktree persistente B0.1 sul branch dedicato; ripetere preflight e confronto baseline, poi caratterizzare test discriminanti, implementare una superficie alla volta secondo tasks.md e validare gate aggregati. Nessuna migrazione dati, deploy o backend. Rollback locale di un futuro apply avviene soltanto sul suo diff coeso e con preservazione di lavoro altrui; non usare reset distruttivi. La PR cumulativa non viene aggiornata da questo planning.

### Criteri misurabili di completamento del futuro apply

1. Otto proprietà migrate: sette O e una R; zero import/tipo/execute legacy sulle tre VM e consumer/test pertinenti; nessuna modifica ad altri Command, foundation, policy/query/persistenza o dipendenze.
2. Tutti i casi C/E/P/S/L e F1.1–F1.7/F2.1–F2.8/F3.1–F3.5/F5.1–F5.5/F6.1–F6.2 applicabili dimostrati con test deterministici e Command reali; nessun nuovo skip o test indebolito; protocollo UseCase e presentation Nearby invariati.
3. Analyzer equivalemente ripetuto: esattamente 18 identità rimosse, 87 INFO residue con identità/molteplicità uguali, zero warning/errori e nuove diagnostiche, log/exits/versioni registrati.
4. Test mirati e suite **Flutter completa** realmente verdi (`flutter test --no-pub`, con soli skip preesistenti identificati), poi strict OpenSpec e controlli diff/whitespace anche untracked. Successi storici 2.480 test di OpenSpec 2 non sostituiscono questo gate.
5. Artifact riconciliati con evidenze reali e review adversariale indipendente dell’implementazione; nessuna integration-readiness dal solo schema valido. Nessun commit/push/merge/archivio implicito.

### Stato del planning

Proposta, design, task e due delta sono il risultato documentale, con task futuri tutti unchecked. Nessuna questione materiale lasciata all’executor: annual rebase, runtime Sync, Nearby partial e retry Post sono decisioni esplicite sottoposte a review, non fatti preesistenti. Non è stato eseguito apply né la suite Flutter in questa fase. Le verifiche realmente eseguite e l’integrità finale saranno registrate nel closeout documentale.

### Closeout documentale originale — 2026-10-21 (storico, prima della review F1–F4)

- `openspec status --change migrate-content-view-model-commands --json`: proposal/specs/design/tasks presenti e planning completo. Il campo CLI isComplete riguarda gli artifact, non l’implementazione: tutti i 27 task di apply restano unchecked.
- `openspec validate migrate-content-view-model-commands --strict --no-interactive`: **valid**, exit 0, senza warning. Delta: otto requisiti aggiunti in command-execution-concurrency e due in home-ongoing-events; nessun requisito canonical riscritto.
- `git diff --check` e `git diff --cached --check`: exit 0. Controllo Python degli artifact untracked: newline finale presente e nessun trailing whitespace. `git diff --name-only` e `git diff --cached --name-only` vuoti; esattamente sei file untracked sotto questa change, nessun altro cambiamento nel worktree.
- HEAD ancora e3d9d891, detached; main e tutti gli altri quattro worktree risultano puliti alla verifica finale, senza operazioni di modifica da questa esecuzione. PR soltanto letta, nessun commit/push/merge/update.
- Analyzer read-only documentato B1: 105 INFO e 18 target riconfermate, zero warning/error. Nessuna suite Flutter eseguita o implementazione/test scritta durante questo planning.

**Esito storico READY FOR INDEPENDENT PLAN REVIEW, superato dalla review F1–F4 e dalla remediation seguente:** artifact completi e validi, scelte materiali esplicite e testabili. Nessun blocker di baseline o questione esecutiva lasciata irrisolta; le proposte D2/D6 e i limiti D5 richiedono comunque valutazione adversariale indipendente prima dell’autorizzazione apply. Questo esito non è una review indipendente già superata né una readiness di implementazione o integrazione.


### Remediation F1–F4 — closeout precedente alla review F5/F6

La richiesta di remediation autorizza gli edit documentali e il trasferimento locale, senza apply. Modificati proposal/design/tasks e la sola delta command-execution-concurrency; `.openspec.yaml` e delta home-ongoing-events sono byte-identici al manifest originario, perché F1–F3 non cambiano il contratto Home. Restano otto requisiti nella delta concurrency (due rafforzati senza rinominarli e otto scenari netti aggiunti) e due nella delta Home; nessuna nuova capability o riscrittura della MODIFIED di OpenSpec 1. Restano cinque gruppi e **27 task futuri tutti unchecked**.

| Finding | Risoluzione del piano | Gate e tracciabilità |
| --- | --- | --- |
| F1 MEDIUM | D2 matrice modal completa, barriera sync + request identity, ordine selezione/admission, retry corrente e osservazione diretta del calendario | F1.1–F1.7; delta Calendar selection; task 2.2/2.3/2.6/5.1 |
| F2 MEDIUM | D6 consegna snackbar corrente mentre context è vivo prima del normale return, messenger globale preservato, pending obsoleto revocabile e dedup per tentativo | F2.1–F2.8, asserzione sync_redirect originale preservata; delta Sync return; task 4.3/4.4/5.1 |
| F3 LOW/MEDIUM | D6 Provider.of listening e confronto identità, detach/attach e riconciliazione terminale senza run | F3.1–F3.5 su vero SyncScreen State; delta Sync return; task 4.4/5.1 |
| F4 operativo | Stesso worktree spostato con Git e branch locale dedicato, nessun dato ricreato o pubblicato | B0.1: HEAD/index/manifest e hash 6/6 identici al move; altri worktree preservati |

Riesame adversariale finale read-only del piano e dei sorgenti (anche reviewer separato): nessun finding materiale residuo rilevato su F1–F4, incluse le dodici condizioni della richiesta. Questo è un controllo della remediation; non sostituisce la successiva re-review indipendente dell’utente e non autorizza apply. Le nuove garanzie UI/lifecycle sono da dimostrare con i test futuri, non successi Dart già ottenuti.

Verifiche documentali ripetute dal percorso persistente: `openspec status --change migrate-content-view-model-commands --json` exit 0, planning completo; `openspec validate migrate-content-view-model-commands --strict --no-interactive` exit 0, valid senza warning. YAML parsato validamente con Ruby/Psych (`ruby --disable-gems -ryaml`, exit 0), controlli espliciti Python sui sei file untracked per UTF-8, newline, trailing whitespace, fence/heading/requisiti/scenari e numero task; `git diff --check` e `git diff --cached --check` exit 0. I controlli strutturali Markdown non sono un rendering visivo né provano i futuri comportamenti UI.

Integrità: HEAD e3d9d891 e branch persistente B0.1, zero commit aggiuntivi, tracked diff e index vuoti, esattamente i sei artifact attesi untracked, nessun Dart/test o altro file modificato. Tutti gli altri worktree hanno HEAD/branch/status identici al preflight. PR #12 letta soltanto e invariata aperta/Draft sul checkpoint; nessun commit/push/PR/merge/rebase/archive/sync canonical. Nessun analyzer o test Flutter rieseguito in questa remediation: baseline storica verificata B1 **105 INFO / 18 target**, obiettivo futuro **87 INFO**, zero nuove diagnostiche, suite completa sempre gate di apply.

**READY FOR INDEPENDENT PLAN RE-REVIEW**


### Remediation F5/F6 — stato corrente del piano

Preflight di questa fase: worktree persistente e branch B0.1 confermati su e3d9d891, index/tracked diff vuoti, esattamente sei artifact untracked già revisionati e inventariati con SHA-256 prima degli edit. Il vecchio `/private/tmp/moliseis-openspec3` è assente e non registrato. PR #12 verificata read-only aperta/Draft sulla HEAD autorizzata. Gli altri quattro worktree sono puliti e conservano HEAD/branch/status; nessuna operazione Git mutativa eseguita in questa fase.

**F5 risolto nel piano:** il ramo cache hit è un return prima di qualsiasi mutazione/derivazione, conserva `_byDate` fallback e terminale corrente anche empty; miss e nuova revisione hanno regole di invalidazione esplicite. D2, delta Calendar, task 2.2/2.3/2.6/5.1 e F5.1–F5.5 verificano contenuti, esiti/notifiche e UI. Nessuna cache multi-giorno o nuovo livello di stato.

**F6 risolto nel piano:** D6, delta Sync return e task 4.3/4.4/4.6/5.1 distinguono F3 lifecycle locale dai test router end-to-end F6.2. Il router resta sull’owner passato alla costruzione; una nuova sessione richiede nuovo app/router lifecycle con Provider coerente. Main/router non acquisiscono un’infrastruttura di rebind dinamico.

Modificati soltanto proposal/design/tasks/delta concurrency. Metadata e delta Home restano invariati rispetto al manifest precedente: nessuna nuova capability, otto Command (sette O/una R), cinque gruppi e 27 task tutti unchecked. I verdetti F1–F4 sopra sono storici: questa remediation non attribuisce loro la chiusura anticipata di F5/F6. Nessun apply, Dart/test edit o risultato runtime nuovo.

Verifiche documentali F5/F6 eseguite dal worktree persistente: strict OpenSpec valido exit 0 senza warning; YAML parser Ruby/Psych exit 0; controlli espliciti UTF-8/newline/trailing whitespace su tutti i sei artifact untracked, task 27/27 unchecked in cinque gruppi; git diff --check e git diff --cached --check exit 0. Pre/post SHA-256 acquisiti per tutti i sei file; metadata e delta Home byte-identici. Manifest completo di confronto in `/private/tmp/os3-f56-integrity.json` (evidenza effimera, non prerequisito futuro), oltre al resoconto finale; il manifest viene finalizzato dopo l’ultimo edit per includere anche l’hash finale del design, senza autohash ricorsivo nel documento.

Review adversariale focalizzata read-only, con reviewer separato e riscontro sui sorgenti: nessun finding materiale residuo F5/F6; gate discriminanti e confini di responsabilità coerenti con i primi due OpenSpec. I test proposti sono futuri: nessun flutter test/flutter analyze rieseguito, nessun nuovo claim runtime. Baseline 105 INFO, 18 target e obiettivo 87 INFO invariati. Nessun codice/test/dependency/backend/canonical o altro worktree modificato, index vuoto e nessun commit/push/PR update/merge/archive/sync.

**READY FOR INDEPENDENT PLAN RE-REVIEW** — il piano resta soggetto alla verifica indipendente finale e a un’autorizzazione apply distinta.


## Apply autorizzato — 2026-10-23

Il prompt utente autorizza l’esecuzione completa dei 27 task, senza commit/push/PR update/archive/sync canonical. Le sezioni di planning/remediation precedenti sono storiche; seguono soltanto evidenze realmente eseguite nell’apply. Worktree persistente e branch B0.1, HEAD e3d9d891; index inizialmente vuoto, nessun tracked diff, sei artifact con hash identici al manifest F5/F6 approvato. Inventario degli altri worktree acquisito, tutti puliti. PR #12 aperta/Draft, head codex/migrate-legacy-commands sullo stesso checkpoint. Nessun fetch/checkout o incorporazione di nuovi commit.

### Gruppo 1 — preflight, B1 e caratterizzazione

Nuovo B1 via Dart diretto 3.13.4 su git archive HEAD con package_config temporaneo adattato, cwd worktree persistente, argv `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/os3-apply-evidence/baseline`: exit grezzo 0, 105 INFO, zero WARNING/ERROR e stderr vuoto. Identità target 18 come B1; tutte le 87 non target conservate nel ledger machine baseline.stdout. Flutter `--version --machine` conferma 3.47.5/framework 6a19cca e Dart 3.13.4; command_it 9.5.2/listen_it 6.0.0 invariati. Nessun pub get/upgrade; soltanto metadata ignorati .dart_tool copiati dalle dipendenze già risolte per eseguire i test nel worktree.

Caratterizzazione prima di produzione: `flutter test --no-pub` su Event VM/calendar, Post VM/screen, Sync VM/screen e sync_redirect_test: exit 0. Log integrale `/private/tmp/os3-apply-evidence/characterization.log`. Il cold start ha preparato gli output Flutter ignorati; nessun errore di test o dipendenza risolta nuovamente.

Supporti auditati per riuso: fake_repositories con pending Futures/handler e fixture modello; command_test_support (reporting restore/pump/owner teardown virtuale); ordinary_view_model_lifecycle_support e relativi probe di identità; events_harness, sync_harness e SyncRestorationFixture/SyncUseCase fixture. Nessun nuovo mock/framework necessario. D5 ordinary e D8 Category confermano cleanup locale; sorgente risolto conferma results sincrono prima del false/reporting, action differita e teardown a 50ms. Le skill Result/test non sostituiscono la distinzione domain/runtime richiesta da AGENTS e dal piano: niente blanket catch Object→Result o soppressioni analyzer.

### Gruppo 2 — Event verificato

Tre lane ordinary e una restartable implementate senza modificare la foundation. selectDate controlla prima il cache hit valido (anche fallback X non presente in all e Success empty), usa request immutabile per autorità/revisione e rebase annuale senza query aggiuntive. Modal e calendario osservano direttamente VM/results: pending anti-stale, terminale domain/runtime esplicito e Riprova sulla data corrente. Home conserva coalescing/snapshot unico, attende lane esterne e rilascia immediatamente i waiter pubblici al dispose.

`flutter test --no-pub test/ui/event test/ui/explore/widgets/explore_screen_test.dart test/routing/events_route_test.dart test/routing/home_event_discovery_test.dart`: exit 0, 84 passati. Nuovi casi F1/F5 nei test event_command_migration/event_day_migration, incluso contenuto UI, annual rebase, stale completions, retry, calendario diretto, Home next occupata dopo cattura clock e reentrancy/dispose. Analyzer mirato Event/consumer/test/support/route: exit 0, nessuna diagnostica. `flutter test --no-pub test/ui/ordinary_view_model_lifecycle_test.dart`: exit 0, 129 passati dopo estensione del supporto esistente alle tre lane ordinary Event; late success/domain/runtime/assertion, barrier/settlement e disposal identità verificati. Analyzer del supporto esteso: exit 0, nessun issue. Formatting soltanto file intenzionali e diff whitespace verdi.

I primi run rossi hanno evidenziato adattamenti dei test al nuovo ingresso differito e una firma Builder errata introdotta nell'edit, corretti prima del passaggio a Post. I test Home ora attendono l’effettivo ingresso della query prima di verificare pending/unmount: nessuna asserzione sul coalescing o sulle continuazioni è stata rimossa. Per i test con stack sintetico command_it detailedStackTraces viene disattivato localmente e ripristinato, così si distingue il forwarding originale dalla ricostruzione Chain upstream. Log grezzi in /private/tmp/os3-apply-evidence/event-final-green.log, event-analysis-green.log ed event-lifecycle.log; evidenza temporanea, non prerequisito futuro.

### Gruppo 3 — Post verificato

loadEvent/loadPlace/loadNearContent migrati a tre ordinary; route ancora identificata da (id,type), soltanto il dettaglio selezionato ammesso. PostScreen osserva results, non legge content late fino al Success corrente e mostra failure terminale generico senza nuovo retry. Listener Weather spostati ai results e staccati su replacement/dispose; Nearby conserva loadKey/coordinate/owner, events→places, partial VM, primo errore e proiezione aggregate failure senza retry.

`flutter test --no-pub test/ui/post test/routing/route_ownership_test.dart test/routing/route_parameter_redirect_test.dart test/ui/core/ui/content/nearby_content_horizontal_list_test.dart`: exit 0, 160 passati, nessuno skip. Casi nuovi: Event/Place × domain/StateError/TypeError terminali e recovery/Weather clear; Nearby tutti gli esiti parziali/doppio error, programmatic retry e runtime nei due stadi; stesso id con nuovo type e late success/domain/runtime, rebuild senza refetch e URI invalidi zero query; dispose rientrante da notify. Analyzer machine mirato Post/core_routes/test: exit 0, stdout/stderr vuoti; formatting intenzionale e diff whitespace verdi. Nessuna modifica al Weather VM o al componente Nearby condiviso.

Supporto lifecycle esistente esteso alle tre lane Post: matrice comune exit 0, 165 passati (post-lifecycle-green.log). Include late throw/assertion e private settlement oltre teardown 50ms virtuale, identity release once e nessuna fase Post successiva alla revoca. Il sentinel test-only dello slot pubblico late distingue inizializzato/non risolto senza aggiungere API al VM. Nell’autoreview Event il guard pre-entry è stato allineato a D5 (owner unavailable locale, senza I/O); il test late annuale ora stabilisce l’ingresso fisico prima del dispose, mentre pre-entry zero query rimane coperto separatamente. Ripetizione `flutter test --no-pub test/ui/event test/ui/ordinary_view_model_lifecycle_test.dart`: exit 0, 231 passati. Log temporanei in /private/tmp/os3-apply-evidence/post-final.log, post-analyzer-final.json ed event-post-lifecycle-guard-green.log.

### Gruppo 4 — Sync verificato

Unica lane ordinary bool, observer fatal prima autoload e guard pre-entry; force/schedule/single-flight invariati. Router osserva results + isRunning differito, usa isRunningSync per admission e conserva owner costruzione. SyncScreen stabilisce Provider.of listening in didChangeDependencies e rebind per identità; terminale corrente consegnato al messenger globale con context vivo prima del normale return, pending reconciliation revocabile, dedup owner/snapshot. Nessun edit main/SyncUseCase/foundation/protocollo/backend.

`flutter test --no-pub test/ui/sync test/routing/sync_redirect_test.dart test/domain/use_cases/sync_use_case_test.dart test/domain/use_cases/sync_use_case_objectbox_test.dart test/routing/geo_map_route_test.dart`: exit 0, 131 passati e uno skip preesistente GeoMap root Back (upstream 18.0.2). Test nuovi S1/S2/S3, runtime diretto e wrapper parallel prepare, fatal retry, feedback runtime dopo return, stessa Exception in tentativi distinti, Provider rebind con State conservato, snapshot B terminale, pending retry/replacement e navigazione estranea. L’asserzione originale sullo snackbar dopo ritorno Home è conservata e verde. Analyzer machine mirato Sync/router/Explore/support/test: exit 0, stdout vuoto. Matrice lifecycle comune: exit 0, 177 passati, tutte le sette nuove O e tre lane Event già verificate. Gate cursor raw late throw/assertion e teardown privato preservano identità/reporting; UseCase resta indivisibile dopo avvio.

Ambiente: primo run ObjectBox fallito per dylib assente, non per regressione; DYLD_LIBRARY_PATH non basta nel processo Flutter hardened. Copiata soltanto la libreria nativa già esistente dal checkout principale al percorso gitignored lib/libobjectbox.dylib del worktree; SHA-256 identico 1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751, nessuna dipendenza o versione modificata e sorgente originale intatto. Ripetizione comprensiva dei test reali ObjectBox verde. Evidenze /private/tmp/os3-apply-evidence/sync-verification.json, sync-targeted-green.log, sync-lifecycle-green.log e native-runtime.json.

Review indipendente read-only Event/Post e poi Sync/crossfeature: nessun finding materiale confermato. Precisazione sul test pending Provider: Element.update sotto BuildOwner.buildScope esercita replacement e rebind prima del callback di feedback; buildScope scarica anche dirty rebuild. Il caso dimostra soppressione del feedback A sullo State conservato, non isola da solo l’intervallo più stretto Provider B / campo State ancora A. Il controllo puntuale context.read del Provider corrente è presente nel codice ed è stato verificato in review; commento e nome del test corretti per non sovradichiarare l’evidenza.

### Gruppo 5 — integrazione finale, 2026-10-23

- Gate aggregato foundation/Event/Post/Sync/lifecycle/Explore/Nearby/routing completo (inclusi back, shell e restoration) e SyncUseCase/ObjectBox: exit 0, 679 passati e quattro skip preesistenti. argv/cwd/exit/durata in /private/tmp/os3-apply-evidence/aggregate.json. Il primo tentativo aveva un percorso inesistente scaffold_shell_test nella lista argv: unico failure di loading, corretto nell’invocazione senza edit o rimozione di test; shell lifecycle resta coperto dai test reali routing/back/restoration. Log del tentativo conservato come aggregate-invalid-path.log.
- Probe S4 esplicito aggiunto dopo l’aggregato: success/domain/runtime notificano terminale results con admission ancora true; il successivo isRunning differito notifica settlement con sync false e snapshot terminale. Suite Sync VM corrente: exit 0, 21 passati (sync-order-green.log). Assertion nel listener usa expectSync; il primo run con expect aveva violato il guard del pump, corretto senza indebolire la condizione. Review indipendente del probe senza finding materiali.
- `flutter test --no-pub` completo sul contenuto finale: exit 0, **2.619 passati, zero failure, sei skip preesistenti**, 101,08 secondi. SDK Flutter 3.47.5 / Dart 3.13.4, cwd worktree persistente, HEAD e3d9d891. Metadati e log in /private/tmp/os3-apply-evidence/full.json e full.log. Questa è una nuova esecuzione dell’apply, non un risultato storico OpenSpec 1/2.
- Sei skip preservati: tre varianti StateError della caratterizzazione upstream command_it 9.5.2 late-dispose (command_it_disposal_behavior_test); GeoMap root Back upstream go_router 18.0.2 già documentato in geo_map_route_test; due E2E locali opt-in all_day_pipeline ed external_event_token_pipeline, le cui variabili MOLISE_ALL_DAY_LOCAL_E2E e MOLISE_EXTERNAL_TOKEN_LOCAL_E2E non sono abilitate. Nessun nuovo skip o asserzione indebolita.
- Formatting finale limitato ai 32 Dart intenzionali: exit 0, zero ulteriori cambi. Dopo il probe S4 ripetuto B1 con stesso SDK, machine argv/flag/default e metadata package temporanei: **exit 0, 87 INFO, zero WARNING/ERROR, stderr vuoto**. Tutte le 18 identità target rimosse; le 87 non target coincidono per file/regola/messaggio/molteplicità (linee spostabili), missing/new entrambi vuoti. Baseline e final metadata/ledger in /private/tmp/os3-apply-evidence/{baseline.json,baseline-ledger.json,final.json,final.stdout}. Nessun flutter analyze separato dichiarato e nessuna configurazione/soppressione introdotta.

### Autoreview e review indipendente dell’apply

Controllati admission/reentrancy/settlement, A→B→A, cache fallback e annual rebase/failure retention, Home waiter e clock, Post detail/Weather/Nearby, Sync bootstrap/redirect/snackbar e owner Provider/router, late errors e cleanup. Correzioni durante esecuzione: guard Event pre-entry allineato a unavailable D5; test pending annual/Home portati prima all’ingresso effettivo della query; proiezioni terminali introdotte come richiesto; test stack rispettano la Chain upstream; distinzione ParallelWaitError dominio da throw diretto documentata; native runtime ObjectBox predisposto senza nuove versioni. Nessuna deviazione architetturale o modifica di foundation/UseCase/repository/backend richiesta.

Reviewer separato read-only ha esaminato prima Event/Post, poi Sync/crossfeature e infine il probe S4/artifact riconciliati: **nessun finding materiale residuo**. Il limite del test Provider/buildScope è esplicitamente documentato nel gruppo 4 e non è usato come prova della finestra più stretta. Questo controllo non sostituisce la successiva code review indipendente richiesta dall’utente. Rimangono soltanto limiti noti già accettati D5: lavoro fisico non cancellabile può trattenere risorse private fino al settlement; nessun timeout o teardown prematuro occulta il problema upstream.

### Manifest finale e vincoli Git

HEAD e branch invariati dal preflight, index vuoto. Inventario previsto: 30 tracked modificati (11 produzione, 15 test, 4 supporti), due nuovi test Dart e i sei artifact OpenSpec untracked. Nessun altro artifact della change, nessun edit a canonical/altre change, main, dipendenze, backend, SyncUseCase, WeatherVM, Nearby condiviso o factory foundation. lib/utils/command.dart resta presente. Metadata YAML e i due delta sono preservati byte per byte rispetto alla versione approvata; soltanto proposal/design/tasks riconciliati con apply. Runtime nativo e metadata SDK temporanei sono gitignored, distinti dal diff sorgente.

Inventario tracked/untracked, SHA-256 pre/post dei sei artifact, stato index/HEAD/branch e confronto non mutativo degli altri worktree in /private/tmp/os3-apply-evidence/final-integrity.json. Il vecchio percorso temporaneo non esiste e non è registrato; gli altri worktree conservano HEAD, branch e status del preflight. PR #12 riconfermata aperta/Draft, head codex/migrate-legacy-commands su e3d9d891, invariata. Nessun commit/push/merge/PR update/archive/sync canonical.

Strict OpenSpec, parsing YAML, UTF-8/newline/trailing whitespace espliciti anche sui sei untracked, git diff --check e staged diff check eseguiti nel closeout. I 27 task sono completati soltanto dopo i rispettivi gate. **READY FOR INDEPENDENT CODE REVIEW**, senza autorizzazione implicita a pubblicare o integrare.

File tracked modificati:

- `lib/routing/core_routes.dart`
- `lib/routing/router.dart`
- `lib/ui/event/view_models/event_view_model.dart`
- `lib/ui/event/widgets/components/events_calendar.dart`
- `lib/ui/event/widgets/components/events_modal.dart`
- `lib/ui/event/widgets/events_screen.dart`
- `lib/ui/explore/widgets/explore_screen.dart`
- `lib/ui/post/view_models/post_view_model.dart`
- `lib/ui/post/widgets/post_screen.dart`
- `lib/ui/sync/view_models/sync_view_model.dart`
- `lib/ui/sync/widgets/sync_screen.dart`
- `test/routing/events_route_test.dart`
- `test/routing/geo_map_route_test.dart`
- `test/routing/home_event_discovery_test.dart`
- `test/routing/route_ownership_test.dart`
- `test/routing/route_parameter_redirect_test.dart`
- `test/routing/sync_redirect_test.dart`
- `test/support/events_harness.dart`
- `test/support/fake_repositories.dart`
- `test/support/ordinary_view_model_lifecycle_support.dart`
- `test/support/sync_harness.dart`
- `test/ui/event/view_models/event_view_model_test.dart`
- `test/ui/event/widgets/components/events_calendar_test.dart`
- `test/ui/event/widgets/components/events_modal_test.dart`
- `test/ui/event/widgets/events_screen_test.dart`
- `test/ui/explore/widgets/explore_screen_test.dart`
- `test/ui/post/view_models/post_view_model_test.dart`
- `test/ui/post/widgets/post_screen_test.dart`
- `test/ui/sync/view_models/sync_view_model_test.dart`
- `test/ui/sync/widgets/sync_screen_test.dart`

File untracked sorgente/planning:

- `openspec/changes/migrate-content-view-model-commands/.openspec.yaml`
- `openspec/changes/migrate-content-view-model-commands/design.md`
- `openspec/changes/migrate-content-view-model-commands/proposal.md`
- `openspec/changes/migrate-content-view-model-commands/specs/command-execution-concurrency/spec.md`
- `openspec/changes/migrate-content-view-model-commands/specs/home-ongoing-events/spec.md`
- `openspec/changes/migrate-content-view-model-commands/tasks.md`
- `test/ui/event/view_models/event_command_migration_test.dart`
- `test/ui/event/widgets/components/event_day_migration_test.dart`
