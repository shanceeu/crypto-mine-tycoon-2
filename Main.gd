extends Node2D

const GRID_SIZE := 5
const TILE_W := 72
const TILE_H := 36

const STAGES := [
    "Prospector",
    "Mining Foreman",
    "Regional Operator",
    "Hash Farm CEO",
    "Global Crypto Empire",
    "Interstellar Crypto Dynasty"
]

const STAGE_TARGETS := [
    2500.0,
    12000.0,
    50000.0,
    180000.0,
    600000.0,
    2000000.0
]

const ASSET_ORDER := ["BTC", "ETH", "SOL"]

var tiles: Array = []
var selected_data: Dictionary = {}
var game_active := false
var event_timer := 0.0

var cash := 1800.0
var balances: Dictionary = {"BTC": 0.0, "ETH": 0.0, "SOL": 0.0}
var asset_prices: Dictionary = {"BTC": 45000.0, "ETH": 2600.0, "SOL": 140.0}
var total_hash_rate := 0.0
var power_capacity := 70.0
var power_usage := 0.0
var miners_owned := 0
var cooling_level := 1
var efficiency := 1.0
var stage_index := 0
var energy_boost := 0.0

var menu_root: CanvasLayer
var hud_root: CanvasLayer
var cash_label: Label
var btc_label: Label
var eth_label: Label
var sol_label: Label
var hash_label: Label
var power_label: Label
var market_label: Label
var selected_label: Label
var stage_label: Label
var objective_label: Label
var status_label: Label
var log_label: Label
var progress_bar: ProgressBar
var event_label: Label

func _ready() -> void:
    _build_menu()
    _build_game_world()
    _build_hud()
    _start_game()
    _update_progression()
    _update_ui()
    _set_status("Press Start to begin your crypto empire.")

func _start_game() -> void:
    game_active = true
    if menu_root != null:
        menu_root.visible = false
    if hud_root != null:
        hud_root.visible = true

    if selected_data.is_empty():
        selected_data = _find_first_available_tile()

    _set_status("Mining operation online.")

func _find_first_available_tile() -> Dictionary:
    for x in range(GRID_SIZE):
        for y in range(GRID_SIZE):
            var cell: Dictionary = tiles[x][y]
            if cell.has("occupied") and not cell["occupied"]:
                return cell
    return {}

func _build_menu() -> void:
    menu_root = CanvasLayer.new()
    add_child(menu_root)

    var root := MarginContainer.new()
    root.anchor_left = 0.0
    root.anchor_top = 0.0
    root.anchor_right = 1.0
    root.anchor_bottom = 1.0
    root.offset_left = 24
    root.offset_top = 24
    root.offset_right = -24
    root.offset_bottom = -24
    menu_root.add_child(root)

    var center := CenterContainer.new()
    center.anchor_left = 0.0
    center.anchor_top = 0.0
    center.anchor_right = 1.0
    center.anchor_bottom = 1.0
    root.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(600, 420)
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(vbox)

    var title := Label.new()
    title.text = "Crypto Mine Tycoon 2"
    title.add_theme_font_size_override("font_size", 34)
    title.modulate = Color(0.88, 0.96, 1.0)
    vbox.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Build your empire, balance your hash power, and expand into multiple crypto markets."
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.custom_minimum_size = Vector2(500, 80)
    vbox.add_child(subtitle)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 18)
    vbox.add_child(spacer)

    var start_button := Button.new()
    start_button.text = "Start Mining"
    start_button.custom_minimum_size = Vector2(260, 52)
    start_button.pressed.connect(_on_start_game_pressed)
    vbox.add_child(start_button)

    var reset_button := Button.new()
    reset_button.text = "Reset Run"
    reset_button.custom_minimum_size = Vector2(260, 52)
    reset_button.pressed.connect(_on_reset_game_pressed)
    vbox.add_child(reset_button)

    var quit_button := Button.new()
    quit_button.text = "Quit"
    quit_button.custom_minimum_size = Vector2(260, 52)
    quit_button.pressed.connect(_on_quit_game_pressed)
    vbox.add_child(quit_button)

