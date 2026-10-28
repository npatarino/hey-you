# Hey You! — PRD

*Versión 1.0 · 2026-10-28 · Autor: Nico Patarino con Claude · Estado: borrador para decisión*

Documento de producto de **Hey You!**, una app de macOS que vive en la barra de menús, lee tu Google Calendar y, un minuto antes de cada reunión, toma toda la pantalla en rojo hasta que la descartas. Complementa a [PLAN.md](../PLAN.md), que es el plan técnico de ejecución. Donde este documento y PLAN.md discrepen, manda este documento en el *qué* y PLAN.md en el *cómo*.

---

## Página 0 — Las ocho decisiones que definen el producto

Si solo lees esto, ya sabes qué es Hey You!.

1. **Un solo trabajo**: que no llegues tarde a una reunión por haber perdido la noción del tiempo. Nada más. Ni agenda, ni notas, ni "hub de reuniones".
2. **Intrusiva pero no coercitiva**: la alerta ocupa todas las pantallas y no se va sola, pero un clic, Esc o Cmd+Q la quitan. Nunca bloqueamos al usuario; solo hacemos imposible no verla.
3. **Un minuto antes**: el momento en que ya no hay nada que terminar y solo queda unirse. Con Pro se puede acortar hasta 10 s; nunca más de un minuto. El aviso temprano se pospone; el tardío no.
4. **Google Calendar primero y solo** en v1, con el botón "Sign in with Google" de siempre. Sin cuenta propia, sin backend, sin servidores nuestros.
5. **Sin backend propio, con analítica de producto**: el calendario se lee en el Mac y los tokens viven en el llavero; los datos de uso (nunca el contenido del calendario) van a PostHog con consentimiento, para saber cómo se usa la app y poder hablar con los usuarios más adelante.
6. **Freemium con compra única**: gratis para el trabajo esencial (alerta a 60 s, unirse con una tecla). **Hey You! Pro** desbloquea el control fino: tiempo de aviso, filtros (rechazados, sin enlace, sin asistentes), calendarios, sonido, horario, estadísticas de puntualidad.
7. **Nativo y pequeño**: Swift 6, SwiftUI, TCA, menos de 15 MB, sin Electron. Terceros: TCA, Google Sign-In, PostHog. StoreKit 2 para la compra.
8. **Construida de forma autónoma por un agente** siguiendo PLAN.md, con tests, en un apetito fijo de tres semanas. Si no cabe, se recorta alcance, no se amplía el plazo.

---

## 1. Working Backwards

### 1.1 Nota de prensa (escrita como si ya se hubiera lanzado)

**Hey You! llega a la Mac App Store: la app que no te deja llegar tarde a una reunión**

*Madrid, 2 de diciembre de 2026.* Hoy se publica Hey You!, una pequeña app para Mac con una única función: un minuto antes de cada reunión de tu Google Calendar, pinta todas tus pantallas de rojo con el nombre de la reunión, una cuenta atrás y un botón para unirte. La alerta no desaparece sola. Un clic, Esc o Cmd+Q y se va, pero nadie puede decir que no la vio.

"Sabía que tenía reunión a las once. Miré el reloj a las 10:55 y, cuando volví a mirar, eran las 11:07", cuenta Nico Patarino, su creador. "No es un problema de organización. Es que cuando estás concentrado el tiempo se diluye. Las notificaciones normales son un rectángulo gris en la esquina, exactamente lo que tu cerebro ha aprendido a ignorar. Quería algo que no se pudiera ignorar sin que me tratara como a un niño".

Hey You! vive en la barra de menús, sin icono en el Dock ni ventanas. Se conecta a Google Calendar con el inicio de sesión habitual de Google, en modo solo lectura, y no tiene servidores propios: el calendario nunca sale de tu Mac. Detecta el enlace de Google Meet, Zoom, Teams o Webex del evento y lo abre con una tecla. La versión gratuita avisa siempre un minuto antes de cualquier reunión con hora. **Hey You! Pro**, una compra única, añade el control fino: avisar desde diez segundos antes, no avisar de las reuniones que has rechazado o que no tienen enlace, elegir qué calendarios vigilar, sonido, horario laboral y una estadística semanal de puntualidad.

"La mayoría de apps de reuniones quieren ser tu nueva agenda. Hey You! quiere ser el compañero que te toca el hombro y te dice: eh, tú, que es ahora", añade Patarino.

Hey You! está disponible en la Mac App Store para macOS 14 o posterior. La versión gratuita no tiene límite de tiempo; Hey You! Pro cuesta 5,99 € una sola vez.

### 1.2 FAQ de usuario

**¿No hace ya esto el Calendario de Mac?**
Calendario y Google envían una notificación en la esquina superior derecha. Es exactamente el tipo de aviso que, cuando estás concentrado, desaparece de tu campo visual en dos segundos. Hey You! ocupa toda la pantalla y no se va hasta que tú lo decides.

**¿Me bloquea el ordenador?**
No. Un clic en cualquier punto de la pantalla, Esc o Cmd+Q descartan la alerta al instante. Puedes seguir trabajando en cuanto quieras. Lo único que no puedes hacer es no enterarte.

**¿Qué pasa si estoy compartiendo pantalla o presentando?**
La alerta aparece igual, y si compartes la pantalla completa, la verán. Es deliberado: si estás presentando y tienes otra reunión en un minuto, tienes un problema de verdad y es mejor que lo sepas. No hay modo "no molestar" ni silencio durante reuniones: la alerta se descarta en un clic.

**¿Qué datos lee?**
Solo lectura de tus calendarios de Google: título, hora, enlace de videollamada y tu respuesta (aceptado, rechazado, pendiente). La respuesta se lee para que, con Pro, las reuniones que has rechazado no te salten. No escribe nada, no lee correos ni contactos. Los permisos de Google se los concedes tú en la pantalla de Google y los puedes revocar en myaccount.google.com.

**¿Dónde van mis datos?**
El contenido de tu calendario, a ningún sitio: la app habla directamente con Google desde tu Mac y guarda los tokens en el llavero de macOS. No tenemos servidores propios. Sí recogemos datos de uso (cuándo aparece una alerta, cómo la descartas, qué ajustes usas, versión de macOS) a través de PostHog, alojado en la UE, para mejorar la app. Nunca enviamos títulos de reuniones, enlaces, asistentes ni nombres de calendarios. Puedes desactivarlo en Ajustes en cualquier momento.

**¿Qué incluye Pro?**
Tiempo de aviso de 10 a 60 segundos, no avisar de reuniones rechazadas, sin enlace o sin otros asistentes, elegir calendarios, sonido, horario laboral y tu estadística de puntualidad. Es una compra única, sin suscripción, y vale en todos tus Macs con el mismo Apple ID.

**¿Y si tengo varios monitores?**
La alerta sale en todos a la vez. Da igual dónde estés mirando.

**¿Y si el Mac estaba dormido?**
Al despertar, la app recalcula. Si la reunión aún no ha empezado, verás la alerta inmediatamente. Si ya empezó, verás "Empezó hace X minutos".

**¿Funciona con Outlook, iCloud o el calendario del Mac?**
Todavía no. v1 es solo Google. Si la app funciona para la gente, lo siguiente es el calendario del sistema (que incluye iCloud, Exchange y también Google).

