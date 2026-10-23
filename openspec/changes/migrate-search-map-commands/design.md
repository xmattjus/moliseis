# Design

## Context

### Baseline verificata — 2026-10-23

Vedere `proposal.md` per motivazione e perimetro. GitHub `get_pr_info(xmattjus/moliseis,12)` ha restituito PR open, draft=true, merged=false, head `codex/migrate-legacy-commands` a `1f3753b10c18061c6655cb32d078bf93aff1b05e`. Nessun avanzamento da riconciliare. I tre commit cumulativi sono `9d17d224` (simple), `e3d9d891` (category), `1f3753b1` (content); i rispettivi tasks hanno 27/27, 21/21 e 27/27 completati. Questo verifica presenza e stato degli artifact/commit, non ripete le loro verifiche storiche.

Worktree persistente: `/Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-search-map-commands`; branch `codex/plan-migrate-search-map-commands`; HEAD iniziale e finale autorizzato `1f3753b10c18061c6655cb32d078bf93aff1b05e`. Prima della creazione branch e percorso non esistevano. Letti AGENTS.md repository-wide (nessun AGENTS annidato trovato), skill openspec-propose e config `schema: spec-driven`; context/list hanno risolto questo worktree come root locale. Nessuna modifica ai checkout esistenti.

Snapshot iniziale: principale main e detached `.codex/worktrees/27f4/moliseis_v2` a `ee60777`; worktree simple a `9d17d224`, category a `e3d9d891`, content a `1f3753b1`; tutti senza modifiche tracked/untracked, index vuoto. Conservare identità HEAD/branch, status, diff e contenuti dei checkout nel controllo finale. La registrazione di un nuovo worktree/ref è l'unico cambiamento Git amministrativo autorizzato.

### Analyzer realmente eseguito

Dopo `flutter pub get --offline` riuscito (solo cache e file ignorati, lock invariato), eseguito `dart analyze --format machine`, exit **0**: **87 INFO / 0 WARNING / 0 ERROR**, esattamente baseline pubblicata. Non equivale a flutter analyze verde e non afferma CI verde. Output integrale di sessione: `/tmp/search-map-analyzer-machine.txt`, stderr vuoto; questi percorsi temporanei non sono prerequisiti per review o apply. Riprodurre dal checkpoint con la stessa dipendenza risolta. Nessun test Flutter eseguito durante questo planning.

Tutte le 21 diagnostiche target hanno severity INFO, type LINT, code `DEPRECATED_MEMBER_USE_FROM_SAME_PACKAGE`; messaggio di deprecazione Command0/Command1 della foundation legacy. Coordinate checkpoint (riga:colonna, lunghezza):

| File relativo | Istanze diagnostiche |
| --- | --- |
| lib/ui/search/view_models/search_view_model.dart | 23:25:15, 23:32:8, 24:24:15, 24:31:8, 31:30:15, 31:37:8, 56:15:8, 61:15:8, 72:15:8 |
| lib/ui/geo_map/view_models/geo_map_view_model.dart | 44:18:15, 44:25:8, 51:18:15, 51:25:8, 53:29:15, 53:36:8, 54:24:15, 54:31:8, 77:15:8, 80:15:8, 81:15:8, 82:15:8 |

Futuro gate: 87→66 INFO, rimozione esatta delle 21 target, nessuna nuova identità/molteplicità non-target (normalizzare root; per righe spostate identificare simbolo e messaggio, non nascondere differenze). Nessuna soppressione/config analyzer. Sette è il numero di Command target residui in queste due superfici, non il totale globale: le altre 66 INFO restano per change successive.

### Evidenze e contratti correnti

I riferimenti riga sono del checkpoint, tutti relativi al worktree sopra.

| Fonte | Evidenza rilevante |
| --- | --- |
| `lib/ui/search/view_models/search_view_model.dart:21–49,103–158` | Tre legacy; bootstrap automatico; add/remove ottimistici; load sostituisce tutta la lista; guard solo dopo await; disposal oggi distrugge solo results/suggestions. Add deduplica case-insensitive ed esclude etichette delle categorie note; remove è exact-case e rollback appende in coda. |
| `lib/ui/search/widgets/components/app_search_anchor.dart:169–175,177–229,253–317,352–358` | Submit: add, close popup, navigazione; suggestion/chip/categoria chiamano add, delete chiama remove. Cronologia letta su input vuoto. Popup può sopravvivere allo State; cached history, mounted guard, timer e controller ownership sono necessari. Reset chip differito già esistente. |
| `lib/domain/repositories/search_repository.dart:5–21`; `lib/data/repositories/search_repository_impl.dart:72–96,213–250` | getAllAsync cronologia in ordine box, add duplicati case-insensitive, remove query exact-case; Exception infrastrutturali diventano Result.error con logging; nessun contratto di serializzazione tra chiamate. Non cambiare repository/ObjectBox. |
| `lib/ui/geo_map/view_models/geo_map_view_model.dart:41–82,117–176,230–282` | Quattro legacy; bootstrap eventi e luoghi indipendente; filtri iniziali tutti noti/tutti i tipi; setter memorizzano alias Set, confrontano per valore, svuotano entrambe le liste; reload entrambi in ordine eventi→luoghi, oppure solo il tipo abilitato, nessun I/O con tipi vuoti. Gli errori dei figli non diventano errori del setter. |
| `lib/ui/geo_map/widgets/geo_map_screen.dart:424–450,525–535` | Marker ascoltano entrambi i legacy e attendono entrambi completed; rendering eventi→luoghi. Selector keyed ObjectKey(owner), callback ai setter; nessun consumer attende il Result dei setter o richiede uno stato Command per essi. |
| `lib/ui/geo_map/widgets/geo_map_bottom_sheet.dart:105–175` | Proietta mode/Search/Post/Nearby; nessuna ownership del caricamento marker. Non aggiungervi stato concorrente. |
| `lib/domain/use-cases/geo_map_use_case.dart:12–45` | getAllEvents→EventRepository.getByCurrentYear; getAllPlaces→PlaceRepository.getAll con default byName. Fetch separati e modelli finali; preservare ordine restituito e filtri temporali, nessun getById per marker. |
| `lib/routing/router.dart:326–360,494–497`; `test/routing/geo_map_route_test.dart:856–906` | Search owner separati per route, bootstrap/disposal reali; la route Map conserva owner e identità semantiche. |
| `lib/ui/category/widgets/category_content_and_type_selection.dart`; test omonimo | Draft per campo, applica il draft alla conclusione consentita della route (Salva/Back/barrier/drag), senza distinzione Cancel; empty→all soltanto se mounted/current; owner replacement rende obsoleta la sessione. Non cambiare questo contratto. |

Inventario completo dei sette Command (nessun listener di risultato cronologia production trovato):

| Legacy | Chiamanti / bootstrap | Dipendenza e stato osservabile | Errori / disposal correnti | Destinazione proposta |
| --- | --- | --- | --- | --- |
| Search.addToPastSearches | submit, suggestion, history chip, category chip in AppSearchAnchor | repository.add; pastSearches + notify; lane indipendente | rollback remove su Result.error; guard tardiva; legacy non disposed | dispatch sincrono verso FIFO del writer con ResultCommand privato |
| Search.loadPastSearches | constructor unawaited; test espliciti | repository.getPastSearches; sostituzione lista + notify | failure conserva lista; può sovrascrivere mutazioni; legacy non disposed | ResultCommand<void,void> con read revisionato |
| Search.removeFromPastSearches | delete chip AppSearchAnchor | repository.remove; pastSearches + notify | rollback append anche se assente; legacy non disposed | dispatch sincrono verso la stessa FIFO ordinata |
| Map.loadEvents | constructor; _load; screen listeners; test | useCase.getAllEvents; allEvents filtrati dopo await | success notifica, failure originale; guard disposed | una sorgente di loadMarkers restartable |
| Map.loadPlaces | constructor; _load; screen listeners; test | useCase.getAllPlaces; allPlaces filtrati dopo await | come eventi | seconda sorgente di loadMarkers |
| Map.setSelectedCategories | selector screen, test | alias set; _load; notify dopo reload | restituisce success anche con child failure; guard tardiva | setter void sincrono, copia immutabile |
| Map.setSelectedTypes | selector screen, test | alias set; _load; notify dopo reload | come categorie | setter void sincrono, copia immutabile |

### Foundation e specifiche confrontate

`pubspec.lock:228–234`: command_it **9.5.2**. Letti sorgenti locali risolti `command_it.dart:312–386,420–446,799–870,920–1024`, oltre a `lib/utils/{command,result_command,restartable_command,command_configuration}.dart` e test foundation. run imposta isRunningSync inline, differisce action entry di un turno zero, scarta duplicati; runAsync può joinare e non prova admission. Result.error resta un valore; raw throw resta Object/stack con globalHandler; assertion fail-loud. Il vecchio Command invece cattura Object in Error Result + FlutterError. Non replicare tale conversione. Nomi debug costanti, niente query/parametri nel reporting.

Risultati ordinary sono notificati sincronicamente; solo isRunning UI è differito. Restartable usa envelope e risultati pubblici differiti, revoca autorità immediatamente e non cancella I/O fisico. Le action restartable non committano dopo await. command_it.dispose ha teardown differito 50ms e limite noto sui throw tardivi: per reader ordinary e Command privato del writer riprendere cleanup locale di Category/Content che attende settlement privato e lascia dispatch/reporting prima di dispose, anche quando logicamente idle. Nessuna nuova utility generica. Non usare runAsync completion o solo false sync come prova di successo/fine dispatch.

