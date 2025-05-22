@tool
extends Node3D

class_name Polyrinthe

const CubeCustom := preload("res://addons/polyrinthe/CubeCustom.gd")
const CubeGraph := preload("res://addons/polyrinthe/cubeGraph.gd")

@export_category("Polyrinthe")
@export_group("Generation Properties")
@export var algo:= GENERATION_ALGORITHME.DFS_3D_ALT_2
## for example: (0, 0, 0)
@export var coord_first: Marker3D
## for example: (1, 0, 0)
@export var coord_right: Marker3D
## for example: (0, 1, 0)
@export var coord_up: Marker3D

@export_group("Design Properties")
## optionnal, a material can be set to walls (need to be set before display)
@export var wall_mat:StandardMaterial3D
## be carefull, it is not recommanded using a scale greater than 10
@export_range(0.5, 2, 0.1, "or_greater") var room_scale:float = 1.0

var cubeGraph: CubeGraph

var maze:Dictionary= {}

var size = 3 # default size
var gapBetweenRooms_multiplier = 1 # 1 for no gap, other value for DEBUG

@export_group("DEBUG")
@export var debug: bool = false
@export var showWall:bool = true

##
## when showWall is set to true:
##	-1 : show outside wall,
##	-2 : hide outside wall,
## no effect otherwise
##
@export_range(CubeCustom.outSideWallValue, CubeCustom.wallValue) 
var outWallV:int = -1


var triColor:bool = true

var wallV = CubeCustom.wallValue # -1 = wall (only -1 !!)
var gapBetweenCubeCenter = (CubeCustom.distFromCenter * 2 + 0.1) * \
		gapBetweenRooms_multiplier

var rng = RandomNumberGenerator.new()
var seed_human:String
var seed_hashed:int
var _characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

enum GENERATION_ALGORITHME { 
	DFS_3D, 
	DFS_3D_ALT_1, 
	DFS_3D_ALT_2, 
	DFS_LBL, 
	DFS_LBL_ALT_1, 
	DFS_LBL_ALT_2, 
	DFS_LBL_ALT_3, 
	DFS_LBL_ALT_4, 
	DFS_LBL_ALT_5, 
	DFS_LBL_ALT_6 
}

func _ready(): # (backward, forward, left, right, down, up)
	pass

func _process(_delta):
	pass

func _generate_seeds(chars:String = _characters, length:int = 10) -> void :
	seed_human = ""
	var chars_len = len(chars)
	for i in range(length):
		seed_human += chars[randi()% chars_len]
	
	seed_hashed = hash(seed_human)
	print(seed_human, ": ", seed_hashed)

func generate(sizeP:int, new_seed:String = "", default_tags: Array = [-1, -1]) -> void:
	if len(new_seed) == 0:
		_generate_seeds()
	else:
		seed_human = new_seed
		seed_hashed = hash(seed_human)
	
	rng.seed = seed_hashed
	
	cubeGraph = CubeGraph.new(sizeP, wallV, outWallV, 6, default_tags)
	
	# only for normal generation : odd size, middle: cubeGraph.getNbrRoom()/2 
	var beginId = 0
	
	var time_start = Time.get_ticks_msec()
	match algo:
		GENERATION_ALGORITHME.DFS_3D:
			createPath_deepWay(beginId)
			
		GENERATION_ALGORITHME.DFS_3D_ALT_1:
			createPath_deepWay_alt_1(beginId)
			
		GENERATION_ALGORITHME.DFS_3D_ALT_2:
			createPath_deepWay_alt_2(beginId)
			
		GENERATION_ALGORITHME.DFS_LBL:
			createPath_deepWay_layer_by_layer(beginId)
			
		GENERATION_ALGORITHME.DFS_LBL_ALT_1:
			createPath_deepWay_layer_by_layer_alt_1(beginId)
			
		GENERATION_ALGORITHME.DFS_LBL_ALT_2:
			createPath_deepWay_layer_by_layer_alt_2(beginId)
			
		GENERATION_ALGORITHME.DFS_LBL_ALT_3:
			createPath_deepWay_layer_by_layer_alt_3(beginId)
			
		GENERATION_ALGORITHME.DFS_LBL_ALT_4:
			createPath_deepWay_layer_by_layer_alt_4(beginId)
			
		GENERATION_ALGORITHME.DFS_LBL_ALT_5:
			createPath_deepWay_layer_by_layer_alt_5(beginId)
			
		GENERATION_ALGORITHME.DFS_LBL_ALT_6:
			createPath_deepWay_layer_by_layer_alt_6(beginId)
			
		_:
			push_warning("gen_algo provided not matched: please have a look at GENERATION_ALGORITHME enum")
			createPath_deepWay_layer_by_layer_alt_6(beginId)
	var time_end = Time.get_ticks_msec()
	
	print("createPath in " + str((time_end - time_start)/1000) + "s " + \
		str((time_end - time_start)%1000) + "ms.")
	
	time_start = Time.get_ticks_msec()
	deepensPath_wideWay(beginId) # recompute connections from given id, by depth
	time_end = Time.get_ticks_msec()
	
	print("deepensPath in " + str((time_end - time_start)/1000) + "s " + \
		str((time_end - time_start)%1000) + "ms.")
	
	print("cubeGraph.getNbrRoom(): ", cubeGraph.getNbrRoom(), ", depth: ", cubeGraph.get_deepest())
	
	cubeGraph.setColorFromDepth()