**¿Cuánto cuesta?**
La versión gratuita es gratis para siempre y hace el trabajo esencial. Pro cuesta 5,99 € una sola vez.

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
Es el modo de fallo más probable (ver pre-mortem). La app no tiene "silenciar"; tiene "salir". Y si sale, lo hace a sabiendas. No hay modo "no molestar" ni silencio durante reuniones, ni lo habrá: es una salida fácil a la que no se vuelve.

**¿Por qué freemium y no de pago desde el primer día?**
Un precio de entrada reduce la muestra a casi cero y la app necesita usuarios para aprender. Gratis sin más deja dinero en la mesa y no da señal de valor. Freemium con compra única: la versión gratuita resuelve el problema (alerta a 60 s, unirse con una tecla), así que nadie se siente estafado; Pro vende *control*, que es lo que pide quien ya la usa cada día. Los dos ganchos principales son que te salten las reuniones rechazadas y no poder acortar el aviso: molestias pequeñas, visibles al segundo día y resueltas por 5,99 €.

**¿Por qué compra única y no suscripción?**
Es una utilidad sin coste de servidor (la analítica cuesta céntimos). Una suscripción en una app de este tamaño genera rechazo y reseñas de una estrella. Si en la fase 3 el mantenimiento o nuevas fuentes de calendario lo justifican, se puede añadir un nivel de suscripción para funciones futuras sin quitar nada a quien compró Pro.

**¿Por qué 5,99 €?**
Por encima del umbral de "impulso sin pensar" (2–3 €) para señalar valor, por debajo de In Your Face y de Fantastical. Se prueba con feature flags de PostHog en la fase 3 (4,99 / 5,99 / 7,99).

**¿Por qué analítica, si antes decíamos que no?**
Porque el fundador quiere saber cómo se usa la app y poder hablar con los usuarios más adelante (segmentar, avisar de novedades, recuperar a quien dejó de usarla). Sin eso, la fase 3 se decide a ciegas. El compromiso: PostHog en la UE, consentimiento explícito en el onboarding, nunca contenido del calendario, y un toggle en Ajustes para apagarlo. El coste es una política de privacidad más larga y etiquetas de privacidad en la App Store que digan la verdad.

**¿Qué podemos "targetear" exactamente?**
Con PostHog: cohortes (p. ej. usuarios gratuitos con más de 10 alertas semanales que nunca vieron el paywall), feature flags por cohorte (precio, textos del paywall), encuestas in-app, y, con el consentimiento de contacto, exportar emails a una herramienta de correo. Lo que no podemos: mensajes push (no hay backend ni APNs en v1).

**¿Por qué TCA para algo tan pequeño?**
Porque el fundador lo quiere, porque obliga a aislar efectos (reloj, red, ventanas), y porque permite testear el scheduler y la lógica de disparo de forma determinista con `TestClock`. El coste de aprendizaje lo paga el agente, no un equipo.

**¿Qué no vamos a hacer nunca?**
Backend propio, cuentas propias, escribir en el calendario, enviar contenido del calendario a la analítica, analítica sin consentimiento, publicidad, bloquear al usuario, silenciar alertas durante reuniones, sincronizar con nada que no sea un calendario.

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
│   ├── S2.2 Tiempo configurable 10–60 s                                 ← v1 Pro
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
│   ├── S4.2 Sin backend propio; el calendario no sale del Mac           ← v1
│   └── S4.3 EventKit como alternativa sin OAuth                         ✗ v2
│
├── O5. "La app no está abierta justo el día que la necesito"
│   ├── S5.1 Abrir al iniciar sesión (opt-in)                            ← v1
│   ├── S5.2 Recalcular al despertar el Mac                              ← v1
│   └── S5.3 Indicador en la barra de menús de que está vigilando        ← v1
│
├── O6. "La alerta salta cuando no debe y pierdo la confianza"
│   ├── S6.1 Ignorar eventos de día completo                            ← v1 (base: no tienen hora)
│   ├── S6.2 Ignorar eventos rechazados                                 ← v1 Pro
│   ├── S6.3 Solo eventos con enlace de videollamada                    ← v1 Pro
│   ├── S6.4 Ignorar eventos sin otros asistentes (bloques de foco)     ← v1 Pro
│   ├── S6.5 Elegir qué calendarios vigilar                             ← v1 Pro
│   ├── S6.6 Horario laboral (no avisar fuera de él)                    ← v1 Pro
│   ├── S6.7 Silenciar mientras hay otra reunión en curso               ✗ no-go (decisión del fundador)
│   └── S6.8 Reglas por título o por organizador                        ✗ v2 Pro
│
└── O7. "Quiero saber si esto me está sirviendo" (y nosotros también)
    ├── S7.1 Estadística semanal de puntualidad en el menú              ← v1 Pro
    └── S7.2 Analítica de producto con consentimiento                   ← v1 (interno)
