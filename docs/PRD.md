# Hey You! — PRD

*Versión 1.0 · 2026-10-28 · Autor: Nico Patarino con Claude · Estado: borrador para decisión*

Documento de producto de **Hey You!**, una app de macOS que vive en la barra de menús, lee tu Google Calendar y, un minuto antes de cada reunión, toma toda la pantalla en rojo hasta que la descartas. Complementa a [PLAN.md](../PLAN.md), que es el plan técnico de ejecución. Donde este documento y PLAN.md discrepen, manda este documento en el *qué* y PLAN.md en el *cómo*.

---

## Página 0 — Las ocho decisiones que definen el producto

Si solo lees esto, ya sabes qué es Hey You!.

1. **Un solo trabajo**: que no llegues tarde a una reunión por haber perdido la noción del tiempo. Nada más. Ni agenda, ni notas, ni "hub de reuniones".
2. **Intrusiva pero no coercitiva**: la alerta ocupa todas las pantallas y no se va sola, pero cualquier clic o tecla la quita. Nunca bloqueamos al usuario; solo hacemos imposible no verla.
3. **Un minuto antes, por defecto**: el momento en que ya no hay nada que terminar y solo queda unirse. Configurable entre 30 s y 5 min, nunca más.
4. **Google Calendar primero y solo** en v1, con el botón "Sign in with Google" de siempre. Sin cuenta propia, sin backend, sin servidores nuestros.
5. **Cero datos fuera del Mac**: solo lectura del calendario, tokens en el llavero, ninguna analítica en v1. La política de privacidad cabe en un párrafo.
6. **Mac App Store, gratis en v1**. El objetivo del lanzamiento es que la usen, no cobrar. La monetización se decide con datos en la fase 3.
7. **Nativo y pequeño**: Swift 6, SwiftUI, TCA, menos de 10 MB, sin Electron, sin frameworks de terceros salvo TCA y el SDK de Google Sign-In.
8. **Construida de forma autónoma por un agente** siguiendo PLAN.md, con tests, en un apetito fijo de tres semanas. Si no cabe, se recorta alcance, no se amplía el plazo.

---

## 1. Working Backwards

### 1.1 Nota de prensa (escrita como si ya se hubiera lanzado)

**Hey You! llega a la Mac App Store: la app que no te deja llegar tarde a una reunión**

*Madrid, 2 de diciembre de 2026.* Hoy se publica Hey You!, una pequeña app para Mac con una única función: un minuto antes de cada reunión de tu Google Calendar, pinta todas tus pantallas de rojo con el nombre de la reunión, una cuenta atrás y un botón para unirte. La alerta no desaparece sola. Un clic, una tecla o Cmd+Q y se va, pero nadie puede decir que no la vio.

"Sabía que tenía reunión a las once. Miré el reloj a las 10:55 y, cuando volví a mirar, eran las 11:07", cuenta Nico Patarino, su creador. "No es un problema de organización. Es que cuando estás concentrado el tiempo se diluye. Las notificaciones normales son un rectángulo gris en la esquina, exactamente lo que tu cerebro ha aprendido a ignorar. Quería algo que no se pudiera ignorar sin que me tratara como a un niño".

Hey You! vive en la barra de menús, sin icono en el Dock ni ventanas. Se conecta a Google Calendar con el inicio de sesión habitual de Google, en modo solo lectura, y no envía nada a ningún servidor propio: no hay cuenta, no hay backend, no hay analítica. Detecta el enlace de Google Meet, Zoom, Teams o Webex del evento y lo abre con una tecla. El tiempo de aviso se puede ajustar entre treinta segundos y cinco minutos, y puedes ignorar los eventos de día completo, los que has rechazado o los que no tienen enlace.

"La mayoría de apps de reuniones quieren ser tu nueva agenda. Hey You! quiere ser el compañero que te toca el hombro y te dice: eh, tú, que es ahora", añade Patarino.

Hey You! está disponible gratis en la Mac App Store para macOS 14 o posterior.

### 1.2 FAQ de usuario

**¿No hace ya esto el Calendario de Mac?**
Calendario y Google envían una notificación en la esquina superior derecha. Es exactamente el tipo de aviso que, cuando estás concentrado, desaparece de tu campo visual en dos segundos. Hey You! ocupa toda la pantalla y no se va hasta que tú lo decides.

**¿Me bloquea el ordenador?**
No. Cualquier clic en la pantalla, cualquier tecla, Esc o Cmd+Q descartan la alerta al instante. Puedes seguir trabajando en cuanto quieras. Lo único que no puedes hacer es no enterarte.

**¿Qué pasa si estoy compartiendo pantalla o presentando?**
En v1, la alerta aparece igual (sobre tu pantalla, y si compartes la pantalla completa, la verán). Lo consideramos una característica: si estás presentando y tienes otra reunión en un minuto, tienes un problema de verdad. En una versión posterior se podrá silenciar mientras haya una reunión en curso.

**¿Qué datos lee?**
Solo lectura de tus calendarios de Google: título, hora, enlace de videollamada, si has aceptado o rechazado. No escribe nada, no lee correos ni contactos. Los permisos de Google se los concedes tú en la pantalla de Google y los puedes revocar en myaccount.google.com.

**¿Dónde van mis datos?**
A ningún sitio. La app habla directamente con Google desde tu Mac y guarda los tokens en el llavero de macOS. No tenemos servidores. No hay analítica.

**¿Y si tengo varios monitores?**
La alerta sale en todos a la vez. Da igual dónde estés mirando.

**¿Y si el Mac estaba dormido?**
Al despertar, la app recalcula. Si la reunión aún no ha empezado, verás la alerta inmediatamente. Si ya empezó, verás "Empezó hace X minutos".

**¿Funciona con Outlook, iCloud o el calendario del Mac?**
Todavía no. v1 es solo Google. Si la app funciona para la gente, lo siguiente es el calendario del sistema (que incluye iCloud, Exchange y también Google).

**¿Cuánto cuesta?**
Nada en el lanzamiento.

**¿Por qué me pide abrirse al iniciar sesión?**
Porque si no está abierta no puede avisarte. Es opcional, pero sin ella la app solo sirve el día que te acuerdes de abrirla.

