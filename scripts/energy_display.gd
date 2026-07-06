class_name EnergyDisplay
extends Control

@onready var _energy_label: Label = $EnergyLabel
@onready var _energy_bar: ProgressBar = $EnergyBar


func set_energy(current_energy: float, max_energy: float) -> void:
	_energy_bar.max_value = max_energy
	_energy_bar.value = current_energy
	_energy_label.text = "Energy: %d/%d" % [roundi(current_energy), roundi(max_energy)]