Confrontati proposal/design/tasks/delta degli OpenSpec 1–3: ordinary optimism/progressivi sono permessi dal MODIFIED di simple, non dalla canonical ancora più restrittiva; Category fornisce il precedente setter sincrono/snapshot e owner-keyed dialog; Content esplicita lifecycle, entry differita e terminal authority. Delta di questa change aggiungono requisiti, non riscrivono quel MODIFIED. **Riconciliazione documentata:** in consolidamento applicare il MODIFIED di OpenSpec 1 prima dei nuovi requisiti Search ordinary; fino ad allora leggere canonical + delta cumulativi insieme. Non copiare una versione tronca del requisito canonical.

`openspec/specs/local-content-retrieval/spec.md` tutela ricerca mista, risultati/suggestions indipendenti, short query, ordine e atomicità: nessun delta a questi requisiti. `harden-geo-map-semantic-state/specs/geo-map-semantic-state/spec.md` è una capability in change completata, non canonical autonoma: mode, Post, Search fence, Weather, Nearby e route rimangono invarianti. Il suo delta local-content-retrieval prescrive partial Places→Events **per Nearby**; i marker hanno invece ordine Events→Places. Non estendere né sovrascrivere quella regola. Non creare una seconda capability semantic-state o modificarne gli artifact.

## Goals / Non-Goals

Commit marker appartenente a uno snapshot coerente; cronologia ottimistica senza overwrite di read obsoleti o rollback incrociati; lifecycle verificabile. Limite di coordinazione Search: una sessione writer e i suoi intenti accepted, nessuna promessa di ordinamento globale tra owner che condividono repository. Foundation, persistenza, query di ricerca, selezione Post, Weather, Nearby, controller/sheet e routing restano alle ownership esistenti.

## Decisions

### D1 — F1/F2: admission sincrona e writer locale ordinato

**Decisione nuova, sostituisce D1 iniziale.** SearchViewModel conserva `loadPastSearches` ordinary. Add/remove diventano metodi di dispatch verso una **sessione writer privata della feature**, nello stesso file del VM: possiede SearchRepository, FIFO, base ordinata, proiezione e un solo `createResultCommand<HistoryMutation,void>` riutilizzato. Non è un nuovo Command framework, servizio DI, repository, singleton o API cross-feature. Il VM osserva la sessione solo finché vivo. L'action del Command cattura esclusivamente repository + richiesta immutabile e invoca una volta il metodo add/remove: non legge State, BuildContext, `_disposed` del VM o callback UI. Non bypassare run dalla View.

Distinguere questi stati, senza dedurli dal solo running:

| Stato | Significato e ownership |
| --- | --- |
| proposta non ammessa | callback non ancora autorizzata; nessun obbligo o epoch |
| excluded / represented | empty/category o intenzione già rappresentata; nessuna nuova entry/write, non è una nuova persistenza riuscita |
| accepted(sequence) | obbligo immutabile trasferito al writer; FIFO/epoch/barriera già installati; non revocabile dalla successiva navigazione |
| Command-admitted | testa passata a run, running sync true; entry repository ancora differita |
| persistence-started | action entrata e metodo repository invocato esattamente una volta |
| physical-settled | Future repository restituisce Result o throw; reporting/dispatch Command devono ancora poter terminare |
| entry-settled | pump fuori dispatch ha acquisito l'esito originale, aggiornato stato privato e liberato testa/receipt |
| UI-detached | nessuna nuova acceptance/notify/rollback UI/read; writer vivo fino al drain degli accepted, incluse entry queued |

L'admission logica è atomica e sincrona: verificare owner/sessione callback corrente; classificare deduplica; assegnare sequence; appendere entry con receipt **Future<void>** privato; incrementare epoch e installare/ottenere il drain Future della FIFO prima di ogni notify o observer. Una receipt void segnala settlement, mai success implicito o completeError non osservato. Se prima testa, run prima della notifica ottimistica; le successive sono già accepted ma Command-admitted solo dopo la testa. Reentrancy dalla notifica vede quindi stato completo e non può cancellare la write accettata. Non esiste una finestra in cui G0 veda epoch precedente a un'intenzione già accepted. Un callback di conferma riserva prima del dispatch un token di follow-through e consuma l’ammissione della popup: la stessa popup non può generare altri intenti durante reentry. Dopo dispatch deve ricontrollare host mounted, owner/controller correnti e token prima di closeView e ancora prima della navigazione, come D5/U6. L’obbligo già accepted non dipende dal risultato di tali controlli UI. Ogni accepted mantiene il suo tentativo, anche se rebase successivo rende la trasformazione localmente no-op.

**Deduplica:** mantenere stringa originale, nessun trim/threshold nuovo. Empty o etichetta categoria nota ignoring-case sono esclusi sempre. Add usa confronto case-insensitive; remove exact-case come ObjectBox. Classificare prima applicando la trasformazione a P corrente (quindi includendo tutte le opposte in Q): può essere represented solo se P non cambierebbe e quel desiderato è dimostrato dalla base nota non incerta o da un’intenzione pending equivalente non superata da un’opposta. La sola membership in B non basta quando Q la modifica. Esempi: add(A)→add(a) è represented; add(A)→remove(A), remove(A)→add(A), add(A)→add(B), remove(A)→remove(B) sono accepted quando cambiano il desiderato. Se bootstrap non ha stabilito la base, assenza locale non dimostra assenza persistita: remove(A) va accettata, pur senza notifica se lista già vuota. Dopo runtime failure la sola base provvisoria non prova ridondanza; un nuovo intento esplicito che altrimenti dipenderebbe da tale incertezza è accepted. Callback obsolete sono rejected prima del dispatch, non deduplicate nella FIFO. Non coalescere operazioni opposte o eliminare retroattivamente entry accepted.

**Proiezione e rollback per operazione:** la sessione mantiene base `B` (ultimo stato confermato, eventualmente provvisorio dopo runtime) e pending `Q`. Visibile `P = fold(Q, B)` con add append se assente ignoring-case, remove exact-case se presente. Admission aggiorna P immediatamente; VM live notifica una volta **solo se** la lista ordinata cambia, prima della persistenza. Nessuna mutazione dopo notify assume il vecchio owner. Al settlement della testa: success applica la trasformazione a B; Result.error lascia B invariata; runtime applica la trasformazione provvisoriamente a B e marca storage incerto. Quindi rimuove solo quella entry, ricalcola P con tutte le intenzioni successive e notifica se P cambia. Non ripristinare una copia globale catturata prima di altre acceptance. Senza pending successiva il Result.error ripristina esattamente il precedente ordine. Con pending successiva il rebase può lasciare P uguale e richiede zero notify, ma quell'entry eseguirà comunque la sua write. Errori originali restano nell’esito della singola entry, nessun successo di batch inventato. Il segnale privato di sessione comunica anche settlement/domanda di read quando P è uguale: il callback detached non viene invocato, quello live aggiorna scheduler a prescindere da N; soltanto notifyListeners VM è condizionato al cambiamento di P. In particolare un runtime dopo commit con P uguale deve comunque schedulare F4.

**Ordine fisico:** un solo metodo repository in volo per sessione. Il pump registra il terminale della testa e, dopo non-running, usa il confine microtask→event già adottato nei lifecycle precedenti. Ricontrolla identità `paramData` della testa, non-running e token del pump; solo fuori dispatch/reporting fa reducer/pop, completa receipt e chiama run sulla nuova testa. Non iniziare il prossimo run dentro results/value listener o finally dell'action; non usare runAsync come admission/settlement. Success, Result.error e runtime handled non fermano il drain; nessun retry automatico delle write. Future non terminante blocca la FIFO fisica, non autorizza inversioni d'ordine o drop.

**F1:** AppSearchAnchor autorizza una conferma contro la sessione popup/owner corrente, poi chiama dispatch, chiude popup e naviga immediatamente senza await. `accepted → run(head) → closeView → navigation/dispose → deferred action entry → repository → settlement` deve produrre una write. Se esistono predecessori pending, la submit resta accepted e viene eseguita dopo di essi anche se la UI è detached. La UI può essere disposed prima della prima notify o action: nessun publish tardivo, ma l'obbligo rimane. La persistenza non deve attendere bootstrap, notifiche, widget o reader. Il writer conserva solo dati privati; detach azzera il callback VM e nessuna closure futura lo cattura.

Alternative scartate: lane comune con drop perde F2; due Command indipendenti consentono write invertite e rollback incrociati; writer restartable annulla autorità di intenti che devono invece persistere; repository dalla View rompe confine; attendere bootstrap/navigation cambia F1; un Command per entry complica risorse senza beneficio rispetto a uno riutilizzato. FIFO locale è giustificata da intenti validi che arrivano mentre la primitiva single-flight è busy. Nessuna promessa cross-owner: un replacement ha la propria sessione e il suo bootstrap può precedere il drain del predecessore; non è stato introdotto un lock condiviso nello storage.

### D2 — F3/F4: unico protocollo admission/write/read

**Decisione nuova, sostituisce D2 iniziale.** Stato minimo: epoch `E` monotona nella sessione (aumenta ad ogni acceptance e settlement), Q/base di D1, drain Future installato sincronicamente quando Q passa vuota→nonvuota, segnale UI-detached separato, storage incerto, e una domanda di read `requested` distinta da `attempted`. Le due ultime generazioni distinguono bisogno non ancora tentato da incertezza che può persistere dopo errore. Non installare settlement Future nell'action differita. Completi receipt dopo aver aggiornato base/Q/E; completi il drain soltanto quando tutte le entry accepted sono fisicamente settled e fuori dispatch. Se un listener accetta una nuova entry dopo il drain, installare il nuovo barrier prima di notify: chi si risveglia ricontrolla Q/E e non può leggere tra le due intenzioni.