```

Cada feature de v1 cuelga de una oportunidad. Lo que no cuelga de ninguna, no entra.

### 2.3 Job stories

Formato: *Cuando [situación], quiero [motivación], para [resultado].*

- **JS1.** Cuando estoy en un bloque de concentración y tengo una reunión dentro de poco, quiero que algo me interrumpa en el último momento posible, para apurar la concentración sin llegar tarde.
- **JS2.** Cuando la alerta aparece, quiero quitarla con lo primero que toque, para no sentir que la app me castiga ni perder segundos peleándome con ella.
- **JS3.** Cuando la alerta aparece, quiero unirme a la llamada con una tecla, para no buscar el enlace en el correo o el calendario.
- **JS4.** Cuando vuelvo de comer y el Mac estaba dormido, quiero saber al instante si tengo algo en marcha, para no descubrirlo por un mensaje de "¿vienes?".
- **JS5.** Cuando instalo una app que pide mi calendario, quiero ver la pantalla de Google de siempre y entender qué lee, para fiarme sin leer una política de privacidad.
- **JS6.** Cuando tengo una reunión que rechacé o un bloque de foco sin nadie más, no quiero que me interrumpan, para seguir confiando en que cada alerta importa. *(Es el job que vende Pro.)*
- **JS10.** Cuando llevo una semana usando la app, quiero ver si he llegado a tiempo más veces que antes, para saber si merece la pena y, de paso, pagar por ella sin remordimiento.
- **JS7.** Cuando estoy presentando en una reunión y empieza la siguiente, quiero enterarme igual, para avisar y salir a tiempo. *(Se acepta el coste de que la alerta se vea en la pantalla compartida en v1.)*
- **JS8.** Cuando ya he llegado tarde, quiero ver cuánto, para decidir si entro o escribo disculpándome.
- **JS9.** Cuando termino el día, quiero no haber pensado en la app ni una vez, para que sea infraestructura y no otra cosa que gestionar.

---

## 3. DIBB

| | Data | Insight | Belief | Bet |
|---|---|---|---|---|
| **B1** | El fundador llega tarde 3–7 min a varias reuniones por semana pese a tener notificaciones activas. Las notificaciones de macOS se ocultan solas a los ~5 s por defecto. | El fallo no es de recuerdo sino de *saliencia*: el aviso existe pero no compite con la tarea en curso. | Un aviso que ocupe el 100 % del campo visual y no desaparezca por sí solo cambia el comportamiento donde las notificaciones no lo hacen. | Alerta a pantalla completa, persistente hasta interacción. **Métrica:** ≥ 80 % de alertas descartadas con "Unirse" o en los 30 s siguientes al inicio (ver §6). |
| **B2** | Los avisos a 10 o 15 min (los defaults de Google) se posponen mentalmente: "aún tengo tiempo". | A 1 minuto no hay nada que terminar, así que la única acción razonable es unirse. El aviso corto elimina la negociación interna. | 60 s es el máximo útil; algunos querrán apurar más (10–30 s), nadie necesita más de un minuto. | Gratis fijo en 60 s; Pro de 10 a 60 s; nunca más de 60. **Métrica:** ≥ 60 % de usuarios Pro cambian el tiempo en la primera semana (si no, la feature no vende). |
| **B3** | In Your Face y MeetingBar existen y tienen usuarios; MeetingBar supera las 4.000 estrellas en GitHub. | Hay demanda demostrada y el mercado tolera apps mono-función. Pero ninguna combina Google directo + capa gratuita + descarte con cualquier interacción. | Hay espacio para una variante más simple y agresiva, sobre todo entre usuarios de Google Workspace que no configuran el Calendario del Mac. | Lanzar freemium, solo Google, en App Store. **Métrica:** 500 instalaciones en 60 días sin inversión en marketing; retención a 4 semanas ≥ 40 %. |
| **B4** | Una parte de usuarios de Google Workspace no tiene su cuenta en Calendario de Mac (política IT, pereza, no saber que se puede). | Pedir "configura tu cuenta Google en el Mac" como paso previo mata el onboarding. | "Sign in with Google" dentro de la app convierte más que cualquier instrucción. | OAuth directo con el SDK oficial pese al coste de verificación. **Métrica:** ≥ 60 % de los que abren la app completan el sign-in. |
| **B5** | Apps que piden calendario generan desconfianza (comentarios típicos en Reddit/HN: "¿a dónde van mis datos?"). | "Tu calendario no sale de tu Mac" es un mensaje de confianza fuerte, y es compatible con medir uso si se separa con claridad contenido de comportamiento. | Se puede tener analítica sin perder la confianza si el consentimiento es explícito y la lista de lo que NO se envía es concreta. | Sin backend propio; PostHog UE con consentimiento; política que enumera lo que no se envía. **Métrica:** cero reseñas de 1–2 estrellas por privacidad; ≥ 75 % aceptan compartir uso en el onboarding. |
| **B6** | En utilidades de Mac, las compras únicas de 3–10 € convierten entre el 2 % y el 5 % de usuarios activos; los ganchos que mejor convierten son molestias pequeñas y frecuentes, no funciones grandes. | Que te salte una reunión rechazada es una molestia pequeña, frecuente y resuelta por un toggle. Es el paywall perfecto: visible al segundo día. | Pro convertirá si el gancho se ve en la propia alerta ("Rechazada · con Pro no te avisaríamos"). | Freemium, 5,99 € compra única, paywall contextual desde la alerta y desde Ajustes. **Métrica:** conversión gratis→Pro ≥ 4 % a 30 días; ≥ 50 % de compras originadas desde un gancho contextual. |

---

## 4. Pitch (Shape Up)

### Problema
Las personas que trabajan concentradas llegan tarde a reuniones que sabían que tenían, porque los avisos existentes no atraviesan la concentración y los avisos tempranos se posponen mentalmente.

### Apetito
**Tres semanas de calendario** hasta un build enviado a App Store Connect (TestFlight), construido de forma autónoma por un agente. El apetito manda: si a mitad de la segunda semana algo no cabe, se recorta de la lista de §8 empezando por abajo (las funciones Pro se recortan antes que el paywall; el paywall y la analítica son núcleo porque sin ellos no hay negocio ni aprendizaje). No se amplía el plazo. La aprobación de Google y Apple queda fuera del apetito porque no depende de nosotros.

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
│ Esta semana: a tiempo 11 de 12  (Pro)           │
│ ───────────────                                 │
│ Probar alerta                                   │
│ Hey You! Pro…                                   │
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
  │   Solo lectura · tu calendario no sale      │
  │   de tu Mac                                 │
  │                                             │
  │   [✓] Compartir estadísticas de uso anónimas│
  │       (nunca el contenido del calendario)   │
  │   [ ] Avisarme de novedades por email       │
  └────────────────────────────────────────────┘

Paywall (hoja desde Ajustes, el menú o la alerta):
  ┌────────────────────────────────────────────┐
  │   Hey You! Pro                              │
  │   Tú decides cuándo y de qué te avisamos.   │
  │   ✓ Aviso de 10 a 60 segundos               │
  │   ✓ Sin reuniones rechazadas                │
  │   ✓ Solo reuniones con enlace               │
  │   ✓ Sin bloques de foco (solo tú)           │
  │   ✓ Elige calendarios · horario laboral     │
  │   ✓ Sonido · estadística de puntualidad     │
  │   [ Comprar por 5,99 € · una sola vez ]     │
  │   Restaurar compra                          │
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
  │     Click anywhere or press Esc to dismiss      │
  └─────────────────────────────────────────────────┘
```

Flujo: abrir → onboarding (Google + consentimiento) → la app desaparece a la barra → cada 60 s consulta las próximas 24 h → aplica filtros (los Pro solo si hay compra) → calcula el siguiente disparo → duerme hasta `inicio − lead time` → pinta todo de rojo → Enter abre el enlace, cualquier otra cosa descarta → evento de analítica con el motivo y los segundos.

Gancho Pro en la alerta: si el evento está rechazado (o sin enlace, o sin asistentes) y el usuario no es Pro, bajo el título aparece una línea pequeña: "Rechazada · Con Pro no te habríamos avisado". No es un botón; el paywall se abre desde el menú.

### Rabbit holes (con límite explícito)

1. **Ventana sobre apps a pantalla completa y sobre todos los Spaces.** Puede comerse días. Límite: `level = .screenSaver` + `collectionBehavior` con `.fullScreenAuxiliary` y `.canJoinAllSpaces`. Si en 1 día de pruebas no cubre un caso (por ejemplo, un juego en exclusiva de pantalla), se documenta como limitación y se sigue.
2. **Interceptar Cmd+Q sin romper nada.** Límite: monitor local de teclado solo mientras la alerta está visible + `applicationShouldTerminate` devolviendo cancelar. Si da problemas con la revisión de Apple, Cmd+Q pasa a cerrar la app (la alerta se va igualmente) y punto.
3. **Parsing de enlaces de videollamada.** Hay infinitos formatos. Límite: `hangoutLink`, `conferenceData`, y una regex por proveedor sobre `location` y `description`. Lo que no matchee abre el evento en Google Calendar. No se añade un quinto proveedor en v1.
4. **Eventos recurrentes, zonas horarias, día completo.** Límite: siempre pedir a Google `singleEvents=true` para que expanda las recurrencias; usar las fechas con offset que devuelve; excluir `date` sin hora (día completo). Nunca calcular recurrencias nosotros.
5. **Fiabilidad del temporizador con el Mac dormido.** Límite: recalcular en `didWakeNotification` y en cada refresco de 60 s. Si el disparo quedó atrás pero el evento no empezó, disparar ya. No usar `NSBackgroundActivityScheduler` ni launch agents.
6. **El SDK de Google Sign-In en macOS con SwiftPM.** Está soportado, pero sus dependencias (AppAuth, GTM) pueden dar guerra. Límite: 1 día. Si no compila, OAuth propio con PKCE y `ASWebAuthenticationSession`, mismo botón, misma `AuthClient`.
7. **Diseño de la alerta.** Es fácil pasarse semanas. Límite: la especificación de PLAN.md §6, sin iteración abierta. Una pasada de pulido en la fase de QA.
8. **StoreKit 2 y el estado de "Pro".** Recibos, restauración, Family Sharing, sandbox de pruebas. Límite: `Transaction.currentEntitlements` como única fuente de verdad, un producto no consumible, un fichero `.storekit` para probar sin App Store Connect. Sin validación de recibo en servidor (no hay servidor). Si alguien piratea una utilidad de 5,99 €, no es nuestro problema.
9. **Analítica.** Es fácil instrumentar todo y no entender nada. Límite: la taxonomía de §6.1, cerrada; ningún evento nuevo sin pasar por este documento. El SDK de PostHog se encapsula en `AnalyticsClient` para poder cambiarlo.