func get_seed() -> String:
	return seed_human

func _get_rotation_from_basis(src_basis: Basis, dst_basis: Basis) -> Vector3:
	src_basis.orthonormalized()
	dst_basis.orthonormalized()
	var rel = dst_basis * src_basis.transposed()
	return rel.get_euler()

func display() -> void:
	if not debug:
		outWallV = -1 # safeguard
	
	# on the corner: right: (1, 0.707, 0.707), up: (-1, 0.707, 0.707)
	var defaul_start_pos:Vector3 = coord_first.position
	var curr_pos:Vector3 = defaul_start_pos
	var right_gap:Vector3 = (coord_right.position - coord_first.position).normalized() * gapBetweenCubeCenter * room_scale
	var up_gap:Vector3 = (coord_up.position - coord_first.position).normalized() * gapBetweenCubeCenter * room_scale
	
	var depth_gap = up_gap.cross(right_gap).normalized() * gapBetweenCubeCenter * room_scale
	
	if right_gap.dot(up_gap) > 0.001:
		push_warning("Please be carefull, marker should be orthogonals, ", right_gap.dot(up_gap), " 
			for this generation: they are replaced with (1,0,0) for right and (0,1,0) for up")
		right_gap = Vector3(1,0,0) * gapBetweenCubeCenter * room_scale
		up_gap = Vector3(0,1,0) * gapBetweenCubeCenter * room_scale
	elif right_gap.dot(up_gap) != 0:
		print("DEBUG: approximation, manually fixed ! ", right_gap.dot(up_gap), " is close to 0")
		up_gap = right_gap.cross(depth_gap).normalized() * gapBetweenCubeCenter * room_scale
	
	var up_nbr = 0
	var depth_nbr = 0
	
	var source = Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)
	var target = Basis(
		right_gap.normalized(),
		up_gap.normalized(),
		depth_gap.normalized()
	)
	
	var euler = _get_rotation_from_basis(source, target)
	
	var time_start
	var time_end
	
	var sizeBase = cubeGraph._size
	var sizeFace = cubeGraph.getNbrRoomOnASide()
	var sizeTotal = cubeGraph.getNbrRoom()
	
	var depthReached = cubeGraph.get_deepest()
	
	# DEBUG: for size > 2: update depth using tag_spread from room 24
	#tag_spreads_wide_way(24, 0, 4, [0, depthReached*1/4, depthReached*2/4, depthReached*3/4, depthReached])
	# update second tag:
	#tag_spreads_wide_way(24, 1, 4, [0, depthReached*1/4, depthReached*2/4, depthReached*3/4, depthReached])
	
	time_start = Time.get_ticks_msec()
	for i in range(sizeTotal):
		#if i%sizeBase == sizeBase - 1: print((100*i)/sizeTotal, "%")
		#print(xCoord, " ", yCoord, " ", zCoord)
		#print(cubeGraph.getNeighbors(i))
		
		var cube = CubeCustom.new(
			curr_pos, 
			cubeGraph.getNeighborsConnection(i), 
			cubeGraph.getColor(i), 
			depthReached,
			debug,
			showWall,
			triColor,
			wall_mat,
			room_scale
		)
		
		cube.rotation = euler
		
		add_child(cube)
		maze[i] = cube
		
		curr_pos += right_gap
		
		if i%(sizeBase) == sizeBase - 1:
			up_nbr += 1
			curr_pos = defaul_start_pos + up_gap * up_nbr + depth_gap * depth_nbr
		
		if i%(sizeFace) == (sizeFace) - 1:
			up_nbr = 0
			depth_nbr += 1
			curr_pos = defaul_start_pos + up_gap * up_nbr + depth_gap * depth_nbr
		
		# TODO : WIP, find a way to continue moving while rendering graph
		# this following line slow down the render but regenerate (while generating)
		# could send errors (try to delete not existing node)
		# await get_tree().create_timer(0.001).timeout 
		
	time_end = Time.get_ticks_msec()
