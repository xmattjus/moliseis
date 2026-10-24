# Proposal

## Why

La terza migrazione cumulativa della Draft PR #12 sostituisce gli otto Command legacy di EventViewModel (4), PostViewModel (3) e SyncViewModel (1) con la foundation command_it esistente. La sostituzione richiede contratti espliciti per selezioni calendario, bootstrap route, errori terminali e redirect Sync: execute legacy e run/runAsync non sono equivalenti.

## What Changes

- Usare sette lane ordinarie ResultCommand e una lane RestartableCommand per il solo giorno calendario, con selezione sincrona nel ViewModel e commit autoritativo.
- Conservare bootstrap annuale, cache/revisioni, policy temporale Europe/Rome e coordinamento Home single-flight con richieste coalescenti e un solo snapshot UTC per passata. Un cache hit dello stesso giorno/revisione conserva il risultato fallback già committato, anche empty, prima di qualsiasi derivazione da _all. Event day avrà proiezione terminale completa, barriera di admission contro snapshot obsoleti, selezione calendario osservata direttamente e retry esplicito della data corrente dopo failure.
- Conservare identità Post (id,type), owner replacement, binding Weather e Nearby events→places, dati parziali e primo errore; rendere terminale visibile il failure del dettaglio senza letture premature di late content e senza nuova navigazione o retry UI.
- Conservare auto-sync prima del primo frame, force, esclusione concorrente e ritorno alla URI validata. Rendere fatalError relativo all’esito corrente, includendo failure runtime senza trasformarlo in Result.error, con reporting globale originale una volta. Autorizzare il feedback nonfatal con context vivo prima del normale return: il messenger globale lo conserva dopo il redirect. Rebind locale SyncScreen tramite dipendenza Provider reattiva; nessun feedback da osservazioni obsolete. Questo non sostituisce l’owner catturato dal router: nel lifecycle applicativo router e Provider condividono l’owner, e una nuova sessione richiede un nuovo lifecycle router coerente. Nessun rebind dinamico del router in scope.
- Adattare i consumer reali a results/ResultCommandSnapshot, distinguendo admission sincrona, ingresso differito e notifiche; cleanup locale deterministico e idempotente secondo OpenSpec 1/2.
- Verificare test mirati, routing/ownership/restoration e suite Flutter completa durante apply; eliminare esattamente le 18 identità diagnostiche target (105→87 INFO, zero warning/errori e zero nuove identità).

## Capabilities

### New Capabilities

Nessuna.

### Modified Capabilities

- `command-execution-concurrency`: aggiungere contratti osservabili Event day/annual, Post detail/Nearby e Sync admission/esito/navigazione/lifecycle, senza riscrivere la MODIFIED del primo piano né indebolire Search/Map.
- `home-ongoing-events`: aggiungere il contratto di settlement indipendente delle due lane, gestione delle richieste esterne e teardown dei waiter; restano invariati classificazione, snapshot unico e retry coordinato.

## Impact

Baseline autorizzata: `e3d9d891c5b560524e66b35f0bf70f9108cacb7e` (OpenSpec 2), padre `9d17d224d5094c5b043128113d9aba6a1ce69f0a`. PR #12 aperta/Draft sullo stesso SHA, origin `https://github.com/xmattjus/moliseis.git`; main è `ee60777c7fdfc5c16daa1151050c134fbb7cde29` e non è una baseline sostitutiva. Preflight storico: worktree `/private/tmp/moliseis-openspec3`, detached sul checkpoint, inizialmente pulito con index vuoto. Nella remediation F4 lo stesso worktree è stato trasferito con `git worktree move` in `/Users/benitomatteobercini/Developer/Progetti/moliseis-worktrees/migrate-content-view-model-commands` e associato al branch locale `codex/plan-migrate-content-view-model-commands`: HEAD invariato, sei hash identici prima/dopo il trasferimento e index vuoto. Questo è l’unico worktree operativo futuro. Audit e ledger ripetuti il 2026-10-21; dettagli riproducibili nel design.

Perimetro apply: tre VM, router/core_routes, widget Event/Explore/Post/Sync e test/support strettamente pertinenti. Nearby condiviso, WeatherViewModel, Provider scope, foundation, SyncUseCase, repository/persistenza, backend, dipendenze e configurazione analyzer restano invariati. L’eventuale conflitto materiale richiede revisione del piano prima dell’esecuzione.

Il planning originale modificava esclusivamente gli artifact della nuova change. La remediation F1–F4 modifica soltanto gli artifact esistenti e ha eseguito le sole operazioni Git locali di trasferimento e associazione branch autorizzate. Nessun Dart/test implementato, commit, push, merge, aggiornamento PR, sync canonical o archivio. Il piano richiede review adversariale indipendente prima di autorizzare apply; i successi storici dei primi due piani non sono nuove verifiche di questa change.

## Stato dell’apply — 2026-10-23

Apply autorizzato dopo review indipendente del piano ed eseguito nel worktree persistente. Gli esiti correnti sono registrati nel design, separati dalla provenienza di planning sopra: suite completa 2.619 passati e sei skip preesistenti, analyzer B1 105→87 INFO con esatte 18 identità target eliminate e zero nuove diagnostiche. Checklist e strict OpenSpec riconciliati nel closeout. Modifiche soltanto locali, nessun commit/push/PR update/archive/sync canonical; richiesta ora la code review indipendente, senza claim di merge readiness.
