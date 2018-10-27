
require 'fileutils'
require 'logger'
require 'yaml'
require 'optparse'

@options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-d", "--dry-run", "Do a try run") do |v|
    puts "Running in dry run mode" if v
    @options[:dry_run] = v
  end
end.parse!


def convert_bytes_to_string(bytes)
  suffixes=["B","KiB","MB","GB","TB","EB"]
  val=bytes
  suffixIndex=0
  while val/1024>10
    val/=1024
    suffixIndex+=1
  end
  "#{val.round} #{suffixes[suffixIndex]}"
end

def seconds_to_s(total_time)
  total_time=total_time.to_int
  return [total_time / 3600, total_time/ 60 % 60, total_time % 60].map { |t| t.to_s.rjust(2,'0') }.join(':')
end

def execute_copy()
  config=YAML.load(File.read("./update_config.yml"))
  @logger.info("Using config #{config}")
  config[:destination]=File.realpath(config[:destination])

  @logger.debug "Using configuration #{config}"
  seen=YAML.load(File.read(config[:seen]))
  @logger.debug "Already seen files that will be skipped: #{seen}"
  if config[:file_digest] then
	@logger.info "Loading file digest"
	`scp seedbox:/home/user/files.yml .`
        candidates=YAML.load_file('./files.yml')
  else
    candidates=Dir.glob("#{config[:source_root]}/**/*").map(&File.method(:realpath))
    config[:source_root]=File.realpath(config[:source_root])
    candidates=candidates.select{|c|!File.directory?(c)}
  end
  @logger.debug "Files that are candidates: #{candidates}"

  files_to_copy=candidates-seen
  @logger.info "Files that need to be coppied: #{files_to_copy}"
  #remaining_size=files_to_copy.map{|f|File.size(f)}.inject(0){|sum,x| sum + x }
  #@logger.info "There are #{files_to_copy.size} files to copy totaling #{convert_bytes_to_string(remaining_size)}" if files_to_copy.size>0
  return if @options[:dry_run]
  bytes_coppied=1
  start_time=Time.now
  files_to_copy.each{|source|
    estimated_throughput=bytes_coppied/(Time.now - start_time)
    #size=File.size(source)
    #estimated_seconds=size/estimated_throughput

    relative_path=source.split(config[:source_root])[1]
    destination=File.join(config[:destination],relative_path)
    parent=File.dirname(destination)

    @logger.info "Copying #{source} to #{destination}."
#    @logger.info "Size is #{convert_bytes_to_string(size)}, and is estimated to take #{seconds_to_s(estimated_seconds)}"

    #FileUtils.mkdir_p(parent) unless File.exists?(parent)
    suffix=source.split(config[:source_root])[1]
    #FileUtils.cp(source,parent)
    command = "#{config[:wget]}#{suffix}\" \"--directory-prefix=#{parent}\""
    @logger.debug "Executing this command: #{command}"
    `#{command}`
    #bytes_coppied+=size
    #remaining_size-=size
    #estimated_throughput=bytes_coppied/(Time.now - start_time)
    #remaining_time=remaining_size/estimated_throughput
    @logger.info "Finished Coppying #{source} to #{destination}."
    #@logger.info "Estimated time remaining for all files: #{seconds_to_s(remaining_time)} to download #{convert_bytes_to_string(remaining_size)}"
    seen<<source
    File.write(config[:seen],seen.to_yaml)
  }
end

@logger=Logger.new(STDOUT)
@logger.level=Logger::INFO

result= `ps -ef | grep -v grep| grep "ruby ./bin/update.rb"`
@logger.info "Found another running process, exiting" if result.lines.count == 1
if result.lines.count !=1 then
  while true 
    execute_copy
    sleep(30 * 60)
  end
end