#	print(cubeGraph.colorsIds)
#	print(cubeGraph.depths)
	print("100% cube in " + str((time_end - time_start)/1000) + "s "+ \
		str((time_end - time_start)%1000) + "ms.")
	
	if debug:
		time_start = Time.get_ticks_msec()
		instantiatePyramidConnection(maze)
		time_end = Time.get_ticks_msec()
		print("instantiatePyramid in " + str((time_end - time_start)/1000) + "s "+ \
			str((time_end - time_start)%1000) + "ms.\n")

func _on_menu_generation(edgeSize) -> void:
	clean()
	generate(edgeSize)
	display()

func clean() -> void:
	maze.clear()
	for i in self.get_children():
		if i is CubeCustom:
			i.clean()
			self.remove_child(i)
			i.queue_free()
		elif i is MeshInstance3D:
			self.remove_child(i)
			i.queue_free()
	
	if cubeGraph != null:
		cubeGraph.clean()

func createPath_deepWay(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	
	stack.append(beginId)
	cubeGraph.setVisited(beginId) # not interesting to remove this line
	#cubeGraph.setDepth(beginId, 0)
	
	var currId = beginId
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId))
		#print(neighborsToExplo)
		
		if len(neighborsToExplo) == 0:
			currId = stack.pop_back()
			continue
		
		stack.append(currId)
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId

# Inconclusive
func createPath_deepWay_alt_1(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	stack.append(beginId)
	cubeGraph.setVisited(beginId)
	
	var currId = beginId
	var i = 0
	var newId
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId))
		#print(neighborsToExplo)
		
		if len(neighborsToExplo) == 0:
			currId = stack.pop_back()
			continue
		
		stack.append(currId)
		
		newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		var prevId = currId
		currId = newId
		i += 1
		
		if i >= cubeGraph.getNbrRoomOnASide() && not neighborsToExplo.is_empty():
			#print("alt Way ?")
			stack.append(currId)
			
			newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
			cubeGraph.connectNeighbors(prevId, newId)
			cubeGraph.setVisited(newId)
			currId = newId
			i = 0

func createPath_deepWay_alt_2(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	
	stack.append(beginId)
	cubeGraph.setVisited(beginId) # not interesting to remove this line
	
	var currId = beginId
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId))
		
		if len(neighborsToExplo) == 0:
			currId = stack.pop_at(rng.randi() % stack.size())
			continue
		
		stack.append(currId)
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId

# TODO : a deepgeneration with sometimes a switch on wide generation

func createPath_deepWay_layer_by_layer(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	
	stack.append(beginId)
	cubeGraph.setVisited(beginId)
	
	var currId = beginId
	var lastUpdated = currId
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		# with "true" get only neighbors on the same layer
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId, true))
		#print(neighborsToExplo)
		
		if len(neighborsToExplo) == 0:
			currId = stack.pop_back()
			# when all nodes are already visited (stack empty) and we are 
			# back to the beginning, connect the last updated node (means the 
			# last dead end) with the upper layer if exist
			if stack.is_empty() && cubeGraph.hasUpNeighbors(lastUpdated):
				currId = cubeGraph.getUpNeighbors(lastUpdated)
				stack.append(currId)
				cubeGraph.connectNeighbors(lastUpdated, currId)
				cubeGraph.setVisited(currId)
			continue
		
		stack.append(currId)
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId
		lastUpdated = currId

