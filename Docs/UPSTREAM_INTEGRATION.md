# Integración de upstream — 21 de octubre de 2026

Brou conserva su identidad, la licencia MIT, los autores y las rutas de datos de Search. Las PR propias #11–#14 están integradas en `main`. Esta actualización selecciona correcciones concretas del original, sin incorporar sus nuevas funciones de producto.

Referencia revisada: `upstream/main` en `b81932c44da6ef186e8771d68affa166d03325de`. Cada commit incorporado con `git cherry-pick -x` conserva su autor y la referencia de origen. Las adaptaciones de conflictos mantienen el filtro de contraseñas por host, las referencias persistentes del llavero y las pruebas propias de formularios y descargas.

| Origen en driceroland/Search | Cambio incorporado |
| --- | --- |
| [c9f283b](https://github.com/driceroland/Search/commit/c9f283b) | Un marcador no sustituye una pestaña fijada ni una página abierta; reutiliza el inicio vacío y permite abrir detrás con ⌘. |
| [2e2d4f2](https://github.com/driceroland/Search/commit/2e2d4f2) | Nombres como `10.io` usan HTTPS; solo cuatro octetos válidos cuentan como IPv4 privada. |
| [4cbeaa7](https://github.com/driceroland/Search/commit/4cbeaa7) | Al cambiar entre builds con y sin permiso de passkeys, la preferencia se adapta a la capacidad real. |
| [73e50a7](https://github.com/driceroland/Search/commit/73e50a7) | La prueba de archivos omite su segunda parte si WebKit rechaza por sí mismo el permiso `file:`. No se cambia la protección de producción. |
| [1b3edc5](https://github.com/driceroland/Search/commit/1b3edc5) | El bloqueador respeta el límite del dominio; no bloquea nombres parecidos. |
| [aee74ba](https://github.com/driceroland/Search/commit/aee74ba) | Las sugerencias consultan atributos; el secreto se lee solo para la cuenta elegida. Se conserva la separación HTTP/HTTPS y la migración del llavero. |
| [4be2fd3](https://github.com/driceroland/Search/commit/4be2fd3) | No se ofrecen cuentas en búsquedas, títulos y códigos, incluidos nombres accesibles y placeholders. Se mantienen los casos propios de destinatarios de correo. |
| [5fc1c06](https://github.com/driceroland/Search/commit/5fc1c06) | Una clave de seguridad puede devolver una aserción sin `userHandle`, sin provocar un cierre. |
| [0b769a3](https://github.com/driceroland/Search/commit/0b769a3) | Ventanas de acceso asíncronas GET/POST tras interacción real: una ventana, cinco segundos, ligada a pestaña y origen; se revoca al navegar. |
| [f14347a](https://github.com/driceroland/Search/commit/f14347a) | El adaptador de extensiones excluye tipos webRequest que WebKit no admite y que impedían arrancar AdBlock. |
| [21143e8](https://github.com/driceroland/Search/commit/21143e8) | El host nativo termina después de drenar su salida, con límites de mensaje y de cierre. |
| [b02bec7](https://github.com/driceroland/Search/commit/b02bec7) | Un clic con ⌘ o botón central no abre dos pestañas cuando la página también llama a window.open. |
| [152e1c9](https://github.com/driceroland/Search/commit/152e1c9) | Los enlaces de un marco con origen opaco pueden usar su propio gesto, sin aprovechar el de otra página. |
| [b2d8314](https://github.com/driceroland/Search/commit/b2d8314) | Dependencia de la protección de importaciones: descubre perfiles solo de extensiones e indica los navegadores cuya clave de contraseñas no es compatible. |
| [ca55c12](https://github.com/driceroland/Search/commit/ca55c12) | Importaciones limitadas a la raíz elegida, archivos regulares y 64 MB de JSON; rechaza enlaces de WAL/SHM y distingue permisos denegados. La carpeta elegida se guarda solo en memoria. |

La corrección de las pruebas de descargas [bc6af1f](https://github.com/driceroland/Search/commit/bc6af1f) ya estaba aplicada de forma equivalente: delegado conectado en el callback, transferencia retenida y casos WebKit aislados. Brou conserva sus diez casos, incluidos los de reanudación adicionales; no se duplica el commit.

La adaptación del envío de credenciales conserva una diferencia importante de Brou: si un usuario tiene entradas HTTP y HTTPS con secretos distintos, se busca el secreto enviado solo entre sus propias entradas, empezando por el esquema actual. Se actualiza la referencia que corresponde sin sobrescribir la otra. Mostrar sugerencias no lee secretos. `Tests/cloud_keychain.py` comprueba esta regresión.

El flujo de autenticación silenciosa de extensiones de upstream y sus correcciones posteriores no aplican al código actual: Brou todavía no incorpora ese flujo. Tampoco se añaden sugerencias remotas, nuevas opciones de pestañas o cambios de interfaz ajenos al alcance.

El `CHANGELOG.md` conserva la historia de las releases del original. Las notas de Brou están en `NOTES.md`; seleccionar estos commits no convierte Brou en una release nueva del original ni implica estar al día con todos sus cambios.

## Repetir las comprobaciones

En macOS, desde la raíz del repositorio:

```sh
python3 Tests/run-ci-tests.py
Tests/AddressRegression/run.sh
node Tests/popup_gesture_script.js
./build.sh release
python3 Tests/bookmark_new_tab.py
python3 Tests/start_bookmarks.py
python3 Tests/popups.py
python3 Tests/one_click_one_tab.py
python3 Tests/identifier_first.py
```

Los probes usan mundos aislados y páginas locales. Ejecutarlos de uno en uno. Las pruebas de llavero `Tests/passwords_site.py` y `Tests/cloud_keychain.py` requieren un build firmado con acceso al grupo de prueba; usan cuentas sintéticas locales, sin sincronizarlas. No ejecutar `LEGACY=1` sin prever la intervención de la persona ante el diálogo del llavero. No incluir perfiles ni claves en el repositorio.

## Resultado y límites

La suite Swift completa ejecuta 122 casos: 121 pasan y uno se omite en macOS 27 por el requisito previo de WebKit descrito arriba. Los diez casos de descargas se ejecutan en procesos separados y pasan sin reintentos. La prueba independiente de direcciones y la del listener de gestos también pasan.

Los recorridos del build Release firmado 1.1.0 (202610211441), ejecutados de uno en uno, también pasan:

| Prueba aislada | Resultado |
| --- | --- |
| `passwords_site.py` | 23 pasan |
| `cloud_keychain.py` | 17 pasan |
| `identifier_first.py` | 26 pasan |
| `popups.py` | 10 pasan |
| `one_click_one_tab.py` | 17 pasan |
| `bookmark_new_tab.py` | 3 pasan |
| `start_bookmarks.py` | 12 pasan |

La compilación Release de desarrollo no es una descarga notarizada. Las pruebas locales de llavero no acreditan sincronización real Mac–iPhone ni conflictos de iCloud. No se han cambiado entitlements, identificadores, contenedores ni el entorno Development. No se ha verificado todavía el menú contextual de ventanas después de mantenerlo abierto más de cinco segundos, ni el funcionamiento con una clave física o con cada extensión real. Los tests cubren las regresiones de código, no esas combinaciones completas.

## Próximas actualizaciones

Mantener `upstream` como remoto de lectura. Revisar las releases para actualizaciones amplias y seleccionar correcciones urgentes en ramas separadas, con referencia al origen, conflictos documentados y pruebas afectadas. No hacer merge indiscriminado de nuevas funciones. Volver a comprobar datos persistentes, credenciales, sesiones y descargas antes de distribuir.

## Later device verification

The basic physical Mac/iPhone journeys were subsequently checked on 21 October 2026; see [VERIFICATION.md](VERIFICATION.md). Earlier statements above about untested cross-device sync describe the integration stage. Offline/conflict/account-switch coverage remains pending.
