# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |task|
  task.libs << "lib"
  task.test_files = FileList["test/**/test_*.rb"].exclude("test/test_helper.rb")
end

task default: :test