func createPath_deepWay_layer_by_layer_alt_1(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	
	stack.append(beginId)
	
	var currId = beginId
	var lastUpdated = currId
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		# with "true" get only neighbors on the same layer
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId, true))
		#print(neighborsToExplo)
		
		if len(neighborsToExplo) == 0:
			currId = stack.pop_back()
			# when all nodes are allready visited (stack empty) and we are 
			# back to the begining, connect the last updated node (means the 
			# last dead end) with the upper layer if exist
			if stack.is_empty() && cubeGraph.hasUpNeighbors(lastUpdated):
				currId = cubeGraph.getUpNeighbors(lastUpdated)
				stack.append(currId)
				cubeGraph.connectNeighbors(lastUpdated, currId)
				cubeGraph.setVisited(currId)
			continue
		
		stack.append(currId)
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId
		lastUpdated = currId

# connection between layer is always on the deppest room from layer beginning
func createPath_deepWay_layer_by_layer_alt_2(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	var currId = beginId
	var depth:int = 0
	
	var deepestId = beginId
	var currMaxDepth = 0
	
	stack.append(currId)
	cubeGraph.setVisited(currId)
	#print("d-setDepth(", currId, ",", depth, ")")
	cubeGraph.setDepth(currId, depth)
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		# with "true" get only neighbors on the same layer
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId, true))
		depth = cubeGraph.getDepth(currId)
		
		if len(neighborsToExplo) == 0:
			if currMaxDepth < depth :
				currMaxDepth = depth
				deepestId = currId
			
			currId = stack.pop_back()
			cubeGraph.setVisited(currId)
			
			# when all nodes are already visited (stack empty) and we are 
			# back to the begining, connect the last updated node (means the 
			# last dead end) with the upper layer if exist
			if stack.is_empty() && cubeGraph.hasUpNeighbors(deepestId):
				currId = cubeGraph.getUpNeighbors(deepestId)
				stack.append(currId)
				cubeGraph.connectNeighbors(deepestId, currId)
				cubeGraph.setVisited(currId)
				
				#print("c-setDepth(", currId, ",", depth, ")")
				currMaxDepth = cubeGraph.getDepth(deepestId) + 1
				cubeGraph.setDepth(currId, currMaxDepth)
				deepestId = currId
			continue
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		cubeGraph.setDepth(newId, depth + 1)
		currId = newId
		stack.append(currId)

# 2 transitions between layers
func createPath_deepWay_layer_by_layer_alt_3(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	var currId = beginId
	var depth:int = 0
	var deepestId = currId
	var currMaxDepth = 0
	
	var secondLayerTransitionId = -1
	var lastSecondId = secondLayerTransitionId
	var lastDeepestId = deepestId
	
	stack.append(currId)
	cubeGraph.setVisited(currId)
	cubeGraph.setDepth(currId, depth)
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId, true))
		depth = cubeGraph.getDepth(currId)
		
		if len(neighborsToExplo) == 0:
			if currMaxDepth < depth && currId != lastDeepestId && currId != lastSecondId:
				secondLayerTransitionId = deepestId
				
				currMaxDepth = depth
				deepestId = currId
			
			currId = stack.pop_back()
			cubeGraph.setVisited(currId)
			
			# when all nodes are already visited (stack empty) and we are 
			# back to the begining, connect the last updated node (means the 
			# last dead end) with the upper layer if exist
			if stack.is_empty() && cubeGraph.hasUpNeighbors(deepestId):
				currId = cubeGraph.getUpNeighbors(deepestId)
				stack.append(currId)
				cubeGraph.connectNeighbors(deepestId, currId)
				cubeGraph.setVisited(currId)
				
				currMaxDepth = cubeGraph.getDepth(deepestId) + 1
				cubeGraph.setDepth(currId, currMaxDepth)
				deepestId = currId
				
				if secondLayerTransitionId != lastSecondId && \
				   secondLayerTransitionId != lastDeepestId && \
				   cubeGraph.hasUpNeighbors(secondLayerTransitionId):
					cubeGraph.connectNeighbors(secondLayerTransitionId, 
						cubeGraph.getUpNeighbors(secondLayerTransitionId))
					lastSecondId = cubeGraph.getUpNeighbors(secondLayerTransitionId)
				else:
					lastSecondId = -1
					
				lastDeepestId = deepestId
			continue
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId
		cubeGraph.setDepth(currId, depth + 1)
		stack.append(currId)

