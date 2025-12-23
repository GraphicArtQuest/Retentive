class_name CodeOrderRule
extends Node

# Per the Godot style guide, the code organization should be in this arrangement:
#	01. @tool
#	02. class_name
#	03. extends
#	04. # docstring

#	05. signals
#	06. enums
#	07. constants
#	08. @export variables
#	09. public variables
#	10. private variables
#	11. @onready variables

#	12. optional built-in virtual _init method
#	13. optional built-in virtual _enter_tree() method
#	14. built-in virtual _ready method
#	15. remaining built-in virtual methods
#	16. public methods
#	17. private methods
#	18. subclasses

# This constant is a non-exhaustive list of Godot's virtual methods. These specifically are taken
#	solely from the Node class. Any other virtual methods will get treated as
#	regular user-defined private methods.
const godot_virtual_methods = [
		'_exit_tree',
		'_get_configuration_warnings',
		'_input',
		'_physics_process',
		'_process',
		'_shortcut_input',
		'_unhandled_input',
		'_unhandled_key_input',
	]

func parse_declarations_and_definitions(loaded_code: Resource) -> Dictionary:

	# If it's a tool:
	#	Find the line that `@tool` appears on
	#	first line MUST be `@tool`

	# If it has a class name:
	#	Find the line the class_name appears on
	#	If it is a tool:
	#		`class_name` must be on second line, `@tool` on first
	#	Else:
	#		`class_name` must be on first line

	# Find the line that `extends` appears on
	#	If it is a tool and there is a class_name, extends must be on third line
	#	If it is not a tool and there is a class_name, extends must be on second line
	#	If it is not a tool and there is not a class_name, extends must be on the first line
	#	If `extends` never appears, throw the error on line 1 that this is required

	var docstring_lines_before_declarations = []
	var tool_line: int
	var class_name_line: int
	var extends_line: int

	var signals = []
	var enums = []
	var constants = []
	var export_variables = []
	var public_variables = []
	var private_variables = []
	var onready_variables = []

	var function_init_line: int
	var function_enter_tree_line: int
	var function_ready_line: int

	var additional_virtual_functions = []
	var public_functions = []
	var private_functions = []
	var subclasses = []

	var code_split = loaded_code.get_source_code().split("\n")

	# Identify the lines these items first appear on, if ever. They will remain 0 if never found.
	# Loop through every line of code once to identify if one of the lines meets this criteria.
	for i in range (code_split.size()):
		if not tool_line and not class_name_line and not extends_line:
			# We have not yet encountered any of these lines, so we are still detecting blanks/docstrings beforehand
			if code_split[i].strip_edges() == "" or code_split[i].begins_with("#"):
				docstring_lines_before_declarations.push_back(i + 1)
				continue

		if code_split[i] == '@tool':
			tool_line = i + 1
			continue
		if code_split[i].begins_with('class_name '):
			class_name_line = i + 1
			continue
		if code_split[i].begins_with('extends '):
			extends_line = i + 1
			continue

		if code_split[i].begins_with('signal '):
			signals.push_back(i + 1)
			continue
		if code_split[i].begins_with('enum '):
			enums.push_back(i + 1)
			continue
		if code_split[i].begins_with('const '):
			constants.push_back(i + 1)
			continue

		if code_split[i].begins_with('@export '):
			export_variables.push_back(i + 1)
			continue
		if code_split[i].begins_with('var ') and code_split[i].substr(4, 1) != '_':
			public_variables.push_back(i + 1)
			continue
		if code_split[i].begins_with('var ') and code_split[i].substr(4, 1) == '_':
			private_variables.push_back(i + 1)
			continue
		if code_split[i].begins_with('@onready '):
			onready_variables.push_back(i + 1)
			continue

		if code_split[i].begins_with('func _init('):
			function_init_line = i + 1
			continue
		if code_split[i].begins_with('func _enter_tree('):
			function_enter_tree_line = i + 1
			continue
		if code_split[i].begins_with('func _ready('):
			function_ready_line = i + 1
			continue

		for virtual_method_name in godot_virtual_methods:
			var is_virtual: bool = false
			if code_split[i].begins_with('func ' + virtual_method_name + '('):
				additional_virtual_functions.push_back(i + 1)
				is_virtual = true
				break
			if is_virtual:
				continue

		if code_split[i].begins_with('func ') and code_split[i].substr(5, 1) != '_':
			public_functions.push_back(i + 1)
			continue
		if code_split[i].begins_with('func ') and code_split[i].substr(5, 1) == '_':
			var regex = RegEx.new()
			regex.compile('_\\w+')
			var func_name: String = regex.search(code_split[i]).get_string()
			if !godot_virtual_methods.has(func_name):
				private_functions.push_back(i + 1)
			continue
		if code_split[i].begins_with('class '):
			subclasses.push_back(i + 1)
			continue

	return {
		'docstring_lines_before_declarations': docstring_lines_before_declarations,
		'tool_line': tool_line,
		'class_name_line': class_name_line,
		'extends_line': extends_line,

		'signals': signals,
		'enums': enums,
		'constants': constants,

		'export_variables': export_variables,
		'public_variables': public_variables,
		'private_variables': private_variables,
		'onready_variables': onready_variables,

		'function_init_line': function_init_line,
		'function_enter_tree_line': function_enter_tree_line,
		'function_ready_line': function_ready_line,
		'additional_virtual_functions': additional_virtual_functions,

		'public_functions': public_functions,
		'private_functions': private_functions,
		'subclasses': subclasses
	}

