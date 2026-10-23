# Tasks

Questa checklist registra l’apply completato e verificato. Il planning e la review indipendente del piano sono conclusi, la remediation F1–F5 è stata incorporata e l’apply è stato autorizzato ed eseguito. Anche la code review indipendente è stata completata; il checkpoint 4 è stato pubblicato nella [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12) con commit `da7c426fb799a26094f043319b47e63b98728f92`.

I 27 task `[x]` rappresentano attività implementate e verificate: le evidenze sono nelle sezioni Apply di `design.md`, con i relativi test e risultati. La numerazione e i gate documentano la sequenza richiesta: ogni gruppo dipende dal gate del precedente e un gate fallito impedisce di proseguire; lo scostamento procedurale del draft UI anticipato è registrato nel design. Scenari S/G/U/R e conteggi restano definiti in `design.md` e nei due delta.

## 1. Preflight e caratterizzazione

- [x] 1.1 Riconfermare PR #12 open/Draft e checkpoint cumulativo, worktree/branch/index e istruzioni applicabili; verificare con metadata PR, log e status che non esista divergenza non riconciliata da `1f3753b10c18061c6655cb32d078bf93aff1b05e`, preservando tutti gli altri checkout.
- [x] 1.2 Rileggere proposal/design/delta approvati e skill Result, mounted-context-safety, unit/widget test e test-support-reuse prima degli edit; verificare manifest ammesso, command_it 9.5.2 e ordine di riconciliazione canonical + delta 1–3 registrati nel design.
- [x] 1.3 Rigenerare analyzer machine B0 con `dart analyze --format machine`; salvare identità/molteplicità e verificare 87 INFO, zero WARNING/ERROR e 21 target, documentando differenze senza soppressioni.
- [x] 1.4 Estendere soltanto supporti esistenti per queue di Completer, contatori e notifiche necessari a S1–S18/G1–G9; verificare test di caratterizzazione bootstrap/ordine/errors attuali e che i test discriminanti delle race falliscano per la ragione attesa prima della correzione. La precedente fase di planning era rimasta esclusivamente documentale.
- [x] 1.5 Gate preflight: registrare nel design evidenze effettive e review delle decisioni corrette D1–D6 e finding F1–F5; verificare assenza di decisioni materiali demandate all'executor e nessun cambiamento foundation/repository/dependency.

## 2. Search history e SearchAnchor — remediation F1–F4

- [x] 2.1 Migrare i tre legacy a reader ResultCommand e writer privato della feature con un solo ResultCommand riutilizzato e FIFO ordinata; verificare S1/S3/S4/S18 e tabella F2: acceptance sincrona con sequence/epoch/drain/receipt prima di run/notify, deduplica dimostrata, nessun drop degli intenti distinti e nessuna serializzazione cross-owner.
- [x] 2.2 Implementare base+pending, ottimismo sincrono e rebase per singola entry secondo D1; verificare S2/S4/S17 e gli otto casi F2 con stato locale/persistito, ordine e numero write/notifiche esatti, anche quando la seconda operazione rimane accepted dopo failure della prima.
- [x] 2.3 R1: introdurre requestPastSearchesRefresh() come unico ingresso pubblico, reader privato/snapshot read-only e bootstrap attraverso la stessa API; verificare R1.1–R1.7 incluse domande prima/dopo avvio fisico e assenza bypass; implementare scheduler reader unico con epoch all'acceptance, requested/attempted, attesa drain OR detach e coalescing; verificare S5/S6/S8/S10/S11/S12/S16 contro G0 prima entry W, write-before/during-G0, read error, reentrancy e disposal senza cicli o waiter UI sospesi.
- [x] 2.4 Separare lifecycle UI/writer, staccare callback prima di disposal e mantenere drain degli accepted queued o non ancora entrati; verificare S9 e U1: submit→Command admission→close→navigation/dispose→entry→settlement, una write per submit accepted, zero publish/accessi UI tardivi e nessuna doppia write.
- [x] 2.5 Aggiornare AppSearchAnchor ai dispatch di intenti, con autorizzazione popup/owner/controller/sessione prima dell'acceptance; verificare U1/U2/U6 con recheck dopo dispatch e dopo own-close (token conferma distinto da popup consumed), su submit queued, suggestion, delete, categorie, vecchie callback dopo close/unmount/replacement, navigazione immediata e nessun doppio pop/reset del nuovo input.
- [x] 2.6 Implementare domanda di riconciliazione dopo runtime write tramite il solo reader D2, senza retry write o rollback inventato; verificare S7/S13/S14/S15/S18 per throw prima/dopo commit, nessun G0, W2 accepted, failure read e disposal con report originale/stack una volta per ciascuna effettiva failure runtime.
- [x] 2.7 Verificare pump/cleanup del Command privato e reader fuori dispatch/reporting, receipt void e drain fisico distinti da detach; eseguire S9/S12/S16 e test lifecycle idle/running/terminal, throw oltre teardown 50ms virtuale, assertion fail-loud e exactly-once release senza normalizzare abort o notificare UI disposed.
- [x] 2.8 Gate Search: eseguire suite Search VM/widget/sliver, foundation/lifecycle e tutte le righe S1–S18/U1/U2/U6 con conteggi e fake store controllato; verificare results/suggestions e repository invariati, aggiornare design con risultati reali e manifest. Non proseguire con failure, contraddizioni F1–F4 o nuove diagnostiche.