# cubeGraph._size*(1/3) transitions between layers
func createPath_deepWay_layer_by_layer_alt_4(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	var currId = beginId
	var depth:int = 0
	var deepestId = currId
	var currMaxDepth = 0
	
	var secondLayerTransitionId = []
	var lastSecondId = []
	var lastDeepestId = deepestId
	var additionalConnections = int(cubeGraph._size * (1/3.) - 1)
	
	for i in range(additionalConnections):
		secondLayerTransitionId.append(-1)
		lastSecondId.append(-1)
	
	stack.append(currId)
	cubeGraph.setVisited(currId)
	#print("d-setDepth(", currId, ",", depth, ")")
	cubeGraph.setDepth(currId, depth)
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		# with "true" get only neighbors on the same layer
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId, true))
		depth = cubeGraph.getDepth(currId)
		
		if len(neighborsToExplo) == 0:
			if currMaxDepth < depth && currId != lastDeepestId && currId not in lastSecondId:
				var indexForTransition = 0
				var currSmallestDepth = cubeGraph.getNbrRoom() + 2
				for i in range(additionalConnections):
					if secondLayerTransitionId[i] == -1:
						indexForTransition = i
						break
					if secondLayerTransitionId[i] != -1 && \
					   currSmallestDepth > cubeGraph.getDepth(secondLayerTransitionId[i]):
						indexForTransition = i
						currSmallestDepth = cubeGraph.getDepth(secondLayerTransitionId[i])
				if additionalConnections > 0:
					secondLayerTransitionId[indexForTransition] = deepestId
				
				currMaxDepth = depth
				deepestId = currId
			
			currId = stack.pop_back()
			cubeGraph.setVisited(currId)
			
			# when all nodes are already visited (stack empty) and we are 
			# back to the begining, connect the last updated node (means the 
			# last dead end) with the upper layer if exist
			if stack.is_empty() && cubeGraph.hasUpNeighbors(deepestId):
				currId = cubeGraph.getUpNeighbors(deepestId)
				stack.append(currId)
				cubeGraph.connectNeighbors(deepestId, currId)
				cubeGraph.setVisited(currId)
				
				currMaxDepth = cubeGraph.getDepth(deepestId) + 1
				cubeGraph.setDepth(currId, currMaxDepth)
				deepestId = currId
				
				for i in range(additionalConnections):
					if secondLayerTransitionId[i] not in lastSecondId && \
					   secondLayerTransitionId[i] != lastDeepestId && \
					   cubeGraph.hasUpNeighbors(secondLayerTransitionId[i]):
						cubeGraph.connectNeighbors(secondLayerTransitionId[i], 
							cubeGraph.getUpNeighbors(secondLayerTransitionId[i]))
					else:
						secondLayerTransitionId[i] = -1
				for i in range(additionalConnections):
					lastSecondId[i] = cubeGraph.getUpNeighbors(secondLayerTransitionId[i])
				lastDeepestId = deepestId
			continue
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId
		cubeGraph.setDepth(currId, depth + 1)
		stack.append(currId)