func _build_game_world() -> void:
    for x in range(GRID_SIZE):
        tiles.append([])
        for y in range(GRID_SIZE):
            var tile_data: Dictionary = {
                "x": x,
                "y": y,
                "occupied": false,
                "rig_level": 0,
                "hash_rate": 0.0,
                "power_draw": 0.0,
                "node": null,
                "rig_node": null,
                "type": "mine"
            }

            var tile := Area2D.new()
            tile.position = _iso_to_screen(x, y)
            tile.set_meta("grid_pos", Vector2i(x, y))

            tile.input_event.connect(func(_viewport, event, _shape_idx):
                if not game_active:
                    return
                if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
                    selected_data = tile_data
                    _update_ui()
                    _set_status("Selected tile (%d, %d)." % [x, y])
            )

            var shape := CollisionPolygon2D.new()
            shape.polygon = PackedVector2Array([
                Vector2(0, -TILE_H * 0.5),
                Vector2(TILE_W * 0.5, 0),
                Vector2(0, TILE_H * 0.5),
                Vector2(-TILE_W * 0.5, 0)
            ])
            tile.add_child(shape)

            var ground := Polygon2D.new()
            ground.polygon = shape.polygon
            ground.color = Color(0.12, 0.15, 0.2)
            ground.texture = _make_ground_texture()
            ground.texture_scale = Vector2(0.5, 0.5)
            tile.add_child(ground)

            var rig := Polygon2D.new()
            rig.polygon = PackedVector2Array([
                Vector2(-10, -10),
                Vector2(10, -10),
                Vector2(10, 10),
                Vector2(-10, 10)
            ])
            rig.position = Vector2(0, -18)
            rig.visible = false
            rig.color = Color(1.0, 1.0, 1.0)
            rig.texture = _make_rig_texture()
            rig.texture_scale = Vector2(0.65, 0.65)
            tile.add_child(rig)

            tile_data["node"] = tile
            tile_data["rig_node"] = rig
            add_child(tile)
            tiles[x].append(tile_data)

func _make_ground_texture() -> Texture2D:
    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.12, 0.18, 0.28, 1.0))
    for y in range(32):
        for x in range(32):
            if (x + y) % 7 == 0:
                image.set_pixel(x, y, Color(0.22, 0.30, 0.40, 1.0))
    return ImageTexture.create_from_image(image)

func _make_rig_texture() -> Texture2D:
    var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.10, 0.20, 0.30, 1.0))
    for y in range(32):
        for x in range(32):
            if x in [4, 10, 16, 22, 28] and y % 5 == 0:
                image.set_pixel(x, y, Color(0.85, 0.96, 1.0, 1.0))
            if y in [4, 10, 16, 22, 28] and x % 5 == 0:
                image.set_pixel(x, y, Color(0.55, 0.90, 0.90, 1.0))
    for i in range(6):
        image.set_pixel(6 + i * 4, 14, Color(0.20, 0.96, 0.78, 1.0))
        image.set_pixel(14, 6 + i * 4, Color(0.20, 0.96, 0.78, 1.0))
    return ImageTexture.create_from_image(image)