Bootstrap richiede una volta un read tramite `loadPastSearches = createResultCommandNoParam<void>`. Un solo read fisico alla volta. Ogni esplicita richiesta mentre il medesimo load è attivo è coalescente (nessun futuro pendente per il chiamante e nessuna promessa di success). Una acceptance invalida immediatamente qualsiasi read già in volo e richiede riconciliazione se c'è read in volo o base non ancora nota; un runtime write richiede sempre riconciliazione anche senza read pending. Success/Result.error su base nota senza read concorrente non aggiungono query superflue. Domande della stessa finestra di write si coalescono al valore requested più recente.

Protocollo reader:

1. Il scheduler, solo se UI live e load idle, avvia un load per domanda non ancora tentata; non chiama run mentre busy. L'action attende `drain OR UI-detached` se Q non vuota, poi ricontrolla UI e Q. È un'attesa di completamento, nessun polling. Il writer **non attende mai** bootstrap, load, read o UI: grafo di attesa aciclico.
2. Immediatamente prima di `getPastSearches`, con Q vuota e UI viva, catturare E e consumare la domanda corrente (`attempted = requested`). Nessuna await/notifica tra controllo, cattura e inizio get. Una nuova acceptance dopo questo punto cambia E e può registrare nuova domanda.
3. Success può sostituire B con una copia ordinata solo se UI ancora viva, E uguale e Q ancora vuota. A quel punto base nota, incertezza risolta, P ricostruita e notify solo se la lista ordinata cambia. Risolvere l’indicatore di get fisico prima di notify: “read in volo” significa get con autorità ancora irrisolta, non il Command che resta busy durante terminal dispatch. Una write accepted dal listener del commit valido usa la base appena confermata e non richiede un get ridondante solo perché load è ancora busy. Un vecchio successo, anche con contenuto per caso uguale, non è un commit.
4. Success obsoleto viene scartato senza notify. Il medesimo load attende il drain più recente e tenta una lettura per l'ultima domanda, mantenendo un solo read fisico; ulteriori acceptance possono invalidare anche questa, senza query per ogni revisione intermedia.
5. Qualsiasi get Result.error termina quell'esecuzione con l'Exception originale e lista conservata. Un raw get throw resta runtime con reporting una volta. Nessuno dei due riaccoda **la domanda appena tentata** perché la base è ancora sconosciuta/incerta. Se una domanda più recente è sorta dopo l'inizio di quel get (per esempio G0 precedente a W), resta pending e lo scheduler la tenta una sola volta dopo terminal/reporting del vecchio load e drain. Un errore vecchio non consuma una domanda futura. Se non esiste domanda più recente, serve retry esplicito o nuova mutazione: niente loop automatico su failure.
6. Dispose risveglia il reader con il segnale UI-detached, revoca scheduler e azzera callback verso VM. Il waiter termina senza nuovo get/notify. Non completare artificialmente il drain fisico o le receipt delle write; accepted writer resta vivo. Get già iniziato può terminare privatamente, senza commit. Tutti i waiter reader hanno quindi uscita su disposal anche con write non terminante.

**F4:** il runtime della write mantiene provvisoriamente l'ottimismo, conserva Object/stack nel Command e marca nuova domanda di read **prima** del completamento della receipt/drain. Lo scheduler usa lo stesso load/epoch/barrier, mai un secondo percorso. Nessun retry write. A UI viva e FIFO drained, viene tentato un get stabile anche senza G0 pending. Se W2 era già accepted, nessun read fra W1 fallita e W2: dopo W2 il get riflette entrambe, senza sovrascrivere P con uno snapshot precedente. Throw prima di commit e dopo commit sono indistinguibili fino a questo get; storage reale decide B. Se quel get fallisce, un tentativo è consumato, la lista provvisoria resta e l'errore read è distinto dall'errore write (ognuno reportato una volta se runtime). UI disposed prima del get: zero riconciliazione. Nessuna convergenza automatica garantita senza I/O riuscito e UI viva.

Invarianti anti-deadlock: admission non aspetta read; write non aspetta read o disposal UI; read aspetta solo drain oppure detach; next write dipende solo da settlement/reporting del predecessore. Le notification VM avvengono dopo installazione dello stato; reentrancy può accettare altre entry o disporre e il pump/scheduler ricontrollano token/owner prima di ogni successiva fase UI. Gli errori non rigenerano da soli una domanda consumata.

### D3 — GeoMap: snapshot, bootstrap, vuoto e retry

Due setter void sincroni copiano set immutabili; iniziali tutte categorie note meno unknown e tutti ContentType. Confronto per valore, non identità wrapper; non mutare set esposti o del chiamante. Unknown non diventa una categoria iniziale; la normalizzazione rimuove unknown. **Vuoto programmatico** categorie o tipi significa nessun marker e zero I/O. Il dialog condiviso conserva invece empty-draft→all alla conclusione consentita della route con State/sessione correnti: non modificarlo per ottenere il vuoto programmatico.

Un `RestartableCommand<MarkerFilterSnapshot,MarkerOutcome>` loadMarkers sostituisce entrambi i load. Ogni snapshot contiene le copie dei set e un ticket Object nuovo per admission; il VM conserva lo snapshot corrente per identità e verifica il ticket di paramData nel completion observer. La deduplica dei setter confronta solo i set, mai il ticket; A2 non riusa quindi A1. Constructor inizializza listener/campi prima di una sola admission con filtro iniziale; lo stato sincrono deve già essere loading. Selezione identica senza cambi intermedi è no-op, anche dopo errore o mentre pending; il retry è un metodo distinto che legge il filtro **corrente all'attivazione** e ammette un nuovo intento anche uguale. Retry durante pending è rifiutato senza I/O; dopo fallimento ritenta tutte le sorgenti selezionate. A→B→A vale tre generazioni, anche con parametri uguali alla prima A.

Prima del run/invalidate cancellare entrambe le collezioni e il terminale marker del VM. Stato sincrono di admission/ticket deve impedire accesso al vecchio terminale anche prima della pubblicazione deferred. Per filtro non vuoto ammettere nuova generation con run e notificare una volta se ancora proprietario dopo reentry. Per vuoto invalidare il vecchio load, committare immediatamente success-empty locale, notify una volta; nessuna action deve partire nemmeno se un vecchio envelope era queued. Non interpretare blank del Command come successo vuoto. Retry vuoto conserva success-empty senza I/O o notifica aggiuntiva.

### D4 — Fetch, atomicità e fallimenti parziali marker

Mantenere fetch separati tramite GeoMapUseCase, sequenza **eventi poi luoghi** quando entrambi selezionati, non Promise/Future.wait che introduce wrapper runtime/ordine reporting diversi. Bootstrap passa quindi da due fetch indipendenti a una sequenza coerente; è una differenza esplicita. Result.error eventi non impedisce query luoghi. Event-only/place-only interroga solo quella sorgente; lista del tipo escluso sempre vuota. Filtrare con categorie dello snapshot, preservare ordine interno repository e concatenazione Events→Places. Nessun sorting/deduplica nuovo, nemmeno tra tipi con stesso id.

La action accumula solo valori locali. L'outcome locale immutabile contiene eventi, luoghi, eventError e placeError originali: `Result.success(outcome)` significa completamento del protocollo, **non** successo completo delle sorgenti. Proiezione UI deve usare errori nell'outcome: nessun errore→success-data/empty; uno o entrambi→failure, con partial items se presenti. Se entrambi falliscono conservare entrambi gli errori e priorità eventi per l'errore principale. Esiti con errore e zero items sono failure, mai empty-success.

Dopo la prima attesa controllare owner/disposal prima della seconda fase; revocare autorità di commit per supersession tramite RestartableCommand. Non promettere abort fisico del secondo fetch su sola supersession se il primo era già entrato: può continuare, ma nessun commit/notify. Disposal invece vieta nuove fasi owner-controlled. Un raw throw termina l'intera esecuzione prima della seconda fase se non ancora iniziata; nessun catch Object→Result e nessuna pubblicazione parziale da runtime failure richiesta. Originale + stack global una volta, anche stale. Assertion conserva fail-loud.

Il completion observer live controlla ticket/snapshot corrente e terminale, copia insieme entrambe le liste e terminale marker, poi notify una sola volta. Mai commit di una sorgente prima dell'altra o dopo notify. Aggiornare terminale anche su runtime failure (liste vuote). Stato non guidato da vecchi completed o da !isRunningSync isolato. Nessun accoppiamento con modalità o Nearby.

### D5 — Presentazione marker e callback

GeoMapScreen osserva il VM e loadMarkers.results; rimuove merge dei due legacy. Loading mostra indicatore discreto overlay mappa e nessun marker obsoleto; success-data mostra MarkerLayer; success-empty mostra messaggio non bloccante «Nessun contenuto per i filtri selezionati»; failure mostra messaggio generico + Riprova non bloccanti, mantenendo gli eventuali marker parziali dell'outcome corrente. Il terminale locale corrente autorizza la proiezione, non il solo Command.completed. Lo status rimane leggibile in Explore/Search/Post senza cambiare sheet/mode; non riusare EmptyView fullscreen che nasconda mappa o navigazione. Errori non stampati nella UI, nessuno snackbar per ogni rebuild.

Retry e marker tap catturano owner e terminale/generation attesi: mounted, stesso Provider/widget owner e stessa ammissione prima di agire. Callback da un marker rimosso o owner A dopo B non può selezionare contenuto/ritentare su B o riaprire vecchio Post. Mantenere ObjectKey(owner) sul selector e guard della sua sessione; setter diretti solo dopo conclusione della route con sessione corrente, zero doppia admission. Notifiche di collezione non ripetono camera/sheet entry effect: quei controller restano basati sull'esatto mode/materialization corrente.