### 1.3 FAQ interna (las preguntas incómodas)

**¿Esto no existe ya?**
Sí, parcialmente. *In Your Face* (Mac App Store, de pago) hace alertas a pantalla completa desde el calendario del sistema. *MeetingBar* (open source) pone la próxima reunión en la barra de menús con botón de unirse y notificaciones normales. *Dato*, *Itsycal*, *Fantastical* y *Meeter* viven en el mismo espacio. Por tanto, la idea no es nueva y no hay foso tecnológico. Lo que apostamos es una ejecución más radical (no se va sola, cualquier interacción la quita, cero fricción, cero configuración, gratis) y la integración directa con Google sin pasar por el Calendario del Mac. Hay que decirlo en voz alta: **si In Your Face ya resuelve esto bien, Hey You! solo se justifica por ser gratis, más simple y más agresiva.** La fase 0 del pre-mortem (§7) exige probar In Your Face una semana antes de construir nada.

**¿Por qué Google directo y no EventKit (el calendario del sistema)?**
EventKit sería más simple (sin OAuth, sin verificación de Google, soporta todos los proveedores). Elegimos Google directo porque (a) es lo que pidió el fundador y usuario número uno, (b) muchos usuarios de Google Workspace no tienen la cuenta configurada en el Calendario del Mac, y pedirles que lo hagan es una fricción de onboarding enorme, (c) "Sign in with Google" es un gesto conocido que transmite confianza. El precio: verificación OAuth de Google antes de poder publicar a cualquiera. La abstracción `CalendarClient` deja EventKit como segunda implementación sin tocar el resto.

**¿Google nos va a dejar?**
El scope `calendar.readonly` es *sensitive* (no *restricted*), así que requiere verificación de la app OAuth (página web, política de privacidad, vídeo demo) pero no la auditoría de seguridad CASA. Hasta que se apruebe, solo funcionan los usuarios de prueba (máximo 100). Esto es una dependencia de calendario real: la verificación tarda de días a semanas. Hay que solicitarla en cuanto haya un build estable, antes de enviar a App Store.

**¿Apple nos va a aprobar?**
Riesgos de revisión: (1) app sin ventana principal (`LSUIElement`): aceptado si hay onboarding y ajustes accesibles; (2) interceptar Cmd+Q mientras hay alerta: lo explicamos en las notas al revisor como "descartar la alerta"; (3) regla 4.8 sobre inicio de sesión con terceros: Apple exige ofrecer Sign in with Apple **salvo** cuando la app es un cliente de un servicio concreto y el usuario debe iniciar sesión en ese servicio para acceder a su contenido. Es exactamente nuestro caso; hay que citarlo en las notas al revisor. (4) Abrirse al iniciar sesión: debe ser opt-in. Lo es.

**¿Qué pasa cuando el usuario lo pone en silencio y se olvida de la app?**
Es el modo de fallo más probable (ver pre-mortem). La app no tiene "silenciar"; tiene "salir". Y si sale, lo hace a sabiendas. No añadimos modo "no molestar" en v1 precisamente para no dar una salida fácil a la que no se vuelve.

**¿Por qué gratis?**
Porque el objetivo del lanzamiento es aprender si la gente lo usa de verdad durante semanas, y un precio de entrada reduce la muestra a casi cero. El coste marginal es cero (sin servidores). Si en la fase 3 vemos retención, hay tres salidas: pago único (4,99 €), versión Pro (múltiples proveedores, reglas) o seguir gratis como proyecto de portfolio. Se decide con datos, no hoy.

**¿Por qué TCA para algo tan pequeño?**
Porque el fundador lo quiere, porque obliga a aislar efectos (reloj, red, ventanas), y porque permite testear el scheduler y la lógica de disparo de forma determinista con `TestClock`. El coste de aprendizaje lo paga el agente, no un equipo.

**¿Qué no vamos a hacer nunca?**
Backend, cuentas propias, escribir en el calendario, analítica sin consentimiento, publicidad, bloquear al usuario, sincronizar con nada que no sea un calendario.

---

## 2. Discovery

### 2.1 El problema y la persona

**Persona principal: la persona concentrada.** Trabajador del conocimiento (desarrollo, diseño, producto, dirección) con entre 2 y 8 reuniones al día, la mayoría por videollamada, que trabaja en bloques de concentración profunda. No es desorganizado: sabe que tiene la reunión. Lo que falla es la *percepción del tiempo* durante la concentración: "sé que es a las 11, miro y son las 10:55, vuelvo a mirar y son las 11:07".

**Lo que ya intenta y por qué no funciona:**
- Notificaciones del calendario: pequeñas, en la esquina, se esfuman. El cerebro las ha filtrado.
- Alarmas en el móvil: el móvil está boca abajo o en silencio por la misma concentración.
- Mirar el reloj: es exactamente lo que no ocurre.
- Fantastical / MeetingBar en la barra de menús: útiles para ver qué viene, inútiles para *interrumpir*.

**Coste del problema:** llegar tarde 3 a 7 minutos, varias veces por semana. Coste reputacional (en equipos remotos, la puntualidad es la mitad de la primera impresión), coste de ansiedad residual ("¿me he pasado?") que estropea la concentración que se pretendía proteger, y ocasionalmente perder la reunión entera.

### 2.2 Opportunity Solution Tree

**Resultado deseado:** que la persona concentrada llegue a tiempo a sus reuniones sin tener que romper su concentración para vigilar el reloj.

