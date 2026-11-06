puedes darme un promp completo para generar con antoigravity widgets para macos 27.2 Quiero que me muestren El calendario, la fecha y temperatura actual, datos de red, datos de carga del procesador, datos de bateria, memoria libre y ocupada y disco libre y ocupado. Debe parecerse a aplicaciones de mac del mismo estilo como usage y otras del mismo estilo que permitan monitorizar el ordenador macos.


-----------


¡¡Buena idea! He ampliado el prompt incorporando lo que de verdad marca la diferencia en el uso diario: alertas inteligentes, procesos que consumen recursos (con acción de cerrarlos), GPU y ventiladores, HUD flotante, cuotas de red mensuales, unión rápida a reuniones desde el calendario, histórico con exportación y modos de ahorro de batería. Aquí tienes el **prompt v2 completo** (sustituye al anterior):

````markdown
# TAREA: App nativa de monitorización para macOS 27.2 estilo "Usage" (barra de menús + widgets)

Actúa como desarrollador senior macOS experto en Swift 6 y SwiftUI. Construye una aplicación
nativa completa llamada **"Pulse Monitor"** para macOS 27.2, inspirada en Usage, iStat Menus y
Stats: barra de menús con panel desplegable + widgets de escritorio nativos. La app debe ser útil
en el día a día (alertas, acciones rápidas, histórico), no solo un panel pasivo de datos.
Trabaja por fases y verifica que compila al final de cada una antes de continuar.

## 1. Stack técnico (obligatorio)
- Xcode 26+, Swift 6.2, SwiftUI, deployment target macOS 26.0 (compilado y probado en 27.2).
- App de barra de menús: `MenuBarExtra` + `LSUIElement = YES` (sin icono en el Dock).
- Target de extensión WidgetKit (widgets interactivos de macOS 26+, con App Intents).
- Swift Charts para gráficas; SwiftData para el histórico local; UserNotifications para alertas;
  CoreWLAN para datos Wi-Fi; App Intents + Shortcuts para automatización.
- SIN dependencias de terceros (solo URLSession para la API del clima Open-Meteo).

## 2. Arquitectura
- MVVM + Swift Concurrency (`async/await`, `@MainActor`). Muestreo en hilo de fondo con QoS
  `.utility` (nunca bloquear la UI).
- `SystemMonitor: ObservableObject` singleton con `DispatchSourceTimer` (2 s por defecto) y
  buffers circulares (60 puntos) para sparklines.
- Motores de datos, cada uno con su API correcta:
  - **CPU**: `host_processor_info()` → total %, por núcleo y separación **núcleos P (rendimiento)
    vs E (eficiencia)** en Apple Silicon.
  - **GPU**: uso y frecuencia vía **IOReport** (mismo enfoque que Stats/iStat Menus).
  - **Memoria**: `host_statistics64()` + `sysctl("hw.memsize")` → usada, libre, comprimida, swap,
    presión (`memory_pressure`).
  - **Disco**: `URL.resourceValues(.volumeAvailableCapacityForImportantUsageKey)` y `statfs()`
    por volumen; **E/S de disco** (lectura/escritura MB/s e IOPS) vía IOKit/DiskArbitration.
  - **Red**: `sysctl(CTL_NET, NET_RT_IFLIST2)` con `if_data64` → subida/bajada en bytes/s (delta),
    acumulado diario y **acumulado mensual por interfaz** (Wi-Fi/Ethernet) para cuotas de datos.
  - **Batería**: `IOPSCopyPowerSourcesInfo()` → %, estado, tiempo restante; ciclos y salud vía
    SMC; **consumo instantáneo en vatios** vía SMC (key "PSTR") y estado de carga.
  - **Temperatura y ventiladores**: SMC vía IOKit ("AppleSMC": "TC0P"/"TC0H" para CPU,
    "F0Ac"…"F2Ac" para RPM de ventiladores) SIN APIs privadas; estado térmico con
    `ProcessInfo.processInfo.thermalState`.
  - **Sistema**: uptime (`ProcessInfo.systemUptime`), load average (`sysctl vm.loadavg`),
    identificación del equipo (chip, modelo, RAM total, versión macOS).
  - **Top procesos**: `libproc` (`proc_listallpids` + `proc_pidinfo`) → top 5–10 apps por CPU y
    por RAM, refrescado cada 5 s.
  - **Wi-Fi**: CoreWLAN → SSID, banda, canal, intensidad de señal (con manejo del permiso de
    ubicación y fallback si se deniega).
