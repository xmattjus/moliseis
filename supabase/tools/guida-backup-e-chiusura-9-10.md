# Guida operativa: backup Supabase e chiusura del task 9.10

Questa guida riguarda `add-external-event-provenance-moderation`. Prima si
prepara una possibilità concreta di recupero; poi si esegue l'audit production
che permette di chiudere **9.10**. Scrivere la guida o provare i tool su fixture
non esegue il rollout e non certifica il backup.

**9.10 è il rapporto di controllo, non il cut-over.** Può essere chiuso quando
l'inventario production è completo, ogni identità è classificata, tutti i dubbi
sono risolti e il dry-run delle vere RPC spiega ogni proposta. Il backfill
committato, il cut-over e l'attivazione restano passaggi successivi da
autorizzare ed eseguire. Non mettere `[x]` a 10.8 senza il freeze e la
quiescenza reali.

## 1. Cosa significa “backup completo”

Supabase è più di un database. Un dump SQL, da solo, non è una copia completa
del progetto. Anche il ripristino managed del database non ricrea
automaticamente tutti gli altri servizi. La documentazione ufficiale distingue
il database dagli oggetti Storage:
[Database backups](https://supabase.com/docs/guides/platform/backups).

Preparare questo inventario prima di cambiare produzione:

| Componente              | Cosa conservare                                                                       | Cosa verificare                                                                                   |
| ----------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Database applicativo    | Schema, dati, sequenze, constraint, RLS, policy, trigger, funzioni, grant, estensioni | Dump riuscito, contenuto atteso, prova di ripristino isolata                                      |
| Auth                    | Dati dello schema `auth`, utenti, identità e personalizzazioni SQL                    | Gli utenti sono presenti; redirect, provider OAuth, SMTP e impostazioni si ricreano separatamente |
| Ruoli                   | Ruoli custom e grant necessari                                                        | Non presumere che i ruoli managed si ripristinino come quelli di un PostgreSQL autonomo           |
| Storia migration        | `supabase_migrations.schema_migrations` e checkout esatto                             | Versioni remote e locali riconciliate; non usare `db pull` come backup                            |
| Storage                 | Metadata SQL, bucket e file binari                                                    | I file richiedono una copia distinta; i metadata non contengono i byte                            |
| Vault                   | Dati cifrati e possibilità di recuperare i valori originali                           | Il dump cifrato, senza la chiave corretta, non garantisce il recupero su un altro progetto        |
| Cron/webhook            | Definizioni dei job, trigger e riferimenti ai segreti                                 | Un restore può riattivare chiamate esterne e il vecchio importer                                  |
| Edge Functions          | Bundle realmente distribuiti, versioni, configurazione JWT, dipendenze                | Il checkout nuovo non è il backup della versione legacy online                                    |
| Segreti Edge            | Valori originali custoditi privatamente                                               | L'elenco dei nomi/digest non permette di recuperare i valori originali                            |
| Configurazione progetto | Auth, API, URL, rete, integrazioni e impostazioni dashboard                           | Un dump SQL non ricrea la configurazione della piattaforma                                        |
| Cloudinary              | Media e configurazione nel servizio Cloudinary                                        | È fuori da Supabase: serve un piano separato                                                      |

Riferimenti:
[ripristino tramite CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore),
[Vault](https://supabase.com/docs/guides/database/vault),
[ripristino su un nuovo progetto](https://supabase.com/docs/guides/platform/clone-project).

### Stato rilevato, non garanzia di recupero

L'ispezione read-only del 3 ottobre 2026 ha rilevato PostgreSQL **17.6**, **300
utenti Auth**, **240 content submissions**, **4 segreti Vault** e **1 job
cron**. Storage risultava vuoto: **0 bucket e 0 oggetti**. Questi conteggi sono
un punto di confronto, non una fotografia immutabile: ricontrollarli al momento
del backup.

L'API backup osservata riportava `pitr_enabled = false`, elenco `backups` vuoto,
`walg_enabled = true` e `physical_backup_data = {}`. Questo **non prova** che ci
sia un punto di ripristino utilizzabile. Prima di contarci, verificare nella
dashboard il punto effettivamente disponibile o ottenere conferma da Supabase.
Non attivare servizi a pagamento o cambiare piano incidentalmente.

Al momento di scrittura, un ripristino completo della produzione **non è stato
provato**. Non iniziare il rollout basandosi soltanto sull'idea che “Supabase
avrà un backup”.

**Stato operativo: backup NON ESEGUITO; restore NON ESEGUITO.** La revisione
automatica delle autorizzazioni ha rifiutato l'esportazione proposta perché
comprende dati e credenziali production e richiede un'approvazione esplicita del
contenuto e della destinazione. I comandi seguenti sono istruzioni, non
operazioni già eseguite.

## 2. Preparare il backup prima del rollout

### 2.1 Scegliere una cartella privata e una copia indipendente

Usare una destinazione **fuori dal repository**, protetta e accessibile solo
all'operatore. I dump possono contenere dati personali, password hash, sessioni,
token e segreti. Non allegarli a issue, PR o chat. Non usare `set -x`,
`--debug`, log di DSN o header di autorizzazione.

Esempio di struttura, da creare nella destinazione privata scelta:

```text
backup-<data-e-ora>/
  database/
  storage/
  deployed-functions/
  configuration/
  secrets/                 # custoditi cifrati; non un file pubblico
  checksums.sha256
  backup-inventory.md
  restore-rehearsal.md
```

Conservare una seconda copia cifrata su un supporto indipendente. Un hash prova
che il file non è cambiato; non prova che sia ripristinabile.

La proposta concreta da approvare per questa macchina è:

- progetto **Molise Is Production**, ref `tnxiujpgzrdeyaoqxwcy`;
- destinazione `/Users/benitomatteobercini/Backups/MoliseIs/Supabase/`,
  sottocartella con timestamp;
- database completo, inclusi utenti Auth e password hash, ruoli e migration
  history; funzioni distribuite e configurazioni recuperabili;
- chiave root Vault e API key del progetto, custodite esclusivamente nel backup
  privato; nomi/digest dei segreti Edge;
- archivio finale `.dmg` cifrato AES-256, con password nuova conservata nel
  Portachiavi macOS, verifica checksum dopo riapertura e rimozione della copia
  temporanea in chiaro solo dopo quella verifica;
- nessuna copia automatica di `.env` locali di provenienza non verificata;
  nessun restore, deploy, freeze o acquisto di PITR.

La preparazione temporanea contiene dati in chiaro: permessi stretti e cifratura
finale non eliminano questa esposizione durante l'export. I segreti Edge
originali e Cloudinary restano componenti da completare separatamente. Finché
manca una copertura verificata, chiamare il risultato **backup dei componenti
esportati**, non “copia completa e ripristinabile dell'istanza”.

### 2.2 Controllare gli strumenti e la connessione

La CLI verificata per questa guida è **2.119.0**. Prima di usare un'altra
versione, ricontrollare i flag:

```bash
supabase --version
supabase db dump --help
supabase functions download --help
pg_dump --version
psql --version
```

Usare un client PostgreSQL compatibile con il server 17. Usare il progetto/ref e
la connessione autorizzati, caricando le credenziali dal gestore di segreti o da
un meccanismo privato; non incollarle nei comandi salvati o nella guida.

### 2.3 Salvare database, Auth, ruoli e storia

La CLI offre dump di schema, dati e ruoli. Gli esempi seguenti sono operazioni
di lettura e scrivono solo nella destinazione privata, **dopo aver verificato il
progetto corretto**:

```bash
# Variabili di percorso/ref, senza password o DSN nei log.
supabase db dump --linked --project-ref "$backup_project_ref" --role-only \
  --file "$backup_dir/database/roles.sql"
supabase db dump --linked --project-ref "$backup_project_ref" \
  --file "$backup_dir/database/schema.sql"
supabase db dump --linked --project-ref "$backup_project_ref" --data-only --use-copy \
  --file "$backup_dir/database/data.sql"
```

**Non considerare questi tre file automaticamente completi.** La CLI tratta
schemi managed come Auth e Storage in modo particolare. Seguire il percorso
ufficiale di restore e verificare la copertura reale dei file prodotti. Per una
copia portabile del database serve anche un export PostgreSQL coerente,
comprensivo degli schemi necessari, più la storia migration e le
personalizzazioni Auth/Storage. Eseguirlo attraverso la connessione privata
approvata, senza stampare il DSN. Preferire un dump unico consistente per schema
e dati; tre dump separati mentre la produzione scrive non condividono
necessariamente lo stesso snapshot.

Per il dump aggiuntivo completo, configurare privatamente `PGHOST`, `PGPORT`,
`PGUSER`, `PGDATABASE` e l'autenticazione PostgreSQL. Non usare un DSN con
password come argomento. Poi, nella destinazione già approvata:

```bash
pg_dump --format=custom --file "$backup_dir/database/full-database.dump"
pg_restore --list "$backup_dir/database/full-database.dump" \
  > "$backup_dir/database/full-database.contents.txt"
supabase db dump --linked --project-ref "$backup_project_ref" \
  --schema supabase_migrations \
  --file "$backup_dir/database/migration-history-schema.sql"
supabase db dump --linked --project-ref "$backup_project_ref" \
  --schema supabase_migrations --data-only --use-copy \
  --file "$backup_dir/database/migration-history-data.sql"
```

Il dump unico PostgreSQL usa uno snapshot consistente dei dati visibili alla
connessione. Verificare accesso a tutti gli schemi richiesti e successo del
comando: non ignorare errori di permessi. Non include ruoli globali o servizi
esterni e non rende atomici gli export separati di configurazione e funzioni.
`pg_restore --list` verifica la leggibilità dell'indice; **non è una prova di
restore**. Conservare una versione di `pg_restore` compatibile con quella di
`pg_dump` che ha creato l'archivio.

Durante la raccolta non applicare migration o deploy concorrenti. Riconciliare
la history separata con quella inclusa nel dump completo e registrare eventuali
scritture avvenute tra i vari export. Per inizializzare i soli percorsi, dopo
l'approvazione della destinazione:

```bash
umask 077
backup_project_ref='tnxiujpgzrdeyaoqxwcy'
backup_dir="$HOME/Backups/MoliseIs/Supabase/$(date -u +%Y%m%dT%H%M%SZ)/private-staging"
private_functions_backup="$backup_dir/deployed-functions"
mkdir -p "$backup_dir/database" "$private_functions_backup"
```

Questa cartella è staging **in chiaro**, non l'archivio cifrato finale. Non
considerare il backup pronto finché non sono concluse cifratura, verifica e
custodia indipendente. Non cancellare un export valido se la cifratura fallisce;
proteggere lo staging e risolvere prima il problema.

Il dump completo PostgreSQL è una copia dei contenuti del database, **non** un
installer autonomo di Supabase: sul progetto di destinazione i servizi e gli
schemi managed vanno preparati secondo le istruzioni ufficiali. Il restore non
consiste nel caricare indiscriminatamente tutto sopra gli schemi managed già
esistenti.

Registrare privatamente: inizio/fine export, versioni client/server, exit code,
dimensioni, checksum, conteggi e oggetti inclusi/esclusi. Verificare almeno
Auth, `content_submissions`, `events`, `submissions_assets`, sequenze, funzioni
e trigger applicativi, RLS/grant e `supabase_migrations.schema_migrations`.

Il backup iniziale può essere fatto mentre il servizio è attivo; resta uno
snapshot di quel momento. Prima dei passaggi irreversibili occorre sapere quali
scritture successive si perderebbero ripristinandolo. Il freeze legacy di 10.8
non ferma automaticamente tutte le scritture umane dell'applicazione.

### 2.4 Salvare Storage, Edge, Vault e configurazione

1. Ricontrollare bucket e oggetti. Se continuano a essere entrambi zero, salvare
   la prova del conteggio; non serve inventare un archivio di file inesistenti.
   Se non sono zero, copiare separatamente i byte di tutti gli oggetti e la
   configurazione bucket, verificando numero e checksum delle copie.
2. Scaricare le **funzioni effettivamente distribuite**, fuori dal checkout:

   ```bash
   supabase functions download --project-ref "$backup_project_ref" \
     --workdir "$private_functions_backup"
   ```

   Conservare le dipendenze condivise, import map/lock/config disponibili,
   versioni e flag JWT. Verificare in particolare il bundle legacy
   `import-external-events`: deve poter essere riprodotto senza usare la nuova
   implementazione locale. Se il download non recupera tutto il necessario,
   completare il recupero prima del freeze.
3. Inventariare i nomi dei segreti Edge e recuperare i **valori originali**
   dalla fonte privata che li custodisce. I digest pubblicabili non
   sostituiscono i valori. Non mettere i segreti nel report 9.10.
4. Per Vault, conservare i dati cifrati ma verificare anche il piano di recupero
   della chiave/valori originali. Un trasferimento a un nuovo progetto può
   richiedere la ricreazione dei segreti; non presumere che il ciphertext basti.
   Il root key è gestito fuori dal database: un restore nello stesso progetto lo
   conserva, mentre il trasferimento manuale a un nuovo progetto richiede il
   trattamento della chiave descritto dalla documentazione
   [Vault](https://supabase.com/docs/guides/database/vault).
5. Conservare privatamente cron, webhook e configurazione piattaforma. Il
   comando di un job può contenere riferimenti o valori sensibili: non
   riversarlo nel log pubblico. Salvare anche chi può invocare manualmente il
   legacy importer.
6. Trattare Cloudinary separatamente: un restore DB può ripristinare riferimenti
   a immagini che nel frattempo sono state eliminate dal servizio.

La configurazione recuperata tramite API può contenere hash/HMAC dei segreti,
non i valori utilizzabili nel restore. Annotare il limite e conservare gli
originali nel gestore privato:
[Project config API](https://supabase.com/docs/reference/api/v2-get-project-config),
[Edge Function secrets](https://supabase.com/docs/guides/functions/secrets).

### 2.5 Provare il recupero in isolamento

La prova deve usare un ambiente separato, non la produzione. Stabilire **prima
del restore** come impedire invocazioni Edge, cron, webhook, email e chiamate
Cloudinary. I cloni managed possono avviare componenti di rete e cron: un nuovo
nome progetto non è isolamento sufficiente.

Seguire il metodo ufficiale compatibile con l'ambiente scelto e verificare:

- restore terminato senza errori;
- conteggi e record campione corrispondenti allo snapshot;
- Auth e personalizzazioni SQL presenti;
- constraint, RLS, funzioni, trigger e sequenze coerenti;
- file Storage recuperabili, se esistenti;
- segreti e configurazioni ricreabili senza esporli;
- nessuna email, chiamata esterna o scrittura del legacy importer partita dalla
  copia.

Registrare cosa è stato realmente provato e cosa resta da recuperare
manualmente. Un restore SQL riuscito non certifica da solo l'intera istanza. Se
non è possibile provare il recupero, riportare quel limite esplicitamente e
decidere il rollout con quel rischio concreto, senza chiamare il backup
“completo e verificato”.

## 3. Preparare la finestra per 9.10

Usare il [runbook normativo](external_event_deployment_runbook.md). L'ordine è:

1. schema additivo, guard DB e compatibilità notifiche;
2. backend Admin compatibile;
3. nuovo client Flutter Admin disponibile ai moderatori;
4. freeze legacy, drain, quiescenza e T0;
5. export, audit, shadow, classificazione e remediation;
6. dry-run delle vere RPC, report e gate; poi backfill verificato;
7. cut-over esplicito e ritiro permanente del legacy writer;
8. attivazione del nuovo importer.

Non distribuire tutte le migration/funzioni in un colpo: il runbook specifica i
prefissi SQL e richiede il backend che gestisce il nuovo outcome prima della RPC
che lo produce. Il client deve essere disponibile **prima** delle proposte
update.

Preparare prima del freeze: backup verificato, release checkout, strumenti,
credenziali private, bundle legacy, manifest di lavoro, prove storiche già
recuperate e un operatore che possa decidere i casi dubbi. Non spendere la
finestra T0 a cercare per la prima volta una vecchia capture.

Il periodo **freeze → audit → cut-over → attivazione** deve terminare nella
stessa data di calendario **Europe/Rome** di T0. Pianificare la finestra con
margine. Non riutilizzare l'export di una prova abbandonata per una nuova
finestra.

## 4. Verificare Admin, poi eseguire 10.8

Le prove del client devono coprire update Link/Apply, Reject con ignore, lista
ignored/un-ignore, stale indicator, acknowledgement, `source_changed` e token
opachi. Registrare riferimenti reali nel JSON di release e verificare:

```bash
deno run --allow-read supabase/tools/external_event_rollout_preflight.ts \
  "$private_release_evidence"
```

Esito atteso: exit 0, `PREFREEZE_EVIDENCE_COMPLETE`. Questo controlla i
riferimenti nel JSON; il revisore deve controllare che corrispondano a prove
vere.

Solo nella release autorizzata, seguire il runbook per:

1. salvare definizione cron e versione legacy;
2. disabilitare il job `import-external-events-eventimolise`;
3. ritirare la route legacy e fermare i chiamanti manuali;
4. rendicontare richieste accodate/in-flight, inclusi gli arrivi tardivi;
5. provare che ogni richiesta entrata nel writer è terminata;
6. registrare T0 e data di Roma dal DB.

“Cron spento”, “coda vuota” e “non vedo log da cinque minuti” non bastano. Una
richiesta già in esecuzione può ancora scrivere. Un timeout non dimostra che il
writer sia terminato. Se manca una richiesta all'appello, non registrare T0.

## 5. Esportare tutta la popolazione legacy

Verificare privatamente l'UUID tecnico legacy. Non prendere tutte le submission,
non limitarsi alle pending, non filtrare via le note malformate. Servono
accepted, rejected e pending di quell'identità tecnica.

Attraverso la connessione operatore privata, usare il file SQL esistente:

```bash
# psql usa la connessione privata già configurata; il comando non contiene DSN.
psql -X --set ON_ERROR_STOP=on \
  --set legacy_importer_user_id="$audited_legacy_importer_uuid" \
  --tuples-only --no-align \
  --file supabase/tools/export_external_event_history.sql \
  > "$private_attempt_dir/legacy-history.json"
```

L'export è SQL JSONB: preserva microsecondi e precisione delle coordinate. Non
sostituirlo con un export PostgREST o con un CSV convertito a mano. Conservare
timestamp, checksum, conteggio totale e per status, query e ref T0 nella prova
`population_evidence_ref`. Riconciliare il numero di righe con la query di
conteggio dello stesso UUID; **240 è il conteggio di tutte le submissions
rilevato prima, non il totale legacy da assumere**.

## 6. Raccogliere le osservazioni EventiMolise

Usare l'adapter già esistente in
`supabase/functions/import-external-events/eventimolise.ts`:

- `discoverFutureStartDates({ now, fetchImpl, maxPages })` per le date;
- `fetchEventsForDate(date, fetchImpl)` per ogni data;
- salvare gli `events` restituiti nell'array `observations`.

L'API restituisce record `EventiMoliseEvent`, non la shape normalized. Non
ricostruire le date, il Delta o l'hash con un secondo algoritmo: `prepareEvent`
e il canonicalizer TypeScript esistenti restano autorevoli.

Usare un wrapper `fetchImpl` di sola lettura che conservi in archivio privato
URL, timestamp, status e risposta originale prima del parsing. Conservare tutte
le pagine discovery e le risposte per data, poi confrontare gli ID con
l'inventario legacy. Non chiamare l'Edge importer per raccogliere questi dati:
ingest potrebbe scrivere e viola il freeze.

La discovery ha un limite di pagine e può interrompersi anche su loop.
Verificare esplicitamente che l'ultima pagina non abbia una pagina successiva
non visitata. Ogni fetch deve riuscire e ogni `invalidCount` deve essere zero.
Una discovery parziale, un errore o un ID non trovato significano
**sconosciuto**, non “evento scomparso”. Per gli eventi storici non più nel feed
futuro, servono prove di disponibilità/assenza specifiche per quell'identità;
non bastano le sole date future.

## 7. Compilare il manifest senza inventare prove

Seguire anche il [README dei tool](README.md). Il manifest contiene:

| Campo                       | Contenuto                                                  |
| --------------------------- | ---------------------------------------------------------- |
| `dataset_kind`              | `production_export`                                        |
| `population_evidence_ref`   | Riferimento all'export completo riconciliato e legato a T0 |
| `submissions`               | Righe integrali del JSON SQL, senza editing del contenuto  |
| `observations`              | Record del provider preparati dall'adapter corrente        |
| `captures`                  | Capture storiche autentiche, per singola submission        |
| `decisions`                 | Una decisione chiusa per ogni strong identity legacy       |
| `mismatch_evidence`         | Spiegazione provata di ogni differenza shadow              |
| `proposal_explanations`     | Identità, hash e prova per ogni pending del dry-run        |
| `never_attempted`           | Normalmente `[]`; eccezioni soltanto con prova positiva    |
| `migration_timestamp`       | Timestamp esplicito con sei cifre di microsecondi          |
| `release_gates`             | Riferimenti ai gate e T0 originali                         |
| `updated_client_probe_refs` | Prove dei percorsi Admin richiesti dal preflight           |

Questo è **uno schema illustrativo incompleto, non un manifest eseguibile**:

```json
{
  "dataset_kind": "production_export",
  "population_evidence_ref": "<prova-reale-export-completo>",
  "submissions": ["<righe-SQL-originali>"],
  "observations": ["<EventiMoliseEvent-dell-adapter>"],
  "captures": ["<capture-storiche-verificate-se-disponibili>"],
  "decisions": ["<decisioni-con-prove-per-ogni-identita>"],
  "mismatch_evidence": ["<spiegazioni-verificate>"],
  "proposal_explanations": ["<identita-hash-prova-per-ogni-pending>"],
  "never_attempted": [],
  "migration_timestamp": "<timestamp-UTC-a-sei-microsecondi>",
  "release_gates": {
    "additive_schema_notifications": "<prova>",
    "compatible_admin_backend": "<prova>",
    "updated_admin_client": "<prova>",
    "legacy_writer_frozen": "<prova>",
    "queued_inflight_drained": "<prova>",
    "writer_quiescent": "<prova>",
    "reviewed_audit_manifest": "<prova>",
    "t0": "<T0-originale>"
  }
}
```

I riferimenti possono essere percorsi/ID dell'archivio privato, ma devono
puntare a prove leggibili, non essere etichette vuote scritte per superare il
validator. Conservare checksum del manifest e revisore/autore della decisione.

### 7.1 Identità e capture

La strong identity v1 è
`{ "provider": "eventimolise", "external_id": "<ID>",
"occurrence_key": null }`.
Non deduplicare per città, nome o giorno.

Le note `Imported from EventiMolise`, `Source event ID` e `Source URL`
identificano la fonte, **non provano cosa conteneva quando fu importata**. Anche
una submission accepted, modificata dal moderatore, non è una capture sorgente.

Una capture valida ha `submission_id`, `identity`,
`origin: "verified_source_capture"`, `evidence_ref` e `normalized` v1 autentico.
Ogni pending legacy deve avere la propria capture verificata. Se non esiste, la
pending è ambigua e blocca il gate; non riempirla con l'osservazione odierna o
con il contenuto moderato. La remediation deve essere esplicita e revisionata.

Due pending per la stessa identità, anche con capture, bloccano il gate. Più
revisioni storiche già gestite non sono invece automaticamente duplicati da
cancellare. L'ordine storico è `handled_at DESC NULLS LAST, id DESC`.

### 7.2 Le sette classificazioni chiuse

| Classificazione                 | Quando è ammessa                                                                                                                           | Watermark previsto                                                   |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| `verified_handled`              | Ultima revisione gestita e snapshot sorgente storico provati; osservazione corrente disponibile                                            | Ultimo snapshot davvero gestito, non necessariamente quello corrente |
| `editorial_baseline`            | Accepted con unico Event, capture ultima non verificabile, differenza editoriale/trasformazione conosciuta spiegata e baseline autorizzata | Corrente, riconosciuto come baseline esplicita                       |
| `remediated_real_drift`         | Drift reale accepted riconciliato, unico Event, remediation e baseline autorizzate                                                         | Corrente solo dopo remediation                                       |
| `rejected_baseline`             | Ultimo esito rejected, fonte corrente disponibile, baseline autorizzata                                                                    | Corrente; il rifiuto storico resta intatto                           |
| `ignored_baseline`              | Come rejected baseline, più autorizzazione a ignorare                                                                                      | Corrente; record ignored                                             |
| `verified_unhandled`            | Nessuna revisione mai gestita, almeno una pending, fonte corrente e prove del never-handled                                                | **Solo qui** proposed è null                                         |
| `verified_no_longer_observable` | Assenza verificata e ultimo snapshot gestito provato                                                                                       | Ultimo snapshot verificato come current e proposed                   |

`retain_legacy` è l'eccezione esplicita di conservazione: assenza verificata,
nessuna capture verificata e nessuna pending. Si conserva la storia senza creare
un record provenance; non è un'ottava baseline e non autorizza proposed null.

Per il dettaglio dei campi usare `RecordDecision` in
`external_event_migration.ts`: `last_handled_submission_id`, `handled_snapshot`,
`availability_evidence_ref`, `baseline_authorization_ref`, `remediation_ref`,
`ignore_authorization_ref`, `never_handled_evidence_ref`, secondo il caso.

Un accepted storico promosso a Place richiede remediation, non una baseline
silenziosa. Se una capture autentica contraddice la baseline, non scegliere la
baseline per comodità. Le differenze shadow richiedono `submission_id`, `kind` e
`evidence_ref`; i kind ammessi sono `source_evolution`,
`editorial_moderation_enrichment`, `known_importer_transformation` e
`unresolved`. `unresolved` non supera il gate.

### 7.3 Immagini e proposte

`never_attempted` resta vuoto se non c'è una prova positiva che l'import
immagine non sia mai stato tentato. Zero assets non è quella prova: upload
fallito, rimozione del moderatore e storia sconosciuta consumano comunque il
budget legacy. Non ripristinare l'eleggibilità dell'immagine per sbloccare
l'audit.

Ogni `proposal_explanations` ha `identity`, `source_hash`, `evidence_ref`. La
prova deve spiegare perché quello stato sorgente è ancora unhandled. Non
inventare gli hash: derivarli con `prepareEvent`/`hashNormalizedExternalEvent`
esistenti, oppure leggerli dalla capture/pending canonica verificata. Il dry-run
richiede esattamente una spiegazione corrispondente all'hash di ciascuna pending
osservata.

## 8. Eseguire audit e pianificazione read-only

```bash
deno run --allow-read supabase/tools/audit_external_events.ts \
  "$private_manifest" > "$private_attempt_dir/audit.json"
deno run --allow-read supabase/tools/migrate_external_events.ts \
  "$private_manifest" --plan > "$private_attempt_dir/plan-report.json"
```

Controllare exit code di **entrambi** i comandi; non sostituirlo con l'exit code
del successivo `cat` o `tee`. `--plan` non usa il database né richiede l'UUID
tecnico di ingest. Il report deve avere `execution: "EXPORTED_DATA_ONLY"`,
`exported_data_gates_pass: true`, `classification_error: null` e tutti i
conteggi di errori/ambiguità/conflitti/differenze non spiegate a zero.

Il solo numero `classified_records` non prova la copertura: conta i **record
provenance pianificati**, non le righe storiche, ed esclude `retain_legacy`.
Riconciliare tutte le righe esportate → tutte le identità → una decisione per
identità → piano oppure conservazione legacy esplicita. Le identità con più
revisioni hanno più righe ma una sola decisione.

Ogni null watermark deve corrispondere esattamente a `verified_unhandled` con le
relative prove. Nessuna percentuale di mismatch accettabile sostituisce gli
zeri.

## 9. Eseguire il dry-run delle vere RPC

Questo passaggio richiede connessione privilegiata production, schema/RPC già
distribuiti, freeze e manifest revisionato. Fa scritture **dentro una
transazione poi rollbackata**, prende lock reali e non è una semplice
simulazione JSON. Eseguirlo nella finestra autorizzata, con il writer ancora
ritirato.

Prima di invocarlo, verificare manualmente che la data Europe/Rome sia ancora
quella del T0 originale. Il controllo data automatico del tool protegge
`--apply`; non affidarsi a quel controllo per rendere valido un dry-run eseguito
in una finestra scaduta.

Caricare privatamente `MIGRATION_DB_URL` e `EXTERNAL_EVENTS_IMPORTER_USER_ID`.
L'UUID di ingest proviene dall'env: un campo manifest `importer_user_id` è
rifiutato. Non stampare questi valori.

```bash
deno run --allow-read --allow-env --allow-net \
  supabase/tools/migrate_external_events.ts "$private_manifest" --dry-run \
  > "$private_attempt_dir/dry-run-report.json"
```

Esito richiesto: exit 0 e:

```text
execution = TRANSACTIONAL_DRY_RUN_ROLLED_BACK
production_cutover = NOT_EXECUTED
gate_report.production_contract_dry_run = ROLLED_BACK_VERIFIED
```

Il comando verifica il backfill e chiama le vere primitive di ingest per le
osservazioni: ogni pending risultante deve avere la spiegazione esatta e non può
coincidere con la versione già gestita. `unexplained_dry_run_proposal` blocca
tutto; non modificare il validator per accettarla.

Conservare report, exit code, timestamp, hash manifest, versione release e prove
delle proposte. Verificare dopo il comando che non siano rimaste modifiche del
dry-run. Un errore non va annotato come “rollback verificato”: correggere la
causa e ripetere entro la stessa finestra valida.

## 10. Compilare il rapporto e chiudere 9.10

Usare `external_event_cutover_report.template.json` come inventario di evidenze,
conservando la copia compilata nell'archivio privato. Riportare:

1. progetto, release/versioni, T0 originale e data di Roma;
2. ref backup, copertura e limiti del recupero;
3. popolazione completa, conteggi righe/status/identità, checksum export e
   manifest;
4. zero parse failures, invalid observations, pending ambigue, conflitti
   identità/link e shadow mismatch non spiegati;
5. classificazione totale, incluse le conservazioni legacy esplicite;
6. elenco dei null watermark, tutti e soltanto `verified_unhandled`;
7. risultato reale `ROLLED_BACK_VERIFIED` e zero proposte prive di spiegazione,
   con riferimenti identità/hash/evidenza;
8. prove schema/backend/client, freeze/drain/quiescenza e review finale;
9. autore/revisore, data e decisione di chiusura del gate 9.10.

Il template ha un campo aggregato `production_audit_backfill_cutover`: se si è
fatto soltanto audit/dry-run, **non trasformarlo in “completo”**. Annotare
separatamente audit eseguito e gate 9.10 PASS, lasciando backfill committato,
cut-over, ritiro permanente e attivazione `NOT_EXECUTED`/senza evidence ref
finché non avvengono davvero. Non riempire i relativi riferimenti con quelli del
dry-run.

Checklist per spuntare 9.10:

- [ ] Backup e piano recupero registrati, con limiti reali esplicitati.
- [ ] Admin disponibile prima di qualsiasi pending update production.
- [ ] Freeze, drain e quiescenza production provati; T0 originale registrato.
- [ ] Export completo riconciliato e osservazioni/capture con prove autentiche.
- [ ] Tutte le identità hanno una decisione valida; nessuna pending ambigua.
- [ ] Conflitti identità/link e mismatch senza spiegazione: zero.
- [ ] Null proposed soltanto per `verified_unhandled` provato.
- [ ] Plan PASS e dry-run reale exit 0 / `ROLLED_BACK_VERIFIED`.
- [ ] Ogni proposta spiegata con esatta identità e hash; nessuna soglia
      percentuale.
- [ ] Manifest/report/prove revisionati, checksum e riferimenti salvati
      privatamente.
- [ ] La finestra T0 è ancora valida per proseguire il rollout nello stesso
      giorno Europe/Rome; nessun risultato di tentativo scaduto riciclato.

Solo allora aggiornare il task 9.10 e registrare nell'evidence document il
riferimento al report privato, senza copiarne dati personali o segreti. La
chiusura del gate non autorizza da sola `--apply`, il cut-over o il deployment.

## 11. Se qualcosa va male

### Prima del cut-over

Se scade la data di Roma o manca una prova, fermarsi e lasciare il writer
ritirato. Invalidare il tentativo come input di release e ripartire con nuovo
freeze, quiescenza e T0. Il ripristino del **bundle legacy invariato** è ammesso
soltanto prima del cut-over e dopo review della compatibilità dello stato
persistito. Se il backfill ha già committato, non presumere che riattivare il
legacy sia sicuro.

Il backup iniziale non è un bottone che annulla solo questa feature: un restore
può cancellare submission, moderazioni e utenti creati dopo lo snapshot. Prima
di un restore, scegliere esplicitamente il punto, la perdita di dati
accettabile, la gestione delle scritture successive e la copia degli altri
servizi.

### Dopo il cut-over

Il legacy writer è **permanentemente ritirato**. Anche un restore completo del
DB non autorizza a riaccenderlo. Un backup pre-cut-over può contenere cron e
trigger che lo richiamano: il recupero deve neutralizzarli prima di esporre il
sistema.

Per un problema del nuovo importer: interrompere il nuovo job/route, drain delle
richieste e mantenere schema, provenance, snapshot e claim irreversibili;
riparare solo l'importer compatibile. Non cancellare provenance né azzerare i
claim.

Un disaster recovery più ampio richiede una procedura dedicata e autorizzata,
con servizi isolati, verifica di email/webhook/Cloudinary e riconciliazione
delle scritture successive. Il runbook non definisce un rollback distruttivo del
DB e questa guida non lo inventa.

## Riferimenti operativi

- [Runbook di deployment](external_event_deployment_runbook.md).
- [README strumenti audit/backfill](README.md).
- [Template del rapporto](external_event_cutover_report.template.json).
- [Export SQL canonico della storia](export_external_event_history.sql).
- [Task OpenSpec](../../openspec/changes/add-external-event-provenance-moderation/tasks.md).
- [Supabase: database backups](https://supabase.com/docs/guides/platform/backups).
- [Supabase: backup/restore CLI](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore).
- [Supabase: Vault](https://supabase.com/docs/guides/database/vault).
- [Supabase: restore to a new project](https://supabase.com/docs/guides/platform/clone-project).