func _build_hud() -> void:
    hud_root = CanvasLayer.new()
    add_child(hud_root)

    var root := MarginContainer.new()
    root.anchor_left = 0.0
    root.anchor_top = 0.0
    root.anchor_right = 1.0
    root.anchor_bottom = 1.0
    root.offset_left = 18
    root.offset_top = 18
    root.offset_right = -18
    root.offset_bottom = -18
    hud_root.add_child(root)

    var vbox := VBoxContainer.new()
    root.add_child(vbox)

    var topbar := HBoxContainer.new()
    vbox.add_child(topbar)

    cash_label = _new_label("Cash: $0.00")
    btc_label = _new_label("BTC: 0.0000")
    eth_label = _new_label("ETH: 0.0000")
    sol_label = _new_label("SOL: 0.0000")
    hash_label = _new_label("Hash: 0 H/s")
    power_label = _new_label("Power: 0 / 0 MW")
    market_label = _new_label("Market: BTC $0")
    stage_label = _new_label("Stage: Prospector")
    selected_label = _new_label("Selected: none")
    objective_label = _new_label("Objective: Reach $2,500")

    for child in [cash_label, btc_label, eth_label, sol_label, hash_label, power_label, market_label, stage_label, selected_label, objective_label]:
        topbar.add_child(child)

    progress_bar = ProgressBar.new()
    progress_bar.min_value = 0.0
    progress_bar.max_value = 100.0
    progress_bar.value = 0.0
    progress_bar.custom_minimum_size = Vector2(500, 22)
    vbox.add_child(progress_bar)

    event_label = _new_label("Market Event: Stable")
    vbox.add_child(event_label)

    var buttons := HBoxContainer.new()
    vbox.add_child(buttons)

    var buy_button := Button.new()
    buy_button.text = "Buy Rig ($220)"
    buy_button.pressed.connect(_on_buy_rig_pressed)
    buttons.add_child(buy_button)

    var upgrade_button := Button.new()
    upgrade_button.text = "Upgrade Rig"
    upgrade_button.pressed.connect(_on_upgrade_rig_pressed)
    buttons.add_child(upgrade_button)

    var power_button := Button.new()
    power_button.text = "Grid +"
    power_button.pressed.connect(_on_power_upgrade_pressed)
    buttons.add_child(power_button)

    var cooling_button := Button.new()
    cooling_button.text = "Cooling +"
    cooling_button.pressed.connect(_on_cooling_upgrade_pressed)
    buttons.add_child(cooling_button)

    var energy_button := Button.new()
    energy_button.text = "Green Energy"
    energy_button.pressed.connect(_on_green_energy_pressed)
    buttons.add_child(energy_button)

    var sell_button := Button.new()
    sell_button.text = "Sell All"
    sell_button.pressed.connect(_on_sell_pressed)
    buttons.add_child(sell_button)

    var lower_panel := PanelContainer.new()
    vbox.add_child(lower_panel)

    var lower_vbox := VBoxContainer.new()
    lower_panel.add_child(lower_vbox)

    status_label = _new_label("Status: waiting")
    log_label = _new_label("Miners: 0 | Cooling: 1 | Wallet value: $0")
    lower_vbox.add_child(status_label)
    lower_vbox.add_child(log_label)

    hud_root.visible = false

func _new_label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 16)
    label.modulate = Color(0.92, 0.97, 1.0)
    return label

func _on_start_game_pressed() -> void:
    _start_game()

func _on_reset_game_pressed() -> void:
    cash = 1800.0
    balances = {"BTC": 0.0, "ETH": 0.0, "SOL": 0.0}
    asset_prices = {"BTC": 45000.0, "ETH": 2600.0, "SOL": 140.0}
    total_hash_rate = 0.0
    power_capacity = 70.0
    power_usage = 0.0
    miners_owned = 0
    cooling_level = 1
    efficiency = 1.0
    stage_index = 0
    energy_boost = 0.0
    selected_data.clear()

    for x in range(GRID_SIZE):
        for y in range(GRID_SIZE):
            var cell: Dictionary = tiles[x][y]
            cell["occupied"] = false
            cell["rig_level"] = 0
            cell["hash_rate"] = 0.0
            cell["power_draw"] = 0.0
            if cell["rig_node"] != null:
                cell["rig_node"].visible = false
                cell["rig_node"].scale = Vector2.ONE

    _start_game()
    _update_progression()
    _update_ui()
    _set_status("Run reset. Time to build a new empire.")

func _on_quit_game_pressed() -> void:
    get_tree().quit()

func _process(delta: float) -> void:
    if not game_active:
        return

    event_timer += delta
    if event_timer >= 16.0:
        event_timer = 0.0
        _trigger_market_event()

    var overload := max(0.0, power_usage - power_capacity)
    var cooling_bonus := 1.0 + (cooling_level - 1) * 0.16
    var power_penalty := 1.0 - (overload / max(1.0, power_capacity)) * 0.65
    var green_bonus := 1.0 + energy_boost
    efficiency = clamp(power_penalty * cooling_bonus * green_bonus, 0.35, 1.8)

    var btc_price_move := randf_range(-100.0, 230.0) * delta * 0.7
    var eth_price_move := randf_range(-30.0, 90.0) * delta * 0.7
    var sol_price_move := randf_range(-3.0, 12.0) * delta * 0.8
    asset_prices["BTC"] = max(15000.0, asset_prices["BTC"] + btc_price_move)
    asset_prices["ETH"] = max(800.0, asset_prices["ETH"] + eth_price_move)
    asset_prices["SOL"] = max(35.0, asset_prices["SOL"] + sol_price_move)

    if total_hash_rate > 0.0:
        var btc_yield := total_hash_rate * delta * 0.0017 * efficiency
        var eth_yield := total_hash_rate * delta * 0.0009 * efficiency * (0.6 + stage_index * 0.14)
        var sol_yield := total_hash_rate * delta * 0.0013 * efficiency * (0.4 + stage_index * 0.18)

        balances["BTC"] += btc_yield
        balances["ETH"] += eth_yield
        balances["SOL"] += sol_yield

    _update_progression()
    _update_ui()

