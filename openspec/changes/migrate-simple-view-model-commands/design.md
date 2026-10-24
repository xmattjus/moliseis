> **Tracciabilità:** le sezioni prima di “Apply evidence — 2026-10-20” sono
> il registro storico del planning e delle sue remediation. L’apply seguente è
> a sua volta il resoconto precedente alla code review CR-F1–CR-F3. La sezione
> “Remediation post-apply — CR-F1–CR-F3” definisce la decisione corrente: corregge
> esplicitamente l’ipotesi storica che vietava anche la riconciliazione del flag
> Sentry dopo dispose, senza ripristinare autorità di presentazione all’owner.

## Context

Vedere proposal.md per motivazione e perimetro. **VERIFICATO** indica codice/documenti letti o comandi realmente eseguiti; **PROPOSTO** indica strategia futura; **INFERENZA** indica conseguenze del sorgente da confermare nei regression test. La remediation modifica solo quattro artifact esistenti, senza apply.

### Preflight e provenienza

Nel preflight F1–F6 furono riletti AGENTS.md, i cinque artifact, i sei ViewModel del precedente perimetro e la canonical. Nel nuovo preflight R1–R3 sono stati riletti AGENTS.md, tutti i cinque artifact, la canonical command-execution-concurrency e i sorgenti/test richiesti per cleanup, Favourite, Theme, repository e reporting, confrontandoli con origin/main e con i pacchetti risolti. Nessun AGENTS annidato; istruzioni OpenSpec e ruoli locali applicabili. La richiesta di remediation autorizza direttamente le modifiche documentali indicate, senza un ulteriore giro di conferma per ciascun artifact. Root repo-local, schema spec-driven; .openspec.yaml invariato (`created: 2026-10-19`, senza skip_specs).

Fetch origin/main riuscito nella remediation: `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, uguale alla baseline richiesta. HEAD `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`, branch `codex/resolve-flutter-analyzer-diagnostics-pr3`, 0 ahead/7 behind. Il checkout vecchio non è base di implementazione. Prima di apply usare l’ultimo origin/main verificato e riconciliare drift. Nessun checkout, reset, merge o worktree creato ora.

Working tree iniziale della remediation: ` M AGENTS.md`, `?? openspec/changes/migrate-simple-view-model-commands/`, `?? openspec/changes/resolve-flutter-analyzer-diagnostics-pr4/`; index vuoto. Hash iniziali dei file tracked/untracked non ignorati acquisiti per verificare che soltanto i quattro artifact autorizzati cambino. Tutto il resto va preservato.

Confronto mirato HEAD↔origin/main: i sei ViewModel riletti, foundation, canonical e dipendenze sono identici. Main include però PR4: await espliciti nei UseCase, Result e fake/test; la differenza nel widget selezione Category è ormai esclusa. Si usano codice e archivio PR4 su main come fonte, non il piano PR4 untracked o i vecchi fake di PR3. Il precedente audit ha letto gli archivi foundation 2026-10-12-adopt-command-it-restartable-foundation e PR4 2026-10-19-resolve-flutter-analyzer-diagnostics-pr4, incluso ledger 125; non sostituiscono il codice corrente.

Foundation riletta: lib/utils/{command,result_command,restartable_command,command_configuration}.dart; test/utils/{result_command_test,command_it_disposal_behavior_test}.dart. Sorgente autoritativo della versione risolta: `~/.pub-cache/hosted/pub.dev/command_it-9.5.2/lib/command_it.dart`, in particolare run 312–413, dispose 799–825, runAsync 859–870. Pubspec ^9.5.2/lock/package_config risolvono command_it 9.5.2 e listen_it 6.0.0; Flutter 3.47.5 e Dart effettivo 3.13.4. Nessun pub get/upgrade. Le limitazioni di lifecycle non sono inferite dalla versione latest online.

### Baseline e diagnostiche — R3

**Risultato storico verificato.** Nella prima fase, sullo snapshot di origin/main `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, il comando analyzer è stato eseguito dalla directory `/Users/benitomatteobercini/Developer/Progetti/moliseis_v2`:

```sh
/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/molise-command-planning-main > /tmp/molise-command-planning-analyze.log
```

È il Dart SDK eseguito direttamente, non il wrapper `flutter analyze`. I soli argomenti analyzer erano `--format machine` e la directory assoluta; nessun `--fatal-infos`, nessuna disattivazione esplicita di fatal-warnings. L’help del Dart risolto conferma warning fatal di default e info non fatal di default: questo spiega la compatibilità di **125 INFO, 0 WARNING, 0 ERROR ed exit grezzo 0**, ma l’exit non viene dedotto da tale conteggio. L’exit 0 è riportato dal risultato del processo nel transcript della prima esecuzione; il solo log machine non registra argv, cwd o exit.

**Evidenze ritrovate e nuova verifica distinta.** Il log originale esiste ed è stato riletto nella remediation R1–R3: SHA-256 `aa6b5d4f212e9a0305ff5c8526c1b2ff6b2f6ba74ed378944ad28f23a7a87f11`. Il replay non mutativo della remediation ha rieseguito lo stesso argv dalla stessa cwd tramite subprocess, salvando stdout in `/tmp/molise-r123-analyzer-replay.log`, stderr in `/tmp/molise-r123-analyzer-replay.stderr` e metadati in `/tmp/molise-r123-analyzer-replay.json`. **Nuovo exit grezzo misurato: 0; 125 INFO, 0 WARNING, 0 ERROR; stderr vuoto.** Il nuovo stdout è identico byte per byte al log storico, con lo stesso SHA-256. Questa è una nuova esecuzione di controllo, non viene presentata come il processo storico.

Prima del replay sono stati confrontati tutti i 1.072 file regolari dell’archivio Git della base con lo snapshot: identici. Il package_config temporaneo ha SHA-256 `081b825b3c18f33193decbd1ad6c94f0b69c3a6510ec84d6298d8a8315ae1356`. Versioni verificate: eseguibile Dart **3.13.4 stable macos_arm64**; metadata SDK Flutter **3.47.5 stable**, framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`; command_it 9.5.2 e listen_it 6.0.0 da lock/package_config. Non è stata eseguita la suite Flutter.

**Preparazione riproducibile proposta.** Dalla root del progetto: estrarre `git archive <SHA-origin/main-verificato>` in una nuova directory temporanea vuota, senza checkout; copiare soltanto il package_config già risolto in `<snapshot>/.dart_tool/package_config.json`. Nella copia, cambiare esclusivamente `rootUri` del package moliseis da `../` alla URI assoluta della directory temporanea **risolta** (`Path(snapshot).resolve().as_uri() + '/'`); mantenere tutte le altre voci SDK/dipendenze e verificare che le relative destinazioni esistano. Nel caso storico la URI è `file:///private/tmp/molise-command-planning-main/`: usare /tmp invece del percorso reale /private/tmp aveva causato diagnostiche part-of artificiali in un tentativo precedente scartato. Nessun adattamento del package_config del checkout, nessun pub get/generazione/upgrade.

Il comando riproducibile è quello sopra con la nuova directory come unico argomento posizionale e un nuovo log. Acquisire sempre cwd, SHA base, versioni, argv completo, modifiche temporanee, stdout/stderr, conteggi per severity e **returncode del processo analyzer**; con subprocess usare returncode, con shell acquisire `$?` subito, senza pipeline che mascherino l’exit. Verificare gli stessi metadati prima e dopo l’apply; non trattare le opzioni default di un wrapper diverso come equivalenti. Se occorre anche `flutter analyze --no-pub`, registrarne separatamente comando/flag/exits: non attribuirgli l’exit del Dart diretto. I file /tmp sono evidenze effimere, non prerequisiti permanenti dell’apply.

**Ledger.** Le 125 righe machine, tutte `DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`, provengono dal log originale e sono riconfermate dal replay; l’inventario durevole di tutte le 125 identità/multiplicità è nell’appendice di `openspec/changes/archive/2026-10-19-resolve-flutter-analyzer-diagnostics-pr4/design.md` su origin/main. Il ledger di preflight va comunque rigenerato sull’execution head. La tabella sotto identifica le 12 posizioni target della prima change, senza confondere rimozione di identità con un saldo numerico.

| File sotto lib/ui | Target su origin/main, linea:colonna | Totale |
| --- | --- | ---: |
| settings/view_models/settings_view_model.dart | 13:25, 21:8 | 2 |
| settings/view_models/theme_view_model.dart | 11:26, 12:20, 25:8, 27:8 | 4 |
| explore/view_models/explore_view_model.dart | 15:18, 21:8 | 2 |
| explore/view_models/suggestion_view_model.dart | 13:12, 21:8 | 2 |
| favourite/view_models/favourite_view_model.dart | 20:12, 29:14 | 2 |

Gate ridotto: **12 target**, sei costruzioni e sei dichiarazioni; **113 residue attese**, comprese le otto Category escluse. Confrontare identità per file/regola/simbolo/contesto e molteplicità, normalizzando root e linee spostate: zero nuove diagnostiche, non solo saldo 125−12. Registrare exit grezzo di flutter analyze, che può restare non-zero per info. Nessun lint/soppressione/config modificato.

## Goals / Non-Goals

Cinque ViewModel e sei lane ordinarie; dipendenze di dominio e persistenza invariate. Command gestisce esecuzione/stato; ViewModel orchestrazione/ottimismo/pubblicazione; repository dominio/persistenza; View rendering/feedback. Conservare Provider/ChangeNotifier, KISS/YAGNI/DRY/SRP/DIP, minimal change e Rule of Three; nessun nuovo package, nuova interfaccia o infrastruttura preventiva.

### F1 risolto per esclusione autorizzata

CategoryViewModel e load/setSelectedCategories/setSelectedTypes/setSort, consumer, test e task esclusivi sono fuori da questa change. Le factory differiscono l’handler e non conservano automaticamente l’ingresso inline e le query annidate legacy. Il problema appartiene alla futura change indipendente **migrate-category-view-model-commands**, non creata ora. Nessuna correzione dei suoi error branch, sort, router seed, lifecycle o test è autorizzata qui. Nessun adapter, scheduler, wrapper o factory viene preparato per quella migrazione.

La sequenza complessiva è ora sette OpenSpec nello stesso branch e una sola PR finale, nessuna change di coordinamento. Le altre sei non sono dipendenze implementative della prima; non modificare i loro Command. La rimozione di command.dart e zero deprecazioni globali appartengono alla PR finale.

## Audit corrente e matrice dei sei Command

Tutte le azioni mantengono Result<void>, con `ResultCommand<P, void>`; i no-param usano P=void. La delta F3 rende superfluo cambiare payload o aggiungere completion observer solo per spostare mutazioni già legittimamente feature-owned.

