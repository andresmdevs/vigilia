# Dónde va el personaje

Cuando elijamos pack de modelos, el `.glb` animado va acá y se instancia
dentro de `Visual` en `scenes/player/player.tscn`, al lado (o en lugar) de
las primitivas de placeholder.

`scripts/player/player.gd` busca solo un `AnimationPlayer` dentro de `Visual`
y reproduce la animación cuyo nombre contenga `idle`, `walk`, `run` o `jump`.
No hay que tocar código para que enganche.
