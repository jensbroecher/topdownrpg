extends Node
class_name WeatherController

@export var worldEnvironment: WorldEnvironment
@export var directionalLight: DirectionalLight3D
@export var seasons: Array[SeasonResource]
@export var dayDuration: float = 86400.0
@export var timeSpeedMultiplier: float = 100.0
@export var startTime: float = 40000.0
@export var startSeason: int = 0
@export var startWeather: int = 0

signal on_season_change(season: SeasonResource)
signal on_weather_change(weather: WeatherResource)

var timeOfDay: float = 0.0
var currentSeasonIndex: int = 0
var currentWeatherIndex: int = 0
var nextWeatherIndex: int = 0
var currentWeatherLength: float = 0.0
var currentWeatherTime: float = 0.0
var currentSeasonLength: float = 0.0
var currentSeasonTime: float = 0.0
var particleSystem: GPUParticles3D

func _ready():
	if not worldEnvironment:
		push_error("WeatherController: worldEnvironment is not assigned!")
	if not directionalLight:
		push_error("WeatherController: directionalLight is not assigned!")
	
	set_season(startSeason, startWeather)
	currentSeasonTime += startTime
	timeOfDay += startTime

func set_season(season_index: int, weather_index: int = -1):
	if seasons.size() == 0:
		return
	currentSeasonIndex = season_index
	currentSeasonLength = seasons[season_index].durationInDays * dayDuration
	currentSeasonTime = 0.0

	if weather_index != -1:
		set_weather(weather_index)
	else:
		set_random_weather()

	on_season_change.emit(seasons[currentSeasonIndex])

func set_random_weather():
	var season = seasons[currentSeasonIndex]
	var total = 0.0
	for occurrence in season.weathers:
		total += occurrence.probabilityRatio
	
	var rand = randf() * total
	var current_total = 0.0
	var weather_index = 0
	for occurrence in season.weathers:
		current_total += occurrence.probabilityRatio
		if rand <= current_total:
			break
		weather_index += 1
	
	set_weather(weather_index)

func set_weather(weather_index: int):
	if seasons.size() == 0:
		return
	var season = seasons[currentSeasonIndex]
	if season.weathers.size() == 0:
		return

	currentWeatherIndex = weather_index
	nextWeatherIndex = randi() % season.weathers.size()
	var weather = season.weathers[currentWeatherIndex].weather
	currentWeatherLength = lerp(weather.minDuration, weather.maxDuration, randf())
	currentWeatherTime = 0.0

	if particleSystem:
		particleSystem.queue_free()
		particleSystem = null
	
	if weather.precipitation and weather.precipitation.particles:
		particleSystem = weather.precipitation.particles.instantiate()
		add_child(particleSystem)

