extends Resource
class_name WeatherResource

@export var minDuration: float = 40000.0
@export var maxDuration: float = 100000.0
@export var cloudSpeed: float = 0.001
@export_range(0.0, 1.0) var smallCloudCover: float = 0.5
@export_range(0.0, 1.0) var largeCloudCover: float = 0.5
@export var cloudInnerColour: Color = Color(1.0, 1.0, 1.0)
@export var cloudOuterColour: Color = Color(0.5, 0.5, 0.5)
@export var precipitation: PrecipitationResource
@export var fogDensity: float = 0.0