AppSearchAnchor cambia dispatch history e autorizzazione callback (F1/U6): controlli mounted prima di State.widget/context; owner/controller/sessione attuali per callback differite e cached chip. Il reset differito dopo delete non deve svuotare input di owner/controller rimpiazzati o di un nuovo input. Catturare owner/controller prima di await; mantenere cached safe defaults nei popup builder e non chiudere di nuovo una popup già popped. Regressioni su close→goNamed/unmount restano obbligatorie. Prima di futuri edit widget applicare la skill mounted-context-safety e skill test/support pertinenti.

Per submit/suggestion, catturare owner/controller e callback soltanto dopo il primo mounted/session check. Dispatch può notificare sincronicamente e disporre/rimpiazzare l’anchor: **ricontrollare** mounted, owner/controller e token conferma dopo dispatch, prima di closeView, e dopo closeView prima di invocare la callback host (che può leggere il proprio State.context). Se invalidato, fermare ogni follow-up UI, mantenendo la persistenza accepted. La chiusura eseguita dalla conferma consuma la vecchia popup per nuove admission ma non revoca da sola il token del proprio follow-through: altrimenti ogni submit legittima perderebbe navigazione. Nuovo intento semantico, owner replacement o unmount revocano invece anche quel token. `_handleOnClose` non deve effettuare un secondo pop o riesumare callback obsolete.

### D6 — F1–F4: due lifecycle, reporting e reentrancy

Disposal VM idempotente revoca subito admission, presentazione e scheduler read, stacca callback/observer, completa esclusivamente il segnale di uscita dei waiter UI e dispone results/suggestions e marker wrapper secondo contratti esistenti. Un dispatch non ancora accepted o una callback stale non crea write. **Non disporre il Command del writer con il VM**: la sessione ha ricevuto prima del disposal ownership degli intenti accepted ed è ancora viva, incluse le entry non ancora Command-admitted. Continua il suo protocollo FIFO senza alcuna chiamata al vecchio VM, State o context. Quando detached e drained, rilascia notifier/listener/Command fuori dispatch esattamente una volta e libera entry/receipt/callback. Il reader ordinary owner-controlled non avvia fasi dopo detach; conserva privatamente il Command se un get già avviato deve ancora riportare runtime.

Il writer non cattura il VM in action o pump. L'unico callback verso UI è detachable e controllato prima dell'invocazione, anche dopo reentry; le mutazioni di base/Q dopo detach sono **stato privato della sessione**, non `_pastSearches` del VM disposto. Il VM conserva la sua ultima proiezione immutabile senza rollback/notifiche tardive. Nessun report manuale di runtime: factory globalHandler con Object/stack originale una volta; Result.error rimane valore senza report runtime; receipt void non genera un secondo errore asincrono. Non interpretare wait completion come successo.

Cleanup segue il confine microtask→event/invalidazione su transizioni sync delle change precedenti; non disporre su solo terminal result, isRunning false isolato, receipt o nel finally dell'action. Il writer viene riutilizzato solo fuori dispatch/reporting; il teardown upstream 50ms non è una barriera di settlement. Assertion mantiene fail-loud e non viene trasformata in Result.error o normale terminale recuperabile: il ramo upstream senza terminale deve comunque liberare waiter/risorse private come abort di sviluppo, senza fingere persistenza riuscita o promettere prosecuzione normale della FIFO dopo un'assertion. Testare separatamente questo ramo; StateError/TypeError handled continuano invece il drain.

**Riconciliazione con OpenSpec 1–3:** non si cambia la loro policy degli owner disposed. Qui la sessione writer è un owner distinto ancora vivo, avviato sincronicamente all'acceptance, mentre l'owner UI si detach. Come il protocollo già iniziato Sync, le sue fasi non appartengono più al VM disposto. Reader, risultati/suggestions, Map/Post/Nearby e tutte le vecchie lane conservano il divieto di nuove fasi owner-controlled dopo disposal. Questa separazione è esplicita nel delta locale; non riscrive o indebolisce il MODIFIED di OpenSpec 1. Nessuna serializzazione cross-owner, ownership app-scoped o riuso della sessione da replacement.

## Concurrency matrix

| Confine / sequenza | Stato immediato | Settlement e I/O consentiti |
| --- | --- | --- |
| load history bootstrap + add/remove | acceptance installa E/Q/drain e ottimismo same-stack | G0 invalidata anche prima entry W, get stabile soltanto dopo drain |
| add→add equivalente | seconda represented solo se ridondanza dimostrata | una write, nessun falso esito per seconda richiesta |
| add→remove / remove→add / voci diverse | tutte le distinte accepted nella FIFO, E subito aggiornata | write una per entry in sequence, rebase per-op, zero drop |
| load→load busy / runtime reconciliation | domande coalescenti, mai run contro lane busy | al massimo un read fisico; domanda stabile consumata anche se get fallisce |
| UI disposed prima entry W accepted | UI detached, writer ancora vivo | tutti accepted persistono in ordine, nessun get/notify UI nuovo |
| Map filtro A→B→A | snapshot/collezioni invalidate e nuovi ticket subito | solo ultimo A terminale/notify; completamenti vecchi non cambiano running corrente |
| Map identico pending/success/failure | stesso stato e ticket | zero I/O/notify; failure ha retry distinto |
| Map filtro vuoto | success-empty locale e vecchia authority revocata | zero nuovi fetch; late success/error ignorati |
| Map retry corrente | pending e liste nascoste subito | nuovo ticket e selected-source fetch; retry busy scartato |
| listener ammette B/dispose durante notify | ticket Map o E/Q Search già coerenti | nessun effetto UI vecchio; writer mantiene soltanto obblighi Search già accepted |
| owner A→B / navigate/unmount | vecchi observer/callback revocati | settlement A privato, mai commit su B o feedback vecchio |

## Regression plan

### Supporti e protocollo comune

Riutilizzare `test/support/{fake_repositories,controllable_search_repository,command_test_support,ordinary_view_model_lifecycle_support,route_ownership_fixture,fixtures}.dart`. FakeSearchRepository ha già load/add/remove Completer e contatori; estendere in support le sole sequenze mancanti. ControllableSearchRepository resta per results/suggestions. Per marker usare GeoMapUseCase reale con fake Event/Place e queue di Completer per ogni invocazione. Nessun fake di GeoMapUseCase che nasconda parametri/ordine. Prima di edit test leggere skill reuse + unit/widget pertinenti. Non creare test helper locali duplicati.

Ogni riga sottostante è un test o parametrizzazione esplicita: registrare notifica VM separatamente da snapshot Command (ordinary loading→terminale, restartable deferred). `N` misura delta dopo aver stabilizzato setup, `C` chiamate repository nell'azione descritta. Prima asserire stato same-stack; poi avanzare entry con `pumpCommandTurns` o pump zero controllati; solo dopo risolvere Completer e drenare turni documentati. Event loop turns non sono attese temporali per sperare nel completamento. Per timer debounce/animation/reset e limite 50ms usare clock virtuale del test, senza sleep wall-clock. Risultati/ordering/notifiche dopo ogni fase, non solo a fine test.

