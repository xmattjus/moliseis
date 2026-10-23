# Proposal

## Why

La quarta change della migrazione cumulativa della Draft PR #12 elimina i sette Command legacy residui di cronologia Search e filtri/marker GeoMap. Una sostituzione meccanica lascerebbe race tra bootstrap e cronologia, snapshot marker incoerenti e fallimenti non distinguibili da caricamento o risultato vuoto.

## What Changes

- Migrati add/load/remove della cronologia alle factory ResultCommand esistenti: un caricamento e un writer privato con FIFO locale ordinata. Il writer accetta sincronicamente gli intenti validi anche mentre una write è pendente, preserva ottimismo e rollback per operazione e completa gli obblighi già accettati anche dopo navigation/disposal della UI. Nessuna infrastruttura globale.
- Sostituiti quattro Command GeoMap con due setter sincroni e un unico caricamento restartable dei marker con snapshot immutabili, commit atomico, esiti parziali espliciti e retry corrente.
- Aggiornati i consumer reali e implementate/verificate regressioni deterministiche per concorrenza, errori, disposal, popup SearchAnchor, filtri, navigazione e owner replacement.
- **BREAKING** (solo API Dart interne): rimossi loadEvents/loadPlaces e la firma Command dei setter GeoMap; adattati tutti i chiamanti. Add/remove diventano dispatch di intenti alla FIFO locale: duplicati realmente rappresentati possono essere no-op, intenti opposti o su voci diverse sono preservati in ordine. La serializzazione è limitata alla sessione, senza cambiare ObjectBox o promettere ordine cross-owner.

## Capabilities

### New Capabilities

Nessuna.

### Modified Capabilities

- `command-execution-concurrency`: ammissione, persistenza ordinata indipendente dal lifecycle UI e riconciliazione revisionata della cronologia; autorità, snapshot, vuoto e retry del caricamento marker.
- `local-content-retrieval`: esiti atomici dei marker, ordine e risultati parziali con errore, distinti dai contratti Nearby esistenti.

## Impact

Apply eseguito su SearchViewModel, GeoMapViewModel, AppSearchAnchor, GeoMapScreen e test/supporti pertinenti, con adattamento dei consumer ExploreScreen e SearchResultScreen per evitare la chiusura ridondante della popup. GeoMapBottomSheet è una superficie di regression, non una nuova ownership di stato. GeoMapUseCase e SearchRepository restano confini esistenti: nessuna modifica a persistenza, backend, dipendenze o foundation.

Baseline dell’apply autorizzato: `1f3753b10c18061c6655cb32d078bf93aff1b05e`, con tre OpenSpec già implementati sulla PR cumulativa. Dopo il planning, la remediation F1–F5 e la review indipendente del piano, l’apply è stato autorizzato ed eseguito. La code review indipendente è stata completata e il checkpoint 4 è stato pubblicato nella [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12) con commit `da7c426fb799a26094f043319b47e63b98728f92`. Le evidenze dell’implementazione e delle verifiche sono registrate nelle sezioni Apply di `design.md`; `tasks.md` riporta le 27 attività completate e verificate. Search loadResults/loadSuggestions, GeoMap loadNearContent/selectContent, mode, Post, Weather, admission fence Search e route ownership rimangono fuori migrazione.

## Remediation F1–F5

La remediation del piano, completata prima dell’apply e incorporata nell’implementazione, ha sostituito le decisioni iniziali che perdevano submit prima dell’action entry, scartavano mutazioni opposte e invalidavano il bootstrap troppo tardi. Il protocollo unico nel design risolve anche la riconciliazione dopo runtime failure. I dialog mantengono l’applicazione del draft alla conclusione consentita della route (Salva, Back, barrier/drag), solo con State e sessione ancora correnti: nessuna nuova semantica di annullamento. Durante il planning i task erano rimasti unchecked in attesa della review indipendente del piano corretto e dell’autorizzazione all’apply; entrambe sono poi intervenute. Le checkbox attuali rappresentano l’apply verificato, non il solo completamento del planning.

## Stato corrente e follow-up

Planning, review indipendente del piano, remediation F1–F5, apply e code review indipendente sono completati; il checkpoint 4 è pubblicato. La PR #12 resta **4/7 implemented and published — Draft, do not merge**. OpenSpec 5–7 e consolidamento finale restano pendenti; l’analyzer non è globalmente green. Canonical sync e archive sono rinviati e il merge non è autorizzato. Le dichiarazioni di solo planning appartengono alla fase storica precedente all’apply.
