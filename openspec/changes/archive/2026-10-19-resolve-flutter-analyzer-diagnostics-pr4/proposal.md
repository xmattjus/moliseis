## Why

Eliminare le 57 info `async_return_with_no_await` residue con un cleanup semanticamente conservativo, separato dalla migrazione Command. Questa consegna autorizza soltanto analisi e planning: nessun apply, modifica Dart o esecuzione dei test d'implementazione.

## What Changes

- Rendere esplicita l'attesa dei risultati asincroni nelle occorrenze inventariate in design.md, conservando firme, errori, valori, ordine degli effetti e lifecycle.
- Distinguere deleghe Future, callback FutureOr e fallback immediati; conservare `async` e scegliere la posizione minima dell'`await` per ciascun ramo.
- Riutilizzare i test esistenti; aggiungere nella futura implementazione soltanto le caratterizzazioni mancanti di Result, debounce e condivisione gallery specificate nel design.
- Verificare zero target, zero errori/warning, nessuna nuova diagnostica e identità delle 125 info Command residue.

## Capabilities

### New Capabilities

Nessuna.

### Modified Capabilities

Nessuna. Non cambiano requisiti di prodotto: nessuna delta spec né modifica alle specifiche canoniche. OpenSpec 1.12.0 riconosce `schema: spec-driven`, `created: 2026-10-18`, `skip_specs: true`; status e instructions riportano specs skipped.

## Impact

Futura implementazione: 12 file di produzione e 4 file di supporto/test già diagnosticati, più soltanto gli eventuali file di test mirati esplicitamente descritti nel design. API pubbliche, backend, persistenza e dipendenze restano invariati. Planning attuale: esattamente `.openspec.yaml`, `proposal.md`, `design.md`, `tasks.md` nella nuova directory PR4.

## Baseline e riconciliazione

Repository origin: `https://github.com/xmattjus/moliseis.git`. Baseline richiesta `142a54fd6659ca76d6a33a252821239934fa6dce`; checkout effettivo `556c62b0d1e57dbebc24d2fb2e19da1785aeab09`, branch `codex/resolve-flutter-analyzer-diagnostics-pr3`. Il confronto completo con riconoscimento rename dimostra esclusivamente quattro R100: gli artifact PR3 sono attivi nel checkout e archiviati nella baseline. Zero differenze di contenuto in codice, test, configurazione e artifact PR3; nessun checkout/reset necessario. PR1 e PR2 archiviati sono stati esaminati; PR3 è stato letto nel percorso attivo e confrontato con l'archivio della baseline mediante Git.

Working tree iniziale: soltanto ` M AGENTS.md`, aggiunta preesistente delle regole GitHub, preservata; index vuoto, nessun untracked. Nessuna istruzione annidata trovata. Flutter 3.47.5, Dart 3.13.4, very_good_analysis 11.0.0 e command_it 9.5.2 confermati da SDK/cache e lockfile; configurazione analyzer esaminata e invariata.

Il 2026-10-18 `flutter analyze --no-pub` ha prodotto exit 1: 0 errori, 0 warning, 182 info = 57 target + 125 `deprecated_member_use_from_same_package` Command. Il primo tentativo sandbox non ha avviato l'analisi per i file cache SDK esterni; il rerun autorizzato ha completato l'analisi. Inventario attuale e ledger durevole sono in design.md; log grezzo temporaneo `/tmp/pr4-analyze.log`. Non si deduce successo dall'exit 1: resta accettabile soltanto per le info legacy dimostrate.

## Base del futuro branch PR4 — remediation F2

`142a54fd6659ca76d6a33a252821239934fa6dce` resta la baseline **storica del planning**, non un vincolo a usare un commit superato. Il futuro branch PR4 deve derivare dall'ultimo `origin/main` verificato e approvato nel preflight dell'implementazione, registrandone SHA e confronto con il remoto. Se main avanza, riconciliare prima dell'apply codice, configurazione, baseline analyzer e identità delle diagnostiche; nessun ampliamento implicito del cleanup. Con modifiche preesistenti nel checkout principale, preferire un worktree isolato da tale origin/main, preservando integralmente AGENTS.md e ogni altro lavoro dell'utente. Trasferire soltanto i quattro artifact PR4 approvati, senza reintrodurre commit/modifiche del vecchio branch PR3 già integrati o spostamenti dei suoi artifact già archiviati. Nessun reset, clean, force push o checkout distruttivo. Prima della readiness per pubblicazione verificare ancestry/merge-base e intero diff PR4 rispetto alla base corretta di main, oltre al diff locale. Questa remediation non crea branch o worktree.

Riconferma in sola lettura del 2026-10-19: HEAD/branch invariati; `origin/main` e HEAD remoto main (git ls-remote) sono entrambi `142a54fd…`; rispetto a questi restano soltanto i quattro R100 PR3. Il ref locale `main` è invece fermo a `6ccc62635d033747159d37c718ad38d961de8376` (PR2) e non è una base aggiornata: non confonderlo con origin/main. Nessun drift remoto sopravvenuto rilevato; nessun ref locale aggiornato. Working tree della remediation: AGENTS.md preesistente più i quattro artifact PR4 untracked, index vuoto; i fatti del planning del 18 ottobre sopra restano storici.

## Esclusioni assolute

Nessuna modifica a Command/Command0/Command1 o deprecazioni, command_it, RestartableCommand, dipendenze/lockfile, analyzer/lint/soppressioni, CI/branch protection, ObjectBox/schema/generati, Supabase/SQL/RPC/Edge Functions/RLS, specifiche canoniche. Nessun package, nuova architettura, wrapper generico, catch aggiuntivo, microtask artificiale, Future superfluo, refactoring opportunistico o migrazione Command. In planning non modificare produzione o test. Non eseguire apply, commit, push, creazione PR, merge, sync o archive. La review avversariale del piano è una fase separata successiva.

## Nota di remediation — 2026-10-19

La review successiva al planning ha rilevato F1 (hook gallery irraggiungibile), F2 (base Git futura non vincolata), F3 (test StateError potenzialmente non deterministico) e N1–N3. Design/tasks ora usano streamFactory → getFileStream → extension reale, fissano origine Git e gestione drift, rendono facoltativa soltanto la prova StateError non osservabile deterministicamente, e consolidano limiti scheduling, riuso dei test e failure path Sentry. Nessuna delle 57 strategie cambia; nessuna implementazione autorizzata. Esito documentale della nuova validazione e autoreview nella nota finale di design.md.
