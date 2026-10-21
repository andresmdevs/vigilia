extends Node
## Ajustes elegidos en el menú, vivos durante toda la partida.
##
## Todo lo que define una dificultad vive en esta tabla y en ningún otro lado.
## Ese es el punto: equilibrar el juego debe ser editar números acá, nunca
## tocar la lógica del zombie o del spawner.

enum Difficulty { CALMA, NOCHE, PESADILLA }

const PRESETS := {
	Difficulty.CALMA: {
		"nombre": "CALMA",
		"lema": "Para aprender el mapa",
		"zombie_intervalo": Vector2(10.0, 18.0),
		"zombie_max": 6,
		"zombie_dano": 6.0,
		"zombie_velocidad": 2.6,
		"loot_intervalo": Vector2(7.0, 12.0),
		"loot_max": 16,
	},
	Difficulty.NOCHE: {
		"nombre": "NOCHE",
		"lema": "Como debe jugarse",
		"zombie_intervalo": Vector2(5.0, 10.0),
		"zombie_max": 12,
		"zombie_dano": 12.0,
		"zombie_velocidad": 3.2,
		"loot_intervalo": Vector2(12.0, 20.0),
		"loot_max": 10,
	},
	Difficulty.PESADILLA: {
		"nombre": "PESADILLA",
		"lema": "Vas a morir. Es el punto",
		"zombie_intervalo": Vector2(2.5, 5.5),
		"zombie_max": 22,
		"zombie_dano": 20.0,
		"zombie_velocidad": 4.0,
		"loot_intervalo": Vector2(20.0, 34.0),
		"loot_max": 6,
	},
}

## Hoy solo hay un mapa; la lista existe para que añadir el segundo no
## obligue a rehacer el menú.
const MAPAS := [
	{"id": "valle", "nombre": "EL VALLE", "escena": "res://scenes/main.tscn",
	 "lema": "Carretera, bosque y casas dispersas"},
]

var difficulty: Difficulty = Difficulty.NOCHE
var mapa_index := 0


func actual() -> Dictionary:
	return PRESETS[difficulty]


func mapa() -> Dictionary:
	return MAPAS[mapa_index]