```
RESULTADO: llegar a tiempo sin vigilar el reloj
│
├── O1. "No me entero del aviso" (el aviso no atraviesa la concentración)
│   ├── S1.1 Alerta a pantalla completa en todas las pantallas         ← v1
│   ├── S1.2 Sonido distintivo                                          ← v1
│   ├── S1.3 Que la alerta no se vaya sola                               ← v1
│   ├── S1.4 Alerta también en iPhone/Watch                              ✗ fuera (requiere backend o iCloud sync)
│   └── S1.5 Parpadeo del icono del Dock                                 ✗ descartada (es otro aviso ignorable)
│
├── O2. "Me entero pero sigo 'solo un minuto más'" (el aviso llega demasiado pronto y lo pospongo)
│   ├── S2.1 Avisar a 1 minuto, cuando ya no hay nada que terminar       ← v1 (decisión central)
│   ├── S2.2 Tiempo configurable 30 s–5 min                              ← v1
│   ├── S2.3 Botón "Unirse" que abre la llamada con una tecla            ← v1
│   └── S2.4 Segundo aviso a 5 min como "pre-aviso" suave                ✗ v2 (riesgo de convertirse en ruido)
│
├── O3. "Cuando me doy cuenta ya ha empezado y tardo en encontrar el enlace"
│   ├── S3.1 Detectar Meet/Zoom/Teams/Webex y abrirlo con Enter          ← v1
│   ├── S3.2 Mostrar "empezó hace X min" para que la culpa sea útil      ← v1
│   └── S3.3 Unirse automáticamente al llegar a 0                        ✗ no-go (sorprende y da miedo)
│
├── O4. "No confío en darle acceso a mi calendario a una app desconocida"
│   ├── S4.1 Sign in with Google oficial, solo lectura                   ← v1
│   ├── S4.2 Sin backend; explicarlo en onboarding y en la App Store     ← v1
│   └── S4.3 EventKit como alternativa sin OAuth                         ✗ v2
│
├── O5. "La app no está abierta justo el día que la necesito"
│   ├── S5.1 Abrir al iniciar sesión (opt-in)                            ← v1
│   ├── S5.2 Recalcular al despertar el Mac                              ← v1
│   └── S5.3 Indicador en la barra de menús de que está vigilando        ← v1
│
└── O6. "La alerta salta cuando no debe y pierdo la confianza"
    ├── S6.1 Ignorar eventos de día completo y rechazados               ← v1
    ├── S6.2 Elegir qué calendarios vigilar                              ← v1
    ├── S6.3 Solo eventos con enlace de videollamada (opcional)         ← v1
    ├── S6.4 Silenciar mientras hay otra reunión en curso               ✗ v2
    └── S6.5 Reglas por título o por organizador                        ✗ v2
```

Cada feature de v1 cuelga de una oportunidad. Lo que no cuelga de ninguna, no entra.

### 2.3 Job stories

Formato: *Cuando [situación], quiero [motivación], para [resultado].*

- **JS1.** Cuando estoy en un bloque de concentración y tengo una reunión dentro de poco, quiero que algo me interrumpa en el último momento posible, para apurar la concentración sin llegar tarde.
- **JS2.** Cuando la alerta aparece, quiero quitarla con lo primero que toque, para no sentir que la app me castiga ni perder segundos peleándome con ella.
- **JS3.** Cuando la alerta aparece, quiero unirme a la llamada con una tecla, para no buscar el enlace en el correo o el calendario.
- **JS4.** Cuando vuelvo de comer y el Mac estaba dormido, quiero saber al instante si tengo algo en marcha, para no descubrirlo por un mensaje de "¿vienes?".
- **JS5.** Cuando instalo una app que pide mi calendario, quiero ver la pantalla de Google de siempre y entender qué lee, para fiarme sin leer una política de privacidad.
- **JS6.** Cuando tengo un evento de día completo o una reunión que rechacé, no quiero que me interrumpan, para seguir confiando en que cada alerta importa.
- **JS7.** Cuando estoy presentando en una reunión y empieza la siguiente, quiero enterarme igual, para avisar y salir a tiempo. *(Se acepta el coste de que la alerta se vea en la pantalla compartida en v1.)*
- **JS8.** Cuando ya he llegado tarde, quiero ver cuánto, para decidir si entro o escribo disculpándome.
- **JS9.** Cuando termino el día, quiero no haber pensado en la app ni una vez, para que sea infraestructura y no otra cosa que gestionar.

---

## 3. DIBB

| | Data | Insight | Belief | Bet |
|---|---|---|---|---|
| **B1** | El fundador llega tarde 3–7 min a varias reuniones por semana pese a tener notificaciones activas. Las notificaciones de macOS se ocultan solas a los ~5 s por defecto. | El fallo no es de recuerdo sino de *saliencia*: el aviso existe pero no compite con la tarea en curso. | Un aviso que ocupe el 100 % del campo visual y no desaparezca por sí solo cambia el comportamiento donde las notificaciones no lo hacen. | Alerta a pantalla completa, persistente hasta interacción. **Métrica:** ≥ 80 % de alertas descartadas con "Unirse" o en los 30 s siguientes al inicio (ver §6). |
| **B2** | Los avisos a 10 o 15 min (los defaults de Google) se posponen mentalmente: "aún tengo tiempo". | A 1 minuto no hay nada que terminar, así que la única acción razonable es unirse. El aviso corto elimina la negociación interna. | 60 s es el punto óptimo entre "demasiado pronto para actuar" y "demasiado tarde para llegar". | Default de 60 s; configurable 30 s–5 min pero nunca más. **Métrica:** ≥ 70 % de usuarios mantienen 60 s tras dos semanas. |
| **B3** | In Your Face y MeetingBar existen y tienen usuarios; MeetingBar supera las 4.000 estrellas en GitHub. | Hay demanda demostrada y el mercado tolera apps mono-función. Pero ninguna combina Google directo + gratis + descarte con cualquier interacción. | Hay espacio para una variante más simple y agresiva, sobre todo entre usuarios de Google Workspace que no configuran el Calendario del Mac. | Lanzar gratis, solo Google, en App Store. **Métrica:** 500 instalaciones en 60 días sin inversión en marketing; retención a 4 semanas ≥ 40 % (proxy: sesiones con la app abierta vía App Store Connect / "opt-in local stats"). |
| **B4** | Una parte de usuarios de Google Workspace no tiene su cuenta en Calendario de Mac (política IT, pereza, no saber que se puede). | Pedir "configura tu cuenta Google en el Mac" como paso previo mata el onboarding. | "Sign in with Google" dentro de la app convierte más que cualquier instrucción. | OAuth directo con el SDK oficial pese al coste de verificación. **Métrica:** ≥ 60 % de los que abren la app completan el sign-in. |
| **B5** | Apps que piden calendario + sin backend conocido generan desconfianza (comentarios típicos en Reddit/HN: "¿a dónde van mis datos?"). | "No tenemos servidores" es un mensaje de confianza más fuerte que cualquier política. | Cero backend es a la vez más barato y mejor producto. | Sin backend, sin analítica, política de privacidad de un párrafo. **Métrica:** cero reseñas de 1–2 estrellas por privacidad. |