func _trigger_market_event() -> void:
    var roll := randi() % 5
    match roll:
        0:
            asset_prices["BTC"] *= 1.12
            event_label.text = "Market Event: BTC pump"
            _set_status("BTC mania! Prices surge.")
        1:
            asset_prices["ETH"] *= 1.15
            event_label.text = "Market Event: ETH momentum"
            _set_status("ETH rallies across the market.")
        2:
            asset_prices["SOL"] *= 1.18
            event_label.text = "Market Event: Solana surge"
            _set_status("SOL breaks out to new highs.")
        3:
            asset_prices["BTC"] *= 0.9
            asset_prices["ETH"] *= 0.92
            asset_prices["SOL"] *= 0.88
            event_label.text = "Market Event: Crypto dip"
            _set_status("Market cools down for a moment.")
        4:
            energy_boost = 0.18
            event_label.text = "Market Event: Green energy"
            _set_status("Renewables boost mining efficiency.")

    _update_ui()

func _update_progression() -> void:
    var max_stage := STAGE_TARGETS.size() - 1

    while stage_index < max_stage and cash >= STAGE_TARGETS[stage_index + 1]:
        stage_index += 1

    stage_index = clamp(stage_index, 0, max_stage)

    var current_target := STAGE_TARGETS[stage_index]
    var next_target := STAGE_TARGETS[min(stage_index + 1, max_stage)]
    var progress_value := 0.0

    if stage_index >= max_stage:
        progress_value = 100.0
    else:
        var span := max(1.0, next_target - current_target)
        var offset := max(0.0, cash - current_target)
        progress_value = clamp((offset / span) * 100.0, 0.0, 100.0)

    progress_bar.value = progress_value
    stage_label.text = "Stage: %s" % STAGES[stage_index]

    if stage_index < STAGES.size() - 1:
        objective_label.text = "Objective: Reach $%.0f" % STAGE_TARGETS[stage_index + 1]
    else:
        objective_label.text = "Objective: Final empire reached"

func _ensure_valid_selection() -> bool:
    if selected_data.is_empty():
        selected_data = _find_first_available_tile()
        return not selected_data.is_empty()

    if selected_data.has("occupied") and selected_data["occupied"]:
        var free_tile := _find_first_available_tile()
        if free_tile.is_empty():
            return false
        selected_data = free_tile

    return true

func _on_buy_rig_pressed() -> void:
    if not game_active:
        return

    if not _ensure_valid_selection():
        _set_status("No free tiles available.")
        return

    if not selected_data.has("occupied"):
        _set_status("This tile is invalid.")
        return

    if selected_data["occupied"]:
        _set_status("This tile is already occupied.")
        return

    var cost := 220.0 + (miners_owned * 30.0)
    if cash < cost:
        _set_status("Not enough cash for a miner.")
        return

    cash -= cost
    selected_data["occupied"] = true
    selected_data["rig_level"] = 1
    selected_data["hash_rate"] = 18.0
    selected_data["power_draw"] = 9.0

    if selected_data.has("rig_node") and selected_data["rig_node"] != null:
        selected_data["rig_node"].visible = true
        selected_data["rig_node"].color = Color(0.28, 0.96, 0.78)

    total_hash_rate += selected_data["hash_rate"]
    power_usage += selected_data["power_draw"]
    miners_owned += 1
    _set_status("ASIC rig purchased on (%d, %d)." % [selected_data["x"], selected_data["y"]])
    _update_ui()

