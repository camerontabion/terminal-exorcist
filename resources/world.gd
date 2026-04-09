class_name WorldData
extends Resource

## All servers the player can SSH into.
@export var servers: Array[ServerData] = []

## All mission tickets shown in the `tickets` command.
@export var tickets: Array[TicketData] = []