# random number of transition transitions between layers max : cubeGraph._size*(1/3)
func createPath_deepWay_layer_by_layer_alt_5(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	var currId = beginId
	var depth:int = 0
	var deepestId = beginId
	var currMaxDepth = 0
	
	var lastSecondId = []
	var lastDeepestId = deepestId
	var secondLayerTransitionId = []
	var maxAdditionalConnections = int(cubeGraph._size * (1/3.) - 1)
	var currentAdditionalConnection = rng.randi_range(0, maxAdditionalConnections)
	
	for i in range(maxAdditionalConnections):
		secondLayerTransitionId.append(-1)
		lastSecondId.append(-1)
	
	stack.append(currId)
	cubeGraph.setVisited(currId)
	#print("d-setDepth(", currId, ",", depth, ")")
	cubeGraph.setDepth(currId, depth)
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		# with "true" get only neighbors on the same layer
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId, true))
		depth = cubeGraph.getDepth(currId)
		
		if len(neighborsToExplo) == 0:
			if currMaxDepth < depth && currId != lastDeepestId && currId not in lastSecondId:
				var indexForTransition = 0
				var currSmallestDepth = cubeGraph.getNbrRoom() + 2
				for i in range(currentAdditionalConnection):
					if secondLayerTransitionId[i] == -1:
						indexForTransition = i
						break
					if secondLayerTransitionId[i] != -1 && \
					   currSmallestDepth > cubeGraph.getDepth(secondLayerTransitionId[i]):
						indexForTransition = i
						currSmallestDepth = cubeGraph.getDepth(secondLayerTransitionId[i])
				if currentAdditionalConnection > 0:
					secondLayerTransitionId[indexForTransition] = deepestId
				
				currMaxDepth = depth
				deepestId = currId
			
			currId = stack.pop_back()
			cubeGraph.setVisited(currId)
			
			# when all nodes are allready visited (stack empty) and we are 
			# back to the begining, connect the last updated node (means the 
			# last dead end) with the upper layer if exist
			if stack.is_empty() && cubeGraph.hasUpNeighbors(deepestId):
				currId = cubeGraph.getUpNeighbors(deepestId)
				stack.append(currId)
				cubeGraph.connectNeighbors(deepestId, currId)
				cubeGraph.setVisited(currId)
				
				currMaxDepth = cubeGraph.getDepth(deepestId) + 1
				cubeGraph.setDepth(currId, currMaxDepth)
				deepestId = currId
				
				for i in range(currentAdditionalConnection):
					if secondLayerTransitionId[i] not in lastSecondId && \
					   secondLayerTransitionId[i] != lastDeepestId && \
					   cubeGraph.hasUpNeighbors(secondLayerTransitionId[i]):
						cubeGraph.connectNeighbors(secondLayerTransitionId[i], 
							cubeGraph.getUpNeighbors(secondLayerTransitionId[i]))
					else:
						secondLayerTransitionId[i] = -1
				for i in range(currentAdditionalConnection):
					lastSecondId[i] = cubeGraph.getUpNeighbors(secondLayerTransitionId[i])
				lastDeepestId = deepestId
				# set random nbr of connection for the next transition layer
				currentAdditionalConnection = rng.randi_range(0, maxAdditionalConnections)
			continue
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId
		cubeGraph.setDepth(currId, depth + 1)
		stack.append(currId)

