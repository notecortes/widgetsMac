# Manual de Instalación y Funcionamiento de Pulse Monitor

**Pulse Monitor** es una aplicación nativa de monitorización de hardware y sistema para **macOS 27.2 / 26+**, inspirada en herramientas de referencia como *Usage*, *iStat Menus* y *Stats*. Combina un panel desplegable translúcido en la barra de menús (*Liquid Glass*), un HUD flotante always-on-top y 10 widgets interactivos de escritorio basados en **WidgetKit** y **App Intents**.

---

## 📋 1. Requisitos del Sistema

- **Sistema Operativo**: macOS Sonoma 14.0 o superior (optimizado, probado y verificado en **macOS 27.2** con Apple Silicon).
- **Arquitectura**: Compatible con procesadores Apple Silicon (M1, M2, M3, M4 y familias Pro/Max/Ultra) y arquitectura Intel x86_64.
- **Herramientas de compilación**: Swift 6+ / Apple Swift Command Line Tools o Xcode 15+.
- **Dependencias**: **0 dependencias externas** (no requiere CocoaPods ni dependencias de terceros; solo frameworks nativos de Apple y URLSession para el servicio meteorológico público de Open-Meteo).

---

## 🛠️ 2. Guía de Instalación en macOS

### Paso 1: Clonar o situarse en el directorio del proyecto
Abre el Terminal y sitúate en la raíz del proyecto:
```bash
cd /ruta/hacia/widgetsMac
```

### Paso 2: Compilación y empaquetado del bundle `.app`
El proyecto incluye un script de compilación y empaquetado que genera la aplicación `.app` completa y le incrusta la extensión de widgets:

```bash
# Dar permisos de ejecución al script si es necesario
chmod +x Scripts/build_app.sh

# Compilar en modo Release y crear el bundle de la aplicación
./Scripts/build_app.sh
```

El script realiza automáticamente las siguientes acciones:
1. Compila la librería del núcleo (`PulseCore`), el binario de la aplicación (`PulseMonitor`) y la extensión de widgets (`PulseWidgets`).
2. Crea la estructura estándar del bundle en `build/PulseMonitor.app`.
3. Integra el archivo `Info.plist` con `LSUIElement = YES` (para que la app viva exclusivamente en la barra de menús sin saturar el Dock).
4. Inserta la extensión de widgets en `Contents/PlugIns/PulseWidgets.appex`.
5. Integra las traducciones en español e inglés (`es.lproj`, `en.lproj`).
6. Aplica una firma ad-hoc (`codesign`) para permitir la ejecución inmediata en tu Mac.

### Paso 3: Mover la aplicación a la carpeta Aplicaciones
Para que macOS reconozca automáticamente los widgets en el selector de widgets del escritorio y para poder configurar el inicio automático:

```bash
# Copiar la aplicación a la carpeta de Aplicaciones del usuario o del sistema
cp -R build/PulseMonitor.app /Applications/
```

### Paso 4: Primer inicio y configuración de permisos
Ejecuta la app con el comando:
```bash
open /Applications/PulseMonitor.app
```
O haz doble clic sobre **Pulse Monitor** en tu carpeta de `/Applications`.

Al arrancar, aparecerá la pantalla de **Bienvenida y Permisos**:
- **Calendario**: Permite detectar las próximas reuniones (Google Meet, Zoom, Microsoft Teams) y habilitar el botón de "Unirse a la Reunión" en 1 clic.
- **Ubicación / Wi-Fi**: macOS requiere autorización de localización para mostrar el nombre de la red Wi-Fi (SSID) y el canal. Si se deniega, la app continúa funcionando normalmente mostrando velocidad y consumo sin el nombre de la red.
- **Notificaciones**: Para recibir alertas si el procesador supera el umbral, si la memoria entra en presión crítica o si la batería baja del límite configurado.

### Paso 5: Inicio automático al arrancar el Mac (Opcional)
1. Pulsa en el icono de Pulse Monitor en la barra de menús (`waveform.path.ecg`).
2. Haz clic en el icono del engranaje (**Ajustes**).
3. Activa la opción **"Iniciar al arrancar el Mac"** (gestiona el registro nativo mediante `SMAppService`).