| ViewModel / Command | VERIFICATO | PROPOSTO |
| --- | --- | --- |
| Settings / setCrashReporting | Ottimismo e notify; repository; su Result.error inversione/notify; SentryLoggingFlag sincronizzato al valore finale. | createResultCommand<bool, void>; runAsync nel callback che richiede feedback, con ammissione verificata e Result della propria esecuzione; guard lifecycle. |
| Theme / setThemeBrightness | Ottimismo, oldBrightness locale, rollback su Result.error; SettingsScreen attende senza continuazione significativa. | createResultCommand<ThemeBrightness, void>; run nel trigger UI; runAsync solo per attese esplicite/test; lane separata. |
| Theme / setThemeType | Come brightness su campo distinto; selettore colori commentato; test e sync_redirect_test attivi. | createResultCommand<ThemeType, void>; stessa policy; non riattivare UI commentata. |
| Explore / loadLatest | Autoload; getLatest diretto; successo sostituisce lista e notify; Result.error conserva dati precedenti. | createResultCommandNoParam<void>; run nel costruttore/retry; commit live nella continuazione esistente. |
| Suggestion / load | Autoload; getSuggestions; su Result.error assegna []; notify; dispose attuale immediato. | createResultCommandNoParam<void>; run; conservare retention diversa da Explore, guard continuazione e cleanup sicuro. |
| Favourite / load | Autoload; place IDs/oggetti e commit, poi event IDs/oggetti e commit; primo errore; forwarding al VM. | createResultCommandNoParam<void>; run; ammissione sync, cattura locale del rifiuto durante write, forwarding results e cleanup post-settlement. |

### Consumer e test nel perimetro

SettingsScreen usa Consumer dei due VM; main.dart Consumer<ThemeViewModel> legge themeMode al notify. ExploreScreen osserva loadLatest: cambiare solo sezione latest, non EventViewModel/coordinator temporale. SuggestionHorizontalListView osserva load, skeleton/error/retry/empty-state. FavouriteScreen osserva **il ViewModel**; FavouriteButton legge isUpdating/membership e attende direttamente setFavourite. Non cambiare lo scope dei Provider in dependencies.dart/router.dart.

Cinque suite: test/ui/settings/view_models/{settings_view_model_test,theme_view_model_test}.dart; test/ui/explore/view_models/{explore_view_model_test,suggestion_view_model_test}.dart; test/ui/favourite/view_models/favourite_view_model_test.dart. Consumer da validare: settings_screen_test, favourite_button_test e widget latest/suggestion/screen pertinenti; routing sync_redirect_test e altri test Provider che istanziano questi cinque owner, senza nuovi test esclusivi di feature escluse. Riutilizzare test/support/{fake_repositories,fixtures,command_test_support,favourite_button_harness,sync_harness} verificati sull’execution head.

## Decisions

### D1 — Foundation e F3 risolto mediante MODIFIED

Usare createResultCommand/createResultCommandNoParam e ResultCommandSnapshot. Non usare RestartableCommand, nuove factory o adapter legacy; non imporre staging terminale o nuovi observer di commit alle azioni ordinarie. L’owner vivo e la singola esecuzione ammessa mantengono l’autorità: nessun generation token necessario quando non esiste superseding nella stessa lane. Theme ha due campi/lane indipendenti; Favourite ha una mutazione diretta indipendente dal Command di lettura, coordinata esplicitamente.

La remediation autorizza una delta **MODIFIED** completa di `Only authoritative completion can commit asynchronous data`, con il nome canonico e lo scenario precedente conservati. Per restartable/latest-intent rimangono retrieval puro e commit sincrono nel completion observer autoritativo, senza eccezioni per Search/GeoMap. Per ordinary single-flight sono consentiti ottimismo, pubblicazioni progressive e rollback nelle continuazioni, soltanto se owner vivo ed esecuzione ancora autoritativa. Dispose revoca commit, rollback, notify e nuove fasi repository; non annulla fisicamente una write già avviata. Non forzare lo staging terminale di Favourite.

**Verifica compatibilità della capability:** execution states e failure kinds restano invariati; Result.error non diventa throw; reporting privacy-aware exactly-once e policy assertion invariati. Newest intent, cross-type Map ownership e late stale error reporting non cambiano. Lifecycle continua a distinguere revoca pubblica e lavoro privato fino a settlement. I completion/forwarding observer pubblici sono staccati prima del notifier dell’owner; il Command trattenuto serve soltanto a completamento/reporting/cleanup privati. Forecast e le lane non migrate non ricevono nuove semantiche. Questa delta non viene sincronizzata alle canonical durante il planning.

### D2 — Snapshot e rendering

Osservare command.results, catturando un solo snapshot per build e usando le extension esistenti. Non usare Command.value come prova di esito: può conservare un Result precedente. La factory non include last-result negli snapshot di loading/failure.

| Snapshot | Contratto consumer |
| --- | --- |
| idle/never-run: data=null e nessun errore | Nessun falso successo o empty-success; discovery può mostrare skeleton previsto per bootstrap. |
| isRunning | Loading/shimmer; dati del VM seguono la retention feature; ammissione separata sync. |
| completed: Success<void>(null) | Successo reale distinto da null iniziale; lista/griglia o empty-state. |
| domainError | Exception applicativa originale, errore/retry previsto. |
| unexpectedError | Failure runtime terminale, UI errore e reporting globale originale; nessun Result.error fabbricato. |
| nuova run dopo esito | Loading e poi nuovo esito; non promuovere value precedente a successo corrente. |

Explore mantiene lista su Result.error, Suggestion la svuota; Favourite mantiene progressione dei lati. Assertions restano fail-loud di sviluppo e non sono normalizzate in normale UI failure. Forwarding Favourite parte da results e copre anche esiti senza nuovo valore Command.

### D3 — run, runAsync e feedback Settings

VERIFICATO: run ammette sincronicamente, alza isRunningSync, pubblica loading e poi attende Duration.zero prima dell’handler. run duplicata viene ignorata. runAsync può restituire il completer pendente e agganciarsi anche a lavoro avviato da run; restrizioni/no-start possono lasciare attesa pendente. Dispose completa il waiter col value corrente, non col successo dell’operazione. Raw throw gestito completa runAsync con errore oltre al reporting globale; Result.error è invece un normale valore.

Usare run per costruttori/retry e callback UI senza continuazioni. Non avvolgerlo in async/unawaited. Usare runAsync nei test e nel feedback Settings soltanto da un owner live e per una richiesta nuova ammissibile (`!isRunningSync.value && canRun.value`), senza await fra check e chiamata. Nessun controllo del notifier asincrono per ammissione. I call site di feedback sono eventi UI, non listener rientranti del terminale Command; non richiamare runAsync da quei listener per attribuirgli una nuova esecuzione.

SettingsScreen cattura VM/input prima dell’attesa, ignora il callback duplicato non ammesso e osserva **il Result ritornato dalla propria esecuzione**, non command.value o uno snapshot successivo di un’altra run. Snackbar solo se richiesta enable=true, Result è Success<void>, context ancora mounted e Provider riferisce ancora allo stesso owner. Il ramo errore del Future va osservato localmente senza convertire Object in Result.error e senza un secondo report: per esempio error continuation che termina soltanto l’attesa UI già gestita dal Command. I test usano handler globali ripristinati. Completamento per dispose o cambio owner non produce feedback. Non aggiungere lifecycle state holder nel widget.

**Correzione visibile dichiarata:** oggi la callback mostra lo snackbar anche dopo Result.error quando value=true. Dopo migrazione quel messaggio non viene mostrato su failure. È l’unica correzione UX intenzionale qui pianificata, già autorizzata dalla richiesta sul feedback; non dichiararla equivalenza del ramo fallito.

### D4 — Error handling

Le azioni mantengono Result.error e identità delle Exception; nessun catch generico Object→Result. Le factory mantengono globalHandler; osservare results non deve disabilitare il reporting. Il wrapper legacy FlutterError.reportError viene sostituito dal percorso globale foundation per i soli sei Command, senza duplicazione. Non modificare command_configuration, whitelist, logging o assertion policy.

setFavourite resta diretto Future<Result<void>>: preservare catch on Exception già in _persistFavourite, errore non-Exception resta throw, nessun global reporting automatico aggiunto a questa API. Raw StateError non diventa rollback applicativo; preservare tale distinzione. La normale failure di una write live produce invece l’esatto rollback previsto.

### D5 — Lifecycle e cleanup locale — R1

**Revoca pubblica immediata, teardown fisico differito per tutti i Command, anche idle.** Ogni owner marca subito _disposed e rende idempotente la propria richiesta di disposal. Stacca subito i listener che possiede sui Command, compresi forwarder results e cattura F2c: removeListener è supportato durante dispatch e tombstona gli elementi rimossi. Non riattaccare mai un listener pubblico dopo la revoca. Il solo listener eventualmente trattenuto è privato e serve al settlement/cleanup.

Verificare il guard all’ingresso dell’azione, dopo ogni await, dopo ogni notify sincrona potenzialmente rientrante, prima di ogni commit e di ogni nuova fase repository. Un guard soltanto dentro _notifyListeners non protegge liste o I/O successivi. Se dispose precede ingresso/write, terminare privatamente con Result.error di owner non disponibile (per Favourite riusare update-unavailable), senza iniziare I/O. Una fase già iniziata conserva il proprio esito, senza commit/rollback/notify o fasi ulteriori; se load multi-stage viene interrotto non fabbricare Success completo. La direct write già avviata conserva l’originale Result/throw. Nessuna cancellazione o rollback remoto implicito.

**Evidenza upstream necessaria, non solo idle.** In command_it.dart:249–251 results è CustomValueNotifier con asyncNotification=false di default (listen_it/src/custom_value_notifier.dart:391–396). I notifier di results e del valore Command sono sincroni; è `_isRunningAsync` a usare asyncNotification=true (command_it.dart:775–779). Su successo la dispatch terminale results precede il false sync e la notifica del valore; su errore results precede reporting globale e il false nel finally (369–407, 1000–1024). Il decoupler interno su false accoda la notifica asincrona isRunning tramite Future; il finally accoda inoltre il proprio zero-delay prima dell’eventuale logging. Il Future runAsync può completare prima di quel lavoro finale. Perciò false, snapshot terminale o Future completato **non provano da soli** che tutte le dispatch siano terminate.

**Strategia locale deterministica:**

