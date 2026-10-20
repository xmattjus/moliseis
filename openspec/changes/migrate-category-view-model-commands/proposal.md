# Proposal

## Why

Category mantiene quattro Command legacy deprecati; la sostituzione meccanica con factory asincrone rende insicuro il bootstrap e conserva richieste filtro perse o risultati mescolati. OpenSpec 2/7 deve rimuovere queste dipendenze usando la foundation già presente e definire prima dell’apply ownership, pubblicazione e lifecycle verificabili.

## What Changes

- Inizializzare la selezione validata della route nel costruttore, prima di esporre il ViewModel; normalizzare gli input diretti vuoti alla selezione completa come già fa la UI; preservare slug, `all`, error routing, Provider e ownership delle route.
- Eliminare i due Command di selezione in favore di metodi sincroni del ViewModel: aggiornano l’intent, senza chiamate Command annidate né attese fittizie.
- Usare un solo caricamento restartable per categoria/tipi, con input immutabili, retrieval separato dal commit autoritativo e ordinamento corrente al commit.
- Pubblicare atomicamente solo successi completi. Una nuova selezione svuota subito il contenuto precedente; refresh della stessa selezione conserva internamente l’ultimo successo, ma loading/errore governano la UI. Nessuna collezione parziale viene pubblicata.
- Conservare `setSort` single-flight tramite factory Result-aware, ordinamento ottimistico e persistenza esistente. Propagare il vero Result della write invece del falso successo legacy; nessun rollback della scelta di sessione e nessuna nuova garanzia di persistenza.
- Rendere espliciti neutral/loading/success/empty/error e retry; revocare pubblicazione e notifiche al dispose con cleanup privato dopo settlement sicuro.
- Correggere il selettore condiviso: confronto semantico delle selezioni confermate, retention del draft su rebuild innocui e label esplicite per draft vuoti. Ripristinare tutte le opzioni solo alla chiusura del modal, con una sola callback se ancora mounted e la sessione draft è corrente. Un cambiamento confermato di valore osservato dal widget ritira la sessione aperta precedente senza ripubblicarla; mantenere indipendenti snapshot confermati, editing e owner.

## Capabilities

### New Capabilities

Nessuna.

### Modified Capabilities

- `command-execution-concurrency`: aggiungere contratti Category per bootstrap, filtri latest-intent, commit atomico, ordinamento, stati UI e lifecycle. La delta aggiunge requisiti disgiunti: non ricopia né sovrascrive il requisito MODIFIED dal primo OpenSpec. Riconciliazione delle delta solo nel consolidamento finale della PR cumulativa.

## Impact

Superfici di produzione implementate nell’apply: `category_view_model.dart`, `category_screen.dart`, inizializzazione Category in `core_routes.dart` e `category_content_and_type_selection.dart`; remediation finale: la sola chiave del selettore in `geo_map_screen.dart`. Confronto semantico e label sicure sono necessari anche per il draft locale. Test dell’apply: suite Category, routing/ownership/restoration e una regressione mirata del consumer reale GeoMap del selettore condiviso, riusando `test/support/`. Nessun cambiamento a UseCase, repository, backend, dipendenze o foundation globale.

Baseline verificata: `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, uguale a `origin/codex/migrate-legacy-commands` dopo fetch e all’HEAD della Draft PR #12. Nuovo worktree dedicato e branch `codex/plan-migrate-category-view-model-commands`; dettagli e ledger in design.md. Analyzer storico di planning: **113 INFO, 8 Category**, senza riduzione in quella fase. Il confronto dell’apply ha verificato **105 INFO residue identiche**, otto target rimosse e zero nuove identità; provenienza e comandi in design.md.

Sono esclusi Event, Post, Search, i Command e l’orchestrazione GeoMap, Sync, Submission, Admin, gli altri Command e la rimozione globale di `command.dart`. Il selettore condiviso già usato da GeoMap riceve F1/F2 e la relativa verifica di compatibilità; la remediation finale della code review aggiunge esclusivamente ObjectKey(owner) al suo punto di montaggio in GeoMapScreen e regressioni di owner replacement. Non si migra quella feature o i suoi Command. Provider/ChangeNotifier, Result e confini UI/domain/data restano quelli del progetto. Nessuna factory generica, adapter legacy o nuova infrastruttura di concorrenza.

Fase corrente: **apply autorizzato il 2026-10-20**, successivo alla review e remediation documentale F1/F2/RF3. Implementazione e regression test nel worktree dedicato; task marcati solo sulla base delle verifiche effettive. Le precedenti fasi erano esclusivamente planning/remediation: le loro evidenze storiche restano in design.md. Nessun commit, push, mutazione PR, merge, archive o sync canonical; la PR #12 resta invariata. Esiti dei gate e readiness di codice nella sezione finale del design.
