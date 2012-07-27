require "thread"
require "cloudfiles"

module Swift
  module Marathon
    class Runner
      def initialize(options)
        @swift_clusters  = Array.new
        @swift_clusters << CloudFiles::Connection.new(options[:swift][:primary])
        @swift_clusters << CloudFiles::Connection.new(options[:swift][:secondary])
        @swift_container = options[:swift][:container]
        @objects         = Queue.new
        Thread.abort_on_exception = true
      end

      def run!
        populate_objects
        2.times do
          create_worker
        end
        loop do
          sleep 30
        end
      end

      private

      def create_container(connection)
        unless connection.container_exists?(@swift_container)
          connection.create_container(@swift_container)
        end
      end

      def container_object_list(connection)
        container = connection.container(@swift_container)
        object_list  = Array.new
        call_options = { :limit => 2048 }
        puts "Getting container object list\n"
        loop do
          putc "."
          response_list = container.objects(call_options)
          object_list  += response_list
          if response_list.size < call_options[:limit]
            break
          end
          call_options[:marker] = response_list.last
        end
        puts ""
        object_list
      end

      def populate_objects
        Thread.new do
          object_lists = Array.new
          @swift_clusters.each do |connection|
            create_container(connection)
            object_lists << container_object_list(connection)
          end
          puts "Determining objects to be replicated"
          object_lists[0].each do |object_name|
            unless object_lists[1].include?(object_name)
              @objects.push(object_name)
            end
          end
        end
      end

      def replicate_object(object_name)
        puts "Replicating object: #{object_name}"
        object  = @swift_clusters[0].container(@swift_container).object(object_name)
        replica = @swift_clusters[1].container(@swift_container).create_object(object_name)
        pipe    = IO.pipe
        begin
          Thread.new do
            object.data_stream do |chunk|
              pipe[1].write(chunk)
            end
            pipe[1].close
          end
          headers = {
            "Etag" => object.etag
          }
          replica.write(pipe[0], headers)
          pipe[0].close
        rescue => error
          puts "Unexpected error: #{error}"
          pipe[0].close rescue nil
          pipe[1].close rescue nil
        end
      end

      def create_worker
        puts "Creating worker"
        Thread.new do
          loop do
            begin
              object_name = @objects.shift
              replicate_object(object_name)
            rescue => error
              puts "Unexpected error: #{error}"
            end
          end
        end
      end
    end
  end
end
