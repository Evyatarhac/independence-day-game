extends Node

signal economy_changed(coins: int, stones_progress: int, skill_rank: int, weapon_tier: int)
signal collection_updated()

# Shared state across scenes
var selected_character := "palmach"
## Display name chosen on NameEntry; used in intro + HUD.
var player_hero_name := "לוחם"
var final_score := 0
var high_score := 0
var current_level := 1
## Set by Game.gd: true only when the player cleared every wave (not score-based).
var stage_won := false

# ─── Run economy (reset when a new stage starts) ────────────────────────────
## מטבעות ארנק — נשמרים בין משחקים; נאספים בשטח ומשמשים בחנות המטא ובין גלים.
var wallet_coins := 0
## Stones toward the next skill jump (0–9 on HUD; at 10 you rank up).
var run_stones_progress := 0
var run_skill_rank := 0
## 0 ידיים → 1 חרב → 2 סכין → 3 רובה ישן
var run_weapon_tier := 0
var _history_card_index := 0
var run_lives_lost := 0
var run_continue_used := false

## קלפי היסטוריה שנאספו (מזהים יציבים מהטבלה HISTORY_CARDS).
var collected_history_card_ids: Array[String] = []
## עד 10 פריטים במתכונת { "id": String, "qty": int } או null לריק.
var inventory_slots: Array = []

const INVENTORY_MAX_SLOTS := 10

const WIKI_ISRAEL_HISTORY := "https://he.wikipedia.org/wiki/%D7%94%D7%99%D7%A1%D7%98%D7%95%D7%A8%D7%99%D7%94_%D7%A9%D7%9C_%D7%9E%D7%93%D7%99%D7%A0%D7%AA_%D7%99%D7%A9%D7%A8%D7%90%D7%9C"

