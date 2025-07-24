json.extract! player_character, :id, :name, :level, :player_class_id, :created_at, :updated_at
json.url player_character_url(player_character, format: :json)
