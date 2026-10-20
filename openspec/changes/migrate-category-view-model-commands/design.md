# Design

## Context

Vedere proposal.md per problema e perimetro. Questo documento distingue **FATTO** (sorgenti, output effettivi), **INFERENZA** (interleaving ricostruite, non prove runtime già eseguite) e **PROPOSTA** (contratto del futuro apply). Planning autorizzato esplicitamente il 2026-10-20; successiva remediation documentale F1/F2 richiesta dalla review indipendente. Questa introduzione e le sezioni iniziali descrivono il piano e le sue evidenze storiche. **Stato corrente: apply autorizzato il 2026-10-20, successivo alla remediation F1/F2/RF3**; implementazione, precisazioni e gate effettivi nella sezione finale «Evidenze dell’apply». Nessuna autorizzazione a commit/push/PR/merge/archive/sync canonical.

### Baseline e provenienza verificate — planning iniziale

- Repository `xmattjus/moliseis`, origin fetch/push `https://github.com/xmattjus/moliseis.git`.
- Worktree esclusivo: `/Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-category-view-model-commands`.
- Branch locale: `codex/plan-migrate-category-view-model-commands`.
- HEAD: `9d17d224d5094c5b043128113d9aba6a1ce69f0a`. Creato nel turno precedente con `git worktree add -b <branch> <path> <checkpoint>`, senza merge/cherry-pick. Il percorso già presente in questo turno è proprio il worktree autorizzato appena creato, non una collisione con lavoro estraneo: identità, branch e stato pulito riconfermati prima di scrivere.
- `git fetch origin` ripetuto dal worktree dedicato: exit 0. `origin/codex/migrate-legacy-commands` e metadata GitHub della Draft PR #12 (`draft=true`, `state=open`, `head=codex/migrate-legacy-commands`) hanno lo stesso SHA. La richiesta corrente autorizza direttamente il planning; il precedente testo storico dei gate nella PR non autorizza apply e non viene modificato.
- `git merge-base --is-ancestor <checkpoint> HEAD`: exit 0; `rev-list <checkpoint>..HEAD` conta zero commit. Il branch nasce esattamente sul checkpoint, pronto a discenderne; non si inventa un commit figlio durante il planning.
- Stato iniziale: working tree e index vuoti. Tre worktree preesistenti preservati: principale su main `ee60777c7fdfc5c16daa1151050c134fbb7cde29`, checkout Codex `27f4` detached sul medesimo SHA, primo OpenSpec su `migrate-simple-view-model-commands` al checkpoint. Nessun checkout del cumulativo duplicato. Main non è baseline.
- I soli file scritti sono i cinque artifact di questa change. Il fetch aggiorna i riferimenti condivisi Git come richiesto; nessun contenuto/index/branch degli altri worktree viene modificato. Le letture di dipendenze e metadata risolti esterni sono read-only; tutti i comandi successivi hanno cwd nel nuovo worktree.

### Istruzioni, schema e dipendenze

FATTO: letto `AGENTS.md`, nessun AGENTS annidato trovato. Applicata skill `openspec-propose`; `openspec context --json` e `list --json` risolvono questa root repo-local. CLI **1.14.3**, schema **spec-driven**, config senza context/rules aggiuntivi; istruzioni proposal/specs/design/tasks lette. `.openspec.yaml`: schema spec-driven, created 2026-10-20, nessun skip_specs. Non si usano le versioni storiche dei CLI come se fossero quelle correnti.

