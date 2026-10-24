# Design

## Context

### Baseline, provenienza e isolamento

Motivazione in proposal.md. Questo documento distingue **OSSERVATO** (codice/check esistenti), **INFERENZA** (rischio dedotto dal timing) e **PROPOSTO** (contratto del futuro apply). Nessun comportamento proposto è già implementato o testato in questa fase.

**OSSERVATO il 23 ottobre 2026:** repository `xmattjus/moliseis`, [PR #12](https://github.com/xmattjus/moliseis/pull/12) aperta e Draft; head `codex/migrate-legacy-commands` = `f48a08946c9ac40146104a0157556243ad433c92`, base `main` = `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. Nuova baseline esplicitamente autorizzata dall’utente dopo lo stop precedente. `f48a0894` ha unico parent `da7c426fb799a26094f043319b47e63b98728f92` (checkpoint 4); il diff contiene soltanto proposal.md/tasks.md della change 4, 19 inserimenti e 11 eliminazioni. Nessun drift source/test da riconciliare. Le change 1–4 sono pubblicate, non sincronizzate né archiviate.

Worktree nuovo: `/Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-content-submission-commands`; branch nuovo `codex/plan-migrate-content-submission-commands`; HEAD iniziale e finale del planning `f48a08946c9ac40146104a0157556243ad433c92`. Percorso e branch verificati liberi prima della creazione. La scrittura dei soli metadati Git necessari a `git worktree add` ha richiesto l’escalation sandbox, riuscita; nessun checkout/reset/rebase sugli altri checkout.

| Checkout preesistente | HEAD | Branch | Stato iniziale |
|---|---|---|---|
| `moliseis_v2` principale | ee60777 | main | clean |
| `.codex/worktrees/27f4/moliseis_v2` | ee60777 | detached | clean |
| `moliseis-worktrees/migrate-simple-view-model-commands` | 9d17d22 | migrate-simple-view-model-commands | clean |
| `moliseis-worktrees/migrate-category-view-model-commands` | e3d9d89 | codex/plan-migrate-category-view-model-commands | clean |
| `moliseis-worktrees/migrate-content-view-model-commands` | 1f3753b | codex/plan-migrate-content-view-model-commands | clean |
| `moliseis-worktrees/migrate-search-map-commands` | f48a089 | codex/plan-migrate-search-map-commands | clean |

Snapshot di HEAD/branch/status inclusi untracked e stage entries dei sei checkout acquisito prima della creazione; nessuna autorizzazione a modificare tali superfici. Il main e il branch cumulativo non sono basi da spostare durante questo planning.

### Fonti lette e riferimenti riproducibili

Riferimenti relativi alla root e linee riferite alla baseline immutabile, non al futuro diff:

| Fonte | Evidenza utilizzata |
|---|---|
| `AGENTS.md`, `.codex/agents/*.toml`, `openspec/config.yaml`, skill openspec-propose | Regole repo, delegazione read-only, schema spec-driven, nessun context/rule aggiuntivo; nessun AGENTS annidato trovato |
| Change 1 `migrate-simple-view-model-commands/{proposal,design,tasks,specs/command-execution-concurrency/spec}.md` | ordinary, progression, reporting, cleanup, consenso; appendici apply distinte dal piano storico |
| Change 2 `migrate-category-view-model-commands/` (quattro artifact e delta) | snapshot e owner, retrieval restartable vs sort ordinary, dialog e filtro |
| Change 3 `migrate-content-view-model-commands/` (quattro artifact e due delta) | Event/Home/Post/Sync, no nuove fasi dopo dispose, feedback corrente e replacement |
| Change 4 `migrate-search-map-commands/` (quattro artifact e due delta) | admission prima action, writer Search con obblighi separati, marker latest intent; reconciliation documentale f48a0894 |
| `openspec/specs/command-execution-concurrency/spec.md` e delta 1–4 nell’ordine sopra | Contratto effettivo cumulativo; il canonical completion-only è già qualificato dal MODIFIED ordinary della change 1 |
| Canonical `content-submission-{draft-persistence,local-asset-staging,submit-orchestration,navigation-lifecycle,server-idempotency,edge-boundary-validation}/spec.md` | Snapshot, arbitro unico, initialization, staging, idempotenza e retry conservativo |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` completo | constructor 99–103; command fields 189–201; initialize 207–312; candidate 316–370; add 373–482; remove 485–529; checkpoint/restore/serialize 540–619; setters/temporal 621–730; submit 744–807; prepare 809–857; release/finalize/clear/retire 860–938; recovery 949–1038 |
| `lib/ui/content_submission/widgets/*.dart` completi, `lib/routing/router.dart:59–193`, `lib/config/dependencies.dart` | consumer, form, controlli, ownership transizioni e Provider unico |
| `test/ui/content_submission/view_models/content_submission_view_model_test.dart`, `test/ui/content_submission/widgets/*.dart`, `test/routing/content_submission_{route,restoration}_test.dart` | test esistenti di tutte le cinque lane, process restoration, validation, race e UI |
| `lib/utils/{command,result_command,restartable_command,command_configuration}.dart` | API legacy, factory e snapshot, reporting, limite di disposal |
| `test/utils/{result_command,restartable_command,command_configuration,command_it_disposal_behavior}_test.dart`, `test/ui/ordinary_view_model_lifecycle_test.dart` | upstream behavior e cleanup ordinary già provati, assertion fail-loud |
| `lib/ui/explore/view_models/explore_view_model.dart:47–86`, Category/Favourite disposal | pattern concreto di cleanup differito senza nuova foundation |
| `lib/domain/models/{content_submission_draft,content_submission_staged_asset,content_submission,submission_asset}.dart`, repository contracts/implementations/mappers/entities corrispondenti | draft profondamente immutabile, fixed ObjectBox ID, path staged e request immutabili |
| `supabase/functions/submit-content/{index,submission_store}.ts`, `supabase/migrations/20261001175539_add_event_all_day_semantics.sql`, test repository/Cloudinary/Edge associati | validazione/auth/RPC atomico, first commit wins, replay ack e quota; nessuna modifica necessaria |

Audit del planning iniziale delegati soltanto read-only a explorer per consumer, contratti e foundation; decisione ownership discussa con architect per l’effettiva ambiguità fixed-ID/disposal. Risultati verificati contro source e canonical. Queste attività non costituiscono la review indipendente del piano: la review iniziale è poi avvenuta e ha prodotto F1–F3, oggetto della remediation corrente; la re-review resta successiva.

### Analyzer B0 realmente rigenerato

Eseguito Dart SDK diretto **3.13.4 stable macos_arm64** del Flutter installato, da questo worktree, su un archivio Git della nuova baseline in una directory temporanea nuova. Copiato soltanto package_config risolto dal worktree della change 4; nel file temporaneo `moliseis.rootUri` punta alla URI assoluta **risolta** dell’archivio, altre root validate e rese assolute preservando le destinazioni. Nessun pub get, upgrade, generazione, copia di segreti o modifica ai metadata/dependency di altri checkout. Lock e sorgente risolto confermano **command_it 9.5.2 / listen_it 6.0.0**. Nessun generated output creato a mano.

Comando reale:

```text
cwd: /Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-content-submission-commands
/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/content-submission-planning-B0
```

Esito misurato subprocess: **exit 0**, **66 INFO**, **0 WARNING**, **0 ERROR**, stderr vuoto. Tutte le righe hanno tipo LINT e codice `DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`. Nessun `--fatal-infos`, nessuna soppressione o configurazione modificata. L’exit del Dart diretto non è quello di `flutter analyze`: non è stata dichiarata una baseline analyzer globalmente verde.

Log temporanei `/tmp/content-submission-B0.{stdout,stderr,json}`; SHA-256 stdout `90809e0f3fc65a09568fd976ee9c3c228a1f00a31b0a6807a4b972ec97792c78`. Confronto Counter di severity/tipo/codice/path/line/column/length/message con `/tmp/search-map-apply-B1.txt` storico, normalizzando esclusivamente la root: **66 contro 66, missing=0, added=0**, comprese tutte le molteplicità. Il log storico è solo confronto, B0 è una nuova esecuzione. Ledger durevole completo nell’appendice; i percorsi temporanei non sono prerequisiti per review/apply.

| Target | Linea:colonna:lunghezza | Significato |
|---|---|---|
| ViewModel | 99:16:8 | addAsset constructor Command0 |
| ViewModel | 100:21:8 | removeAssetAt constructor Command1 |
| ViewModel | 101:14:8 | submit constructor Command0 |
| ViewModel | 102:13:8 | clear constructor Command0 |
| ViewModel | 103:26:8 | retrieveLostAssets constructor Command0 |
| ViewModel | 189:8:8 | addAsset field Command0 |
| ViewModel | 191:8:8 | removeAssetAt field Command1 |
| ViewModel | 192:8:8 | submit field Command0 |
| ViewModel | 195:8:8 | clear field Command0 |
| ViewModel | 201:8:8 | retrieveLostAssets field Command0 |
| ProgressScreen | 16:24:7 | dartdoc Command |
| ProgressScreen | 131:46:7 | color helper Command |
| ProgressScreen | 139:5:7 | text helper Command |
| ProgressScreen | 154:21:7 | icon helper Command |

Sono **14 diagnostiche**, non 14 Command: cinque costruzioni, cinque dichiarazioni e quattro riferimenti nel progress. Le restanti **52** sono AdminAuth 6, AdminSubmissionEditor VM 33, AdminSubmissions VM 9, AdminSubmissionEditor screen 1 e fake_repositories dartdoc 3.

### Inventario completo dei cinque Command alla baseline

| Command legacy osservato | Tipo/result | Ingressi/consumer osservati | Invariante e rischio inferito | Modifica proposta |
|---|---|---|---|---|
| addAsset | `Command0<AssetSelectionOutcome>`; Success anche con soft rejection, Error hard failure | AssetList tap, running spinner, await+result warning; test VM/widget | checkpoint prima picker; picker gap libero; cattura attuale dopo initialize non protegge pre-entry deferred | request envelope sessione/ticket e snapshot terminale osservato sul VM |
| removeAssetAt | `Command1<void,int>` | item callback indice renderizzato; AssetList merged listener; test VM/widget | indice catturato nel corpo oggi inline; deferred potrebbe cambiare asset | cattura sincrona sessione/digest/invalidità nel request; action no-param |
| submit | `Command0<void>` | form validate/checkpoint/fire-and-push; progress UI+retry; canRetry getter; test VM/widget/route/restoration | prepare dopo attese; lease/ack separati; snapshot request-time oggi non garantito; late phase dopo dispose | request draft/assets/issue e modalità, lease sotto arbitro, snapshot terminale domain/runtime |
| clear | `Command0<void>` | Screen legge running; test VM/widget; nessun execute UI production | retire persistence-first, guard lease dentro arbitro; stale deferred request non deve clear nuovo ID | request target, stessa retire primitive, no-op stale e guard live |
| retrieveLostAssets | `Command0<void>` | Screen post-frame; AssetList spinner/merged listener; test VM/widget | platform best-effort, eligible ID letto dopo lost data; risposta non può legarsi a una sessione successiva | request initialization/eligible target, early retrieval, commit guardato e terminale distinto |

Setters form/event, initialize, checkpointDraft e restoreCheckpointDraft non sono Command e restano tali. CTA naviga soltanto alla form route. Nessun altro Command è stato trovato nei widget figli date/description/checkbox/fields; i Command omonimi Admin sono altri owner e fuori perimetro.

## Goals / Non-Goals

**Goals:** rendere osservabile l’admission senza cambiare payload o storage, fissare gli intenti prima dell’action differita, mantenere ordine locale e ownership, distinguere gli errori e chiudere le finestre di consumer replacement/disposal con test discriminanti.

**Non-Goals:** nessuna queue Command aggiuntiva, Restartable, framework, coordinator globale, cross-owner serialization, schema migration, repository nuovo, modifica Cloudinary/idempotenza/ObjectBox/codec draft; nessuna migrazione Admin, rimozione legacy compatibility o nuova validazione di form/terms. Nessuna retry automatica o persistenza dell’ack. Foundation e command_configuration restano invariate.

## Decisions

### D1 — Cinque lane ordinary, ingresso pubblico sincrono

**OSSERVATO:** command_it 9.5.2 `lib/command_it.dart:312–408` alza `isRunningSync` e loading `results` sincronicamente; attende `Future.delayed(Duration.zero)` prima dell’action. `run` busy è ignorato. `runAsync:859–870` unisce chiamanti a un completer; dispose 799–825 può completarlo con il valore corrente dopo 50ms. Né await né valore trattenuto provano successo di una nuova richiesta. `results` notifica sincronicamente; `isRunning` è differito. Il legacy esegueva il corpo prima di restituire.

**PROPOSTO:** cinque command privati `_addAssetCommand`, `_removeAssetAtCommand`, `_submitCommand`, `_clearCommand`, `_retrieveLostAssetsCommand`, tutti `ResultCommand<void,T>` creati con `createResultCommandNoParam` (T = AssetSelectionOutcome per add, void per gli altri). Anche remove è no-param: l’indice viene risolto nel suo envelope, non passato alla futura action. DebugName costanti, non sensibili; reporting le normalizza al contesto `command` già allowlisted. Niente estensione di command_configuration.

API pubblica determinata:

- `bool requestAddAsset()`, `bool requestRemoveAssetAt(int index)`, `bool requestSubmit()`, `bool requestClear()`, `bool requestRetrieveLostAssets()`;
- cinque snapshot read-only `addAssetSnapshot`, `removeAssetAtSnapshot`, `submitSnapshot`, `clearSnapshot`, `retrieveLostAssetsSnapshot`, tipo `command_it.CommandResult<void, Result<T>?>`; il ChangeNotifier del VM è l’osservabile pubblico unico (void e void? sono equivalenti nel parametro no-param; usare la firma risolta dalla factory);
- getters sincroni `isAddingAsset`, `isRemovingAsset`, `isSubmitting`, `isClearing`, `isRetrievingLostAssets`, che leggono `isRunningSync.value` privato;
- `canRetrySubmissionImmediately` derivato, nessun flag retry mutabile. Nessun oggetto pubblico con `run`, `execute` o `runAsync`.

Ogni metodo verifica prima `_disposed` e busy della propria lane. Se negato restituisce false senza cambiare snapshot/slot, senza I/O e senza feedback. Se ammesso cattura il target D2. Per il solo submit normale Ready registra subito la cattura ordinata D2.F2 nello stesso `_serialize` e collega il suo handler, senza I/O o notifiche. Costruisce poi l’envelope immutabile con identità di esecuzione Object e quel Future già osservato, assegna lo slot della sola lane e chiama `run()`, restituendo true. Registrazione e handler precedono quindi `run()` e qualunque sua notifica; un duplicato negato non registra alcuna cattura. true significa admission, non successo. Un indice invalido viene ammesso con errore catturato e produce terminale Error; non diventa valido dopo restore. Nessuna queue di richieste scartate. I caller che devono aspettare usano il terminale di quell’esecuzione; nessun public waiter introduce un nuovo framework.

**Dettaglio verificato nell’apply (reentrancy ordinary):** l’inizio running e gli snapshot restano inoltrati subito; soltanto la notifica VM del passaggio sync-running a false viene differita a un microtask. In command_it 9.5.2 il percorso success scrive false sia prima di value sia nel finally: ammettere una nuova esecuzione dentro il primo callback consentirebbe al vecchio finally di azzerarne il busy. Il microtask lascia terminare quello stack prima di esporre il sync-idle ai listener VM. I getter e l’admission leggono ancora lo stato sincrono originale; nessuna richiesta rifiutata viene accodata, nessun nuovo arbitro. I callback differiti ricontrollano disposal e leggono gli snapshot correnti, senza pubblicare cache di un’esecuzione precedente.

Lo slot non è una seconda serializzazione: per lane esiste al più un envelope, non un backlog. L’action lo copia in una variabile locale prima del primo await. Ogni pulizia del riferimento controlla `identical(slot, envelope)` per non cancellare una richiesta rientrante successiva. Prima di ogni side effect si ricontrolla owner e target; osservatori sincroni della admission possono aver disposto/rebound l’owner. Non avviare initialize dal wrapper prima di `run`: si può creare/identificare il ticket senza I/O.

**Scartati:** sostituire `.execute()` con `.run()` lasciando snapshot dentro action (finestra di reinterpretazione); cinque `runAsync()` pubblici (join e false success); Restartable per mutazioni (nessun requisito latest-intent); nuova façade Command o nuova dipendenza.

### D2 — Snapshot alla richiesta e inizializzazione identificata

**OSSERVATO:** draft è profondamente immutabile (`freezeDescriptionDelta`); `assets` getter è una vista non modificabile ma **viva**, non uno snapshot. `_removeAssetAt` cattura oggi sessione/digest prima dell’await; spostarlo dentro una action deferred perde quel timing. `_prepareSubmissionAttempt` cattura oggi dopo initialize e dopo l’attesa dell’arbitro. Recovery legge l’eligible identity dopo retrieveLostData, quindi può attribuire una risposta a una diversa sessione se non si fissa la provenienza.

**PROPOSTO (corretto da F2):** envelope Ready del submit contiene `clientSubmissionId`, draft immutabile e issue catturati sincronicamente, più il Future privato della membership ordinata definita in D2.F2; non copia la lista runtime immediatamente alla richiesta; per remove contiene coppia sessione/digest oppure errore di indice originario; add/clear contengono l’identità, recovery contiene l’identity eleggibile già stabilita. XFile è usato come riferimento al path staged e digest, non viene copiato il binario né promesso che un file non possa sparire. I setter successivi della stessa sessione non modificano il payload catturato.

Richiesta durante loading: identifica subito il **medesimo ticket di inizializzazione del VM** (una sola istanza, non un epoch globale), e cattura anche draft provvisorio e issue visibili alla richiesta; la membership viene dal risultato immutabile di quel ticket, non dalla lista runtime provvisoria. L’inizializzazione memoizzata sigilla un risultato immutabile prima di `notifyListeners` e prima di completare il Future:

1. restored: draft proveniente dal risultato load, lista completa di asset riconciliati e identity eleggibile; non usare setter arbitrari avvenuti durante reconcile per costruire il draft del ticket;
2. absent: identità provvisoria, esito staged/orphan reconciliation; la richiesta conserva **il proprio** draft/issue catturati, mai gli edit successivi durante l’attesa;
3. unknown/unavailable: errore originale sigillato nel ticket. Submit non ricattura membership o recupera implicitamente quello stato. Add mantiene il retry di riconciliazione pre-picker già canonico, soltanto per la stessa identità e sotto il medesimo arbitro; persisted ownership unknown resta bloccante e non autorizza adozione/orphan cleanup;
4. assertion di bootstrap: esito privato runtime con Object/StackTrace originali (D5.F1), sigillato senza generare un secondo Future error non osservato; initialize rilancia e la action che lo attende conserva il fail-loud, senza attendere un ticket rimasto irrisolto.

La richiesta attende il Future esistente e risolve **solo dal ticket identificato**; non ricattura `_state` o `_assets` arbitrariamente dopo await: Ready legge gli asset esclusivamente al punto ordinato D2.F2, Loading usa la lista sigillata del ticket. Per restored, il risultato può legittimamente identificare il draft persistito che alla richiesta non era ancora noto; è una scelta esplicita del protocollo initialize, non adozione di una sessione creata successivamente. Per absent non vengono inventati asset futuri. Prima di usare il target entra nell’arbitro e confronta identity corrente, ticket ed eventuale disponibilità staged. Una rotazione dopo la sigillatura invalida il target. Direct add/submit/clear prima di initialize restano possibili tramite il ticket; remove su indice inizialmente invalido resta errore.

#### D2.F2 — Membership ordinata, distinta dallo snapshot del draft

**Finding e scelta:** il precedente piano copiava la lista runtime alla richiesta e poteva escludere X già nel commit serializzato. Il legacy copia invece draft e membership in `_prepareSubmissionAttempt` dopo l’attesa dell’arbitro (`809–855`), potendo includere anche Y posteriore alla richiesta. La remediation preserva gli effetti anteriori nell’arbitro, ma esclude deterministicamente i posteriori: è una precisazione semantica esplicita, **non equivalenza perfetta** del legacy. Draft/issue/identity restano request-time; membership ha un punto di cattura diverso, fissato dalla stessa richiesta.

**Terminologia:** registrazione nell’arbitro = esecuzione sincrona di `_serialize` fino all’assegnazione di `_lifecycleTail`, prima del suo primo await (`605–609`); ingresso fisico = chiamata della closure dopo `await previous`. Le registrazioni già presenti prima di `requestSubmit` sono anteriori anche se la loro closure non è ancora partita. Un tap add precedente ancora in deferred action, initialize o picker, senza registrazione della fase commit, non è staging anteriore. La promessa riguarda l’ordine di questo arbitro locale, non l’ordine globale dei tap o le write fra owner.

Traccia baseline prima/dopo gli await (nessuna modifica al source in questa remediation):

| Fase | Prima dell’await | Dopo l’await e prima del release | Pubblicazione |
|---|---|---|---|
| `_addAsset` pre-picker 377–409 | initialize conclusa; registra `_serialize`; eventuale reconcile e save | cattura identity solo se checkpoint riuscito | checkpoint può notify; non c’è ancora il picker |
| picker 414–418 | pre-picker boundary rilasciato | selectedAssets disponibili; registra la fase commit separata | nessun asset runtime durante il picker |
| `_processAssetCandidate` 325–369 nel commit | capacity; await length, poi hash, poi acquire | acquire Success rende staged unavailable; await resolve; solo Success aggiunge record e ristabilisce available | `_assets.add` è **prima** del release del commit; notify add è fuori boundary e può arrivare dopo la cattura F2 |
| `_removeAssetAt` 500–514 | target già catturato; registra boundary; await repository remove | solo Success live rimuove digest dalla lista | membership aggiornata prima release; notify esterna dopo |
| `_prepareSubmissionAttempt` 809–857 legacy | registra boundary dopo initialize | legge `_state` e copia `_assets`, poi await save della snapshot; claims ownership | membership legacy dopo predecessor, ma non legata all’admission |
| `_submit` 744–807 | await preparation | upload sequenziali e submit fuori boundary; await release/finalize nei rispettivi punti | payload usa attempt, non lista corrente |
| `_serialize` 605–619 | salva previous e installa release Future sincronicamente | attende previous; esegue action; finally completa release | nessun notify proprio, ordine tail anche se una action fallisce |

Protocollo **Ready / submit normale**:

1. Il request method verifica disposed/busy senza side effect, cattura draft/issue/identity. Nel medesimo stack registra una sola closure di cattura mediante `_serialize`; con il Future già munito di handler costruisce e assegna l’envelope immutabile della lane, tutto **prima** di `Command.run()`. Non alza il lease di submission, non checkpointa e non inizia I/O.
2. `_serialize` appende il suo release Future alla coda già esistente. La closure aspetta solo le registrazioni anteriori; quando entra verifica owner live, identità catturata e `_stagedStateAvailable`. Se validi copia `List<Asset>.unmodifiable(_assets)` nell’ordine corrente **dentro questa closure**. Un’indisponibilità diventa l’errore di preparazione esistente; identity stale non adotta una sessione diversa. Se disposed produce soltanto un esito privato revoked. Non notifica, non reclama ownership, non attende la futura action e rilascia subito l’arbitro.
3. Il request method collega immediatamente, prima di `run`, un handler al Future di cattura: ogni `(Object, StackTrace)` imprevisto viene trasportato in un esito privato non lanciato (ready/domain/revoked/runtime), senza `Result.error` sintetico né reporting anticipato. Non c’è un await fra creazione del Future e installazione dell’handler. Non usare `unawaited` su un Future che può ancora fallire senza handler.
4. La action deferred consuma quel preciso esito. Anche se disposed deve drenare il Future di cattura già registrato, mantenendo il Command vivo fino al settlement; non avvia initialize o nuovi I/O. Se l’esito è runtime rilancia l’Object con lo stack originale tramite `Error.throwWithStackTrace`, così il Command lo riporta una volta; se revoked non pubblica alcun esito UI. Con esito ready e owner ancora valido entra nella normale preparazione `_serialize` con draft/issue/identity request-time e lista sigillata. La preparazione rivalida identità e disponibilità staged corrente, ma **non ricopia la lista né cambia il draft**.
5. Operazioni registrate dopo la cattura possono entrare fra questa e la preparazione deferred: Y può essere già visibile quando la preparazione entra, ma non viene aggiunto al payload. Una rimozione successiva può rendere un path catturato indisponibile, lasciando la normale failure del primo upload. Clear fra cattura e preparazione può ruotare la sessione: submit termina Error, zero checkpoint/upload/final request per la sessione obsoleta. Se la preparazione è già proprietaria, resta la regola S3 che respinge clear.

Questa closure è **una voce nello stesso `_lifecycleTail`**, senza nuova coda, mutex, writer, coordinatore, revision log o attesa di HTTP/picker nell’arbitro. Finalization-only non registra catture di membership: va direttamente al solo retirement dell’identità acknowledged. La mutabilità del file sul disco resta il limite esistente: è congelata la lista di record/path/digest, non il binario.

**Loading:** nessuna closure viene registrata in attesa di un’inizializzazione non ancora avviata; altrimenti dispose prima dell’action potrebbe lasciare l’arbitro bloccato. L’action live avvia/attende initialize fuori `_serialize` come prima, e usa la lista completa sigillata dal ticket D2 (restored) o la lista assente/riconciliata del ticket (absent), con draft provvisorio request-time per absent. Tutti i percorsi mutativi aspettano initialize prima di registrare le proprie fasi: mentre è loading non può esserci una mutation locale già dentro l’arbitro da includere. La riconciliazione di bootstrap è parte del ticket, non una mutazione Command concorrente. Mutazioni registrate dopo il ticket non cambiano quella lista; una rotation successiva fallisce il guard identità in preparazione. Dispose prima dell’action non avvia initialize e non lascia alcuna cattura prenotata per Loading.

**Se la mutation anteriore fallisce:** la catena `_lifecycleTail` attende il suo release, non propaga l’esito della sua action. Acquire X che restituisce Error prima del commit lascia la precedente lista disponibile: la cattura include solo quella lista, add fallisce e submit può riuscire indipendentemente. Acquire riuscito seguito da resolve Error lascia invece `_stagedStateAvailable == false` e svuota la runtime list (`349–366`): cattura/preparazione falliscono, zero upload/submit. Un raw throw rimane runtime della propria lane secondo D5; non si fabbrica un successo X né si importa il suo errore come risultato di un altro Command. La disponibilità effettiva lasciata dal boundary viene sempre rivalidata, mai catturata nel mezzo di acquire/resolve alla richiesta.

**Alternative scartate:** lista request-time (perde X anteriore), lista nella preparazione deferred (include Y posteriore), intera preparazione registrata alla richiesta (anticipa checkpoint/lease e complica la revoca), filtro per digest di una lista già copiata (non rappresenta X ancora invisibile), seconda queue/epoch delle mutazioni (ridondante rispetto al tail esistente). Nessuna scelta è lasciata all’executor.

Standalone `checkpointDraft()` e `restoreCheckpointDraft()` restano Future<Result<void>> senza Command, cattura di checkpoint **dentro** `_serialize` come canonical; non trasferire loro lo snapshot request-time del submit. Nessun vecchio save può riesumare un’identità ritirata. L’inizializzazione mantiene l’attuale boundary di normalizzazione non-assertion read/reconcile e ready/unknown (eccezione fail-loud esplicita D5.F1): non aggiungere reporting duplicato per errori già consumati da quel boundary; un throw che raggiunge una action Command segue D5.

**Scartati:** cattura del solo indice, cattura della membership al request-time invece del posto D2.F2, UnmodifiableListView come snapshot, ripristino letto da `_state` dopo await, fallire tutte le richieste loading, oppure creare una seconda initialization/copia di storage.

### D3 — `_serialize` resta l’unico arbitro locale

Non aggiungere mutex, scheduler, writer, coordinator o queue. Le cinque lane single-flight sono indipendenti; il loro running non è mutua esclusione cross-lane. La semantica d’ordine è quella dell’acquisizione di `_serialize`, non una promessa globale sull’ordine dei tap.

- Add: initialize/ticket; fase pre-picker dentro arbitro (guard identità, ownership nota, reconcile se necessario, checkpoint della sessione corrente); picker fuori arbitro; fase commit dentro arbitro con identity guard prima di ogni candidato. Capacity, SHA-1 dedup, 10MB, massimo cinque, soft rejections e logging senza nomi nell’UI invariati.
- Remove: target catturato; sotto arbitro verifica stessa sessione e presenza digest, remove persistente prima del runtime update. Se target già assente/ritirato: successo no-op senza effetti UI specifici.
- Submit: cattura la membership al posto registrato da D2.F2; poi la preparazione sotto lo stesso arbitro verifica identità del target, staged disponibile, stessa eligibility corrente (nessuna validazione aggiuntiva), usando draft/issue request-time e ordered assets sigillati da D2.F2; checkpointa esattamente quel draft; ricontrolla owner dopo await/notify, poi reclama ownership prima di rilasciare l’arbitro. Nessun upload dentro arbitro.
- Clear: sotto arbitro verifica target e assenza ownership attiva/pending. Se il target è già ritirato: no-op senza ritirare quello nuovo. Persistence-first, cleanup e una rotazione sul successo live. Unknown persisted state resta il caso esistente: clear persistente riuscito autorizza orphan cleanup, non adozione di asset.
- Recovery: richiesta lega eligible identity/ticket prima di attendere media. Retrieval Android fuori arbitro (può precedere fine initialize); commit serializzato richiede stesso target, staged disponibile e owner live. I candidati riusano `_processAssetCandidate`. Un’altra sessione non può diventare eleggibile per quella risposta. Non-Android zero retrieve.

`_serialize` deve usare `try/finally { release.complete(); }` preservando l’eccezione, rimuovendo le attuali conversioni generic Exception/Object→Result. Nessuna `catch` che nasconda AssertionError. Tutti i caller sono auditati: repository expected errors già come Result; checkpoint/restore diretti possono propagare un unexpected throw; i consumer UI/route lo trattano con il boundary esplicito D5, senza trasformarlo in successo o Result fabbricato. Le transizioni catturano token/release prima dell’await. La release privata dell’ownership submit non effettua storage: entra nello stesso arbitro per matching dell’identità e libera sempre il lease pre-ack, anche se il VM è disposed.

**Scartati:** mantenere generic catches solo per far terminare il Command; aspettare picker/HTTP dentro `_serialize`; un secondo FIFO come Search; proibire tutte le mutazioni durante submit (canonical consente stesso-session B, che sopravvive a failure ed è ritirato su success).

### D4 — Submit: preparazione, ownership, acknowledgement, retry

L’envelope submit identifica anche la modalità alla richiesta (membership ordinata D2.F2 solo per tentativo normale): normale tentativo oppure finalizzazione-only con acknowledged id. Non cambiarla dopo un await. `isSubmitting` impedisce un secondo tentativo nella stessa lane. Prima di ack, solo l’attuale preparazione riuscita può installare `_activeSubmissionClientSubmissionId`; una clear entrata prima può ruotare A e far fallire submit obsoleto, mentre una clear dietro preparazione già proprietaria deve fallire senza I/O. Non reclamare ownership già all’admission: checkpoint può fallire, e l’arbitro esistente resta la fonte dell’ordine.

Dopo preparazione: upload sequenziali dell’elenco catturato, stop al primo Result.error; prima di ciascun upload e prima della final request guard owner live. La rimozione successiva di una fonte catturata può produrre normale failure upload; non re-snapshot, non acquisire nuovi asset. Form edits e staged additions della stessa identity continuano secondo `_serialize`; su failure restano, su successo sono ritirati con la sessione. Nessun trasferimento di B a una nuova identity.

`try/finally` deve comprendere tutta la fase con ownership; Result.error, malformed ack (già classificato repository), throw Exception/Error/Object e assertion prima di ack liberano il matching lease privato senza nuovi I/O e senza sostituire error/stack. Nessun catch converte il primario in Result. La precedenza fra failure primaria e un eventuale errore secondario di rilascio è fissata in D5.F1, senza mascheramento.

Su Success remoto live: impostare pending e acknowledged id **prima** di qualunque finalization await. Da quel punto non rilasciare ownership in finally per failure locale. `_finalizeSubmittedSession(expectedId)` sotto arbitro verifica pending, owner e identità corrente prima di clear; usa lo stesso retirement di clear, non il Command clear pubblico (che deve essere negato). Solo successo locale live produce una nuova identity e Success<void>(null). Un Result.error di staged cleanup già best-effort rimane tale limite: non introdurre una nuova condizione terminale dopo che draft clear è già riuscito. Un unexpected throw del cleanup resta runtime e pending; retry idempotente riusa i primitive esistenti.

Retry UI = `!isSubmitting && submitSnapshot.hasFailure && submissionFinalizationPending` su owner corrente. Domain failure e handled runtime failure di finalizzazione sono entrambi retry locale; non si fabbrica Error<void> per attivarlo. Una retry admitted azzera la vecchia presentazione subito; nessun nuovo prepare/checkpoint/upload/submit. Ordinaria failure pre-ack: niente Riprova immediato, anche se backend oggi è idempotente. Si torna al form e si usa il normale flusso validato con la stessa identity. Conservato il rollout legacy/hardened del canonical: nessun parsing di messaggi, capability probe o retry nascosta.

**Contratti esterni immutati:** UUID v4 del draft; SHA-1 locale per dedup e SHA-256 Cloudinary per riuso; staged path feature-owned; ObjectBox fixed draft ID; Edge auth e request allowlist; un `submit_content` RPC atomico per content/assets/quota; replay scoped per utente/identity con primo payload vincente; ack positivo validato repository. Nessuna Cloudinary deletion/rollback.

### D5 — Errori, terminale e disposal

| Provenienza | Esito Command | Reporting | Retry progress |
|---|---|---|---|
| Repository Result.error, validation/range/session stale | data Error originale | nessun CommandExecutionFailed aggiuntivo | no prima ack |
| PlatformException attesa da picker/recovery, FileSystemException attesa nella lettura del candidato | add Error con logging feature esistente; recovery log + Success best-effort | logging feature, non global runtime | no |
| StateError/TypeError/Exception/Object inatteso che raggiunge action o serialize | error runtime originale, no conversione | global configurato una volta, stack originale | solo se ack pending |
| Result.error o throw in finalize dopo ack | domain o runtime come sopra, pending/owner conservati | secondo tipo reale | solo finalize |
| AssertionError | upstream fail-loud, nessuna normale failure UI promessa | sviluppo/test upstream | non classificato come retry |
| initialization boundary normalizza read/reconcile non-assertion | ready unavailable/unknown esistente; assertion raw | nessun nuovo global duplicato per quarantena; assertion fail-loud | nessuna nuova policy retry |
| checkpoint/restore Future diretti, fuori Command, raw inatteso | throw al chiamante diretto, nessun Result fabbricato | boundary UI/route FlutterError una volta | nessun submit/push/exit su failure |

#### D5.F1 — Audit esaustivo dei catch e responsabilità di normalizzazione

**Causa verificata:** oltre a `_serialize`, `_removeAssetAt` ha un proprio `on Exception catch` (`522–530`) che logs feature e restituisce Error. Rimuovere solo i catch dell’arbitro lascia quindi F1 aperto: una `Exception` raw del contratto repository sarebbe ancora sintetizzata come dominio. La classificazione dipende dal **boundary di provenienza**, non dalla sola classe Exception.

| Boundary effettivo alla baseline | Catch/normalizzazione osservati | Contratto del futuro apply e logging |
|---|---|---|
| `_initialize` 207–259, comune a tutte le lane | `on Object` mette read/reconcile in quarantena; Exception conservata o non-Exception convertito per unknown/unavailable; finally ready | Conservare la normalizzazione intenzionale di bootstrap per failure non-assertion e la distinzione unknown/absent, senza nuovo global duplicato. **AssertionError deve uscire con rethrow prima della normalizzazione**: il ticket registra esito runtime originale, non Error sintetico; finally/settlement non lasciano waiter pendenti. Questo limite esplicito della normalizzazione concilia bootstrap con fail-loud. |
| `_reconcileStagedAssets` 265–312 | nessun catch; propaga Result.error di reconcile/resolve; count e path validation sono dominio | In initialize vale il boundary di bootstrap sopra. Nel pre-picker già inizializzato i raw throw arrivano al Command; un FileSystemException raw di un repository non diventa atteso solo per il tipo. |
| `_addAsset` 373–483 | broad `on Exception` 474–482 log AddFailed e Error | Togliere il catch generale. Gestire PlatformException solo intorno alla chiamata picker, e failure file soltanto nelle letture dirette sotto. Raw Exception di checkpoint/acquire/resolve/logger/policy fuori questi scope resta runtime. |
| `_processAssetCandidate` 316–370: length/hash vs acquire/resolve | nessun catch proprio; capacity/size/dedup sono disposition, repository ritorna Result | FileSystemException di `XFile.length/openRead` è failure operativa attesa della **lettura diretta**, con originale error/stack; normalizzarla esclusivamente lì. Acquire/resolve Result.error restano gli stessi Error; qualunque throw diretto di quei contratti è runtime anche se FileSystemException o PlatformException. |
| `_removeAssetAt` 485–530 | broad `on Exception` 522–530 | **Eliminare il catch generale, senza sostituirlo con `on FileSystemException` o PlatformException.** Non c’è I/O file/plugin diretto da classificare qui: `remove` promette Future<Result<void>>. Risultati Error conservati; ogni throw dal contratto di remove, inclusa una normale `Exception`, attraversa il Command come runtime originale. |
| checkpoint/restore e snapshot checkpoint 540–603 | nessun catch proprio; save Error conserva Exception | `_serialize` non converte raw. Nei Command vale global; per Future diretti valgono il boundary Screen/router sotto e il reporting del chiamante. Snapshot baseline avanza solo su Success live. |
| `_serialize` 605–619 | `on Exception`→Error; `on Object`→Exception wrapper; finally complete | Eliminare entrambi i catch. `previous` è solo il release Future non fallibile del predecessore; callback in try/finally, release esattamente una volta, nessun I/O/log/await nella release. Exception/Error/Object/AssertionError non vengono sostituiti. |
| `_submit` 744–807, `_prepareSubmissionAttempt` 809–858 | nessun catch; validate Error; finally release lease | Domain Result da prepare/upload/final submit conserva Exception. Raw del task upload o di submit rimane runtime. Nel finally valgono precedenza e matching del lease qui sotto, mai wrapping Object. |
| `_releaseSubmissionOwnership` 860–867 | nessun catch, usa `_serialize`, solo matching e assegnazione privata | Nessun await/storage dentro la closure né logger/notifica; idempotente sul matching id. Il suo Future è atteso nel protocollo di precedenza senza mascherare il primario. |
| `_finalizeSubmittedSession` 869–892, `_clear` 894–912, `_retireCurrentSessionInsideBoundary` 914–938 | nessun catch; draft clear Error è bloccante; Result dei cleanup staged è intenzionalmente best-effort | Nessuna nuova normalizzazione raw. Clear/reconcile/clearSession raw resta runtime. Prima ack release; dopo ack pending/owner conservati e retry esclusivamente locale. Best-effort riguarda i **Result** già restituiti, non bug raw nascosti. |
| `_retrieveLostAssets` 949–1038: retrieve 957–960 | broad `on Object`→feature log e Success | Restringere alla PlatformException attesa della **sola** chiamata retrieveLostData; mantenere response.exception log+Success 970–976 e response vuota come no-op. Raw Exception/StateError di plugin non classificato resta runtime. |
| recovery processing 993–1030 | broad `on Object`→feature log e Success; processed Error log 1015–1017 | Rimuovere il broad catch: Results di staging e file failure operative note sono log best-effort, zero UI recovery; raw repo/helper/logger segue global una volta, non Success. |
| repository draft/staged, confini esterni invariati | draft load/save/clear e staged acquire/remove/resolve/reconcile/clearSession normalizzano Exception operative; acquire pulisce temp best-effort | Non modificare repository. Mantengono i loro Result e logging feature. In staged acquire il cleanup temp già protegge l’Exception primaria; non copiarne generic catches nel VM. |
| repository submit / Cloudinary upload task, confini esterni invariati | submit distingue FunctionsFetchException, FunctionException normalizzata, Format/transport Exception; task espone Result; transaction.finish già unawaited | Preservare gli attuali boundary e riuso/retry bounded. Normalizzazioni già consumate sono Result per il VM; non riaprire/error-classificare l’infrastruttura, non dichiarare risolti i suoi limiti di telemetry cleanup. |
| capture membership Ready, nuova sola lettura D2.F2 | Future può precedere action entry | Handler immediato trasporta raw `(Object, StackTrace)` in privato, senza global/Result.error; la action rilancia originale una volta. Nessuna nuova normalizzazione di dominio per un bug della cattura. |

**Logging e provenance:** remove atteso (`Result.error`) è già loggato da `ContentSubmissionStagedAssetRepositoryImpl.remove:141–169` con ContentSubmissionAssetRemovalFailed: il VM non ripete quell’evento e non chiama global. Remove raw non genera un secondo evento feature al VM: passa al solo CommandExecutionFailed con error originale. Vale lo stesso per i raw degli altri contratti repository. Per picker e lettura file direttamente posseduti dal VM restano ContentSubmissionAssetAddFailed (add) o ContentSubmissionAssetRetrievalFailed (recovery) con error/stack originali, senza global. Soft rejection size/capacity resta successo con warning senza nomi nell’UI.

Per la lettura file condivisa, conservare privatamente provenance **diretta** e coppia `(FileSystemException, StackTrace)` fino alla policy add/recovery; una failure così catturata non va confusa con un FileSystemException raw lanciato da acquire/resolve. La politica del caller emette il proprio evento feature una volta e restituisce l’Error originale (add), oppure completa best-effort senza UI (recovery). L’esito privato può essere un record del helper già feature-local: non è un nuovo contratto repository o un framework di errori. Non collocare il catch file intorno a tutto `_processAssetCandidate` includendo le sue repository await. Recovery può mantenere il proprio evento di contesto sui Result repository già falliti, come oggi; non duplicare l’evento per una medesima file failure già loggata e non mandare questi Result al reporter Command.

**Oggetto e stack:** su raw failure non costruire Exception(error), toString, nuovo StackTrace o Result.error. Un catch necessario solo per eseguire release usa `rethrow`, oppure conserva la coppia e termina con `Error.throwWithStackTrace(original, originalStack)`. command_it può decorare lo stack con detailedStackTraces: il test discriminante salva/ripristina questa opzione e la disabilita solo localmente per confrontare lo stack sentinel; il test con configurazione reale verifica anche che i frame originari restino. Il logger globale riceve l’Object originale una volta, senza parametri sensibili.

**Precedenza primaria/cleanup:** la chiusura del tail usa un completer privato completato una sola volta; non deve eseguire altre operazioni fallibili. Per il lease submit distinguere il risultato primario prima di attendere release: successo, Result.error originale o raw `(Object, StackTrace)`, inclusa assertion. Eseguire la release matching in un try separato. Se riesce, restituire/rilanciare il primario invariato. Se produce un errore secondario e il primario è già failure, conservare il primario come risultato del Command e segnalare separatamente il secondario con error/stack originali al boundary FlutterError (contesto costante, nessun nuovo Result o CommandExecutionFailed per il primario). Se non c’è una failure primaria, il cleanup throw è la runtime failure di quell’esecuzione. Anche un errore del reporter secondario non può sostituire la coppia primaria; la consegna finale del primario avviene in finally. Nessun retry I/O, dispose anticipato o cancel del lease. Una assertion primaria viene sempre rilanciata, mai trasformata in terminale normale; una assertion secondaria resta visibile nel canale diagnostico sviluppo, senza rimpiazzare il primario.

**Test discriminanti E1/E2:** estendere il fake staged condiviso, che oggi ha solo removeResult/pendingRemove (`test/support/fake_repositories.dart:1238–1324`), con throw controllato e stack sentinel, senza nuovo fake parallelo. Dopo initialize e asset A, remove lancia direttamente `Exception('unexpected remove')`, non un Error Result. E1 live: terminal `unexpectedError` stessa istanza, `domainError == null`, frame/stack sentinel conservati, CommandExecutionFailed esattamente uno, nessun doppio AssetRemovalFailed dal VM, A/path/digest invariati; un checkpoint indipendente successivo attraversa l’arbitro e riesce. E2: remove fisicamente entrato rimane pending, dispose, poi completa con quella Exception oltre 50ms virtuali; stessi error/report in privato, **zero** notify/snapshot pubblici dopo dispose, asset invariato e cleanup una volta. La disponibilità dell’arbitro dopo throw si prova in E1 prima della revoca; dopo dispose nuove request sono vietate, quindi E2 non pretende una mutation pubblica del VM morto. Il precedente test Result.error di remove (VM test 1956–1975) resta distinto, con domainError originale e global=0. E4 completa il fake load/reconcile con AssertionError e stack controllati mentre una action attende il ticket: assertion originale sul canale sviluppo, nessun domain terminale fabbricato, niente reconcile/staging successivo e nessun waiter di inizializzazione o cleanup settled stranded. E3 verifica che il raw primario upload/final submit o assertion non cambi dopo release matching e che un clear indipendente trovi il lease rilasciato; revisione statica del ramo secondario verifica la precedenza senza introdurre una seam di storage fallibile nel cleanup.

Per `_submit`/`_openExternalLink` della Screen e `onExit` del router, i Future diretti checkpoint/restore non passano da un Command. Aggiungere un catch di boundary che conserva error/stack originali, riporta una volta con `FlutterError.reportError(FlutterErrorDetails(...))` e solo contesto costante non sensibile; AssertionError viene rilanciato secondo fail-loud. Non avviare submit, launch, push o route removal; feedback generico soltanto con mounted/owner/session ancora correnti, release token nel finally già catturato. Il router oggi cattura Object senza reporting: estendere quel catch circoscritto, senza duplicare il reporting dei Result.error infrastrutturali. La Screen oggi ha solo finally: non lasciare un nuovo raw throw non gestito nei callback unawaited dopo aver rimosso il catch di `_serialize`. Chiamanti diretti non-UI continuano a ricevere il throw e ne possiedono il reporting, senza doppia segnalazione dal VM.

Narrow catches attesi devono stare ai confini picker/file che li possiedono; non catturare generic Exception per far sembrare ogni runtime un errore di dominio. La recovery resta best-effort per gli esiti attesi di piattaforma, non un contenitore che inghiotte qualunque bug. Logger feature e privacy restano: niente path/nome file nei messaggi UI, payload nei debugName o parameter wrappers nei log.

Dispose è idempotente: marca disposed e revoca forwarding/consumer callback prima di qualsiasi teardown. Le continuazioni controllano owner **dopo ogni await**, dopo notify rientrante e prima di ogni nuova fase (length/hash/acquire/resolve/remove/checkpoint/upload/final submit/clear/cleanup); il guard impedisce fasi nuove, non annulla I/O in corso. Le normali uscite revocate possono restituire un Result neutro interno ma nessun consumer lo usa come successo pubblico.

| Momento della revoca | Settlement ammesso | Vietato dopo revoca |
|---|---|---|
| prima action entry | terminale/cleanup privato | initialize o qualunque I/O dell’action |
| draft load/reconcile/checkpoint pending | completamento dell’I/O già iniziato | fase seguente, commit/notify |
| picker/candidate/remove pending | risultato privato | nuovo hash/acquire/resolve/runtime-list update |
| upload pending | esito corrente e release lease pre-ack | prossimo upload/final request |
| final request pending | esito, ack privato se valido | nuovo finalize/clear/cleanup e success pubblico |
| clear draft pending | suo settlement | nuovo cleanup staged, rotazione, notify |
| staged cleanup pending | suo settlement | rotazione o notify |

**Scostamento deliberato dal legacy:** `_submit` oggi può proseguire upload/finalize dopo dispose e `_retireCurrentSessionInsideBoundary` può iniziare cleanup dopo il clear; questo piano revoca le fasi successive. Il delta orchestration qualifica il requisito di finalizzazione con owner live e aggiunge le race di disposal; il delta navigation non espone successo del vecchio owner. Non si assume che l’invariante fosse già implementato.

L’ack tardivo non viene persistito né trasferito a B; nessuna nuova UI del VM morto. Un success remoto già avvenuto non viene negato o annullato. Se il draft persiste, un nuovo owner ripristina identity e asset e resta idle: un successivo invio esplicito segue l’idempotenza esistente e le policy di rollout, senza promessa di exactly-once delle richieste HTTP tra processi. Se il clear era già partito, può risultare assenza del draft e cleanup degli orfani alla successiva initialize.

Per ogni Command usare il pattern ordinary già presente in Explore/Category/Favourite: mantenere vivo il Command pendente; revocare pubblicazioni del VM; listener privato su isRunningSync con flag queued/invalidated/released; barriera microtask + event turn, ricontrollo idle/reentry, detach listener e dispose una volta, fuori dispatch e dopo reporting/finally. Cleanup anche per command mai eseguito e da terminal observer; super.dispose differito fuori notifier dispatch. Nessun timer reale nei test. Il difetto upstream late throw oltre teardown 50ms è coperto mantenendo il command vivo fino al settlement, non fidandosi di global reporting dopo dispose immediato. Assertion settlement usa il calo sync-running; non si aspetta un terminal snapshot normale che upstream non garantisce.

I cinque snapshot pubblici sono cache di presentazione neutre iniziali aggiornate dai listener sincroni dei Command soltanto mentre il VM è live; aggiornare la cache prima di notify. I listener sync-running del VM fanno osservare anche la discesa dopo il terminale, necessaria a retry e canPop. Non esporre direttamente results o listenable del Command privato. Al dispose staccare tutti i listener di forwarding prima di disporre ChangeNotifier; gli snapshot restano congelati e nessuna notifica pubblica tardiva può sfuggire dal canale privato. I listener esclusivamente privati di cleanup rimangono fino al settlement. Questa è proiezione nel ChangeNotifier esistente, non un secondo framework o scheduler.

**Limite cross-owner esplicito:** `_serialize` è per VM e `clearDraft()` elimina incondizionatamente il record fixed ID 1. Un vecchio clear/save **già iniziato** può interferire con write del nuovo owner. I gate vietano nuove fasi dopo dispose, non promettono serializzazione o CAS fra VM. Risolverlo richiederebbe cambiare repository/coordinamento fuori scope. Rebinding dei consumer non implica cambiare questo contratto di storage. Non dichiarare il rischio risolto.

### D6 — Consumer, progress, route e replacement

| Consumer osservato | Stato/comportamento B0 | Proposta |
|---|---|---|
| AssetList 36–44, 91–132 | merged listenable creato una volta; add await execute e legge result; remove usa indice | ascoltare il VM, che inoltra soltanto snapshot/running live; rebind al cambio owner; invocare request methods; warning da terminale della propria admission corrente |
| AssetListItem / AddAssetButton | callback UI, Image.file, nessun Command proprio | cattura owner/session/digest/indice **durante itemBuilder**, riconvalida sincronicamente con D6.F3 prima della request; componenti e persistenza restano ai loro confini |
| Screen 44–81 | listener init/dispose ma senza didUpdateWidget; post-frame recovery | detach A/attach B, invalidare callback e reset entrambi Form keys anche con uguale client ID se owner cambia; bootstrap per owner corrente una volta |
| Screen 133–183 | validate, token, checkpoint await, unawaited execute, push | stessi gate; dopo await controllare mounted, owner identity e sessione; requestSubmit true prima push; false non naviga; controllare ancora owner dopo admission sincrona |
| Screen 204–215 | osserva VM + clear e mostra loading | osserva VM + clearSnapshot/isRunningSync proiettato; loading include clear dalla admission, nessuna falsa ready prima action |
| Progress 45–120, 131–160 | legacy Command; canPop !running&&!pending; error helpers | snapshot Result-aware + immediate isSubmitting; listenable aggiornato per owner; neutral/running/domain/runtime/completed; pending osservato anche da VM |
| Progress retry 92–96 | execute stesso submit | requestSubmit modalità finalization-only; guard mounted, owner e snapshot ancora corrente; nessuna doppia retry |
| Router 109–193 | onExit centralizzato, token e save/restore; form/progress leggono Provider | preservare route e token; dopo dialog/await verifica context mounted, owner Provider corrente e sessione prima di save/restore, feedback o true; finally release catturato |
| Provider composition | owner condiviso form/progress, initialize avviato | invariato; nessuna sostituzione DI o init aggiuntiva |
| VM canRetry 146–154 | !submit.running && result Error && pending | formula D4 sul snapshot con hasFailure e sync-running |
| Test diretti/unit/widget/route/restoration | execute await e legacy flag | request bool + pump entry/terminal; asserzioni sugli snapshot attuali, non sul value storico |

Non ci sono consumer UI di clear.execute: clear resta API usata dai test/lifecycle, mentre `Esci senza salvare` usa **restoreCheckpointDraft**, non clear. I cinque Command sono gli unici target; fields/date/description/checkbox/CTA e le primitive temporal/event non acquisiscono un Command nuovo.

#### D6.F3 — Callback di removal precedente all’admission

Il guard D2 protegge il tempo **dopo** la richiesta; non può correggere una callback che rappresentava A e viene invocata quando l’indice rappresenta B. Si mantiene la firma pubblica minima `requestRemoveAssetAt(int index)`: la View non riceve contratti di storage né cancella per digest direttamente. La protezione pre-admission appartiene a `ContentSubmissionAssetList`, che costruisce la callback di `ContentSubmissionAssetListItem`.

Durante `itemBuilder`, **fuori dalla closure onRemove**, catturare in variabili locali final `renderedOwner`, `renderedClientSubmissionId`, `renderedDigest` e `renderedIndex`. Alla successiva invocazione eseguire, senza await o notify intermedi:

1. `if (!mounted) return;` prima di qualunque accesso a `widget`/State/context;
2. richiedere `identical(widget.viewModel, renderedOwner)` e stessa session identity catturata;
3. leggere la lista corrente di **renderedOwner**, verificare bounds di renderedIndex e uguaglianza del digest in quella posizione a renderedDigest;
4. solo se tutti i controlli passano chiamare `renderedOwner.requestRemoveAssetAt(renderedIndex)`. Il request method ricattura sincronicamente target e invalidità come D1/D2; nel medesimo stack non c’è una finestra async fra guard e admission.

Se un controllo fallisce: ritorno senza chiamare il request method, senza mutare lo slot, senza cambiare snapshot/running e senza snackbar, notifica di successo/errore o repository call. Non cercare A in un’altra posizione e non usare il nuovo owner per eseguire il vecchio intento. Un indice riutilizzato per B fallisce anche se il widget non è ancora stato ricostruito; owner diversi con uguale client ID falliscono per identity dell’oggetto. Dopo admission resta la regola A8: se l’ordine cambia ancora, il VM rimuove esclusivamente il digest già catturato o fa no-op.

Un normale rebuild con **stesso owner, stessa sessione e stesso target nella stessa posizione** non invalida la callback: nessun contatore di build o invalidazione indiscriminata delle closure. Il test conserva davvero la vecchia `onRemove` dal widget item prima della mutation, poi la invoca direttamente dopo aver ottenuto `[B]`; fare tap soltanto sul nuovo widget non riproduce F3. Varianti replacement A→B e session rotation devono produrre zero chiamate a entrambi i repository; una callback valida conservata attraverso un rebuild deve rimuovere il suo target una sola volta dopo Success persistente.

Scartato un nuovo ingresso pubblico session/digest: non necessario, perché i controlli e `requestRemoveAssetAt` sono sincroni nello stesso isolate. Il consumer fa esclusivamente validazione del target rappresentato; il VM mantiene validazione richiesta, arbitratura, repository I/O e pubblicazione.

Feedback add: listener del VM installato prima dell’admission, con marker locale della selezione ammessa e riconoscimento della transizione running→terminale del suo addAssetSnapshot; il marker si consuma una volta. Un busy guard precede la creazione del marker: una richiesta ignorata non sostituisce quello dell’esecuzione in corso. Il consumer non deve conoscere il tipo privato dell’envelope. Gate mounted, owner del widget e identity ancora quella catturata o quella sigillata dal ticket; no feedback da duplicate busy/no-op stale/dispose. Nessun await runAsync poi lettura del value. Se owner o sessione cambiano nel medesimo stack della notifica, verificare nuovamente prima dello snackbar. Nomi file solo logging diagnostico già previsto.

Screen `didUpdateWidget` deve invalidare i propri boundary callback con una generazione locale e associare `_boundaryPending` alla specifica operazione; il finally di A rilascia il suo token catturato ma non può abbassare il pending della nuova operazione B. Le callback post-frame non leggono liberamente `widget.viewModel`: catturano owner/generazione, `if (!mounted) return;` prima di accedere a State/widget/context, poi guard identità. Stesso pattern per iOS explicit-pop allowance. La nuova form presentation non deve riprodurre onChanged/reset da A, neppure se B usa la stessa client identity.

La route onExit verifica il Provider attuale anche se il vecchio widget State non ha ancora eseguito il rebind; una vecchia scelta di dialogo non deve ripristinare/salvare il nuovo owner. Revoca owner non è autorizzazione a rimuovere la route di B: fail closed false e release token. Conservare Save/Discard/Cancel, policy iOS/predictive, central exit e nessun cleanup da Back/Home/New suggestion.

Progress usa `isSubmitting || snapshot.isRunning` per escludere la finestra deferred e l’ordine terminale prima della discesa runningSync. Per la presentazione success/error usare il terminale, mai il valore trattenuto. Una nuova admission soppianta la vecchia UI prima del push. `canPop` richiede non running e non pending; running/pending nascondono anche Home e altre exit action. Dopo success, form sotto progress si resetta alla nuova sessione tramite notify live, e Home/Back non duplicano clear. Dopo process restart nuovo VM idle, ritorno al form e nessuna ripresa automatica.

### D7 — Compatibilità cumulativa 1–4

| Contratto precedente | Applicazione qui | Non trasferito |
|---|---|---|
| 1 ordinary/single-flight, ottimismo/progression ammessi, no fasi dopo dispose | lane indipendenti, commit locali guardati, cleanup/reporting identici | nessun blanket completion-only o rollback inventato |
| 2 Category snapshot, owner e dialog/session binding | input immutabili e callback current-owner | nessun Restartable su asset/submit; sort policy resta propria |
| 3 Event/Post/Sync feedback, latest snapshot e immediate admission | progress e callback route da owner/snapshot attuali | nessun coordinator Home o nuove factory |
| 4 Search acceptance prima action, writer specifico, GeoMap latest intent | fissare request prima deferred e distinguere lifecycle fisico/UI | nessun obbligo Search writer che sopravvive disposal per Submission, nessun secondo FIFO |

La correzione F2 usa lo stesso arbitro senza importare la coda writer Search: la posizione della cattura è fissata all’admission, mentre draft e identity restano immediati. F1 mantiene gli esiti di dominio e il reporting ordinary; F3 aggiunge solo la validazione consumer precedente al guard VM.

Le canoniche non sincronizzate vanno lette con i delta 1–4 in ordine; questa change aggiunge requisiti feature-specific e modifica integralmente solo Durable submission attempt, Finalization-only retry, Immediate retry availability (orchestration) e Confirmed remote success (navigation), preservandone tutti gli scenari preesistenti. Non modifica il requisito ordinary generale già approvato né l’eccezione del writer Search. Nessun canonical viene scritto adesso.

## Matrice race e tabella regression

Tutti gli scenari sono **futuri test**, non esiti ottenuti nel planning. Completer gates espliciti e clock virtuale, nessun sleep/wait infinito. Ogni test che copre una race nuova deve fallire senza il relativo guard/snapshot per il motivo previsto; non limitarsi a verificare che non lanci. Le molteplicità di I/O e identità/payload sono parte dell’oracolo.

| ID | Ordine controllato / gate | Oracolo discriminante | Superficie test |
|---|---|---|---|
| A1 | due richieste stessa lane nello stesso stack, prima action | true/false, action e I/O una volta, slot originale intatto | VM, tutte 5 |
| A2 | admission → result observer dispose prima entry | zero nuovo initialize/picker/repo, cleanup 1 | lifecycle |
| A3 | submit A → setter B prima timer action | checkpoint e payload A, B dirty su failure | VM |
| A4 | request A durante initialize → restored R → clear C prima entry | nessuna adozione di C, no remoto per target stale | VM |
| A5 | loading absent con request A → edit B durante wait | payload A, B resta dirty dopo failure; load/reconcile una volta | VM |
| A6 | loading restored, edit durante reconcile | ticket conserva draft load/asset order, non gli edit arbitrari | VM |
| A7 | remove indice invalido → restore list valida | Error originale, remove=0 | VM |
| A8 | remove digest A → altra rimozione/spostamento lista | remove solo A o no-op, mai nuovo occupante | VM |
| L1 | pre-picker save pending → clear queued | solo uno dentro arbitro, save A prima clear A, nessun save A tardivo | VM |
| L2 | picker A pending → clear A→B → picker ritorna | nessun hash/acquire, nessun warning, B invariato | VM/widget |
| L3 | acquire A già dentro boundary → clear | acquire/resolve completano prima clear A, fresh B senza vecchi asset | VM |
| L4 | normal add + recovery con medesimo digest/capacity | ordine locale, dedup, massimo cinque, 10MB, staged path | VM |
| L5 | recovery response prima/dopo init/clear, tre permutazioni | solo eligible ID del ticket; absent/unknown/B zero acquire | VM Android |
| L6 | serialize throws Object/StateError → seconda mutation | errore/stack originale global=1, arbitro rilasciato, seconda entra | VM/reporting |
| L7 | standalone checkpoint/restore vs clear | nessun save identità ritirata, invarianti dirty e checkpoint | VM |
| S1 | captured A save pending → edits B → prepare success | save A, owner A prima release; remote A; B dirty su failure | VM |
| S2 | clear entra prima preparation A | clear una volta, submit terminal Error, remote=0, B invariato | VM |
| S3 | prepare già dentro boundary → queued clear | clear Error, clearDraft/cleanup=0; owner A rimane | VM |
| S4 | upload/final request pending → external clear | clear Error senza I/O; failure pre-ack rilascia lease poi clear possibile | VM |
| S5 | upload A1 pending → mutate/remove/add same session | payload membership catturato; failure mantiene edit; success ritira insieme | VM |
| S6 | primo upload Result.error / throw / assertion | niente secondo upload/final request, lease rilasciato; tipo/report corretto | VM/lifecycle |
| S7 | checkpoint Result.error / raw throw | zero remoto, error identity/stack corretti, lease non stranded | VM |
| S8 | final request Result.error, malformed ack, throw Object | no finalize; stesso ID/assets; global solo raw, clear successivo possibile | VM/repository existing |
| S9 | ack success → draft clear Error ripetuto → retry success | submit=1, upload=N una sola passata, checkpoint=1 o skip known durable, retry solo clear, rotate=1 | VM/progress |
| S10 | ack → finalize raw throw | runtime terminal + global=1; pending resta; retry locale senza resend | VM/progress |
| S11 | ack A ma identity/owner mismatch | clear=0/cleanup=0/rotation=0, pending non cancellato | VM |
| S12 | ack → staged cleanup Result.error | best-effort contract preservato, no nuova doppia retire o backend retry | VM |
| P1 | requestSubmit true → push prima action timer | progress running immediato, no Back/Home né idle-interrotto | widget/route |
| P2 | retry admission prima action | old error scompare, retry disabilitato; doppio tap no altro clear | progress |
| P3 | neutral / Success<void>(null) / domain / runtime / pending | stati distinti e policy retry/back esatta, no success da null | progress |
| P4 | validazione/temporal failure / checkpoint Error | zero request/push per failure, snackbar invariato | screen |
| P5 | submit/external boundary pending vs AppBar/system/predictive/go | vincitore token esclude concorrente; finally rilascia su failure/cancel | route |
| P6 | restore process su progress con VM nuovo | idle, no auto-submit/clear/retry; Back draft stesso ID/staged | restoration |
| P7 | success sotto form poi Back/New/Home | fresh empty clean, nessun onChanged stale, clear e rotate una volta | screen/route |
| P8 | raw checkpoint/restore in submit/link/onExit, live o dopo replacement/dispose | FlutterError originale una volta, no nuovo submit/launch/push/exit, release token, no stale feedback; assertion fail-loud | screen/route |
| B1 | State retained A→B stessi ID e ID diversi | vecchi listener staccati, nuovi rebuild, form keys sostituite, A notify inefficace | screen/asset/progress |
| B2 | picker warning A pending → B → terminal A | snackbar=0 per A, nessun effetto su B | asset |
| B3 | post-frame recovery A → replacement B/unmount prima callback | A retrieve=0, B bootstrap=1 se mounted; nessun State.widget post-unmount | screen |
| B4 | checkpoint/dialog A pending → Provider B prima rebind | niente old submit/launch/exit, B non mutato; token rilasciato | screen/route |
| B5 | finally A dopo avvio boundary B | pending/generazione B non azzerati da A | screen |
| D1 | dispose in ogni punto tabella D5 | settle solo fase avviata, zero successive, zero notify/public feedback | VM/lifecycle |
| D2 | late Success/Result.error/StateError/ArgumentError/Object oltre 50ms virtuali | raw global=1 originale, domain global=0, cleanup ogni lane=1 | lifecycle |
| D3 | terminal snapshot/VM listener dispone o nuova admission durante barriera | no double dispose, barriera invalidata se torna busy | lifecycle |
| D4 | assertion dopo owner dispose | zone vede assertion originale, non Error dominio; cleanup settled=1 | lifecycle |
| D5 | ack tardivo dopo dispose prima clear | final request=1, clear/cleanup=0, no success/notify | VM |
| D6 | dispose durante clear già fisicamente pending | clear può finire, cleanup nuovo=0, rotate/notify=0 | VM |


| E1 | repository remove lancia Exception diretta live | unexpectedError stessa istanza/stack, domainError null, global=1, asset invariato; checkpoint indipendente entra | VM/reporting |
| E2 | remove pending → dispose → Exception oltre 50ms | stesso raw/report privato una volta, nessun snapshot/notify pubblico, cleanup una volta | lifecycle |
| E3 | upload/final submit raw o assertion → release lease | primario/stack non mascherati, release matching senza storage, clear successivo possibile; verifica ramo secondario D5.F1 | VM/lifecycle |
| E4 | action Loading → initialize load/reconcile AssertionError | assertion originale fail-loud, nessun Error sintetico né I/O successivo, ticket assestato e cleanup privato una volta | VM/lifecycle |
| S13 | commit X già registrato e pending → submit → X Success | P,Q,X sigillati in ordine, 3 upload/1 submit con D0/I; nessuna cattura incompleta | VM |
| S14 | submit registra cattura → commit Y successivo → action deferred | P,Q soltanto, 2 upload/1 submit con D0/I; Y resta su failure, ritirato insieme su success | VM |
| S15 | acquire X precedente Error prima commit → cattura | P,Q soltanto, add Error indipendente, 2 upload/1 submit D0/I | VM |
| S16 | acquire X Success → resolve Error precedente cattura | staged unavailable, submit domain failure; checkpoint/upload/submit nuovi=0 | VM |
| S17 | X pending → submit → clear già in coda dietro cattura → X completa | clear ruota I→J prima prepare; submit Error, zero remoto, nessun vecchio checkpoint su J | VM |
| S18 | X pending → submit Ready → dispose → X settle | sola acquire già iniziata; zero nuova resolve/prepare/upload/submit, cattura drained, zero notify tardivi | VM/lifecycle |
| S19 | remove P precedente pending → submit → remove Success | solo Q, 1 upload/1 submit D0/I, nessuna riesumazione P | VM |
| S20 | submit Loading → ticket P,Q → mutation post-ticket | membership del ticket P,Q e draft D2; nessun await init prenotato dentro arbitro, no deadlock alla revoca | VM |
| S21 | batch precedente committa X poi acquire Z Error | prefisso P,Q,X preservato, Z escluso; add Error e submit indipendenti, 3 upload/1 submit | VM |
| B6 | conserva onRemove(A,0) → lista [B] → invoca vecchia closure | zero admission/remove repo, B invariato, snapshot/running identici e zero feedback | asset widget |
| B7 | vecchia onRemove A → owner B, anche stesso ID → invoca | zero chiamate su entrambi i VM/repository, nessun effetto su B | asset widget |
| B8 | conserva callback valida → rebuild ordinario → invoca | admission=1, repo remove=1 sul digest catturato, Success elimina solo target | asset widget |
| B9 | vecchia callback → stesso owner ma sessione I→J | zero admission/repository/notify per J, nessuna rimozione del sostituto | asset widget |

Estendere suite esistenti, non riscriverle svuotando asserzioni: VM ha già gruppi remove (1763+), disposal (2060+), recovery (2272+), submit (3378+), ownership/race (3979+), clear (4526+). Widget asset/progress/screen, route/restoration esistono e mantengono gli scenari di validation, date, session-sync e best-effort recovery. A1/A3/A4/B1/B4/D5 sono discriminanti nuovi prioritari. La coverage osservata include i test di snapshot payload/asset durante il gap Cloudinary (VM 3740+), single-flight della transizione prima del push (screen 453–523), ownership/clear (VM 3979–4183), e la prima emissione canonical clean del retirement sotto real progress (route 427–521). Sono evidenze di test esistenti, non nuovi esiti eseguiti. La sostituzione del VM sulla medesima State è un nuovo requisito esplicito di robustezza: l’attuale Provider è app-scoped e restoration ricostruisce l’albero, quindi il gap non è spacciato per una regressione già dimostrata in produzione.

### Oracoli completi F2 — S13–S21

Fixture comune per le righe Ready: sessione **I**, draft valido **D0** della richiesta, lista ordinata `[P,Q]`; D0 è già durevole oppure viene reso durevole dal checkpoint anteriore H specificato per S14, path distinti, upload fake sempre Success. Dopo admission si può editare lo stesso draft in **D1** per provare che il payload resta D0. Per S13/S14/S15/S19/S21 la final request controllata ritorna il medesimo **Error(remoteRejected)**: questo permette di osservare membership live e stessa identity dopo failure senza confondere il test con retirement. Ogni riga verifica anche numero checkpoint di preparazione = 0 se D0 è già noto durevole, nessuna retry automatica e remote identity I. Un test dirty ripete S13 con D0 non ancora durevole e save controllata: checkpoint esattamente D0 una volta prima degli upload, non D1.

| ID | Future e ordine fisico da controllare | Membership/payload e conteggi remoti | Draft, identity, terminali e notifiche |
|---|---|---|---|
| S13 | X è dentro commit: acquire o resolve sospeso. `requestSubmit` registra cattura; solo dopo completare X e drenare boundary/action | `[P,Q,X]`; upload P→Q→X, Cloudinary=3, final submit=1 | remoto D0/I; locale D1/I su remoteRejected; add Success, submit Error(remoteRejected), global=0. Pubblicazione X prima release e notify live ammessi; vietato mostrare submit success o inviare D1/lista senza X. |
| S14 | ammettere submit (cattura registrata), poi registrare commit Y. Fare entrare Y **prima** della preparazione ritardando il consumo della cattura con clock virtuale e gates su fasi già esistenti; non introdurre seam di ordering produttiva | `[P,Q]`; upload P→Q, Cloudinary=2, submit=1 anche se runtime list è `[P,Q,Y]` all’ingresso di prepare | D0/I remoto, D1/I e Y persistono dopo Error(remoteRejected); add Success. Solo notify live delle proprie esecuzioni; nessun payload Y o false success. Variante final Success: stessi conteggi/payload, retirement una volta I→J clean, Y ritirato senza trasferimento come ogni mutation tardiva della stessa sessione. |
| S15 | acquire X già dentro commit risolve Error(acquireFailure), senza descriptor/runtime commit; solo poi cattura | `[P,Q]`; P→Q, Cloudinary=2, submit=1 | add Error(acquireFailure), submit Error(remoteRejected), entrambi oggetti distinti preservati; D0/I remoto, D1/I locale; global=0. Error add/terminale submit live ammessi, niente notify di X o importazione della failure add nel submit. |
| S16 | acquire X Success, resolve pending poi Error(resolveFailure); la cattura segue il release | nessun payload; Cloudinary=0, submit=0, checkpoint preparazione=0 | D0/I mai inviato; stessa I/D1, staged unavailable e lista non completa non adottata; add Error e submit Error(staged unavailable), global=0. Stato unavailable/terminali live ammessi, vietati successo submit, restore inventato o cleanup distruttivo. |
| S17 | X pending; submit registra cattura; avviare clear e farne registrare `_serialize` mentre X resta bloccato. Completare X: ordine tail X→cattura→clear→prepare | cattura può contenere `[P,Q,X]`, ma **nessun payload**; Cloudinary=0, submit=0, checkpoint vecchio I=0 | clear Success I→J una volta; submit domain stale, no global; draft J clean invariato e nessun checkpoint D0 su J. Notify live di X/rotation e terminale stale ammessi; nessun successo submit per I/J. |
| S18 | acquire X già iniziata, submit Ready ammesso dietro X; dispose prima di completare acquire. Avanzare oltre 50ms virtuali, poi completare con Success | nessun payload, Cloudinary=0, submit=0, nuova resolve=0, prepare/checkpoint=0; la sola acquire può essere durevole | snapshot pubblici congelati alla revoca (possono restare running), nessun terminale UI di successo/errore da lavoro revocato; I e draft dell’owner morto non ruotano. Command/cattura si assestano privatamente e cleanup una volta; zero notify/list changes dopo dispose e nessun zone error. |
| S19 | remove P è già pending dentro `_serialize`; submit ammesso; remove ritorna Success prima del release | `[Q]`; upload Q, Cloudinary=1, submit=1 | remoto D0/I e locale D1/I; remove Success, submit Error(remoteRejected), global=0; update membership/notify live consentiti, P non rimosso due volte né reinserito nel payload. |
| S20 | load/reconcile pending: submit lega ticket; sigillare restored `[P,Q]` e draft persistito **DR** prima notify. Mutare D1 e aggiungere Y solo dopo il ticket. Variante absent: draft provvisorio **D0** della richiesta, lista ticket vuota | restored: P→Q, Cloudinary=2, submit=1 con DR/I; absent: zero upload, submit=1 con D0/provisional I. Y sempre escluso | submit Error(remoteRejected) mantiene live D1 e stessa I; load/reconcile una volta, nessuna cattura Ready o doppia initialize. Notify ready/asset/terminali live consentiti, nessuna adozione dei valori D1. Variante dispose prima action: initialize nuovo=0 e zero I/O/catture bloccate. |
| S21 | un unico batch commit ha già pubblicato X, poi acquire Z pending; ammettere submit, risolvere Z con Error senza rendere unavailable la lista già committata | `[P,Q,X]`; P→Q→X, Cloudinary=3, submit=1; Z zero upload | add Error(acquireFailureZ), submit Error(remoteRejected) indipendente; remoto D0/I, locale D1/I con X; global=0. Pubblicazioni live del prefisso ammesse, niente rollback X, inventata presenza Z o add Success. |

Per S14 la variante discriminante parte con il picker Y **già aperto** (pre-picker concluso), ma senza alcun commit Y registrato: il tap precedente non è ancora una mutation anteriore nell’arbitro. Editare D0 e tenere un checkpoint indipendente H che sta salvando proprio D0 già dentro `_serialize`; ammettere submit (cattura in coda), poi far ritornare il picker Y e registrarne il commit dietro la cattura mentre la action submit è ancora deferred. Con `pumpCommandTurns` controllare il rilascio del checkpoint e le microtask: il commit Y già accodato viene eseguito prima della prepare che la action registra **solo dopo** aver consumato il Future di cattura. Registrare dal fake l’ingresso di acquire/resolve Y e il primo upload P, verificando Y pubblicato prima di prepare/remote senza cambiare il codice per controllare il clock. Se la action parte prima, il suo await dell’esito della cattura lascia comunque Y già accodato davanti alla successiva prepare. H scrive D0 una volta come checkpoint indipendente, la preparazione lo riconosce ormai durevole e non risalva; D1 editato dopo la richiesta non viene checkpointato. Il test deve osservare questi gate, non affidarsi a un tempo di sleep. Una seconda variante ammette anche `requestAddAsset` di Y dopo `requestSubmit` prima delle action deferred: Y resta escluso indipendentemente dal fatto che il suo commit arrivi prima o dopo prepare. La discriminazione del caso Y già pubblicato prima di prepare è data dalla prima variante, senza fingere che il pre-picker di un add nuovo possa saltare l’arbitro.

I conteggi si riferiscono alle chiamate `uploadImageTask` osservate dal repository fake e alla singola `ContentSubmissionRepository.submit`, non ai retry HTTP interni Cloudinary. Le notifiche vive possono variare di numero per il forwarding degli stati Command: l’oracolo è l’identità e il contenuto di ogni snapshot ammesso e l’assenza assoluta di notifiche **dopo** revoca, non un totale accidentale di rebuild. E1–E4/B6–B9 aggiungono gli oracoli di reporting e pre-admission descritti in D5.F1 e D6.F3.

Supporti da riusare: `test/support/{fake_repositories,fake_image_picker,test_image_files,fixtures,command_test_support,ordinary_view_model_lifecycle_support,route_ownership_fixture,predictive_back}.dart`. Estendere con hook Completer/contatori solo dove mancanti; nessun mock Command legacy aggiuntivo né duplicazione di classi controllabili già esistenti. `testOwnerUI` e `pumpCommandTurns` gestiscono cleanup e teardown 50ms virtuale; unit test attendono snapshot/entry espliciti, non busy loop su microtask che non lascia partire `Duration.zero`. Prima degli edit test caricare skill test-support-reuse + unit/widget/integration se applicabili; ObjectBox test-store soltanto se si cambia un test data (non previsto).

## Manifest previsto del futuro apply

| Classe | File ammessi / esito |
|---|---|
| Produzione obbligatoria | `lib/ui/content_submission/view_models/content_submission_view_model.dart`; `lib/ui/content_submission/widgets/content_submission_{screen,progress_screen,asset_list}.dart` |
| Produzione routing circoscritta | `lib/routing/router.dart` soltanto callback Content Submission per guard owner/session/mounted dopo await; nessun refactor generale |
| Test da adattare/estendere | `test/integration/all_day_pipeline_test.dart` (consumer diretto censito nel gate integrato); `test/ui/content_submission/view_models/content_submission_view_model_test.dart`; `test/ui/content_submission/widgets/content_submission_{screen,progress_screen,asset_list}_test.dart`; `test/routing/content_submission_{route,restoration}_test.dart`; `test/ui/ordinary_view_model_lifecycle_test.dart` |
| Supporti se necessari | `test/support/{fake_repositories,fake_image_picker,ordinary_view_model_lifecycle_support,command_test_support,route_ownership_fixture}.dart`, riuso prima di estensione; eventuale nuovo `content_submission_command_harness.dart` solo se tre usi concreti non coperti dai supporti esistenti |
| Test invariati ma regression gate | restanti widget Content Submission; foundation test/utils quattro suite; repository draft/staged/submission; Cloudinary upload client; domain draft/staged e mapper |
| Artifact presenti | `.openspec.yaml`, `proposal.md`, `design.md`, `tasks.md`, quattro `specs/*/spec.md` in questa change |
| Esclusi | lib/utils foundation/legacy, repository/domain/entity/mappers/generati, dependencies/config/lock, Supabase/SQL/Edge, Admin, canonical, altre change |

Nessun bisogno di build_runner o schema migration. Se un vincolo futuro richiede una superficie esclusa, fermare quel task e presentare la contraddizione, non estendere il perimetro silenziosamente. Il router è incluso già nel manifest per i callback realmente auditati; non è una licenza per modificare altre route.

## Criteri analyzer B0/B1 e gate di verifica

In apply rigenerare B0 prima degli edit e B1 sul diff finale con **stesso SDK, dipendenze, argv/flag/default, root mapping e procedura**. Ledger = Counter di severity/tipo/codice/path relativo/colonna/lunghezza/messaggio più contesto del simbolo e molteplicità. La linea fa parte della prova B0, ma in B1 uno spostamento richiede mapping documentato allo stesso riferimento; non si elimina tutta l’informazione di posizione per fare tornare il conto. Per nuove source o supporti controllare tutte le diagnostiche, non solo il codice deprecation.

Acceptance: B0 **66/0/0**, B1 atteso **52 INFO/0 WARNING/0 ERROR**, eliminate esattamente le 14 identità target. Le 52 non-target restano con medesime identità e molteplicità, anche i tre dartdoc legacy di fake_repositories; non correggerli opportunisticamente. Zero nuovi codici/info/warning/errori. Non usare ignores, esclusioni o lint changes. Se saldo=52 ma c’è un missing non-target o una nuova diagnostica, gate fallito. Registrare sempre returncode grezzo e stderr separati dai conteggi. Se si esegue anche flutter analyze, registrarne separatamente l’eventuale exit non-zero per INFO.

Gate mirati futuri (comandi da questo worktree; preparare soltanto metadata/runtime ignorati con procedura già adottata, nessun upgrade):

```sh
flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart
flutter test --no-pub test/ui/content_submission/widgets test/routing/content_submission_route_test.dart test/routing/content_submission_restoration_test.dart
flutter test --no-pub test/ui/ordinary_view_model_lifecycle_test.dart test/utils/result_command_test.dart test/utils/restartable_command_test.dart test/utils/command_configuration_test.dart test/utils/command_it_disposal_behavior_test.dart
flutter test --no-pub test/data/repositories/content_submission_draft_repository_impl_test.dart test/data/repositories/content_submission_staged_asset_repository_impl_test.dart test/data/repositories/content_submission_repository_impl_test.dart test/data/services/api/cloudinary/cloudinary_upload_client_impl_test.dart
flutter test --no-pub
openspec validate migrate-content-submission-commands --strict
```

Piccoli gate prima della suite completa. Registrare pass/fail/skip reali; gli skip upstream noti non sono nuovi test passati. La suite completa è richiesta prima di readiness implementation. Backend invariant audit è read-only, non si dichiara esecuzione DB/Edge durante planning o apply senza averla fatta. Formatter solo file Dart intenzionali; diff/whitespace e manifest includono untracked. Nessun test Flutter eseguito in questo planning.

## Risks / Trade-offs

- [Snapshot request-time vs mutation anteriore] → draft request-time, cattura membership ordinata nello stesso tail e ticket initialization; test A3–A8/S13–S20; differenza dal legacy esplicita, non equivalenza dichiarata.
- [Raw throw oggi convertito da serialize] → boundary expected stretti, release finally sempre, reporting type/identity/stack e test di arbitro non avvelenato; nessun blanket catch.
- [Owner revocato durante notify sincrono] → guard prima di ogni fase, non solo dopo await, cleanup fuori dispatch.
- [Fixed draft e I/O cross-owner già in corso] → limite esplicito D5; nessuna promessa di atomicità cross-owner. Non è introdotto né risolto dalla migrazione.
- [Future fisica mai terminante] → risorse private possono restare trattenute indefinitamente; nessun timeout/cancellation inventato. UI disposed non riceve feedback.
- [Process kill perde ack e stato Command] → draft/asset durabili e stable identity restano i primitive di recovery; nessun background submit, persistent ack o immediate retry remoto nuovo.
- [Cleanup staged Result.error best-effort] → preservato il limite canonical; nessuna garanzia di propagazione totale o rollback Cloudinary. Orphan reconciliation esistente resta il recupero.
- [Assertion fail-loud] → non promettere failure UI terminale o reporting normale, ma cleanup privato settled verificato.
- [Baseline analyzer ancora non pulita] → residui Admin e dartdoc legacy riservati alle change successive; 52 è obiettivo futuro, non risultato del planning.

## Migration Plan

Questa fase consegna esclusivamente otto artifact. Review indipendente del piano e autorizzazione apply separata. Futuro apply in questo worktree: preflight/checkpoint e B0 → test discriminanti → VM e lifecycle → consumer/routing → gate mirati → analyzer B1/suite completa/strict/manifest. Ogni task ha acceptance in tasks.md e resta unchecked.

Nessun deploy, migrazione dati o sincronizzazione canonical è necessario. Nessun commit/push/PR update/merge autorizzato da questo piano. Un eventuale rollback futuro riguarda soltanto il diff coeso dell’apply dopo preservazione del lavoro altrui, mai reset/rebase distruttivi. La PR resta cumulativa Draft 4/7 fino alla successiva pubblicazione autorizzata; completamento del planning non è checkpoint implementato 5/7.

## Verifica documentale del planning

Gli esiti strict/status, controllo requisiti/scenari, integrità checkout e manifest finale vengono registrati nella consegna e nel blocco finale sotto. Non sono sostituiti da risultati storici delle change precedenti. La verifica corrente di coerenza F1–F3 e il suo verdetto sono nel blocco finale della remediation. Il limite cross-owner e i confini di disposal restano deliberati, non una garanzia assoluta rinviata.

## Appendice — ledger B0 completo e molteplicità

Ogni riga sotto identifica severity INFO, tipo LINT e codice DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE. Messaggio comune esatto, con SYMBOL sostituito dal simbolo della riga:

```text
'SYMBOL' is deprecated and shouldn't be used. Legacy compatibility command. Do not use in new code. Use createResultCommand/createResultCommandNoParam for ordinary single-flight actions, or RestartableCommand when newer intent must supersede older work.
```

Posizione = linea:colonna:lunghezza. Le due righe nello stesso punto con lunghezza diversa sono identità distinte, non duplicati da deduplicare. Target = T; non-target = N. Contatore complessivo: 66, target 14, non-target 52.

| Path | Posizione | Simbolo | Conteggio | Gruppo |
|---|---|---|---|---|
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 23:13:37 | Command1 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 23:13:8 | Command1 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 24:14:14 | Command0 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 24:14:8 | Command0 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 39:8:8 | Command1 | 1 | N |
| `lib/ui/admin/auth/view_models/admin_auth_view_model.dart` | 42:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 43:12:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 43:12:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 44:12:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 44:12:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 45:14:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 45:14:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 46:15:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 46:15:56 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 49:12:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 49:12:35 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 50:15:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 50:15:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 51:22:22 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 51:22:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 52:13:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 52:13:30 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 53:19:36 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 53:19:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 54:16:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 54:16:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 55:19:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 55:19:19 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 88:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 91:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 94:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 97:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 100:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 103:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 108:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 113:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 149:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 152:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart` | 155:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 17:12:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 17:12:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 18:19:14 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 18:19:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 19:16:35 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 19:16:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 33:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 36:8:8 | Command1 | 1 | N |
| `lib/ui/admin/submissions/view_models/admin_submissions_view_model.dart` | 51:8:8 | Command0 | 1 | N |
| `lib/ui/admin/submissions/widgets/admin_submission_editor_screen.dart` | 99:35:7 | Command | 1 | N |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 99:16:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 100:21:8 | Command1 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 101:14:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 102:13:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 103:26:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 189:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 191:8:8 | Command1 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 192:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 195:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/view_models/content_submission_view_model.dart` | 201:8:8 | Command0 | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 16:24:7 | Command | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 131:46:7 | Command | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 139:5:7 | Command | 1 | T |
| `lib/ui/content_submission/widgets/content_submission_progress_screen.dart` | 154:21:7 | Command | 1 | T |
| `test/support/fake_repositories.dart` | 43:51:7 | Command | 1 | N |
| `test/support/fake_repositories.dart` | 656:17:7 | Command | 1 | N |
| `test/support/fake_repositories.dart` | 1165:13:7 | Command | 1 | N |

## Planning iniziale — esiti storici prima della review F1–F3

Risultati storici del planning iniziale, prima della review indipendente che ha trovato F1–F3; il verdetto corrente è nella chiusura remediation in fondo. Nessun apply era stato eseguito. OpenSpec CLI **1.14.3**: `openspec validate migrate-content-submission-commands --strict` eseguito con exit **0**, change **valid**, nessun warning; status **4/4 gruppi artifact complete**, che indica esistenza degli artifact e non implementazione. **32 task implementativi, 0 completati**. Otto file nel manifest, quattro capability esistenti, **62 scenari normativi** e **46 righe di matrice regression**. Non sono risultati di test eseguiti.

Controlli documentali eseguiti: corrispondenza capability/delta, preservazione dei titoli di tutti gli scenari canonical nei quattro requirement MODIFIED, scenari WHEN/THEN per ogni requirement, assenza placeholder e symlink, path confinati alla change, newline finale/assenza trailing whitespace in tutti gli otto untracked. `git diff --check` exit **0**; controllo separato degli untracked riuscito. Ledger B0 e comparazione storica come documentati sopra; **nessun Flutter test eseguito** e nessun risultato B1 prodotto in questo planning.

Preflight finale: PR #12 riconfermata **open/Draft**, HEAD esattamente `f48a08946c9ac40146104a0157556243ad433c92`, base `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. Checks dell’HEAD letti: [run 39964646512](https://github.com/xmattjus/moliseis/actions/runs/39964646512) completed/failure, job Autonomous Flutter tests success e Flutter analyze failure; CodeRabbit status success. Questi sono stati CI, non nuovi test locali né una nuova riconciliazione del log CI analyzer; non si deduce il numero di diagnostiche CI dal solo job failure.

Il nuovo worktree conserva branch `codex/plan-migrate-content-submission-commands` e HEAD iniziale; nessuna differenza tracked o staged, soltanto `?? openspec/changes/migrate-content-submission-commands/` (otto file). Verifica finale dei sei checkout preesistenti: **6/6** con identici HEAD/branch, status inclusi untracked e contenuto stage entries rispetto allo snapshot iniziale; nessun mismatch. Nessun source/test/config/dependency/canonical modificato, nessun commit/push/PR update/sync/archive/merge.

Verdetto storico prima della review: **READY FOR INDEPENDENT PLAN REVIEW**, successivamente superato dai finding F1–F3; non è il verdetto della remediation corrente. Restano deliberati i limiti di I/O già avviato cross-owner, Future non terminanti, ack runtime-only/process loss, assertion fail-loud e cleanup staged best-effort. Questa valutazione non sostituisce la review indipendente e non autorizza l’apply.

## Remediation documentale F1–F3 — decisioni e verifica corrente

La review indipendente iniziale ha rilevato i finding F1 e F2 alti/blocker e F3 medio. Il precedente verdetto di planning è storico. Questa remediation è **solo documentale**: nessun test o produzione modificato, nessun apply avviato e nessun esito dei futuri regression test rivendicato.

### Preflight e manifest della remediation

Riutilizzato il worktree persistente e il branch esistenti, HEAD esattamente `f48a08946c9ac40146104a0157556243ad433c92`, index e diff tracked vuoti. Prima degli edit verificati esattamente gli otto artifact untracked; contenuti e SHA-256 iniziali acquisiti come confronto della remediation. PR #12 letta soltanto, ancora open/Draft sulla stessa HEAD e base main `ee60777c7fdfc5c16daa1151050c134fbb7cde29`. Gli altri sei checkout sono stati verificati clean e inventariati per HEAD/branch/status inclusi untracked/stage entries, senza mutation o cambio branch.

Manifest esatto modificato rispetto agli otto file iniziali, sempre sotto `openspec/changes/migrate-content-submission-commands/`:

- `design.md`;
- `tasks.md`;
- `specs/command-execution-concurrency/spec.md`;
- `specs/content-submission-local-asset-staging/spec.md`;
- `specs/content-submission-submit-orchestration/spec.md`.

`.openspec.yaml`, `proposal.md` e il delta `content-submission-navigation-lifecycle/spec.md` restano byte-identici. Non servono una capability nuova, un artifact nuovo o una firma pubblica diversa: la proposal già richiede request immutabili e unico arbitro, e il delta navigation resta coerente con i confini corretti. F2 precisa il punto di cattura senza promettere equivalenza legacy; la API rimane quella proposta. Nessun intervento su altre change/canonical/backend/repository/foundation/dependency.

### Esito dei finding e coerenza D1–D7

| Finding | Decisione documentata e acceptance futura | Artifact coinvolti |
|---|---|---|
| F1 | D5.F1 inventaria ogni catch/helper e i boundary esterni, distingue Result operativi e raw repository (anche Exception), elimina il catch generale remove, definisce provenance file/plugin, oggetto/stack/report una volta, release in finally e precedenza primaria/cleanup. E1 live, E2 late-dispose, E3 release e E4 assertion bootstrap hanno oracoli espliciti. | design, task 2.4/3.4/4.2/4.5/5.3 e delta concurrency |
| F2 | D2.F2 registra la cattura Ready nel tail alla richiesta, sigilla dopo i predecessor e prima delle registrazioni posteriori; draft/issue/identity restano immediati. Loading usa il ticket, finalization-only non cattura asset. S13–S21 specificano gate, payload/ordine/conteggi, failure di acquire vs resolve, prefisso parziale, rotation e dispose. | design D1–D4, task 2.2/4.1/4.5/5.1/5.3 e delta orchestration/concurrency |
| F3 | D6.F3 conserva la firma requestRemoveAssetAt; callback catturata nel rendering e guard sincrona mounted/owner/session/index/digest prima della request. B6–B9 provano callback obsoleta, replacement, rebuild valido e rotation senza persistenza nella View. | design, task 6.1/6.6 e delta staging |

Controllo incrociato effettuato: cinque Command ancora ordinary e privati; niente reinterpretazione verso owner/sessione successivi; admission non significa successo; `_serialize` resta l’unico tail di lifecycle; runtime e domain failure restano distinti; pending acknowledgement non consente resend in finalization-only; dispose vieta nuove fasi e pubblicazione obsoleta, ma mantiene settlement privato. Progress/Back/restoration/recovery e i contratti esterni approvati restano quelli del piano. Le modifiche normative sono esplicite e compatibili con i canonical e i delta precedenti; nessuna loro sincronizzazione eseguita.

### Controlli eseguiti nella remediation

- `openspec validate migrate-content-submission-commands --strict`: **valid**, exit **0**, nessun warning. Il completamento degli artifact non è completamento implementativo.
- **32 task originali, tutti unchecked**, con identiche numerazioni e nessun task rimosso o segnato come fatto.
- Matrice: **63 ID univoci** = tutti i **46 ID originali nello stesso ordine**, più **E1–E4, S13–S21, B6–B9** (17 nuovi). I dettagli tabellari di S13–S21 non sono conteggiati di nuovo. Delta: **79 scenari normativi** = 62 titoli precedenti preservati + 17 nuovi; nessuno scenario canonical MODIFIED perduto.
- Controllati preservazione di requirement/scenari preesistenti e canonical, match capability/delta, formato WHEN/THEN, assenza symlink/placeholder, confinamento dei path e manifest di otto file. `.openspec.yaml` invariato, nessun nuovo artifact.
- `git diff --check` e controllo whitespace/newline separato di tutti gli untracked: passati; diff rispetto alle copie pre-remediation limitato ai cinque file elencati.
- HEAD/branch/index/diff tracked e altri sei checkout riconfermati invariati rispetto al preflight; nessun commit, push, update PR, reset/rebase/checkout distruttivo, sync, archive o merge.
- Baseline analyzer **storica documentata** invariata: **66 INFO, 14 target**, attese **52 INFO** dopo futuro apply, zero nuove diagnostiche. **Nessun analyzer o Flutter test rieseguito** in questa remediation.

F1–F3 chiusi a livello di planning; nessuna decisione materiale rinviata all’executor. **READY FOR INDEPENDENT PLAN RE-REVIEW**. La re-review indipendente del piano corretto e l’autorizzazione all’implementazione restano due passaggi successivi separati. Limiti deliberati del piano (I/O cross-owner già partito, Future non terminante, ack runtime-only e cleanup staged best-effort) invariati e non dichiarati risolti.


## Evidenze apply — esecuzione autorizzata

L’utente ha autorizzato l’apply del piano locale dopo due review indipendenti; non ha autorizzato pubblicazione. Le sezioni storiche di planning/remediation sopra conservano la propria provenienza temporale. HEAD resta `f48a08946c9ac40146104a0157556243ad433c92`, branch `codex/plan-migrate-content-submission-commands`, worktree previsto. Preflight: index vuoto, zero modifiche tracked, esattamente gli otto artifact untracked approvati. PR #12 riconfermata aperta e Draft, HEAD identico alla baseline; sei altri checkout con HEAD/branch/index/status invariati.

B0 nuovamente eseguita su archivio Git pulito `/private/tmp/content-submission-apply-evidence/baseline`, con il medesimo Dart diretto 3.13.4 e package_config risolto senza pub get. Argv: `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/content-submission-apply-evidence/baseline`; cwd worktree autorizzato; exit 0; stderr vuoto; 66 INFO/0 WARNING/0 ERROR. Counter completo confrontato con le 66 righe del ledger durevole sopra: missing=0, added=0; 14 target e 52 non-target identiche, comprese molteplicità e posizioni. Log/metadata in `/private/tmp/content-submission-apply-evidence/B0.{stdout,stderr,json}`.

Caratterizzazione iniziale: suite VM esistente 132 pass, zero failure/skip, exit 0; suite widget Content Submission + route/restoration esistente 134 pass, zero failure/skip, exit 0. Il primo tentativo VM ha rilevato il runtime nativo ObjectBox assente nel nuovo checkout: copiato soltanto `lib/libobjectbox.dylib` ignorato dal precedente worktree, quindi ripetuta la suite con esito positivo. Il wrapper Flutter richiede accesso alla cache SDK esterna al sandbox; esecuzione autorizzata con escalation, nessuna modifica alle dipendenze tracked.

Prove rosse consumer: B6 conserva davvero la vecchia onRemove(A,0), rimuove A e invoca la closure quando resta B; baseline effettua una seconda chiamata repository anziché zero. B1 conserva State e sostituisce il VM: B contiene un asset ma la lista non si aggiorna. Due failure comportamentali attese, exit 1, senza errori di compilazione nel run probante (`baseline-consumer-red.log`).

Gate 1.4 completato prima di qualsiasi edit produzione. VM discriminanti sulla baseline: A3 invia Draft B invece di A; D5 avvia clear dopo disposal; E1 normalizza il raw remove e non lo riporta globalmente; S14 include Y posteriore. Quattro failure comportamentali attese e S13 pass, exit 1 (`gate1-discriminating-baseline.log`). A7 e S13 preservano comportamento legacy già corretto, come D2 documenta: non sono dichiarati falsamente rossi sulla baseline. Per provarne la discriminazione “senza correzione”, in una copia temporanea isolata sono stati rimossi i rispettivi invarianti: A7 con attesa initialize prima della validazione fallisce su completedBeforeRestoration; S13 con membership priva dell’ultimo asset fallisce sul payload P,Q anziché P,Q,X. Entrambe exit 1, nessun errore harness/compilazione; log `gate1-{a7,s13}-mutation.log`. Nessuna mutation è stata applicata al source autorizzato. B1/B6 completano i discriminanti consumer. Foundation/lifecycle iniziale: 219 pass, 3 skip effettivi, zero failure, exit 0 (`baseline-foundation.log`).


Gruppo 2 verificato: cinque NoParam privati, request bool/snapshot/running pubblici; envelope Ready e ticket Loading sigillato con draft/asset/error originali; remove indice/digest request-time; `_serialize` finally senza normalizzazione; forwarding revocato e cleanup ordinary minimo necessario a E2. Questo prerequisito di cleanup è incluso nel gruppo 2 perché il task 2.4 richiede E2; il gruppo 5 resta responsabile della matrice completa delle fasi e dei casi lifecycle.

Gate finale gruppo 2: `flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --name 'OpenSpec 5 gates (A|E|L|S)|initialization|initializ|unknown|quarantin|invalid early removal|removal queued behind|checkpoint ordered' --reporter expanded`, cwd worktree; **42 pass / 0 failure / 0 skip, exit 0**. Metadata esatti `group2-gate.json`, log `group2-combined.log`. Include A1 per cinque lane, A2 con turni realmente drenati, A3–A8, L6/L7, E1/E2 e 14 test F2 S13–S21 con varianti dirty D0, S14 success/failure e nuova admission Y dopo submit, Loading restored/absent/dispose e prefisso parziale X. Verificati payload/ordine, contatori upload/submit/checkpoint, identity, failure originali, nessuna nuova resolve dopo disposal e nessuna pubblicazione tardiva. E1/E2 verificano zero ContentSubmissionAssetRemovalFailed duplicati; il vero Command E2 viene osservato dal global error callback per provarne la physical disposal esattamente una volta, senza esporlo dalla API VM. La sonda Flutter non registra il Command privato mai ascoltato direttamente; i casi delle altre lane restano al gruppo 5.

Un run preliminare con filtro troppo ampio includeva D5, difetto late-ack già caratterizzato e riservato al gruppo 5: 42 pass/1 failure prevista; non è presentato come gate verde. Il filtro finale sopra copre tutte le acceptance del gruppo 2 e F2. Dart analyzer diretto su VM, VM test, harness e fake condiviso: exit 0, soltanto le tre INFO legacy già presenti in fake_repositories alle posizioni B0 43:51:7, 656:17:7, 1165:13:7; nessuna nuova diagnostica. `git diff --check` passa. Nessuna modifica foundation/repository/dependency; il solo fake staged aggiunge pendingResolve e contatore resolve con default invariati. Nuovo harness feature-local riusato in oltre tre test, senza facciata Command eseguibile.


Gruppo 3 verificato: catch PlatformException limitati alle sole chiamate picker/retrieveLostData; FileSystemException limitata a length/openRead-hash con coppia privata error/stack distinta dai repository. Add conserva Error originale e logging feature, recovery conserva best-effort per esiti attesi. Raw repository, incluso FileSystemException, non viene normalizzato. Clear rimane persistence-first e non avvia cleanup dopo disposal durante clearDraft. Binding sessione e guard dopo await/notify preservati.

Gate `group3-gate.json`: `flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --name 'ContentSubmissionViewModel (addAsset|removeAssetAt|retrieveLostAssets|clear|draft checkpoints|OpenSpec 5 gates (E|L))|in-flight staging|picker results after clear|checkpoint ordered|thrown staged commit' --reporter expanded`, cwd worktree, **74 pass/0 failure/0 skip, exit 0** (`group3-vm.log`). Coperti L1–L7, limiti/dedup/staged path, clear/recovery, E1/E2 e bootstrap E4. Le prove nuove distinguono lettura file diretta attesa da FileSystemException raw dei repository add/recovery, PlatformException attesa da Exception plugin inattesa. Il precedente test best-effort del throw recovery usa ora PlatformException del boundary previsto, mantenendo le asserzioni; un test distinto esige runtime/reporting per Exception inattesa. E4 usa Completer e initialize nella medesima error-zone, verifica assertion/stack originali, global=0, ticket assestato e nessuna fase downstream o domain terminale sintetico. Il primo tentativo E4 aveva il Completer nella root zone ed è stato corretto nel solo harness, senza attribuirlo alla produzione. Analyzer diretto VM/test/harness: exit 0, no issues; diff whitespace valido. Repository, foundation e storage invariati.


Riapertura del gate 3.5 durante la prima suite VM completa: il filtro di gruppo 3 ometteva il test top-level “does not open the picker when staged reconciliation retry fails”. La suite completa ha mostrato reconcile=1 anziché 2. È una regressione d’implementazione, non un motivo per indebolire il test: il canonical staging (“Hard reconciliation failure completes safely”, righe 211–217) e D3/task 3.1 richiedono il retry pre-picker. Rimossa esclusivamente la early return initializationError da add Loading. Il ticket continua a fissare l’identità; la riconciliazione propria di add avviene sotto il medesimo arbitro. Unknown ownership continua a restituire l’errore originale senza cleanup; submit conserva invece membership/error immutabili del ticket, senza recovery implicita. Non vengono adottati owner/sessioni successivi e non cambia la delta. Il gate viene ripetuto e il task 3.5 resta aperto fino alla nuova verifica. Il lavoro gruppo 4 già presente resta non certificato, senza reset o nuovi avanzamenti finché il gate non è ristabilito.


Gate 3.5 ristabilito dopo la correzione: **80 pass/0 failure/0 skip, exit 0** (`group3-vm-after-retry-fix.log`, argv aggiornato in `group3-gate.json`), inclusi i test top-level precedentemente omessi e l’asserzione originale reconcile=2 invariata. La prima suite VM completa è conservata in `group4-vm-initial-failures.log`: 170 pass/3 failure (la regressione appena corretta; due asserzioni legacy disposal da adeguare al contratto approvato: nessuna nuova staged cleanup dopo disposal, e confronto notifiche dalla revoca anziché da prima dell’admission). Nessuno di questi run falliti viene dichiarato gate verde.


Gruppo 4 verificato: preparazione usa draft/issue/identity request-time e membership F2, checkpoint e live/identity guard prima del claim; upload sequenziali e payload finale immutabile; release matching pre-ack senza storage, con conservazione primaria domain/raw/assertion. Il ramo secondario è stato rivisto staticamente: errore cleanup diagnosticato separatamente via FlutterError, un fallimento del reporter non sostituisce il primario; nessuna seam di storage introdotta per renderlo artificialmente fallibile. Dopo ack live pending/ownership precedono finalization; errore domain o runtime locale conserva pending, retry derivato e modalità finalization-only fissata all’admission. Nessun secondo checkpoint/upload/submit; guard mismatch e una sola rotazione. Late ack già coperto da D5 revoca nuove fasi.

Suite VM **completa**: `flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --reporter expanded`, cwd worktree, **173 pass/0 failure/0 skip, exit 0**, log `group4-vm-full.log`, metadata `group4-gate.json`. Comprende S1–S21/E1–E4, E3 con domain/Exception/StateError/Object/assertion e clear indipendente dopo release, S10 runtime post-ack con pending e retry locale, doppia retry respinta e conteggi 2 upload/1 remote/nessun save ripetuto. Le due asserzioni legacy disposal sono aggiornate al contratto D5, mantenendo membership/identity e contatori persistenti; le continuazioni vengono drenate dopo il fake settlement prima dei controlli.

Gate dati ripetuto dopo le modifiche: `flutter test --no-pub test/data/repositories/content_submission_draft_repository_impl_test.dart test/data/repositories/content_submission_staged_asset_repository_impl_test.dart test/data/repositories/content_submission_repository_impl_test.dart test/data/services/api/cloudinary/cloudinary_upload_client_impl_test.dart --reporter expanded`: **91 pass/0 failure/0 skip, exit 0**, `group4-data.log`. Wire/ack/replay/upload restano invariati; nessun source repository/backend modificato. Analyzer diretto VM/test/harness: exit 0, no issues (`group4-analyzer.log`), diff whitespace valido. Il fake upload condiviso aggiunge soltanto stackTrace opzionale al throw controllato per l’oracolo E3, con default compatibile.


Verifica supplementare S11 senza seam produzione: gli ingressi pubblici non possono creare un mismatch post-ack mentre il lease è attivo (draft identity final, setters preservano ID, initialize memoizzata, clear negato, restore stesso checkpoint e submit single-flight). Owner disposal è coperto da D5. Per verificare anche i rami difensivi d’identità, creata una copia isolata della baseline con il diff Dart corrente e i soli metadata/runtime ignorati, `/private/tmp/content-submission-apply-evidence/S11-guard-probe`. Soltanto in tale copia, immediatamente dopo `_submissionFinalizationPending = true` e prima di `_finalizeSubmittedSession(draft.clientSubmissionId)`, fault injection separata: (a) `_state = ContentSubmissionDraft(clientSubmissionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', name: 'Replacement')`; (b) `_activeSubmissionClientSubmissionId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'`. Nessun oggetto domain reso mutabile e nessuna injection nel worktree.

Il test temporaneo `S11 isolated identity mismatch fails closed after acknowledgement` usa i fake e requestAndWait reali: remote=1 con ID originale, upload=0, clearDraft=0, staged cleanup=0, domain failure/non-success, pending conservato, state/identity sostitutiva invariata (oppure originale nel caso b). Ripete requestSubmit e verifica ancora remote=1/clear=0/pending, quindi retry locale fail-closed. Argv in quella cwd: `flutter test --no-pub test/ui/content_submission/view_models/content_submission_view_model_test.dart --name 'S11 isolated' --reporter expanded`. Entrambi gli esperimenti **1 pass/0 failure/0 skip, exit 0**, log `S11-{state,owner}-green.log`. Nella stessa copia togliendo soltanto il corrispondente controllo `_state... != expectedClientSubmissionId` oppure `_active... != expectedClientSubmissionId`, entrambi **exit 1** sull’oracolo clearDraft atteso 0/effettivo 1 (`S11-{state,owner}-red.log`), senza errori di compilazione. Questa è fault injection su guard difensivi, non una falsa dichiarazione di raggiungibilità del mismatch tramite API valide e non è inclusa nel conteggio dei 173 test persistenti. Il codice del test è conservato con le evidenze `S11-probe-test.txt`; le condizioni/invarianti normali sono inoltre testate da S3/S4/S9/D5.


Verifica aggiuntiva A3 prima del consumer gate: il submit ammette draft temporale A incompleto con issue catturata; un edit B prima dell’action disabilita l’evento e cancella l’issue. Rilevato un difetto nuovo della migrazione: `_prepareSubmissionAttempt` ripubblicava l’issue A su B, avvelenando anche il prossimo submit diretto valido. Test persistente variante A3 `captured issue preserves a later valid temporal edit`: red comportamentale exit 1, atteso issue null/effettivo missingStartDate (`A3-issue-red.log`). Task 4.1/4.5 riaperti fino alla correzione minima: pubblicazione dell’issue soltanto se `_state == draft` catturato. L’errore di A resta dominio come previsto; nessuna nuova policy di validazione e nessun nuovo identificatore scenario (variante A3, matrice sempre 63).


Variante A3 issue corretta e verificata: suite VM completa **174 pass/0 failure/0 skip, exit 0**, `group5-vm-final.log`, stesso argv VM completo e cwd worktree. L’issue A resta nel terminale del tentativo A; B valido mantiene issue null e il successivo submit diretto raggiunge il repository una volta. Task 4.1/4.5 nuovamente verificati. La correzione aggiunge soltanto il guard di presentazione `_state == draft` prima di pubblicare issue, senza reinterpretare lo snapshot. Il testo D2 unknown/unavailable è precisato per conservare il retry add esplicitamente canonico (correzione rilevata e descritta sopra), nessuna nuova policy.

Gruppo 5 verificato: oltre ai prerequisiti ordinary già introdotti, guard fresh initialize dopo disposal, restore già accodato e retirement entry, più canRetry false su owner revocato. Audit di tutti gli await/notify contro la tabella D5. **75 nuovi test lifecycle** (13 per cinque lane più 10 fasi) passano: prima entry, success/domain/raw/assertion oltre 50ms virtuali, settlement/dispose stesso turno in entrambi ordini, terminal observer reentrante, nuova admission nel sync-idle observer, idle/mai eseguiti. Probe SDK cattura i cinque results notifier diretti attraverso ObjectCreated, distingue i derivati e prova rilascio fisico esattamente una volta; durante pending quattro idle sono rilasciati e quello attivo resta vivo fino al settlement. Nessuna API Command resa pubblica.

Fasi controllate aggiuntive: upload primo di due pending → zero secondo/final request; cleanup staged post-ack pending → nessuna rotazione, pending/snapshot congelati e retry false; reconcile/resolve bootstrap → nessun resolve successivo/list publication; length/hash e resolve candidato in add/recovery → nessuna fase successiva o asset nuovo. Gate focused: `flutter test --no-pub test/ui/ordinary_view_model_lifecycle_test.dart --plain-name 'Content Submission private' --reporter expanded`, **75 pass/0 fail/0 skip, exit 0**. Aggregate foundation quattro suite + ordinary + Category lifecycle/Settings: **319 pass/0 fail/3 skip preesistenti, exit 0**. Argv/cwd/skip provenance esatti in `group5-lifecycle-evidence.json`, log `group5-foundation-lifecycle.log`. I tre skip sono le modalità StateError già presenti nella caratterizzazione upstream, non nuovi skip. Analyzer VM/VM test/harness/due file lifecycle: exit 0, no issues (`group5-analyzer.log`). Nessun timer reale, nuova foundation o storage; limite cross-owner I/O già iniziato e Future non terminante invariati.


Audit interno prima del gate consumer: rilevata una finestra rientrante nel forwarding sync-idle di command_it 9.5.2. Il run upstream pubblica false prima di value e di nuovo nel finally; un listener VM che ammette una seconda esecuzione nel primo callback può vedersi azzerare il busy dal finally precedente. Il caso lifecycle precedente disponeva immediatamente il nuovo owner e non provava un secondo tentativo vivo. Task 2.1/2.5/5.2/5.3 riaperti fino a prova discriminante e correzione locale del dispatch. Nessuna modifica della foundation o nuova coda è autorizzata o necessaria; il gate del gruppo 6 resta non certificato fino alla risoluzione.


Prova discriminante D3 reentry: **10 failure comportamentali/0 pass, exit 1** prima del fix (`group5-reentrant-red.log`), tutte cinque lane × secondo tentativo live oppure disposal con raw settlement. Il secondo I/O era realmente entrato e pending, ma il busy risultava false; nessun errore di compilazione. Correzione limitata al forwarding locale del sync-idle descritta in D1, risultati/running-start immediati e factory invariata. Stessi dieci test **10 pass/0 failure/0 skip, exit 0** (`group5-reentrant-green.log`): busy durante il secondo I/O, terza admission false e snapshot/slot intatti; variante dispose oltre 50ms virtuali conserva raw/stack/report=1, zero pubblicazione obsoleta e cinque notifier rilasciati una volta. Sono varianti del D3 esistente, nessuna rinumerazione dei 63 scenari o dei 79 normativi. Analyzer dei due file lifecycle exit 0 senza diagnostiche.


Gate riaperti ristabiliti dopo reentry fix: VM completa **174 pass/0 failure/0 skip, exit 0** (`group5-reentrant-vm-full-retry.log`); aggregate foundation/lifecycle/Category/Settings **329 pass/0 failure/3 skip preesistenti, exit 0** (`group5-foundation-lifecycle-reentrant.log`). I casi lifecycle Content Submission privati sono ora **85** (75 precedenti + 10 varianti D3). Analyzer mirato VM e file lifecycle senza nuove diagnostiche; task 2.1/2.5/5.2/5.3 nuovamente verificati. Il primo tentativo VM è fallito prima di eseguire test per accesso negato alla cache SDK; log conservato separatamente, ripetizione autorizzata con escalation effettivamente verde.


Gruppo 6 verificato: AssetList usa VM/snapshot e warning soltanto della propria admission, con owner/session/digest/index catturati nel rendering e riconvalidati prima di remove; callback obsolete realmente conservate nei test B6–B9. Screen ribinda listener, Form keys e generazione anche a parità di ID, isola pending/finally e protegge submit/link/iOS/recovery post-frame. Progress distingue neutral/running/success/domain/runtime/pending e mantiene retry locale-only. Router limita il diff a Content Submission, segue replacement tramite selector di identità e controlla owner Provider/sessione dopo dialog e await, compresa la finestra prima di didUpdateWidget.

Gate consumer completo: `flutter test --no-pub test/ui/content_submission/widgets test/routing/content_submission_route_test.dart test/routing/content_submission_restoration_test.dart --reporter expanded`, cwd worktree autorizzato; **164 pass/0 failure/0 skip, exit 0** (`group6-consumers-full.log`). Copertura P1–P8/B1–B9: running prima action, doppia retry con un solo invio remoto, runtime pre/post-ack, restoration idle, policy di navigazione precedente, replacement stessa/diversa identity, vecchio finally contro pending nuovo e raw checkpoint/restore live/replacement/unmount con oggetto/stack/report=1/token rilasciato/zero feedback obsoleto. Gli otto casi router aggiunti verificano Save/Discard con Provider già sostituito e fault diretti checkpoint/restore × live/replacement/unmount, senza reinterpretare il target. B3 usa un host MaterialApp già inizializzato e buildScope pubblico: prova Screen A realmente montato (finder skipOffstage:false), poi replacement o unmount prima di flush post-frame, A retrieve=0 e B=1 soltanto se vivo. Nella sola copia temporanea mutation-gate, rimuovendo le due guard del callback recovery, **0 pass/2 failure, exit 1** su recovery obsoleta; fonte autorizzata intatta (`group6-b3-mutation.log/json`). Nessuna seam produzione.

I run preliminari B3 con finder onstage prima del completamento del frame e URI del router dopo push imperativo avevano oracoli del fixture inadeguati: corretti per osservare mounting e presenza effettiva della Screen, senza indebolire i vincoli I/O/owner/policy. I run falliti restano conservati e non vengono conteggiati come gate. Analyzer diretto consumer/test/supporti corretto fino a zero nuove diagnostiche, nessun ignore/skip aggiunto. La modifica a testOwnerUI aggiunge soltanto un callback teardown opzionale per gli owner .value, default invariato; il nuovo harness feature-local è riusato anche dal clock virtuale widget.


Primo B1 integrato: 52 INFO attese ma **2 ERROR, exit 3**, entrambe riferimenti legacy submit nel test `test/integration/all_day_pipeline_test.dart:74–75`, sfuggito al manifest nominale del planning. Il consumer è strettamente parte della pipeline Content Submission richiesta e della suite completa; non è una superficie esclusa backend/persistenza né una nuova decisione architetturale. Manifest corretto esplicitamente con quel solo test. Adattamento minimo al requestAndWait già condiviso e allo snapshot success, mantenendo tutti gli assert wire/persistenza/rendering e lo skip opt-in originale del test locale Supabase. Nessun nuovo helper o infrastruttura. La compilazione viene ricontrollata dal test mirato e da B1; il corpo opt-in non verrà dichiarato eseguito senza stack locale. Gate 7.1 ancora aperto fino al nuovo confronto. Il primo runner archivio ha inoltre incontrato TypeError dell’opzione Python tarfile filter, prima dell’analyzer: runner compatibile corretto senza toccare il worktree; non è una diagnostica Dart. Log B1 iniziale preservato separatamente in B1-initial.{stdout,stderr,json}.


Gate 7.1 completato: formatter dei 16 Dart iniziali più il consumer integrato (17 file intenzionali) con zero cambiamenti residui. B1 finale, stesso SDK/flag/cwd/config procedura di B0 su archivio HEAD più diff e nuovo harness, argv `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/content-submission-apply-evidence/final`: **52 INFO/0 WARNING/0 ERROR, exit 0**, stderr vuoto. Metadata/stdout/stderr separati in B1.{json,stdout,stderr}. Il Counter completo confronta severity/type/code/path/line/column/length/message; SequenceMatcher mappa ogni linea non-target soltanto su source identico: **14 target eliminate, missing non-target=0, added=0**, nessuna variazione di molteplicità. L’unico spostamento non-target nuovo è il riferimento dartdoc fake_repositories 1165→1169; gli altri 51 restano alla stessa linea. Mapping completo in analyzer-comparison.json. Il run intermedio ha rilevato un import inutilizzato perché il test integrato usava isSuccess upstream: corretto all’estensione completed Result-aware, poi verificato zero warning. I risultati falliti iniziale/intermedio restano separati; nessun ignore o nuovo skip. Dart diretto exit 0 non equivale a Flutter analyze globale verde: restano le 52 INFO, e Flutter analyze non è stato eseguito in questo apply.


Gate 7.2 completo: `flutter test --no-pub --reporter json`, cwd worktree autorizzato, **2.862 pass/0 failure/6 skip, exit 0**, durata runner 102.405ms, stderr vuoto. Raw stdout/stderr separati e metadata in full-suite.{stdout,stderr,json}. Conteggi ricavati da testDone non hidden e evento done.success=true, non da stime; i 17 Dart correnti coincidono byte per byte con quelli di B1 e i relativi SHA256 sono registrati. I sei skip sono effettivi e verificati nelle direttive preesistenti a HEAD: all_day_pipeline opt-in locale Supabase; external_event_token_pipeline opt-in autenticato; tre modalità StateError upstream A/B/E di command_it_disposal_behavior; NAV-01 upstream #188018 in geo_map_route. Nessun nuovo skip/suppression. Il gate mirato all-day ha compilato con 0 pass/1 skip/exit 0; il corpo che richiede stack locale non è dichiarato eseguito. Rispetto al risultato storico pubblicato 2.705 pass, i nuovi 157 casi corrispondono a VM +42, lifecycle +85 e consumer/route +30; la suite corrente è comunque stata eseguita integralmente, non derivata dalla somma storica.

Copertura conclusiva della matrice: A1–A8, L1–L7, S1–S21 ed E1–E4 nella suite VM completa e nei boundary repository/Cloudinary; D1–D6 ed E2/E4 nei gate lifecycle fisici e nelle fasi controllate; P1–P8 e B1–B9 nei 164 widget/route/restoration. S11 distingue la prova normale dell’impossibilità di mismatch con API valide dai due fault injection difensivi isolati documentati sopra. Restano 63 ID univoci nello stesso ordine (46 originali +17 remediation), senza contare le varianti runtime/domain/loading/reentry come nuovi ID. Delta: 79 scenari normativi, rispettivamente concurrency 14, staging 15, navigation 20, orchestration 30; tutti i 20 scenari canonical dei quattro requirement MODIFIED restano presenti (canonical-preservation.json).


### Manifest effettivo dell’apply

16 file tracked modificati e 9 untracked (gli otto artifact preesistenti più il solo nuovo harness), tutti locali e non staged. Produzione: cinque file; test/supporti: dodici Dart, incluso il consumer all-day censito nel gate finale. Elenco completo:

- `lib/routing/router.dart`
- `lib/ui/content_submission/view_models/content_submission_view_model.dart`
- `lib/ui/content_submission/widgets/content_submission_asset_list.dart`
- `lib/ui/content_submission/widgets/content_submission_progress_screen.dart`
- `lib/ui/content_submission/widgets/content_submission_screen.dart`
- `test/integration/all_day_pipeline_test.dart`
- `test/routing/content_submission_restoration_test.dart`
- `test/routing/content_submission_route_test.dart`
- `test/support/command_test_support.dart`
- `test/support/fake_repositories.dart`
- `test/support/ordinary_view_model_lifecycle_support.dart`
- `test/ui/content_submission/view_models/content_submission_view_model_test.dart`
- `test/ui/content_submission/widgets/content_submission_asset_list_test.dart`
- `test/ui/content_submission/widgets/content_submission_progress_screen_test.dart`
- `test/ui/content_submission/widgets/content_submission_screen_test.dart`
- `test/ui/ordinary_view_model_lifecycle_test.dart`
- `openspec/changes/migrate-content-submission-commands/.openspec.yaml`
- `openspec/changes/migrate-content-submission-commands/design.md`
- `openspec/changes/migrate-content-submission-commands/proposal.md`
- `openspec/changes/migrate-content-submission-commands/specs/command-execution-concurrency/spec.md`
- `openspec/changes/migrate-content-submission-commands/specs/content-submission-local-asset-staging/spec.md`
- `openspec/changes/migrate-content-submission-commands/specs/content-submission-navigation-lifecycle/spec.md`
- `openspec/changes/migrate-content-submission-commands/specs/content-submission-submit-orchestration/spec.md`
- `openspec/changes/migrate-content-submission-commands/tasks.md`
- `test/support/content_submission_command_harness.dart`

Rispetto agli artifact approvati sono cambiati soltanto proposal, design, tasks e il THEN della variante Edit-before-deferred-entry nel delta orchestration per preservare l’issue di presentazione dell’edit valido successivo; `.openspec.yaml` e gli altri tre delta restano identici byte per byte. Nessuna nuova capability/artifact e nessuna scrittura canonical. Metadata/runtime ignorati `.dart_tool` e `lib/libobjectbox.dylib` sono stati preparati soltanto nel worktree autorizzato per eseguire i gate, esclusi dal manifest Git. Le evidenze operative restano in `/private/tmp/content-submission-apply-evidence/`; risultati, motivi delle riaperture e limiti rilevanti sono riportati qui anche senza dipendere dai file temporanei.


Controlli documentali finali: esattamente otto artifact originali, quattro capability esistenti, 32 task originari e nessuna nuova capability; verificata sequenza dei 63 ID originali/remediation e 79 scenari normativi, tutti i titoli scenario canonical dei quattro MODIFIED conservati. Formatter finale dei 17 Dart: zero cambiamenti, exit 0. Whitespace/newline controllati anche per i nove untracked, nessun problema. Nessun nuovo ignore, skip o configurazione analyzer. Il manifest finale include esplicitamente il consumer integrato all-day individuato da B1; è l’unica aggiunta nominale al manifest previsto, motivata sopra e senza modifica dei contratti backend/persistenza.


### Chiusura apply locale

**32/32 task verificati**. `openspec validate migrate-content-submission-commands --strict`: valid, exit 0. HEAD `f48a08946c9ac40146104a0157556243ad433c92` e branch autorizzati invariati, index vuoto; 16 tracked modificati e 9 untracked nel manifest. Confronto dei sei altri checkout con il preflight: HEAD/branch/index/status tracked e untracked tutti invariati, nessuna loro scrittura. PR #12 riconfermata open/Draft su f48a0894, base main ee60777c; nessun update. Diff/whitespace/manifest e hash dei 17 Dart validati riconfermati. Nessun commit, push, merge, sync, archive o operazione distruttiva.

Nessun blocker materiale residuo nei gate dell’apply. Restano deliberatamente i limiti approvati: I/O fisico cross-owner già avviato non cancellato/serializzato globalmente; Future non terminante può trattenere risorse private; acknowledgement non durevole attraverso process kill; cleanup staged Result.error best-effort; sei test skip preesistenti, inclusi i due opt-in di integrazione non eseguiti senza stack locale. S11 fault injection difensivo è distinto dai test persistenti. Non si dichiara analyzer globalmente pulito né CI eseguita sul diff locale.

**READY FOR INDEPENDENT CODE REVIEW**. Il diff è locale e non committato. Review indipendente del codice e autorizzazione alla pubblicazione sono i prossimi gate separati; nessuna autorizzazione a commit/PR update o merge viene inferita dall’apply.