| ID | Setup e sequenza controllata | Sincrono / entry attesi | Settlement, N e C; error/lifecycle |
| --- | --- | --- | --- |
| S1 | Nuovo Search, bootstrap G0 pending; richiesta load duplicata; G0→[a,b] | load admitted, P=[]; Cget=1 dopo entry, duplicato coalescente | P=[a,b], N=1; success distinto neutral; nessun get extra |
| S2 | Base nota [a,b]; add c oppure remove a; hold W | acceptance/epoch/barrier e ottimismo same-stack: [a,b,c]/[b], N=1 prima action | success N extra=0, Cwrite=1; Result.error P=[a,b], N extra=1, stessa Exception/global=0; nessun get aggiuntivo su base nota senza read |
| S3 | Base nota [a,b]; add empty/categoria/A; remove assente o case mismatch | excluded/represented, E invariato, N=0 | write/get extra=0, nessuna finta admission-success; parametrizzare base sconosciuta/incerta: assenza non dimostrata→accepted remove, write=1/N=0 |
| S4 | Le otto sequenze F2 nella tabella sotto; due dispatch same-stack, W1 pending | distinte accepted in FIFO, duplicate represented; P immediato e N definiti sotto | W2 mai prima del settlement/reporting W1; C/order/finale/rollback sotto; niente completion fisica fuori ordine perché write seriali |
| S5 | G0 pending E0; accepted add c ma W non entrata; G0→[a,b] prima entry W | E già cambiata, P=[c] N=1; G0 non può committare nonostante Command entry differita | G0 scartato N=0; W entry Cwrite=1, settle; G1→[a,b,c] N=1; Cget=2, nessun G1 prima drain |
| S6 | Base nota [a,b]; reload G0 pending; remove a; W success prima G0→[a,b]; G1→[b] | P=[b] N=1, E acceptance già invalida G0 | nessuna resurrezione; G1 lista uguale N=0, Cget extra=2/write=1; invertire ordine G0/W con stessi esiti |
| S7 | Base nota []; add A; throw prima commit / dopo fake store commit; nessun read pending | P=[A] N=1, write=1; nessun rollback alla sola throw | global W=1 originale/stack, G1 obbligatorio dopo drain Cget extra=1; prima commit G1=[]→N=1, dopo commit G1=[A]→N=0; zero retry write |
| S8 | G0 pending; accepted add A e add B prima entry W1; settle W1/W2, poi G0 | P=[A,B], N=2, E invalidata da entrambe; W2 pending senza write concorrente | writes=[add A,add B], get=G0+G1 (2), G1 stabile finale contiene persisted A/B e vecchia base; una sola reconcile per burst, nessun read tra W1/W2 |
| S9 | accepted W, dispose prima action / da notify / durante await; eventuale W2 accepted prima detach | obblighi già nella sessione, UI last snapshot immutabile; richieste dopo detach rejected | Cwrite=numero accepted anche dopo detach; N post-dispose=0, get nuovi=0; runtime global=1 ciascuno, risultati expected non reportati; terminal/idle/assertion cleanup separati |
| S10 | G stabile Result.error/runtime senza nuove domande; retry esplicito | lista conservata; attempted consuma domanda, nessun self-retry | Cget=1 per tentativo, esplicito retry Cget+1; N solo se success cambia lista; domain global=0/runtime=1 |
| S11 | G0 pending; W accepted; G0 Result.error oppure throw durante W; W success | nessun rollback da read; domanda W più recente non consumata da G0 | G0 errore originale, runtime se presente global=1; dopo drain un G1, Cget=2, poi stop se G1 error; nessun loop da base sconosciuta |
| S12 | G0 stale success; reader aspetta drain di W non terminante; dispose | UI-detached signal completa attesa, non drain/receipt fisici | reader termina senza nuovo get/N; W può completare dopo dispose write=1, report/cleanup privati; nessun waiter UI bloccato |
| S13 | Runtime W1 con W2 già accepted (opposta e altra voce); G0 pending oppure assente | P include W2, niente read fra W1/W2 | write order invariato, global W1=1; un G1 post-drain all'ultima E (più G0 se già in volo), finale storage reale; read vecchio non sovrascrive W2 |
| S14 | Runtime W senza G0; dopo drain domanda G1; G1 Result.error/runtime | proiezione provvisoria mantenuta; nessun rollback inventato | Wwrite=1, G1get=1, nessun retry write/read spontaneo; domain G1 global=0/runtime G1=1 distinto da W; esplicito load può ritentare |
| S15 | Runtime W; dispose dopo throw ma prima scheduled G1 action/get | pending domanda non autorizza UI disposed | write=1/report=1; G1 repository=0, N post-dispose=0, waiter reader rilasciato |
| S16 | Base nota []; listener admission add A accetta add B; variante listener stable get=[A] accetta add C; variante settlement listener accetta W3 con reader su vecchio drain | prima variante P=[A,B]/N=2 prima write; seconda commit [A] N=1 poi [A,C] N=1 con get fisico già risolto | prima write=2/get extra=0/N settlement=0; seconda get=1/write=1/nessun get extra e N settlement=0; terza reader aspetta nuovo drain e non committa vecchia E; dispose da listener→N futuro=0 |
| S17 | W1 Result.error con W2 opposta/voce diversa accepted; G0 prima/durante/dopo W1 | nessuna restoration di predecessor globale | rebase elimina solo W1, preserva trasformazione W2; write=2 in ordine; se G0 invalidata una sola G1 dopo entrambe; error W1 originale/global=0 |
| S18 | Runtime W rende B incerta; nuovo add A o remove A sembra già rappresentato dalla sola B provvisoria; e duplicato rappresentato da pending | nessuna deduplica su sola conoscenza incerta; entry nuova accepted, duplicato pending equivalente represented | nuovo intento produce write=1, no autoretry W; reconcile coalescente dopo drain; P non notifica se uguale, snapshot stabile risolve incertezza |
| G1 | Nuovo Map, eventi E pending; dopo E success avvia P pending | initial all known/all types, loading, liste vuote; E=1 P=0 finché E pending | E da solo N=0 e zero marker parziali; P success→N=1 e liste atomiche, E=1/P=1, events→places |
| G2 | Bootstrap concluso; filtri event-only/place-only/entrambi con categorie note; mutare Set chiamante dopo setter | getter snapshot immutabile, vecchie liste vuote, loading N=1 | E/P=(1,0)/(0,1)/(1,1), filtro catturato, terminal N=1; ordine repository e cross-type id preservati |
| G3 | A completed/pending/failure; ripetere copie set uguali; poi categorie vuote o tipi vuoti | uguali N=0; vuoto N=1 success-empty subito, vecchia authority revocata | uguali/empty C=0; completamento vecchio N=0, nessun blank interpretato erroneamente; retry empty N=0/C=0 |
| G4 | Avviare A, entry E; poi B, entry E; poi A2 entry; completare A2 prima dei vecchi | ogni distinto set N=1, liste vuote subito; ticket distinti | A2 terminal N=1; A/B success/error N=0, current running invariato; C esatto per sorgenti realmente entrate, eventuale P obsoleto ammesso fisico ma nessun commit |
| G5 | A→B→A same-stack prima action; e A→empty prima entry | solo snapshot finale autoritativo, empty è terminale locale | envelope queued obsoleti C=0; solo final nonempty può fare E/P=1/1; empty C=0 e nessun late notify |
| G6 | Entrambi selezionati; E error/P data, E data/P error, entrambi error, entrambi success empty; E success empty/P error | loading N=0 durante fasi, liste vuote | unico N=1 terminale: partial markers + retry, entrambi error conserva oggetti/priorità E, empty-success solo senza errori; E/P=1/1; global=0 |
| G7 | E oppure P throws StateError; stale throw dopo nuova generazione; assertion separata | pending senza partial commit | runtime terminal failure corrente N=1/global=1; stale N=0/global=1; E throw P=0, P throw E/P=1/1; assertion fail-loud e cleanup, niente domain finto |
| G8 | Failed snapshot corrente; salvare callback retry, cambiare filtro; chiamare vecchio callback; poi retry corrente | vecchio callback N=0/C=0; corrente loading N=1 | ogni sorgente corrente una nuova chiamata, terminal N=1; retry busy scartato C=0; mai riusare set catturato dal vecchio bottone |
| G9 | Listener su N admission/terminal ammette B, filtro vuoto o dispose | tutti i campi coerenti prima listener; B/empty/disposed immediato | nessuna seconda notifica/fase da A dopo reentry; una sola pubblicazione B; dispose prima E C=0, dispose durante E P=0, post-dispose N=0 |
| U1 | SearchAnchor: submit unica valida; bloccare action entry; admission→closeView→goNamed/dispose→entry→settlement; ripetere con submit queued dietro W1 | navigazione immediata, popup chiusa una volta; epoch/barrier già installati, nessun accesso State dopo unmount | esattamente una write della submit accepted (più predecessore se presente), N post-dispose=0, runtime global=1; success/error senza doppia write; vecchio callback popup closed crea zero intenti |
| U2 | Delete chip; sostituire Search owner/controller o digitare nuovo testo prima reset; invocare cached callback dopo replace/unmount | vecchi callback non mutano nuovo input/owner | zero nuove write da callback stale, zero doppio close/pop, reset soltanto stessa sessione/input; timer con clock virtuale |
| U3 | GeoMap reale, load pending→success empty/data/partial/error e retry | overlay loading presente, nessun vecchio marker | marker/count/order e messaggi distinti, N come G1/G6; errore non è empty o spinner infinito, retry una volta, nessuna animazione camera ripetuta |
| U4 | Dialog categorie/tipi × empty/nonempty/invariato; Salva, Back, barrier/drag consentiti; rebuild, unmount, owner replacement e sessione obsoleta | nessuna I/O prima route completion; draft conservato stesso owner, no falsa UX Cancel | callback una volta se mounted/current, empty→all; setter equal C/N=0, diverso una admission; stale/unmounted callback=0; dettaglio trigger nella tabella F5 e quattro gate owner-key preservati |
| U5 | Owner Map A pending→B; conservare marker/retry A; settle A dopo B | B bootstrap proprio, nessun marker A; vecchi callback revocati | solo B commit; A runtime report=1 senza B notify; niente refetch su rebuild identico owner/filter |
| U6 | Submit/suggestion valida; listener della notifica ottimistica unmount/replace host prima che dispatch ritorni; variante close callback supersede host prima della navigation callback | accepted installata, Cwrite=0 prima action; nessun close/navigation follow-up su host invalido; own-close normale conserva invece token e naviga una volta | accepted write=1 anche dopo detach, N dopo dispose=0; callback navigazione vecchia=0, nessun accesso State/context; own-close normale callback=1, nessuna nuova acceptance da popup consumed |
| R1 | Route Map Explore→Search→Post→close/Back; query/lookup/Weather/Nearby pendenti; return/restoration e Gallery | invarianti mode/admission fence e owner/URI prima delle completion | eseguire suite route/ownership/restoration/back e Map semantic; late history/marker non cambia mode/selection/fence/Weather/Nearby; C delle lane escluse invariati |

### F2 — Esiti discriminanti delle intenzioni ordinate

N conta solo cambiamenti di lista del VM vivo; status Command privato e receipt non sono notify VM. Setup base stabile e nessun read in volo, nessun errore salvo dove indicato; expected Result.error implica il consueto ramo repository failure da simulare senza modifica dello store. Scritture seriali: il fake deve fallire il test se W2 entra prima del settlement privato W1. Nessuna permutazione di completion W2→W1 è ammessa dal protocollo; i get possono invece completare in qualunque ordine relativo alle write e sono protetti da E.