1. Alla revoca, per ogni Command posseduto conservare soltanto un listener privato isRunningSync e flag locali di chiusura (controllo accodato / barriera invalidata da transizione successiva / rilascio effettuato). Se inizialmente attivo attendere la transizione false; se idle o never-run chiedere comunque il controllo differito, mai il dispose inline; nessuna chiamata sincrona a Command.dispose dalla dispatch dell’owner o di un notifier Command.
2. Coalescere la richiesta in una microtask che, dopo l’uscita dallo stack corrente, accoda un unico callback event-queue tramite `Future<void>(...)`. Al momento della richiesta iniziare una barriera valida; ogni nuova transizione sync true/false prima del callback la invalida. Il listener false chiede un controllo, senza duplicarlo se è già accodato; non modifica i listener pubblici. Non eseguire il rilascio nella sola microtask: così il callback event viene accodato dopo le notifiche asincrone e lo zero-delay del finally prodotti nello stack terminale. È una barriera derivata da questo sorgente, non un timer di durata scelta né un generico rilevatore di dispatch.
3. Nel callback consumare il flag controllo accodato e verificare di nuovo revoca, rilascio non ancora effettuato, isRunningSync e validità della barriera. Se nel frattempo c’è stata una transizione ma il Command è già tornato idle, richiedere una nuova barriera dopo quell’ultimo settlement invece di riusare quella precedente. Questo evita il caso completion durante una barriera già accodata (R1.3); è un nuovo controllo giustificato dalla transizione osservata, non polling né retry di dispose. La sicurezza deriva **insieme** da autorità revocata, uscita da dispatch, barriera non invalidata sugli eventi terminali noti e stato attuale non-running; non da idle isolato. Un’azione ordinaria in attesa mantiene true; dopo un throw gestito il reporting originale precede il false. Il finally abbassa false anche per assertion, senza trasformarla in normale terminal failure.
4. Se ancora attivo, non disporre, non fare polling e non riaccodare tentativi periodici: attendere la prossima transizione sync false, che richiederà la stessa barriera. La transizione true invalida la barriera precedente senza programmare controlli periodici. Un nuovo run rientrante prima del controllo viene così rilevato; gli handler revocati non possono iniziare I/O. Nessun listener pubblico viene riattaccato.
5. Se sicuro, staccare il listener privato, marcare rilasciato **prima** dell’unica chiamata Command.dispose e non ritentare dispose. La successiva dismissione dei notifier interni resta quella upstream: Command.dispose marca _isDisposing e programma internamente il teardown a 50ms (799–825). Non duplicare quel timer, non chiamare direttamente dispose sui notifier interni e non usare quei 50ms come proxy del settlement dell’azione.

La microtask da sola basta a uscire dalla dispatch sincrona corrente, ma non a lasciare eseguire gli eventi asincroni upstream; la barriera microtask→event callback è il piccolo passo aggiuntivo motivato dal codice. Non affermare che misuri quiescenza di qualunque callback esterno arbitrario. La policy è specifica per le factory ordinarie risolte senza nuove restriction/progress handler; un upgrade richiede nuovo audit. Il callback event effettua il ricontrollo prima di avviare il rilascio upstream; una run dopo tale chiamata è rifiutata da _isDisposing.

**Teardown del notifier dell’owner:** anche Flutter ChangeNotifier.dispose asserisce depth==0 (SDK foundation/change_notifier.dart:376–383). Il caso Favourite results→VM.notify→listener.dispose renderebbe rientrante anche super.dispose del VM. Per questo programmare sempre la chiamata exactly-once a super.dispose del notifier dell’owner fuori dallo stack, tramite microtask dopo la revoca; non attendere per essa il Future repository. Tutti i notify e commit applicativi restano già bloccati da _disposed. Una dispatch iniziata prima della revoca può finire il proprio stack; non iniziano nuove dispatch pubbliche dopo la revoca. Non introdurre un tracker della profondità, un nuovo state holder o una nuova gerarchia per fermare retroattivamente callback già entrati.

Nessun manager lifecycle, nuova factory, reference counting, scheduler condiviso, polling, dispose retry illimitato, dipendenza o timeout arbitrario. I flag locali coalescono le richieste, invalidano le barriere antecedenti a nuove transizioni e garantiscono il rilascio exactly-once; la revoca rende idempotente il dispose dell’owner. Un Future non terminante conserva risorse private fino al settlement. Errori runtime tardivi continuano a raggiungere il global handler una volta senza errori secondari; assertion policy fail-loud invariata. Non usare il finally dell’azione, runAsync o soltanto results per dichiarare cleanup sicuro.

### Regression matrix R1.1–R1.6

Questi sono gate di apply con Command reali, Completer e clock virtuale già usati nel test support; non esiti già verificati. Riutilizzare le fixture e parameterizzare i casi comuni senza sei copie di logica; MockCommand non prova il lifecycle reale. Osservare identità e ordine degli eventi, non un numero preciso di microtask. Per il rilascio exactly-once si possono osservare gli eventi pubblici di disposal FlutterMemoryAllocations in debug, registrati prima della costruzione e filtrati per identità (SDK memory_allocations.dart), con restoration nel teardown; nessun contatore/API di test aggiunto in produzione. Accompagnare con assenza di doppio-dispose assertion e con review dei flag locali: la sola assenza di FlutterError non prova un rilascio avvenuto.

| Caso | Coordinazione deterministica | Risultato obbligatorio |
| --- | --- | --- |
| R1.1 terminale | Listener results terminale dispone owner durante la propria callback; includere anche listener del valore Command già logicamente idle | Revoca immediata, nessuna richiesta di teardown rientrante, nessun notifier-after-dispose, nessuna nuova notifica owner, rilascio privato exactly-once dopo la barriera |
| R1.2 idle | Dispose never-run o già completato; Theme anche con una lane idle e l’altra pendente | Sempre rilascio fuori stack, nessun secondo dispose; lane pendente sopravvive fino al proprio settlement |
| R1.3 stesso turno | Completer liberato e owner disposal nello stesso turno; coprire disposal prima e da callback terminale, e nuova transizione/settlement durante barriera già accodata | Nessuna collisione fra settlement/dispatch/cleanup, nessun report originale perso |
| R1.4 attivo | Owner revocato mentre Completer repository è ancora pendente, poi success/Result.error | Command vivo privatamente fino a settlement, zero nuovi commit/rollback/notify/fasi repository, rilascio una volta |
| R1.5 late failure | Dopo revoca liberare Completer con StateError originale; variante AssertionError con policy upstream invariata | StateError originale e stack al global handler una volta, nessun errore notifier secondario; assertion sul percorso fail-loud, non Result.error o report globale normale; cleanup privato una volta |
| R1.6 Favourite | Forwarder load.results invoca notify del VM, listener del VM dispone owner rientrantemente | Forwarding e cattura admission rimossi subito; anche teardown del notifier VM fuori dispatch; nessun commit/nuova notifica tardiva e Command rilasciato una volta |

Non cambiare gli skip upstream preesistenti per nascondere il bug: le nuove prove riguardano la policy owner che evita il dispose anticipato. Usare pump/event turn virtuali per la barriera e, ove necessario per osservare gli eventi di teardown fisico, il timer interno 50ms documentato; nessuna attesa reale o durata di sicurezza inventata.

| Owner | Guardie specifiche / risorse |
| --- | --- |
| Settings — decisione storica superata da CR-F1 | Un Command; guard dopo notify prima della write e dopo await prima di rollback/notify. Il precedente divieto di aggiornare anche SentryLoggingFlag dopo dispose era errato: vedere la remediation post-apply per la riconciliazione del consenso condiviso. |
| Theme | Due Command indipendenti; guard prima delle write e dei rollback/notify; scope app non sostituisce il lifecycle. |
| Explore | Un Command; guard prima dell’unico commit lista/notify, senza nuovo completion observer o payload. |
| Suggestion | Un Command; guard anche su assegnazione [] di errore; sostituire dispose immediato con settlement sicuro. |
| Favourite | Un Command più API write diretta; guard post-await e post-notify, prima delle lookup/fasi successive e dei rollback; separare revoca pubblica da cleanup del load. |

## Audit temporale Settings/Theme

Riletti VM, tutti i call site di setCrashReporting/setThemeBrightness/setThemeType, Consumer main.dart, test e SettingsRepositoryImpl su origin/main. L’implementazione del repository copia i settings al momento della chiamata e aggiorna la cache dopo persistenza riuscita; nessun intervento al repository è previsto. L’indipendenza locale delle lane non è una garanzia di fusione atomica delle scritture condivise: vedere R2 sotto.

| Fase | Legacy verificato | Factory ordinaria proposta |
| --- | --- | --- |
| 1. Ammissione | running=true e reset risultato nello stack execute; notifica Command | isRunningSync=true e snapshot loading nello stack run; duplicati già esclusi |
| 2. Aggiornamento locale | Action entra subito; assegna crashReporting/brightness/type; Theme cattura old-value | Action entra dopo Duration.zero; stessa assegnazione e cattura old-value |
| 3. Observer VM | notifyListeners sincrono dopo assegnazione | Identico ordine dentro action, più tardi rispetto a dispatch; guard se observer dispone |
| 4. Persistenza | Chiamata repository dopo notify, quindi await | Identico ordine dopo notify e guard live, quindi await |
| 5. Esito | Su Result.error rollback e notify; su success conserva valore. Settings sincronizza flag dopo esito | Stesse politiche live; dopo dispose nessun rollback/notify/flag; Result.error distinto dal raw throw |

**Differenza reale:** un getter letto nello stesso stack subito dopo run può ancora contenere il valore precedente; non è corretto sostenere timing identico. **Evidenza consumer:** SettingsScreen attende la write crash-reporting; brightness non ha continuazione dipendente dal getter; main.dart ricostruisce su notify. setThemeType non ha UI runtime attiva oltre ai test/routing che attendono il completamento. Nessun consumer verificato richiede same-stack optimism, né orchestra un’altra operazione in funzione di quel getter subito dopo dispatch. Le due lane Theme aggiornano campi distinti; nessun nuovo latest-wins o serializzazione comune.

**Decisione:** conservare l’ordine applicativo dentro l’azione e consentire esplicitamente ingresso differito nella delta. Il ritardo è osservabile al livello di chiamata sincrona, ma non emerge un cambiamento materiale dei contratti dei consumer attuali. Non introdurre un bridge per simulare l’ingresso inline o aggiornare stato da snapshot listener. Non promettere identico frame di rendering o sequenza universale di microtask.

