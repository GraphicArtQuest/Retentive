class_name EditorSettingsRule
extends Node

func identify_editor_issues() -> Array:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var setting: String
	var issues = []

	setting = 'text_editor/behavior/files/trim_trailing_whitespace_on_save'
	if not settings.get_setting(setting):
		issues.push_back({
			'filepath': 'Editor Settings',
			'line': 0,
			'description':
				'"Trim Trailing Whitespace On Save" is not set to true'
		})

	setting = 'text_editor/appearance/whitespace/draw_tabs'
	if not settings.get_setting(setting):
		issues.push_back({
			'filepath': 'Editor Settings',
			'line': 0,
			'description':
				'"Draw Tabs" is not set to true'
		})

	setting = 'text_editor/behavior/indent/type'
	if settings.get_setting(setting) != 0: # 0 = tab, 1 = space
		issues.push_back({
			'filepath': 'Editor Settings',
			'line': 0,
			'description':
				'"Indent Type" is set to spaces instead of tabs'
		})

	setting = 'text_editor/behavior/indent/size'
	if settings.get_setting(setting) != 4: # 0 = tab, 1 = space
		issues.push_back({
			'filepath': 'Editor Settings',
			'line': 0,
			'description':
				'"Indent Size" is not set to 4'
		})

	return issues

func fix_issues():
	var settings: EditorSettings = EditorInterface.get_editor_settings()

	settings.set_setting('text_editor/behavior/files/trim_trailing_whitespace_on_save', true)
	settings.set_setting('text_editor/appearance/whitespace/draw_tabs', true)
	settings.set_setting('text_editor/behavior/indent/type', 0)
	settings.set_setting('text_editor/behavior/indent/size', 4)