func identify_problem_lines(loaded_code: Resource) -> Array:
	var script: Dictionary = parse_declarations_and_definitions(loaded_code)
	var issues = []

	# Script header declarations
	#region
	if script.docstring_lines_before_declarations:
		for line in script.docstring_lines_before_declarations:
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': line,
				'description': 'Script may not have blank lines or docstrings before the declarations'
			})

	if script.tool_line and script.tool_line != 1:
		issues.push_back({
			'filepath': loaded_code.resource_path,
			'line': script.tool_line,
			'description': 'Script is a tool, but the `@tool` declaration is not made on line 1'
		})

	if script.class_name_line:
		if script.tool_line and script.class_name_line != script.tool_line + 1:
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': script.class_name_line,
				'description': 'The `class_name` must be declared on line 2 immediately after the `@tool` declaration'
			})

	if not script.tool_line and script.class_name_line and script.class_name_line != 1:
		issues.push_back({
			'filepath': loaded_code.resource_path,
			'line': script.class_name_line,
			'description': 'The `class_name` must be declared on line 1'
		})

	if not script.extends_line:
		issues.push_back({
			'filepath': loaded_code.resource_path,
			'line': 1,
			'description': 'The script must have an explicit `extends` declaration'
		})

	if script.extends_line and script.tool_line and script.class_name_line and script.extends_line != 3:
		issues.push_back({
			'filepath': loaded_code.resource_path,
			'line': script.extends_line,
			'description':
				'The `extends` declaration must be on line 3 immediately following the `class_name` declaration'
		})

	if script.extends_line and not script.tool_line and script.class_name_line and script.extends_line != 2:
		issues.push_back({
			'filepath': loaded_code.resource_path,
			'line': script.extends_line,
			'description':
				'The `extends` declaration must be on line 2 immediately following the `class_name` declaration'
		})

	if script.extends_line and script.tool_line and not script.class_name_line and script.extends_line != 2:
		issues.push_back({
			'filepath': loaded_code.resource_path,
			'line': script.extends_line,
			'description':
				'The `extends` declaration must be on line 2 immediately following the `@tool` declaration'
		})

	if script.extends_line and not script.tool_line and not script.class_name_line and script.extends_line != 1:
		issues.push_back({
			'filepath': loaded_code.resource_path,
			'line': script.extends_line,
			'description':
				'The `extends` declaration must be on line 1 immediately following the `class_name` declaration'
		})
	#endregion

	# Script signals
	#region
	for entry_to_check in script.signals:
		var is_issue: bool = false
		for comparison_entry in script.enums:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the enum found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.constants:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the constant found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.export_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the @export variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.public_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the public variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the private variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.onready_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the @onready variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		if script.function_init_line and entry_to_check > script.function_init_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Signals must be defined before the _init() function found on line ' + str(script.function_init_line)
			})
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Signals must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Signals must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Signals must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script enums
	#region
	for entry_to_check in script.enums:
		var is_issue: bool = false
		for comparison_entry in script.constants:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the constant found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.export_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the @export variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.public_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the public variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the private variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.onready_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the @onready variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		if script.function_init_line and entry_to_check > script.function_init_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Enums must be defined before the _init() function found on line ' + str(script.function_init_line)
			})
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Enums must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Enums must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Enums must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script constants
	#region
	for entry_to_check in script.constants:
		var is_issue: bool = false
		for comparison_entry in script.export_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the @export variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.public_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the public variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the private variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.onready_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the @onready variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		if script.function_init_line and entry_to_check > script.function_init_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Constants must be defined before the _init() function found on line ' + str(script.function_init_line)
			})
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Constants must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Constants must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Constants must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script export variables
	#region
	for entry_to_check in script.export_variables:
		var is_issue: bool = false
		for comparison_entry in script.public_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@export variables must be defined before the public variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@export variables must be defined before the private variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.onready_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@export variables must be defined before the @onready variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		if script.function_init_line and entry_to_check > script.function_init_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'@export variables must be defined before the _init() function found on line ' + str(script.function_init_line)
			})
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'@export variables must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'@export variables must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@export variables must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@export variables must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@export variables must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@export variables must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script public variables
	#region
	for entry_to_check in script.public_variables:
		var is_issue: bool = false
		for comparison_entry in script.private_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public variables must be defined before the private variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.onready_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public variables must be defined before the @onready variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		if script.function_init_line and entry_to_check > script.function_init_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Public variables must be defined before the _init() function found on line ' + str(script.function_init_line)
			})
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Public variables must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Public variables must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public variables must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public variables must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public variables must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public variables must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script private variables
	#region
	for entry_to_check in script.private_variables:
		var is_issue: bool = false
		for comparison_entry in script.onready_variables:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Private variables must be defined before the @onready variable found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		if script.function_init_line and entry_to_check > script.function_init_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Private variables must be defined before the _init() function found on line ' + str(script.function_init_line)
			})
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Private variables must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'Private variables must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Private variables must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Private variables must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Private variables must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Private variables must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script onready variables
	#region
	for entry_to_check in script.onready_variables:
		var is_issue: bool = false
		if script.function_init_line and entry_to_check > script.function_init_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'@onready variables must be defined before the _init() function found on line ' + str(script.function_init_line)
			})
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'@onready variables must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'@onready variables must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@onready variables must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@onready variables must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@onready variables must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'@onready variables must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script _init() function
	#region
	if script.function_init_line:
		var entry_to_check = script.function_init_line
		var is_issue: bool = false
		if script.function_enter_tree_line and entry_to_check > script.function_enter_tree_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'The _init() function must be defined before the _enter_tree() function found on line ' + str(script.function_enter_tree_line)
			})
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'The _init() function must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _init() function must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _init() function must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _init() function must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _init() function must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script _enter_tree() function
	#region
	if script.function_enter_tree_line:
		var entry_to_check = script.function_enter_tree_line
		var is_issue: bool = false
		if script.function_ready_line and entry_to_check > script.function_ready_line:
			is_issue = true
			issues.push_back({
				'filepath': loaded_code.resource_path,
				'line': entry_to_check,
				'description':
					'The _enter_tree() function must be defined before the _ready() function found on line ' + str(script.function_ready_line)
			})

		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _enter_tree() function must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _enter_tree() function must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _enter_tree() function must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _enter_tree() function must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

# Script _ready() function
	#region
	if script.function_ready_line:
		var entry_to_check = script.function_ready_line
		var is_issue: bool = false
		for comparison_entry in script.additional_virtual_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _ready() function must be defined before the Godot built-in virtual function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break

		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _ready() function must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _ready() function must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'The _ready() function must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script additional virtual functions
	#region
	for entry_to_check in script.additional_virtual_functions:
		var is_issue: bool = false
		for comparison_entry in script.public_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Godot built-in virtual functions must be defined before the public function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Godot built-in virtual functions must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Godot built-in virtual functions must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script public functions
	#region
	for entry_to_check in script.public_functions:
		var is_issue: bool = false
		for comparison_entry in script.private_functions:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public functions must be defined before the private function found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Public functions must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	# Script private functions
	#region
	for entry_to_check in script.private_functions:
		var is_issue: bool = false
		for comparison_entry in script.subclasses:
			if entry_to_check > comparison_entry:
				is_issue = true
				issues.push_back({
					'filepath': loaded_code.resource_path,
					'line': entry_to_check,
					'description':
						'Private functions must be defined before the subclass found on line ' + str(comparison_entry)
				})
			if is_issue:
				break
	#endregion

	return issues
