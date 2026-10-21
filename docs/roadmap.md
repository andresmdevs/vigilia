# Roadmap

Orden pensado para que haya algo jugable lo antes posible y para que cada
fase valide la siguiente. Los tiempos asumen trabajo de ratos, no full time.

---

## Fase 0 — Prototipo jugable (un solo jugador)

Objetivo: un bucle completo de principio a fin. Feo, pero terminable.

- [x] Proyecto, renderer, mapa de controles
- [x] Controlador en tercera persona + cámara orbital con colisión
- [x] Nivel de pruebas
- [ ] **Personaje con modelo y animaciones** (idle / walk / run)
- [ ] Zombies: `NavigationRegion3D` + `NavigationAgent3D`, perseguir y atacar
- [ ] Combate cuerpo a cuerpo, vida, muerte
- [ ] Piezas recolectables repartidas por el mapa
- [ ] Carro reparable = condición de victoria
- [ ] Ciclo día/noche con cuenta regresiva

Al final de esta fase ya se puede enseñar y pedir opinión.

---

## Fase 1 — Multijugador

**Transporte: WebSocket, no ENet.** ENet (UDP) es el default de Godot y no
funciona dentro de un navegador. Como el navegador es plataforma objetivo,
`WebSocketMultiplayerPeer` desde el principio — si lo dejamos para después
hay que reescribir toda la capa de red.

**Topología: servidor autoritativo.** Un Godot headless corriendo la misma
lógica, con los clientes mandando intención y recibiendo estado. Un cliente
en navegador no puede *hospedar* (no acepta conexiones entrantes), así que
el modelo "un jugador es el host" no es opción.

- [ ] Servidor headless + export dedicado
- [ ] `MultiplayerSpawner` / `MultiplayerSynchronizer` para jugadores y zombies
- [ ] Códigos de sala para entrar con amigos
- [ ] Reconexión y salida limpia

---

## Fase 2 — Web

- [ ] Instalar export templates de Godot (~1 GB)
- [ ] Export HTML5
- [ ] Hosting estático gratis: Cloudflare Pages, itch.io o GitHub Pages
- [ ] Si activamos hilos, hacen falta cabeceras `COOP`/`COEP`
      (Cloudflare Pages lo permite con un archivo `_headers`; GitHub Pages no)

Realidad a tener presente: un build web de Godot 3D pesa decenas de MB y
tarda en cargar. Para escritorio está bien; en navegador de celular va
flojo. Por eso el móvil va como app nativa, no como web.

---

## Fase 3 — Android / Play Store

- [ ] Instalar JDK 17 y el SDK de Android (hoy no hay Java en la máquina)
- [ ] Controles táctiles: joystick virtual + arrastre de cámara + botones
- [ ] Keystore de release (guardarlo bien: se pierde, se pierde la app)
- [ ] Ficha de Play Console, política de privacidad, content rating

Dos cosas que suelen sorprender:

1. Las cuentas de desarrollador **personales** nuevas tienen que correr una
   prueba cerrada con un mínimo de testers durante varios días seguidos antes
   de poder pedir acceso a producción. Conviene confirmar el número y los
   días vigentes en Play Console, porque Google los ha ido cambiando. Es un
   retraso de calendario, no técnico — pero hay que planearlo.
2. Los controles táctiles no son "lo mismo con botones en pantalla". Es
   rediseño de verdad y se nota si se deja para el final.

---

## Fase 4 — iOS

- [ ] Apple Developer Program
- [ ] Export de Godot → proyecto Xcode → TestFlight

---

## Costos

| Concepto | Costo |
|---|---|
| Godot | Gratis |
| Hosting web estático | Gratis |
| Play Console | ~25 USD, pago único |
| Apple Developer | ~99 USD al año |
| **Servidor multijugador** | **El único costo recurrente real** |

El servidor es lo único que no sale gratis de verdad. Un VPS pequeño basta
para empezar; hay capas gratuitas que sirven para pruebas pero se duermen o
se quedan cortas con jugadores reales. La decisión se puede aplazar hasta la
Fase 1.