**PREF1–5, regression gate:** registrare local value al notify e ingresso repository con Completer; local update/notify precedono write; successo mantiene valore, failure ripristina campo/flag; duplicati prima del primo pump e dal listener notify non scrivono due volte; type/brightness indipendenti con risposte rilasciate nei due ordini controllati, verificando esclusivamente stato/rollback locale e single-flight per lane, non l’assenza di lost update nel repository condiviso; widget Consumer si aggiorna durante persistence pending e rollback; dispose prima ingresso, dal notify e durante write impedisce le fasi vietate. Per Settings verificare zero snackbar su failure/throw/duplicato/cambio owner e uno sul successo enable della propria run. Nessun sleep o assertion sul numero preciso di microtask. Se la caratterizzazione sull’execution head trova un consumer con dipendenza same-stack, fermare affected apply e riconciliare il piano; non è una scelta architetturale già lasciata aperta.

### R2 — Rischio preesistente di lost update sul repository condiviso

VERIFICATO su origin/main: ThemeViewModel ha due Command separati (inizializzazione 11–12 e azioni 30–60); SettingsRepositoryImpl.setThemeBrightness/setThemeType costruiscono entrambi `_cache.copyWith(...)` (96–104). `_persistNewSettings` attende `_dataSource.save(newSettings)` e sostituisce `_settings` soltanto su Success (43–50). Non ci sono qui mutex, merge dopo await, aggiornamenti per campo o coordinamento transazionale fra le due lane.

**Rischio concreto, preesistente alla migrazione:** se A=brightness e B=type vengono costruiti dalla stessa cache S0 prima che una save completi, gli snapshot possono essere S_A=(brightness nuovo, type vecchio) e S_B=(brightness vecchio, type nuovo). Un ordine di completamento può lasciare cache e contenuto salvato corrispondenti a un solo snapshot e perdere l’altro aggiornamento; dipende dall’effettivo ordine di esecuzione/salvataggio. Il VM può comunque mostrare entrambi i campi nuovi. Questo esempio dimostra il rischio, non afferma che ogni esecuzione reale lo produca o che il Command lo introduca.

**Decisione e confine:** mantenere ammissione/esecuzione indipendenti, single-flight dentro ciascuna lane, ottimismo locale e rollback del solo campo pertinente. Questa change **non garantisce atomicità, serializzazione o assenza di lost update persistito fra campi differenti**. Il differimento dell’handler resta quello dichiarato da F4; nessuna promessa di identici interleaving globali. Una caratterizzazione che provi una regressione aggiuntiva introdotta dalla migrazione richiede riconciliazione del piano; non autorizza a correggere incidentalmente il rischio repository preesistente.

Correzione di tale rischio riservata a intervento separato, non creato né implementato qui: non modificare SettingsRepositoryImpl/data source, non aggiungere mutex, queue, transaction coordinator o serializzazione globale. È un limite noto accettato del perimetro, non un blocker nascosto da fare risolvere all’esecutore.

**Acceptance PREF corretta:** con repository fake controllabile, ammettere entrambe le lane, rifiutare un duplicato della stessa lane, osservare per ciascun campo update locale/notify prima della sua write e rollback locale solo su suo Result.error; rilasciare le due risposte in entrambi gli ordini, includendo combinazioni success/failure e dispose. Nessun nuovo accoppiamento fra i Command, nessun commit post-dispose. I risultati del fake dimostrano la logica ViewModel e non la correttezza persistente di due AppSettings reali. Non eliminare questi test, non aggiungere l’aspettativa che il repository finale contenga sempre entrambi i nuovi campi. Non modificare la delta per promettere garanzie persistenti nuove.

## Review adversariale Favourite — F2 riconciliato con F3

### Contratto e ammissione

VERIFICATO: autoload nel costruttore; isUpdating=load.running||_mutationRunning; setFavourite alza _mutationRunning prima dell’ottimismo; _load controlla _mutationRunning all’ingresso. Le mutazioni aggiungono/rimuovono ID e oggetti ottimisticamente e ripristinano esattamente liste/indici su Result.error. IDs deduplicati sopravvivono a mancata risoluzione dell’oggetto. _load pubblica un intero lato places prima di iniziare events; esegue anche il secondo lato se il primo ha dato Result.error e privilegia il primo errore. Un errore su un lato non elimina l’altro lato riuscito. Questa progressione è prevista e consentita dalla nuova MODIFIED.

PROPOSTO: admission di setFavourite usa `_disposed || load.isRunningSync.value || _mutationRunning`; isUpdating mantiene il controllo sync e il flag indipendente. Nessun aggiornamento post-dispose neppure nel finally di _mutationRunning. Il load continua a rifiutare una write attiva; il forwarder rimane necessario perché Screen/Button osservano VM e Provider. Un solo forwarder da results, rimosso al dispose; notifiche partial/optimistic del VM sono distinte e necessarie.

### F2c — Race inversa e cattura locale del rifiuto

INFERENZA verificabile dal sorgente: se load.run è chiamato durante una write e questa termina prima dell’handler differito, il solo guard attuale dentro _load vedrebbe _mutationRunning=false e partirebbe; il legacy avrebbe già restituito update-unavailable. Il retry di FavouriteScreen è un ingresso reale anche dopo precedente errore, quindi non ignorare questo caso.

Strategia concreta: aggiungere **un solo fatto di ammissione locale**, `_loadRejectedAtAdmission`, inizializzato false. Installare, prima dell’autoload, un listener isRunningSync che sulla transizione a true cattura `_mutationRunning`; quando running torna false non riscrive il fatto. All’ingresso _load controllare prima _disposed, poi il rifiuto catturato e il guard difensivo _mutationRunning; se bloccato ritorna lo stesso tipo di Result.error update-unavailable senza query. La successiva ammissione sovrascrive sempre la cattura; duplicate run o join runAsync non generano nuova transizione e non la alterano.

Single-flight garantisce un solo load ammesso e la mutazione non può iniziare dopo l’ammissione del load grazie al guard sync. Per questo il fatto non necessita di token, coda, Future o reset nel finally. È informazione storica non derivabile dal valore corrente di _mutationRunning: conservarla preserva un comportamento concreto. Il listener coordina solo l’ammissione, non esegue I/O/commit e non inoltra notifiche al VM; nessuna duplicazione del forwarder results. Viene rimosso al dispose prima del notifier. Questa soluzione copre anche chi invoca direttamente il Command pubblico e non introduce nuovi ingressi API, factory o adapter. Il relativo test rimane obbligatorio, non è una prova già eseguita.

### Commit progressivi, rollback e disposal

Guard dopo ogni attesa IDs/oggetto prima del commit e prima di altra lookup; accumulare ogni lato localmente come oggi e pubblicarlo soltanto live. Dopo il notify places, ripetere guard prima di events: un observer può disporre l’owner. Dopo ogni optimistic notify ripetere guard prima di _persistFavourite: l’I/O non iniziato deve essere saltato. Dopo write già avviata conservare Result/throw, ma saltare rollback e notify se disposed. _notifyListeners guard da solo non basta. Cleanup del load usa D5; non usare la direct write come motivo di introdurre un nuovo Command.

**Regression FAV1–8:** (1) constructor/load.run e mutazione immediata prima di pump → rejection, zero write; (2) write pending→load.run→write risolta prima dell’ingresso load → failure unavailable e zero query; duplicate/join non riscrivono cattura, successivo load live può riuscire; (3) seconda mutazione rifiutata; (4) progressive places mentre events pending, partial success nei due versi, primo errore, ID dedup/senza oggetto e retry; (5) rollback add/remove esatto con ordine e ID presente senza oggetto; (6) dispose in IDs/per-oggetto/tra lati/durante write e da notify prima di write o events: zero nuove fasi/commit/rollback/notify, outcome diretto preservato se write già avviata; (7) late StateError del Command una segnalazione originale, nessun FlutterError secondario, cleanup once, anche assertion/reentrant dispose; (8) forwarder aggiorna FavouriteScreen e riabilita FavouriteButton a start/terminal/retry. Tutti da verificare con Command reale, fake riusati e Completer, non MockCommand per le race.

**Stato F2:** strategia definita e compatibile con F3, non ancora implementata né verificata. I test esistenti coprono partial/rollback e alcune assenze di FlutterError dopo dispose; non dimostrano l’assenza di commit tardivi o tutte le race sopra.

## Simplification Opportunities and Decisions

Solo opportunità dei cinque owner residui. Gli ID rimasti conservano tracciabilità; le opportunità esclusivamente escluse non fanno più parte di questa tabella o dei task.

| ID / codice verificato | Complessità effettiva | Proposta e principio | Invarianti | Rischio | Test | Decisione |
| --- | --- | --- | --- | --- | --- | --- |
| S1: builder legacy leggono più getter di stato | Discriminazione ripetuta, rischio successo null/value conservato | Un snapshot results per build + extension esistente; KISS/DRY | Neutral, void, entrambi errori e retry distinti | Mancato rebuild/falso successo | Matrice widget stati/retry | ADOPT |
| S2: unawaited(execute) senza continuazioni | Future scartato non necessario con run | run diretto per bootstrap/retry/trigger senza seguito; Minimal Change/SRP | Una sola operazione, nessuna conferma dal Future | Rimuovere attesa realmente necessaria | Call count, Settings feedback separato | ADOPT |
| S5: forwarder Favourite load→VM | Apparente duplicazione, ma consumer ascoltano VM | Eliminarlo | Screen/Button aggiornati su load e membership | Perdita rebuild/riabilitazione | FAV8 | REJECT: mantenerlo su results; ha responsabilità distinta |
| S6: quattro rami add/remove Event/Place Favourite | Somiglianza sintattica con rollback e indici diversi | Helper generico mutazione | Esatto predecessore e ordine | Astrazione nasconde rollback | FAV5–6 | REJECT: Rule of Three non impone un’astrazione, beneficio non dimostrato |
| S7: _mutationRunning, _disposed, ID e oggetti Favourite | Non derivabili da load Result<void> | Unificarli nel Command load | Membership senza oggetto, mutazione diretta, lifecycle | Perdita ID/esclusione/rollback | FAV1–6 | REJECT: preservare stato indipendente; cattura F2c è un fatto diverso necessario |
| S8: disposer mancanti/immediati o incompleti | Teardown idle può essere rientrante, settlement non coincide con sola fine Future | Revoca immediata, barriera locale sempre microtask→event anche idle, cleanup once dopo ricontrollo; KISS/SRP | Reporting, no nuovi commit/notify, policy assertion | Retention nonterminante/rientranza | R1.1–R1.6 e guardie dei cinque VM | ADOPT: evita rilevamento dinamico della dispatch e manager |
| S9: cleanup locale simile nei cinque VM | Ripetizione reale con owner/observer differenti | Helper globale per tutte le migrazioni | Corretto teardown di ciascun owner | Framework lifecycle prematuro legato a dettagli upstream | Matrice lifecycle prima di futura valutazione | DEFER: nessun task/helper in questa change |

