extends PanelContainer

func _process(delta: float):
	if not $"../SamplePopup".visible:
		self.visible = false
