# frozen_string_literal: true

class Views::PlayerClasses::Index < Views::PlayerClasses::Base
  def page_title = "Player Classes - RPG Combat Simulator"

  def initialize(player_classes:, notice: nil)
    @player_classes = player_classes
    @notice = notice
  end

  def view_template
    div(class: "w-full") do
      if @notice.present?
        p(id: "notice", class: "py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounded-md inline-block") { @notice }
      end

      div(class: "flex justify-between items-center") do
        Heading(level: 1, class: "font-bold text-4xl") { "Player Classes" }
        Link(variant: :ghost, href: new_player_class_path, class: "border-2 border-solid text-white") { "New Player Class" }
      end

      div(id: "player_classes", class: "min-w-full divide-y divide-gray-200 space-y-5") do
        Table do
          TableHeader do
            TableRow do
              model_class.humanized_table_columns.each do |column|
                TableHead { column }
              end
            end
          end
          TableBody do
            if @player_classes.any?
              @player_classes.each do |player_class|
                TableRow do
                  TableCell { player_class.name }
                  TableCell { player_class.hit_die }
                  TableCell { player_class.description }
                  TableCell { player_class.spellcasting_modifier }
                end
              end
            else
              TableRow do
                TableCell(colspan: model_class.humanized_table_columns.size) { b { "No player classes found." } }
              end
            end
          end
        end
      end
    end
  end
end
