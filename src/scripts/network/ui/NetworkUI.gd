extends Control

func _on_server_pressed() -> void:
	NetConnection.start_server()
	$VBoxContainer/Client.visible = false
	
#функцией создать еще одного игрока , который ничего не будет делать

func _on_client_pressed() -> void:
	NetConnection.start_client()
	$VBoxContainer/Server.visible = false
	$VBoxContainer/Client.visible = false
