# Loads the YAML files under db/seeds/ into the database (formats documented in db/seeds/templates/).
#
# Idempotent: features, unlocks, spell slots and spells are updated in place; classes, level
# progressions and characters that already exist are left alone (ClassLevelProgression freezes
# itself after_find, so existing rows are immutable). Keys omitted from a YAML entry take the
# column default.
module SeedData
  ROOT = Rails.root.join("db/seeds")
  CLASS_KEYS = %w[ name hit_die description spellcasting_modifier progression features ].freeze
  CHARACTER_KEYS = %w[ name level class fighting_style martial_archetype combatant spells maneuvers ].freeze

  module_function

  def load_all(root = ROOT)
    load_spells(root.join("spells.yml"))
    Dir[root.join("classes/*.yml")].sort.each { load_class(it) }
    Dir[root.join("characters/*.yml")].sort.each { load_character(it) }
  end

  def load_spells(path)
    YAML.safe_load_file(path).each { |attrs| save(Spell.find_or_initialize_by(slug: attrs.fetch("slug")), attrs) }
  end

  def load_class(path)
    data = read(path, CLASS_KEYS)
    player_class = PlayerClass.find_or_create_by!(name: data.fetch("name")) do |pc|
      pc.assign_attributes(data.slice("hit_die", "description", "spellcasting_modifier"))
    end

    Array(data["progression"]).each do |row|
      progression = ClassLevelProgression.find_or_initialize_by(player_class:, level: row.fetch("level"))
      progression.update!(row) if progression.new_record?
    end
    Array(data["features"]).each { load_feature(player_class, it) }
  end

  def load_character(path)
    data = read(path, CHARACTER_KEYS)
    player_class = PlayerClass.find_by!(name: data.fetch("class"))
    feature = ->(slug) { player_class.class_features.find_by!(slug:) }

    character = PlayerCharacter.find_or_create_by!(name: data.fetch("name")) do |pc|
      pc.level = data.fetch("level")
      pc.player_class = player_class
      pc.fighting_style = feature.(data["fighting_style"]) if data["fighting_style"]
      pc.martial_archetype = feature.(data["martial_archetype"]) if data["martial_archetype"]
      pc.combatant_attributes = data["combatant"] if data["combatant"]
    end
    Array(data["spells"]).each { |slug| character.player_character_spells.find_or_create_by!(spell: Spell.find_by!(slug:)) }
    Array(data["maneuvers"]).each { |slug| character.player_character_maneuvers.find_or_create_by!(maneuver: feature.(slug)) }
  end

  # A feature's `subclass_features` are its subclass_progression children: the feature is their marker.
  def load_feature(player_class, attrs, marker: nil)
    attrs = attrs.dup
    unlocks = attrs.delete("unlocks") || []
    spell_slots = attrs.delete("spell_slots") || []
    subclass_features = attrs.delete("subclass_features") || []
    attrs["feature_type"] ||= "subclass_progression" if marker

    feature = ClassFeature.find_or_initialize_by(player_class:, slug: attrs.fetch("slug"))
    save(feature, attrs.merge("subclass_marker" => marker))

    unlocks.each do |unlock_attrs|
      unlock = ClassFeatureUnlock.find_or_initialize_by(class_feature: feature, level: unlock_attrs.fetch("level"))
      save(unlock, { "description" => feature.description }.merge(unlock_attrs))
    end

    spell_slots.each do |row|
      row = row.dup
      row.delete("slots").each.with_index(1) { |count, spell_level| row["spell_slots_#{spell_level}"] = count }
      save(SpellSlotProgression.find_or_initialize_by(class_feature: feature, level: row.fetch("level")), row)
    end

    subclass_features.each { load_feature(player_class, it, marker: feature) }
  end

  def read(path, allowed_keys)
    data = YAML.safe_load_file(path)
    unknown = data.keys - allowed_keys
    raise ArgumentError, "#{path}: unknown keys #{unknown.join(', ')}" if unknown.any?

    data
  end

  def save(record, attrs)
    record.assign_attributes(attrs)
    record.save! if record.changed?
  end
end