## Curated “cards” tied to the Wikipedia article theme (short in-game blurbs).
## Each entry includes `ornament` + colors so the HUD can render a distinct collectible card face.
const HISTORY_CARDS := [
	{
		"id": "independence_1948",
		"title": "הכרזת העצמאות (1948)",
		"body": "בעקבות החלטת האו\"ם על חלוקה ובתום המנדט הבריטי, הוכרזה מדינת ישראל. האירוע סימן תחילת דרכה של מדינה ריבונית במזרח התיכון.",
		"ornament": "flag_star",
		"accent_a": Color(0.08, 0.16, 0.48),
		"accent_b": Color(0.22, 0.42, 0.82),
		"face_a": Color(0.97, 0.98, 1.0),
		"face_b": Color(0.78, 0.86, 0.98),
		"border": Color(0.82, 0.66, 0.18),
		"title_color": Color(0.04, 0.08, 0.28),
		"body_color": Color(0.1, 0.12, 0.2),
	},
	{
		"id": "war_of_independence",
		"title": "מלחמת העצמאות",
		"body": "צבאות ערב נכנסו לשטחי המדינה הצעירה. כוחות ההגנה והיחידות המגובשות עמדו בפני אתגר קיומי — הגנת יישובים, שבירת מצור והקמת צה\"ל.",
		"ornament": "olive_shield",
		"accent_a": Color(0.22, 0.28, 0.12),
		"accent_b": Color(0.42, 0.36, 0.18),
		"face_a": Color(0.94, 0.92, 0.84),
		"face_b": Color(0.72, 0.68, 0.55),
		"border": Color(0.55, 0.12, 0.1),
		"title_color": Color(0.12, 0.1, 0.06),
		"body_color": Color(0.18, 0.16, 0.12),
	},
	{
		"id": "immigration_growth",
		"title": "עליית העולים והצמיחה",
		"body": "גלים גדולים של עלייה עיצבו מחדש את החברה: מחנות עולים, פיתוח שפה ותרבות משותפת, ובניית תשתיות במרץ.",
		"ornament": "ship_waves",
		"accent_a": Color(0.12, 0.42, 0.52),
		"accent_b": Color(0.28, 0.62, 0.68),
		"face_a": Color(0.98, 0.96, 0.88),
		"face_b": Color(0.85, 0.78, 0.62),
		"border": Color(0.35, 0.52, 0.58),
		"title_color": Color(0.06, 0.2, 0.26),
		"body_color": Color(0.14, 0.18, 0.2),
	},
	{
		"id": "six_day_war",
		"title": "מלחמת ששת הימים (1967)",
		"body": "עימות צבאי קצר ודרמטי ששינה את מפת האזור. ניצחון ישראלי הוביל לשינוי קווי שטח ולדיון מדיני שנמשך עד היום.",
		"ornament": "desert_sun",
		"accent_a": Color(0.62, 0.42, 0.12),
		"accent_b": Color(0.92, 0.72, 0.22),
		"face_a": Color(1.0, 0.95, 0.82),
		"face_b": Color(0.88, 0.72, 0.48),
		"border": Color(0.72, 0.38, 0.08),
		"title_color": Color(0.28, 0.14, 0.04),
		"body_color": Color(0.32, 0.2, 0.1),
	},
	{
		"id": "yom_kippur_war",
		"title": "מלחמת יום הכיפורים (1973)",
		"body": "פתעון בחזיתות סיני ורמת הגולן, התאוששות קשה, ולקחים חברתיים וצבאיים שעיצבו דור שלם.",
		"ornament": "golan_mist",
		"accent_a": Color(0.18, 0.22, 0.32),
		"accent_b": Color(0.38, 0.44, 0.55),
		"face_a": Color(0.88, 0.9, 0.94),
		"face_b": Color(0.58, 0.62, 0.72),
		"border": Color(0.42, 0.48, 0.58),
		"title_color": Color(0.08, 0.1, 0.16),
		"body_color": Color(0.12, 0.14, 0.2),
	},
	{
		"id": "camp_david",
		"title": "הסכמי קמפ דייוויד",
		"body": "צעד דיפלומטי נועז: נסיגה מסיני תמורת שלום עם מצרים — אבן דרך ביחסי ישראל–מצרים ובמזרח התיכון.",
		"ornament": "peace_arc",
		"accent_a": Color(0.1, 0.28, 0.55),
		"accent_b": Color(0.25, 0.55, 0.75),
		"face_a": Color(0.94, 0.98, 1.0),
		"face_b": Color(0.72, 0.86, 0.95),
		"border": Color(0.2, 0.55, 0.42),
		"title_color": Color(0.05, 0.18, 0.32),
		"body_color": Color(0.1, 0.22, 0.3),
	},
	{
		"id": "oslo_peace_era",
		"title": "אינתיפאדה, הסכמי אוסלו ומאמצי שלום",
		"body": "שנים של עימותים לצד ניסיונות להסדר מדיני. המאבק בטרור לצד משא ומתן — מתח שחוזר בצורות שונות בהיסטוריה.",
		"ornament": "olive_branch",
		"accent_a": Color(0.32, 0.22, 0.14),
		"accent_b": Color(0.52, 0.4, 0.22),
		"face_a": Color(0.96, 0.94, 0.88),
		"face_b": Color(0.78, 0.72, 0.62),
		"border": Color(0.28, 0.48, 0.28),
		"title_color": Color(0.16, 0.12, 0.08),
		"body_color": Color(0.22, 0.18, 0.14),
	},
	{
		"id": "tech_economy",
		"title": "הייטק, חברה ומשק",
		"body": "מאז שנות ה־90 התפתחה בישראל תעשיית טכנולוגיה עולמית לצד רפורמות כלכליות — מנוע צמיחה וסמל לחדשנות.",
		"ornament": "circuit_glow",
		"accent_a": Color(0.12, 0.08, 0.38),
		"accent_b": Color(0.35, 0.12, 0.55),
		"face_a": Color(0.12, 0.14, 0.22),
		"face_b": Color(0.06, 0.1, 0.18),
		"border": Color(0.2, 0.85, 0.92),
		"title_color": Color(0.75, 0.92, 1.0),
		"body_color": Color(0.82, 0.88, 0.94),
	},
]

const _SAVE_PATH := "user://independence_save.cfg"

const SHOP_HEART_PRICE := 22
const SHOP_PRICE_SWORD := 30
const SHOP_PRICE_KNIFE := 36
const SHOP_PRICE_RIFLE := 42
const SHOP_PRICE_STONES_BUNDLE := 24
const SHOP_STONES_BUNDLE_AMOUNT := 5

const WEAPON_TIER_NAMES_HE: Array[String] = [
	"ידיים", "חרב", "סכין", "רובה ישן",
]

