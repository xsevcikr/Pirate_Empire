extends TestCase


func test_height_inversion_matches_displaced_surface() -> void:
	var w := WaveModel.new(6.0, Vector2(1, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 200:
		var x: float = rng.randf_range(-500.0, 500.0)
		var z: float = rng.randf_range(-500.0, 500.0)
		var t: float = rng.randf_range(0.0, 100.0)
		var h: float = w.height_at(x, z, t)
		# Find the rest-position whose displaced point lands on (x, z): its height must equal h.
		var px: float = x
		var pz: float = z
		for _j in 8:
			var q: Vector3 = w.displaced(px, pz, t)
			px += x - q.x
			pz += z - q.z
		var final: Vector3 = w.displaced(px, pz, t)
		assert_near(final.x, x, 0.01, "x residual")
		assert_near(final.z, z, 0.01, "z residual")
		assert_near(final.y, h, 0.05, "height")


func test_glassy_sea_is_flat() -> void:
	var w := WaveModel.new(0.0)
	for i in 50:
		assert_true(absf(w.height_at(i * 13.0, i * 7.0, i * 1.3)) < 0.2, "sea state 0 within 0.2 m")


func test_significant_wave_height_matches_table() -> void:
	for ss: float in [2.0, 4.0, 6.0, 8.0]:
		var w := WaveModel.new(ss)
		var expected: float = WaveModel.sea_params(ss)["height"]
		var samples: Array[float] = []
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 4000:
			samples.append(w.height_at(rng.randf_range(-3000.0, 3000.0), rng.randf_range(-3000.0, 3000.0), rng.randf_range(0.0, 600.0)))
		var mean_sq: float = 0.0
		for s in samples:
			mean_sq += s * s
		mean_sq /= samples.size()
		var hs: float = 4.0 * sqrt(mean_sq)
		assert_near(hs, expected, expected * 0.35, "Hs at sea state %s" % ss)


func test_steepness_never_self_intersects() -> void:
	for ss: float in [0.0, 3.0, 6.0, 9.0]:
		var w := WaveModel.new(ss)
		var total: float = 0.0
		for i in WaveModel.WAVE_COUNT:
			total += w.wave_q[i] * w.wave_k[i] * w.wave_amp[i]
		assert_true(total <= 0.6, "sum Q*k*A <= 0.6 at state %s, got %s" % [ss, total])


func test_shader_arrays_have_all_waves() -> void:
	var w := WaveModel.new(4.0)
	assert_eq(w.shader_wave_a().size(), WaveModel.WAVE_COUNT)
	assert_eq(w.shader_wave_b().size(), WaveModel.WAVE_COUNT)
