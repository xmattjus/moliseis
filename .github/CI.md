# CI per pull request

Il workflow `pull-request.yml` esegue due job indipendenti per ogni pull request
verso `main` (apertura, aggiornamento dei commit e riapertura), anche senza modifiche
a file Dart. Non effettua build release, deploy o merge e non configura protezioni
del branch: gli eventuali required checks vanno impostati separatamente su GitHub.

## Controlli automatici

- **Flutter analyze incrementale**: esegue `flutter analyze --no-pub` sia sul
  commit base esatto della PR sia sul candidato. Tutti gli errori sono bloccanti;
  warning e info già presenti costituiscono debito visibile, mentre nuove
  diagnostiche fanno fallire il job. Non usa `--no-fatal-warnings` o
  `--no-fatal-infos` e non sopprime diagnostiche.
- **Autonomous Flutter tests**: `flutter test --no-pub --reporter expanded` con
  tutti i file `test/**/*_test.dart`, tranne quelli in `test/integration/`.
  Alla preparazione della CI sono 144 file: unit test, widget test, repository e
  persistenza con store ObjectBox temporanei reali. I nuovi test fuori da
  `test/integration/` vengono inclusi automaticamente. Una selezione vuota fallisce.

I job sono indipendenti: un fallimento del gate analyze non impedisce l'esecuzione
dei test. Nessun `continue-on-error` o esclusione per nome di test fallito.
Gli skip già dichiarati nei test restano visibili nel reporter;
questa CI non li rimuove e non equivale a copertura di quei casi.

Entrambi usano `ubuntu-latest`, `permissions: contents: read`, checkout v6 e
flutter-action v2, Flutter **3.47.5**, canale stable e cache come
`build-release.yml`. Dart è quello incluso in Flutter (3.13.4 nella verifica
locale), senza un'installazione indipendente. Le dipendenze vengono installate con
`flutter pub get --enforce-lockfile`: un lockfile non valido fallisce invece di
risolvere nuove versioni. Java e Xcode del workflow release non servono a questi
controlli. `build-release.yml` rimane invariato.

Il job test imposta `TZ=Europe/Rome`: alcune fixture esistenti costruiscono
`DateTime` locali e li confrontano con istanti/orari della policy Roma. Sul runner
UTC predefinito il primo run ha mostrato sette fallimenti di queste aspettative,
riprodotti localmente con `TZ=UTC`. Il fuso è quindi un prerequisito esplicito
della suite attuale; questa prima CI non verifica la portabilità dei test a fusi
diversi e non cambia la policy applicativa o le aspettative dei test.

### Baseline verificata dell'analyzer

Il finding CodeRabbit sul fallimento delle 291 diagnostiche preesistenti è
corretto. Disabilitare globalmente la fatalità di warning e info consentirebbe
però nuove regressioni: la remediation usa invece uno script Python con sola
libreria standard, `.github/scripts/analyzer_baseline.py`.

La baseline viene ricalcolata da `github.event.pull_request.base.sha`, recuperato
dal remoto in un worktree isolato fuori dal candidato. Entrambi i checkout usano
Flutter 3.47.5/Dart incluso e le proprie dipendenze bloccate installate con
`--enforce-lockfile`. Il candidato è il merge ref della PR, come per i test.
Log completi e SHA di entrambe le revisioni restano visibili; non si mantiene un
file di allowance che una PR possa aggiornare con le proprie nuove diagnostiche.
La base iniziale verificata ha 4 warning e 287 info; non è un tetto numerico.

L'identità di una diagnostica comprende percorso relativo, severità, codice,
messaggio, riga e colonna. Git `diff --no-index --diff-algorithm=patience`
mappa le righe sorgenti invariate dalla base al candidato, usando dichiarazioni
e altre righe uniche come ancore. Il confronto usa un multinsieme delle occorrenze
mappate: una diagnostica nuova non può essere pagata dalla rimozione di un'altra
altrove, anche con codice/messaggio identici e totale invariato. Inserire righe
sopra il debito esistente non genera falsi positivi. Errori anche già presenti
sulla base fanno sempre fallire il controllo; gli errori non hanno allowance.

Lo script interpreta l'exit 1 di `flutter analyze` solo quando il report è
completo, il riepilogo corrisponde alle diagnostiche lette e contiene
esclusivamente warning/info. Crash, report mancante/incompleto, formato inatteso,
SDK diverso, problemi di checkout/pub get e qualsiasi errore analyzer bloccano
il job. I regression test del gate verificano nuovi codici/occorrenze,
cambiamenti di severità, spostamenti di riga, rimozione e aggiunta di una riga
identica in scope diversi, debito rimosso e fallimenti del tool.
Una modifica ai file tracciati `analysis_options.yaml` richiede una revisione
esplicita della policy/baseline e viene bloccata, per evitare di ridurre le regole
implicitamente insieme al codice.