# random number of transition transitions between layers max : cubeGraph._size*(1/3)
# shuffle the stack on deadend
func createPath_deepWay_layer_by_layer_alt_6(beginId: int = 0):
	var neighborsToExplo = []
	var stack = []
	var currId = beginId
	var depth:int = 0
	var deepestId = beginId
	var currMaxDepth = 0
	
	var lastSecondId = []
	var lastDeepestId = deepestId
	var secondLayerTransitionId = []
	var maxAdditionalConnections = int(cubeGraph._size * (1/3.) - 1)
	var currentAdditionalConnection = rng.randi_range(0, maxAdditionalConnections)
	
	for i in range(maxAdditionalConnections):
		secondLayerTransitionId.append(-1)
		lastSecondId.append(-1)
	
	stack.append(currId)
	cubeGraph.setVisited(currId)
	#print("d-setDepth(", currId, ",", depth, ")")
	cubeGraph.setDepth(currId, depth)
	
	while not stack.is_empty():
		neighborsToExplo.clear()
		# with "true" get only neighbors on the same layer
		neighborsToExplo.append_array(cubeGraph.getNotVisitedNeighbors(currId, true))
		depth = cubeGraph.getDepth(currId)
		
		if len(neighborsToExplo) == 0:
			if currMaxDepth < depth && currId != lastDeepestId && currId not in lastSecondId:
				var indexForTransition = 0
				var currSmallestDepth = cubeGraph.getNbrRoom() + 2
				for i in range(currentAdditionalConnection):
					if secondLayerTransitionId[i] == -1:
						indexForTransition = i
						break
					if secondLayerTransitionId[i] != -1 && \
					   currSmallestDepth > cubeGraph.getDepth(secondLayerTransitionId[i]):
						indexForTransition = i
						currSmallestDepth = cubeGraph.getDepth(secondLayerTransitionId[i])
				if currentAdditionalConnection > 0:
					secondLayerTransitionId[indexForTransition] = deepestId
				
				currMaxDepth = depth
				deepestId = currId
			
			currId = stack.pop_at(rng.randi() % stack.size())
			#cubeGraph.setVisited(currId)
			
			# when all nodes are allready visited (stack empty) and we are 
			# back to the begining, connect the last updated node (means the 
			# last dead end) with the upper layer if exist
			if stack.is_empty() && cubeGraph.hasUpNeighbors(deepestId):
				currId = cubeGraph.getUpNeighbors(deepestId)
				stack.append(currId)
				cubeGraph.connectNeighbors(deepestId, currId)
				cubeGraph.setVisited(currId)
				
				currMaxDepth = cubeGraph.getDepth(deepestId) + 1
				cubeGraph.setDepth(currId, currMaxDepth)
				deepestId = currId
				
				for i in range(currentAdditionalConnection):
					if secondLayerTransitionId[i] not in lastSecondId && \
					   secondLayerTransitionId[i] != lastDeepestId && \
					   cubeGraph.hasUpNeighbors(secondLayerTransitionId[i]):
						cubeGraph.connectNeighbors(secondLayerTransitionId[i], 
							cubeGraph.getUpNeighbors(secondLayerTransitionId[i]))
						#print("connect: ", secondLayerTransitionId[i], " and: ", cubeGraph.getUpNeighbors(secondLayerTransitionId[i]))
					else:
						secondLayerTransitionId[i] = -1
				#print(currentAdditionalConnection, " ", lastDeepestId, " ", lastSecondId)
				for i in range(currentAdditionalConnection):
					lastSecondId[i] = cubeGraph.getUpNeighbors(secondLayerTransitionId[i])
				lastDeepestId = deepestId
				# set random nbr of connection for the next transition layer
				currentAdditionalConnection = rng.randi_range(0, maxAdditionalConnections)
				#print(currentAdditionalConnection, " ", lastDeepestId, " ", lastSecondId)
			continue
		
		var newId = neighborsToExplo.pop_at(rng.randi() % neighborsToExplo.size())
		cubeGraph.connectNeighbors(currId, newId)
		cubeGraph.setVisited(newId)
		currId = newId
		cubeGraph.setDepth(currId, depth + 1)
		stack.append(currId)


# BE CAREFUL : this function reset depth and color stored of cubeGraph 
# using beginId for the new depth computation, 0 by default
func deepensPath_wideWay(beginId: int = 0):
	cubeGraph.reset_Depth_Color_Visited()
	
	var neighbors: Array[int]
	var depth: int = 0
	neighbors = cubeGraph.getNeighborsConnectionNotVisited(beginId)
	cubeGraph.setDepth(beginId, depth)
	cubeGraph.setVisited(beginId)
	for i in neighbors:
		cubeGraph.setVisited(i)
	
	var neighborsNext: Array[int]
	
	while(!neighbors.is_empty()) :
		neighborsNext = neighbors.duplicate()
		neighbors.clear()
		depth += 1
		while(!neighborsNext.is_empty()):
			var currentNeighbor:int = neighborsNext.pop_back() # neighbors to process
			cubeGraph.setDepth(currentNeighbor, depth)
			for i in cubeGraph.getNeighborsConnectionNotVisited(currentNeighbor):
				neighbors.append(i)
				cubeGraph.setVisited(i)
	
	cubeGraph.setColorFromDepth()