La delta F3 consente di tenere i commit nelle continuazioni vive: non introdurre payload, observer di commit o stato parallelo loading/completed/error solo per uniformare i VM. Non rimuovere stato necessario, non riscrivere repository, non uniformare retention Explore/Suggestion.

## Invarianti e acceptance gates

Sei Command migrati; cinque VM senza import/riferimenti legacy. Dodici identità eliminate, 113 preservate salvo drift riconciliato e nessuna nuova diagnostica. Nessun cambiamento dominio/repository/persistenza/backend/ObjectBox; nessuna API ID/N+1 per latest. local-content-retrieval conserva membership/ordine/limiti diretti; SuggestionViewModel non è Search.loadSuggestions. URI/Provider scope e router retention invariati.

Nessun redesign UX, con sola correzione esplicita del falso feedback Settings. Ordine ottimismo→notify→write→success/rollback preservato dentro le action, ingresso differito dichiarato; single-flight e autorità rispettati. Errori applicativi/runtime distinti, global reporting once, assertion policy intatta. Dopo dispose zero commit/notifiche/rollback locali o nuove fasi repository; command cleanup sempre fuori dispatch, anche idle, dopo settlement e ricontrollo secondo D5/R1.1–R1.6. Nessuna atomicità o serializzazione delle write Theme promessa (R2); i test garantiscono lo stato locale per lane, non l’assenza di lost update preesistente. Analyzer con argv/cwd/flag/versioni/exit grezzo acquisiti e ledger per identità (R3). Test cinque suite VM, widget pertinenti e integrazioni Provider/router verdi; suite Flutter completa verde con soli skip preesistenti identificati. Nessuna modifica ai Command delle altre sei change; nessun gate zero diagnostiche globali/rimozione command.dart.

## Risks / Trade-offs

- [Ingresso differito preferenze] → esplicitarlo, test ordine e consumer attuali, nessun ponte generico o promessa same-stack.
- [Race Favourite nelle due direzioni] → isRunningSync per mutazioni e cattura del rifiuto all’ammissione load; FAV1–2 deterministici.
- [Notify dispone rientrantemente l’owner] → guard anche dopo notify e prima delle nuove fasi I/O, non solo dopo await.
- [R1: teardown rientrante anche se idle] → revoca/detach subito; teardown del notifier owner fuori stack e rilascio Command sempre con barriera microtask→event, ricontrollo e flag exactly-once; R1.1–R1.6.
- [Late throw upstream dopo dispose] → Command trattenuto fino a settlement sicuro, reporting originale prima del rilascio, assertion fail-loud e nessun affidamento al solo idle.
- [R2: lost update persistito Theme preesistente] → dichiarare indipendenza locale senza atomicità/serializzazione repository; PREF verifica i campi del VM, correzione storage separata e nessuna infrastruttura aggiunta.
- [R3: exit/log analyzer non autosufficienti] → comando esatto, cwd, flag e returncode separati dal conteggio; replay nuovo distinto dalla prova storica e rigenerazione ledger per identità in apply.
- [Future non terminante] → retention privata senza timeout/cancellazione nuovi.
- [Write già iniziata dopo disposal] → nessun commit locale, nessuna promessa di annullamento persistente; outcome diretto preservato.
- [Feedback Settings attribuito a join/value vecchio] → ammissione check senza await, Result della propria run, owner/context correnti; error Future osservato senza secondo report.
- [Drift base/SDK] → rifare preflight, sorgente lifecycle e ledger prima degli edit; nessun upgrade implicito sotto caret.

## Migration Plan

Soltanto remediation documentale ora. Dopo review indipendente e autorizzazione apply, usare il branch comune alle sette change dalla base origin/main verificata; isolare il lavoro se il checkout utente è occupato e trasferire solo artifact approvati. Non importare vecchio codice PR3 o piani PR4. Caratterizzare poi migrare Settings/Theme, Explore/Suggestion, Favourite, consumer/routing e validare. Nessuna dipendenza da implementazioni future. Una sola PR finale, senza crearla ora. Rollback futuro circoscritto al diff attribuibile alla prima change, preservando lavoro altrui; nessun reset/clean globale.

Prima di test/edit di apply caricare skill test-support-reuse e dart-add-unit-test, skill widget/integration pertinenti, lifecycle per State/callback async, static-analysis. Riutilizzare supporto main aggiornato. Completer e pump virtuali per race, MockCommand solo per proiezioni; niente sleep o test seam produttivi. Test mirati prima della suite completa `flutter test --no-pub`, analisi e confronto completo rispetto alla base.

## Autoreview adversariale della remediation

| Finding | Severità / evidenza | Remediation documentale / stato |
| --- | --- | --- |
| F1 ingresso differito e nested orchestration | HIGH; action legacy inline contro zero timer upstream | RISOLTO PER ESCLUSIONE: futura change indipendente, nessun requisito/task qui |
| F3 disciplina unica sui commit | HIGH; testo canonico generale incompatibile con progressive/rollback | RISOLTO NEL PLANNING: MODIFIED autorizzata distingue lane, preserva scenario obsoleto e garanzie Search/GeoMap |
| F2 admission async e rollback/commit tardivi | HIGH; isRunning async, _load/mapError post-await | STRATEGIA DEFINITA: sync admission, flag write indipendente, progressione, guard lifecycle e safe cleanup; test apply obbligatori |
| F2c write finita prima dell’handler load | HIGH; zero timer prima del guard _mutationRunning | STRATEGIA DEFINITA: unico fatto di rifiuto catturato sulla sync admission; nessun bridge di esecuzione o API nuova |
| F4 timing ottimistico Settings/Theme | MEDIUM; getter può essere vecchio dopo dispatch | RISOLTO NEL PIANO: ritardo dichiarato, nessun consumer same-stack verificato, ordine applicativo conservato e PREF1–5 |
| F5 falso snackbar Settings | MEDIUM; callback attuale ignora esito Result | CORREZIONE ESPLICITA: feedback solo per proprio Success<void>, test failure/throw/duplicato/dispose |
| F6 dispose da notify prima della write/fase successiva | HIGH; notify sincrono seguito da I/O | STRATEGIA DEFINITA: guard post-notify oltre a post-await, outcome unavailable se write non avviata, no rollback tardivo |
| R1 cleanup idle/settlement dentro dispatch | HIGH; notifier sincroni, UI running async e assertion depth nei notifier | REMEDIATO: D5 sempre fuori stack/barriera, owner notifier differito, flag once e R1.1–R1.6; test futuri |
| R2 storage Theme condiviso | MEDIUM; copyWith da cache e save/cache commit successivo | REMEDIATO DOCUMENTALMENTE: rischio preesistente esplicito, nessuna garanzia persistente/nuova serializzazione; PREF locale |
| R3 baseline analyzer poco riproducibile | LOW; machine log non contiene argv/exit | REMEDIATO: comando/cwd/flag/SDK/adattamento URI/exit storico e replay indipendente misurato, con hash e provenienza ledger |

Nessuna assunzione di runAsync come prova di ammissione o successo; nessun catch Object→Result; nessuna rimozione di forwarding utile; niente cleanup prematuro; nessun refactoring di produzione per supportare le altre sei change. ADOPT integrati nei task feature, DEFER non diventano attività. Le strategie restano da implementare e verificare; questo non costituisce un blocker documentale quando decisioni ed esiti attesi sono concreti.

**READY FOR INDEPENDENT REVIEW.** Nessun blocker architetturale materiale noto resta aperto dopo le decisioni esplicite della remediation e l’audit aggiuntivo. Non significa review approvata, test superati o READY FOR APPLY. La review indipendente deve contestare in particolare la cattura F2c, disposal rientrante, attribuzione feedback e compatibilità della MODIFIED con i contratti restartable.

## Validazione della precedente remediation F1–F6 — 2026-10-19 (storica)

- `openspec validate migrate-simple-view-model-commands --strict --no-interactive`: eseguito, **exit 0**, change valida.
- `git diff --check`: eseguito, exit 0; controllo esplicito dei cinque file untracked della change: nessuno spazio finale/tab, newline finale presente.
- Coerenza: cinque artifact presenti; quattro modificati e .openspec.yaml invariato. Una delta con **1 requisito MODIFIED, 4 ADDED e 23 scenari**; **23 task con ID univoci, tutti unchecked**. Nessuna occorrenza di Category in requisiti o task; compare solo come esclusione/provenienza in proposal/design.
- MODIFIED corrisponde esattamente al nome canonico e conserva lo scenario preesistente Superseded retrieval returns data; gli altri sei blocchi canonici non sono modificati. Self-review semantica in D1 verifica che ordinary allowance non si applichi a Search/GeoMap e non alteri error reporting, assertion, ownership restartable o lifecycle.
- Confronto SHA-256 dei file tracked/untracked non ignorati rispetto all’inizio della remediation: cambiano soltanto proposal.md, design.md, tasks.md e specs/command-execution-concurrency/spec.md di questa change. Metadata, canonical dirette, produzione, test/support, dipendenze/config, AGENTS.md e piano PR4 preesistente invariati. Nessuna futura change creata.
- HEAD/branch/origin/main invariati rispetto al preflight, index vuoto; working tree finale conserva gli stessi tre elementi iniziali. Nessun apply, test d’implementazione, commit, push, PR o archivio. L’analisi baseline citata resta quella realmente eseguita nella fase precedente sul medesimo origin/main; nessun risultato futuro attribuito alla remediation.

Esito: **READY FOR INDEPENDENT REVIEW**; validazione strutturale positiva e assenza di blocker documentali noti non equivalgono ad approvazione architetturale o a readiness per apply. I regression test delle strategie restano gate futuri obbligatori.

## Autoreview e validazione R1–R3 — 2026-10-19

