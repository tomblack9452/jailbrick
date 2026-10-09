extends GutTest
## Phase 0 smoke test: proves GUT runs headless and the project is set up
## the way CLAUDE.md describes (portrait, stretch, Mobile renderer).


func test_gut_runs() -> void:
	assert_true(true, "GUT is installed and running")


func test_project_is_portrait_1080x1920() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1080)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 1920)
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "portrait")


func test_stretch_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")


func test_mobile_renderer() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")