---

## 4. Pitch (Shape Up)

### Problema
Las personas que trabajan concentradas llegan tarde a reuniones que sabían que tenían, porque los avisos existentes no atraviesan la concentración y los avisos tempranos se posponen mentalmente.

### Apetito
**Tres semanas de calendario** hasta un build enviado a App Store Connect (TestFlight), construido de forma autónoma por un agente. El apetito manda: si a mitad de la segunda semana algo no cabe, se recorta de la lista de §8 empezando por abajo. No se amplía el plazo. La aprobación de Google y Apple queda fuera del apetito porque no depende de nosotros.

### Solución a trazo grueso

```
┌─ Barra de menús ───────────────────────────────┐
│ 🔔 Hey You!                                     │
│ ───────────────                                 │
│ Vigilando 3 calendarios · próximo en 42 min     │
│ 11:00  Weekly sync            [Meet]            │
│ 12:30  1:1 con Ana            [Zoom]            │
│ 16:00  Demo cliente           [sin enlace]      │
│ ───────────────                                 │
│ Probar alerta                                   │
│ Ajustes…                                        │
│ Salir                                           │
└─────────────────────────────────────────────────┘

Onboarding (una ventana, una vez):
  ┌────────────────────────────────────────────┐
  │   🔔                                        │
  │   Hey You!                                  │
  │   Un minuto antes de cada reunión,          │
  │   toda tu pantalla se pone roja.            │
  │   No te bloquea. Solo no te deja ignorarlo. │
  │                                             │
  │   [ G  Sign in with Google ]                │
  │   Solo lectura · sin servidores             │
  └────────────────────────────────────────────┘

Alerta (todas las pantallas, rojo, sin ventana):
  ┌─────────────────────────────────────────────────┐
  │                                                 │
  │                  MEETING IN                     │
  │                 ╭──────────╮                    │
  │                 │   47s    │   (anillo)         │
  │                 ╰──────────╯                    │
  │                Weekly sync                      │
  │          11:00 – 11:30 · Google Meet            │
  │                                                 │
  │             [ Join meeting → ]                  │
  │                                                 │
  │   Click anywhere or press any key to dismiss    │
  └─────────────────────────────────────────────────┘
```

Flujo: abrir → onboarding → Google → la app desaparece a la barra → cada 60 s consulta las próximas 24 h → calcula el siguiente disparo → duerme hasta `inicio − 60 s` → pinta todo de rojo → Enter abre el enlace, cualquier otra cosa descarta.

### Rabbit holes (con límite explícito)

1. **Ventana sobre apps a pantalla completa y sobre todos los Spaces.** Puede comerse días. Límite: `level = .screenSaver` + `collectionBehavior` con `.fullScreenAuxiliary` y `.canJoinAllSpaces`. Si en 1 día de pruebas no cubre un caso (por ejemplo, un juego en exclusiva de pantalla), se documenta como limitación y se sigue.
2. **Interceptar Cmd+Q sin romper nada.** Límite: monitor local de teclado solo mientras la alerta está visible + `applicationShouldTerminate` devolviendo cancelar. Si da problemas con la revisión de Apple, Cmd+Q pasa a cerrar la app (la alerta se va igualmente) y punto.
3. **Parsing de enlaces de videollamada.** Hay infinitos formatos. Límite: `hangoutLink`, `conferenceData`, y una regex por proveedor sobre `location` y `description`. Lo que no matchee abre el evento en Google Calendar. No se añade un quinto proveedor en v1.
4. **Eventos recurrentes, zonas horarias, día completo.** Límite: siempre pedir a Google `singleEvents=true` para que expanda las recurrencias; usar las fechas con offset que devuelve; excluir `date` sin hora (día completo). Nunca calcular recurrencias nosotros.
5. **Fiabilidad del temporizador con el Mac dormido.** Límite: recalcular en `didWakeNotification` y en cada refresco de 60 s. Si el disparo quedó atrás pero el evento no empezó, disparar ya. No usar `NSBackgroundActivityScheduler` ni launch agents.
6. **El SDK de Google Sign-In en macOS con SwiftPM.** Está soportado, pero sus dependencias (AppAuth, GTM) pueden dar guerra. Límite: 1 día. Si no compila, OAuth propio con PKCE y `ASWebAuthenticationSession`, mismo botón, misma `AuthClient`.
7. **Diseño de la alerta.** Es fácil pasarse semanas. Límite: la especificación de PLAN.md §6, sin iteración abierta. Una pasada de pulido en la fase de QA.

### No-gos

- No EventKit, Outlook, iCloud ni CalDAV en v1.
- No app de iPhone, ni Watch, ni widget.
- No escribir en el calendario (ni "marcar como asistido", ni nada).
- No unirse automáticamente a la llamada.
- No modo "no molestar" ni snooze: la alerta se descarta o se descarta.
- No reglas por título, organizador o palabras clave.
- No analítica, ni crash reporting de terceros, ni telemetría en v1. Solo lo que da App Store Connect.
- No backend, cuentas, sincronización ni pago in-app.
- No bloquear Cmd+Tab, el ratón, ni nada que impida al usuario hacer lo que quiera.
- No localizar más allá de inglés y español.

---

## 5. Especificación orientada a decisiones (Linear Method)

Cada subsección dice qué se decide y por qué. Lo que no está aquí, no se ha decidido y el agente usa PLAN.md o su criterio.

### 5.1 Momento del aviso
**Decisión:** un único aviso, por defecto 60 s antes del inicio. Opciones: 30 s, 1, 2, 5 min. Sin segundo aviso.
**Por qué:** un aviso temprano se pospone; dos avisos convierten el primero en ruido y el segundo en rutina. A un minuto, la única acción sensata es unirse (B2).