- **R1 completata nel planning:** D5 revoca/detach immediati, teardown owner fuori dalla propria notify, barriera locale anche per Command idle, invalidazione di una barriera antecedente a nuove transizioni, ricontrollo e rilascio exactly-once. Non considera idle/Future/microtask isolati prova universale di fine dispatch. Nessuna nuova infrastruttura, polling o sicurezza basata su delay arbitrario. Matrice R1.1–R1.6 concreta e integrata nei task owner/comuni; test futuri, non dichiarati superati.
- **R2 completata documentalmente:** rischio lost update preesistente riconosciuto con evidenza copyWith/save/cache; nessuna atomicità o serializzazione implicita, nessuna correzione repository o coordinator. PREF valuta ammissione/single-flight/update/rollback locale/post-dispose e non esiti di fusione persistente del fake. Il rischio MEDIUM resta presente nel prodotto come limite noto fuori perimetro, non è nascosto né richiesto di correggere per questa acceptance.
- **R3 completata:** comando/cwd/flag/default/SDK/URI temporanee ed exit storico distinti dalla nuova esecuzione; replay con returncode grezzo 0 e stdout identico al log originale, 125 INFO/0 WARNING/0 ERROR. Rigenerazione per identità richiesta in apply; nessun exit dedotto dal numero di diagnostiche o confuso fra Dart e Flutter wrapper.
- **Coerenza:** matrice dei sei Command e perimetro 5/6/12/113 invariati; sette OpenSpec/una PR finale; Category resta esclusa. F1–F6 e F2c preservati, setFavourite diretto, forwarding necessario mantenuto. MODIFIED F3 e gli scenari preesistenti non cambiano; la delta aggiunge soltanto il vincolo e uno scenario osservabile contro il teardown che invalida una dispatch terminale già in corso. Nessun requisito di persistenza aggiunto.
- **Conteggi attuali:** cinque artifact presenti, .openspec.yaml invariato; **24 task con ID univoci, tutti unchecked; 24 scenari**, un requisito MODIFIED e quattro ADDED. Il precedente conteggio 23/23 nella sezione storica è l’esito della remediation precedente, non quello corrente. S8 ADOPT rafforzata; S1/S2 ADOPT, S5/S6/S7 REJECT e S9 DEFER conservati.
- **Validazione eseguita:** `openspec validate migrate-simple-view-model-commands --strict --no-interactive`, `git diff --check` e `git diff --cached --check` exit 0; whitespace/newline controllati anche nei cinque file untracked, senza problemi. Hash iniziali/finali dei file tracked/untracked non ignorati confermano soltanto i quattro artifact autorizzati modificati; .openspec.yaml, canonical dirette, AGENTS.md, piano PR4, produzione, test/support e dipendenze/config invariati.
- **Git:** HEAD `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`, branch `codex/resolve-flutter-analyzer-diagnostics-pr3`, origin/main dopo fetch `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, index vuoto. Stato iniziale/finale: AGENTS.md modificato e directory untracked di questa change e PR4, nessun altro cambiamento.

**READY FOR INDEPENDENT REVIEW.** R1, R2 e R3 sono tutte applicate agli artifact; nessun blocker documentale o architetturale noto rimane aperto. Il rischio persistente R2 è deliberatamente documentato come preesistente, non risolto in produzione. Nessun apply, suite Flutter completa, commit/push/PR/merge/archive eseguito. La validazione strict non è READY FOR APPLY e non sostituisce la successiva review indipendente.


## Apply evidence — 2026-10-20

### A. Baseline e ambiente

Apply esplicitamente autorizzato dal prompt utente del 2026-10-20; le etichette
storiche READY FOR INDEPENDENT REVIEW nelle sezioni precedenti descrivono il
planning, non lo stato corrente. Worktree e branch:
`/Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-simple-view-model-commands`,
`migrate-simple-view-model-commands`. HEAD iniziale/finale e origin/main locale:
`ee60777c7fdfc5c16daa1151050c134fbb7cde29`. Il confronto con la base storica
`d16f737` cambia soltanto AGENTS/skill e relativi metadata; nessun drift del codice,
delle foundation, delle dipendenze o dei contratti canonici interessati.
Nessun nuovo fetch/sync/checkout/worktree/commit/push/PR eseguito nell’apply.

Stato iniziale: soltanto la directory untracked dei cinque artifact revisionati.
Stato finale: diff di implementazione/test e artifact disponibile non committato;
index vuoto. Gli artifact non sono stati importati dal codice PR3.
Flutter 3.47.5, framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`,
Dart 3.13.4, command_it 9.5.2 e listen_it 6.0.0. Nessun pub get/upgrade.

Il worktree non aveva `.dart_tool/package_config.json` né `package_graph.json`:
sono stati preparati come metadata ignorati e temporanei dalle dipendenze già
risolte del checkout principale, adattando soltanto moliseis.rootUri alla URI
assoluta risolta del worktree. Nessun file di configurazione tracked cambiato.
Il wrapper Flutter richiede scrittura nella cache SDK esterna al sandbox.

### B. Sei Command implementati

| Owner / operazione | Factory e consumer | Concorrenza e lifecycle |
| --- | --- | --- |
| Settings / setCrashReporting | createResultCommand<bool, void>; SettingsScreen attende il Result della propria richiesta ammessa | Single-flight; ottimismo/notify prima della write; rollback e flag soltanto live; isDisposed impedisce feedback e ammissione da owner revocato |
| Theme / setThemeBrightness | createResultCommand<ThemeBrightness, void>; SettingsScreen usa run | Lane indipendente; old brightness e rollback locale; guardie prima I/O e dopo await |
| Theme / setThemeType | createResultCommand<ThemeType, void>; sync_redirect_test osserva runAsync con pump virtuale e verifica il Result | Lane indipendente; old type e rollback locale; selettore commentato resta inattivo |
| Explore / loadLatest | createResultCommandNoParam<void>; bootstrap/retry run; latest di ExploreScreen osserva results | Single-flight; commit atomico della lista live; retention su errore e svuotamento su successo vuoto |
| Suggestion / load | createResultCommandNoParam<void>; bootstrap/retry run; SuggestiondHorizontalListView osserva results | Single-flight; skeleton neutral/loading; errore svuota la lista; successo vuoto distinto; lista non modificabile |
| Favourite / load | createResultCommandNoParam<void>; bootstrap/retry run; FavouriteScreen usa snapshot, Button resta API diretta | Single-flight e cattura sync F2c; pubblicazioni progressive vive; forwarding results→VM mantenuto e staccato alla revoca |

Tutti gli owner applicano D5 localmente: revoca idempotente immediata, guardie
all’ingresso/post-notify/post-await, super.dispose in microtask; Command attivi
trattenuti privatamente. Cleanup microtask→event, controllo running e barriera
invalidata dalle transizioni sync, listener privato rimosso e rilascio marcato
prima dell’unica dispose. Nessuna nuova factory o astrazione lifecycle globale.
S1/S2/S8 adottati; S5/S6/S7 rispettati come REJECT e S9 come DEFER.

Differenze intenzionali: ingresso differito delle preferenze; failure runtime
separata da Result.error secondo foundation; snackbar Settings soltanto per
Success<void> enable della propria richiesta, context montato e stesso owner live.
Invocazioni ignorate/join, failure, throw, unmount, dispose e cambio owner non
producono feedback positivo. Il rischio repository Theme R2 resta invariato:
nessun mutex, serializzazione o garanzia di fusione persistente introdotta.

### C. Favourite — evidenze

- F2: isRunningSync respinge write anche immediatamente dopo il bootstrap;
  _mutationRunning conserva l’esclusione della seconda write.
- F2c: listener sync installato prima dell’autoload cattura il rifiuto a ogni
  nuova ammissione; duplicate/join non lo riscrivono. Write completata prima
  dell’handler load → unavailable, zero nuove query; load successivo libero riesce.
- Places sono pubblicati prima di events; successo parziale nei due versi,
  retention del lato precedente fallito e primo errore sono conservati.
- IDs deduplicati e membership senza oggetto completo restano osservabili.
  Add/remove conservano rollback esatto e ordine per Event/Place.
- Dispose durante IDs/lookup, tra lati, durante write o dalla notify ottimistica
  impedisce nuovi commit, rollback, notifiche e fasi I/O. Una write già avviata
  conserva il proprio Result/throw diretto; StateError tardivo non entra nel
  reporting globale del Command e non annulla l’ottimismo dopo la revoca.
- Forwarding load.results→VM verificato con Provider reale in Screen/Button,
  inclusi errore/retry e riabilitazione. Dispose rientrante coperto separatamente.

### D. Lifecycle R1.1–R1.6

`test/ui/ordinary_view_model_lifecycle_test.dart`: 79 casi con Command reali sulle
sei lane; supporto in `test/support/ordinary_view_model_lifecycle_support.dart`.
R1.1 listener terminale results/value; R1.2 never-run/completato e Theme con altra
lane idle; R1.3 entrambi gli ordini settlement/dispose e transizioni true→false
che invalidano una barriera accodata; R1.4 success/error pendenti e revoca prima
dell’ingresso; R1.5 StateError/ArgumentError con oggetto e stack originali once,
AssertionError nel percorso fail-loud originale; R1.6 forwarding Favourite che
provoca dispose dalla notify del VM. Aggiunta la revoca dalla notify ottimistica
Settings e dalle due lane Theme prima di qualsiasi persistenza.

Gli eventi pubblici FlutterMemoryAllocations ObjectDisposed sono filtrati per
identità, provando zero release durante dispatch/pending e una release dopo
settlement, anche con dispose duplicato. Non si usa soltanto l’assenza di errori.
Handler globali e probe SDK vengono ripristinati; nessun seam di produzione.
Event turns e timer upstream 50 ms sono mossi nel clock virtuale, senza sleep.
Un Future che non termina conserva le risorse private: limite deliberato senza
timeout né promessa di cancellazione della write esterna.

### E. Analyzer R3

Stesso eseguibile e argv baseline/finale, cwd il worktree dedicato:

```text
/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-simple-view-model-commands
```

Default warning fatal e info non fatal; nessun --fatal-infos. Exit grezzo
baseline **0**, finale **0**; stderr entrambi vuoti. **125 INFO → 113 INFO**,
zero warning/errori in entrambe le esecuzioni. Confronto Counter per
path/regola/messaggio (simbolo e contesto), normalizzando root e spostamenti di
linea: esattamente dodici identità rimosse, zero nuove, tutte le 113 residue
inalterate anche nella molteplicità. Le identità originarie sono:

| File lib/ui | Linea:colonna baseline | Eliminate |
| --- | --- | ---: |
| settings/view_models/settings_view_model.dart | 13:25, 21:8 | 2 |
| settings/view_models/theme_view_model.dart | 11:26, 12:20, 25:8, 27:8 | 4 |
| explore/view_models/explore_view_model.dart | 15:18, 21:8 | 2 |
| explore/view_models/suggestion_view_model.dart | 13:12, 21:8 | 2 |
| favourite/view_models/favourite_view_model.dart | 20:12, 29:14 | 2 |

Nessun flutter analyze eseguito; nessun suo exit viene dedotto da quello Dart.
Log stdout/stderr, metadati argv/cwd/SHA/versioni, ledger baseline/finale e
confronto JSON sono in `/private/tmp/molise-simple-apply-evidence/`.

### F. Test realmente eseguiti

