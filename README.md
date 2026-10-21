# Vigilia

Survival co-op en 3D tercera persona. Rebuscas de día, atrancas de noche,
arreglas el carro y te largas. Pensado para correr en navegador y, más
adelante, como app nativa en Android e iOS.

> Nombre provisional. El juego es original: tomamos el *género*
> (survival co-op con objetivo de escape y ciclo día/noche), no los assets,
> textos, marca ni interfaz de ningún otro juego.

## Correr el proyecto

Abre la carpeta desde Godot 4.7+ o, desde la terminal:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . 
```

**Controles:** clic para enganchar el mouse · `WASD` mover · `Shift` correr ·
`Espacio` saltar · `E` interactuar · `Esc` soltar el mouse.

## Captura automática

Para revisar el juego sin abrirlo a mano (útil para comparar un cambio visual
antes/después). Abre la ventana unos segundos, guarda el PNG y cierra:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --shot /tmp/vigilia.png
```

Imprime también FPS, draw calls y número de objetos.

## Estructura

```
scenes/
  main.tscn            Escena raíz: entorno, sol, nivel, jugador, HUD
  player/player.tscn   Jugador: colisión, Visual (el modelo va aquí), CameraRig
  world/test_level.tscn  Banco de pruebas (la geometría la genera el script)
scripts/
  core/game_input.gd   Mapa de controles, registrado por código
  core/hud.gd          HUD de desarrollo (temporal)
  player/player.gd     Movimiento, salto, giro, enganche de animaciones
  player/camera_rig.gd Cámara orbital con SpringArm
  world/test_level.gd  Genera el nivel de pruebas
  dev/dev_tools.gd     Captura automática (inerte en partida normal)
assets/characters/     Aquí va el modelo del personaje
```

## Dos decisiones que conviene no revertir a la ligera

**Renderer `GL Compatibility`, no Forward+.** Forward+ se ve mejor, pero
Compatibility es el único que corre en WebGL2 (export web) y en Android de
gama media. Cambiarlo nos cerraría las dos plataformas objetivo.

**El `CharacterBody3D` del jugador nunca rota.** Solo se traslada. Quien rota
es `Visual` (hacia donde camina) y `CameraRig` (con el mouse). Si algún día
haces que el cuerpo rote, la cámara y el personaje se pelean por la
orientación — es el bug clásico de los controladores en tercera persona.

## Créditos

Todo el arte de terceros es CC0 de Quaternius. Ver [CREDITS.md](CREDITS.md).

## Estado

Prototipo. Ver [docs/roadmap.md](docs/roadmap.md).