---

## ⚙️ 3. Cómo Funciona Pulse Monitor

### A. Muestreo Eficiente y en Segundo Plano (Background QoS)
Pulse Monitor está diseñado bajo el patrón **MVVM** con **Swift Concurrency**:
- Un temporizador ligero (`DispatchSourceTimer`) muestrea el sistema cada **2 segundos** (configurable a 1s o 5s).
- Todo el cálculo pesado y lectura de hardware se ejecuta en una cola dedicada con calidad de servicio `.utility` (`DispatchQueue(label: "com.pulse.sampling", qos: .utility)`), evitando cualquier tipo de bloqueo en la interfaz de usuario.
- **Consumo mínimo**: La app consume menos del **2% de CPU** y menos de **80 MB de memoria RAM** en reposo.

### B. Modo Eficiente Adaptativo (Ahorro de Batería)
Pulse Monitor escucha los eventos del sistema operativo:
- Si el Mac pasa a batería y se activa el **Modo de Bajo Consumo** (`ProcessInfo.isLowPowerModeEnabled`), o el estado térmico pasa a nivel serio/crítico, la app incrementa automáticamente el intervalo de muestreo a **5 segundos** y suspende temporizadores secundarios.

### C. Motores de Hardware Nativos

| Métrica | API Utilizada | Funcionamiento |
|---|---|---|
| **CPU** | Mach `host_processor_info()` | Calcula el delta de ticks (user, system, idle, nice). Consulta `hw.perflevel0.logicalcpu` y `hw.perflevel1.logicalcpu` para separar **núcleos de Rendimiento (P-Cores)** y **núcleos de Eficiencia (E-Cores)** en chips Apple Silicon. |
| **GPU** | IOKit `IOAccelerator` | Lee `PerformanceStatistics` del acelerador gráfico (`Device Utilization %`, frecuencia en MHz y memoria asignada). |
| **Memoria** | `host_statistics64()` + `hw.memsize` + `vm.swapusage` | Desglose estándar de macOS: Memoria de Aplicaciones (Activa), Memoria Alámbrica (Wired), Comprimida, Swap ocupado y nivel de presión (`kern.memorystatus_vm_pressure_level`). |
| **Disco** | `URL.resourceValues` + IOKit `IOBlockStorageDriver` | Lee espacio libre/usado por volumen montado y calcula la velocidad en tiempo real de lectura/escritura (MB/s) y operaciones por segundo (**IOPS**). |
| **Red** | sysctl `CTL_NET, NET_RT_IFLIST2` | Captura la estructura `if_data64` para medir la velocidad viva de subida y bajada, almacena el acumulado diario y el **acumulado mensual para control de cuotas**. Detecta la IP local vía `getifaddrs()`. |
| **Batería** | `IOPSCopyPowerSourcesInfo` + `AppleSmartBattery` | Muestra porcentaje, si está cargando o en adaptador CA, tiempo restante, ciclos de carga, salud porcentual (`AppleRawMaxCapacity / DesignCapacity`) y **potencia instantánea en Vatios (W)**. |
| **Térmica / Ventiladores** | IOKit `AppleSMC` + `ProcessInfo.thermalState` | Lee sensores de temperatura de SoC/CPU y velocidad real de ventiladores en RPM (`F0Ac`, `F1Ac`...), con soporte para refrigeración pasiva en modelos como MacBook Air. |
| **Top Procesos** | `libproc` (`proc_listallpids`, `proc_pidinfo`) | Muestrea las aplicaciones que más CPU y RAM consumen cada 4-5 segundos, permitiendo su cierre selectivo. |
| **Clima** | URLSession + Open-Meteo API | Pronóstico horario y actual con caché en memoria de 15 minutos, sin requerir claves de API. |
| **Calendario** | `EventKit` (`EKEventStore`) | Analiza notas, enlaces y ubicaciones de eventos buscando URLs de Google Meet, Zoom o Microsoft Teams. |