### 5.2 Qué eventos disparan
**Decisión:** eventos con hora de inicio, en los calendarios seleccionados (por defecto todos), dentro de las próximas 24 h, que no sean de día completo (por defecto), que el usuario no haya rechazado (por defecto), y, opcionalmente, solo los que tengan enlace de videollamada (apagado por defecto). Los eventos marcados "libre" (transparencia) sí disparan; no queremos adivinar.
**Por qué:** cada falso positivo erosiona la confianza (O6). Cada falso negativo es exactamente el fallo que la app promete evitar. Ante la duda, disparar.

### 5.3 Dos eventos a la vez
**Decisión:** una sola alerta con el primer evento por orden alfabético; el segundo se marca como disparado. La alerta muestra "+1 más" bajo el título.
**Por qué:** dos alertas simultáneas se pisan. El usuario ya sabe que tiene solape; nuestro trabajo es que mire la pantalla.

### 5.4 Comportamiento de la alerta
**Decisión:** una ventana sin borde por pantalla, nivel screenSaver, sobre todos los Spaces y apps a pantalla completa, sin auto-cierre. Descarta: clic en cualquier punto, cualquier tecla, Esc, Cmd+Q, Cmd+W, Cmd+punto. Enter o clic en "Unirse" abre el enlace y descarta. Mientras hay alerta, Cmd+Q no cierra la app. Si llega otra alerta mientras hay una visible, la reemplaza. Al pasar la hora de inicio, "AHORA" durante 60 s y luego "EMPEZÓ HACE X MIN".
**Por qué:** la intrusión está en la *aparición*, no en la *permanencia obligada*. Cualquier fricción para descartar sería castigo, y el castigo hace que se desinstale (decisión 2 de la página 0). Interceptamos Cmd+Q porque es el reflejo de "quítame esto" y queremos que ese reflejo funcione sin matar al vigilante.

### 5.5 Sonido
**Decisión:** un sonido corto del sistema al aparecer, activado por defecto, desactivable. No se repite.
**Por qué:** cubre el caso de mirar al otro monitor o a la ventana. Repetirlo sería castigo.

### 5.6 Autenticación y datos
**Decisión:** SDK oficial de Google Sign-In, scope `calendar.readonly` (+ `openid email` para mostrar la cuenta), tokens gestionados por el SDK en el llavero. Una sola cuenta de Google en v1. Sin backend. Sin analítica.
**Por qué:** B4 y B5. Varias cuentas multiplican la complejidad del onboarding y de la lista de calendarios; el 90 % de los usuarios tiene una cuenta de trabajo.

### 5.7 Sincronización
**Decisión:** polling cada 60 s de los eventos entre ahora y +24 h, en todos los calendarios seleccionados, con `singleEvents=true&orderBy=startTime&fields=…`. Sin push, sin sync tokens, sin caché persistente.
**Por qué:** 1 petición por minuto por calendario está órdenes de magnitud por debajo de los límites de Google, el estado se reconstruye desde cero en cada ciclo (sin bugs de caché) y los eventos creados hace menos de un minuto quedan cubiertos. Push requeriría backend (no-go).

### 5.8 Presencia en el sistema
**Decisión:** solo barra de menús (`LSUIElement`), icono SF Symbol `bell`, con el texto "Xm" cuando quedan menos de 10 min para la próxima reunión. Menú con próximos 5 eventos del día, estado, "Probar alerta", "Ajustes…", "Salir". Abrir al iniciar sesión como toggle opt-in, sugerido en el onboarding.
**Por qué:** O5. El indicador de la barra responde a "¿está vigilando?" sin abrir nada. "Probar alerta" es la primera cosa que hace cualquiera después de instalar; que esté a un clic.

### 5.9 Onboarding
**Decisión:** una sola pantalla, abierta automáticamente la primera vez, con tres frases, el botón de Google y la nota "solo lectura · sin servidores". Tras el sign-in, muestra un toggle "Abrir al iniciar sesión" (recomendado) y un botón "Probar la alerta". Cierre automático.
**Por qué:** JS5 y JS9. El usuario debe entender en 10 segundos qué hace la app y qué no, y ver la alerta antes de que le pille por sorpresa en una reunión real.

### 5.10 Errores
**Decisión:** si Google devuelve 401 y el refresh falla: estado "desconectado" visible en la barra (icono `bell.slash`) y en el menú, con botón para volver a iniciar sesión. Sin red: se mantiene la última lista de eventos en memoria y se sigue disparando con ella; el menú muestra "sin conexión desde hh:mm". Nunca una alerta modal de error.
**Por qué:** una app de vigilancia que se calla sin avisar es peor que no tenerla. El estado tiene que verse de un vistazo, sin molestar.

### 5.11 Distribución y precio
**Decisión:** Mac App Store, gratis, macOS 14+, en inglés y español. Sin distribución fuera de la App Store en v1.
**Por qué:** B3. La App Store da confianza (sandbox, firma) a una app que pide el calendario, y es el canal que pidió el fundador. Notarización y venta directa duplican trabajo sin aportar al aprendizaje de la fase 2.

### 5.12 Lo que explícitamente no se decide todavía
Monetización (fase 3). EventKit (fase 3). Silenciar durante reuniones en curso (fase 3). Segunda cuenta de Google (nunca, salvo demanda clara).

---

## 6. Métricas

Restricción honesta: **sin analítica en v1, casi todo se mide a mano o con App Store Connect.** Proponemos un contador local opt-in (ajuste "Compartir estadísticas anónimas", apagado) que se diseña en v1 pero solo se implementa si entra en RICE; mientras tanto, el fundador y los testers de TestFlight reportan a mano con un comando de "exportar estadísticas locales" (JSON en el portapapeles). Las métricas se definen igual para que el día que se midan, ya signifiquen algo.

### North Star
**Reuniones alcanzadas a tiempo gracias a la alerta**: alertas que terminan en "Unirse" o se descartan dentro de los 30 s siguientes al inicio del evento, por usuario activo y semana.

Captura el valor (llegar) y el comportamiento que lo genera (reaccionar a la alerta).