`pubspec.yaml`/`pubspec.lock` e package_config già risolto: **command_it 9.5.2**, **listen_it 6.0.0**, **go_router 18.0.2**; Flutter **3.47.5**, framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`; eseguibile Dart **3.13.4 stable macos_arm64**. Nessun pub get, upgrade, generazione o dipendenza nuova. Fonte primaria per il timing: `~/.pub-cache/hosted/pub.dev/command_it-9.5.2/lib/command_it.dart`, soprattutto run 312–413, dispose 799–825, runAsync 859–870. Consultati anche [API ufficiale](https://pub.dev/documentation/command_it/9.5.2/command_it/Command-class.html) e [changelog 9.5.2](https://pub.dev/packages/command_it/changelog). Il tentativo Context7 non ha restituito dati prima dell’interruzione; non è fonte di conclusioni.

### Baseline diagnostica rigenerata — evidenza storica del planning iniziale

FATTO: nuova esecuzione di analisi sul contenuto Git del checkpoint, senza modificare il checkout. `git archive <checkpoint>` estratto in `/private/tmp/category-plan-baseline-xvhh0wl7`; tutti i file tracked provengono da quel commit. Solo nella copia temporanea è stato aggiunto `.dart_tool/package_config.json`, derivato da quello già risolto del checkout principale: modificato esclusivamente moliseis.rootUri alla URI assoluta reale dello snapshot, verificate le destinazioni degli altri package. Nessuna analisi del codice di un altro branch; nessuna modifica ai metadata del checkout principale.

Cwd: questo worktree. Argv esatto:

```text
/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/category-plan-baseline-xvhh0wl7
```

Nessun flag fatal-infos; default Dart: warning fatal, info non fatal. `subprocess.run` ha misurato **returncode grezzo 0**, stderr vuoto, **113 INFO / 0 WARNING / 0 ERROR**, tutte `DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`. Non attribuire exit 0 al diverso wrapper `flutter analyze`. Output `/private/tmp/category-plan-analyzer.log`, stderr `.stderr`, metadati `.json`; stdout SHA-256 `a542fd96198de78a678731293b66ccd6b1ff01dde1726ff597a6ae69b964d6c0`. Questi file sono evidenze effimere, non dipendenze dell’apply.

Le otto identità correnti, tutte nello stesso file `lib/ui/category/view_models/category_view_model.dart`, sono:

| Linea:colonna | Simbolo | Contesto | Molteplicità |
| --- | --- | --- | ---: |
| 22:12 | Command0 | costruzione load | 1 |
| 23:29 | Command1 | costruzione setSelectedCategories | 1 |
| 24:15 | Command1 | costruzione setSort | 1 |
| 25:24 | Command1 | costruzione setSelectedTypes | 1 |
| 35:8 | Command0 | dichiarazione load | 1 |
| 36:8 | Command1 | dichiarazione setSelectedCategories | 1 |
| 37:8 | Command1 | dichiarazione setSort | 1 |
| 38:8 | Command1 | dichiarazione setSelectedTypes | 1 |

L’appendice PR4 `archive/2026-10-19-resolve-flutter-analyzer-diagnostics-pr4/design.md` contiene il ledger durevole 125. Un confronto automatico del ledger meno le dodici occorrenze eliminate da OpenSpec 1 coincide con questa nuova analisi per file/simbolo/molteplicità: **113**. Il futuro apply deve confrontare anche regola, contesto e molteplicità, normalizzando root/linee mosse: otto identità target eliminate, **105 residue immutate e zero nuove**, non un semplice saldo. Il planning non riduce alcuna diagnostica. L’analisi non è stata rieseguita nella remediation documentale F1/F2; i conteggi restano evidenza storica invariata.

### Fonti lette e mappa dei consumer

| Superficie letta | Evidenza e responsabilità |
| --- | --- |
| `lib/utils/{command,result_command,restartable_command,command_configuration,result}.dart` | Contratti reali legacy/foundation, Result, reporting e ownership |
| `test/utils/{result_command,restartable_command,command_configuration,command_it_disposal_behavior}_test.dart` | Deferred entry, single-flight/join, neutral/void/error, stale work, rientranza, assertion, limiti upstream |
| `openspec/changes/migrate-simple-view-model-commands/` (metadata, proposal, design, tasks, delta) | Esclusione Category, D5/R1 e remediation; progressive Favourite è specifico e non impone progressive Category |
| `openspec/specs/command-execution-concurrency/spec.md`, canonical routing/navigation e local-content-retrieval | Autorità restartable, bootstrap/routing invariati; retrieval locale non include automaticamente Category nei target storici |
| `category_view_model.dart:15–151` | Quattro Command, lista condivisa, filtri mutabili, sort e nessun dispose override |
| `core_routes.dart:23–75` | Unica creazione production Category; Provider key slug; setter bootstrap unawaited; invalid slug prima del Provider |
| `category_screen.dart:45–124` | Menu osserva setSort; filtri passano callback; body osserva solo VM e usa load.completed OR setSort.completed |
| `category_content_and_type_selection.dart:34–157` | Copie modificabili; didUpdateWidget confronta identità wrapper (F1); first senza guard su draft vuoto e tipi vuoti etichettati Luoghi (F2); reset all solo alla chiusura e mounted dopo modal |
| `category_use_case.dart:18–24`, `explore_use_case.dart:25–33` | Delega Result a getByCategories, getAllPlaces e getByCurrentYear; conservare sequenza e significato temporale eventi |
| `settings_repository.dart`, `settings_repository_impl.dart:43–50,72–75` | Write Result; cache modificata solo su save riuscita; sort locale e cache persistita possono differire |
| `test/ui/category/view_models/category_view_model_test.dart` | Cinque test attuali: entrambi i lati, primo/secondo errore, selezione uguale, solo places; helper locale presume categorie vuote |
| `test/ui/category/widgets/category_content_and_type_selection_test.dart` | Sheet/dialog, reset e unmount del selettore; non prova primo frame route né owner replacement |
| `test/routing/{route_parameter_redirect,route_ownership,back_navigation_integration,geo_map_route,main_navigation_restoration,restoration_behavior}_test.dart` | Slug/all/invalid, branch/Post parent, chrome, restoration shell/Search/Map/Gallery; mancano regressioni Category con Future pending e primo frame |
| `test/support/{command_test_support,ordinary_view_model_lifecycle_support,route_ownership_fixture,sync_harness,fake_repositories,fixtures}.dart`, `test/ui/ordinary_view_model_lifecycle_test.dart` | Riuso fixture reali, fake, reporting e tempo virtuale; produzione Category è usata dalla fixture route |

La ricerca repo-wide dei tipi/proprietà trova come consumer production diretti solo route e CategoryScreen. Il selettore è indiretto tramite callback; ContentSliverGrid e callback story usano solo content, Provider/ChangeNotifier osservano il VM. Test Category e fixture route sono consumer aggiuntivi. Gli omonimi Command in GeoMap sono di un altro owner e restano esclusi. Audit read-only F1/F2: `GeoMapScreen` usa lo stesso `CategoryContentAndTypeSelection` in `geo_map_screen.dart:525–532`, con callback ai suoi Command legacy. I getter GeoMap (`geo_map_view_model.dart:130–141`) ricreano UnmodifiableSetView e i setter (`:230–258`) sostituiscono i backing set. La correzione condivisa deve conservarne firma, timing di conferma e mounted guard. Sede minima: test componente parametrizzato esistente; una sola integrazione distinta in `test/ui/geo_map/widgets/geo_map_screen_test.dart` verifica il wiring reale e rebuild da owner, senza duplicare tutta la matrice sheet/dialog. Nessun consumer production attende il risultato dei due setter filtro, legge i loro stati o richiede di conservarli come Command.

## Goals / Non-Goals

Garantire stato coerente prima del build, un solo dominio latest-intent per entrambi i filtri, commit atomico autoritativo, ordine corrente e zero effetti di presentazione post-dispose. Mantenere dominio/repository e Provider, evitando di ricostruire la vecchia API. Non promettere cancellazione fisica, serializzazione delle impostazioni tra owner, recupero automatico di write fallite o persistenza dei filtri di sessione durante process restoration. Nessuna migrazione delle altre sei aree della migrazione cumulativa; sola correzione del selettore condiviso F1/F2 e regressione di compatibilità del consumer GeoMap effettivo.

## Decisions

### D1 — Matrice dei quattro Command

| Command | Semantica attuale verificata | Alternativa proposta | Motivazione | Test futuri |
| --- | --- | --- | --- | --- |
| load | Single-flight awaitable; clear condiviso; places→events; Error anticipato; notify solo al successo completo | `RestartableCommand<CategoryLoadRequest, List<ContentBase>>`, `refresh()` cattura filtri; observer VM committa | Filtri richiedono sostituzione immediata; foundation offre già autorità e cleanup | C1–C4, P1–P4, L1–L4 |
| setSelectedCategories | Command1 single-flight; equality no-op; update/clear inline; await load ignorando il suo Result | Metodo VM sincrono void, copia/normalizza input, equality no-op, aggiorna intent e dispatch latest load | Non è un’operazione async autonoma né ha consumer del suo stato; evita wrapper e nested await falsamente significativo | B1–B3, C1–C3, U2 |
| setSelectedTypes | Lane legacy separata; modifica anche con load occupato, annidata respinta, successo setter fittizio | Metodo VM sincrono void con identica policy di coordinamento e snapshot combinato | Nessuna esclusione artificiale tra i due campi e nessun cambiamento perso | C2–C4, P4 |
| setSort | Single-flight; no-op uguale; sort/notify ottimistici; attende write ma ignora Result, sempre Success | `createResultCommand<ContentSort, void>`; sort sincrono, notify, write esistente, restituisce Result reale | È una vera azione persistente async; conserva lane e ordine locale senza nuova infrastruttura | S1–S4, L2–L4 |

`CategoryLoadRequest` è soltanto un typedef locale nel file VM per un record con `Set<ContentCategory> categories` e `Set<ContentType> types`, copiati non modificabili a ogni dispatch. Il nome rende leggibile il tipo della lane, non crea un layer, una factory o un framework. Sort non fa parte dell’input query: si applica al commit. Conservare `load` come oggetto osservabile; `refresh()` è l’azione VM che cattura un nuovo snapshot della selezione corrente, usata per bootstrap e retry. UI non costruisce record e non chiama una query direttamente. Nessuna interfaccia repository nuova.

### D2 — Bootstrap sincrono e normalizzazione della selezione

FATTO: legacy execute invoca l’action inline fino al primo await; il setter route aggiorna le categorie prima del rendering. La route valida slug/all prima del Provider, ma il VM parte vuoto. Il selettore chiama `.first` quando length non è quella di tutte le categorie. INFERENZA fondata sul sorgente: convertire solo execute→run lascia una finestra vuota perché command_it attende uno zero-event prima dell’action.

FATTO aggiuntivo: una chiamata diretta legacy con tipi vuoti può produrre successo vuoto senza query; categorie vuote seguono il path filtrato con un insieme vuoto. Il selettore production invece ripristina già tutti i valori alla chiusura. La normalizzazione proposta sotto sposta questa policy al boundary VM e cambia intenzionalmente soltanto questi input diretti anomali, coperti da C3.

PROPOSTA: costruttore con `required Set<ContentCategory> initialCategories`; route passa il singleton validato o l’insieme minusUnknown. Copiare prima di esporre il VM; difendere il boundary: categorie vuote vengono normalizzate a tutte le categorie note, rimuovendo unknown; tipi vuoti diventano tutti i tipi, come già fa il selettore al salvataggio. Questi sono cambiamenti espliciti per caller diretti anomali, non una modifica allo slug parser. Selezione iniziale tipi = tutti; sort iniziale = settings.contentSort. Installare observer e comandi, poi ammettere un solo refresh nel costruttore, **senza notifyListeners nel costruttore**. Rimuovere il setter bootstrap unawaited dalla route. Il run restartable pubblica deferred; nessun listener UI è notificato sincronicamente durante creazione Provider.

F2 corregge l’affermazione precedente: **l’invariante VM nonempty riguarda solo la selezione confermata** e il bootstrap; non garantisce la sicurezza del draft locale. **L’invariante widget è distinto**: durante editing categorie e tipi temporanei possono diventare vuoti. Rendering sicuro senza normalizzazione anticipata: categorie vuote → `Nessuna categoria`, tipi vuoti → `Nessun tipo`, distinti da `Categoria`/`Tipo` per tutte le opzioni. `.first` è ammesso solo nel ramo esplicitamente nonempty. Il reset a tutte le opzioni resta alla normale chiusura/conferma mounted di una sessione ancora corrente (D7/RF3), prima dell’unica callback. Nessuna semantica persistente empty e nessun altro cambiamento ai filtri VM già decisi. Il route error per invalid/numeric/unknown rimane prima di qualsiasi creazione/query. Stesso slug/stesso Provider conservato: non reseed, non ricaricare da build. Slug diverso o nuovo owner: inizializzazione indipendente. Restoration ricrea dall’URI; non si aggiungono campi restorable per filtri non serializzati.

### D3 — Eliminare la chiamata annidata e fissare admission/outcome

FATTO: il legacy rifiuta una seconda execute mentre running e restituisce subito Future<void>; la prima execute è attendibile ma non restituisce il Result. I setter attendono load.execute, poi riportano Success anche su load.error o rifiuto. I loro propri duplicati possono essere respinti prima di applicare il nuovo filtro. I filtri sono letti nuovamente dopo await, quindi lo stesso job può interrogare places con A e events con B.

FATTO upstream: `run` ritorna void, admission/runningSync sono immediati ma action differita; `runAsync` con completer esistente fa join senza una nuova admission. Anche chiamando runAsync dopo run può osservare il lavoro già attivo; dispose può completare waiter col valore corrente. Non usarlo per provare che un’intenzione filtro sia stata accettata o caricata. Test foundation già descrivono queste differenze.

PROPOSTA: setter filtro sincrono non promette un risultato async. Se vivo e diverso, copia la selezione, svuota `_content`, ammette **prima della notify** uno snapshot di entrambi i campi su load, poi notifica se ancora vivo. run revoca subito l’intent precedente; non c’è await tra intent e revoca. Reentrancy da observer running/notify può ammettere un altro filtro o disporre il VM: dopo dispatch non fare altre mutazioni e dopo notify non iniziare I/O. Il callback UI si limita a invocare il metodo VM. Uguaglianza per valore dei set, non identità; nessun alias modificabile dal chiamante. A ogni cambiamento confermato sostituire il backing set con una nuova copia indipendente, senza clear/add in place sul precedente: i vecchi parametri Widget e gli UnmodifiableSetView esposti conservano i valori precedenti. In alternativa un getter può fornire una copia snapshot indipendente; preferire la sostituzione già naturale ai setter senza ulteriore wrapper. UnmodifiableSetView da solo non protegge dalla mutazione del backing. Le copie draft non mutano i parametri confermati; C3/U3 verificano l’indipendenza degli snapshot. `refresh()` non deduplica: retry di stessi filtri è nuovo intent.

| Evento | Nuovo contratto |
| --- | --- |
| Setter uguale | Nessuna query, clear o notify; nessuna falsa attestazione di caricamento |
| Intent filtro cambiato | Accettato senza single-flight dei setter; load immediatamente authoritative |
| Refresh uguale | Nuova esecuzione latest-intent; non join |
| Sort duplicato pending | Rifiutato single-flight; nessuna queue o seconda write |
| Load Success completo | Observer vivo copia/ordina/committa e notifica |
| Load Result.error | Snapshot terminale domainError originale; nessun commit candidato |
| Raw throw | Runtime snapshot/reporting globale once; nessun catch Object→Result |
| AssertionError | Policy upstream fail-loud; non normale UI failure |
| Completamento post-dispose | Nessun commit/notify/fase nuova; settlement/reporting privati |

### D4 — Concorrenza e retrieval puro

PROPOSTA: action load usa **solo il record catturato** per scegliere CategoryUseCase contro ExploreUseCase e i lati place/event. I metodi getByCategories delle implementazioni Event/Place mappano gli indici del set senza mutarlo: le copie non modificabili sono compatibili. Preservare places prima di events, short-circuit sul primo Result.error e semantica all-events=current-year. Accumulare in una lista locale, restituire Result<List<ContentBase>>; nessuna scrittura a `_content`, filtri o sort nell’action. Il solo accesso owner permesso è guard `_disposed` all’ingresso e dopo await, prima di un’ulteriore fase. Non avviare events dopo dispose durante places. La fase già iniziata può finire/throw; per interruzione multistage restituire privatamente Result.error owner unavailable, non successo completo inventato. Non catturare runtime per farne unavailable.

Un observer sincrono su load.results, registrato prima dell’autoload e rimosso al dispose, è l’unico commit di retrieval. Su Success attuale: creare una copia della lista, ordinarla con `_sort` corrente, assegnare `_content`, notify, poi nessun altro effetto. Su running/failure non mutare contenuto: i relativi rebuild sono guidati direttamente da results. La foundation non consegna snapshot obsoleti dopo una nuova admission: **nessun generation counter/token aggiunto**, e il caso A→B→A non si risolve confrontando solo i valori dei filtri.

| Sequenza | Esito atteso |
| --- | --- |
| A→B con A pendente | B parte senza attendere A; solo B committa, A non abbassa running di B |
| A→B→A | L’ultimo A è un’esecuzione nuova, primo A sempre obsoleto |
| Tipi cambiano durante places | Nuovo snapshot completo; vecchi dati non entrano nel nuovo output |
| Categoria e tipi nello stesso turno | Ultimo record include entrambi; la foundation può evitare di iniziare i record già superati in coda |
| Cambio durante events/partial privato | Nessuna parte vecchia visibile; latest Success intero |
| Uguale durante query | Nessuna supersession/query inutile |
| Input iniziale route | Un solo snapshot con categorie già valide, nessun passaggio empty |

Il lavoro fisico superseded può proseguire sui filtri catturati, anche col secondo lato se il VM è ancora vivo: pubblicazione comunque revocata. Non introdurre cancellazione cooperativa, token di fase o nuova API foundation per evitare I/O obsoleto. Dopo dispose, invece, nessuna fase ulteriore. Limite di risorse noto per Future che non termina.

### D5 — Pubblicazione atomica e stato dati

FATTO legacy: clear all’ingresso; append places, poi events; Error primo lato lascia vuoto e salta il secondo; Error secondo lato lascia places **non necessariamente ordinati**; notify VM solo sul successo completo. La collezione parziale è osservabile dal getter o da altre notifiche (per esempio sort), ma non viene notificata sistematicamente né rappresentata da uno stato partial. Sort può inoltre rendere la grid visibile mentre un job muta la lista. Queste non sono garanzie da preservare implicitamente.

PROPOSTA: commit atomico al successo completo, per evitare qualsiasi provenienza mista. Nuovo filtro: clear immediato perché i dati vecchi non descrivono la selezione nuova. Refresh stesso filtro: conservare l’ultimo successo internamente; durante loading/errore non presentarlo come esito corrente. Non creare una seconda cache per filtro. Nessuna partial publication e nessun modello partial-success.

| Caso | Contenuto dopo esito | Stato UI |
| --- | --- | --- |
| Successo completo | Sostituzione unica, ordinata al commit | Grid, oppure empty esplicito |
| Prima query Error | Nessun candidato; clear se nuovo filtro, ultimo successo se refresh | Errore + retry |
| Seconda query Error | Come sopra; candidate places scartate | Errore + retry, non grid parziale |
| Zero risultati completo | Lista vuota committata | Empty, non skeleton |
| Retry dopo errore | Nuovo intent; sostituzione solo al successo completo | Loading→esito corrente |
| Cambio filtro dopo places | Lista visibile subito svuotata; vecchio partial resta privato | Loading nuovo→esito nuovo |

Questa scelta **cambia intenzionalmente** la retention di partial legacy e non altera Favourite progressive del primo OpenSpec. Non parallelizzare le query: mantenere ordine e short-circuit riduce variabili e preserva chiamate repository.

### D6 — Ordinamento e persistenza

FATTO legacy: `_sortContent` è async senza await; assegna sort e ordina sincronicamente name.compareTo asc / modifiedAt desc. `_setSort` attende quel Future, notify, attende setContentSort, ignora il suo Result e torna Success. La repository salva uno snapshot copyWith e cambia cache solo su Success.

PROPOSTA: helper di ordinamento **sincrono** sulle liste del VM/candidato; nessun Future fittizio. setSort resta factory ordinaria single-flight. Se uguale: Success no-op, nessuna write/notify. Altrimenti, se vivo, assegnare `_sort`, riordinare contenuto corrente, notify; ricontrollare `_disposed` prima della write (un listener può disporre). Se già revocato, unavailable senza write. Se write iniziata, restituire **l’originale Result**; nessun commit/notifica dopo await e nessun rollback, anche su runtime throw. Rimuovere il falso Success è un cambiamento intenzionale al risultato dell’action, non al contratto repository.

Sessione e persistenza sono distinte: su Result.error l’ordine locale rimane quello scelto come legacy; la cache repository rimane precedente e un nuovo owner riparte da essa. Ripetere lo stesso sort resta no-op anche dopo failure: nessun nuovo protocollo retry persistence. La UI non mostra conferme di salvataggio o snackbar non richiesti. Un observer può comunque distinguere il vero Result.error della write. Eventuali concorrenti write da altri owner mantengono il rischio preesistente di snapshot/lost update; non si introduce serializzazione cross-owner o modifica storage.

Ogni load committa ordinando **in quel momento** secondo `_sort`; non usare un sort catturato prima degli await e non refetch a ogni sort. Se il load finisce prima dell’action sort differita, il sort successivo riordina la lista; se finisce dopo, l’observer usa il nuovo sort. Un obsoleto non committa mai. Menu e body si aggiornano dal VM durante la write, non soltanto dal terminale del Command. Nessun legame tra setSort.completed e successo load.

### D7 — Osservazioni UI e owner replacement

PROPOSTA: `ListenableBuilder` sulle porzioni interessate con listenable composto dal VM e load.results, più setSort.results solo dove serve lo stato della write. Rebind automatico al cambiare di widget.viewModel; evitare forwarder load→VM usato solo per duplicare rebuild, mentre l’observer load→commit è necessario. `ResultCommandSnapshot` distingue idle/isRunning/completed/domainError/unexpectedError; non usare command.value o completed per dedurre possesso dati.

Body: neutral o running → SkeletonContentSliverGrid; completed + content nonempty → ContentSliverGrid; completed + content empty → EmptyView esplicita; hasFailure → EmptyView errore e pulsante `Riprova` che invoca VM.refresh. Usare i pattern EmptyView/SliverFillRemaining già presenti in Favourite/Explore, senza un nuovo componente framework. I filtri restano azionabili durante query; il menu segue `vm.sort`. Una write sort pending non altera loading/error load. Le notifiche results sono differite: constructor neutro rende skeleton e admission di nuovo filtro revoca immediatamente la vecchia pubblicazione. **Precisazione verificata nell’apply:** anche il refresh dello stesso filtro deve nascondere il precedente terminale già al primo frame. Il body legge `load.isRunningSync.value` come barriera di admission prima dello snapshot; non vi installa listener sincroni. `refresh()` notifica il VM dopo l’admission, con guard alive; il costruttore usa il solo `_startLoad()` privato e non notifica. Lo snapshot continua a definire successo/errore/empty e il VM/results resta l’unica osservazione UI. Testare primo frame dopo refresh e cambio filtro, escludendo vecchia grid/empty. Non leggere isRunning asincrono come fatto di admission né aggiungere un flag loading parallelo.

**F1 — Confronto semantico per campo.** I getter VM creano nuovi UnmodifiableSetView a ogni accesso; `!=` in didUpdateWidget confronta identità dei wrapper. Il parent può ricostruire per fine query, sort o altro evento senza cambiare filtri: riassegnare allora le copie locali perde il draft. Usare `setEquals(oldWidget.selectedCategories, widget.selectedCategories)` e l’equivalente per i tipi, disponibile in Flutter foundation. Confrontare **vecchi e nuovi valori confermati**, non draft e nuovo confermato: quest’ultimo confronto cancellerebbe proprio l’editing non confermato. Su valori confermati uguali non assegnare né modificare il set locale; ordine d’iterazione e identità wrapper non sono cambiamenti. Su valori realmente diversi sostituire solo la copia locale del campo cambiato con Set.of del nuovo parametro, senza resettare il draft dell’altro campo o invocare callback da didUpdateWidget. Verificare label e selezione alla successiva apertura; un confermato cambiato durante modal ritira il vecchio draft con la policy di sessione sotto, senza ripubblicarlo. Vecchi e nuovi parametri restano confrontabili grazie a D3. Fonte API locale verificata: Flutter SDK `foundation/collections.dart:25–41`, setEquals confronta cardinalità e membership.

**RF3 — Sessione draft e cambiamento reale durante modal aperto.** Il controllo critico indipendente della remediation ha rilevato che `_showAdaptiveSelectionWidget` riceve children materializzati una volta e ogni checkbox conserva un bool `selected`. Sostituire il campo State non aggiorna quelle righe: lasciare le callback leggere il nuovo campo mescolerebbe checkbox vecchie e nuovo confermato. La soluzione locale è catturare il riferimento al set draft del campo prima dell’apertura. Le callback delle righe mutano solo quel set catturato, mai un campo State riletto dopo un cambiamento esterno. Su vero cambiamento confermato didUpdateWidget sostituisce il relativo campo con una copia nuova: le vecchie righe restano una vista della sessione precedente, non controllano il nuovo set. Dopo await, controllare **prima mounted e poi identical(draftCatturato, campoCorrente)**. Se differiscono, la sessione è superseded: terminare senza setState, reset empty o callback; la prossima apertura usa i nuovi valori. Il nuovo confermato vince quando didUpdateWidget **osserva** il cambiamento di valore. A→B→A ritira il vecchio draft se B e poi A vengono consegnati in rebuild distinti. Se Flutter coalesca gli update e il widget osserva soltanto A→A, si tratta invece di uguaglianza semantica F1: conservare il draft, senza revision/token per ricostruire eventi non osservati. Confronto semantico F1 sui parametri e confronto identità del draft hanno responsabilità diverse: il primo evita invalidazioni spurie; il secondo prova l’ownership della sessione concreta. Un cambiamento solo dell’altro campo non ritira il modal corrente. Non aggiornare live le righe con notifier/controller nuovi, non chiudere route da didUpdateWidget e non ripristinare draft obsoleti. Nessun token aggiunto: basta l’identità dei set locali già presenti.

**F2 — Draft vuoto ammesso, label totale.** Le copie temporanee mutabili sono distinte dal confermato. Deselezionare l’ultima checkbox non deve ripristinare all né emettere callback: l’utente può continuare a editare. Su ogni rebuild, anche del parent mentre il modal è aperto, il ramo empty precede `.first` e il fallback singleton: `Nessuna categoria` / `Nessun tipo`. Conservare gli altri rami: `Categoria`/`Tipo` per tutte, nome categoria e conteggio, `Eventi`/`Luoghi` per singleton. Empty non significa all né Luoghi. Alla normale chiusura mounted **della sessione ancora corrente** secondo RF3, conservare il reset a minusUnknown per categorie e ContentType.values per tipi, poi pubblicare una sola copia con la callback relativa. Nessun reset in build, didUpdateWidget o toggle e nessuna notifica VM durante editing. F1 deve preservare anche il draft esattamente vuoto: la label safe non deve mascherare perdita delle modifiche.

**Owner distinto dalla semantica dei set.** Conservare **ObjectKey(viewModel)** in CategoryScreen: anche se i set confermati coincidono, il cambio owner smonta il vecchio State. **Precisazione della remediation finale della code review:** applicare la stessa separazione con `ObjectKey(owner)` al selettore nel trailing di GeoMapScreen, che può cambiare owner attraverso didUpdateWidget senza cambiare lo State dello screen. Il confronto semantico del confermato non sostituisce l’identità dell’owner. Il guard mounted precede ogni accesso post-await a State.widget/context, setState, normalizzazione e callback. Il vecchio modal, anche con draft vuoto, non aggiorna né vecchio né nuovo VM; stesso owner mantiene State e draft su rebuild innocui. Nessuna business logic domain spostata nella View. Prima di edit State applicare la skill async-mounted-context.

La modifica al selettore condiviso è ora **necessaria**, anche per il consumer reale GeoMap. Preservare firma callback, pubblicazione solo alla chiusura e reset empty su entrambi i layout. Nessun edit a GeoMapViewModel, Command o sua concorrenza. Testare il componente in `test/ui/category/widgets/category_content_and_type_selection_test.dart` per width 400/1000 × categoria/tipo; usare CategoryScreen per owner replacement e una regressione GeoMapScreen per il wiring reale. Nessun controller modal, wrapper di stato o notifica anticipata per risolvere F1/F2.

### D8 — Lifecycle e cleanup

PROPOSTA: `_disposed` idempotente; tutti i metodi VM e callback commit rifiutano lavoro dopo revoca. `dispose`: prima marcare revocato, rimuovere observer load→commit e qualsiasi forwarding pubblico posseduto, poi disporre RestartableCommand. La foundation revoca authority, differisce teardown dei propri notifier fuori dispatch e trattiene i figli fino al settlement/reporting; non duplicare il suo tracker o disporre manualmente i child.

Per l’unico Command ordinario setSort, applicare **localmente** la policy D5 già implementata in Explore/Theme del primo OpenSpec: trattenerlo mentre isRunningSync è true, poi cleanup microtask→event fuori dispatch, anche per never-run/idle; invalidare la barriera se si osserva una transizione successiva; ricontrollare live running/barriera, marcare released e staccare listener privato prima dell’unico dispose. Nessun polling, timeout, timer di sicurezza arbitrario o nuovo helper di produzione. Il solo listener dopo revoca serve a cleanup privato. Il timer upstream 50ms non è una prova di settlement.

Anche `super.dispose` del VM va programmato fuori dalla sua notify (microtask), senza aspettare il Future repository; la revoca blocca intanto ogni notifica nuova. Rientranza da notify, result terminale e running listener deve rimanere sicura. Un notify già iniziato può finire lo stack; non promettere cancellazione di listener già entrati. Non leggere State.widget/context del widget smontato per controllare owner.

FATTO noto command_it 9.5.2: dispose anticipato del Command con raw throw tardivo può fallire nei notifier già distrutti prima del reporting globale. Non basta un guard solo al notify né attendere runAsync né considerare false sync isolato prova di fine dispatch. Trattenere setSort vivo fino al settlement sicuro mantiene originale Object/stack al reporting; restartable fa già lo stesso per i child. Non cambiare gli skip upstream esistenti o normalizzare StateError/TypeError/AssertionError. Nessuna nuova fase repository dopo revoca; write già avviata non è cancellata né annullata remotamente.

### D9 — Alternative e simplification paths

| Alternativa | Valutazione |
| --- | --- |
| Sostituzione quattro tipi + execute→run | REJECT: bootstrap vuoto, nested run non awaitable, richieste perse e stale commit restano |
| Factory ordinarie per i due setter filtro | REJECT: nessun consumer dei loro stati e ingresso differito/single-flight aggiungono due lane, cleanup e rischio intent perso; non serve un wrapper async per un cambio sincrono |
| Un solo load single-flight, rifiutare filtri pending | REJECT: viola filtri correnti e requirement cambio durante query |
| Single-flight + latest desired snapshot + rerun su settlement | Credibile ma REJECT: necessita coda/coalescing, revoca delle vecchie pubblicazioni e distinzione A→B→A oltre a lifecycle; più coordinamento locale della foundation già esistente |
| Un solo RestartableCommand load e setter sincroni | ADOPT: autorità esistente, due Command totali invece di quattro; nessun token ridondante |
| Generation token/generic scheduler/adapter execute awaitable | REJECT: duplica ownership o vecchia API senza beneficio concreto |
| Preservare partial pubblicando progress/eventi | REJECT: richiede semantica partial nuova e autorità per ogni emissione; nessun consumer Category la richiede; atomic è più semplice e dichiarato |
| Trasformare anche sort in latest-intent | REJECT: write persistenti non cancellabili e rischio riordino storage; non necessario |
| Rollback o retry automatico sort failure | DEFER: cambierebbe policy UX/persistenza; preservare scelta sessione e restituire il Result reale è sufficiente |
| Nuovo stato UI/cache per filtro/factory lifecycle globale | REJECT: snapshot esistente, lista committata e guard owner bastano; niente state manager o layer aggiunti |
| Rimozione defensive lifecycle foundation | REJECT: source review e test mostrano bug risolto dagli owner; non opportunistica |
| Confronto identità wrapper o draft→nuovo confermato | REJECT F1: può cancellare editing su rebuild innocuo; setEquals vecchio→nuovo confermato e backing indipendenti |
| Reset all non appena il draft è vuoto | REJECT F2: impedisce editing progressivo; label empty e reset solo alla chiusura |
| Controller modal, stato parallelo o nuovo package per F1/F2 | REJECT: confronto semantico e branch label locali risolvono i due finding senza nuovi layer |

La semplificazione non consiste nel mantenere quattro wrapper per simmetria: due setter diventano normali mutazioni VM sincrone, una lane di lettura usa la foundation latest-intent e una write rimane ordinaria. Non rinominare o migrare gli omonimi di altre feature.

### D10 — Delta e consolidamento con OpenSpec 1

Canonical `Only authoritative completion can commit asynchronous data` descrive ancora il contratto generale pre-consolidamento. La delta MODIFIED del primo OpenSpec distingue correttamente ordinary/restartable e preserva progressive Favourite, rollback e riconciliazione consenso. Questa change aggiunge **sette requisiti Category con nomi distinti**, senza una seconda MODIFIED dello stesso blocco: il load Category rispetta il ramo restartable, setSort quello ordinario. Nessuna contraddizione con newest intent (refresh uguale è nuovo intent; setter equal non invoca la lane). Dati parziali Category vietati non impongono terminal-only a Favourite.

Alla fase finale autorizzata della PR cumulativa riconciliare la MODIFIED OpenSpec 1 e gli ADDED Category sullo stesso canonical, preservando tutti gli scenari Search/Map/Favourite/consent e senza duplicate headers. Adesso nessuna sync/archive/canonical edit. Routing e navigation-shell restano vincolanti senza delta perché la struttura URI/branch/restoration non cambia. Nessuna modifica a local-content-retrieval o backend.

## Regression plan

Tutti i casi sotto sono **gate futuri**, non test già eseguiti durante questo planning. Caricare prima dell’edit test le skill dart-add-unit-test e molise-is-test-support-reuse; per widget flutter-add-widget-test, per State/callback async molise-is-async-mounted-context-safety, per verifiche statiche dart-run-static-analysis. Cercare e riusare test/support prima di estenderlo.

| ID | Casi e osservazioni necessarie | Sede/riuso |
| --- | --- | --- |
| B1 | Primo frame singleton e all con query pending: selezione nonempty già prima di pump terminale, label corretto, una admission, nessun first/notify-during-build error | Category VM e route_parameter_redirect, production categoryRoute |
| B2 | Invalid/numeric/unknown slug: error screen, zero query Category; stesso owner/slug rebuild senza reseed/refetch; nuovo owner stessa URI riparte una volta | RouteOwnershipFixture e routing test esistenti |
| B3 | Back da Post conserva Category owner/filtri; branch retention; cambio slug ricrea owner; restoration canonica Category inizializza da URI e preserva parentage | route_ownership e main_navigation_restoration; riusare harness restorable reale |
| C1 | A→B e A→B→A, future completati in entrambi gli ordini, anche stessi valori A: solo ultima esecuzione committa; old domain/runtime non cambiano current failure/running | Category VM con query fake controllabili, Completer |
| C2 | Tipi durante places/event pending, category e tipi nello stesso turno e in turni diversi: snapshot coerente e output finale corretto | Estendere il minimo fake condiviso per getByCategories/getAll/getByCurrentYear se necessario |
| C3 | Equal set con nuova identità oggetto è no-op durante/after load; mutare set caller dopo dispatch non cambia request; input empty/unknown normalizzato; retry stesso filtro è nuovo intent | Category VM |
| C4 | Vecchio load parzialmente recuperato, nuovo load successo/errore; nuovo in coda superseded prima d’ingresso; nessuna query del record già superato quando foundation la sopprime | Foundation esistente + integrazione VM senza duplicare tutte le sue prove |
| P1 | Filtered e all path: places→events, prima failure salta secondo, seconda failure scarta places; query di un solo tipo; non chiamare repository fuori tipi selezionati | Category VM, fake esistenti |
| P2 | Candidate places non osservabili durante events pending; zero risultati = Success empty; successi con dati = singolo commit intero | Category VM e widget |
| P3 | Refresh fallito conserva ultimo successo internamente, mostra error; retry sostituisce intero; filtro cambiato svuota subito e failure non riesuma vecchio contenuto | Category VM/screen |
| P4 | Nessun Result.error convertito a throw; raw StateError/TypeError originale al global handler once anche stale; assertion fail-loud | installCommandTestReporting, MockLogger, foundation |
| S1 | Name asc, modifiedAt desc, uguale no write; ordinamento e menu osservabili prima di write settlement; no refetch | Category VM/screen |
| S2 | Query finisce prima/dopo sort action/write; entrambi gli ordini, vecchio obsolete rientra dopo sort recente: output sempre sort corrente | Completer di query e write separati |
| S3 | Write success/Result.error/raw throw: Result reale e identità Exception, local sort conservato, cache fake segue contratto; nuovo owner usa preferenza cache; uguale post-failure non scrive | FakeSettingsRepository e controlli repository esistenti, nessuna modifica storage |
| S4 | Sort doppio prima primo pump/durante write/rientrante da notify: una sola admission/write, nessuna queue; filtri rimangono indipendenti | VM, Command reale |
| U1 | Neutral/loading/grid/empty/domain error/runtime error/retry; sort.completed non sblocca skeleton/error; header e menu seguono stato corrente | Nuovo test screen Category se manca, harness material/Provider condivisi |
| U2 | Modal con draft nonempty/empty, owner sostituito (anche con set uguali) o pop: chiusura senza reset/pubblicazione al vecchio o nuovo VM; chiusura normale con esattamente una callback relativa, mai durante editing | Parametri width 400/1000 del test selettore; CategoryScreen reale ObjectKey(owner) |
| U3 — F1/RF3 | Categoria/tipo: edit non confermato e rebuild stesso owner/wrapper nuovi di uguali valori preserva State/draft/esito. Cambio confermato osservato, incluso A→B→A con pump distinti, aggiorna campo/label e supersede il modal: per quella sessione i toggle restano sul draft catturato e close non resetta/pubblica; riapertura usa nuovo confermato. A→B→A coalescato visto solo A→A mantiene invece draft F1 e conferma normalmente (reset empty/callback una volta). Altro campo non invalida il modal; vecchio snapshot VM immutato | Test selettore sheet/dialog, Category VM C3; includere ordine set diverso senza duplicare le cause rebuild |
| U4 — F2 + F1 | Deselezionare tutto, modal ancora aperto, rebuild parent con wrapper uguali: draft vuoto e checkbox deselezionate persistono, label Nessuna categoria/Nessun tipo, zero callback/exception. Proseguire con una voce prova assenza di reset prematuro; variante conferma empty ripristina all una volta. U2 copre unmount/replacement con empty | Test esistente width 400/1000 × categoria/tipo: estendere reset/unmount già presenti con rebuild e osservazioni intermedie senza duplicazione |
| U5 — Consumer condiviso | GeoMapScreen reale: draft modificato/empty e rebuild stesso owner da notify non causano reset/errori; conferma una sola volta aggiorna il filtro giusto con callback esistente, senza toccare altro filtro o lane legacy | Una regressione distinta in test/ui/geo_map/widgets/geo_map_screen_test.dart col suo harness; matrice completa dei due layout solo nel test componente |
| L1 | Dispose prima entry, durante places, durante events, callback terminale; no mutazioni/notify/fasi nuove, late success/domain/runtime/assertion | Command reali + reporting support + clock virtuale |
| L2 | setSort dispose never-run/idle/pending/notify prima write/terminal/value callback; settlement/dispose stesso turno nei due ordini e transizione durante barriera | Riuso matrice ordinary_view_model_lifecycle_support, adattatore test scoped |
| L3 | Pending oltre 50ms virtuali dopo owner disposal, poi late throw originale una volta senza notifier error; assertions in percorso previsto; exact-once cleanup | pumpCommandTurns, testOwnerUI dove serve, FlutterMemoryAllocations per sort e debug child count restartable |
| L4 | Pop/cambio owner con query e sort pendenti, staccare listener pubblici, nessun update al sostituto; dispose ripetuto idempotente | Production route fixture; non MockCommand come prova lifecycle |

I fake correnti getByCategories non espongono tutti gli hook pending necessari: estendere in `test/support/fake_repositories.dart` soltanto i metodi richiesti con callback/call recording coerenti con i pending già presenti, mantenendo i default. Non inventare fakes duplicati dentro i test Category. Trasferire/riusare l’attuale builder locale secondo policy support; nessun MockCommand per verificare concorrenza reale. Non aggiungere test per il mero nome del tipo o uno per ogni diagnostica.

Nuovi casi concurrency/lifecycle: Completer, `testWidgets` clock virtuale, `pumpCommandTurns`, `testOwnerUI` quando owner teardown crea timer; niente sleep reale, delay arbitrario o assertion sul numero microtask. Handler globali/zone/memory probe ripristinati; unmount esplicito e drain teardown upstream nel clock virtuale. Gli attuali test upstream con attese reali e skip documentati sono prove storiche della limitazione, non un modello per nuovi test.

## Risks / Trade-offs

- [Atomic cambia partial legacy] → decisione intenzionale D5 e P1–P3; nessuna falsa equivalenza col comportamento precedente.
- [Due setter non sono più Command] → audit consumer verificato, callback diretti e test aspettano esiti load; nessun adapter transitorio.
- [Window di admission/build] → constructor seed, deferred snapshot UI e B1/U1; non risolvere con notify durante build.
- [Reentrancy] → load.run prima di notify, nessun effetto dopo notify, guard owner prima write; L1/L2.
- [F1 wrapper identità/snapshot aliasati] → setEquals vecchio/nuovo confermato per campo e backing sostituiti D3; U3 prova anche cambiamento reale.
- [RF3 righe modal vecchie su nuovo confermato] → callback sul set catturato, mounted prima del controllo identità sessione, mismatch termina senza reset/callback; U3 include toggle post-update e distingue A→B→A osservato da quello coalescato.
- [F2 draft vuoto scambiato per confermato/all] → D2/D7 distinguono invarianti, label esplicite e reset solo alla chiusura; U4 combinato F1 e U2 copre conferma/revoca.
- [Modal migra tra owner] → chiave owner e U2 anche con set uguali e draft vuoto, senza lifecycle state holder.
- [Regressione componente condiviso GeoMap] → U5 prova wiring reale; nessun edit ai suoi Command/owner e nessuna matrice duplicata.
- [Obsoleto continua I/O] → consentito finché live ma senza commit; no nuove fasi dopo disposal; memoria privata fino settlement.
- [Sort sessione diverso da storage su errore/lost update tra owner] → contratto esplicito, Result reale, nessun rollback/serializzazione inventato; S3.
- [Cleanup command_it 9.5.2] → foundation restartable invariata e D5 locale del primo OpenSpec per ordinary; no early dispose di lavoro live.
- [Drift branch/SDK] → ripetere preflight mirato prima apply e fermare affected work se cambia il checkpoint o contratto, senza rebase/reset automatico.

## Migration Plan

Dopo review indipendente e autorizzazione separata: rifare preflight su questo checkpoint/cumulativo autorizzato, rigenerare ledger; implementare VM e route bootstrap con test dedicati, poi sort/lifecycle e UI con test per ogni gruppo, quindi integrazione/analyzer/suite completa. Nessun main baseline sostitutivo e nessuna modifica di altri Command. L’ordine esatto è in tasks.md. Eventuale rollback futuro è il solo diff attribuibile a questa change, preservando il primo checkpoint e lavoro esterno; nessun reset/clean globale.

Gate apply: zero legacy Category, zero nuove diagnostiche, 113→105 solo dopo implementazione e confronto delle altre identità; snapshot/coerenza filtri/bootstrap/sort/lifecycle soddisfatti; test deterministici, nessuna dipendenza/abstraction nuova senza beneficio. Nessun gate zero deprecazioni globale in OpenSpec 2. PR cumulativa e merge restano una fase successiva con autorizzazioni proprie.

## Evidenze, incertezze e readiness

Verificati: identità Git/remoto/PR, sorgenti sopra, versioni risolte, nuova analisi baseline e confronto ledger PR4. I test di comportamento nuovi **non sono stati scritti né eseguiti**; nessuna suite Flutter viene dichiarata verde ora. Le interleaving problematiche legacy sono inferenze dal codice e dalle prove foundation esistenti, non output di nuove caratterizzazioni Category.

Non restano decisioni sospese su bootstrap, concorrenza, pubblicazione, sort o lifecycle. Le limitazioni residue sono deliberate: non cancellazione fisica, risorse private con Future infinito, perdita del salvataggio sort senza rollback locale e rischio snapshot write già esistente. Una divergenza dei test dall’evidenza fonte va riconciliata prima di affected apply, senza redesign silenzioso. La validazione strict e l’audit documentale sono registrati dopo la loro esecuzione; non equivalgono a review indipendente o prova d’implementazione.


## Validazione documentale iniziale — 2026-10-20 (storica, precedente a F1/F2)

- `openspec validate migrate-category-view-model-commands --strict --no-interactive`: eseguito, **exit 0**, change valida. Status mostra 4/4 artifact planning completi (metadata più quattro artifact); non significa completamento apply.
- Cinque file presenti: `.openspec.yaml`, proposal, design, tasks e una delta spec. **21 task univoci tutti unchecked; 7 requisiti ADDED e 27 scenari**, nessun header sovrapposto alla delta del primo OpenSpec. Tutte le descrizioni normative aggiunte entro 500 caratteri, percorsi risolti interni alla change.
- `git diff --check` e `git diff --cached --check`: exit 0. Controllo esplicito dei cinque untracked: newline finale, nessun trailing whitespace/tab. Confronto Git blob di **1.073 file tracked** contro HEAD: tutti identici, incluse produzione, test/support, canonical, primo OpenSpec, dipendenze e AGENTS. Untracked non ignorati esclusivamente i cinque artifact di questa change.
- Stato finale: solo `?? openspec/changes/migrate-category-view-model-commands/`; index vuoto. Branch e HEAD invariati, ancestry positiva e zero commit oltre checkpoint. Controllo finale GitHub read-only: PR #12 ancora open/draft, head al checkpoint, updated_at `2026-10-20T12:18:05Z` identico al preflight. Nessuna mutation GitHub effettuata.
- Autocontrollo documentale: esplicitati no-op vs refresh, A→B→A, raw throw vs Result, partial atomico, session sort vs storage, cleanup pending e rientranza, modal owner replacement e consolidamento delta senza sovrascrivere OpenSpec 1. Corretto il censimento dei test VM esistenti a cinque. Nessun blocker materiale noto rimane aperto nel piano.

Il verdetto iniziale era **READY FOR INDEPENDENT PLAN REVIEW**. La successiva review indipendente ha rilevato F1/F2: questa nota storica non li dichiara risolti né vale come readiness della remediation corrente. Nessun apply, edit produzione/test, commit, push, PR, merge, sync canonical o archive era stato effettuato.


## Remediation documentale F1/F2 e riesame indipendente — 2026-10-20

### Baseline e perimetro della remediation

Worktree, branch e HEAD sono quelli attesi nel preflight: `codex/plan-migrate-category-view-model-commands`, `9d17d224d5094c5b043128113d9aba6a1ce69f0a`. Ancestry verificata con exit 0 e zero commit oltre checkpoint. Stato iniziale e finale: soltanto i cinque artifact non tracciati della change, index vuoto, nessun diff tracked. Il worktree già autorizzato è stato riutilizzato; nessun nuovo worktree, checkout, fetch, reset, clean, merge, rebase o cherry-pick in questa remediation.

Letti AGENTS, skill openspec-update-change, config/status/context e tutti i cinque artifact; verificati i consumer reali CategoryScreen/GeoMapScreen, i backing set di entrambi i VM, il selettore e i widget test pertinenti, API Flutter setEquals locale e delta OpenSpec 1. La richiesta dell’utente autorizza direttamente i quattro edit documentali, senza un ulteriore gate di conferma per artifact. Modificati esclusivamente proposal.md, design.md, tasks.md e specs/command-execution-concurrency/spec.md; `.openspec.yaml` invariato. Nessun file creato nella change o altrove nel repository.

La baseline diagnostica 113 INFO / otto Category resta l’evidenza storica del planning. **Nessun analyzer, test Flutter o build eseguito nella remediation**; nessuna riduzione a 105 rivendicata. Fonte per il confronto documentale: snapshot iniziale dei cinque testi e hash dei 1.073 tracked; nessun lavoro preesistente sconosciuto sovrascritto.

### Finding e decisioni riconciliate

| ID | Root cause / evidenza | Remediation del piano | Gate futuri e stato |
| --- | --- | --- | --- |
| F1 — MEDIUM | Nuovi wrapper UnmodifiableSetView a ogni getter e confronto identità in didUpdateWidget: un rebuild innocuo può cancellare il draft | D3 garantisce vecchi snapshot indipendenti tramite backing sostituiti; D7 usa setEquals vecchio/nuovo confermato per campo, mai confronto draft/confermato; equal preserva State/draft, vero cambio osservato aggiorna solo quel campo | U3 e task 2.2/4.2; scenari Equal confirmed categories/types e Changed confirmed selection. RISOLTO NEL PIANO; codice non modificato |
| F2 — MEDIUM | Nonempty confermato VM non implica nonempty della copia locale durante editing; `.first` può fallire, tipi empty appaiono Luoghi | D2/D7 distinguono i due invarianti; label Nessuna categoria/Nessun tipo, first solo dopo guard, nessun reset durante editing; all soltanto alla chiusura mounted della sessione corrente | U4 combinato F1, U2 owner/empty, U5 consumer condiviso; scenari Empty drafts/confirmation. RISOLTO NEL PIANO; codice non modificato |
| RF3 — MEDIUM, emerso dal controllo indipendente della remediation | Righe modal materializzate una volta e Checkbox con bool catturato; sostituire il campo su un vero confermato ma lasciare callback sul nuovo campo mescola due sessioni | D7 cattura il set draft usato dalle righe; mounted prima del confronto identità col campo corrente. Una sessione sostituita non normalizza né pubblica. Distinguere cambiamenti A→B→A consegnati con rebuild distinti (invalida) da update coalescati osservati solo A→A (F1, conserva e conferma normalmente) | U3/task 4.2 e scenario Confirmed changes supersede the open draft session; altro campo non invalida il modal. RISOLTO NEL PIANO senza controller, notifier o token nuovo |

Sono correzioni funzionali e contrattuali, non preferenze stilistiche. Il riesame indipendente read-only ha verificato i quattro artifact contro i sorgenti e il diff iniziale, segnalato RF3 e il limite degli update coalescati, poi verificato le correzioni e la formulazione degli esiti U3. **Esito conclusivo: nessun finding materiale residuo nella remediation documentale.** Questo non è una review dell’implementazione né una prova dei test futuri.

### Invarianti e architettura preservata

- Confermato VM: normalizzato, esposto senza alias mutabili; un cambio sostituisce il backing, i parametri widget precedenti conservano i valori. Questa policy non impone una nuova semantica persistente empty.
- Draft widget/sessione: può essere vuoto, non viene ripristinato da rebuild semanticamente uguali o toggle; label totali. Le righe editano il set catturato e solo una sessione ancora corrente può normalizzare e confermare una volta.
- Owner: ObjectKey(viewModel) in CategoryScreen separa gli State anche con set uguali. Mounted precede ogni accesso post-await: rientro di vecchio modal dopo unmount non aggiorna vecchio o nuovo VM. Il confronto semantico non sostituisce la verifica owner/sessione.
- Compatibilità condivisa: stesse callback e reset alla chiusura in sheet/dialog; correzione nel componente condiviso e sola regressione wiring GeoMap, senza modificarne Command o orchestrazione.
- Le sezioni D1/D4/D5/D6/D8/D10 sono state confrontate col testo iniziale e restano identiche: matrice comandi, retrieval latest-intent, commit atomico, sort/Result, cleanup e consolidamento delta non sono ridisegnati. Nessun nuovo layer, controller, dipendenza o state manager.

### Validazione documentale della remediation

- `openspec validate migrate-category-view-model-commands --strict --no-interactive`: **exit 0**. Sette requisiti ADDED, **34 scenari**, nessun header sovrapposto a OpenSpec 1 e nessuna seconda MODIFIED. Descrizioni normative entro 500 caratteri.
- **21 task**, ID univoci, tutti unchecked. Task 4.2 esteso senza aggiungere attività estranee; U2–U5 includono sheet/dialog (width 400/1000), categoria/tipo, casi combinati e la sola regressione condivisa distinta.
- Markdown dei quattro documenti analizzato con il parser GFM marked già disponibile: heading, tabelle e code fence verificati. Metadata YAML letto con Psych.safe_load consentendo Date: schema spec-driven e data invariati; exit 0. Nessun package installato per questi controlli.
- `git diff --check`, `git diff --cached --check`, `git diff --quiet` e `git diff --cached --quiet`: **exit 0**. Questi comandi non controllano gli untracked: whitespace/tab/newline finale verificati separatamente e positivamente su tutti i cinque artifact.
- Confronto hash iniziali/finali: tutti i **1.073 tracked invariati**; soli quattro documenti esistenti modificati, metadata invariato. Inventario esatto dei cinque untracked preservato; nessun artifact primo OpenSpec/canonical/codice/test/support/dipendenze/config cambiato. HEAD, refs di tutti i branch e registrazioni di tutti i worktree identici al preflight.
- Verifica GitHub read-only: PR #12 ancora open/draft con head al checkpoint e updated_at `2026-10-20T12:18:05Z`, come nel planning iniziale. Nessuna mutation GitHub effettuata.

**READY FOR INDEPENDENT PLAN REVIEW**. F1/F2/RF3 risultano risolti documentalmente; nessun blocker materiale noto rimane aperto nel piano. I bug di produzione restano da implementare e verificare dopo review conclusiva e autorizzazione separata. Nessun apply, commit, push, PR, merge, archive o sync canonical in questa fase.


## Evidenze dell’apply — 2026-10-20

Questa sezione descrive l’implementazione autorizzata dopo il verdetto READY FOR APPLY. Le sezioni precedenti conservano planning e remediation: le frasi «nessun apply» e i conteggi storici si riferiscono a quelle fasi. Questa implementazione non autorizza consolidamento Git o canonical.

### Preflight, provenienza e ambiente

Tutti i comandi di implementazione e verifica hanno cwd `/Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-category-view-model-commands`; branch `codex/plan-migrate-category-view-model-commands`, HEAD iniziale `9d17d224d5094c5b043128113d9aba6a1ce69f0a`. `git fetch origin`: exit 0; riferimento remoto cumulativo e HEAD della PR #12 open/draft corrispondono al checkpoint. Ancestry positiva, nessun commit oltre checkpoint, index vuoto. Inventario iniziale: solo i cinque artifact approvati untracked, preservati e letti integralmente prima degli edit. Manifest iniziale dei tracked, testi degli artifact e registrazioni worktree acquisiti in `/private/tmp/category-apply-lfqm6rs2/initial.json`. Gli altri tre worktree non sono superfici di scrittura. Nessun nuovo worktree, checkout, reset, clean, merge, rebase o cherry-pick.

Skill apply e skill test/unit/widget/reuse/async-mounted/static-analysis applicate. Riutilizzati supporti command reporting/turns/disposal, fake repository, routing production e matrice ordinary del primo OpenSpec. Dipendenze e lock invariati: command_it 9.5.2, listen_it 6.0.0, go_router 18.0.2; Flutter 3.47.5, Dart 3.13.4. Nessun pub get/upgrade. Package metadata locali ignorati derivati dal package_config già risolto, senza cambiare i package esterni.

### Caratterizzazione prima degli edit produttivi — task 1.4

Comando `/opt/homebrew/bin/flutter test --no-pub test/ui/category/view_models/category_view_model_test.dart test/ui/category/widgets/category_content_and_type_selection_test.dart test/routing/route_parameter_redirect_test.dart --reporter expanded`: **exit 0, 78 passed**. Test legacy temporanei, conservati fuori repository nel log della sessione, hanno verificato bootstrap inline, sequenza places→events, rifiuto del load annidato occupato, errore prima query, contenuto parziale al secondo errore e falso Success del sort con persistence Error. In seguito sono stati sostituiti dalle aspettative approvate; nessun test mantiene il partial o il falso successo come requisito futuro. Evidenze: `legacy-characterization.log`, `.json` e `legacy-characterization-test.dart` nella directory temporanea della sessione.

### Implementazione e precisazioni

- **D2/D3:** initialCategories obbligatorie e normalizzate prima dell’esposizione; tipi completi e sort dalla cache. Observer installato prima dell’unico autoload. La route passa direttamente il seed; invalid resta fuori dalla creazione. Setter sincroni confrontano per valore, sostituiscono backing immutabili, preservano vecchi snapshot e acquisiscono entrambi i filtri. Uguale è no-op; refresh esplicito ammette invece nuovo lavoro.
- **D4/D5:** `RestartableCommand<CategoryLoadRequest, List<ContentBase>>` conserva l’unica autorità. L’action legge snapshot non modificabili, assembla candidate private, preserva all/filtered, eventi current-year, places→events e primo errore originale; non committa. Il listener installato prima dell’autoload pubblica solo Success autorevole, con sort corrente. Filtro nuovo clear immediato, refresh mantiene internamente ultimo successo. Nessun progressive commit, token aggiuntivo o cancellazione fittizia.
- **D6:** setSort usa createResultCommand, conserva single-flight e no-op, aggiorna ordine locale e menu prima della write, controlla revoca dopo notify rientrante e restituisce il Result originale. Failure conserva sort di sessione senza fingere cache persistita; nessun refetch o rollback. Test con nomi e date in ordini opposti distinguono realmente i due sort.
- **D7, precisazione emersa da regressione:** al primo frame di un refresh la notifica results differita può ancora contenere il vecchio terminale. Il body usa la lettura immediata `load.isRunningSync.value` prima dello snapshot; non osserva quel notifier. `refresh()` notifica il VM dopo admission, il costruttore usa `_startLoad()` senza notify. Questo evita vecchia grid/empty senza aggiungere uno stato loading o un forwarder. Il risultato corrente continua a distinguere skeleton, grid, empty e failure/retry; setSort non sblocca il caricamento.
- **F1:** setEquals confronta vecchi/nuovi confermati per campo; wrapper equivalenti preservano draft, cambiamenti reali aggiornano solo il campo interessato. Snapshot VM precedenti restano indipendenti.
- **F2:** draft vuoti ammessi durante editing, label Nessuna categoria/Nessun tipo, guard prima di first; reset completo soltanto alla normale chiusura corrente. Nessuna semantica persistente empty.
- **RF3:** righe chiudono sul draft e callback catturati all’apertura. Dopo await: mounted, poi identità della sessione; una sessione sostituita non normalizza né pubblica. ObjectKey(viewModel) separa owner anche con selezioni uguali. A→B→A osservato invalida; A→A coalescato conserva secondo F1. Nessun controller/notifier/token nuovo.
- **D8:** revoca idempotente sincrona e detach del commit prima di dispose restartable; super.dispose differito fuori notify. Cleanup ordinary locale di setSort riprende la barriera microtask→event del primo OpenSpec, invalidabile e once, trattenendo il Command reale fino a settlement/reporting. Nessuna modifica della foundation globale o conversione di raw throw in Result.error.

### Gate mirati eseguiti

Tutti i comandi test usano `/opt/homebrew/bin/flutter test --no-pub` nel worktree Category; reporting expanded. Non si sommano run sovrapposti come test distinti.

| Gate | Evidenza e sede | Esito |
| --- | --- | --- |
| B1–B3 | route_parameter_redirect, route_ownership, main_navigation_restoration: singleton/all primo frame pending, invalid zero query, stesso owner/Back/branch, nuovo slug e restoration production | Pass nel run aggregato |
| C1–C4/P1–P3/S1–S4 | Category VM: 26 casi, Completer, snapshot caller/esposti, sequenziale atomico, primo/secondo errore e retry, A→B/A→B→A, tipologie, sort e query nei due ordini, single-flight e Result identico | Pass nel run aggregato |
| U1 | CategoryScreen: 11 casi, skeleton iniziale, runtime/domain retry empty, refresh retained primo frame, filtro pending e menu ottimistico | Pass nel run aggregato |
| U2–U4/F1/F2/RF3 | Selettore: 41 casi, 400/1000 × categoria/tipo, draft modificato/vuoto, confermato reale/altro campo/coalescato, sessione stale con toggle e riapertura; screen con owner replacement | Pass nel run aggregato |
| U5 | Un caso GeoMapScreen reale: draft vuoto, notify parent, retention e conferma attraverso callback esistente; nessuna migrazione GeoMap | Pass nel run aggregato |
| L1/L3/L4/P4 | Category lifecycle: 15 casi, before-entry, places/events, late Success/Result.error/StateError/TypeError/assertion oltre 50 ms virtuali, original stack/reporting, revoca rientrante, child cleanup once | 15 passed, exit 0 |
| L2/L3 | Lane categorySort nella matrice ordinary esistente, +14 casi; foundation Result/restartable/reporting e disposal upstream | Pass nel run aggregato, soli skip upstream preesistenti |

Run aggregato finale: `/opt/homebrew/bin/flutter test --no-pub test/ui/category test/ui/ordinary_view_model_lifecycle_test.dart test/routing/route_parameter_redirect_test.dart test/routing/route_ownership_test.dart test/routing/main_navigation_restoration_test.dart test/ui/geo_map/widgets/geo_map_screen_test.dart test/utils/result_command_test.dart test/utils/restartable_command_test.dart test/utils/command_configuration_test.dart test/utils/command_it_disposal_behavior_test.dart --reporter expanded`: **exit 0, 375 passed, 3 skipped preesistenti**. Log/metadati `targeted-tests-final.log/.json` nella directory della sessione.

Correzioni durante sviluppo: prima compilazione VM usava erroneamente un copyWith inesistente su Place; sostituito con il parametro opzionale modifiedAt nella fixture condivisa. Prime prove lifecycle avevano Completer creati fuori dalla Zone che li attendeva: raw error attraversava un diverso error-zone boundary; creazione spostata nella stessa Zone, mantenendo le asserzioni original error/stack e fail-loud. La prima prova screen ha individuato il vecchio terminale al primo frame refresh, risolto con la precisazione D7 sopra. Import e lints corretti nei soli file interessati. Nessuna aspettativa indebolita, nuovo skip o seam produttivo per ottenere verde.

### Analyzer e formatter dell’apply

Baseline analizzata: git archive del checkpoint in `/private/tmp/category-apply-lfqm6rs2/baseline`; package_config risolto con sola root del package locale adeguata allo snapshot. Comando `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/category-apply-lfqm6rs2/baseline`: **returncode grezzo 0, 113 INFO, 0 warning/errori**, tutte DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE. Metadati/output `baseline-analyzer.json/.log/.stderr`.

Finale: snapshot dei file effettivi non ignorati, con verifica byte a byte, in `/private/tmp/category-apply-lfqm6rs2/final-snapshot`; stessi metadata risolti. Comando `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/tmp/category-apply-lfqm6rs2/final-snapshot`: **returncode grezzo 0, 105 INFO, 0 warning/errori**. Confronto Counter per severity/regola/file/messaggio/molteplicità, normalizzando root e linee spostate: **esattamente le otto Category rimosse, altre 105 identiche, zero nuove**. Metadati `final-analyzer.json`, stdout/stderr associati; manifest SHA256 `cd14356fd692252f8a3c95997371b1e574ae02ef59031737dda488674279c34a`. Le successive sole modifiche documentali non alterano il codice analizzato. Non si attribuisce questo exit al wrapper Flutter: flutter analyze non è stato eseguito separatamente. Nessuna soppressione o config analyzer modificata.

`dart format` sui soli 19 Dart intenzionalmente modificati: **exit 0, 19 files, 0 changed** nell’ultimo passaggio. Nessun import/tipo/uso Command legacy rimane in lib/ui/category. Nessuna modifica a dipendenze, UseCase, repository produttivi, foundation, altri Command o canonical.

### Limiti conservati e review locale

Una query fisica obsoleta può finire e, mentre l’owner è vivo, completare le fasi previste dal suo snapshot: non ha autorità di commit. Dopo dispose non parte una nuova fase. Un Future che non termina trattiene il relativo cleanup privato secondo il contratto upstream: nessun timeout inventato. Errori inattesi mantengono originale e stack; AssertionError resta fail-loud. Session sort può divergere dalla cache dopo persistence Error; nessun nuovo protocollo retry o serializzazione cross-owner. Filtri di sessione non serializzati non vengono promessi come restaurabili.

Autocontrollo adversariale del diff e review locale indipendente read-only: nessun finding materiale residuo su bootstrap, snapshot/latest-intent, atomicità, sort, F1/F2/RF3, reporting, cleanup e scope. Il reviewer ha richiesto di rendere esplicita la barriera del primo frame e aggiornare lo stato degli artifact: precisazione inserita in D7 e qui. Questa review locale non sostituisce la successiva review indipendente di codice richiesta prima dell’integrazione cumulativa.


### Suite completa, validazione e integrità finale

`/opt/homebrew/bin/flutter test --no-pub --reporter expanded`: run finale **exit 0, 2.476 passed, 6 skipped, 0 failed**, durata 90,85 s. Log `full-tests-final.log` e metadati `full-tests-final.json` in `/private/tmp/category-apply-lfqm6rs2/`. Sei skip già nel checkpoint: tre scenari StateError di command_it_disposal_behavior (limitazione upstream documentata), un caso GeoMap route già skipped, due integrazioni E2E locali condizionate dalle variabili MOLISE_ALL_DAY_LOCAL_E2E e MOLISE_EXTERNAL_TOKEN_LOCAL_E2E. Nessun nuovo skip.

I primi due run completi erano falliti con exit 1 (**2.254 passed, 6 skipped, 222 failed**) per ObjectBox nativo assente nel nuovo worktree, con errori di setup/teardown conseguenti. Il secondo tentativo con solo DYLD_LIBRARY_PATH non aveva risolto la ricerca della libreria. Correzione d’ambiente: copia byte-identica del binario già disponibile nel checkout principale, letto soltanto, nel percorso `lib/libobjectbox.dylib` già ignorato dal Git del worktree Category; SHA256 `1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751`. Nessun download, modifica a manifest/lock o codice ObjectBox. Il run finale usa il comando ordinario senza override DYLD. Sono runtime locali ignorati, come i metadata risolti/build, non nuovi sorgenti di produzione. Log dei tentativi falliti mantenuti come `full-tests.log/.json` e `full-tests-native.log/.json`.

Controlli documentali: `openspec validate migrate-category-view-model-commands --strict --no-interactive`, **exit 0**. Quattro Markdown passati da marked lexer/parser; YAML safe_load con Psych, **exit 0**, schema spec-driven/data valida. Primo tentativo Psych.safe_load_file non disponibile nella versione Ruby locale (exit 1), corretto usando safe_load del contenuto; nessun package installato. Controllati fence, whitespace e newline finali esplicitamente su tutti i 24 file del diff, inclusi i dieci untracked: nessuna anomalia. `git diff --check` e `git diff --cached --check`: exit 0; non usati come sostituto del controllo untracked.

Inventario finale: **14 tracked modificati e 10 file untracked**, nessun staged. Quattro superfici produttive: `lib/routing/core_routes.dart` (solo bootstrap Category), `lib/ui/category/view_models/category_view_model.dart`, `lib/ui/category/widgets/category_screen.dart`, `lib/ui/category/widgets/category_content_and_type_selection.dart`. Quindici Dart di test/support:

- `test/routing/main_navigation_restoration_test.dart`, `test/routing/route_ownership_test.dart`, `test/routing/route_parameter_redirect_test.dart`;
- `test/support/fake_repositories.dart`, `test/support/fixtures.dart`, `test/support/ordinary_view_model_lifecycle_support.dart`;
- `test/support/category_screen_test_support.dart`, `test/support/category_selection_test_support.dart`, `test/support/category_view_model_test_support.dart`;
- `test/ui/category/view_models/category_view_model_test.dart`, `test/ui/category/view_models/category_view_model_lifecycle_test.dart`;
- `test/ui/category/widgets/category_content_and_type_selection_test.dart`, `test/ui/category/widgets/category_screen_test.dart`;
- `test/ui/geo_map/widgets/geo_map_screen_test.dart`, `test/ui/ordinary_view_model_lifecycle_test.dart`.

I cinque artifact OpenSpec preesistenti restano untracked. Proposal/design/tasks aggiornati; `.openspec.yaml` e delta approvata invariati. Delta: **7 requisiti, 34 scenari**, nomi disgiunti dal primo OpenSpec e nessuna seconda MODIFIED. Primo OpenSpec e canonical invariati; nessuna sync/archive. Tutti i **21 task verificati**, inclusa la review locale indipendente che ha riletto gli artifact dopo la precisazione D7, senza finding materiali residui.

Verifica automatica contro il manifest iniziale: ogni tracked esterno all’allowlist conserva lo SHA256 originale; registrazioni dei quattro worktree identiche, index vuoto, branch invariato, HEAD finale ancora `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, ancestry positiva e zero commit oltre checkpoint. Nessun altro checkout o branch modificato. Nessun commit/push/PR/merge/archive/sync eseguito. I comandi dei log hanno cwd Category; i percorsi temporanei contengono prove/snapshot, non baseline alternative.