### D. Sincronización con Widgets (App Group)
De acuerdo con las directrices de Apple, los widgets **nunca deben muestrear el hardware por su cuenta** para evitar drenar la batería.
1. La aplicación principal toma las muestras del sistema.
2. Guarda de forma atómica un snapshot serializado en JSON (`pulse_snapshot.json`) en el contenedor compartido (`group.com.pulse.monitor` con fallback automático a `Application Support/PulseMonitor/`).
3. Notifica a WidgetKit mediante `WidgetCenter.shared.reloadAllTimelines()`.
4. El `TimelineProvider` del widget lee el snapshot instantáneamente desde disco.

---

## 🖥️ 4. Uso del Panel y Funciones del Día a Día

### 1. Barra de Menús
En la barra superior de macOS verás el icono del monitor cardíaco (`waveform.path.ecg`) junto con el **porcentaje de uso de CPU actual** con tipografía monoespaciada para evitar saltos visuales.

### 2. Panel Desplegable (Dropdown)
Haz clic en el icono para abrir el panel principal:
- **Cabecera del Equipo**: Muestra el procesador exacto (ej. *Apple M1 Max*), modelo del Mac, memoria total instalada, versión de macOS, tiempo de actividad (*uptime*) y carga media del sistema (*load average*).
- **Acciones Rápidas en 1 Clic**:
  - **Copiar IP**: Copia tu dirección IPv4 local inmediatamente.
  - **Copiar SSID**: Copia el nombre de tu red Wi-Fi actual.
  - **Monitor de Actividad**: Abre la utilidad nativa de macOS.
  - **Reunión**: Si tienes una videollamada en los próximos minutos, aparece un botón directo para entrar a Google Meet, Zoom o Teams.
- **Navegación por Pestañas**:
  - `Resumen`: Vista general estilo **Usage** con filas `[Icono] [Etiqueta] [Valor] [Sparkline]`.
  - `CPU`: Desglose detallado de núcleos P y núcleos E, porcentajes individuales y gráfica Swift Charts de los últimos 60 segundos.
  - `GPU`: Porcentaje de carga gráfica y frecuencia.
  - `Memoria`: Gráfica apilada (Apps, Wired, Comprimida, Libre) y swap.
  - `Disco`: Barras de volúmenes con advertencia de color naranja (80%) y roja (90%), más velocidad de E/S e IOPS.
  - `Red`: Velocidad viva de subida y bajada, total consumido hoy, acumulado mensual y barra de progreso de cuota.
  - `Batería`: Salud, ciclos, vatios consumidos y tiempo restante.
  - `Térmica`: Temperatura del SoC y revoluciones por minuto (RPM) de ventiladores.
  - `Clima`: Tarjetas de predicción de las próximas 6 horas y viento.
  - `Calendario`: Próximos eventos y botón para unirse.
  - `Procesos`: Monitor interactivo de apps con buscador en tiempo real, filtro por CPU o RAM y botón para **Forzar Salida** con ventana de confirmación.

### 3. HUD Flotante (Always-on-top)
- Pulsa el atajo global **`⌥⌘M`** (*Option + Command + M*) en cualquier momento para mostrar u ocultar una mini-ventana flotante translúcida.
- Es un panel no intrusivo (`NSPanel` utility) que flota sobre todas las ventanas, se puede arrastrar a cualquier esquina de la pantalla y muestra CPU, RAM y Red en tiempo real.

### 4. Ventana de Ajustes y Alertas Inteligentes
- Puedes abrir la ventana de Ajustes pulsando el icono del engranaje (`⚙️`) en la cabecera del panel o mediante el atajo **`⌘,`** (*Command + Comma*) cuando Pulse Monitor esté activo.
- Se abre como ventana independiente con pestañas nativas (*General*, *Alertas*, *Red y Cuota*, *Historial*, *Acerca de*), que permanece en pantalla y conserva el foco independientemente de la barra de menús.
- **Alertas Inteligentes**: Define umbrales para CPU > X%, presión de RAM, espacio en disco, batería baja (< 20%) y temperatura del SoC.
- **Prueba de Notificaciones**: Incluye un botón directo para enviar una notificación de prueba en tiempo real y verificar los permisos de macOS.
- *Anti-rebote*: El motor de alertas bloquea avisos repetitivos de la misma métrica durante al menos **15 minutos** para no molestar.

