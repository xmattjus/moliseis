## Why

All’inizio del planning sei operazioni ordinarie dipendevano ancora dai Command legacy deprecati, mentre il repository disponeva già di factory Result-aware command_it. Questa prima migrazione conserva i comportamenti delle feature e rende espliciti ammissione, esiti e lifecycle, senza riprodurre l’API legacy.

## Stato corrente — remediation post-apply

L’apply è stato autorizzato ed eseguito il 2026-10-20 nel worktree dedicato:
cinque ViewModel, sei Command, quattro consumer e relativi test/support sono
implementati, senza commit o PR. Le evidenze dell’apply sono in design.md,
sezione “Apply evidence — 2026-10-20”. La successiva code review indipendente
ha individuato CR-F1 (consenso Sentry dopo dispose), CR-F2 (stato documentale)
e CR-F3 (wrapper test troppo estesi). La remediation corrente riconcilia il
consenso dalla cache repository e riduce i wrapper sulla base di prove mirate;
la validazione post-remediation e il relativo verdetto sono registrati nella
sezione finale di design.md e nei task 7.1–7.3. Non è un’approvazione al merge.

Le sezioni di planning sotto mantengono baseline, motivazioni e review del piano.
I loro F1–F6/R1–R3 sono identificatori storici distinti da CR-F1–CR-F3 della
code review post-apply. Nessuna delle altre sei change è stata avviata.

## What Changes

- Migrare soltanto SettingsViewModel.setCrashReporting; ThemeViewModel.setThemeBrightness e setThemeType; ExploreViewModel.loadLatest; SuggestionViewModel.load; FavouriteViewModel.load: **5 ViewModel, 6 Command**.
- Adattare consumer e test strettamente necessari; osservare command.results tramite ResultCommandSnapshot e usare run/runAsync secondo la reale necessità di attesa. Nessuna latest-intent implicita.
- Conservare aggiornamenti ottimistici e rollback Settings/Theme, retention specifica Explore/Suggestion, pubblicazione progressiva e membership Favourite. setFavourite resta Future<Result<void>>, senza nuovo Command.
- Proteggere ogni commit locale, notifica, rollback e nuova fase repository dopo dispose; programmare sempre il cleanup fuori dispatch, anche per Command già idle, e rilasciare quelli attivi solo dopo settlement sicuro e ricontrollo, mantenendo il reporting globale.
- Correggere esplicitamente il feedback Settings: una scrittura fallita non deve più produrre il messaggio di successo. Nessun altro cambiamento UX intenzionale.

## Capabilities

### New Capabilities

Nessuna.

### Modified Capabilities

- `command-execution-concurrency`: delta **MODIFIED** del requisito `Only authoritative completion can commit asynchronous data`, autorizzata dalla remediation, per distinguere lane restartable da operazioni ordinarie single-flight. Aggiungere i soli contratti osservabili pertinenti alle sei operazioni, feedback, ammissione Favourite e lifecycle.

Search/GeoMap conservano retrieval separato dal commit sincrono autoritativo e divieto di pubblicazione obsoleta. Le operazioni ordinarie possono conservare continuazioni ottimistiche/progressive vive e autoritative. Nessuna modifica diretta alle canonical in questa fase. `local-content-retrieval`, routing e navigation-shell restano vincolanti e invariati; nessuna nuova capability artificiale per preferenze/preferiti.

## Impact

Perimetro di produzione approvato e implementato: cinque ViewModel, SettingsScreen, sezione latest di ExploreScreen, SuggestionHorizontalListView e FavouriteScreen; verificare FavouriteButton come consumer Provider di isUpdating/membership, senza cambiarne il contratto diretto. Non cambiare scope o composizione dei Provider. Test: cinque suite ViewModel, widget pertinenti, integrazioni Provider/router che consumano questi owner (incluso sync_redirect_test).

### Baseline e diagnostiche — planning storico del 2026-10-19

Preflight iniziale e remediation del 2026-10-19: repository xmattjus/moliseis; HEAD `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`, branch `codex/resolve-flutter-analyzer-diagnostics-pr3`; fetch conferma origin/main `d16f73714fcbb58d1ee4ed91a45e61be1072667e`, identico alla baseline richiesta. L’HEAD di quel preflight era 0 ahead/7 behind. Fonte di implementazione futura: l’ultimo origin/main verificato, non questo vecchio checkout PR3.