- Baseline cinque suite legacy: 34 passati; caratterizzazione preferenze legacy:
  11 passati; caratterizzazione Favourite write→load: 1 passato prima degli edit.
- Settings/Theme + widget: 31 passati nel primo gate; aggiunte successive dei
  widget Settings/Favourite: 21 passati nel run mirato (suite sovrapposte).
- Explore/Suggestion/Home: 24 passati nel gate C.
- Favourite: 23 passati nel gate D, poi 25 nella versione finale con late throw
  diretto e dispose durante lookup events.
- Matrice lifecycle iniziale: 76 passati; finale: 79. Ultimo run mirato combinato
  lifecycle + Favourite: **104 passati**, exit 0.
- Router sync + quattro suite foundation: **65 passati, 3 skip preesistenti**,
  exit 0. Foundation comprende result_command, restartable_command,
  command_configuration e command_it_disposal_behavior.
- Integrazioni Provider/router dopo adattamento cleanup: 277 passati, uno skip;
  l’unico failure di quel run era il runtime ObjectBox non caricato da shell.
  Smoke DI con runtime correttamente caricato: 1 passato, exit 0.
- Suite completa finale: **2366 passati, 0 falliti, 6 skip preesistenti**, exit 0.
  I 191 eventi framework hidden non sono contati come test applicativi passati.

Il primo run completo è fallito per runtime nativo ObjectBox assente e timer
pendenti dopo l’unmount automatico dei Provider migrati. Nessuna asserzione è
stata indebolita: il supporto testOwnerUI esegue i callback originali e poi
unmount + drain virtuale della barriera e teardown upstream. I test di altre
feature toccati per questo motivo cambiano soltanto registrazione/import e
formattazione; nessuna loro logica di produzione è stata migrata.

Runtime test ObjectBox C 5.3.2 ufficiale macOS, esclusivamente in /private/tmp;
archivio objectbox-macos-universal.zip SHA-256
`680c598573ede04b9762565d48d4e161ad286f786f159abb8da89353bfa1d0bc`,
verificato contro il digest della release ufficiale. Nessuna dipendenza cambiata.
La shell macOS perde DYLD_LIBRARY_PATH: il run completo finale ha avviato lo
stesso tool Flutter direttamente, con comando effettivo:

```text
DYLD_LIBRARY_PATH=/private/tmp/molise-simple-apply-evidence/runtime/lib TZ=Europe/Rome /opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart /opt/homebrew/share/flutter/bin/cache/flutter_tools.snapshot test --no-pub --reporter json
```

L’exit 0 appartiene a questo processo, non al precedente wrapper fallito.
Risultati machine e metadati: full-suite-final.jsonl/.stderr/.json nella directory
delle evidenze. I sei skip sono gli stessi presenti in HEAD:
all_day_pipeline locale; external_event_token_pipeline locale; tre casi upstream
late StateError di command_it_disposal_behavior; inactive branch Back upstream
#188018 in geo_map_route_test. Nessun nuovo skip o servizio esterno simulato come
verifica eseguita; i due smoke locali Supabase/Deno restano non eseguiti.

### G. OpenSpec e coerenza

24 task verificati, nessuna canonical sincronizzata o change archiviata.
OpenSpec 1.14.3 strict aveva rilevato quattro warning di lunghezza >500 nei
requisiti ADDED approvati. Le quattro formulazioni sono state rese più concise,
conservando nomi, obblighi e tutti i 24 scenari invariati; nessun cambio dei
contratti D1–D5, F2c o perimetro. La validazione strict successiva è verde,
exit 0. Metadata/proposal invariati; design/tasks/delta aggiornati coerentemente.

### H. Autoreview e review adversariale

Audit completo rispetto a HEAD/base approvata: produzione limitata a cinque VM
e quattro consumer; nessuna modifica foundation, command.dart, dominio,
repository, DI, router, database/backend, generati, dipendenze, analyzer o CI.
Le sole modifiche agli altri test Provider/router servono al cleanup degli owner
migrati. Riletti ammissione e join, rollback e progressive publication, notify
rientranti, teardown idle/pending/assertion, reporting once e feedback Settings.
Review avversariale separata in sola lettura da agente reviewer: nessun finding
materiale residuo. Le verifiche eseguite sono quelle riportate sopra; il reviewer
non ha rivendicato test autonomi. L’approvazione indipendente dell’utente resta
separata da questa autoreview dell’apply.

### I. Readiness storica dell’apply

Questo verdetto precede la code review CR-F1–CR-F3; lo stato corrente è nella sezione post-apply seguente.

**READY FOR INDEPENDENT CODE REVIEW** per questa prima change soltanto.
Diff lasciato non committato; nessun push, PR, merge, sync canonical, archive o
avvio automatico delle altre sei change. Restano i limiti espliciti di R2 e del
Future fisicamente non terminante, non blocker nascosti né garanzie aggiunte.


## Remediation post-apply — CR-F1–CR-F3

### Stato e provenienza

La review indipendente successiva all’apply ha riscontrato CR-F1 HIGH (consenso
Sentry non riconciliato dopo dispose), CR-F2 MEDIUM (stato documentale obsoleto)
e CR-F3 LOW (wrapper test esteso senza audit selettivo). Questi ID non sono i
finding omonimi della review del piano del 2026-10-19. Il prompt di remediation
è l’autorizzazione corrente. La precedente readiness dell’apply è un esito
storico, non la risoluzione di questi finding né un’approvazione al merge.

Preflight corrente: worktree dedicato e branch migrate-simple-view-model-commands;
HEAD e origin/main locale restano ee60777c7fdfc5c16daa1151050c134fbb7cde29.
L’implementazione era già non committata; nessun reset, checkout, fetch/sync,
commit, push, PR o modifica al checkout principale. Sono stati acquisiti hash
dei file tracked/untracked e stato iniziale in
/private/tmp/molise-simple-remediation/initial-hashes.json e initial-status.txt.

### CR-F1 — consenso condiviso distinto dalla presentazione

**Root cause verificata:** il guard _disposed dopo l’await della write impediva
anche l’aggiornamento di SentryLoggingFlag. Una disattivazione già persistita
poteva così lasciare attiva la telemetria. Il vincolo D5 sulla presentazione era
stato impropriamente esteso a uno stato applicativo condiviso da AppLogger.

**Correzione minima:** alla normale restituzione del Result, prima del guard di
presentazione, SettingsViewModel assegna il flag da
_settingsRepository.crashReporting. Non usa enable né _crashReporting come
valore autoritativo. SettingsRepositoryImpl._persistNewSettings aggiorna la
cache solo dopo Success della save e prima di completare il Future; il getter
legge quella cache senza I/O. Lettura e assegnazione del flag sono sincrone e
senza await/notify intermedio: una continuation consegnata tardi legge il valore
repository corrente, non uno snapshot catturato dal vecchio owner.

Un Result.error mantiene identità ed esito e non committa la cache; anche in
questo caso il flag riflette il consenso confermato corrente, mai la richiesta
fallita. Un throw inatteso non aggiorna la cache in questa implementazione e
resta sul reporting command_it originale; non è aggiunto alcun catch/finally
che lo converta o lo segnali due volte. Assertion policy e D5 sono invariati.
Ottimismo, rollback e notify restano vietati dopo revoca. Le nuove write restano
bloccate; la riconciliazione non avvia nuove fasi repository.

**Concorrenza e limite:** nessuna serializzazione o latest-request-wins aggiunta.
Il repository persiste snapshot interi e può perdere aggiornamenti concorrenti
fra preferenze, come già documentato in R2. Il flag segue il consenso della cache
confermata attuale, che può riflettere una richiesta più vecchia se quella è
l’ultima write a completare. Non si promette atomicità fra storage/cache/flag
attraverso gli await né cancellazione remota di write iniziate. Non viene risolto
il rischio generale di snapshot concorrenti, né introdotto un coordinator.

**Regression F1.1–F1.6:** settings_view_model_test aggiunge sei casi deterministici:
disable/enable dopo dispose, Result.error originale, entrambi gli ordini di commit
con consegna invertita dei Results e StateError tardivo originale once. Usano
SettingsRepositoryImpl reale, FakeSettingsLocalDataSource con callback save
opzionale e lo stesso flag per gli owner A/B. DeferredSettingsRepository è un
fixture solo test che ritarda la consegna dopo il vero commit/cache: dimostra la
race senza cambiare API o seam di produzione. La sua attesa non rappresenta una
nuova garanzia del repository. Le prove confrontano anche persistenza simulata,
cache, flag, assenza di notify/rollback tardivi e controllo del primo ingresso I/O.

F1.6 conserva i casi SettingsScreen per successo della propria richiesta,
duplicate admission, dispose, unmount, owner replacement con stesso context,
Result.error e throw. SettingsScreen e AppLogger non cambiano. La matrice comune
R1 resta una prova di stato **di presentazione**: il suo snapshot Settings non
include più il flag condiviso, ora verificato separatamente dai sei nuovi test
con assert positivi di riconciliazione. Le prove di rilascio SDK exactly-once,
reporting e fail-loud non sono rimosse o sostituite da teardown generico.

### CR-F2 — tracciabilità degli artifact

Proposal distingue ora stato corrente, planning storico, remediation documentali,
autorizzazione e apply eseguito. Il design originario resta consultabile come
storia; la tabella Settings segnala esplicitamente l’ipotesi errata superata da
CR-F1. La delta MODIFIED precisa “presentation commits” e aggiunge soltanto la
riconciliazione del consenso corrente da repository, senza I/O né riattribuzione
di autorità UI e senza modificare il paragrafo restartable Search/Map. Due scenari
coprono owner disposto e commit/delivery invertiti: 24 scenari originali più 2.
Nessuna canonical modificata. Task 2.3 e gate 6.1–6.4 riaperti selettivamente
finché riverificati; task 7.1–7.3 esplicitano F1–F3, senza riaprire il resto.

### CR-F3 — audit selettivo del test support

Audit di tutti i 160 siti di registrazione testOwnerUI in 18 file rispetto allo
snapshot iniziale della remediation. Due probe senza wrapper hanno mantenuto
callback, assert e skip: 154 esecuzioni hanno fallito intenzionalmente soltanto
per “A Timer is still pending even after the widget tree was disposed.” Ogni sito
KEEP ha almeno un caso generato con quella prova, attribuita dagli stack agli
owner migrati. Non è una nuova necessità architetturale delle feature escluse:
è il teardown delle fixture che istanziano quei Provider, spesso al root.

