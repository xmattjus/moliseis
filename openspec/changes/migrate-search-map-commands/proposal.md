# Proposal

## Why

La quarta change della migrazione cumulativa della Draft PR #12 elimina i sette Command legacy residui di cronologia Search e filtri/marker GeoMap. Una sostituzione meccanica lascerebbe race tra bootstrap e cronologia, snapshot marker incoerenti e fallimenti non distinguibili da caricamento o risultato vuoto.

## What Changes

- Migrare add/load/remove della cronologia alle factory ResultCommand esistenti: un caricamento e un writer privato con FIFO locale ordinata. Accettare sincronicamente gli intenti validi anche mentre una write è pendente, preservare ottimismo e rollback per operazione e completare gli obblighi già accettati anche dopo navigation/disposal della UI. Nessuna infrastruttura globale.
- Sostituire quattro Command GeoMap con due setter sincroni e un unico caricamento restartable dei marker con snapshot immutabili, commit atomico, esiti parziali espliciti e retry corrente.
- Aggiornare i consumer reali e pianificare regressioni deterministiche per concorrenza, errori, disposal, popup SearchAnchor, filtri, navigazione e owner replacement.
- **BREAKING** (solo API Dart interne): rimuovere loadEvents/loadPlaces e la firma Command dei setter GeoMap; adattare tutti i chiamanti. Add/remove diventano dispatch di intenti alla FIFO locale: duplicati realmente rappresentati possono essere no-op, intenti opposti o su voci diverse sono preservati in ordine. La serializzazione è limitata alla sessione, senza cambiare ObjectBox o promettere ordine cross-owner.

## Capabilities

### New Capabilities

Nessuna.

### Modified Capabilities

- `command-execution-concurrency`: ammissione, persistenza ordinata indipendente dal lifecycle UI e riconciliazione revisionata della cronologia; autorità, snapshot, vuoto e retry del caricamento marker.
- `local-content-retrieval`: esiti atomici dei marker, ordine e risultati parziali con errore, distinti dai contratti Nearby esistenti.

## Impact

Futuro apply limitato a SearchViewModel, GeoMapViewModel, AppSearchAnchor, GeoMapScreen e test/supporti pertinenti. GeoMapBottomSheet è una superficie di regression, non una nuova ownership di stato. GeoMapUseCase e SearchRepository restano confini esistenti: nessuna modifica a persistenza, backend, dipendenze o foundation.

Baseline autorizzata: `1f3753b10c18061c6655cb32d078bf93aff1b05e`, tre OpenSpec già implementati sulla PR cumulativa. Questa change produce esclusivamente planning; nessun apply, commit, push, aggiornamento PR, sync canonical o archive. Search loadResults/loadSuggestions, GeoMap loadNearContent/selectContent, mode, Post, Weather, admission fence Search e route ownership rimangono fuori migrazione.

## Remediation F1–F5

Questa revisione sostituisce le decisioni iniziali che perdevano submit prima dell’action entry, scartavano mutazioni opposte e invalidavano il bootstrap troppo tardi. Il protocollo unico nel design risolve anche la riconciliazione dopo runtime failure. I dialog mantengono l’applicazione del draft alla conclusione consentita della route (Salva, Back, barrier/drag), solo con State e sessione ancora correnti: nessuna nuova semantica di annullamento. Tutti i task restano unchecked; serve review indipendente del piano corretto prima di qualsiasi autorizzazione apply.