### No-gos

- No EventKit, Outlook, iCloud ni CalDAV en v1.
- No app de iPhone, ni Watch, ni widget.
- No escribir en el calendario (ni "marcar como asistido", ni nada).
- No unirse automáticamente a la llamada.
- No modo "no molestar", ni snooze, ni silenciar durante reuniones en curso: la alerta se descarta o se descarta.
- No reglas por título, organizador o palabras clave.
- No enviar a la analítica títulos, enlaces, asistentes, descripciones ni nombres de calendarios. Nunca.
- No backend propio, ni cuentas propias, ni sincronización.
- No suscripción en v1. Un producto no consumible.
- No crash reporting de terceros en v1 (App Store Connect basta).
- No lead time por encima de 60 s, ni gratis ni Pro.
- No bloquear Cmd+Tab, el ratón, ni nada que impida al usuario hacer lo que quiera.
- No localizar más allá de inglés y español.

---

## 5. Especificación orientada a decisiones (Linear Method)

Cada subsección dice qué se decide y por qué. Lo que no está aquí, no se ha decidido y el agente usa PLAN.md o su criterio.

### 5.1 Momento del aviso
**Decisión:** un único aviso. Gratis: fijo a 60 s. Pro: deslizador de 10 a 60 s en pasos de 5 s (default 60). Nunca más de 60 s. Sin segundo aviso.
**Por qué:** un aviso temprano se pospone; dos avisos convierten el primero en ruido y el segundo en rutina. A un minuto, la única acción sensata es unirse (B2). El tope de 60 s es identidad de producto: Hey You! avisa cuando ya no hay nada que hacer salvo entrar.

### 5.2 Qué eventos disparan
**Decisión:** eventos con hora de inicio dentro de las próximas 24 h, en todos los calendarios de la cuenta. Los de día completo nunca disparan (no tienen hora; es comportamiento base, no un filtro). Los marcados "libre" (transparencia) sí disparan.
Con **Pro**, además: ignorar rechazados, solo con enlace de videollamada, ignorar eventos sin otros asistentes (bloques de foco), elegir calendarios, horario laboral (p. ej. L–V 8:00–19:00; fuera de él no hay alertas). Todos los filtros Pro vienen activados al comprar salvo "solo con enlace", "calendarios" y "horario", que se configuran.
**Por qué:** cada falso positivo erosiona la confianza (O6); cada falso negativo es el fallo que la app promete evitar. En gratis preferimos el falso positivo (ante la duda, disparar) y lo convertimos en el gancho de Pro (B6). Un usuario gratuito ve en la propia alerta por qué le interesa Pro.

### 5.2.1 Qué es Pro y qué es gratis
| | Gratis | Pro (5,99 €, compra única) |
|---|---|---|
| Alerta a pantalla completa, todas las pantallas, sin auto-cierre | ✓ | ✓ |
| Sign in with Google, todos los calendarios | ✓ | ✓ |
| Unirse con Enter (Meet, Zoom, Teams, Webex) | ✓ | ✓ |
| Abrir al iniciar sesión, menú con próximos eventos | ✓ | ✓ |
| "Empezó hace X min", recálculo al despertar | ✓ | ✓ |
| Probar alerta | ✓ | ✓ |
| Tiempo de aviso 10–60 s | 60 s fijo | ✓ |
| Ignorar reuniones rechazadas | ✗ | ✓ |
| Solo reuniones con enlace | ✗ | ✓ |
| Ignorar bloques sin otros asistentes | ✗ | ✓ |
| Elegir qué calendarios vigilar | ✗ | ✓ |
| Horario laboral | ✗ | ✓ |
| Sonido al aparecer (elegir entre 5 o ninguno) | sonido fijo | ✓ |
| Countdown "Xm" en la barra de menús | ✗ | ✓ |
| Estadística semanal de puntualidad | ✗ | ✓ |

Ideas Pro para v2 (no en v1): tema de color de la alerta, atajo global para unirse a la próxima reunión, aviso de fin de reunión ("quedan 2 min"), reglas por palabra clave, otras fuentes de calendario (EventKit), varias cuentas de Google, mensaje personalizado en la alerta, exportar estadísticas.

### 5.3 Dos eventos a la vez
**Decisión:** una sola alerta con el primer evento por orden alfabético; el segundo se marca como disparado. La alerta muestra "+1 más" bajo el título.
**Por qué:** dos alertas simultáneas se pisan. El usuario ya sabe que tiene solape; nuestro trabajo es que mire la pantalla.

### 5.4 Comportamiento de la alerta
**Decisión:** una ventana sin borde por pantalla, nivel screenSaver, sobre todos los Spaces y apps a pantalla completa, sin auto-cierre. Descarta: clic en cualquier punto (también clic derecho), Esc, Cmd+Q, Cmd+W, Cmd+punto. Enter o clic en "Unirse" abre el enlace y descarta. El resto de teclas (letras, espacio, flechas, otros atajos) no hacen nada. Durante el primer segundo tras aparecer se ignora cualquier clic o tecla. Mientras hay alerta, Cmd+Q no cierra la app. Si llega otra alerta mientras hay una visible, la reemplaza. Al pasar la hora de inicio, "AHORA" durante 60 s y luego "EMPEZÓ HACE X MIN".
**Por qué:** la intrusión está en la *aparición*, no en la *permanencia obligada*. Cualquier fricción para descartar sería castigo, y el castigo hace que se desinstale (decisión 2 de la página 0). Interceptamos Cmd+Q porque es el reflejo de "quítame esto" y queremos que ese reflejo funcione sin matar al vigilante. *Revisado el 2026-10-29:* en la primera prueba real la alerta apareció mientras el fundador escribía y una pulsación que ya estaba en marcha la quitó sin que la viera. Por eso solo descartan las teclas que se pulsan a propósito para cerrar (Esc y los atajos de cerrar/salir), y el primer segundo ignora toda entrada.

### 5.5 Sonido
**Decisión:** un sonido corto del sistema al aparecer, activado por defecto, desactivable. No se repite.
**Por qué:** cubre el caso de mirar al otro monitor o a la ventana. Repetirlo sería castigo.

