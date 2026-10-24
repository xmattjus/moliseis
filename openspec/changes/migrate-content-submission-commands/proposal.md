# Proposal

## Why

La quinta change della migrazione cumulativa della Draft PR #12 elimina cinque Command legacy di Content Submission e 14 diagnostiche target. La sostituzione deve preservare draft, staged assets, ownership e finalizzazione, impedendo che l’action entry differita di command_it interpreti una richiesta come riferita a una sessione o un asset successivo.

## What Changes

- Migrare `addAsset`, `removeAssetAt`, `submit`, `clear`, `retrieveLostAssets` alle factory ResultCommand esistenti, con admission sincrona, richieste immutabili e una sola arbitratura locale `_serialize`.
- Rendere espliciti i confini tra inizializzazione, richiesta, preparazione, acknowledgement e finalizzazione; mantenere mutazioni della stessa sessione, submit sequenziale e retry esclusivamente locale dopo acknowledgement confermato.
- Distinguere Result di dominio, throw runtime, reporting e assertion; revocare nuove fasi ed effetti UI dopo disposal conservando settlement privato e cleanup sicuro dei cinque Command.
- Adattare form, lista asset, progress e callback di routing al terminale corrente e al rebinding del ViewModel; conservare process restoration idle e policy Back/Home.
- **BREAKING** (API Dart interne): i cinque Command eseguibili diventano privati. I consumer usano `requestAddAsset`, `requestRemoveAssetAt`, `requestSubmit`, `requestClear`, `requestRetrieveLostAssets` e osservabili Result-aware senza accesso a run/runAsync. Nessun contratto remoto o persistito cambia.

## Capabilities

### New Capabilities

Nessuna.

### Modified Capabilities

- `command-execution-concurrency`: admission e lifecycle ordinary specifici dei cinque Command, errori runtime distinti e settlement dopo disposal.
- `content-submission-local-asset-staging`: binding alla richiesta e all’inizializzazione, identità della rimozione, arbitratura e recovery Android obsoleta.
- `content-submission-submit-orchestration`: snapshot alla richiesta, controllo della sessione prima degli effetti, rilascio su failure e confini di disposal della finalizzazione.
- `content-submission-navigation-lifecycle`: stati Result-aware, retry derivato, handoff sincrono e consumer sostituibili senza callback obsolete.

## Impact

Baseline autorizzata `f48a08946c9ac40146104a0157556243ad433c92`, figlio diretto di `da7c426fb799a26094f043319b47e63b98728f92`: l’unico avanzamento è la riconciliazione documentale dell’OpenSpec 4. PR #12 riconfermata aperta/Draft sulla SHA autorizzata. Worktree persistente e branch dedicati documentati nel design.

Apply autorizzato limitato al ViewModel, tre consumer principali, hardening dei callback Content Submission nel router e test/supporti pertinenti. Nessuna modifica a foundation, dipendenze, composizione Provider, repository, ObjectBox, Cloudinary, RPC, Edge Function, schema o persistenza draft. Analyzer B0 dell’apply rigenerato: 66 INFO, zero WARNING/ERROR; gate B1 richiesto: 52 INFO con rimozione delle sole 14 target e conservazione delle identità non-target. I risultati effettivi sono registrati nell’appendice apply del design.

Il planning e le remediation F1–F3 sono stati approvati dopo due review indipendenti. L’utente ha successivamente autorizzato l’apply, attualmente locale e non committato: checklist ed evidenze effettive sono in tasks e design. La review indipendente del codice e l’autorizzazione alla pubblicazione restano successive. Nessun commit, push, aggiornamento PR, sync canonical, archive o merge.

Apply locale verificato: cinque Command migrati, gate funzionali completati, suite Flutter completa **2.862 pass/0 failure/6 skip preesistenti (exit 0)**. Analyzer B0/B1 **66→52 INFO**, zero WARNING/ERROR, esattamente 14 identità target rimosse e nessuna variazione non-target dopo mapping delle linee. Il legacy command.dart resta per le migrazioni successive. Nessuna pubblicazione eseguita; il prossimo passaggio è la review indipendente del codice.