### Métricas de entrada (las que mueven la North Star)
- Usuarios con sign-in completado / usuarios que abren la app (objetivo ≥ 60 %).
- Usuarios con "abrir al iniciar sesión" activado (objetivo ≥ 70 %).
- Alertas mostradas por usuario y semana (sanidad: debería acercarse a sus reuniones reales).
- Alertas con enlace detectado / alertas totales (objetivo ≥ 85 % en calendarios con videollamadas).

### Métricas de valor
- Tasa de reacción útil: (Unirse + descarte ≤ 30 s tras inicio) / alertas (objetivo ≥ 80 %).
- Retención: usuarios con la app abierta en la semana 4 / instalados (objetivo ≥ 40 %).
- Lead time mantenido en 60 s tras dos semanas (objetivo ≥ 70 %, B2).

### Guardarraíles (si se cruzan, se revisa el producto)
- Alertas descartadas en < 2 s sin unirse > 30 %: la alerta se ha vuelto ruido o salta mal.
- Alertas de eventos sin enlace > 50 %: revisar el default de "solo con enlace".
- Reseñas ≤ 2 estrellas que mencionen "molesta", "no puedo cerrar" o "privacidad".
- Tasa de crash > 1 % de sesiones (App Store Connect).
- Usuarios que desactivan "abrir al iniciar sesión" después de activarlo > 25 %.

### Métrica de parada
Si a las 8 semanas del lanzamiento la retención a 4 semanas es < 15 % **y** la tasa de reacción útil es < 50 %, el producto no cambia el comportamiento: se congela v1 y no se invierte en fase 3.

---

## 7. Pre-mortem e hipótesis más arriesgada

### 7.1 Pre-mortem: es marzo de 2027 y Hey You! ha fracasado. ¿Por qué?

| # | Causa del fracaso | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | **La gente la desinstala a la semana porque le molesta.** La alerta funcionaba, pero la sensación de "me gritan" ganó. | Alta | Fatal | Descarte instantáneo con cualquier interacción; filtros por defecto sensatos; "Probar alerta" en onboarding para que nadie se sorprenda; medir descartes < 2 s como guardarraíl. |
| 2 | **Google tardó dos meses en verificar la app** y no pudimos publicar a nadie fuera de 100 testers. | Media | Alto | Solicitar verificación en la semana 2 con un build estable; tener web y política de privacidad listas antes; plan B: EventKit en v1.1 si la verificación se eterniza. |
| 3 | **Apple rechazó la app** por interceptar Cmd+Q, por ser "solo una notificación" (regla 4.2, funcionalidad mínima) o por el login de terceros. | Media | Alto | Notas al revisor citando la excepción de 4.8; Cmd+Q interceptado documentado como "descartar"; onboarding y ajustes visibles; fallback: no interceptar Cmd+Q. Sobre 4.2: In Your Face está publicada, hay precedente. |
| 4 | **La alerta no aparece** sobre ciertas apps (pantalla completa, juegos, pantallas compartidas de Zoom) y el usuario llega tarde *con la app instalada*. | Media | Fatal | Probar explícitamente sobre Safari fullscreen, Zoom compartiendo, Keynote presentando, VS Code fullscreen (casos B.9–B.12). Documentar lo que no cubra. |
| 5 | **El temporizador falla tras dormir el Mac**, o la app muere en background y nadie se da cuenta. | Media | Fatal | Recalcular al despertar; refresco de 60 s; indicador en la barra; test B.6. |
| 6 | **Nadie la encuentra.** 40 descargas en dos meses. | Alta | Medio | Es un problema de distribución, no de producto. Post en HN/Reddit/X con el GIF de la alerta; página web con el "porqué"; pedir reseñas a los testers. No afecta a la validez del producto para el fundador. |
| 7 | **In Your Face ya lo hace mejor** y la comparación nos deja como copia inferior. | Media | Medio | Probarla antes (fase 0). Diferenciar en lo que decidimos: gratis, Google directo, descarte con todo, sin configuración. Si no hay diferencia perceptible, reconsiderar antes de construir. |
| 8 | **El SDK de Google en macOS da problemas** y se queman días de apetito. | Media | Medio | Límite de 1 día (rabbit hole 6); fallback a OAuth propio. |
| 9 | **Falsos positivos** (eventos rechazados, de día completo, calendarios de cumpleaños) hacen que el usuario deje de creer en la alerta. | Media | Alto | Filtros por defecto; selección de calendarios; mostrar "+1 más" en solapes. |
| 10 | **El agente construye algo que compila pero no funciona de verdad** porque no pudo probarlo sin Xcode. | Alta (hoy) | Alto | Instalar Xcode antes de empezar. Hito 7 de PLAN.md es obligatorio y manual. |

### 7.2 Hipótesis más arriesgada

> **Si una alerta ocupa toda la pantalla un minuto antes y no se va sola, la persona concentrada se une a tiempo y, además, no desinstala la app por molesta.**

Si esto es falso, da igual lo bien hecho que esté todo lo demás. Tiene dos mitades que pueden fallar por separado: (a) eficacia, (b) tolerancia.

### 7.3 Tests baratos antes de construir (fase 0, una semana)

1. **Wizard of Oz con 50 líneas.** Un script Swift (o incluso un AppleScript lanzado por un atajo de Automator) que, al ejecutarse, muestra una ventana roja a pantalla completa con un texto y se cierra con cualquier tecla. Se programa con `at`/`launchd` o se lanza a mano un minuto antes de cada reunión del fundador durante 5 días laborables. Mide: ¿cuántas veces llegó a tiempo? ¿Cuántas veces le molestó? ¿Cambió algo frente a la semana anterior? Coste: 2 horas.
2. **Probar In Your Face una semana** (competidor existente, de pago, pequeño). Si resuelve el problema al 100 % y no molesta, la pregunta pasa a ser "¿por qué construir otra?". Si molesta o falla en algo concreto, eso es la hoja de ruta. Coste: el precio de la app.
3. **Cinco conversaciones de diez minutos** con personas del perfil (JS1) preguntando solo dos cosas: "¿cuándo fue la última vez que llegaste tarde a una reunión que sabías que tenías?" y "si tu pantalla entera se pusiera roja un minuto antes, ¿la dejarías puesta una semana?". Buscamos repulsión o entusiasmo, no cortesía.
4. **Prueba del guardarraíl de tolerancia**: en la semana del Wizard of Oz, contar cuántas veces el fundador sintió el impulso de desactivarlo. Si > 2, la hipótesis (b) está en peligro y hay que suavizar (sonido, animación) antes de construir.