### 5.6 Autenticación y datos
**Decisión:** SDK oficial de Google Sign-In, scope `calendar.readonly` (+ `openid email` para mostrar la cuenta), tokens gestionados por el SDK en el llavero. Una sola cuenta de Google en v1. Sin backend propio.
**Por qué:** B4 y B5. Varias cuentas multiplican la complejidad del onboarding y de la lista de calendarios; el 90 % de los usuarios tiene una cuenta de trabajo.

### 5.6.1 Analítica
**Decisión:** PostHog Cloud EU, SDK oficial para macOS, encapsulado en `AnalyticsClient`. Consentimiento en el onboarding con dos toggles independientes: "Compartir estadísticas de uso" (activado por defecto, desactivable en Ajustes) y "Avisarme de novedades por email" (desactivado por defecto). Identificación: `distinct_id` = UUID generado en el primer arranque; al iniciar sesión se añade como propiedad de persona el hash SHA-256 del email; el email en claro solo se envía si el segundo toggle está activado. Taxonomía de eventos cerrada en §6.1. Feature flags de PostHog para precio y textos del paywall. Sin session replay.
**Por qué:** el fundador quiere saber cómo se usa la app y poder segmentar y contactar usuarios. PostHog da eventos, cohortes, flags y encuestas en un solo sitio, con alojamiento en la UE y plan gratuito suficiente para los primeros miles de usuarios. El consentimiento explícito y la separación contenido/comportamiento mantienen la promesa de B5. El toggle de uso viene activado por defecto porque sin datos no hay fase 3; el de email, desactivado, porque el marketing por correo en la UE lo exige.

### 5.6.2 Compra
**Decisión:** StoreKit 2, un producto no consumible `com.patarino.heyyou.pro`, 5,99 € (tier equivalente en cada país), Family Sharing activado. Estado Pro derivado exclusivamente de `Transaction.currentEntitlements`, cacheado en `@Shared` para arrancar sin red, y re-verificado en cada arranque y en `Transaction.updates`. Botón "Restaurar compra" en el paywall y en Ajustes. Paywall accesible desde el menú ("Hey You! Pro…"), desde cada ajuste bloqueado (candado) y desde Ajustes. En la alerta, solo la línea de gancho, sin botón.
**Por qué:** compra única (ver FAQ interna). Sin servidor no hay validación de recibo; StoreKit 2 verifica la firma localmente y es lo que Apple recomienda. Un botón de compra dentro de la alerta roja sería de mal gusto y Apple podría considerarlo manipulador.

### 5.7 Sincronización
**Decisión:** polling cada 60 s de los eventos entre ahora y +24 h, en todos los calendarios seleccionados, con `singleEvents=true&orderBy=startTime&fields=…`. Sin push, sin sync tokens, sin caché persistente.
**Por qué:** 1 petición por minuto por calendario está órdenes de magnitud por debajo de los límites de Google, el estado se reconstruye desde cero en cada ciclo (sin bugs de caché) y los eventos creados hace menos de un minuto quedan cubiertos. Push requeriría backend (no-go).

### 5.8 Presencia en el sistema
**Decisión:** solo barra de menús (`LSUIElement`), icono SF Symbol `bell`; con Pro, texto "Xm" cuando quedan menos de 10 min para la próxima reunión. Menú con próximos 5 eventos del día, estado, línea de puntualidad semanal (Pro; en gratis muestra "Estadística de puntualidad · Pro"), "Probar alerta", "Hey You! Pro…" (oculto si ya es Pro), "Ajustes…", "Salir". Abrir al iniciar sesión como toggle opt-in, sugerido en el onboarding.
**Por qué:** O5. El indicador de la barra responde a "¿está vigilando?" sin abrir nada. "Probar alerta" es la primera cosa que hace cualquiera después de instalar; que esté a un clic.

### 5.9 Onboarding
**Decisión:** una sola pantalla, abierta automáticamente la primera vez, con tres frases, el botón de Google, la nota "solo lectura · tu calendario no sale de tu Mac" y los dos toggles de consentimiento (§5.6.1). Tras el sign-in, muestra un toggle "Abrir al iniciar sesión" (recomendado) y un botón "Probar la alerta". Cierre automático. No se menciona Pro en el onboarding.
**Por qué:** JS5 y JS9. El usuario debe entender en 10 segundos qué hace la app y qué no, y ver la alerta antes de que le pille por sorpresa en una reunión real.

### 5.10 Errores
**Decisión:** si Google devuelve 401 y el refresh falla: estado "desconectado" visible en la barra (icono `bell.slash`) y en el menú, con botón para volver a iniciar sesión. Sin red: se mantiene la última lista de eventos en memoria y se sigue disparando con ella; el menú muestra "sin conexión desde hh:mm". Nunca una alerta modal de error.
**Por qué:** una app de vigilancia que se calla sin avisar es peor que no tenerla. El estado tiene que verse de un vistazo, sin molestar.

### 5.11 Distribución y precio
**Decisión:** Mac App Store, descarga gratuita con compra única "Hey You! Pro" a 5,99 €, macOS 14+, en inglés y español. Sin distribución fuera de la App Store en v1.
**Por qué:** B3 y B6. La App Store da confianza (sandbox, firma) a una app que pide el calendario, resuelve el cobro y es el canal que pidió el fundador. Notarización y venta directa duplican trabajo sin aportar al aprendizaje de la fase 2.

### 5.12 Lo que explícitamente no se decide todavía
Precio definitivo (se prueba con flags en fase 3). EventKit (fase 3, como Pro). Qué funciones Pro de v2 entran primero (RICE con datos reales). Segunda cuenta de Google (nunca, salvo demanda clara).

---

## 6. Métricas

Todo lo de esta sección se mide en PostHog con los eventos de §6.1, más App Store Connect para descargas, crashes e ingresos.

### 6.1 Taxonomía de eventos (cerrada)

Reglas: nombres en `snake_case`, pasado; nunca títulos, enlaces, asistentes, descripciones ni nombres de calendario; tiempos en segundos enteros; cada evento lleva automáticamente `app_version`, `macos_version`, `locale`, `is_pro`.

| Evento | Propiedades | Para qué |
|---|---|---|
| `app_launched` | `launch_at_login: bool`, `days_since_install` | Actividad, retención |
| `onboarding_viewed` | | Embudo |
| `signin_started` / `signin_completed` / `signin_failed` | `error_type` | Embudo B4 |
| `consent_changed` | `usage: bool`, `email: bool`, `source: onboarding\|settings` | Consentimiento |
| `calendar_synced` | `calendars_count`, `events_24h_count`, `events_with_link_count`, `duration_ms`, `error_type?` | Salud |
| `alert_scheduled` | `seconds_until_fire` | Sanidad del scheduler |
| `alert_shown` | `lead_time`, `provider: meet\|zoom\|teams\|webex\|other\|none`, `screens_count`, `is_declined`, `has_other_attendees`, `overlapping_count`, `trigger: scheduled\|wake\|test`, `pro_hook_shown: declined\|no_link\|solo\|none` | North Star, ganchos |
| `alert_dismissed` | `reason: join\|click\|escape\|quit_shortcut\|replaced`, `seconds_shown`, `seconds_to_start` (negativo si ya empezó), `provider` | North Star, guardarraíles |
| `test_alert_triggered` | `source: menu\|onboarding\|settings` | Onboarding |
| `setting_changed` | `key`, `value` (solo claves no sensibles: lead_time, filtros, sonido, launch_at_login, horario) | Uso de Pro |
| `paywall_viewed` | `source: menu\|settings_lock\|alert_hook\|stats`, `price_variant` | Conversión |
| `purchase_started` / `purchase_completed` / `purchase_failed` / `purchase_restored` | `price_variant`, `error_type` | Ingresos |
| `signout` | | Churn |
| `app_quit` | `alert_visible: bool` | Churn, guardarraíl |
| `error_occurred` | `type`, `code` | Salud |