| Sequenza | P dopo ciascuna acceptance | Write fisiche in ordine | Esito locale e persistito / rollback | N totale |
| --- | --- | --- | --- | --- |
| []: add(A)→add(A) | [A], [A] (seconda represented) | add(A), una sola | [A], nessun rollback | 1 |
| []: add(A)→remove(A) | [A], [] | add(A), remove(A) | [], nessun rollback | 2 |
| [A,B]: remove(A)→add(A) | [B], [B,A] | remove(A), add(A) | [B,A], nuovo inserimento in coda come ObjectBox | 2 |
| []: add(A)→add(B) | [A], [A,B] | add(A), add(B) | [A,B] | 2 |
| [A,B,C]: remove(A)→remove(B) | [B,C], [C] | remove(A), remove(B) | [C] | 2 |
| []: add(A) fallisce→add(B) già accepted | [A], [A,B] | add(A) Error, add(B) Success | al fallimento P=[B] (un notify rollback), finale locale/store [B] | 3 |
| []: add(A) fallisce→remove(A) già accepted | [A], [] | add(A) Error, remove(A) Success no-op repository | P resta [], rollback nessun notify perché W2 già nasconde A; finale [] | 2 |
| [A,B]: remove(A) fallisce→add(A) già accepted | [B], [B,A] | remove(A) Error, add(A) Success no-op repository | rebase su B=[A,B] restituisce [A,B], un notify; originale ordine conservato, finale store [A,B] | 3 |

La stessa acceptance reentrante usa la sequence successiva e non modifica gli esiti già associati alle entry. Base conosciuta senza pending: remove assente è represented; base sconosciuta o incerta non autorizza questo no-op. Se la prima è runtime, usare S7/S13 invece del rollback Expected della tabella: storage può già essere cambiato e soltanto G1 stabilisce la verità.

### F5 — Conclusione reale dei dialog, nessuna UX di annullamento

Evidenze: `CategoryContentAndTypeSelection` cattura draft/callback prima di await (`:110–164` circa; usare i simboli `_onTypeChipPressed` e `_onCategoryChipPressed` al checkout); dopo route controlla mounted e identità del draft, senza leggere un risultato Save/Cancel. `showDialog` non imposta barrierDismissible=false; `appShowModalBottomSheet` ha isDismissible=true/enableDrag=true. `ObjectKey(owner)` in GeoMapScreen sostituisce lo State a owner replacement. I quattro test reali in `test/ui/geo_map/widgets/geo_map_screen_test.dart:53–200` incrociano categorie/tipi e empty/nonempty, con vecchio modal ancora aperto e owner nuovo con filtri uguali: nessun callback verso A o B.

| Trigger / sessione | Contratto conservato e gate U4 |
| --- | --- |
| Salva, draft modificato, State/sessione correnti | pop route; applica una volta il draft e invoca callback una volta; setter ammette un load solo se set realmente diverso |
| Back/pop, draft modificato | identico a Salva quando conclude normalmente la route; non è annullamento |
| Barrier dismiss, dove consentito; drag dismiss dello sheet | identico a Salva quando conclude route; verificare entrambi i layout adattivi con clock virtuale |
| Draft vuoto, uno dei trigger sopra | resta vuoto durante editing/rebuild; alla conclusione valida normalizza il solo campo a tutte le opzioni e callback una volta |
| Draft invariato, route conclusa | callback una volta dal selector, setter equal produce zero admission/I/O/notify; non confondere callback e caricamento |
| Widget unmount | nessuna normalizzazione/setState/callback dopo await, anche se la route termina più tardi |
| Owner A→B con filtri uguali | ObjectKey(owner) unmount A, vecchia sessione può rimanere visibile ma non pubblica su nessun owner; mantenere quattro test esistenti |
| Sessione per campo obsoleta dopo confirmed change | identity check fallisce: niente normalizzazione/callback; cambio del solo altro campo non invalida la sessione corrente |

Aggiungere gate espliciti Back/barrier/drag perché i quattro test owner replacement chiudono via Salva e da soli non provano quei trigger. Nessuna nuova distinzione Cancel, nessuna modifica di widget o del delta Category precedente.

I conteggi marker sopra escludono notifiche semantiche mode/Nearby/selection: nei test isolare quelle lane con fixture stabili, non indebolire N con “almeno una”. Per G4 registrare dispatch-to-entry order per ogni generazione e asserire i contatori di ogni fase; una supersession non promette cancellation fisica. Test di disposal includono idle, running, terminal e throw oltre 50ms virtuali per discriminare teardown prematuro.

Suite esistenti da aggiornare/eseguire nel futuro apply: `test/ui/search/view_models/search_view_model_test.dart`, `test/ui/search/widgets/components/{app_search_anchor,search_anchor_suggestion_list}_test.dart`, `test/ui/search/widgets/search_result_sliver_list_test.dart`, `test/ui/geo_map/view_models/geo_map_view_model_test.dart`, `test/ui/geo_map/widgets/{geo_map_screen,geo_map}_test.dart`, `test/ui/category/widgets/category_content_and_type_selection_test.dart`, `test/data/repositories/search_repository_impl_test.dart` come regression read-only se runtime disponibile, `test/routing/{geo_map_route,route_ownership,back_navigation_integration,main_navigation_restoration,restoration_behavior,route_parameter_redirect}_test.dart`, test foundation/lifecycle e suite completa finale. Non affermare risultati prima di esecuzione.

## Risks / Trade-offs

- [FIFO transient e Future write non terminante] → conserva intenti accepted senza inversioni/drop; può trattenere la sessione privata e le entry successive, nessun timeout o cap che perda intenti. Costo limitato alle entry ancora pendenti della sessione; liberarle al settlement. Nessuna coda persistita/recovery dopo process kill.
- [Bootstrap può rileggere sotto write ripetute] → coalescing per revisione stabile, attesa Future controllato, nessun polling; progresso richiede una finestra senza mutazioni e I/O terminante.
- [Raw write throw con storage incerto] → F4 richiede un get automatico post-drain nella stessa logica F3, senza retry write. Se get fallisce o UI è detached può restare una proiezione incerta; domanda tentata consumata evita loop. Originale e stack riportati una volta, nessun vincolo ObjectBox nuovo.
- [Writer detached e replacement concorrenti sullo stesso repository] → nessun ordine/convergenza cross-owner promesso; un nuovo bootstrap può precedere le write del predecessore, limite esplicito senza lock globale.
- [Marker bootstrap più lento, non progressivo] → una sola completion coerente, partial soltanto a settlement; niente duplicazione dei vecchi load per velocizzare.
- [Risultato marker con errore racchiuso in protocol success] → projection e test G6 obbligatori; mai usare completed isolato per classificare successo completo.
- [Canonical non ancora cumulativa] → ordine di riconciliazione documentato sopra, nessun sync in questa change. Non è autorizzazione ad aggirare conflitti nuovi.
- [I/O vecchio non cooperativo] → authority revocata subito, private resources possono restare fino a settlement; nessuna promessa di abort o zero I/O fisico dopo sola supersession.

## Migration Plan

Planning soltanto. Dopo review indipendente del piano e nuova autorizzazione, eseguire tasks in ordine e fermarsi a ogni gate fallito. Adattare API interne e consumer nello stesso gruppo coerente; non rimuovere command.dart globale. Nessun deploy/schema change. Un eventuale rollback di implementazione ripristina unitariamente VM/consumer/test della quarta change sul branch dedicato, senza toccare i tre checkpoint precedenti; non eseguire reset/revert automaticamente su lavoro altrui.

## Stato e decisioni aperte

D1/D2/D6 revisionate chiudono contratti F1–F4, F5 chiarisce D3/D5/U4. Nessuna scelta materiale lasciata all'executor. FIFO locale con Command single-flight e writer vivo distinto da UI disposed è una decisione di piano da sottoporre a re-review, non codice implementato. GeoMap D4/marker G1–G9/U3/U5 rimangono invariati; nessuna nuova UX di annullamento dialog. Posizionamento/accessibilità overlay restano dettagli dentro D5.

## Evidenze storiche del planning iniziale — 2026-10-23 (prima di F1–F5)

Eseguiti realmente: lettura metadata PR e checkpoint, snapshot Git di tutti i worktree, pub get offline, analyzer machine, context/list/instructions/status OpenSpec, `openspec validate migrate-search-map-commands --strict` (exit 0, valid), `git diff --check` (exit 0) e controllo whitespace/newline anche di tutti i sei artifact untracked. Status OpenSpec: 4/4 artifact groups complete; tasks **0/25** applicati, non 25 implementati.

Manifest esclusivo: `.openspec.yaml`, `proposal.md`, `design.md`, `tasks.md`, `specs/command-execution-concurrency/spec.md`, `specs/local-content-retrieval/spec.md`, tutti sotto la nuova change e senza symlink. Nessun tracked diff, index vuoto, HEAD invariato al checkpoint. I cinque checkout preesistenti mantengono HEAD/branch/status e diff digest iniziali. Nessun codice/test/dipendenza/config tracked modificato, nessun commit/push/update PR/merge/sync/archive. La cache ignorata inizializzata per analyzer non è artifact da pubblicare.

Autocontrollo: inventario sette target↔21 diagnostiche; ogni decisione ha scenario S/G/U/R e task con gate; nuovi delta soltanto ADDED per due capability esistenti, nessuna sovrascrittura dei contratti cumulativi. La matrice contiene **25 gruppi di scenari** deterministici, inclusi rami parametrizzati. Test Flutter e review adversariale indipendente **non eseguiti** in questo planning: sono i gate successivi, non evidenze già acquisite. Stato dichiarato allora: **READY FOR INDEPENDENT PLAN REVIEW**, superato dai finding F1–F5 e dalla presente remediation.

## Remediation adversariale F1–F5 — stato corrente del piano

### Preflight della remediation

