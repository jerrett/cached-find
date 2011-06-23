require 'rails'

module CachedFind
  class Railtie < ::Rails::Railtie
    initializer "cached_find.extend_active_record" do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.send( :extend, CachedFind::ClassMethods )
      end
    end
  end
end

