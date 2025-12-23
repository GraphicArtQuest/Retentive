class_name Numbers
extends Node

var _myhexnum   =  0x0d2226

func identify_problem_lines(loaded_code: Resource) -> Array:
	var code_split = loaded_code.get_source_code().split("\n")
	var issues = []

	var regex = RegEx.new()
	regex.compile('var \\w+ *= *0x\\[w+]')

	for i in range (code_split.size()):
		var func_name: RegExMatch = regex.search(code_split[i])
		if func_name:
			print('xxxx')
			print(func_name.strings)


	return issues