Riconfermati worktree/branch/HEAD/index e tutti i sei worktree registrati. PR #12 open, Draft, head invariato `1f3753b10c18061c6655cb32d078bf93aff1b05e`; log e artifact dei tre checkpoint coerenti, nessuna nuova implementazione inferita dalla sola metadata PR. Alla partenza della remediation erano presenti i sei artifact untracked **e** `openspec/changes/migrate-search-map-commands.zip`, aggiunto esternamente dopo il planning iniziale: ZIP fuori perimetro, preservato byte-per-byte. Nessun tracked diff o file staged. Snapshot pre-remediation di HEAD/branch/status/diff e digest di ogni untracked conservato per confronto; hash degli artifact controllati prima della prima sovrascrittura, nessun edit concorrente rilevato. Nessuna operazione Git distruttiva o registrazione di nuovi worktree eseguita in questa remediation.

Rilette le sei fonti di questa change e le superfici source/test indicate nel Context, incluso sorgente locale command_it 9.5.2 (`run`: sync running, action deferred; `runAsync`: join; reporting; `dispose`: teardown 50ms). Confermati legacy action inline e submit add→close→callback, firma add case-insensitive/remove exact-case ObjectBox, supporti fake/Completer e quattro gate GeoMap owner-key. Gli esiti analyzer 87/0/0 e precedente strict nel blocco storico restano evidenze **del planning iniziale**: nessun analyzer, pub get o Flutter test ripetuto per questa remediation documentale.

### Tracciabilità della chiusura documentale

| Finding / problema confermato | Decisione correttiva e motivazione | Alternative scartate | Artifact/sezioni e gate discriminante |
| --- | --- | --- | --- |
| F1 — disposal prima dell'action perde submit | Acceptance trasferisce obbligo a writer privato ancora vivo; detach revoca solo UI. Una action repository per accepted, navigazione senza await; guard dopo dispatch/close protegge reentry | repository dalla View, attendere write/boostrap, dispose writer con VM | proposal, design D1/D5/D6/S9/U1/U6, concurrency delta lifecycle e accepted persistence, tasks 2.4/2.5/2.7; admission→close→dispose→entry deve chiamare repository una volta |
| F2 — single-flight drop perde operazioni distinte | FIFO locale sopra un Command riutilizzato; base+pending e rollback per-op/rebase; conoscenza reale decide deduplica | due write lane concorrenti, restartable writer, drop, lock globale, child Command per entry | proposal, D1/S4/S17/S18/tabella F2, concurrency delta order/dedup/rollback, tasks 2.1/2.2; otto sequenze con local/store/N/order esatti |
| F3 — epoch tardiva autorizza G0 obsoleta | Acceptance installa E/entry/receipt/drain prima di run/notify; get attende drain OR detach; requested/attempted separati e writer senza dipendenza dai read | revision solo action entry, Future installato dopo await, read-lock che blocca write, reinterpretare busy load come get pendente | D2/S5/S6/S8/S10/S11/S12/S16, concurrency delta read authority/demands, task 2.3; G0 completa dopo acceptance e prima action W, senza commit vecchio o deadlock |
| F4 — runtime conserva ottimismo indefinitamente senza read | Marca incertezza e domanda post-drain nel solo scheduler F3, anche senza G0; un tentativo stabile consuma domanda, nessun write retry | rollback inventato, secondo reconciliation service, retry finché incertezza scompare, report manuale doppio | D1/D2/D6/S7/S13–S15/S18/Risks, concurrency delta runtime/demands, task 2.6; fake throw prima/dopo commit, W2 pending, read fallita o dispose |
| F5 — “annulla/save” non descrive widget | Route completion consentita applica draft se mounted/current: Salva, Back, barrier/drag; empty→all, stale/unmount nessun callback | nuova UX Cancel, callback soltanto Salva, rimozione ObjectKey(owner) | D3/D5/U4/tabella F5, concurrency delta frase current-session close, task 4.2; categorie/tipi × trigger, empty/changed/unchanged, quattro owner replacement originali |

Il delta `local-content-retrieval` e `.openspec.yaml` restano byte-per-byte invariati: F1–F4 sono ammissione/ownership della cronologia, F5 precisa senza cambiare il contratto dei dialog. Search loadResults/loadSuggestions, Nearby e i marker D4/G1–G9/U3/U5 non sono rimigrati; nessuna modifica al loro retrieval o reporting. Le precisazioni F5 in D3/D5 non introducono nuova normalizzazione programmatica o UX.

### Verifica corrente e limiti

Stato corrente: **0/27 task implementati**, tutti unchecked; matrice principale **34 gruppi** S1–S18, G1–G9, U1–U6, R1. Le otto righe F2 e i trigger F5 espandono gruppi parametrizzati, non sono una dichiarazione sul numero di test eseguiti. Eseguiti strict OpenSpec (valid, exit 0), status/instructions, controllo nomi/scenari/numerazione e coerenza dei riferimenti, whitespace/newline inclusi untracked, manifest completo e confronto Git/digest con il preflight. Queste sono verifiche documentali, non prove di implementazione o pass di test futuri.

Manifest della change invariato nei nomi: `.openspec.yaml`, `proposal.md`, `design.md`, `tasks.md`, `specs/command-execution-concurrency/spec.md`, `specs/local-content-retrieval/spec.md`. Soltanto quattro file hanno contenuto aggiornato: proposal/design/tasks e delta concurrency. Metadata e delta retrieval invariati; ZIP preesistente invariato; nessun file fuori change modificato. Index vuoto, nessun tracked diff, HEAD/branch/worktree inventory invariati. Gli altri cinque checkout conservano HEAD/branch/status/diff e untracked byte-per-byte rispetto al preflight della remediation.

Trade-off intenzionali: ordine garantito solo nella sessione writer; nessun coordinamento con replacement o altri owner sullo stesso repository. Future non terminante può trattenere writer/FIFO, nessuna garanzia di sopravvivenza a process kill; assertion conserva fail-loud con release dei waiter, non normale recovery della FIFO. Una riconciliazione fallita mantiene incertezza e richiede nuova domanda esplicita/qualificante, senza loop. Nessun indebolimento della revoca di autorità UI o delle lane restartable precedenti. Nessun blocker documentale noto residuo; chiusura F1–F5 proposta alla re-review indipendente, nessuna autorizzazione apply implicita.

**READY FOR INDEPENDENT PLAN RE-REVIEW**


## Apply autorizzato — R1 e preflight

Il nuovo prompt autorizza esclusivamente l'apply locale del quarto OpenSpec, dopo re-review READY FOR APPLY, senza commit/push/update PR/sync/archive. Preflight: branch e HEAD autorizzati invariati, origin xmattjus/moliseis, PR #12 open/Draft al medesimo checkpoint, sei artifact revisionati presenti, index/tracked diff vuoti. Lo ZIP storico non è presente al preflight apply: nessuna ricreazione o rimozione. Gli altri cinque checkout sono fuori perimetro e snapshot iniziale registrato. B0 machine rieseguito: 87 INFO, zero WARNING/ERROR, exit 0; output /tmp/search-map-apply-B0.txt.

### R1 — unico ingresso pubblico reader (prima del task 2.3)

SearchViewModel espone `void requestPastSearchesRefresh()`: owner live incrementa requested sincronicamente e avvisa il solo scheduler D2, owner disposed no-op. Constructor registra il bootstrap una volta attraverso tale metodo, dopo inizializzazione. Il reader ResultCommand è privato; eventuale snapshot pubblico è ValueListenable read-only senza run. Nessun caller o test può bypassare requested/attempted. Domande prima dell'avvio fisico coalescono; una domanda registrata dopo l'avvio G0 conserva autorità distinta e rende G0 non pubblicabile per la nuova domanda. Il commit richiede E e domanda corrente ancora uguali alla cattura e FIFO vuota; il nuovo tentativo parte soltanto dopo settlement/dispatch G0, senza letture sovrapposte. La domanda è consumata all'avvio fisico, non al settlement. Failure non riaccoda la domanda consumata; retry esplicito registra una nuova domanda. Un solo reader fisico, drain OR disposal senza cicli.

Gate R1.1–R1.7: bootstrap unico; retry domain/runtime senza loop e con report runtime una volta; domanda durante writer drain; domanda dopo avvio G0 senza commit obsoleto; disposal prima API/con pending/durante get; ricerca statica senza bypass del reader. Tutti test con Completer e clock virtuale, non risultati già acquisiti.

### Apply — gate 1 e 2 Search verificati

Caratterizzazione RED eseguita prima dell’edit VM: `search_history_characterization_test.dart` ha mostrato bootstrap che sovrascrive query accepted (visible old invece di accepted); log /tmp/search-map-characterization-red.log. Lo stesso test adattato alla nuova API è verde. Search implementata con writer privato nel file VM, API reader incapsulata R1 e popup session guards; i due host Explore/SearchResult non effettuano più un closeView ridondante dopo il close dell’anchor. Nessuna modifica a VM Explore o routing ownership. Supporto FakeSearchRepository esteso con hook history e registro write, default invariati; SearchHistoryHarness riusa questo fake e modella solo il confine repository con Future controllabili.

Gate finale Search: `flutter test --no-pub test/ui/search/view_models test/ui/search/widgets test/utils/result_command_test.dart test/utils/restartable_command_test.dart test/utils/command_configuration_test.dart test/utils/command_it_disposal_behavior_test.dart test/ui/ordinary_view_model_lifecycle_test.dart --reporter expanded` exit 0, **343 passed / 3 pre-existing skips / 0 failures**, /tmp/search-map-search-gate-final.log. Include S1–S18, otto righe F2, R1 retry/bootstrap/coalescing/disposal, 33 test anchor e dieci lifecycle aggiunti. Focus analyzer Search/propri test/supporto nuovo: zero diagnostiche. Ricerca statica: reader eseguibile solo dentro `_scheduleRead`, nessun loadPastSearches.run esterno; i retry dei test usano requestPastSearchesRefresh. Runtime stack con detailedStackTraces conserva frame originali più chain upstream; test lifecycle salva/ripristina false per confronto identity, test integrazione verifica anche chain decorata. Nessuna modifica della foundation. Gate Search chiuso prima delle modifiche GeoMap.

