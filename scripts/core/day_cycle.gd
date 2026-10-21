extends Node
## Reloj del mundo: fases, cuenta regresiva y la luz que las acompaña.
##
## Es la columna vertebral del juego: de día se rebusca, de noche se aguanta.
## Todo lo demás (cuántos zombies llegan, qué dice el HUD, si hace falta
## linterna) se cuelga de las señales de aquí en vez de llevar su propio reloj.
##
## Las fases son explícitas y no un ángulo de sol continuo, porque la cuenta
## regresiva necesita saber exactamente cuándo empieza la noche, y porque
## equilibrar "cuánto dura el día" debe ser cambiar un número.

signal fase_cambiada(fase: Fase)
signal dia_cambiado(dia: int)

enum Fase { DIA, ATARDECER, NOCHE, AMANECER }

@export_group("Duraciones en segundos")
@export var dura_dia := 210.0
@export var dura_atardecer := 40.0
@export var dura_noche := 150.0
@export var dura_amanecer := 30.0

@export_group("Escena")
@export var sol: DirectionalLight3D
@export var entorno: WorldEnvironment

## Aspecto de cada fase. Se interpola entre la fase actual y la siguiente a lo
## largo de la fase, así que el cambio nunca es un salto: el atardecer se va
## tiñendo de naranja y la noche entra sola.
const VISUAL := {
	Fase.DIA: {
		"luz": Color(1.0, 0.97, 0.91), "energia": 1.15, "elevacion": -52.0,
		"cielo_alto": Color(0.29, 0.36, 0.47), "cielo_horiz": Color(0.62, 0.65, 0.67),
		"ambiente": 0.45, "niebla": Color(0.64, 0.67, 0.70), "densidad": 0.0028,
	},
	Fase.ATARDECER: {
		"luz": Color(1.0, 0.62, 0.34), "energia": 0.75, "elevacion": -12.0,
		"cielo_alto": Color(0.24, 0.24, 0.38), "cielo_horiz": Color(0.78, 0.45, 0.28),
		"ambiente": 0.30, "niebla": Color(0.55, 0.38, 0.32), "densidad": 0.0045,
	},
	Fase.NOCHE: {
		"luz": Color(0.42, 0.52, 0.78), "energia": 0.07, "elevacion": 28.0,
		"cielo_alto": Color(0.016, 0.020, 0.043), "cielo_horiz": Color(0.05, 0.06, 0.11),
		"ambiente": 0.055, "niebla": Color(0.05, 0.06, 0.10), "densidad": 0.0052,
	},
	Fase.AMANECER: {
		"luz": Color(0.85, 0.72, 0.68), "energia": 0.55, "elevacion": -10.0,
		"cielo_alto": Color(0.25, 0.30, 0.45), "cielo_horiz": Color(0.70, 0.56, 0.52),
		"ambiente": 0.27, "niebla": Color(0.52, 0.50, 0.52), "densidad": 0.0105,
	},
}

const ORDEN := [Fase.DIA, Fase.ATARDECER, Fase.NOCHE, Fase.AMANECER]
const NOMBRES := {
	Fase.DIA: "DÍA", Fase.ATARDECER: "ATARDECER",
	Fase.NOCHE: "NOCHE", Fase.AMANECER: "AMANECER",
}

var fase: Fase = Fase.DIA
var dia := 1
var _restante := 0.0
var _cielo: ProceduralSkyMaterial
var _env: Environment


func _ready() -> void:
	add_to_group("reloj")
	if entorno != null:
		_env = entorno.environment
		if _env != null and _env.sky != null:
			_cielo = _env.sky.sky_material as ProceduralSkyMaterial
	_restante = _duracion(fase)
	_aplicar(0.0)


func _process(delta: float) -> void:
	_restante -= delta
	if _restante <= 0.0:
		_avanzar()
	_aplicar(1.0 - clampf(_restante / maxf(_duracion(fase), 0.001), 0.0, 1.0))


func _avanzar() -> void:
	var i := ORDEN.find(fase)
	fase = ORDEN[(i + 1) % ORDEN.size()]
	_restante = _duracion(fase)
	if fase == Fase.DIA:
		dia += 1
		dia_cambiado.emit(dia)
	fase_cambiada.emit(fase)


func _duracion(f: Fase) -> float:
	match f:
		Fase.DIA: return dura_dia
		Fase.ATARDECER: return dura_atardecer
		Fase.NOCHE: return dura_noche
		_: return dura_amanecer


func es_noche() -> bool:
	return fase == Fase.NOCHE


## Hace falta luz propia desde que empieza a caer la tarde, no solo de noche.
func hay_poca_luz() -> bool:
	return fase == Fase.NOCHE or fase == Fase.ATARDECER


func nombre_fase() -> String:
	return NOMBRES[fase]


## Segundos hasta que entre la noche. Durante la noche devuelve 0: ahí lo que
## importa es cuánto falta para amanecer, que da `para_amanecer()`.
func para_anochecer() -> float:
	match fase:
		Fase.NOCHE: return 0.0
		Fase.ATARDECER: return _restante
		Fase.DIA: return _restante + dura_atardecer
		_: return _restante + dura_dia + dura_atardecer


func para_amanecer() -> float:
	return _restante if fase == Fase.NOCHE else 0.0


## Interpola entre la fase actual y la siguiente según `t` (0..1 dentro de la
## fase). Suavizado para que el cambio no se note como una rampa lineal.
func _aplicar(t: float) -> void:
	var actual: Dictionary = VISUAL[fase]
	var siguiente: Dictionary = VISUAL[ORDEN[(ORDEN.find(fase) + 1) % ORDEN.size()]]
	var k := smoothstep(0.0, 1.0, t)

	if sol != null:
		sol.light_color = Color(actual["luz"]).lerp(siguiente["luz"], k)
		sol.light_energy = lerpf(actual["energia"], siguiente["energia"], k)
		var elev := lerpf(actual["elevacion"], siguiente["elevacion"], k)
		sol.rotation = Vector3(deg_to_rad(elev), -0.7, 0.0)
		# Bajo el horizonte las sombras direccionales solo producen artefactos.
		sol.shadow_enabled = elev < -3.0

	if _env != null:
		_env.ambient_light_energy = lerpf(actual["ambiente"], siguiente["ambiente"], k)
		_env.fog_light_color = Color(actual["niebla"]).lerp(siguiente["niebla"], k)
		_env.fog_density = lerpf(actual["densidad"], siguiente["densidad"], k)

	if _cielo != null:
		var alto := Color(actual["cielo_alto"]).lerp(siguiente["cielo_alto"], k)
		var horiz := Color(actual["cielo_horiz"]).lerp(siguiente["cielo_horiz"], k)
		_cielo.sky_top_color = alto
		_cielo.sky_horizon_color = horiz
		_cielo.ground_horizon_color = horiz
		_cielo.ground_bottom_color = alto.darkened(0.3)