Tradeoff: servono due analisi complete e un secondo pub get. Il parser è
deliberatamente limitato al formato Flutter 3.47.5 e va rivalutato con l'SDK.
Modificare una riga sorgente con debito la rende nuova, scelta conservativa.
La mappatura Git è testuale, non semantica: blocchi di codice identici spostati o
duplicati possono essere allineati come invariate dal diff. Non dimostra l'identità
di un nodo AST e non costituisce una protezione contro modifiche intenzionalmente
ostili alla CI. Cambiamenti al lockfile possono produrre nuove diagnostiche attraverso
le dipendenze e saranno bloccati come le altre; la baseline usa il lockfile della
base, non quello fornito dalla PR. Questo controllo rileva regressioni rispetto
alla base, non impedisce da solo commenti `ignore` o cambiamenti alla CI, che
restano oggetto della review. Non risolve le 291 diagnostiche pregresse.

I test ObjectBox richiedono la libreria nativa anche se non richiedono servizi:
`flutter test` non compila il plugin Linux. Il job scarica l'archivio ufficiale
Linux x64 di ObjectBox C **5.3.2**, coerente con `objectbox` e
`objectbox_flutter_libs` nel lockfile e nel CMake del plugin, verifica il checksum
SHA-256 e ne estrae solo `lib/libobjectbox.so`. Download, checksum o caricamento
falliti fanno fallire il job. Quando si aggiorna ObjectBox vanno rivalutati versione
e checksum del runtime di test. Non è una nuova dipendenza applicativa.

Il checkout contiene già i sorgenti generati Envied, ObjectBox e dart_mappable:
non viene eseguito `build_runner`, non si crea `.env` e non si configurano segreti
di produzione. I test autonomi usano stub HTTP, fake e fixture gestite dal test
(incluso un fake server Cloudinary su loopback), senza backend esterni.

## Test con servizi locali, fuori dalla prima CI

`test/integration/` è riservata ai test con stack locale e viene esclusa
esplicitamente dalla selezione, senza affidarsi agli skip opt-in:

| Test | Prerequisiti |
| --- | --- |
| `external_event_token_pipeline_test.dart` | Stack Supabase locale con schema/migration applicati, API/Auth/PostgreSQL, CLI Supabase e Deno; avvia `run_external_event_token_e2e_fixture.sh` tramite `ExternalEventTokenBridge`. |
| `all_day_pipeline_test.dart` | Stesso stack locale e Deno; avvia `run_all_day_e2e_fixture.sh`; richiede anche il runtime ObjectBox. |

Gli script ricavano endpoint e credenziali dello stack **locale** tramite
`supabase status --output env`. Le fixture creano/modificano dati e utenti: usare
solo un ambiente locale di verifica predisposto, mai credenziali di produzione.
Solo dopo aver predisposto e verificato lo stack si possono eseguire, separatamente:

```bash
MOLISE_EXTERNAL_TOKEN_LOCAL_E2E=1 flutter test test/integration/external_event_token_pipeline_test.dart
MOLISE_ALL_DAY_LOCAL_E2E=1 flutter test test/integration/all_day_pipeline_test.dart
```

Prima di aggiungere test che richiedono servizi, collocarli in `test/integration/`
e aggiornare questa lista; i test autonomi vanno nelle altre directory di `test/`.
Un futuro job per lo stack locale dovrà predisporre esplicitamente servizi,
migration e fixture e lasciare propagare i fallimenti.

Restano fuori anche test SQL/migration/RLS e Deno sotto `supabase/`, test su device
o emulatori, build Android/iOS, signing, verifica dei generatori, coverage e
deploy. Nessuno di questi controlli è dichiarato coperto dalla prima CI.

## Verifica iniziale

La base verificata è `origin/main` al commit
`05b0f9e3432462a2fbf86c84dc4b6f80e0ed4ab9`. La PR documenta gli esiti delle
verifiche locali e GitHub Actions. Il debito analyzer è confrontato esplicitamente;
i fallimenti dei test restano bloccanti. La correzione della sincronizzazione dei
test AppLogger/Sentry viene proposta in una PR separata: il job test della PR CI
resta rosso finché quella correzione non è inclusa nel candidato. Nessun test viene
escluso o modificato dal workflow per ottenere un risultato verde.

Riferimenti: [sintassi GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax),
[Flutter action](https://github.com/subosito/flutter-action),
[runtime ufficiale ObjectBox C 5.3.2](https://github.com/objectbox/objectbox-c/releases/tag/v5.3.2).