- Los widgets NO muestrean el sistema: la app escribe un snapshot JSON en un **App Group**
  (contenedor compartido) y el `TimelineProvider` del widget lo lee; la app llama
  `WidgetCenter.shared.reloadAllTimelines()` en cambios significativos.
- `AlertEngine`: evalúa umbrales sobre las métricas y dispara notificaciones con anti-rebote
  (no repetir la misma alerta antes de X minutos).
- `HistoryStore` (SwiftData): detalle de los últimos 24 h + agregados diarios 30 días, escritura
  por lotes para no penalizar SSD ni batería.

## 3. Widgets (10)
1. **Calendario/Fecha**: fecha destacada, mini-mes, próximos eventos (EventKit con permiso;
   fallback elegante si se deniega).
2. **Clima**: temperatura actual, icono SF Symbol, sensación térmica, pronóstico 3–6 h y viento
   (Open-Meteo, sin API key, caché 15 min, ubicación configurable, valores por defecto si no hay red).
3. **Red**: subida/bajada en vivo con formato humano, gráfica de área, total del día e IP local.
4. **CPU**: % actual grande, sparkline, desglose P/E por núcleo y temperatura.
5. **Batería**: %, estado, tiempo restante, vatios de consumo/carga, ciclos, color dinámico
   verde/ámbar/rojo.
6. **Memoria**: barra apilada usada/libre/comprimida/swap, cifras GB, gráfica de presión.
7. **Disco**: barra usada/libre por volumen con alerta de color a 80 %/90 %.
8. **Resumen del sistema** (medium/large): cuadrícula compacta con CPU, RAM, disco, red y batería
   a la vez — el widget "chulo" principal, estilo Usage.
9. **Top apps**: lista de las 5 apps que más CPU/RAM consumen ahora mismo.
10. **Térmica/Ventiladores**: temperatura del SoC, presión térmica y RPM por ventilador.

## 4. Diseño visual (estilo macOS 26/27 "Liquid Glass")
- Materiales translúcidos `.ultraThinMaterial`, esquinas 16–20 pt, vibrancy, respeto a
  "Reduce transparency" y modo claro/oscuro.
- SF Pro para etiquetas; `monospacedDigit()` en todas las cifras; SF Symbols consistentes.
- Paleta fija por métrica: CPU azul, GPU violeta, Memoria morado, Disco naranja, Red verde,
  Batería dinámica, Térmica rojo/ámbar/verde. Acentos suaves, nunca saturados.
- Layout tipo Usage: filas `[icono SF Symbol] [etiqueta] [valor] [sparkline]`; en widgets,
  jerarquía dato grande arriba + gráfica abajo, 3 tamaños (small/medium/large).
- Localización: **español por defecto**, inglés incluido (`String Catalogs`).

## 5. Panel de barra de menús (dropdown)
- Cabecera "Equipo": chip, RAM total, macOS, uptime y load average.
- Navegación lateral por secciones (CPU, GPU, Memoria, Disco, Red, Batería, Térmica, Clima,
  Calendario, Procesos) con Swift Charts grandes y datos detallados.
- **Sección Procesos con acción**: lista top procesos con % CPU / RAM, campo de búsqueda y botón
  "Salir" (con confirmación) vía `NSRunningApplication.terminate`.
- **Acciones rápidas**: copiar IP local/externa, copiar SSID, abrir Monitor de Actividad,
  unirse a la próxima reunión (detecta URLs de Meet/Zoom/Teams en los eventos de EventKit y
  muestra botón "Unirse en 10 min").
- Atajo de teclado global (⌥⌘M por defecto, reasignable) para abrir/cerrar el panel.