Criterio: si en la fase 0 el fundador llega a tiempo a ≥ 90 % de las reuniones con la alerta de mentira y no la desactiva, se construye. Si no, se revisa el pitch antes de gastar el apetito.

---

## 8. Priorización RICE

Reach: usuarios afectados de cada 100 activos al mes. Impact: 3 masivo, 2 alto, 1 medio, 0,5 bajo, 0,25 mínimo. Confidence: 100 / 80 / 50 %. Effort: días-persona (de agente supervisado). Score = R × I × C / E.

| # | Feature | R | I | C | E | Score | v1 |
|---|---|---|---|---|---|---|---|
| 1 | Alerta a pantalla completa en todas las pantallas, sin auto-cierre, descarte con cualquier interacción | 100 | 3 | 80 % | 3 | 80 | ✅ |
| 2 | Scheduler: polling, cálculo del siguiente disparo, dedupe, wake | 100 | 3 | 100 % | 2 | 150 | ✅ |
| 3 | Sign in with Google + lectura de calendarios | 100 | 3 | 80 % | 3 | 80 | ✅ |
| 4 | Botón Unirse con detección de Meet/Zoom/Teams/Webex | 85 | 2 | 100 % | 1 | 170 | ✅ |
| 5 | Barra de menús con próximos eventos y estado | 100 | 1 | 100 % | 1,5 | 67 | ✅ |
| 6 | Onboarding de una pantalla | 100 | 1 | 100 % | 1 | 100 | ✅ |
| 7 | Abrir al iniciar sesión | 90 | 2 | 100 % | 0,5 | 360 | ✅ |
| 8 | Filtros: día completo, rechazados, solo con enlace | 70 | 2 | 80 % | 0,5 | 224 | ✅ |
| 9 | "Probar alerta" en menú y onboarding | 100 | 1 | 100 % | 0,25 | 400 | ✅ |
| 10 | Selección de calendarios | 50 | 1 | 80 % | 1 | 40 | ✅ |
| 11 | Lead time configurable (30 s–5 min) | 40 | 1 | 80 % | 0,25 | 128 | ✅ |
| 12 | Sonido al aparecer (desactivable) | 80 | 1 | 80 % | 0,25 | 256 | ✅ |
| 13 | Localización inglés + español | 100 | 0,5 | 100 % | 0,5 | 100 | ✅ |
| 14 | "Empezó hace X min" tras el inicio | 60 | 1 | 80 % | 0,25 | 192 | ✅ |
| 15 | Estado de error visible (desconectado, sin red) | 30 | 2 | 80 % | 0,5 | 96 | ✅ |
| 16 | Exportar estadísticas locales (JSON) | 10 | 1 | 50 % | 0,5 | 10 | ⚠️ si sobra |
| 17 | Silenciar durante reunión en curso | 40 | 1 | 50 % | 1 | 20 | ✗ v2 |
| 18 | EventKit (iCloud, Exchange, Outlook) | 50 | 2 | 80 % | 2 | 40 | ✗ v2 |
| 19 | Segundo aviso a 5 min | 30 | 0,5 | 50 % | 0,5 | 15 | ✗ v2 |
| 20 | Reglas por título/organizador | 20 | 1 | 50 % | 1,5 | 7 | ✗ |
| 21 | Varias cuentas de Google | 15 | 1 | 50 % | 2 | 4 | ✗ |
| 22 | App de iPhone / Watch | 30 | 1 | 50 % | 10 | 1,5 | ✗ |

**Orden de recorte si el apetito no alcanza** (se quita primero lo de arriba): 16 → 10 (todos los calendarios, sin selección) → 13 (solo inglés) → 15 (solo icono tachado, sin texto) → 11 (fijo 60 s) → 12. Los puntos 1–9 y 14 son el núcleo y no se recortan: sin ellos no hay producto.

---

## 9. Ejecución por fases

| Fase | Qué | Duración | Criterio de salida | Criterio de parada |
|---|---|---|---|---|
| **0. Validación** | Wizard of Oz, probar In Your Face, 5 conversaciones (§7.3). Instalar Xcode. Crear OAuth client y cuenta de desarrollador. | 1 semana | Fundador a tiempo ≥ 90 % con la alerta falsa; no la desactivó; ≥ 3 de 5 personas dicen "lo probaría". Xcode operativo. | Fundador la desactivó por molesta, o In Your Face resolvió el problema sin pegas. → Revisar pitch. |
| **1. Construcción** | Hitos 1–6 de PLAN.md por el agente. Verificación OAuth de Google solicitada en cuanto hay build. | 2 semanas | Build Debug ejecutable; `swift test` verde; casos B.1–B.8 pasan con calendario mock. | Mitad de semana 2 sin alerta funcionando sobre apps a pantalla completa. → Recortar según §8 o replantear ventana. |
| **2. QA y lanzamiento** | Hitos 7–9 de PLAN.md. Casos B.9–B.14 a mano. TestFlight con 5–10 personas una semana. Envío a App Store. | 1 semana + revisión | Todos los casos del anexo B pasan; 0 crashes en TestFlight; aprobación de Apple. | Apple rechaza dos veces por lo mismo. → Quitar la causa (p. ej. Cmd+Q) y reenviar. |
| **3. Aprendizaje** | 8 semanas en producción. Medir §6 a mano y con App Store Connect. Decidir monetización, EventKit, silenciar en reunión. | 8 semanas | Retención 4 sem ≥ 40 % y reacción útil ≥ 80 % → se planifica v2 con RICE 17–19. | Métrica de parada (§6): retención < 15 % y reacción < 50 %. → Congelar. |

Las fases 0 y 1 pueden solaparse parcialmente (el agente puede empezar el hito 1–2 mientras el fundador hace el Wizard of Oz), pero **no se pasa del hito 4 sin haber cerrado la fase 0**.

---

## Anexo A — Glosario

