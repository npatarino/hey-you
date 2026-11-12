# Product Hunt launch kit

Everything to paste into the Product Hunt submission form, plus the first comment and ready answers. Gallery images are in [product-hunt/](product-hunt) (1270×760, made by `scripts/make-store-screenshots.sh`).

## Listing

| Field | Text |
|---|---|
| Name | Hey You! |
| Tagline (60 max) | Your whole screen turns red 20 seconds before each meeting |
| Topics | Productivity, Mac, Menu Bar Apps, Calendar, Meetings |
| Pricing | Free, with a paid option (Pro, one-time 5.99) |
| Links | Mac App Store page, https://chimi.pro |
| Thumbnail | `App/Assets.xcassets/AppIcon.appiconset/icon_512x512.png` (PH wants 240×240) |

Other taglines that fit, in case you want to test them:

- The meeting reminder you can't ignore (37)
- A full-screen red alert 20 seconds before every meeting (55)
- Never join a meeting 7 minutes late again (40)

## Description (260 max)

> You knew the meeting was at 11. You looked at 10:55, then it was 11:07. Hey You! turns every screen red 20 seconds before each Google Calendar meeting. Enter joins the call, Esc dismisses it. Free Mac menu bar app, one-time Pro, no subscription.

## Gallery order

1. `01-alert.png`: the alert, with the tagline as headline. This is the image people see in the feed.
2. `03-join-or-dismiss.png`: Enter joins, Esc dismisses.
3. `02-every-screen.png`: every display.
4. `04-started.png`: "Started 3 min ago".
5. `05-menu-bar.png`: the menu.
6. `06-privacy.png`: read-only sign-in.
7. `07-pro.png`: Pro.

A 10 to 15 second screen recording of the alert appearing over a full-screen editor would beat any of these as the first slot. It has to be recorded on a real Mac (the agent has no Screen Recording permission): start typing in a full-screen app, trigger **Test alert**, press Enter.

## First comment (maker)

> Hi Product Hunt! I'm Nico, and I made Hey You! because I kept being seven minutes late to meetings I knew I had.
>
> It was never a planning problem. I'd see the meeting was at 11, check the clock at 10:55, go back to what I was doing, and the next time I looked up it was 11:07 and someone was typing "are you joining?". The calendar notification had been there the whole time, a small grey box in the corner that I stopped seeing years ago.
>
> So Hey You! does one thing. 20 seconds before every meeting on your Google Calendar, every screen turns red with the meeting name, a countdown and a Join button.
>
> A few decisions I'd love your opinion on:
>
> It fires 20 seconds before the meeting. A 10-minute reminder gets a "yeah, in a bit", and even a full minute leaves room for "let me finish this line". At 20 seconds there's nothing left to finish, so you just join. Pro lets you pick anything from 1 second to 2 minutes, never more.
>
> It's loud, but it never traps you. A click anywhere or Esc and it's gone. Enter opens the Meet, Zoom, Teams or Webex link. It ignores keys for the first second so a keystroke you were already typing can't dismiss it before you've seen it.
>
> There's no snooze and no "do not disturb". If you can silence it once, you'll silence it forever. If it shows up while you're presenting, you really do have a problem and it's better to know.
>
> Your calendar stays on your Mac. Read-only Google sign-in, no backend, no account with me. The app talks to Google directly.
>
> The free version does the whole job: an alert 20 seconds before every meeting, forever. Pro is a one-time 5.99 for people who want to tune it: skip meetings you declined, skip solo focus blocks, pick calendars and working hours, and see how many meetings you made on time each week.
>
> Full-screen meeting alerts aren't a new idea, and I tried the existing ones before building this. I wanted one that was free for the core job, connected to Google without setting up the Mac Calendar first, and went away with any click.
>
> It's Google Calendar only for now. If you'd use it with Outlook or iCloud, tell me, because that decides what I build next.

## Ready answers

**Does it work with Outlook / iCloud / the Mac Calendar?**
Not yet, v1 is Google Calendar only. The next step is the system calendar, which covers iCloud and Exchange. If that's what's stopping you, reply here and I'll count the vote.

**Can I snooze it?**
No, on purpose. It shows up when there are 20 seconds left, so there's nothing to snooze to. You can dismiss it with a click or Esc.

**What if I'm sharing my screen?**
It shows anyway, and if you're sharing the whole screen people will see it. It's one click to dismiss. I'd rather you know about the next meeting than find out at 11:07.

**What do you do with my calendar data?**
Nothing leaves your Mac. The app reads your events from Google with a read-only permission and keeps them in memory. There's no server. Anonymous usage stats are opt-in and never contain titles, links or attendees. Policy: https://chimi.pro/legal/hey-you/privacy

**Why not a subscription?**
It has no server costs, so charging monthly would be hard to justify. Pro is a one-time purchase and works on all your Macs with Family Sharing.

**Isn't this the same as In Your Face?**
Same family, different choices: Hey You! is free for the core alert, signs in to Google directly, fires 20 seconds before the meeting (never more than two minutes, even with Pro), and has no snooze.

## Posts for launch day

**X / Bluesky**

> I kept joining meetings 7 minutes late, so I made a Mac app that turns my whole screen red 20 seconds before each one.
>
> Enter joins the call. Esc makes it go away. Free on the Mac App Store.
>
> [link] [video of the alert]

**Show HN title**

> Show HN: Hey You! – my Mac's screen turns red 20 seconds before a meeting

**LinkedIn (Spanish)**

> Sabía que tenía reunión a las 11. Miré el reloj a las 10:55 y, cuando volví a mirar, eran las 11:07.
>
> Me pasaba varias veces por semana, así que hice Hey You!: una app para Mac que pinta toda la pantalla de rojo 20 segundos antes de cada reunión de Google Calendar. Enter te une a la llamada y Esc la quita.
>
> Es gratis en la Mac App Store. Si la pruebas, cuéntame qué cambiarías.

## Before pressing Launch

- [ ] The app is live on the Mac App Store and Google has verified the OAuth app (until then only 100 test users can sign in, and a launch would hit that wall).
- [ ] Record the 10 to 15 second video and put it first in the gallery.
- [ ] Schedule for 00:01 Pacific time on a Tuesday, Wednesday or Thursday.
- [ ] Post the first comment yourself right after launch and answer every comment that day.