## חנות (מגן דוד ובין גלים) — רק לב, נשק, אבני ירושלים.
const META_SHOP_ITEMS := [
	{"id": "meta_heart", "name_he": "לב נוסף", "price": SHOP_HEART_PRICE, "desc": "חיים נוספים במאבק."},
	{"id": "meta_weapon_sword", "name_he": "חרב", "price": SHOP_PRICE_SWORD, "desc": "שדרוג מידיים לחרב."},
	{"id": "meta_weapon_knife", "name_he": "סכין", "price": SHOP_PRICE_KNIFE, "desc": "שדרוג מחרב לסכין."},
	{"id": "meta_weapon_rifle", "name_he": "רובה ישן", "price": SHOP_PRICE_RIFLE, "desc": "שדרוג מסכין לרובה ישן."},
	{"id": "meta_stones", "name_he": "אבני ירושלים (חבילה)", "price": SHOP_PRICE_STONES_BUNDLE, "desc": "אבנים לקראת שדרוג מיומנות.", "stone_count": SHOP_STONES_BUNDLE_AMOUNT},
]

const CHARACTERS := {
	"palmach": {
		"name_he": "פלמ\"ח",
		"name_en": "Palmach",
		"description": "לוחם עילית מאומן\nאיזון של כוח ותחבולה",
		"color_body":   Color(0.27, 0.34, 0.17),   # זית כהה – מדי שטח
		"color_accent": Color(0.78, 0.66, 0.20),
		"color_skin":   Color(0.80, 0.63, 0.45),
		"max_health": 100,
		"speed": 200.0,
		"punch_damage": 15,
		"kick_damage": 20,
		"special_damage": 40,
		"attack_rate": 1.0,
		"char_type": "palmach",
		"ideology_power":   4,
		"ideology_speed":   3,
		"ideology_tactics": 4,
	},
	"lehi": {
		"name_he": "לח\"י",
		"name_en": "Lehi",
		"description": "מחתרת זריזה ומתוחכמת\nמומחי תכסיסים ומהירות",
		"color_body":   Color(0.22, 0.20, 0.16),   # בגדי אזרח כהים
		"color_accent": Color(0.88, 0.82, 0.18),
		"color_skin":   Color(0.80, 0.63, 0.45),
		"max_health": 75,
		"speed": 260.0,
		"punch_damage": 20,
		"kick_damage": 15,
		"special_damage": 35,
		"attack_rate": 1.3,
		"char_type": "lehi",
		"ideology_power":   2,
		"ideology_speed":   4,
		"ideology_tactics": 5,
	},
	"haganah": {
		"name_he": "הגנה",
		"name_en": "Haganah",
		"description": "הכוח הגדול | גרעין צה\"ל\nעמיד וחזק, איטי מעט",
		"color_body":   Color(0.52, 0.46, 0.26),   # קאקי בריטי עודף
		"color_accent": Color(0.68, 0.72, 0.82),
		"color_skin":   Color(0.80, 0.63, 0.45),
		"max_health": 130,
		"speed": 160.0,
		"punch_damage": 22,
		"kick_damage": 28,
		"special_damage": 55,
		"attack_rate": 0.8,
		"char_type": "haganah",
		"ideology_power":   5,
		"ideology_speed":   2,
		"ideology_tactics": 3,
	},
	"irgun": {
		"name_he": "אצ\"ל",
		"name_en": "Irgun",
		"description": "שודדים מהירים וחסרי פחד\nפשיטות אגרסיביות ומהירות",
		"color_body":   Color(0.32, 0.27, 0.14),   # זית כהה – בגדי שטח
		"color_accent": Color(0.88, 0.55, 0.12),
		"color_skin":   Color(0.80, 0.63, 0.45),
		"max_health": 90,
		"speed": 195.0,
		"punch_damage": 18,
		"kick_damage": 18,
		"special_damage": 70,
		"attack_rate": 1.0,
		"char_type": "irgun",
		"ideology_power":   3,
		"ideology_speed":   5,
		"ideology_tactics": 2,
	}
}

func _ready() -> void:
	_load_persistent()
	_setup_input_actions()


