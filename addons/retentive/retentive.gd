@tool
extends EditorPlugin

var user_settings = {
	"auto_fix": true
}

var toolbar
var issue_container
var script_editor = EditorInterface.get_script_editor()
var script_files: Array = []
var new_issue_bar = preload("res://addons/retentive/issue_bar.tscn")

var rules = {
	'code_order': preload("res://addons/retentive/rules/code_order.gd").new(),
	'editor_settings': preload("res://addons/retentive/rules/editor_settings.gd").new(),
	'numbers': preload("res://addons/retentive/rules/numbers.gd").new(),
}

func _enter_tree():
	toolbar = preload("res://addons/retentive/toolbar.tscn").instantiate()
	issue_container = toolbar.get_node("VBoxContainer").get_node("VBoxContainer").get_node("ScrollContainer").get_node("issue_container")
	add_control_to_bottom_panel(toolbar, "Retentive Formatting")

	make_bottom_panel_item_visible(toolbar)
	toolbar.get_node("VBoxContainer").get_node("Button").connect("pressed", _on_button_pressed)

	if not EditorInterface.get_script_editor().is_visible_in_tree():
		return
	script_editor.get_current_editor().get_base_editor().add_gutter(0)
	script_editor.get_current_editor().get_base_editor().connect("gutter_clicked", _on_gutter_click)

	print('done')

func _exit_tree():
	remove_control_from_bottom_panel(toolbar)
	EditorInterface.get_script_editor().get_current_editor().get_base_editor().remove_gutter(0)
	toolbar.queue_free()

func add_issue_to_toolbar_list(issue: Dictionary):
	var new_issue = new_issue_bar.instantiate()

	#new_issue.name = script_path
	new_issue.set_meta("script_path", issue.filepath)
	new_issue.set_meta("line", issue.line)
	new_issue.set_meta("issue_description", issue.description)

	if issue.line:
		new_issue.text = issue.filepath + " (Line: " + str(issue.line) + ") - " + issue.description
		script_editor = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
		script_editor.set_line_gutter_text(issue.line - 1, 0, "*")
		script_editor.set_line_gutter_item_color(issue.line - 1, 0, Color.RED)
		script_editor.set_line_gutter_clickable(issue.line - 1, 0, true)
		script_editor.set_line_gutter_metadata(issue.line - 1, 0, issue.filepath)
		script_editor.set_line_background_color(issue.line - 1, Color.GOLDENROD)
	else:
		new_issue.text = issue.filepath + " - " + issue.description

	issue_container.add_child(new_issue)



func identify_all_script_issues(script_path: String) -> Array:
	#var source_code = FileAccess.open(script_path, FileAccess.READ)
	#source_code.close()

	var loaded_code: Script = load(script_path)

	#var code_order_issues = rules.code_order.identify_problem_lines(loaded_code)
	var script_issues = []

	# Needed rules
	#region
	 #line feed instead of CRLF or just CR
	 ##one LF at end of each file
	 #UTF-8 encoding without byte order mark
	 ##tabs instead of spaces for indentation
	 #indentation level one greater than block containing it
		 #2 indent levels for continuation lines from regular code blocks
		 #arrays, dictionaries, and enums get single indentation for continuations
	 #Use trailing commas
	 #Blank lines
		 #Functions and class definitions get two lines around them
		 #No more than one blank line anywhere else
	 #Line length
		 #Keep under 100 characters where possible
	 #One statement per line
	 # No ending statements with semicolons
	 #Multiline statement readability
	 #Avoid unnecessary parenthesis
	 #Prefer plain english boolean operators
	 #Comments start with space, but commented code lines do not
	 #Whitespace
	 #Prefer single quotes
	 #No omitted leading or trailing zeros on floats
	 #Lowercase letters in hex numbers
	 #Use underscores in literals to make large numbers readable
	 #Naming conventions
		 #snake_case for file names
		 #Named classes should have same filename, but in snake_case instead of Pascal case
		 #Use PascalCase for class and node names
		 #Use PascalCase when loading a class into a constant or variable
		 #Functions and variables get snake_case
		 #Signals get snake_case
		 #Constants get CONSTANT_CASE
		 #Enums get PascalCase for the enum name, and CONSTANT_CASE for the members
		 #Enums get one item per line
	## code order
	# member variables should not be declared locally
	# static typing (various rules here)
	# no print() commands
	#endregion
	script_issues.append_array(rules.code_order.identify_problem_lines(loaded_code))
	script_issues.append_array(rules.numbers.identify_problem_lines(loaded_code))





	return script_issues

	# Variable not in snake_case

func _parse_folder(dir_path = "res://"):
	var dir = DirAccess.open(dir_path)
	var folders = dir.get_directories()
	var files = dir.get_files()

	for folder in folders:
		if folder.begins_with('.'):
			continue # Omit hidden folders
		if dir_path == "res://":
			dir_path = "res:/" # Prevents bad filepath
		_parse_folder(dir_path + "/" + folder)

	for file in files:
		if file.begins_with('.') or !file.ends_with('.gd'):
			continue # Omit hidden and non-script files
		script_files.push_back(dir_path + '/' + file)

func _on_button_pressed():
	var all_issues = []
	script_files = []
	_parse_folder()

	for old_issue_node in issue_container.get_children():
		old_issue_node.queue_free()

	# Handle the editor issues first independently of the scripts.
	if user_settings.auto_fix:
		rules.editor_settings.fix_issues()
	else:
		all_issues.append_array(rules.editor_settings.identify_editor_issues())

	# Handle all of the script issues
	for script in script_files:
		all_issues.append_array(identify_all_script_issues(script))

	for issue in all_issues:
		add_issue_to_toolbar_list(issue)

	if all_issues.size() == 0:
		var no_issues_detected_bar = new_issue_bar.instantiate()
		issue_container.add_child(no_issues_detected_bar)

func _on_gutter_click(line, gutter):
	print(line)
	print(gutter)
	print(EditorInterface.get_script_editor().get_current_editor().get_base_editor().get_line_gutter_metadata(line, gutter))
	make_bottom_panel_item_visible(toolbar)