- **Alerta**: la toma de pantalla roja. No confundir con notificación de macOS.
- **Lead time**: segundos antes del inicio del evento en que se dispara la alerta. Default 60.
- **Disparo (fire)**: momento `inicio − lead time`.
- **Reacción útil**: descartar con "Unirse", o descartar en los 30 s posteriores al inicio.
- **Persona concentrada**: la persona usuaria descrita en §2.1.

## Anexo B — Casos de prueba con datos reales

Zona horaria del Mac: Europe/Madrid (CET, UTC+1 en estas fechas). Formato Given / When / Then. Los casos B.1–B.8 son automatizables con `TestClock` y el calendario mock; B.9–B.14 son manuales en el hito 7.

**B.1 Disparo básico**
- Given: ahora es 2026-11-03 10:58:30; evento "Weekly sync" 11:00–11:30 con `hangoutLink = https://meet.google.com/abc-defg-hij`, estado `accepted`; lead time 60 s.
- When: el reloj llega a 10:59:00.
- Then: la alerta aparece en todas las pantallas con "MEETING IN", "60s", "Weekly sync", "11:00 – 11:30 · Google Meet" y botón "Join meeting"; suena una vez.

**B.2 Enter abre el enlace**
- Given: alerta de B.1 visible a las 10:59:12.
- When: el usuario pulsa Enter.
- Then: se abre `https://meet.google.com/abc-defg-hij` en el navegador por defecto, la alerta desaparece con fade de 0,25 s, el evento queda marcado como disparado.

**B.3 Cualquier interacción descarta**
- Given: alerta visible.
- When: (a) clic en una zona vacía del fondo, (b) tecla `j`, (c) Esc, (d) Cmd+Q, (e) Cmd+W, (f) clic derecho.
- Then: en los seis casos la alerta desaparece y **la app sigue ejecutándose** (icono en la barra presente). No se abre ningún enlace.

**B.4 Sin interacción, no se cierra**
- Given: alerta de B.1 visible, nadie toca nada.
- When: el reloj llega a 11:00:00; luego a 11:00:59; luego a 11:03:00.
- Then: a las 11:00:00 el número pasa a "NOW" con animación; a las 11:00:59 sigue "NOW"; a las 11:03:00 la etiqueta es "STARTED 3 MIN AGO" y el número "3". La alerta sigue visible.

**B.5 Dedupe tras refresco**
- Given: B.1 disparada y descartada a las 10:59:20.
- When: a las 10:59:30 llega un refresco con el mismo evento.
- Then: no se reprograma ni se vuelve a mostrar "Weekly sync". El siguiente disparo programado es el del siguiente evento.

**B.6 Despertar del Mac con disparo atrasado**
- Given: evento "1:1 con Ana" 12:30–13:00, lead time 60 s; el Mac se durmió a las 12:10 y despierta a las 12:29:40.
- When: llega `didWakeNotification`.
- Then: la alerta aparece inmediatamente (el `fireAt` 12:29:00 quedó atrás pero el evento no ha empezado) mostrando "20s".

**B.7 Despertar con evento ya empezado**
- Given: mismo evento; el Mac despierta a las 12:34:10.
- When: llega `didWakeNotification`.
- Then: la alerta aparece con "STARTED 4 MIN AGO". *(Decisión: sí se muestra, porque el usuario necesita saberlo; JS4.)* Si despierta a las 13:05, el evento ya terminó: no se muestra nada.

**B.8 Filtros por defecto**
- Given: ahora 2026-11-03 08:00; eventos: "Cumpleaños de Marta" (día completo, 2026-11-03), "Retro" 09:00 con estado `declined`, "Foco" 09:30–11:00 sin asistentes ni enlace, "Demo cliente" 10:00 con `location = "https://zoom.us/j/91234567890?pwd=abc"`.
- When: se calcula el siguiente disparo con los filtros por defecto (`ignoreAllDay`, `ignoreDeclined`, `onlyEventsWithMeetingLink = false`).
- Then: el siguiente disparo es "Foco" a las 09:29:00 (sin enlace, pero sí dispara); "Cumpleaños" y "Retro" se ignoran. Con `onlyEventsWithMeetingLink = true`, el siguiente es "Demo cliente" a las 09:59:00 con proveedor Zoom.

**B.9 Solape de dos eventos**
- Given: "Weekly sync" y "Alinear roadmap" ambos a 11:00.
- When: dispara a 10:59:00.
- Then: una única alerta, título "Alinear roadmap" (alfabético), subtítulo "+1 more"; ambos quedan marcados como disparados.

**B.10 Sobre app a pantalla completa (manual)**
- Given: Safari en modo pantalla completa en el monitor 1; VS Code en el monitor 2; evento en 60 s (vía "Probar alerta").
- Then: la alerta cubre ambos monitores, por encima de Safari a pantalla completa; Esc la quita y Safari sigue a pantalla completa.

**B.11 Compartiendo pantalla en Zoom (manual)**
- Given: Zoom compartiendo el escritorio completo.
- Then: la alerta aparece (y se ve en la compartición). Se documenta como comportamiento esperado en v1.

**B.12 Keynote presentando (manual)**
- Given: Keynote en modo presentación.
- Then: la alerta aparece por encima. Si no aparece, se documenta como limitación conocida y no bloquea el lanzamiento.

**B.13 Pérdida de sesión de Google (manual)**
- Given: usuario revoca el acceso en myaccount.google.com.
- When: siguiente refresco.
- Then: icono de la barra pasa a `bell.slash`, el menú muestra "Desconectado de Google · Volver a iniciar sesión"; no aparece ninguna alerta modal; al pulsar, se abre la pantalla de Google.

**B.14 Sin conexión (manual)**
- Given: Wi-Fi apagada a las 10:50 con eventos ya cargados.
- When: 10:59:00.
- Then: la alerta de "Weekly sync" aparece igual; el menú muestra "Sin conexión desde 10:50".

**B.15 Probar alerta (manual)**
- Given: app recién instalada, onboarding completado.
- When: clic en "Probar alerta".
- Then: en 5 s aparece una alerta con un evento ficticio "Hey You! test" con enlace a la página del proyecto; Enter lo abre; cualquier otra cosa la quita.
