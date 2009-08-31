module Paperclip
  module Storage
    module Mogilefs
      def mogilefs
        @mogilefs ||= MogileFS::MogileFS.new(mogilefs_options[:connection].symbolize_keys)
      end

      def mogilefs_key_exist?(key)
        mogilefs.get_paths(key).any?
      rescue MogileFS::Backend::UnknownKeyError
        return false
      end

      def exists?(style = default_style)
        mogilefs_key_exist?(url(style))
      end

      def to_file style = default_style
        @queued_for_write[style] || StringIO.new(mogilefs.get_file_data(path(style)))
      end
      alias_method :to_io, :to_file

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          Paperclip.log("Saving #{url(style)} to MogileFS")
          
          mogilefs.store_file(url(style), mogilefs_class, file)
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          Paperclip.log("Deleting #{path} from MogileFS")

          begin
            mogilefs.delete(path)
          rescue MogileFS::Backend::UnknownKeyError
            Paperclip.log("Error: #{path} not found in MogileFS")
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
        @mogilefs_options ||= YAML.load_file(File.join(Rails.root, "config", "mogilefs.yml"))[Rails.env].symbolize_keys
      end

      def mogilefs_options=(value)
        @mogilefs_options = value
      end

    end
  end
end