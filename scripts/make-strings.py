#!/usr/bin/env python3
"""Regenerates HeyYouKit's Localizable.xcstrings (en base + es).

Keys come from the .stringsdata files the compiler emits during `swift build` (pass their folder).
Every key must have a Spanish translation below; the script fails if one is missing.
"""
import glob
import json
import os
import sys

ES = {
    "%lld min": "%lld min",
    "(No title)": "(Sin título)",
    "+%lld more": "+%lld más",
    "Account": "Cuenta",
    "Alert": "Alerta",
    "Alert before the meeting": "Avisar antes de la reunión",
    "Alert from 10 to 60 seconds before": "Aviso de 10 a 60 segundos antes",
    "Allow Hey You! in System Settings → General → Login Items.": "Permite Hey You! en Ajustes del Sistema → General → Ítems de inicio.",
    "Bell": "Campana",
    "Buy": "Comprar",
    "Buy for %@ · one time": "Comprar por %@ · una sola vez",
    "Calendars": "Calendarios",
    "Calendars appear here once you're connected.": "Los calendarios aparecen aquí cuando te conectas.",
    "Chime": "Carillón",
    "Choose calendars · working hours": "Elige calendarios · horario laboral",
    "Click anywhere or press Esc to dismiss": "Haz clic o pulsa Esc para descartar",
    "Close": "Cerrar",
    "Connect Google Calendar": "Conectar Google Calendar",
    "Connected as %@": "Conectado como %@",
    "Connecting…": "Conectando…",
    "Couldn't open the Google sign-in window. Try again.": "No se pudo abrir la ventana de inicio de sesión de Google. Inténtalo de nuevo.",
    "Couldn't reach the App Store. Try again.": "No se pudo conectar con la App Store. Inténtalo de nuevo.",
    "Couldn't sign in with Google. Try again.": "No se pudo iniciar sesión con Google. Inténtalo de nuevo.",
    "Countdown in the menu bar": "Cuenta atrás en la barra de menús",
    "Declined · With Pro we wouldn't have alerted you": "Rechazada · Con Pro no te habríamos avisado",
    "Default": "Predeterminado",
    "Disconnect": "Desconectar",
    "Disconnected from Google": "Desconectado de Google",
    "Done": "Listo",
    "Email me about new features": "Avisarme de novedades por email",
    "Filters": "Filtros",
    "Focus blocks and reminders you created for yourself.": "Bloques de foco y recordatorios que creaste para ti.",
    "Free version": "Versión gratuita",
    "From": "Desde",
    "General": "General",
    "Google sign-in isn't set up in this build. Add your OAuth client ID to Config/Secrets.xcconfig.":
        "El inicio de sesión con Google no está configurado en esta versión. Añade tu client ID de OAuth en Config/Secrets.xcconfig.",
    "Hey You! Pro is active. Thank you!": "Hey You! Pro está activo. ¡Gracias!",
    "Hey You! Pro…": "Hey You! Pro…",
    "Hey You! can only alert you while it's running.": "Hey You! solo puede avisarte mientras está abierta.",
    "Hey You! needs read access to your calendar. Please allow it on Google's screen.":
        "Hey You! necesita acceso de lectura a tu calendario. Permítelo en la pantalla de Google.",
    "Hey You! test": "Prueba de Hey You!",
    "Horn": "Bocina",
    "Ignore events with no other attendees": "Ignorar eventos sin otros asistentes",
    "Ignore meetings I declined": "Ignorar reuniones que he rechazado",
    "It doesn't lock you out. It just can't be ignored.": "No te bloquea. Solo no te deja ignorarlo.",
    "Join meeting": "Unirse a la reunión",
    "Just you · With Pro we wouldn't have alerted you": "Solo tú · Con Pro no te habríamos avisado",
    "MEETING IN": "REUNIÓN EN",
    "Meeting in %lld seconds": "Reunión en %lld segundos",
    "Meeting started %lld minutes ago": "La reunión empezó hace %lld minutos",
    "Meeting starting now": "La reunión empieza ahora",
    "NOW": "AHORA",
    "Never the content of your calendar.": "Nunca el contenido de tu calendario.",
    "Never your meeting titles, links, attendees or calendar names.":
        "Nunca los títulos, enlaces, asistentes ni nombres de tus calendarios.",
    "No link": "Sin enlace",
    "No link · With Pro we wouldn't have alerted you": "Sin enlace · Con Pro no te habríamos avisado",
    "No more meetings today": "No hay más reuniones hoy",
    "No previous purchase found for this Apple ID.": "No hay compras anteriores con este Apple ID.",
    "None": "Ninguno",
    "Not connected": "No conectado",
    "Not connected to Google": "No conectado a Google",
    "Offline since %@": "Sin conexión desde las %@",
    "On time %lld of %lld this week": "Esta semana: a tiempo %lld de %lld",
    "One minute before every meeting, your whole screen turns red.": "Un minuto antes de cada reunión, toda tu pantalla se pone roja.",
    "Only during working hours": "Solo en horario laboral",
    "Only meetings with a video link": "Solo reuniones con enlace de videollamada",
    "Open Login Items": "Abrir Ítems de inicio",
    "Open at login": "Abrir al iniciar sesión",
    "Open at login (recommended)": "Abrir al iniciar sesión (recomendado)",
    "Open in Calendar": "Abrir en Calendar",
    "Outside hours": "Fuera de horario",
    "Outside working hours: no alert": "Fuera de horario: sin alerta",
    "Privacy": "Privacidad",
    "Privacy policy": "Política de privacidad",
    "Pulse": "Pulso",
    "Punctuality stats · Pro": "Estadística de puntualidad · Pro",
    "Purchase restored. Thanks for supporting Hey You!": "Compra restaurada. ¡Gracias por apoyar Hey You!",
    "Quit Hey You!": "Salir de Hey You!",
    "Read-only · your calendar never leaves your Mac": "Solo lectura · tu calendario no sale de tu Mac",
    "Refresh now": "Actualizar ahora",
    "Restore purchase": "Restaurar compra",
    "STARTED %lld MIN AGO": "EMPEZÓ HACE %lld MIN",
    "See what the alert looks like (in 5 seconds).": "Mira cómo es la alerta (en 5 segundos).",
    "Settings…": "Ajustes…",
    "Share anonymous usage statistics": "Compartir estadísticas de uso anónimas",
    "Shows “8m” next to the bell when a meeting is less than 10 minutes away.":
        "Muestra «8m» junto a la campana cuando falta menos de 10 minutos para una reunión.",
    "Sign in again": "Volver a iniciar sesión",
    "Sign in with Google": "Iniciar sesión con Google",
    "Skip focus blocks (just you)": "Sin bloques de foco (solo tú)",
    "Skip meetings you declined": "Sin reuniones rechazadas",
    "Sound": "Sonido",
    "Sound · weekly punctuality stats": "Sonido · estadística semanal de puntualidad",
    "Terms": "Términos",
    "Test alert": "Probar alerta",
    "Test the alert": "Probar la alerta",
    "The App Store is not available right now.": "La App Store no está disponible ahora mismo.",
    "The purchase couldn't be completed. Try again.": "No se pudo completar la compra. Inténtalo de nuevo.",
    "To": "Hasta",
    "Unlock Pro…": "Desbloquear Pro…",
    "Unlock with Hey You! Pro": "Desbloquear con Hey You! Pro",
    "Version": "Versión",
    "Video call": "Videollamada",
    "Watching %lld calendars": "Vigilando %lld calendarios",
    "Watching %lld calendars · next in %@": "Vigilando %lld calendarios · próxima en %@",
    "You decide when and for what we alert you.": "Tú decides cuándo y de qué te avisamos.",
    "Your purchase is waiting for approval.": "Tu compra está pendiente de aprobación.",
}

# Singular forms for keys whose only number is a count.
PLURALS = {
    "Watching %lld calendars": ("Watching %lld calendar", "Vigilando %lld calendario"),
    "Meeting in %lld seconds": ("Meeting in %lld second", "Reunión en %lld segundo"),
    "Meeting started %lld minutes ago": ("Meeting started %lld minute ago", "La reunión empezó hace %lld minuto"),
}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(one, other):
    return {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}


def main(folder, output):
    keys = set()
    for path in glob.glob(os.path.join(folder, "*.stringsdata")):
        with open(path) as handle:
            data = json.load(handle)
        for entries in data.get("tables", {}).values():
            keys.update(entry["key"] for entry in entries)
    missing = sorted(keys - ES.keys())
    if missing:
        sys.exit("Missing Spanish translations:\n" + "\n".join(missing))
    strings = {}
    for key in sorted(keys):
        if key in PLURALS:
            en_one, es_one = PLURALS[key]
            strings[key] = {"localizations": {"en": plural(en_one, key), "es": plural(es_one, ES[key])}}
        else:
            strings[key] = {"localizations": {"es": unit(ES[key])}}
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    with open(output, "w") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"{len(strings)} strings written to {output}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
