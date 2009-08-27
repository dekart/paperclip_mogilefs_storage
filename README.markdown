MogileFS Storage for Paperclip
======================

Store files uploaded with Paperclip in MogileFS storage system (http://www.danga.com/mogilefs/)

Requirements
------------

This plugin depends on mogilefs-client gem (http://seattlerb.rubyforge.org/mogilefs-client/)
and Thoughtbot's Paperclip gem/plugin (http://github.com/thoughtbot/paperclip)

Usage
-----

1) Set default Paperclip storage in your environment.rb file:

    Rails::Initializer.run do |config|
      ...

      config.after_initialize do
        Paperclip::Attachment.default_options.merge!(:storage => :mogilefs)
      end
    end

2) Add config/mogilefs.yml file with configuration:

    development:
      connection:
        domain: "my-development-domain.com"
        hosts:
          - 192.168.0.1:6001
      class: "file"

    production:
      connection:
        domain: "my-production-domain.com"
        hosts:
          - 12.34.56.78:6001
      class: "myclass"

3) Profit! :)

You can also use MogileFS only for certain attachments. In this case you should
define storage directly in your model, not in the environment.rb file. MogileFS class
can be also defined directly in the attachment definition (class "file" is used by default):

    class User < ActiveRecord::Base
      has_attached_file :avatar,
        :styles => {:small => "100x100>"}

      has_attached_file :photo,
        :styles   => {:normal => "600x600>"},
        :storage  => :mogilefs,
        :mogilefs => {:class => "photo"}
    end

Testing
-------

No tests yet :( You can fork this plugin at GitHub (http://github.com/dekart/paperclip_mogilefs_storage)
and add your own tests. I'll be happy to accept patches!

Installing the plugin
------------------

    ./script/plugin install git://github.com/dekart/paperclip_mogilefs_storage.git
    rake gems:install # Gem mogilefs-client will be installed

Credits
-------

Written by Alex Dmitriev (http://railorz.ru)

Thanks to Sergey Shadrin aka SergeantXP for code samples and patience :)
