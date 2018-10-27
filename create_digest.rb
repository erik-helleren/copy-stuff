require 'yaml'

path=ARGV[0]

puts "Using root path of #{path}"
candidates=Dir.glob("#{path}/**/*").map(&File.method(:realpath))
candidates=candidates.select{|c|!File.directory?(c)}

puts "Found a total of #{candidates.length} candidate files for copying"

File.write("files.yml",candidates.to_yaml)