## 3. GeoMap marker retrieval

- [x] 3.1 Sostituire setter legacy con setter sincroni e snapshot immutabili/ticket distinti; inizializzare un solo loadMarkers restartable e bootstrap; verificare G1/G2/G3/G5 per stato same-stack, equality, alias, empty zero-I/O e normalizzazione dialog invariata.
- [x] 3.2 Implementare fetch locale eventi→luoghi per le sorgenti selezionate, filtro catturato, outcome immutabile per-source e commit atomico live; verificare G1/G2/G6 con tutte le combinazioni success/empty/error, ordine, cross-type identity, error precedence e nessun partial prima del settlement.
- [x] 3.3 Implementare terminal authority/ticket, invalidazione immediata, retry del filtro corrente e no-op busy/empty; verificare G3/G4/G5/G8 con A→B→A, completamenti fuori ordine e finestre prima della pubblicazione deferred, senza recupero del vecchio terminale uguale per valore.
- [x] 3.4 Integrare disposal e reentrancy del marker lane mantenendo isolate selectContent/loadNearContent; verificare G7/G9 per throw/AssertionError, reporting originale una volta, nessuna fase Places dopo disposal, nessuna notifica/commit obsoleti e cleanup esattamente una volta.
- [x] 3.5 Gate VM GeoMap: eseguire test VM GeoMap e foundation restartable, verificare rimozione completa dei quattro legacy target e invarianti semantic mode/Post/Nearby invariati; registrare prove e limiti di I/O fisico obsoleto nel design prima di adattare UI.

## 4. GeoMap UI, filtri e navigazione

- [x] 4.1 Adattare GeoMapScreen a status/terminal marker corrente con loading overlay, success-empty, MarkerLayer data e partial/total failure con retry; verificare U3 e G6/G8, messaggi distinguibili, nessun completed isolato e nessuna mappa/navigazione bloccata.
- [x] 4.2 Aggiornare wiring dei due setter e guardare retry/marker callback con owner e admission correnti; mantenere ObjectKey(owner), ownership dialog e stato draft; verificare U4/U5 e tabella F5: Salva, Back, barrier/drag consentiti applicano il draft corrente; unmount/sessione obsoleta non pubblicano, empty→all alla route completion, quattro regressioni owner replacement categorie/tipi × empty/nonempty conservate. Callback equal una volta ma zero admission/I/O; nessuna nuova UX Cancel.
- [x] 4.3 Verificare GeoMapBottomSheet, Search admission fence, Post selezionato e Weather senza modificarne ownership; eseguire U1/U5/R1 e test Map semantic per niente camera/sheet replay su notifiche marker, niente stale not-found o nuova lookup da vecchio marker.
- [x] 4.4 Eseguire gate routing/navigation/back/restoration/owner replacement elencato nel design, includendo SearchAnchor popup route e Gallery root; confrontare URI, chiamate delle lane escluse e stato dopo late settlement con invarianti baseline, registrando risultati reali nel design.
- [x] 4.5 Gate UI integrata: verificare tutti S1–S18/G1–G9/U1–U6/R1, tabella F2 e trigger F5 soddisfatti, stato sync e settlement distinti nei test, nessuna attesa wall-clock arbitraria, nessuna modifica a fondazione, query repository, Weather/Nearby, backend o route ownership; fermarsi in caso di regressione o conflitto materiale.

## 5. Integrazione e consegna per review implementazione

- [x] 5.1 Formattare soltanto file Dart intenzionalmente modificati e rigenerare analyzer machine B1; verificare rimozione delle 21 target, atteso 66 INFO senza WARNING/ERROR o nuove identità/molteplicità non-target, preservando configurazione e output completo per confronto B0/B1.
- [x] 5.2 Eseguire suite Flutter completa con `flutter test --no-pub` dopo gate mirati; registrare pass/fail/skip reali e ogni limite ObjectBox/runtime, senza equiparare risultati storici o CI a nuove esecuzioni.
- [x] 5.3 Aggiornare esclusivamente artifact della presente change con evidenze apply e scostamenti approvati, poi eseguire `openspec validate migrate-search-map-commands --strict`; verificare schema/delta e niente canonical sync o archive.
- [x] 5.4 Verificare manifest diff/whitespace inclusi nuovi file, HEAD/index e integrità di tutti gli altri checkout; richiedere review indipendente dell'implementazione con inventario completo e stato inequivocabile. Il vincolo originale richiedeva autorizzazione specifica successiva per commit/push/update PR: tale autorizzazione è poi intervenuta per la pubblicazione del checkpoint 4; il merge resta non autorizzato.

## Workflow follow-up

- Pubblicazione del checkpoint 4: **completata**, con commit `da7c426fb799a26094f043319b47e63b98728f92`.
- PR cumulativa #12: **4/7 implemented and published — ancora Draft, do not merge**. OpenSpec **5–7** e consolidamento finale restano pendenti.
- Merge della PR: **non autorizzato**; richiede autorizzazione esplicita dell’utente dopo i gate finali.
- Sync canonical e archive appartengono al consolidamento futuro: applicare prima il MODIFIED ordinary del primo OpenSpec e conservare i contratti semantic/Nearby della change precedente. Nessuna modifica a tali fonti in questo lavoro.