Propiedades de persona: `email_hash`, `email` (solo con consentimiento), `is_pro`, `pro_purchased_at`, `lead_time`, `calendars_count`, `launch_at_login`, `install_date`, `weekly_meetings_bucket` (0–2, 3–10, 11–25, 25+), `locale`.

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
- Conversión gratis → Pro a 30 días (objetivo ≥ 4 %, B6).
- Compras originadas desde un gancho contextual (`paywall_viewed.source = alert_hook` o `settings_lock`) / compras totales (objetivo ≥ 50 %).
- Usuarios Pro que cambian el lead time en la primera semana (objetivo ≥ 60 %, B2).
- Consentimiento de uso aceptado en onboarding (objetivo ≥ 75 %; por debajo, revisar el texto).

### Guardarraíles (si se cruzan, se revisa el producto)
- Alertas descartadas en < 2 s sin unirse > 30 %: la alerta se ha vuelto ruido o salta mal.
- Alertas de eventos sin enlace > 50 %: revisar el default de "solo con enlace".
- Reseñas ≤ 2 estrellas que mencionen "molesta", "no puedo cerrar" o "privacidad".
- Tasa de crash > 1 % de sesiones (App Store Connect).
- Usuarios que desactivan "abrir al iniciar sesión" después de activarlo > 25 %.
- Usuarios que desactivan la analítica después del onboarding > 15 %: el texto o la práctica generan desconfianza.
- Reembolsos de Pro > 5 %.

### Métrica de parada
Si a las 8 semanas del lanzamiento la retención a 4 semanas es < 15 % **y** la tasa de reacción útil es < 50 %, el producto no cambia el comportamiento: se congela v1 y no se invierte en fase 3. Si la retención es buena pero la conversión a Pro es < 1 %, el producto funciona y el modelo no: se revisa el paquete Pro y el precio, no el producto.

---

## 7. Pre-mortem e hipótesis más arriesgada

### 7.1 Pre-mortem: es marzo de 2027 y Hey You! ha fracasado. ¿Por qué?

| # | Causa del fracaso | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | **La gente la desinstala a la semana porque le molesta.** La alerta funcionaba, pero la sensación de "me gritan" ganó. | Alta | Fatal | Descarte instantáneo con un clic, Esc o Cmd+Q; filtros por defecto sensatos; "Probar alerta" en onboarding para que nadie se sorprenda; medir descartes < 2 s como guardarraíl. |
| 2 | **Google tardó dos meses en verificar la app** y no pudimos publicar a nadie fuera de 100 testers. | Media | Alto | Solicitar verificación en la semana 2 con un build estable; tener web y política de privacidad listas antes; plan B: EventKit en v1.1 si la verificación se eterniza. |
| 3 | **Apple rechazó la app** por interceptar Cmd+Q, por ser "solo una notificación" (regla 4.2, funcionalidad mínima) o por el login de terceros. | Media | Alto | Notas al revisor citando la excepción de 4.8; Cmd+Q interceptado documentado como "descartar"; onboarding y ajustes visibles; fallback: no interceptar Cmd+Q. Sobre 4.2: In Your Face está publicada, hay precedente. |
| 4 | **La alerta no aparece** sobre ciertas apps (pantalla completa, juegos, pantallas compartidas de Zoom) y el usuario llega tarde *con la app instalada*. | Media | Fatal | Probar explícitamente sobre Safari fullscreen, Zoom compartiendo, Keynote presentando, VS Code fullscreen (casos B.9–B.12). Documentar lo que no cubra. |
| 5 | **El temporizador falla tras dormir el Mac**, o la app muere en background y nadie se da cuenta. | Media | Fatal | Recalcular al despertar; refresco de 60 s; indicador en la barra; test B.6. |
| 6 | **Nadie la encuentra.** 40 descargas en dos meses. | Alta | Medio | Es un problema de distribución, no de producto. Post en HN/Reddit/X con el GIF de la alerta; página web con el "porqué"; pedir reseñas a los testers. No afecta a la validez del producto para el fundador. |
| 7 | **In Your Face ya lo hace mejor** y la comparación nos deja como copia inferior. | Media | Medio | Probarla antes (fase 0). Diferenciar en lo que decidimos: gratis, Google directo, descarte con todo, sin configuración. Si no hay diferencia perceptible, reconsiderar antes de construir. |
| 8 | **El SDK de Google en macOS da problemas** y se queman días de apetito. | Media | Medio | Límite de 1 día (rabbit hole 6); fallback a OAuth propio. |
| 9 | **Falsos positivos** (eventos rechazados, de día completo, calendarios de cumpleaños) hacen que el usuario deje de creer en la alerta. | Media | Alto | Filtros por defecto; selección de calendarios; mostrar "+1 más" en solapes. |
| 10 | **El agente construye algo que compila pero no funciona de verdad** porque no pudo probarlo sin Xcode. | Alta (hoy) | Alto | Instalar Xcode antes de empezar. Hito 7 de PLAN.md es obligatorio y manual. |
| 11 | **Nadie compra Pro** porque la versión gratuita ya resuelve el problema y los ganchos no duelen. | Media | Alto para el negocio, nulo para el usuario | Ganchos visibles en la alerta; medir `paywall_viewed` por fuente; probar precio con flags. Si a los 60 días la conversión es < 1 %, mover "ignorar rechazados" a gratis y subir "lead time" a gancho principal, o viceversa. |
| 12 | **La analítica genera rechazo** ("¿para qué necesita una app de alertas mandar datos?") y reseñas negativas. | Media | Medio | Texto claro en onboarding con la lista de lo que NO se envía; toggle a un clic en Ajustes; UE; etiquetas de privacidad honestas. Guardarraíl de desactivación > 15 %. |
| 13 | **Apple rechaza el paywall** (regla 3.1.1) por un gancho dentro de la alerta que parezca presión, o por no tener "Restaurar compra". | Baja | Medio | El gancho en la alerta es texto, no botón. Restaurar en paywall y en Ajustes. Precio visible antes de comprar. |

### 7.2 Hipótesis más arriesgada

> **Si una alerta ocupa toda la pantalla un minuto antes y no se va sola, la persona concentrada se une a tiempo y, además, no desinstala la app por molesta.**

Si esto es falso, da igual lo bien hecho que esté todo lo demás. Tiene dos mitades que pueden fallar por separado: (a) eficacia, (b) tolerancia.

### 7.3 Tests baratos antes de construir (fase 0, una semana)

