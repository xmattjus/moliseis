# CI per pull request

Il workflow `pull-request.yml` esegue due job indipendenti per ogni pull request
verso `main` (apertura, aggiornamento dei commit e riapertura), anche senza modifiche
a file Dart. Non effettua build release, deploy o merge e non configura protezioni
del branch: gli eventuali required checks vanno impostati separatamente su GitHub.

## Controlli automatici

- **Flutter analyze**: `flutter analyze --no-pub` sull'intero progetto, con le
  opzioni già presenti in `analysis_options.yaml`. Errori, warning e info conservano
  il comportamento di fallimento predefinito; nessuna diagnostica viene soppressa.
- **Autonomous Flutter tests**: `flutter test --no-pub --reporter expanded` con
  tutti i file `test/**/*_test.dart`, tranne quelli in `test/integration/`.
  Alla preparazione della CI sono 144 file: unit test, widget test, repository e
  persistenza con store ObjectBox temporanei reali. I nuovi test fuori da
  `test/integration/` vengono inclusi automaticamente. Una selezione vuota fallisce.

I job sono indipendenti: un fallimento di analyze non impedisce l'esecuzione dei
test. Nessun `continue-on-error`, esclusione per nome di test fallito o neutralizzazione
degli exit code. Gli skip già dichiarati nei test restano visibili nel reporter;
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
verifiche locali e del primo run GitHub Actions. Un fallimento preesistente resta
un fallimento: questa modifica introduce la CI, senza correggere codice,
dipendenze o migration e senza rendere artificialmente verdi i controlli.

Riferimenti: [sintassi GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax),
[Flutter action](https://github.com/subosito/flutter-action),
[runtime ufficiale ObjectBox C 5.3.2](https://github.com/objectbox/objectbox-c/releases/tag/v5.3.2).