**READY FOR INDEPENDENT CODE REVIEW**. Gate B/C/P/S/U/L coperti, suite completa verde, 105 INFO residue esattamente riconciliate, strict verde. Nessun blocker materiale noto. Le limitazioni upstream e di persistenza sopra descritte restano esplicite; la consegna non autorizza integrazione nella PR cumulativa.


## Remediation finale della code review — F1 callback owner GeoMap

Questa sezione supera il precedente verdetto dell’apply solo rispetto al finding emerso nella successiva review indipendente. **F1 della code review (MEDIUM)** è distinto da F1 del planning: qui il difetto è ownership del consumer GeoMap, non il confronto semantico dei set. Planning, F1/F2/RF3 documentali e risultati storici dell’apply restano conservati.

### Baseline incrementale e supporti

Worktree Category, branch e HEAD ancora `codex/plan-migrate-category-view-model-commands` / `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, ancestry positiva, index vuoto. Inventario iniziale identico alla consegna apply: 14 tracked modificati, 10 untracked, cinque artifact presenti e 21/21 task completati. Verificati byte/hash dei 19 Dart dell’apply contro lo snapshot analizzato precedente; nessuna modifica sconosciuta. Nessun checkout/fetch/reset/clean/merge/rebase/cherry-pick o nuovo worktree in questa remediation. Manifest e diff iniziali in `/private/var/folders/c3/zqb0crmd579dm8qdg8cyfhsr0000gn/T/category-final-remediation-2huxf73t/initial.json` e `initial.diff`.

Supporti cercati e riutilizzati: builder privati già presenti nello stesso geo_map_screen_test, ValueListenableBuilder del test production owner replacement esistente, FakeEventRepository.pendingGetById/getByIdCallCount, makeEvent, testOwnerUI e pumpCommandTurns. Nessun nuovo helper, fake o supporto. Skill test/reuse/async-mounted/static-analysis lette prima delle modifiche pertinenti.

### Root cause verificata e correzione minima

GeoMapScreen.didUpdateWidget già scollega il precedente ViewModel e revoca le query selection/nearby. Tuttavia il trailing di AnimatedGeoMapSearchBar montava CategoryContentAndTypeSelection senza chiave dell’owner. Con A→B e confermati uguali, Flutter conservava lo State del selettore; setEquals preservava correttamente il draft ma il callback catturato all’apertura apparteneva ancora ad A. Mounted e identità draft rimanevano veri, consentendo la callback obsoleta.

Unica modifica produttiva: `key: ObjectKey(owner)` sul CategoryContentAndTypeSelection effettivamente restituito dal builder GeoMapScreen. Il riferimento owner è lo stesso passato a selezioni e callback in quel build. Alla sostituzione del ViewModel cambia la chiave: GeoMapScreen mantiene lo State e attraversa didUpdateWidget, il vecchio selettore viene smontato e il nuovo monta da B. Il vecchio modal può rimanere visibile, ma il mounted guard già presente termina prima di normalizzazione/callback. Con stesso owner la chiave resta equivalente e il draft non viene perso.

Minima estensione autorizzata di compatibilità del componente condiviso: quinto file produttivo rispetto ai quattro dell’apply, solo una riga in GeoMapScreen. Nessun edit a GeoMapViewModel/Command, selettore condiviso, CategoryViewModel, factory/foundation, repository, UseCase o dipendenze. Nessun token/controller/notifier e nessuna duplicazione del guard RF3. Il contratto normativo già richiede scarto dei callback owner obsoleti; delta invariata (sette requisiti, 34 scenari), nessuna duplicazione o modifica canonical.

### Nuove regressioni R1–R5 e prova red/green

Quattro test parametrizzati in geo_map_screen_test: categorie/tipi × draft non vuoto/vuoto. Usano GeoMapScreen reale mantenendo il suo State; ValueListenableBuilder sostituisce il ViewModel A con B distinto e filtri uguali. Prima della chiusura, provano vecchie righe ancora visibili con checkbox modificate, vecchio State già non mounted, nuovo selettore montato. Dopo close provano zero admission di entrambi i Command filtro su A e B, anche nel caso empty→all che sarebbe un no-op semantico: i listener rilevano comunque l’eventuale esecuzione. Selezioni di entrambi gli owner invariate e nuovo selettore inizializzato da B.

Tutti e quattro i casi includono lookup fisici pendenti tramite Completer per A e B; didUpdateWidget revoca A senza trasferirne l’autorità. Dopo chiusura si dispone A con Future ancora pending, si avanza oltre 50 ms virtuali, poi completano A obsoleto e B corrente. Nessuna notifica post-dispose, nessuna mutazione di A, solo il contenuto proprio di B, nessuna seconda azione o eccezione lifecycle. Nessun sleep reale o dipendenza dal numero di microtask.

R4 riusa il test GeoMap preesistente di draft empty mantenuto su owner notify e normalizzazione alla singola conferma; la matrice Category condivisa già copre draft nonempty, altro campo, sheet/dialog e chiusure normali senza duplicarla in GeoMap. R1/R2/R3 provano entrambe le tipologie; R5 aggiunge query pendenti e settlement post-dispose al medesimo scenario reale.

**Prova discriminante prima dell’edit produttivo:** `/opt/homebrew/bin/flutter test --no-pub test/ui/geo_map/widgets/geo_map_screen_test.dart --plain-name 'Map selector owner replacement' --reporter expanded`: **exit 1, 0 passati / 4 falliti**, tutti su oldPublications: atteso 0, effettivo 2 (start/terminale del setter causato dal callback obsoleto). Dopo la sola chiave: **exit 0, 4 passati**, stessi test/aspettative. Log `red.log/.json` e `green.log/.json` nella directory della remediation. Le correzioni successive ai test sono soltanto lint/format (cascade, braces e commenti), senza cambiamento delle aspettative.

Primi tentativi di setup dei nuovi test non costituiscono questa prova red: pumpAndSettle non terminava con skeleton intenzionalmente animato e un finder usava ValueKey<Object> anziché la reale ValueKey tipizzata. Corretto guidando l’animazione modal con Durations.long4 e clock virtuale e usando le chiavi tipizzate; nessuna modifica produttiva prima della prova red effettiva.


### Gate della remediation e confronto diagnostico

Tutti i comandi sotto hanno cwd nel worktree Category autorizzato. Log e metadati grezzi nella directory `category-final-remediation-2huxf73t` indicata sopra. Nessun risultato dell’apply storico viene riattribuito a questa remediation.

- **Mirati:** `/opt/homebrew/bin/flutter test --no-pub test/ui/geo_map/widgets/geo_map_screen_test.dart test/ui/category test/routing/route_ownership_test.dart test/ui/ordinary_view_model_lifecycle_test.dart --reporter expanded`: **exit 0, 264 passati, zero falliti/skipped** (`targeted.log/.json`).
- **Aggregati finali:** `/opt/homebrew/bin/flutter test --no-pub test/ui/category test/ui/ordinary_view_model_lifecycle_test.dart test/routing/route_parameter_redirect_test.dart test/routing/route_ownership_test.dart test/routing/main_navigation_restoration_test.dart test/ui/geo_map/widgets/geo_map_screen_test.dart test/utils/result_command_test.dart test/utils/restartable_command_test.dart test/utils/command_configuration_test.dart test/utils/command_it_disposal_behavior_test.dart --reporter expanded`: **exit 0, 379 passati, 3 skip upstream preesistenti**, zero fallimenti (`aggregate-final.log/.json`). B/C/P/S/U/L rimangono soddisfatti; +4 casi rispetto ai 375 dell’apply.
- **Suite completa:** `/opt/homebrew/bin/flutter test --no-pub --reporter expanded`: **exit 0, 2.480 passati, 6 skip preesistenti, zero fallimenti** nel primo run della remediation (`full.log/.json`). Sono gli stessi sei skip identificati nell’apply; nessun nuovo skip. Runtime ObjectBox locale già predisposto riutilizzato senza modifiche, hash invariato. Dopo i soli lint finali dei nuovi test sono stati riconfermati gli aggregati; risultato dell’ulteriore run completo sui file definitivi registrato nel paragrafo conclusivo sotto.
- **Formatter:** `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart format lib/ui/geo_map/widgets/geo_map_screen.dart test/ui/geo_map/widgets/geo_map_screen_test.dart`: **exit 0, 2 file, zero modifiche residue** nell’ultimo passaggio. Nessun formatter su altre superfici.
- **Analyzer:** `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze --format machine /private/var/folders/c3/zqb0crmd579dm8qdg8cyfhsr0000gn/T/category-final-remediation-2huxf73t/analyzer-snapshot`: **returncode grezzo 0, 105 INFO / zero warning / zero errori**, tutte DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE. Snapshot byte-identico dei sorgenti non ignorati; metadata risolti copiati, sola root del package locale adeguata al percorso fisico canonico. Counter per severity/tipo/regola/file/messaggio/molteplicità contro `category-apply-lfqm6rs2/final-analyzer.log`, normalizzando root e posizioni spostate: **105 identità invariate, zero aggiunte/rimosse** (`analyzer.log/.stderr/.json`). Nessuna nuova dipendenza legacy in Category, nessuna modifica ai Command GeoMap. Non eseguito un diverso flutter analyze; il suo exit non è inferito dal Dart.

Un primo tentativo analyzer usava il percorso `/var/folders` non risolto nella rootUri mentre l’analyzer vedeva `/private/var/folders`: diagnosticava erroneamente sorgenti dello stesso package come root diverse (exit 3). Scartato come errore di preparazione dello snapshot, corretto con Path.resolve senza toccare il checkout. L’analisi valida intermedia rilevava tre soli lint nuovi (due commenti oltre 80 caratteri e un cascade): corretti nei nuovi test e rieseguita l’analisi, producendo il confronto identico sopra. Log intermedi conservati; nessuna soppressione o modifica analyzer.

### Riesame adversariale e confini invariati

Autocontrollo più review locale indipendente read-only del diff incrementale e dei log red/green: **nessun finding materiale residuo**. Verificati punto corretto della chiave, sopravvivenza dello State screen, remount per owner distinti anche con set uguali, mounted guard prima della callback, vecchio modal ancora visibile, draft vuoto/nonvuoto e query pending. Nessuna nuova responsabilità di ownership nel selettore e nessun mutamento della semantica legacy GeoMap. La review resta locale, non sostituisce la successiva verifica indipendente conclusiva.

L’inventario incrementale contiene esattamente **cinque file**: `lib/ui/geo_map/widgets/geo_map_screen.dart`, `test/ui/geo_map/widgets/geo_map_screen_test.dart`, proposal.md, design.md e tasks.md della change Category. Il diff produttivo è una sola riga; rimuoverla riproduce byte per byte lo stato iniziale del file. Il suffisso originale di tutti i test GeoMap preesistenti è byte-identico; le quattro prove sono aggiunte all’inizio, nessuna aspettativa preesistente alterata. Tutti gli altri sorgenti/supporti/artifact conservano l’hash iniziale, inclusi `.openspec.yaml`, delta, primo OpenSpec e canonical. Il diff complessivo apply + remediation conta ora **15 tracked modificati e 10 file untracked**; index vuoto. I 21 task originali restano completati, sette requisiti/34 scenari normativi invariati.

Verifica GitHub read-only: PR #12 ancora open/draft, head `codex/migrate-legacy-commands` al checkpoint, updated_at `2026-10-20T12:18:05Z`, invariato dalla consegna precedente. Nessuna mutation PR. Branch e HEAD Category invariati, ancestry positiva, registrazioni worktree identiche; nessuna scrittura negli altri checkout. Nessun commit, push, merge, rebase, archive o sync canonical. La nuova riga della View non modifica i Command GeoMap o l’ordine delle query; le limitazioni e decisioni Category documentate nell’apply restano invariate.


### Esito conclusivo della remediation

Ultimo run completo sui file definitivi, dopo i lint: `/opt/homebrew/bin/flutter test --no-pub --reporter expanded`, **exit 0, 2.480 passati, 6 skip preesistenti, zero fallimenti**, 91,99 s (`full-final.log/.json`). Hash dei due Dart registrati nei metadati e coincidenti con l’analyzer e i file consegnati. Nessuna modifica di codice dopo questo run.

`openspec validate migrate-category-view-model-commands --strict --no-interactive`: **exit 0**; Markdown parse dei quattro artifact e YAML safe-load pertinenti validi. `git diff --check` e `git diff --cached --check`: exit 0; whitespace/newline controllati separatamente e senza anomalie su tutti i 25 file del diff complessivo, inclusi i dieci untracked. Index vuoto, branch/HEAD invariati, ancestry positiva e zero commit oltre checkpoint; altri worktree preservati. Manifest finale `integrity-final.json` attesta i cinque soli file incrementali e gli hash inalterati del resto dell’apply. Nessun nuovo artifact richiesto o non richiesto; `.openspec.yaml`, delta, canonical e primo OpenSpec invariati.

**F1 della code review chiuso con evidenza red/green e gate completi. Nessun finding materiale residuo noto. READY FOR INDEPENDENT CODE REVIEW.** Restano le limitazioni documentate dell’apply, non nuovi blocker di questa remediation. Nessuna autorizzazione a integrazione o pubblicazione è implicita nella readiness.
