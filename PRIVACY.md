# Privacy Policy — Hey You!

*Last updated: 29 October 2026* · [Español más abajo](#política-de-privacidad--hey-you)

Published at <https://chimi.pro/legal/hey-you/privacy> (English) and <https://chimi.pro/legal/hey-you/privacidad> (español). Keep this file and those pages (repo `cv-blog`, `src/pages/legal/hey-you/`) in sync.

Hey You! is a macOS menu-bar app that shows a full-screen alert one minute before your Google Calendar meetings. It is built by Nicolás Patarino ("we"). Contact: hola@chimi.pro.

## What the app reads from Google

With your permission, given on Google's own screen, Hey You! gets **read-only** access to your Google Calendar (`calendar.readonly`) and your email address. For the next 24 hours it reads each event's title, start and end time, video-call link, location, description (only to find a video link), whether other people are invited and your response (accepted, declined…).

- This data is used **only on your Mac** to decide when to alert you and what to show.
- It is **never sent to us or to anyone else**. We have no servers. The app talks directly to Google.
- It is kept in memory only; nothing about your calendar is written to disk.
- Your Google sign-in tokens are stored in the macOS Keychain by Google's official Sign-In library.
- The app never writes to your calendar and never reads your email or contacts.
- You can revoke access at any time at <https://myaccount.google.com/permissions> or with **Settings → Disconnect**.

Hey You!'s use of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

## Usage statistics (optional)

If **Share anonymous usage statistics** is on (you choose in the welcome window, and can change it any time in Settings → Privacy), the app sends usage events to PostHog, hosted in the **European Union** (`eu.i.posthog.com`). In plain words, these events say:

- the app started (whether it opens at login, days since install), the welcome window was shown, sign-in started/finished/failed (error type only);
- your consent choices changed;
- the calendar was synced (how many calendars and events, how many have a video link, how long it took, error type);
- an alert was scheduled, shown and dismissed (lead time, video provider such as "zoom", number of screens, whether you had declined, whether others were invited, how many meetings overlapped, how you dismissed it and how many seconds before/after the start);
- you pressed "Test alert", changed a setting (lead time, filters, sound, working hours on/off, number of calendars), opened the Pro screen, started/completed/restored a purchase;
- you signed out or quit; an error happened (type and code).

Every event also carries the app version, macOS version, your locale and whether you have Pro. You are identified by a random ID created on your Mac plus a one-way hash (SHA-256) of your email.

**What is never sent:** meeting titles, descriptions, links, locations, attendees or organisers, calendar names, your email address (unless you opt in below), your contacts, or anything you type.

With the toggle off, nothing is sent at all — events are dropped on your Mac, not queued.

## Email about new features (optional, off by default)

Only if you turn on **Email me about new features**, your email address is added to your PostHog profile so we can write to you about the app. Turn it off at any time in Settings → Privacy.

## Purchases

Hey You! Pro is bought through Apple's App Store. Apple handles payment; we never see your payment details. The app only asks the App Store whether you own Pro.

## Children

Hey You! is not directed at children under 16.

## Your rights

You can ask us to delete the usage data linked to your ID or email hash by writing to hola@chimi.pro. Turning the toggle off stops all future collection.

## Changes

If this policy changes, the new version will be published at this address with a new date.

---

# Política de privacidad — Hey You!

*Última actualización: 29 de octubre de 2026*

Hey You! es una app de barra de menús para macOS que muestra una alerta a pantalla completa un minuto antes de tus reuniones de Google Calendar. La desarrolla Nicolás Patarino. Contacto: hola@chimi.pro.

## Qué lee de Google

Con tu permiso, que das en la pantalla de Google, Hey You! tiene acceso **de solo lectura** a tu Google Calendar y a tu dirección de email. De las próximas 24 horas lee de cada evento: título, hora de inicio y fin, enlace de videollamada, ubicación, descripción (solo para buscar un enlace), si hay más invitados y tu respuesta (aceptada, rechazada…).

- Estos datos se usan **solo en tu Mac** para decidir cuándo avisarte y qué mostrar.
- **Nunca se envían a nosotros ni a nadie.** No tenemos servidores; la app habla directamente con Google.
- Se guardan solo en memoria; nada de tu calendario se escribe en disco.
- Los tokens de Google se guardan en el llavero de macOS mediante la librería oficial de Google.
- La app nunca escribe en tu calendario ni lee tu correo o tus contactos.
- Puedes revocar el acceso en <https://myaccount.google.com/permissions> o en **Ajustes → Desconectar**.

El uso que Hey You! hace de la información recibida de las APIs de Google cumple la [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), incluidos los requisitos de uso limitado.

## Estadísticas de uso (opcional)

Si **Compartir estadísticas de uso anónimas** está activado (lo eliges en la ventana de bienvenida y lo puedes cambiar en Ajustes → Privacidad), la app envía eventos de uso a PostHog, alojado en la **Unión Europea**. Dicho llano, cuentan: que la app arrancó, que se mostró la bienvenida, el resultado del inicio de sesión (solo el tipo de error), cambios de consentimiento, cada sincronización (cuántos calendarios y eventos, cuántos con enlace, cuánto tardó), cada alerta programada, mostrada y descartada (tiempo de aviso, proveedor como "zoom", número de pantallas, si la habías rechazado, si había más invitados, solapes, cómo la descartaste y cuántos segundos antes o después del inicio), pruebas de alerta, cambios de ajustes, visitas a la pantalla Pro y compras, cierres de sesión, salidas de la app y errores (tipo y código). Cada evento lleva la versión de la app y de macOS, tu idioma y si tienes Pro. Se te identifica con un ID aleatorio creado en tu Mac y un hash irreversible (SHA-256) de tu email.

**Nunca se envía:** títulos, descripciones, enlaces, ubicaciones, asistentes u organizadores de reuniones, nombres de calendarios, tu email (salvo que aceptes abajo), tus contactos ni nada que escribas.

Con el interruptor apagado no se envía nada: los eventos se descartan en tu Mac, no se guardan para después.

## Avisos de novedades por email (opcional, desactivado por defecto)

Solo si activas **Avisarme de novedades por email**, tu dirección se añade a tu perfil de PostHog para escribirte sobre la app. Puedes desactivarlo en cualquier momento.

## Compras

Hey You! Pro se compra en la App Store de Apple. Apple gestiona el pago; nunca vemos tus datos de pago.

## Menores

Hey You! no está dirigida a menores de 16 años.

## Tus derechos

Puedes pedirnos que borremos los datos de uso asociados a tu ID o al hash de tu email escribiendo a hola@chimi.pro. Apagar el interruptor detiene toda recogida futura.