func _on_upgrade_rig_pressed() -> void:
    if not game_active:
        return

    if not _ensure_valid_selection():
        _set_status("No rig selected to upgrade.")
        return

    if not selected_data.has("occupied") or not selected_data.has("rig_level"):
        _set_status("This tile is invalid.")
        return

    if not selected_data["occupied"]:
        _set_status("There is no rig to upgrade.")
        return

    var current_level: int = int(selected_data["rig_level"])
    var upgrade_cost: float = 120.0 + (current_level * 75.0)

    if cash < upgrade_cost:
        _set_status("Not enough cash to upgrade.")
        return

    var old_hash: float = selected_data.get("hash_rate", 0.0)
    var old_power: float = selected_data.get("power_draw", 0.0)

    cash -= upgrade_cost
    selected_data["rig_level"] = current_level + 1
    selected_data["hash_rate"] = 18.0 * selected_data["rig_level"]
    selected_data["power_draw"] = 9.0 * selected_data["rig_level"]

    total_hash_rate += selected_data["hash_rate"] - old_hash
    power_usage += selected_data["power_draw"] - old_power

    if selected_data.has("rig_node") and selected_data["rig_node"] != null:
        selected_data["rig_node"].scale = Vector2(
            1.0 + selected_data["rig_level"] * 0.12,
            1.0 + selected_data["rig_level"] * 0.12
        )

    _set_status("Rig upgraded to level %d." % selected_data["rig_level"])
    _update_ui()

func _on_power_upgrade_pressed() -> void:
    if not game_active:
        return

    var cost := 260.0 + (power_capacity * 1.8)
    if cash < cost:
        _set_status("Not enough cash to expand the grid.")
        return

    cash -= cost
    power_capacity += 25.0
    _set_status("Power grid expanded.")
    _update_ui()

func _on_cooling_upgrade_pressed() -> void:
    if not game_active:
        return

    var cost := 320.0 + (cooling_level * 100.0)
    if cash < cost:
        _set_status("Not enough cash for cooling.")
        return

    cash -= cost
    cooling_level += 1
    _set_status("Cooling upgraded to level %d." % cooling_level)
    _update_ui()

func _on_green_energy_pressed() -> void:
    if not game_active:
        return

    var cost := 500.0
    if cash < cost:
        _set_status("Not enough cash for green energy.")
        return

    cash -= cost
    energy_boost += 0.1
    _set_status("Green energy supply online.")
    _update_ui()

func _on_sell_pressed() -> void:
    if not game_active:
        return

    var total_value := 0.0
    for asset_name in ASSET_ORDER:
        total_value += balances[asset_name] * asset_prices[asset_name]

    if total_value <= 0.0:
        _set_status("No crypto available to sell.")
        return

    cash += total_value
    for asset_name in ASSET_ORDER:
        balances[asset_name] = 0.0

    _set_status("Sold all crypto for $%.2f." % total_value)
    _update_ui()

func _update_ui() -> void:
    if cash_label == null:
        return

    var wallet_value := 0.0
    for asset_name in ASSET_ORDER:
        wallet_value += balances[asset_name] * asset_prices[asset_name]

    cash_label.text = "Cash: $%.2f" % cash
    btc_label.text = "BTC: %.4f" % balances["BTC"]
    eth_label.text = "ETH: %.4f" % balances["ETH"]
    sol_label.text = "SOL: %.4f" % balances["SOL"]
    hash_label.text = "Hash: %.1f H/s" % total_hash_rate
    power_label.text = "Power: %.1f / %.1f MW" % [power_usage, power_capacity]
    market_label.text = "Market: BTC $%.0f | ETH $%.0f | SOL $%.0f" % [asset_prices["BTC"], asset_prices["ETH"], asset_prices["SOL"]]

    if selected_data.is_empty():
        selected_label.text = "Selected: none"
    else:
        selected_label.text = "Selected: (%d, %d)" % [selected_data["x"], selected_data["y"]]

    status_label.text = "Status: mining %.2fx efficient" % efficiency
    log_label.text = "Miners: %d | Cooling: %d | Wallet value: $%.2f" % [miners_owned, cooling_level, wallet_value]

func _set_status(message: String) -> void:
    if status_label != null:
        status_label.text = "Status: %s" % message

func _iso_to_screen(x: int, y: int) -> Vector2:
    return Vector2((x - y) * (TILE_W * 0.5), (x + y) * (TILE_H * 0.5))