func _load_persistent() -> void:
	var cf := ConfigFile.new()
	if cf.load(_SAVE_PATH) != OK:
		_ensure_inventory_slots()
		return
	high_score = int(cf.get_value("game", "high_score", high_score))
	wallet_coins = int(cf.get_value("meta", "wallet_coins", wallet_coins))
	var cards_json: Variant = cf.get_value("meta", "history_cards_json", "")
	if cards_json is String and not (cards_json as String).is_empty():
		var pc: Variant = JSON.parse_string(cards_json as String)
		if pc is Array:
			collected_history_card_ids.clear()
			for c in pc:
				if c is String and not (c as String).is_empty():
					collected_history_card_ids.append(c as String)
	else:
		var cards_raw: Variant = cf.get_value("meta", "history_cards", [])
		if cards_raw is Array:
			collected_history_card_ids.clear()
			for c in cards_raw:
				if c is String and not (c as String).is_empty():
					collected_history_card_ids.append(c as String)
	var inv_json: Variant = cf.get_value("meta", "inventory_json", "")
	if inv_json is String and not (inv_json as String).is_empty():
		var pi: Variant = JSON.parse_string(inv_json as String)
		if pi is Array:
			inventory_slots = (pi as Array).duplicate()
	else:
		var inv_raw: Variant = cf.get_value("meta", "inventory", [])
		if inv_raw is Array:
			inventory_slots = (inv_raw as Array).duplicate()
	_ensure_inventory_slots()


func save_persistent() -> void:
	var cf := ConfigFile.new()
	cf.load(_SAVE_PATH)
	cf.set_value("game", "high_score", high_score)
	cf.set_value("meta", "wallet_coins", wallet_coins)
	cf.set_value("meta", "history_cards_json", JSON.stringify(collected_history_card_ids))
	cf.set_value("meta", "inventory_json", JSON.stringify(inventory_slots))
	cf.save(_SAVE_PATH)


func _ensure_inventory_slots() -> void:
	while inventory_slots.size() < INVENTORY_MAX_SLOTS:
		inventory_slots.append(null)


func ensure_inventory_slots() -> void:
	_ensure_inventory_slots()


func has_history_card(card_id: String) -> bool:
	return collected_history_card_ids.has(card_id)


func unlock_history_card(card_id: String) -> void:
	if card_id.is_empty():
		return
	if has_history_card(card_id):
		return
	collected_history_card_ids.append(card_id)
	save_persistent()
	collection_updated.emit()


func get_history_card_by_id(card_id: String) -> Dictionary:
	for entry in HISTORY_CARDS:
		var d: Dictionary = entry as Dictionary
		if str(d.get("id", "")) == card_id:
			var out: Dictionary = d.duplicate()
			out["wiki_url"] = WIKI_ISRAEL_HISTORY
			return out
	return {}


func get_meta_shop_item(item_id: String) -> Dictionary:
	for it in META_SHOP_ITEMS:
		var d: Dictionary = it as Dictionary
		if str(d.get("id", "")) == item_id:
			return d
	return {}


func try_buy_meta_shop_item(item_id: String, player: CharacterBody2D = null) -> bool:
	match item_id:
		"meta_heart":
			if player == null or not is_instance_valid(player):
				return false
			if not player.has_method("try_shop_buy_heart"):
				return false
			return player.try_shop_buy_heart()
		"meta_stones":
			var def_s: Dictionary = get_meta_shop_item("meta_stones")
			var price_s: int = int(def_s.get("price", SHOP_PRICE_STONES_BUNDLE))
			var n_st: int = int(def_s.get("stone_count", SHOP_STONES_BUNDLE_AMOUNT))
			if wallet_coins < price_s:
				return false
			wallet_coins -= price_s
			add_run_stones_batch(n_st)
			save_persistent()
			economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)
			collection_updated.emit()
			return true
		"meta_weapon_sword":
			if run_weapon_tier != 0:
				return false
			if wallet_coins < SHOP_PRICE_SWORD:
				return false
			wallet_coins -= SHOP_PRICE_SWORD
			run_weapon_tier = 1
			save_persistent()
			economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)
			collection_updated.emit()
			return true
		"meta_weapon_knife":
			if run_weapon_tier != 1:
				return false
			if wallet_coins < SHOP_PRICE_KNIFE:
				return false
			wallet_coins -= SHOP_PRICE_KNIFE
			run_weapon_tier = 2
			save_persistent()
			economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)
			collection_updated.emit()
			return true
		"meta_weapon_rifle":
			if run_weapon_tier != 2:
				return false
			if wallet_coins < SHOP_PRICE_RIFLE:
				return false
			wallet_coins -= SHOP_PRICE_RIFLE
			run_weapon_tier = 3
			save_persistent()
			economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)
			collection_updated.emit()
			return true
		_:
			return false


func get_weapon_upgrade_price_for_current() -> int:
	match run_weapon_tier:
		0:
			return SHOP_PRICE_SWORD
		1:
			return SHOP_PRICE_KNIFE
		2:
			return SHOP_PRICE_RIFLE
		_:
			return 99999