1. **Wizard of Oz con 50 líneas.** Un script Swift (o incluso un AppleScript lanzado por un atajo de Automator) que, al ejecutarse, muestra una ventana roja a pantalla completa con un texto y se cierra con cualquier tecla. Se programa con `at`/`launchd` o se lanza a mano un minuto antes de cada reunión del fundador durante 5 días laborables. Mide: ¿cuántas veces llegó a tiempo? ¿Cuántas veces le molestó? ¿Cambió algo frente a la semana anterior? Coste: 2 horas.
2. **Probar In Your Face una semana** (competidor existente, de pago, pequeño). Si resuelve el problema al 100 % y no molesta, la pregunta pasa a ser "¿por qué construir otra?". Si molesta o falla en algo concreto, eso es la hoja de ruta. Coste: el precio de la app.
3. **Cinco conversaciones de diez minutos** con personas del perfil (JS1) preguntando solo dos cosas: "¿cuándo fue la última vez que llegaste tarde a una reunión que sabías que tenías?" y "si tu pantalla entera se pusiera roja un minuto antes, ¿la dejarías puesta una semana?". Buscamos repulsión o entusiasmo, no cortesía.
4. **Prueba del guardarraíl de tolerancia**: en la semana del Wizard of Oz, contar cuántas veces el fundador sintió el impulso de desactivarlo. Si > 2, la hipótesis (b) está en peligro y hay que suavizar (sonido, animación) antes de construir.

5. **Test de precio de pasillo.** En las cinco conversaciones, al final: "¿pagarías 5,99 € una vez para que no te avise de las reuniones que has rechazado y para poder acortar el aviso a 20 segundos?". Buscamos un "sí, claro" inmediato o un "¿por eso? no". Si tres de cinco dicen "no, por eso no", el paquete Pro está mal elegido antes de escribirlo.

Criterio: si en la fase 0 el fundador llega a tiempo a ≥ 90 % de las reuniones con la alerta de mentira y no la desactiva, se construye. Si no, se revisa el pitch antes de gastar el apetito.

---

## 8. Priorización RICE

Reach: usuarios afectados de cada 100 activos al mes. Impact: 3 masivo, 2 alto, 1 medio, 0,5 bajo, 0,25 mínimo. Confidence: 100 / 80 / 50 %. Effort: días-persona (de agente supervisado). Score = R × I × C / E.

| # | Feature | R | I | C | E | Score | v1 |
|---|---|---|---|---|---|---|---|
| 1 | Alerta a pantalla completa en todas las pantallas, sin auto-cierre, descarte con clic, Esc o Cmd+Q | 100 | 3 | 80 % | 3 | 80 | ✅ núcleo |
| 2 | Scheduler: polling, cálculo del siguiente disparo, dedupe, wake | 100 | 3 | 100 % | 2 | 150 | ✅ núcleo |
| 3 | Sign in with Google + lectura de calendarios | 100 | 3 | 80 % | 3 | 80 | ✅ núcleo |
| 4 | Botón Unirse con detección de Meet/Zoom/Teams/Webex | 85 | 2 | 100 % | 1 | 170 | ✅ núcleo |
| 5 | Barra de menús con próximos eventos y estado | 100 | 1 | 100 % | 1,5 | 67 | ✅ núcleo |
| 6 | Onboarding de una pantalla con consentimiento | 100 | 1 | 100 % | 1 | 100 | ✅ núcleo |
| 7 | Abrir al iniciar sesión | 90 | 2 | 100 % | 0,5 | 360 | ✅ núcleo |
| 8 | "Probar alerta" en menú y onboarding | 100 | 1 | 100 % | 0,25 | 400 | ✅ núcleo |
| 9 | Analítica PostHog con taxonomía §6.1 y consentimiento | 100 | 2 | 80 % | 1,5 | 107 | ✅ núcleo |
| 10 | Paywall + StoreKit 2 + estado Pro + restaurar | 100 | 3 | 80 % | 2 | 120 | ✅ núcleo |
| 11 | "Empezó hace X min" tras el inicio | 60 | 1 | 80 % | 0,25 | 192 | ✅ |
| 12 | Estado de error visible (desconectado, sin red) | 30 | 2 | 80 % | 0,5 | 96 | ✅ |
| 13 | Localización inglés + español | 100 | 0,5 | 100 % | 0,5 | 100 | ✅ |
| 14 | Pro: ignorar rechazados + gancho en la alerta | 70 | 2 | 80 % | 0,5 | 224 | ✅ Pro |
| 15 | Pro: lead time 10–60 s | 40 | 1 | 80 % | 0,25 | 128 | ✅ Pro |
| 16 | Pro: solo con enlace + gancho | 50 | 1 | 80 % | 0,25 | 160 | ✅ Pro |
| 17 | Pro: ignorar sin otros asistentes + gancho | 40 | 1 | 80 % | 0,25 | 128 | ✅ Pro |
| 18 | Pro: selección de calendarios | 50 | 1 | 80 % | 1 | 40 | ✅ Pro |
| 19 | Pro: sonido elegible (5 + ninguno) | 60 | 0,5 | 80 % | 0,5 | 48 | ✅ Pro |
| 20 | Pro: countdown "Xm" en la barra | 50 | 0,5 | 80 % | 0,25 | 80 | ✅ Pro |
| 21 | Pro: estadística semanal de puntualidad | 40 | 1 | 50 % | 1 | 20 | ✅ Pro |
| 22 | Pro: horario laboral | 30 | 1 | 50 % | 0,75 | 20 | ✅ Pro |
| 23 | Pro v2: tema de color de la alerta | 30 | 0,5 | 50 % | 0,5 | 15 | ✗ v2 |
| 24 | Pro v2: atajo global "unirse a la próxima" | 25 | 1 | 50 % | 0,5 | 25 | ✗ v2 |
| 25 | Pro v2: aviso de fin de reunión | 30 | 1 | 50 % | 1 | 15 | ✗ v2 |
| 26 | Pro v2: EventKit (iCloud, Exchange, Outlook) | 50 | 2 | 80 % | 2 | 40 | ✗ v2 |
| 27 | Pro v2: reglas por palabra clave | 20 | 1 | 50 % | 1,5 | 7 | ✗ v2 |
| 28 | Varias cuentas de Google | 15 | 1 | 50 % | 2 | 4 | ✗ |
| 29 | App de iPhone / Watch | 30 | 1 | 50 % | 10 | 1,5 | ✗ |

**Orden de recorte si el apetito no alcanza** (se quita primero lo de arriba): 22 → 21 → 19 (sonido fijo para todos) → 20 → 18 (todos los calendarios) → 13 (solo inglés) → 12 (solo icono tachado) → 17. Los puntos 1–10 son el núcleo y no se recortan: sin ellos no hay producto ni negocio. Pro se lanza como mínimo con 14, 15 y 16: tres ganchos claros bastan para validar B6.

---

## 9. Ejecución por fases