### 5. Histórico y Exportación de Datos
- Pulse Monitor almacena un registro histórico de las últimas 24 horas muestreado a intervalos respetuosos con el disco SSD (escrituras por lotes cada 5 minutos).
- Desde **Ajustes > Historial de Métricas** puedes pulsar:
  - **Exportar CSV**: Genera un archivo `.csv` compatible con Excel o Numbers con fecha, CPU, RAM, disco, velocidad de red y temperatura.
  - **Exportar JSON**: Exporta la serie temporal completa en formato JSON para análisis o scripts externos.

---

## 📱 5. Cómo Añadir los 10 Widgets al Escritorio

Una vez la aplicación esté en `/Applications`:

1. Haz clic derecho sobre una zona vacía de tu fondo de escritorio y selecciona **"Editar widgets..."** (o abre el Centro de Notificaciones haciendo clic en la hora/fecha superior derecha y pulsa "Editar widgets" abajo).
2. En la barra lateral izquierda del selector de widgets, busca **Pulse Monitor** o **Pulse Widgets**.
3. Verás disponibles los 10 widgets especializados:

| Widget | Tamaños | Qué te muestra |
|---|---|---|
| **Fecha y Calendario** | Pequeño, Mediano | Día de la semana, día del mes en grande, mes y próximas reuniones. |
| **Clima y Pronóstico** | Pequeño, Mediano | Temperatura actual, sensación térmica, viento, icono SF Symbol multicolor y pronóstico horario. |
| **Red y Conexión** | Pequeño, Mediano | Velocidad en vivo de bajada/subida, gráfica de área, consumo de hoy e IP local. |
| **Procesador CPU** | Pequeño, Mediano | Porcentaje grande, sparkline de los últimos 60s, desglose de núcleos y temperatura. |
| **Batería y Energía** | Pequeño, Mediano | Nivel %, vatios de consumo instantáneo o carga, estado de alimentación y ciclos. |
| **Memoria RAM** | Pequeño, Mediano | Memoria usada y libre en GB, barra apilada y nivel de presión. |
| **Almacenamiento** | Pequeño, Mediano | Espacio ocupado/libre por disco con cambio dinámico a ámbar (80%) y rojo (90%). |
| **Resumen del Sistema** | Mediano, Grande | El widget principal estilo *Usage*: cuadrícula compacta con CPU, RAM, Disco, Red y Batería a la vez. |
| **Top Apps y Procesos** | Pequeño, Mediano | Lista de las aplicaciones que más recursos están consumiendo ahora mismo. |
| **Térmica y Ventiladores** | Pequeño, Mediano | Temperatura del procesador SoC, estado térmico y barras de RPM de los ventiladores. |

4. Arrastra el widget deseado a tu escritorio o al Centro de Notificaciones.

---

## ❓ 6. Preguntas Frecuentes y Solución de Problemas

#### ¿Por qué no veo el icono de la aplicación en el Dock?
Pulse Monitor está configurado intencionadamente como agente de barra de menús (`LSUIElement = YES`). Esto evita saturar el Dock y asegura que la aplicación viva de forma discreta y permanente en la barra superior.

#### Los widgets muestran datos por defecto o "Sin datos"
Asegúrate de haber abierto la aplicación **Pulse Monitor** al menos una vez tras encender el Mac. La aplicación es la encargada de escribir el snapshot compartido que leen los widgets. Si activas la opción **"Iniciar al arrancar el Mac"** en Ajustes, siempre estarán actualizados automáticamente.

#### ¿Cómo forzar la actualización de un widget?
Todos los widgets son interactivos y responden a los eventos de recarga automáticos de macOS cada 30 segundos, así como a la llamada directa de la aplicación cuando hay cambios sustanciales en el sistema.

#### ¿Cómo desinstalar completamente la app?
1. Pulsa en el icono de Pulse Monitor en la barra de menús y haz clic en el icono de encendido (**Salir**).
2. Elimina `/Applications/PulseMonitor.app`.
3. Si deseas borrar las configuraciones y el histórico:
   ```bash
   rm -rf ~/Library/Application\ Support/PulseMonitor
   rm -rf ~/Library/Group\ Containers/group.com.pulse.monitor
   ```