func _process(delta):
	if not worldEnvironment or seasons.size() == 0:
		return

	timeOfDay = fmod(timeOfDay + delta * timeSpeedMultiplier, dayDuration)
	currentWeatherTime += delta * timeSpeedMultiplier
	currentSeasonTime += delta * timeSpeedMultiplier

	if currentWeatherTime >= currentWeatherLength:
		set_weather(nextWeatherIndex)
	
	var season = seasons[currentSeasonIndex]
	var next_season_index = (currentSeasonIndex + 1) % seasons.size()
	var next_season = seasons[next_season_index]
	
	if currentSeasonTime >= currentSeasonLength:
		set_season(next_season_index)

	var t_season = currentSeasonTime / currentSeasonLength
	var t_weather = currentWeatherTime / currentWeatherLength
	var t_time = timeOfDay / dayDuration

	# Interpolation
	var day_night_factor = 1.0 - season.dayNightCycleCurve.sample(t_time)
	
	var sky_day = season.skyColourDaytime
	var sky_night = season.skyColourNight
	
	var current_sky_colour = sky_day.skyColour.lerp(sky_night.skyColour, day_night_factor)
	var current_horizon_colour = sky_day.horizonColour.lerp(sky_night.horizonColour, day_night_factor)
	var current_ground_colour = sky_day.groundColour.lerp(sky_night.groundColour, day_night_factor)
	var current_cloud_brightness = lerp(sky_day.cloudBrightness, sky_night.cloudBrightness, day_night_factor)

	var weather = season.weathers[currentWeatherIndex].weather
	var next_weather = season.weathers[nextWeatherIndex].weather
	
	var current_fog_density = lerp(weather.fogDensity, next_weather.fogDensity, t_weather)
	var current_cloud_speed = lerp(weather.cloudSpeed, next_weather.cloudSpeed, t_weather)
	var current_small_cloud = lerp(weather.smallCloudCover, next_weather.smallCloudCover, t_weather)
	var current_large_cloud = lerp(weather.largeCloudCover, next_weather.largeCloudCover, t_weather)
	var current_cloud_inner = weather.cloudInnerColour.lerp(next_weather.cloudInnerColour, t_weather) * current_cloud_brightness
	var current_cloud_outer = weather.cloudOuterColour.lerp(next_weather.cloudOuterColour, t_weather) * current_cloud_brightness

	# Update Environment
	var sky_mat = worldEnvironment.environment.sky.sky_material as ShaderMaterial
	if sky_mat:
		sky_mat.set_shader_parameter("small_cloud_cover", current_small_cloud)
		sky_mat.set_shader_parameter("large_cloud_cover", current_large_cloud)
		sky_mat.set_shader_parameter("cloud_speed", current_cloud_speed)
		sky_mat.set_shader_parameter("cloud_shape_change_speed", current_cloud_speed)
		sky_mat.set_shader_parameter("cloud_inner_colour", current_cloud_inner)
		sky_mat.set_shader_parameter("cloud_outer_colour", current_cloud_outer)
		sky_mat.set_shader_parameter("sky_top_color", current_sky_colour)
		sky_mat.set_shader_parameter("sky_horizon_color", current_horizon_colour)
		sky_mat.set_shader_parameter("ground_horizon_color", current_horizon_colour)
		sky_mat.set_shader_parameter("ground_bottom_color", current_ground_colour)

	worldEnvironment.environment.volumetric_fog_enabled = false # Performance: Disable volumetric fog by default
	worldEnvironment.environment.volumetric_fog_density = current_fog_density * 0.5

	if particleSystem:
		var amount_ratio = weather.precipitation.amountRatio if weather.precipitation else 0.0
		particleSystem.amount_ratio = amount_ratio
		var cam = get_viewport().get_camera_3d()
		if cam:
			particleSystem.global_position = cam.global_position + Vector3.UP * 10.0

	if directionalLight:
		var sun_angle = (timeOfDay / dayDuration) * PI * 2.0 + PI * 0.5
		
		# Create a realistic sun orbit:
		# 1. Daily rotation around local X axis
		var daily_rot = Basis(Vector3(1, 0, 0), sun_angle)
		# 2. Latitude tilt: positive angle ensures shadows fall towards -Z (behind objects)
		var latitude_tilt = Basis(Vector3(1, 0, 0), deg_to_rad(35.0))
		# 3. Azimuth: angle the light horizontally (e.g., 45 degrees) like the original light
		var azimuth_rot = Basis(Vector3(0, 1, 0), deg_to_rad(45.0))
		
		directionalLight.global_transform.basis = azimuth_rot * latitude_tilt * daily_rot
		directionalLight.light_energy = 1.0 - day_night_factor
		
		# Restore original shadow settings to fix missing shadows on trees and the well
		directionalLight.shadow_enabled = true
		directionalLight.shadow_bias = 0.03
		directionalLight.directional_shadow_blend_splits = true
		directionalLight.directional_shadow_max_distance = 60.0
	
	worldEnvironment.environment.ambient_light_sky_contribution = 1.0 - day_night_factor