| Fase | Qué | Duración | Criterio de salida | Criterio de parada |
|---|---|---|---|---|
| **0. Validación** | Wizard of Oz, probar In Your Face, 5 conversaciones (§7.3). Instalar Xcode. Crear OAuth client y cuenta de desarrollador. | 1 semana | Fundador a tiempo ≥ 90 % con la alerta falsa; no la desactivó; ≥ 3 de 5 personas dicen "lo probaría". Xcode operativo. | Fundador la desactivó por molesta, o In Your Face resolvió el problema sin pegas. → Revisar pitch. |
| **1. Construcción** | Hitos 1–6 de PLAN.md por el agente. Verificación OAuth de Google solicitada en cuanto hay build. Crear el producto IAP en App Store Connect y el proyecto PostHog. | 2 semanas | Build Debug ejecutable; `swift test` verde; casos B.1–B.9 y B.16–B.19 pasan con calendario y tienda mock. | Mitad de semana 2 sin alerta funcionando sobre apps a pantalla completa. → Recortar según §8 o replantear ventana. |
| **2. QA y lanzamiento** | Hitos 7–9 de PLAN.md. Casos B.10–B.15 y B.20 a mano. TestFlight con 5–10 personas una semana (compra en sandbox). Envío a App Store. | 1 semana + revisión | Todos los casos del anexo B pasan; 0 crashes en TestFlight; eventos llegando a PostHog; aprobación de Apple. | Apple rechaza dos veces por lo mismo. → Quitar la causa (p. ej. Cmd+Q, gancho en alerta) y reenviar. |
| **3. Aprendizaje** | 8 semanas en producción. Dashboards de §6 en PostHog. Experimento de precio con flags. Decidir paquete Pro v2 y EventKit. | 8 semanas | Retención 4 sem ≥ 40 %, reacción útil ≥ 80 %, conversión ≥ 4 % → v2 con RICE 23–27. | Métrica de parada (§6). → Congelar, o rehacer el paquete Pro si solo falla la conversión. |

Las fases 0 y 1 pueden solaparse parcialmente (el agente puede empezar el hito 1–2 mientras el fundador hace el Wizard of Oz), pero **no se pasa del hito 4 sin haber cerrado la fase 0**.

---

## Anexo A — Glosario

- **Alerta**: la toma de pantalla roja. No confundir con notificación de macOS.
- **Lead time**: segundos antes del inicio del evento en que se dispara la alerta. 60 en gratis; 10–60 en Pro.
- **Pro**: compra única no consumible que desbloquea los ajustes de §5.2.1.
- **Gancho (hook)**: línea de texto en la alerta que explica qué habría hecho Pro con ese evento.
- **Disparo (fire)**: momento `inicio − lead time`.
- **Reacción útil**: descartar con "Unirse", o descartar en los 30 s posteriores al inicio.
- **Persona concentrada**: la persona usuaria descrita en §2.1.

## Anexo B — Casos de prueba con datos reales

Zona horaria del Mac: Europe/Madrid (CET, UTC+1 en estas fechas). Formato Given / When / Then. Los casos B.1–B.9 y B.16–B.19 son automatizables con `TestClock`, el calendario mock y la tienda mock; B.10–B.15 y B.20 son manuales en el hito 7.

**B.1 Disparo básico**
- Given: ahora es 2026-11-03 10:58:30; evento "Weekly sync" 11:00–11:30 con `hangoutLink = https://meet.google.com/abc-defg-hij`, estado `accepted`; lead time 60 s.
- When: el reloj llega a 10:59:00.
- Then: la alerta aparece en todas las pantallas con "MEETING IN", "60s", "Weekly sync", "11:00 – 11:30 · Google Meet" y botón "Join meeting"; suena una vez.

**B.2 Enter abre el enlace**
- Given: alerta de B.1 visible a las 10:59:12.
- When: el usuario pulsa Enter.
- Then: se abre `https://meet.google.com/abc-defg-hij` en el navegador por defecto, la alerta desaparece con fade de 0,25 s, el evento queda marcado como disparado.

**B.3 Descarte deliberado**
- Given: alerta visible.
- When: (a) clic en una zona vacía del fondo, (b) Esc, (c) Cmd+Q, (d) Cmd+W, (e) clic derecho.
- Then: en los cinco casos la alerta desaparece y **la app sigue ejecutándose** (icono en la barra presente). No se abre ningún enlace.
- When: tecla `j`, espacio o una flecha. Then: no pasa nada; la alerta sigue visible.
- When: cualquier clic o tecla (también Enter) en el primer segundo tras aparecer. Then: se ignora; la alerta sigue visible.

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

**B.8 Filtros: gratis frente a Pro**
- Given: ahora 2026-11-03 08:00; eventos: "Cumpleaños de Marta" (día completo, 2026-11-03), "Retro" 09:00 con estado `declined` y enlace Meet, "Foco" 09:30–11:00 sin asistentes ni enlace, "Demo cliente" 10:00 con `location = "https://zoom.us/j/91234567890?pwd=abc"` y 4 asistentes.
- When (usuario **gratis**): se calcula el siguiente disparo.
- Then: el siguiente es "Retro" a las 08:59:00 (rechazada, pero en gratis dispara) con gancho `pro_hook_shown = declined`; después "Foco" a las 09:29:00 con gancho `solo`; después "Demo cliente" a las 09:59:00 sin gancho. "Cumpleaños" nunca dispara.
- When (usuario **Pro** con `ignoreDeclined`, `ignoreSolo` activados, `onlyWithLink` desactivado): el siguiente es "Demo cliente" a las 09:59:00, proveedor Zoom. Con `onlyWithLink = true` el resultado es el mismo. Con `leadTime = 20`, el disparo es a las 09:59:40.

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
- Then: en 5 s aparece una alerta con un evento ficticio "Hey You! test" con enlace a la página del proyecto; Enter lo abre; cualquier otra cosa la quita. Se envía `alert_shown` con `trigger = test` y `alert_dismissed` con el motivo.

**B.16 Lead time limitado**
- Given: usuario Pro; en Ajustes mueve el deslizador.
- Then: los valores posibles son 10, 15, 20 … 60; no existe 5 ni 65. Usuario gratis: el deslizador aparece bloqueado en 60 con candado; clic en el candado → `paywall_viewed` con `source = settings_lock`.

**B.17 Compra y entitlement**
- Given: usuario gratis, fichero `.storekit` local, paywall abierto desde el menú.
- When: compra `com.patarino.heyyou.pro` en sandbox.
- Then: `purchase_completed`, el paywall se cierra, en Ajustes desaparecen los candados, `ignoreDeclined` e `ignoreSolo` quedan activados por defecto, el menú deja de mostrar "Hey You! Pro…", el icono muestra "Xm" cuando toca. Tras reiniciar la app sin red, sigue siendo Pro (caché).

**B.18 Restaurar compra**
- Given: Pro comprado en otro Mac con el mismo Apple ID; app recién instalada.
- When: Ajustes → "Restaurar compra".
- Then: `purchase_restored`, estado Pro activo sin pasar por el paywall.

**B.19 Consentimiento y contenido**
- Given: onboarding con "Compartir estadísticas de uso" desactivado.
- When: ocurre todo B.1–B.3.
- Then: PostHog no recibe ningún evento (`AnalyticsClient` descarta en origen; no se encola). Al activarlo en Ajustes, `consent_changed` es el primer evento. Con cualquier consentimiento, una inspección del tráfico a PostHog no contiene la cadena "Weekly sync" ni "meet.google.com".

**B.20 Horario laboral (manual)**
- Given: Pro con horario L–V 09:00–18:00; evento el sábado 2026-11-07 a las 10:00.
- Then: no hay alerta; el menú muestra el evento con un icono de luna y "fuera de horario". Evento el lunes 2026-11-09 a las 08:30: tampoco (empieza antes de las 09:00). Evento el lunes a las 17:59: sí.