func clean_tag_wide_way(begin_id: int = 0, tag_id: int = 0, max_depth: int = 5, default_tag_value:int = -1) -> void:
	cubeGraph.resetVisited()
	
	var neighbors: Array[int]
	var depth: int = 0
	neighbors = cubeGraph.getNeighborsConnectionNotVisited(begin_id)
	cubeGraph.set_tag(begin_id, tag_id, default_tag_value)
	cubeGraph.setVisited(begin_id)
	for i in neighbors:
		cubeGraph.setVisited(i)
	
	var neighborsNext: Array[int]
	
	while(!neighbors.is_empty() && depth < max_depth):
		neighborsNext = neighbors.duplicate()
		neighbors.clear()
		depth += 1
		
		while(!neighborsNext.is_empty()):
			var currentNeighbor:int = neighborsNext.pop_back()
			cubeGraph.set_tag(currentNeighbor, tag_id, default_tag_value)
			for i in cubeGraph.getNeighborsConnectionNotVisited(currentNeighbor):
				neighbors.append(i)
				cubeGraph.setVisited(i)

func tag_spreads_wide_way(begin_id:int, tag_id:int, max_depth:int, values:Array) -> void:
	if not cubeGraph.isInRange(begin_id):
		push_error("begin_id out of range, aborted ! For current graph, should be lower than:", cubeGraph.getNbrRoom())
		return
	if not cubeGraph.isTagInRange(tag_id):
		push_error("tag_id not in tags, aborted ! For current graph, should be lower than:", cubeGraph.get_nbr_tag())
		return
	if max_depth < 1:
		push_error("max_depth cannot be less or equal to 0, aborted !")
		return
	
	if len(values) - 1 < max_depth:
		push_warning("Too fiew values for max_depth: ", max_depth, ", len of values should be: ", 
		max_depth + 1, ", actually is: ", len(values), "! Values sets to [0..", max_depth, "].")
		values.clear()
		values = range(max_depth + 1)
	
	cubeGraph.resetVisited()
	
	var neighbors: Array[int]
	var depth: int = 0
	neighbors = cubeGraph.getNeighborsConnectionNotVisited(begin_id)
	cubeGraph.set_tag(begin_id, tag_id, values[depth])
	cubeGraph.setVisited(begin_id)
	for i in neighbors:
		cubeGraph.setVisited(i)
	
	var neighborsNext: Array[int]
	
	while(!neighbors.is_empty() && depth < max_depth):
		neighborsNext = neighbors.duplicate()
		neighbors.clear()
		depth += 1
		
		while(!neighborsNext.is_empty()):
			var currentNeighbor:int = neighborsNext.pop_back()
			cubeGraph.set_tag(currentNeighbor, tag_id, values[depth])
			for i in cubeGraph.getNeighborsConnectionNotVisited(currentNeighbor):
				neighbors.append(i)
				cubeGraph.setVisited(i)

func get_tag(room_id: int, tag_id: int) -> int:
	return cubeGraph.get_tag(room_id, tag_id)

func instantiatePyramidConnection(mazeUsed: Dictionary):
	var depthReached = cubeGraph.get_deepest()
	for id in mazeUsed:
		for i in cubeGraph.getNextNeighbors(id):
			# print(id, " ", i, " ", (mazeUsed[i].getCenter() - mazeUsed[id].getCenter()).normalized())
			add_child(
				cubeGraph.instantiate_pyramid(
					mazeUsed[id].getCenter(),
					mazeUsed[i].getCenter() - mazeUsed[id].getCenter(),
					cubeGraph.computeColor(cubeGraph.getDepth(id), depthReached)
				)
			)

func instantiatePyramidConnection_allNeighbors(mazeUsed: Dictionary):
	var depthReached = cubeGraph.get_deepest()
	for id in mazeUsed:
		for i in cubeGraph.getNeighbors(id):
			if i > -1 && cubeGraph.isFollowing(id, i):
				add_child(
					cubeGraph.instantiate_pyramid(
						mazeUsed[id].getCenter(),
						mazeUsed[i].getCenter() - mazeUsed[id].getCenter(),
						cubeGraph.computeColor(cubeGraph.getDepth(id), depthReached)
					)
				)