### Apply — correzioni audit interno Search e gate 3 GeoMap

Audit interno read-only ha rilevato due regressioni del draft Anchor, entrambe corrette prima del gate GeoMap: cancellazione del debounce senza reset del testo ricordato alla chiusura (riapertura stesso testo rimaneva senza lookup), e hint popup non propagato. Test deterministico riapertura durante debounce e assertion della SearchBar aperta aggiunti; suite Anchor finale **34/34 pass**, analyzer dei due file zero diagnostiche. Nessun finding residuo sul writer/reader Search dall’audit interno; non sostituisce la futura code review indipendente.

Gate VM GeoMap isolato eseguito: `flutter test --no-pub test/ui/geo_map/view_models test/utils/restartable_command_test.dart --reporter expanded` exit 0, **98 passed, zero failures**, /tmp/search-map-geo-vm-gate-final.log. Copertura 25 nuovi test marker più suite semantic e foundation: bootstrap atomico, source membership/filter/snapshot, empty, A→B→A fisico e queued, otto esiti source/empty, current/stale runtime, assertion, retry, disposal e reentry. I primi test avevano fixture `unknown` escluse correttamente dal filtro iniziale: corrette a categorie note. Un test semantic esistente richiedeva teardown virtuale condiviso per il nuovo child marker, senza cambiare le sue assertion; ripetizione verde.

Deviazione procedurale registrata: dopo chiusura Search l’assegnazione parallela ha fatto scrivere un draft dello screen prima della conclusione del gate VM3.5. Non è stato validato/considerato integrato in quel momento; il gate VM è stato eseguito isolatamente e chiuso prima della prosecuzione e validazione UI. Nessuna deviazione funzionale o ampliamento scope.

### Apply — gate UI e regressioni 4 verificati

Marker overlay spostato sopra il foglio e la search bar dopo finding interno sullo stacking: retry realmente hit-testable con foglio completo in Explore/Search/Post. Preservati mode/controller/URI; nessuna modifica a GeoMapBottomSheet, Weather o lane selection/Nearby. GeoMapScreen+test analyzer zero; suite screen finale **63/63 passed**, incluse quattro regressioni owner-key originali e Save/Back/barrier/drag per categorie/tipi, callback stale dopo filtro/owner/unmount, stati marker e retry. I nuovi test widget inizialmente controllavano il metodo fake di Category invece di getByCurrentYear/getAll: corretti al confine reale GeoMapUseCase, senza cambiare codice query.

Gate integrato `flutter test --no-pub test/ui/geo_map test/routing test/ui/category/widgets/category_content_and_type_selection_test.dart test/ui/weather test/data/repositories/search_repository_impl_test.dart --reporter expanded`: exit 0, **534 passed / 1 pre-existing skip / 0 failures**, /tmp/search-map-ui-routing-gate-final.log. Test marker aggiuntivi reentry terminale e conservazione Post/ordine inclusi nella suite `geo_map_markers_test.dart`, **27/27 passed**. Un test route /map richiedeva testOwnerUI per drenare i timer zero del reader/writer al vero unmount finale; corretta solo la harness invocation, tutte le assertion route preservate. Retest route **51 passed / 1 existing skip**.

Runtime test ObjectBox mancante nel worktree: riutilizzata la dylib già disponibile nel principale, copiata solo nel percorso ignorato lib/libobjectbox.dylib dopo verifica hash **1af2e266e523dbcc33b3682eebf297f2f4f23ade6ab706dab794f7a6f8108751**. Sorgente intatto, nessuna dipendenza/versione/schema modificati. Formatting sul manifest di **18 file Dart**: zero residui.

### Apply — analyzer B0/B1 finale e manifest

`dart analyze --format machine` rieseguito prima delle modifiche e sul manifest finale: B0 **87 INFO/0 WARNING/0 ERROR**, B1 **66 INFO/0 WARNING/0 ERROR**, entrambi exit **0**, stderr vuoto. Eliminate esattamente le **21** identità target inventariate (9 Search,12 GeoMap); nessuna nuova diagnostica o molteplicità non-target. Confronto automatico per path/codice/colonna/lunghezza/messaggio e contesto sorgente verificato; due riferimenti legacy preesistenti nei dartdoc di test/support/fake_repositories.dart si spostano **653→656** e **1159→1165** per gli hook aggiunti sopra. Non sono nuovi usi e non sono stati soppressi o rimigrati. Evidence /tmp/search-map-apply-B0.txt, /tmp/search-map-apply-B1.txt, /tmp/search-map-analyzer-comparison.json. Non eseguito né dichiarato verde flutter analyze: le 66 INFO restano visibili per OpenSpec successivi.

Manifest completo locale: **24 file** (6 produzione, 12 test/supporto, 6 artifact), index vuoto. Fonte di verità del manifest verificata tramite diff tracked + ls-files untracked, hash dei **18 file Dart** salvati all’avvio suite completa in /tmp/search-map-validated-source-hashes.json. Nessun nuovo ignore, nessun file generato modificato, nessuna modifica a dipendenze/lock/config/CI/backend/schema/repository/foundation/altre change/canonical. I cinque checkout esterni conservano listing HEAD/branch e digest/status/untracked iniziali.

### Apply — suite completa e closeout locale

`flutter test --no-pub --reporter expanded` sul manifest finale: **2705 passed / 6 pre-existing skips / 0 failures**, exit **0**, /tmp/search-map-full-suite.log. Nessun file Dart modificato durante/dopo la suite: hash dei 18 file del manifest controllati contro lo snapshot iniziale della verifica. Il run include tutti i support consumer, le nuove regressioni e i test reali ObjectBox. I risultati di singole suite sopra restano conteggi dei loro run effettivi, non vengono sommati come test distinti. Il gate finale supera le failure intermedie descritte senza nasconderle.

I tre finding dell’audit interno sono chiusi con codice e regressioni: debounce riapribile a testo invariato; hint popup conservato; overlay marker sopra foglio/search bar con retry hit-testable in ogni mode. Non è la code review indipendente richiesta dopo l’apply. Nessun finding funzionale noto residuo, nessuna autorizzazione merge/pubblicazione inferita.

Riconfermata PR #12 open/Draft/nonmerged con head ancora 1f3753b10c18061c6655cb32d078bf93aff1b05e. Nessun commit/push/update PR/merge/sync/archive. HEAD/branch/index invariati (index vuoto), gli altri cinque checkout byte-per-byte rispetto al preflight per file modificati/untracked e metadata Git. Runtime dylib ignorato è escluso dal manifest pubblicabile. Metadata .openspec.yaml, proposal e delta local-content-retrieval conservati dal piano; modificati design/tasks ed esclusivamente delta concurrency per R1.

Limiti intenzionali del piano preservati: FIFO per sessione senza ordine cross-owner; Future non terminante può trattenere risorse/obblighi pending; nessuna persistenza della coda su process kill; runtime write incerto riconciliato con un tentativo stabile, errore read non produce loop; assertion fail-loud distinta da normale recovery. Le 66 INFO sono ancora previste. Unica deviazione procedurale: draft UI anticipato rispetto al gate VM per assegnazione parallela, dichiarato sopra; nessuna deviazione funzionale, source/repository boundary o perimetro più ampio.

Manifest completo verificato (24 file, 6 produzione + 12 test/supporto + 6 artifact):

```text
lib/ui/explore/widgets/explore_screen.dart
lib/ui/geo_map/view_models/geo_map_view_model.dart
lib/ui/geo_map/widgets/geo_map_screen.dart
lib/ui/search/view_models/search_view_model.dart
lib/ui/search/widgets/components/app_search_anchor.dart
lib/ui/search/widgets/search_result_screen.dart
openspec/changes/migrate-search-map-commands/.openspec.yaml
openspec/changes/migrate-search-map-commands/design.md
openspec/changes/migrate-search-map-commands/proposal.md
openspec/changes/migrate-search-map-commands/specs/command-execution-concurrency/spec.md
openspec/changes/migrate-search-map-commands/specs/local-content-retrieval/spec.md
openspec/changes/migrate-search-map-commands/tasks.md
test/routing/geo_map_route_test.dart
test/support/fake_repositories.dart
test/support/geo_map_marker_harness.dart
test/support/search_history_harness.dart
test/ui/geo_map/view_models/geo_map_markers_test.dart
test/ui/geo_map/view_models/geo_map_view_model_test.dart
test/ui/geo_map/widgets/geo_map_screen_test.dart
test/ui/search/view_models/search_history_characterization_test.dart
test/ui/search/view_models/search_history_lifecycle_test.dart
test/ui/search/view_models/search_history_test.dart
test/ui/search/view_models/search_view_model_test.dart
test/ui/search/widgets/components/app_search_anchor_test.dart
```

Controlli finali: format 18 Dart zero cambi residui, diff/nuovi file senza whitespace o newline mancanti, nessun nuovo ignore, manifest e hash coerenti, strict OpenSpec valido. Checklist finale 27/27 soltanto dopo le verifiche descritte; successiva azione autorizzabile: code review indipendente, non commit o apply aggiuntivo.

**READY FOR INDEPENDENT CODE REVIEW**
