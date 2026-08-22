extends Node

func _ready():
	print("[MathUtils] Math utils started")
	perlin_set_seed(12345)

# ==================== Random ====================

func set_random_seed(seed):
	seed(seed)

func random_int(min_val, max_val):
	return randi() % (max_val - min_val + 1) + min_val

func random_float(min_val, max_val):
	return randf() * (max_val - min_val) + min_val

func random_bool(chance):
	if chance == null:
		chance = 0.5
	return randf() < chance

func random_from_array(arr):
	if arr.size() == 0:
		return null
	return arr[random_int(0, arr.size() - 1)]

func shuffle_array(arr):
	var result = arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j = random_int(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result

func random_color():
	return Color(randf(), randf(), randf())

func random_color_range(min_color, max_color):
	return Color(
		random_float(min_color.r, max_color.r),
		random_float(min_color.g, max_color.g),
		random_float(min_color.b, max_color.b)
	)

# ==================== Interpolation ====================

func lerp(a, b, t):
	return a + (b - a) * t

func lerp_angle(a, b, t):
	var diff = fmod(b - a, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return a + diff * t

func smoothstep(a, b, t):
	var x = clamp((t - a) / (b - a), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func smootherstep(a, b, t):
	var x = clamp((t - a) / (b - a), 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)

func ease_in(t, power):
	if power == null:
		power = 2.0
	return pow(t, power)

func ease_out(t, power):
	if power == null:
		power = 2.0
	return 1.0 - pow(1.0 - t, power)

func ease_in_out(t, power):
	if power == null:
		power = 2.0
	if t < 0.5:
		return pow(2.0 * t, power) / 2.0
	else:
		return 1.0 - pow(-2.0 * t + 2.0, power) / 2.0

func lerp_vector(a, b, t):
	return a.lerp(b, t)

# ==================== Geometry ====================

func distance(a, b):
	return a.distance_to(b)

func distance_squared(a, b):
	return a.distance_squared_to(b)

func distance_2d(x1, y1, x2, y2):
	return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))

func angle_between(a, b):
	return a.angle_to(b)

func direction_to(from, to):
	return (to - from).normalized()

func rotate_vector(v, angle):
	return v.rotated(angle)

func normalize_vector(v):
	return v.normalized()

func clamp_value(value, min_val, max_val):
	return clamp(value, min_val, max_val)

func clamp_vector(v, min_val, max_val):
	return Vector2(clamp(v.x, min_val, max_val), clamp(v.y, min_val, max_val))

func point_in_rect(point, rect):
	return rect.has_point(point)

func point_in_circle(point, center, radius):
	return point.distance_squared_to(center) <= radius * radius

func rects_overlap(rect1, rect2):
	return rect1.intersects(rect2)

func circle_rect_overlap(circle_center, circle_radius, rect):
	var closest_x = clamp(circle_center.x, rect.position.x, rect.position.x + rect.size.x)
	var closest_y = clamp(circle_center.y, rect.position.y, rect.position.y + rect.size.y)
	var distance_x = circle_center.x - closest_x
	var distance_y = circle_center.y - closest_y
	return (distance_x * distance_x + distance_y * distance_y) <= (circle_radius * circle_radius)

func vector_to_angle(v):
	return v.angle()

func angle_to_vector(angle):
	return Vector2(cos(angle), sin(angle))

func midpoint(a, b):
	return (a + b) / 2.0

func triangle_area(p1, p2, p3):
	return abs((p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y)) / 2.0)

# ==================== Probability ====================

func uniform_distribution(min_val, max_val):
	return random_float(min_val, max_val)

func normal_distribution(mean, std_dev):
	if mean == null:
		mean = 0.0
	if std_dev == null:
		std_dev = 1.0
	var u1 = randf()
	var u2 = randf()
	if u1 < 0.0001:
		u1 = 0.0001
	var z0 = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return mean + z0 * std_dev

func exponential_distribution(lambda_val):
	if lambda_val == null:
		lambda_val = 1.0
	if lambda_val <= 0.0:
		return 0.0
	var u = randf()
	if u < 0.0001:
		u = 0.0001
	return -log(u) / lambda_val

func weighted_random(items, weights):
	if items.size() == 0 or weights.size() == 0:
		return null
	if items.size() != weights.size():
		return null
	var total_weight = 0.0
	for w in weights:
		total_weight += w
	if total_weight <= 0.0:
		return random_from_array(items)
	var r = random_float(0.0, total_weight)
	var cumulative = 0.0
	for i in range(items.size()):
		cumulative += weights[i]
		if r <= cumulative:
			return items[i]
	return items[items.size() - 1]

func percent_chance(percent):
	return randf() * 100.0 < percent

func dice_roll(num_dice, sides):
	var total = 0
	for i in range(num_dice):
		total += random_int(1, sides)
	return total

func gaussian_sample(mean, std_dev, num_samples):
	if mean == null:
		mean = 0.0
	if std_dev == null:
		std_dev = 1.0
	if num_samples == null:
		num_samples = 12
	var sum = 0.0
	for i in range(num_samples):
		sum += randf()
	return mean + std_dev * (sum - num_samples / 2.0) / sqrt(num_samples / 12.0)

# ==================== Perlin Noise ====================

var _perlin_permutation = []
var _perlin_seed = 0

func perlin_set_seed(seed):
	_perlin_seed = seed
	_perlin_permutation.clear()
	var p = []
	for i in range(256):
		p.append(i)
	p = shuffle_array(p)
	for i in range(512):
		_perlin_permutation.append(p[i % 256])

