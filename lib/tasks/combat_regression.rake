# Safety net for refactoring CombatSimulatorService: see .okf/ops/combat-regression.md.
require "etc"

namespace :combat_regression do
  desc "Rewrite the golden files and the query baseline from the current code (runs the regression test in write mode)"
  task :regenerate do
    sh({ "COMBAT_REGRESSION_WRITE" => "1" }, "bin/rails", "test", "test/services/combat_regression_test.rb")
  end

  desc "Median ms and queries per simulation per composition (RAILS_ENV=test); RECORD=1 writes the baseline, else exits 1 above it + 10%"
  task benchmark: :environment do
    abort "combat_regression:benchmark runs in the test environment: RAILS_ENV=test bin/rails combat_regression:benchmark" unless Rails.env.test?

    runs = Integer(ENV.fetch("RUNS", 40))
    compositions = CombatRegression::COMPOSITIONS
    samples = compositions.transform_values { [] }
    queries = {}
    ActiveRecord::Base.logger = nil # SQL debug lines to log/test.log only add I/O noise
    ActiveRecord::Base.transaction do
      CombatRegression.load_seeds!
      compositions.each { |name, composition| queries[name] = CombatRegression.within(composition) { CombatRegression.queries_per_sim(composition) } }
      # A warm-up round, then rounds that take turns over the compositions after timing the yardstick.
      (runs + 1).times do |round|
        reference = CombatRegression.reference_ms
        compositions.each do |name, composition|
          ms = CombatRegression.within(composition) { CombatRegression.ms_per_sim(composition) }
          samples[name] << [ ms, ms / reference ] unless round.zero?
        end
      end
      raise ActiveRecord::Rollback
    end
    median = ->(values) { values.sort[values.size / 2] }
    measured = compositions.keys.index_with do |name|
      { "ms_per_sim" => median.(samples[name].map(&:first)).round(2), "relative" => median.(samples[name].map(&:last)).round(3),
        "queries_per_sim" => queries[name] }
    end

    path = CombatRegression.benchmark_baseline_path
    baseline = File.exist?(path) && ENV["RECORD"] != "1" ? YAML.load_file(path) : nil
    # The yardstick cancels drift within one environment, not across them (Docker + YJIT vs the host
    # without it measured +40% on unchanged code): compare only where the baseline was recorded.
    if baseline
      recorded = baseline["environment"].values_at("docker", "ruby", "cpu")
      current = [ File.exist?("/.dockerenv"), RUBY_DESCRIPTION, File.exist?("/proc/cpuinfo") ? File.read("/proc/cpuinfo")[/model name\s*:\s*(.+)/, 1] : nil ]
      abort "the baseline was recorded on another environment (docker, ruby, cpu: #{recorded.to_json}, here #{current.to_json}): " \
            "run it there or record a new one with RECORD=1" if recorded != current
    end
    over = []
    measured.each do |name, numbers|
      line = format("%-40s %8.2f ms/sim %4d queries/sim %7.3f relative", name, *numbers.values_at("ms_per_sim", "queries_per_sim", "relative"))
      if baseline
        base = baseline.dig("compositions", name)
        over << name if base.nil? || numbers["relative"] > base["relative"] * 1.1
        line += base ? format("  (base %.2f ms, relative %+.1f%%)", base["ms_per_sim"], (numbers["relative"] / base["relative"] - 1) * 100) : "  (no base)"
      end
      puts line
    end

    if baseline
      puts "base recorded on: #{baseline['environment'].to_json}"
      abort "over the baseline + 10% (relative time): #{over.join(', ')}" if over.any?
    else
      environment = {
        "recorded_at" => Time.now.utc.iso8601, "runs" => runs, "seeds" => CombatRegression::SEEDS.size,
        "host" => Etc.uname.values_at(:sysname, :release, :machine).join(" "), "docker" => File.exist?("/.dockerenv"),
        "cpu" => File.exist?("/proc/cpuinfo") ? File.read("/proc/cpuinfo")[/model name\s*:\s*(.+)/, 1] : nil,
        "cpus" => Etc.nprocessors, "ruby" => RUBY_DESCRIPTION, "rails" => Rails.version,
        "postgres" => ActiveRecord::Base.connection.select_value("SHOW server_version")
      }
      File.write(path, YAML.dump("environment" => environment, "compositions" => measured))
      puts "baseline written to #{path.relative_path_from(Rails.root)}"
    end
  end
end