| Gruppo di test | Decisione | Motivazione verificata |
| --- | --- | --- |
| Consumer diretti migrati | KEEP selettivo / REVERT | Explore mantiene 7 siti; FavouriteButton 8, Screen 1 e disposal VM 2. Suggestion ripristina tutti i 7 testWidgets: owner esterno e teardown già equivalente. Settings mantiene i propri test con cleanup esplicito. |
| Routing con owner migrati | KEEP selettivo | Mantiene solo percorsi che istanziano Explore/Suggestion o root Favourite/Settings/Theme e falliscono realmente senza drain. Restoration e ownership del router non vengono modificate. |
| Feature non migrate | REVERT dove indipendenti | Admin conserva solo 3 casi Settings; Content Submission solo 2 siti che raggiungono Home. Nearby ripristina tutti gli 8 testWidgets: in 2 casi bastano pumpCommandTurns locali per i timer zero del bootstrap Favourite esterno; nessun teardown Provider necessario. Events mantiene solo il caso con card che istanzia il Favourite lazy. |
| Foundation e lifecycle | KEEP prove esplicite; nessun nuovo wrapper | Restano testWidgets e controlli SDK exactly-once, reporting/assertion e interleaving. Il wrapper non è una prova del rilascio; nessuna sostituzione della matrice R1. |

| File | Original wrapper sites | KEEP | REVERT | Evidence / actual dependency |
|---|---:|---:|---:|---|
| `test/ui/core/ui/content/nearby_content_horizontal_list_test.dart` | 8 | 0 | 8 | All 8 revert. Two external `.value` Favourite owners leave constructor automatic-run zero timers; a local `pumpCommandTurns` at callback end drains them. No owned-provider teardown needed. Other 6 already drain/dispose or create no migrated owner. |
| `test/ui/event/widgets/events_screen_test.dart` | 3 | 1 | 2 | Only the nonempty current-day rendering creates the lazy Favourite Provider through event-card Consumers; its constructor/disposal timer needs virtual drain. Empty/error calendar cases never instantiate it. |
| `test/routing/admin_route_test.dart` | 13 | 3 | 10 | Only 3 Settings-screen cases instantiate Settings/Theme providers; 10 authentication/admin/editor/error cases do not. |
| `test/routing/content_submission_route_test.dart` | 27 | 2 | 25 | Only 2 registration sites reach real Home/Explore (successful Home action, failed progress Home exit). Other form/progress/session cases never create migrated owners. |
| `test/routing/route_ownership_test.dart` | 19 | 13 | 6 | Real Post/card paths instantiate root Favourite Provider; stub roots, category/search-only empty paths and unavailable Gallery leave it lazy/uncreated. Keep only reproduced paths. |
| `test/routing/geo_map_route_test.dart` | 22 | 19 | 3 | Real retained Home and populated selected/map/chrome paths instantiate Explore/Suggestion/root Favourite; remove the preexisting skipped registration, explicit route-destruction cleanup case, and direct-map case with no retained Home owner. |
| `test/routing/route_parameter_redirect_test.dart` | 15 | 4 | 11 | Only canonical populated Post, canonical Category Post, cold Search Post and search text round-trip registrations create root Favourite; invalid/error-only and empty category/search cases do not. |
| `test/routing/main_navigation_restoration_test.dart` | 2 | 2 | 0 | Production restored Map/Search Post paths create migrated root Favourite; wrapper acts after restoration assertions, does not manipulate router restoration. |
| `test/routing/events_route_test.dart` | 1 | 1 | 0 | Retained production Home creates Explore/Suggestion and root Favourite owners before Events navigation. |
| `test/routing/home_event_discovery_test.dart` | 6 | 5 | 1 | Five registrations retain real Home Explore/Suggestion; explicit-unmount regression already drains cleanup and reverts. |
| `test/routing/sync_redirect_test.dart` | 16 | 13 | 3 | Retained Home paths own Explore/Suggestion/Favourite; Settings and real MoliseIsApp paths additionally instantiate root Settings/Theme. Error routing after Home still retains those owners. 3 admin/fatal paths never instantiate migrated owners and pass without wrapper. |
| `test/main_scroll_behavior_test.dart` | 2 | 2 | 0 | Actual MoliseIsApp/Home root Provider creates migrated Theme/Explore/Suggestion owners despite unrelated scroll assertion. Existing explicit unmount needs event/50 ms drain. |
| `test/config/dependencies_test.dart` | 1 | 1 | 0 | Directly resolves all advertised root providers including Settings, Theme and Favourite; production-owned disposal needs virtual teardown drain. |
| `test/ui/explore/widgets/explore_screen_test.dart` | 7 | 7 | 0 | All execute production Home with Provider-owned migrated Explore/Suggestion and root Favourite. |
| `test/ui/explore/widgets/suggestion_horizontal_list_view_test.dart` | 7 | 0 | 7 | All 7 revert: fixture owns VM externally; pumpAndSettle and existing explicit loop unmount/dispose/drain already suffice; no added wrapper obligation. |
| `test/ui/favourite/widgets/favourite_button_test.dart` | 8 | 8 | 0 | All instantiate migrated Favourite via owning Provider; actual owner disposal leaves local requestCleanup timer. |
| `test/ui/favourite/widgets/favourite_screen_test.dart` | 1 | 1 | 0 | Owning Provider forwards migrated Favourite load; real cleanup timer reproduced. |
| `test/ui/favourite/view_models/favourite_view_model_test.dart` | 2 | 2 | 0 | Two explicit disposal regression registrations create migrated command cleanup; preserve wrapper to advance its documented internal 50 ms timer. Assertions remain inside callbacks. |

Totals: **160 → 84 retained / 76 removed**. Only registration names changed except two local virtual-clock drains in nearby-content tests. No original assertions, callbacks (other than these drains), variants, skip metadata, production code, or router fixtures changed for F3.


Il helper condiviso rimane invariato: solo clock virtuale, nessun catch,
takeException, handler globale, skip automatico o accesso al router. Le sue
registrazioni passano gli stessi callback, varianti e skip al runner. Errori
sincroni e asincroni non vengono consumati: nessun catch o lettura delle
eccezioni del framework è stato aggiunto dal helper. I 270 nomi dei casi
sottoposti a probe compaiono nel run finale dell’audit. Restano 84 KEEP, 76 REVERT;
10 file ridotti, nessuna asserzione originaria persa. La documentazione completa
per singola esecuzione è in /private/tmp/molise-simple-remediation/f3-audit.json.

### Validazione post-remediation

- Mirati F1/Settings UI/Theme/lifecycle: 117 passati, exit 0.
- Audit finale dei 18 file F3: 291 passati, 0 falliti, 1 skip preesistente, exit 0.
- Quattro suite foundation più SettingsRepositoryImpl: 49 passati, 3 skip
  preesistenti, exit 0.
- Suite Flutter completa: **2372 passati, 0 falliti, 6 skip preesistenti**,
  exit grezzo 0. I sei skip coincidono per identità con il run dell’apply:
  due smoke locali esterni, tre casi upstream command_it e #188018.
- Ultimo aggiustamento esclusivamente nominale del super parametro nella fixture
  test (dataSource → _dataSource, per matching_super_parameters): 17 test mirati
  Settings VM/repository ripetuti e verdi, poi analyzer finale confrontato.
- Analyzer finale: **113 INFO, 0 WARNING, 0 ERROR, exit grezzo 0**; zero identità
  aggiunte/rimosse rispetto alle 113 approvate dopo apply. Le 12 identità target
  restano assenti rispetto alle 125 originali. Stessi eseguibile/argv/cwd della
  sezione R3, nessuna modifica al package_config nella remediation, stderr vuoto.
- OpenSpec strict, git diff --check e git diff --cached --check: exit 0;
  whitespace/newline verificati anche per i file untracked.
- Formattati solo i 15 Dart modificati durante la remediation. Nessuna modifica
  tracked a repository, backend, dominio, logging, foundation, DI/router,
  dipendenze, generati, analyzer, CI o specifiche canoniche.

Analyzer: il riferimento approvato resta il ledger apply a 113 INFO. Il primo
lancio durante i probe F3 ha osservato 10 import temporaneamente inutilizzati
(123 diagnostiche, exit 2): è un’analisi sovrapposta all’esperimento, scartata come
baseline stabile e conservata in baseline.stdout/.stderr/.json per trasparenza.
Il confronto finale usa identità/molteplicità del ledger approvato, non
quel tentativo transitorio, senza soppressioni o modifiche alle regole.

### Autoreview e closeout corrente

Riesaminati lettura cache/assegnazione flag sincrone, ordine commit/delivery,
Result.error/throw/assertion, guardie UI/feedback, teardown D5, fixture e wrapper.
Una review avversariale separata in sola lettura ha verificato F1, la copertura
positiva distinta dal snapshot di presentazione, F2 e il confronto selettivo dei
18 file F3: nessun finding materiale residuo. Il reviewer non ha eseguito test;
ha ispezionato sorgenti, diff e log dei run riportati, senza sostituire la nuova
review indipendente dell’utente. Nessun ampliamento architetturale necessario.

La remediation modifica 19 file: un file di produzione (SettingsViewModel),
settings_view_model_test, tre file di supporto (ordinary_view_model_lifecycle_support,
settings_local_data_source, il nuovo settings_consent_support), dieci file di test
ridotti per F3 e quattro artifact di questa change. Elenco completo e hash
iniziali: remediation-files.json e initial-hashes.json nelle evidenze temporanee.
Nessun file iniziale eliminato, nessuna modifica alle altre change o al checkout
principale. HEAD/branch/origin/main e index vuoto restano quelli del preflight.

Evidenze riproducibili in /private/tmp/molise-simple-remediation/: f1-targeted.log,
f3-audit.md/.json, f3-probe1.jsonl, f3-probe2.jsonl, f3-final.jsonl,
foundation.log, constructor-final-check.log, full-suite.jsonl/.stderr/.json,
final.stdout/.stderr/.json e analyzer-comparison.json. Il run Flutter conserva
lo stesso ambiente già verificato durante apply: runtime ObjectBox ufficiale
5.3.2 temporaneo e TZ=Europe/Rome. Comando effettivo completo:

```text
DYLD_LIBRARY_PATH=/private/tmp/molise-simple-apply-evidence/runtime/lib TZ=Europe/Rome /opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart /opt/homebrew/share/flutter/bin/cache/flutter_tools.snapshot test --no-pub --reporter json
```

**Stato corrente: READY FOR INDEPENDENT CODE REVIEW.** CR-F1, CR-F2 e CR-F3
risolti; non è readiness al merge. Nessun commit, push, PR, merge, archive,
sync canonical o avvio della seconda change. Restano soltanto i limiti
preesistenti esplicitamente documentati, senza blocker materiale residuo.
