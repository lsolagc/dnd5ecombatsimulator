namespace :gambits do
  desc "Replace the gambits of Brenna Ironhide and Corwin Vale with their Pass 6 setup (idempotent)"
  task brenna_corwin: :environment do
    GambitSetups.apply!.each do |character, gambits|
      puts "#{character.name} (id #{character.id})"
      gambits.each { |gambit| puts "  #{gambit.position}. #{gambit.label}#{' (desligada)' unless gambit.enabled}" }
    end
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => error
    abort "gambits:brenna_corwin abortada, nada foi alterado: #{error.message}"
  end
end