func get_interwave_shop_summary_line() -> String:
	var wnext: String = ""
	if run_weapon_tier < 3:
		wnext = "%s (%d)" % [WEAPON_TIER_NAMES_HE[run_weapon_tier + 1], get_weapon_upgrade_price_for_current()]
	else:
		wnext = "מקסימום"
	return "לב: %d · נשק הבא: %s · אבנים (×%d): %d" % [
		SHOP_HEART_PRICE,
		wnext,
		SHOP_STONES_BUNDLE_AMOUNT,
		SHOP_PRICE_STONES_BUNDLE,
	]


func get_next_weapon_button_text() -> String:
	if run_weapon_tier >= 3:
		return "נשק: רובה ישן (מלא)"
	var nm: String = WEAPON_TIER_NAMES_HE[run_weapon_tier + 1]
	var pr: int = get_weapon_upgrade_price_for_current()
	return "קנה %s (+%d מטבעות)" % [nm, pr]


func add_inventory_item(item_id: String, qty: int = 1) -> bool:
	if qty <= 0:
		return false
	_ensure_inventory_slots()
	for i in inventory_slots.size():
		var slot: Variant = inventory_slots[i]
		if slot is Dictionary:
			var sd: Dictionary = slot
			if str(sd.get("id", "")) == item_id:
				sd["qty"] = int(sd.get("qty", 1)) + qty
				save_persistent()
				collection_updated.emit()
				return true
	for i in inventory_slots.size():
		if inventory_slots[i] == null:
			inventory_slots[i] = {"id": item_id, "qty": qty}
			save_persistent()
			collection_updated.emit()
			return true
	return false


func get_inventory_item_name_he(item_id: String) -> String:
	var def := get_meta_shop_item(item_id)
	if def.is_empty():
		return item_id
	return str(def.get("name_he", item_id))

func _setup_input_actions() -> void:
	var actions := {
		"move_left":  [KEY_LEFT,  KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up":    [KEY_UP,    KEY_W],
		"move_down":  [KEY_DOWN,  KEY_S],
		"punch":      [KEY_Z,     KEY_J],
		"kick":       [KEY_X,     KEY_K],
		"special":    [KEY_C,     KEY_L],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in actions[action]:
			if _input_action_has_physical_key(action, keycode):
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode as Key
			InputMap.action_add_event(action, ev)


func _input_action_has_physical_key(action: String, keycode: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == keycode:
			return true
	return false

func get_char_data() -> Dictionary:
	return CHARACTERS[selected_character]


func reset_run_economy() -> void:
	run_stones_progress = 0
	run_skill_rank = 0
	run_weapon_tier = 0
	_history_card_index = 0
	run_lives_lost = 0
	run_continue_used = false
	economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)


func add_run_coins(amount: int) -> void:
	if amount <= 0:
		return
	wallet_coins += amount
	save_persistent()
	economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)


func add_run_stone_pickup() -> void:
	run_stones_progress += 1
	while run_stones_progress >= 10:
		run_stones_progress -= 10
		run_skill_rank += 1
	economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)


func add_run_stones_batch(amount: int) -> void:
	if amount <= 0:
		return
	for _i in amount:
		run_stones_progress += 1
		while run_stones_progress >= 10:
			run_stones_progress -= 10
			run_skill_rank += 1
	economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)


func try_buy_extra_heart() -> bool:
	if wallet_coins < SHOP_HEART_PRICE:
		return false
	wallet_coins -= SHOP_HEART_PRICE
	save_persistent()
	economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)
	return true


func try_buy_weapon_upgrade() -> bool:
	if run_weapon_tier >= 3:
		return false
	var p: int = get_weapon_upgrade_price_for_current()
	if wallet_coins < p:
		return false
	wallet_coins -= p
	run_weapon_tier += 1
	save_persistent()
	economy_changed.emit(wallet_coins, run_stones_progress, run_skill_rank, run_weapon_tier)
	return true


func get_weapon_name_he() -> String:
	var idx: int = clampi(run_weapon_tier, 0, WEAPON_TIER_NAMES_HE.size() - 1)
	return WEAPON_TIER_NAMES_HE[idx]


func get_next_history_card() -> Dictionary:
	var idx: int = _history_card_index % HISTORY_CARDS.size()
	_history_card_index += 1
	var card: Dictionary = (HISTORY_CARDS[idx] as Dictionary).duplicate()
	card["wiki_url"] = WIKI_ISRAEL_HISTORY
	return card
