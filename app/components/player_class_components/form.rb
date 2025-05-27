# frozen_string_literal: true

class Components::PlayerClassComponents::Form < Components::Base
  def initialize(player_class:)
    @player_class = player_class
  end

  # This method is used to render the form for creating or editing a player class.
  # It uses the `form_with` helper to create a form that is bound to the `@player_class` model.
  # The form includes fields for the player's name, hit die, description, and spellcasting modifier.
  # It also handles displaying validation errors if any exist.
  def view_template
    form_with(model: @player_class, class: "contents") do |form|
      if @player_class.errors.any?
        div(
          id: "error_explanation",
          class: "bg-red-50 text-red-500 px-3 py-2 font-medium rounded-md mt-3"
        ) do
          h2 { "#{pluralize(@player_class.errors.count, "error")} prohibited this player_class from being saved:" }
          ul(class: "list-disc ml-6") do
            @player_class.errors.each { |error| li { error.full_message } }
          end
        end
      end

      div(class: "my-5") do
        plain form.label :name
        plain form.text_field :name,
                              class: [
                                "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full text-stone-950",
                                {
                                  "border-gray-400 focus:outline-blue-600":
                                    @player_class.errors[:name].none?,
                                  "border-red-400 focus:outline-red-600":
                                    @player_class.errors[:name].any?
                                }
                              ]
      end

      div(class: "my-5") do
        plain form.label :hit_die
        plain form.text_field :hit_die,
                              class: [
                                "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full text-stone-950",
                                {
                                  "border-gray-400 focus:outline-blue-600":
                                    @player_class.errors[:hit_die].none?,
                                  "border-red-400 focus:outline-red-600":
                                    @player_class.errors[:hit_die].any?
                                }
                              ]
      end

      div(class: "my-5") do
        plain form.label :description
        plain form.textarea :description,
                            rows: 4,
                            class: [
                              "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full text-stone-950",
                              {
                                "border-gray-400 focus:outline-blue-600":
                                  @player_class.errors[:description].none?,
                                "border-red-400 focus:outline-red-600":
                                  @player_class.errors[:description].any?
                              }
                            ]
      end

      div(class: "my-5") do
        plain form.label :spellcasting_modifier
        plain form.text_field :spellcasting_modifier,
                              class: [
                                "block shadow-sm rounded-md border px-3 py-2 mt-2 w-full text-stone-950",
                                {
                                  "border-gray-400 focus:outline-blue-600":
                                    @player_class.errors[
                                      :spellcasting_modifier
                                    ].none?,
                                  "border-red-400 focus:outline-red-600":
                                    @player_class.errors[:spellcasting_modifier].any?
                                }
                              ]
      end

      div(class: "inline") do
        input type: "submit",
              name: "commit",
              value: @player_class.new_record? ? "Create Player class" : "Update Player class",
              class: input_primary_classes,
              data: { disable_with: "Update Player Class" }
      end
    end
  end

  def input_primary_classes
     "px-4 py-2 h-9 text-sm whitespace-nowrap inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 bg-primary text-primary-foreground shadow hover:bg-primary/90"
  end
end
