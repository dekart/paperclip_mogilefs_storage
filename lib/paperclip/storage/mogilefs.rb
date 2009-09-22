module Paperclip
  module Storage
    module Mogilefs
      RETRIES_ON_BROKEN_SOCKET = 2 # 3 tries in total
      
      def mogilefs
        @instance.class.attachment_definitions[@name][:mogilefs_connection] ||=
          MogileFS::MogileFS.new(mogilefs_options[:connection].symbolize_keys)
      end

      def drop_mogilefs_connection!
        @instance.class.attachment_definitions[@name][:mogilefs_connection] = nil
      end

      def mogilefs_key_exist?(key)
        retry_on_broken_socket do
          mogilefs.get_paths(key).any?
        end
      rescue MogileFS::Backend::UnknownKeyError
        false
      end

      def exists?(style = default_style)
        mogilefs_key_exist?(url(style))
      end

      def to_file style = default_style
        if @queued_for_write[style]
          @queued_for_write[style]
        else
          retry_on_broken_socket do
            StringIO.new(mogilefs.get_file_data(url(style)))
          end
        end
      end
      alias_method :to_io, :to_file

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, io|
          Paperclip.log("Saving #{url(style)} to MogileFS")

          begin
            retry_on_broken_socket do
              begin
                io.open if io.closed? # Reopen IO to avoid empty_file error

                mogilefs.store_file(url(style), mogilefs_class, io)
              ensure
                io.close
              end
            end
          ensure
            io.close
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          Paperclip.log("Deleting #{path} from MogileFS")

          begin
            retry_on_broken_socket do
              mogilefs.delete(path)
            end
          rescue MogileFS::Backend::UnknownKeyError
            Paperclip.logger.error("[paperclip] Error: #{path} not found in MogileFS")
          end
        end
        @queued_for_delete = []
      end

      # Don't include timestamp by default
      def url(style = default_style, include_updated_timestamp = false)
        super(style, include_updated_timestamp)
      end

      # Use url instead of path while queuing attachments for delete
      def queue_existing_for_delete #:nodoc:
        return unless file?
        @queued_for_delete += [:original, *@styles.keys].uniq.map do |style|
          url(style) if exists?(style)
        end.compact
        instance_write(:file_name, nil)
        instance_write(:content_type, nil)
        instance_write(:file_size, nil)
        instance_write(:updated_at, nil)
      end

      def mogilefs_class
        if @options[:mogilefs] and @options[:mogilefs][:class]
          @options[:mogilefs][:class]
        else
          mogilefs_options[:class] || "file"
        end
      end

      def mogilefs_options
        @mogilefs_options ||= YAML.load_file(
          File.join(Rails.root, "config", "mogilefs.yml")
        )[Rails.env].symbolize_keys
      end

      def mogilefs_options=(value)
        @mogilefs_options = value
      end

      def retry_on_broken_socket
        retries = 0
        
        begin
          yield
        rescue MogileFS::UnreadableSocketError => e
          retries += 1
          
          if retries <= RETRIES_ON_BROKEN_SOCKET
            Paperclip.logger.error("[paperclip] MogileFS socket broken. Retrying (#{retries}/#{RETRIES_ON_BROKEN_SOCKET})...")

            drop_mogilefs_connection!
            
            retry
          else
            Paperclip.logger.error("[paperclip] MogileFS socket broken. Out of retries (#{retries}/#{RETRIES_ON_BROKEN_SOCKET})! Exiting...")

            raise e
          end
        end
      end

    end
  end
end