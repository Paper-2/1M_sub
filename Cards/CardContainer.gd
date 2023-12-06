extends Node2D
class_name CardContainer
## Lays out cards in the player's hand and spawns new cards.
##
## When a card is clicked, it is set as the CardManager's queued_card by this class.
## The queued_card can then be accessed from anywhere.
## When a card is queued, you can't hover any other cards in your deck. Left click any card to
## remove the current card from the queue.
## TODO Right click cancels the queued card instead?
## TODO We need a global way to deal cards so we can deal cards from
## card effects (eg: draw 2 cards). There is also no concept of draw pile/discard pile.


@export var card_scene: PackedScene
@export var total_hand_width: float = 100
@export var card_hovered_offset: float = 100
@export var card_queued_offset: float = 100
@export var default_hand: Array[CardBase]

var cards: Array[CardWorld]


func _ready() -> void:
	PhaseManager.on_phase_changed.connect(_on_phase_changed)
	CardManager.successful_card_play.connect(_on_card_successful_play)


func _process(_delta: float) -> void:
	_update_card_positions()


func deal_cards() -> void:
	discard_all_cards()
	for card_index: int in default_hand.size():
		# create card and add to list
		var card_instance: CardWorld = card_scene.instantiate()
		add_child(card_instance)
		cards.append(card_instance)
		card_instance.init_card(default_hand[card_index])
		
		# bind mouse events
		var card_click_handler: ClickHandler = card_instance.get_click_handler()
		card_click_handler.on_click.connect(_on_card_clicked.bind(card_instance))
		card_click_handler.on_mouse_hovering.connect(_on_card_hovering.bind(card_instance))
		card_click_handler.on_unhover.connect(_on_card_unhovered.bind(card_instance))


func discard_all_cards() -> void:
	for card: CardWorld in cards:
		card.queue_free()
	cards.clear()


func remove_card(card: CardWorld) -> void:
	var card_index: int = cards.find(card)
	cards[card_index].queue_free()
	cards.remove_at(card_index)


func _on_phase_changed(new_phase: Enums.Phase, _old_phase: Enums.Phase) -> void:
	if new_phase == Enums.Phase.PLAYER_ATTACKING:
		deal_cards()
	if new_phase == Enums.Phase.ENEMY_ATTACKING:
		discard_all_cards()


func _on_card_clicked(card: CardWorld) -> void:
	if CardManager.is_card_queued():
		# If we click ANY card while we have one queued, unqueue the queued card
		var queued_card = CardManager.queued_card
		CardManager.set_queued_card(null)
		
		# If the card we clicked was the global queued card, we are still hovering it
		if card == queued_card:
			_on_card_hovering(card)
		else:
			# If we clicked another card, then we already unhovered the queued card
			_on_card_unhovered(queued_card)
			# Now call this function again for the card we clicked, which should queue it
			_on_card_clicked(card)
	else:
		# If we click a card with no card queued, queue it
		CardManager.set_queued_card(card)
		_focus_card(card, card_queued_offset)
		
		# Unfocus all other cards
		for other_card in cards:
			if other_card == card:
				continue
			_unfocus_card(other_card)


func _on_card_hovering(card: CardWorld) -> void:
	if !CardManager.is_card_queued():
		_focus_card(card, card_hovered_offset)


func _on_card_unhovered(card: CardWorld) -> void:
	if !CardManager.is_card_queued():
		_unfocus_card(card)


func _focus_card(card: CardWorld, offset: float) -> void:
	card.get_lerp_component().desired_position.y = -offset
	card.z_index = 1


func _unfocus_card(card: CardWorld) -> void:
	card.get_lerp_component().desired_position.y = 0
	card.z_index = 0


func _on_card_successful_play(card: CardWorld) -> void:
	remove_card(card)


func _update_card_positions() -> void:
	if cards.size() <= 0:
		return
	
	var viewport_width: float = get_viewport_rect().size.x
	var viewport_height: float = get_viewport_rect().size.y
	
	# set container to bottom center of screen (doing every frame encase the viewport size changes)
	position.x = viewport_width / 2
	position.x -= total_hand_width / 2
	position.y = viewport_height 
	
	# set spacing of each card
	var per_card_width: float = 0
	if cards.size() > 1:
		per_card_width = total_hand_width / (cards.size() - 1)
	for card_index: int in cards.size():
		var card: CardWorld = cards[card_index]
		var card_x: float = per_card_width * card_index

		card.get_lerp_component().desired_position.x = card_x