func _perlin_fade(t):
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

func _perlin_lerp(a, b, t):
	return a + t * (b - a)

func _perlin_grad(hash_val, x, y):
	var h = hash_val & 3
	var u = x
	if h >= 2:
		u = y
	var v = y
	if h >= 2:
		v = x
	var u_result = u
	if (h & 1) != 0:
		u_result = -u
	var v_result = v
	if (h & 2) != 0:
		v_result = -v
	return u_result + v_result

func perlin_noise_2d(x, y):
	if _perlin_permutation.size() == 0:
		perlin_set_seed(_perlin_seed)
	var X = int(floor(x)) & 255
	var Y = int(floor(y)) & 255
	x -= floor(x)
	y -= floor(y)
	var u = _perlin_fade(x)
	var v = _perlin_fade(y)
	var A = _perlin_permutation[X] + Y
	var B = _perlin_permutation[X + 1] + Y
	return _perlin_lerp(
		_perlin_lerp(_perlin_grad(_perlin_permutation[A], x, y), _perlin_grad(_perlin_permutation[B], x - 1, y), u),
		_perlin_lerp(_perlin_grad(_perlin_permutation[A + 1], x, y - 1), _perlin_grad(_perlin_permutation[B + 1], x - 1, y - 1), u),
		v
	)

func _perlin_grad_3d(hash_val, x, y, z):
	var h = hash_val & 15
	var u = x
	if h >= 8:
		u = y
	var v = y
	if h >= 4:
		if h == 12 or h == 14:
			v = z
		else:
			v = x
	var u_result = u
	if (h & 1) != 0:
		u_result = -u
	var v_result = v
	if (h & 2) != 0:
		v_result = -v
	return u_result + v_result

func perlin_noise_3d(x, y, z):
	if _perlin_permutation.size() == 0:
		perlin_set_seed(_perlin_seed)
	var X = int(floor(x)) & 255
	var Y = int(floor(y)) & 255
	var Z = int(floor(z)) & 255
	x -= floor(x)
	y -= floor(y)
	z -= floor(z)
	var u = _perlin_fade(x)
	var v = _perlin_fade(y)
	var w = _perlin_fade(z)
	var A = _perlin_permutation[X] + Y
	var AA = _perlin_permutation[A] + Z
	var AB = _perlin_permutation[A + 1] + Z
	var B = _perlin_permutation[X + 1] + Y
	var BA = _perlin_permutation[B] + Z
	var BB = _perlin_permutation[B + 1] + Z
	return _perlin_lerp(
		_perlin_lerp(
			_perlin_lerp(_perlin_grad_3d(_perlin_permutation[AA], x, y, z), _perlin_grad_3d(_perlin_permutation[BA], x - 1, y, z), u),
			_perlin_lerp(_perlin_grad_3d(_perlin_permutation[AB], x, y - 1, z), _perlin_grad_3d(_perlin_permutation[BB], x - 1, y - 1, z), u),
			v
		),
		_perlin_lerp(
			_perlin_lerp(_perlin_grad_3d(_perlin_permutation[AA + 1], x, y, z - 1), _perlin_grad_3d(_perlin_permutation[BA + 1], x - 1, y, z - 1), u),
			_perlin_lerp(_perlin_grad_3d(_perlin_permutation[AB + 1], x, y - 1, z - 1), _perlin_grad_3d(_perlin_permutation[BB + 1], x - 1, y - 1, z - 1), u),
			v
		),
		w
	)

func fractal_noise_2d(x, y, octaves, persistence, lacunarity):
	if octaves == null:
		octaves = 4
	if persistence == null:
		persistence = 0.5
	if lacunarity == null:
		lacunarity = 2.0
	var total = 0.0
	var frequency = 1.0
	var amplitude = 1.0
	var max_value = 0.0
	for i in range(octaves):
		total += perlin_noise_2d(x * frequency, y * frequency) * amplitude
		max_value += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	return total / max_value

func fractal_noise_3d(x, y, z, octaves, persistence, lacunarity):
	if octaves == null:
		octaves = 4
	if persistence == null:
		persistence = 0.5
	if lacunarity == null:
		lacunarity = 2.0
	var total = 0.0
	var frequency = 1.0
	var amplitude = 1.0
	var max_value = 0.0
	for i in range(octaves):
		total += perlin_noise_3d(x * frequency, y * frequency, z * frequency) * amplitude
		max_value += amplitude
		amplitude *= persistence
		frequency *= lacunarity
	return total / max_value

# ==================== Utilities ====================

func map_value(value, in_min, in_max, out_min, out_max):
	return out_min + (out_max - out_min) * ((value - in_min) / (in_max - in_min))

func wrap(value, min_val, max_val):
	var range_val = max_val - min_val
	if range_val == 0:
		return min_val
	return value - range_val * floor((value - min_val) / range_val)

func approach(current, target, delta):
	if current < target:
		return min(current + delta, target)
	elif current > target:
		return max(current - delta, target)
	return current

func sign_nonzero(value):
	if value > 0:
		return 1
	elif value < 0:
		return -1
	return 1

func is_approximately(a, b, epsilon):
	if epsilon == null:
		epsilon = 0.0001
	return abs(a - b) < epsilon

func degrees_to_radians(degrees):
	return degrees * PI / 180.0

func radians_to_degrees(radians):
	return radians * 180.0 / PI