## 6. Funciones de día a día (imprescindibles)
- **Alertas configurables** (UserNotifications): CPU > X % durante N min, memoria con presión
  crítica, disco > 90 %, batería < 20 % / 10 %, temperatura del SoC alta, cuota mensual de red
  al 80 %/100 %, ventilador por encima de RPM fijadas. Anti-rebote y modo silencio temporal.
- **Cuotas de red mensuales**: definir límite GB por mes (útil con datos móviles/VPN) con widget
  de progreso y alerta.
- **HUD flotante opcional** (`NSPanel` always-on-top, no activable): mini-panel con CPU/RAM/Red
  siempre visible tipo iStat Menus.
- **Modo eficiente**: si está en batería con Modo de Bajo Consumo
  (`ProcessInfo.isLowPowerModeEnabled`) o presión térmica alta → aumentar el intervalo de
  muestreo automáticamente y pausar gráficas no visibles.
- **Histórico y estadísticas**: gráficas 1 h / 24 h / 7 días / 30 días; exportación CSV/JSON.
- **Automatización**: App Intents ("pausar monitorización", "informe de estado", "obtener % de
  batería"…) para Shortcuts y widgets interactivos (p. ej. botón de pausa dentro del widget).
- **Onboarding de permisos** en 1 pantalla: Calendario, Ubicación (para Wi-Fi) con explicación
  de por qué y funcionamiento degradado si se rechazan.

## 7. Privacidad y rendimiento
- 100 % local: sin telemetría, sin análisis, única petición de red es Open-Meteo y detección de
  IP externa (configurables).
- App en reposo: < 2 % CPU, < 80 MB RAM; escrituras de histórico por lotes; cero fugas de memoria
  (revisar con Instruments en F7).

## 8. Fases de trabajo (en orden, compilando al final de cada una)
- **F1**: Proyecto + targets (app, widget extension) + App Group + menú bar funcional.
- **F2**: Motores CPU (con P/E), Memoria y Disco + E/S, con tests unitarios.
- **F3**: Red (+ acumulados diarios/mensuales), Batería (+ vatios), GPU, Térmica/Ventiladores,
  uptime/load, Top procesos.
- **F4**: Dropdown completo con Swift Charts y diseño Liquid Glass + Procesos con acciones.
- **F5**: Widgets leyendo del App Group (los 10), interactivos donde aplique.
- **F6**: Clima, Calendario y unión a reuniones; Wi-Fi con CoreWLAN.
- **F7**: AlertEngine + notificaciones + cuotas; HUD flotante; histórico SwiftData + export.
- **F8**: Ajustes completos (muestreo, unidades, umbrales, atajo global, autoarranque con
  `SMAppService`), onboarding, localización ES/EN, icono de app, pulido claro/oscuro,
  revisión con Instruments.

## 9. Criterios de aceptación
- Compila sin errores ni warnings en Xcode 26+ para macOS 27.2.
- < 2 % CPU y < 80 MB RAM en reposo; widgets dentro del presupuesto de WidgetKit leyendo el
  snapshot compartido, nunca muestreando por su cuenta.
- Formateos de bytes/GB/tiempo localizados y coherentes; ninguna feature crashea con permisos
  denegados, sin red o sin sensores SMC disponibles (degradación elegante siempre).
- Tras el onboarding, el usuario ve datos reales en la barra de menús en menos de 5 segundos.
````

**Resumen de lo añadido respecto a la v1:**

1. **Monitorización real diaria**: GPU, ventiladores, vatios de consumo, térmica, E/S de disco, núcleos P/E, top procesos con botón para cerrarlos.
2. **Proactividad**: alertas con notificaciones, cuota mensual de red, modo eficiente en batería.
3. **Acciones rápidas**: unirse a reuniones desde el calendario, copiar IP, atajo global, HUD flotante.
4. **Memoria a largo plazo**: histórico 30 días con exportación CSV y widgets interactivos de macOS 26+.

¿Te lo guardo también como archivo `.md` para que lo tengas siempre a mano, o quieres que ajuste alguna sección (por ejemplo, quitar funciones para hacerlo más ligero)?