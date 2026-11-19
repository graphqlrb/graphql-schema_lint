# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |task|
  task.libs << "lib"
  task.test_files = FileList["test/**/test_*.rb"].exclude("test/test_helper.rb")
end

task default: :test

namespace :docs do
  desc "Generate the reference from gem metadata"
  task :generate do
    ruby "tools/generate_reference.rb"
  end

  desc "Check that the generated reference is current"
  task :check do
    ruby "tools/generate_reference.rb", "--check"
  end
end