La precedente analisi realmente eseguita sullo snapshot main ha rilevato 125 info legacy, zero warning/errori. R3 in design.md registra comando esatto Dart diretto `analyze --format machine`, cwd, flag/default, SDK, adattamento temporaneo del package_config e exit storico 0; un nuovo replay separato ha misurato exit grezzo 0 e output identico al log originale. Non attribuire tale exit al wrapper flutter analyze né dedurlo dai conteggi. Il perimetro ridotto comprende **12 diagnostiche target**: Theme 4; Settings, Explore, Suggestion e Favourite 2 ciascuno. Dopo apply sono attese **113 residue**, incluse le otto di Category. Confrontare le identità, non soltanto il saldo; riconciliare qualsiasi drift prima degli edit. Pubspec/lock/package_config confermano command_it 9.5.2, listen_it 6.0.0 e Flutter 3.47.5, Dart effettivo 3.13.4; nessun aggiornamento dipendenze.

Working tree della remediation già conteneva AGENTS.md modificato e le directory untracked di questa change e PR4; index vuoto. Preservare integralmente questi lavori e tutti i file estranei. .openspec.yaml resta invariato, spec-driven senza skip_specs.

### Risoluzione F1 e sequenza complessiva

Category e tutte le sue quattro operazioni, consumer, test e attività esclusive sono **fuori perimetro**. Le factory asincrone differiscono l’ingresso nell’action; conservarne le esatte interleaving semantics richiederebbe coordinamento specifico non giustificato qui. Saranno affrontate dalla futura change indipendente **migrate-category-view-model-commands**, che non viene creata ora. Nessun adapter, scheduler, wrapper o nuova factory preparatoria.

La migrazione complessiva comprende ora **sette OpenSpec sequenziali nello stesso branch e una sola PR finale**, secondo la richiesta esplicita dell’utente. Questa prima change non dipende dall’implementazione delle altre sei. Non creare una change di coordinamento. Rimozione command.dart e zero deprecazioni globali restano obiettivi della PR finale.

### Gate, rischi e non-obiettivi — planning storico

Sei Command migrati; cinque ViewModel senza legacy; dodici identità eliminate, 113 preservate salvo drift; nessuna nuova diagnostica; contratti di dominio/persistenza invariati; nessun redesign UX oltre alla correzione del falso feedback Settings; errori applicativi/runtime distinti e terminali; single-flight preservato; zero commit/notify post-dispose; test ViewModel/widget/Provider/router e suite Flutter completa verdi.

Rischi concreti e mitigazioni sono nel design: ingresso differito Settings/Theme senza vincolo same-stack nei consumer attuali; ammissione Favourite sincrona, inclusa cattura del rifiuto se una write termina prima dell’ingresso load; guardie anche dopo notify rientrante; cleanup privato sempre fuori dispatch con rilascio exactly-once (R1). Le lane Theme restano indipendenti ma condividono SettingsRepositoryImpl: il rischio preesistente di lost update tra snapshot concorrenti è documentato (R2). Questa change non garantisce persistenza atomica/serializzata o assenza di quel rischio, e non modifica il repository né introduce mutex/queue/coordinator; un’eventuale correzione appartiene a intervento separato. I test PREF garantiscono stato e rollback locali per lane, non fusione delle scritture persistite. Questa era la valutazione del planning; i risultati realmente eseguiti e le successive correzioni sono nelle sezioni apply e post-apply di design.md.

**Stato storico della remediation documentale del 2026-10-19:** quella fase modificava esclusivamente i quattro artifact documentali esistenti. Nessun codice/test/support, dipendenza, analyzer, CI, backend, generato, logging globale, canonical diretta o altro piano; nessun apply, commit, push, PR, merge o archivio. F1 è risolto per esclusione autorizzata, F3 mediante delta MODIFIED; F2 ha strategia concreta e regression gate. Lo stato di allora era **READY FOR INDEPENDENT REVIEW**, non approvazione né autorizzazione apply. L’autorizzazione e l’implementazione successive sono descritte nello stato corrente sopra.
