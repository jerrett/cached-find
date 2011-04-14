require 'railtie'

module CachedFind
  VERSION = '0.0.1'
  # This provides a super simple wrapper around Rails.cache.fetch to make it super
  # easy to grab objects from the database using caching. It also handles the glory that is
  # unmarshalling objects from memory into classes lazy/auto loaded from Rails. (Extra fun in development!)
  #
  # If you need to manually use Rails.cache.something and need the key, 
  # call +cached_find_key_for( *args )+ using the same *args you would use on the cached_find.
  # 
  # This works in Rails 3.0.7
  module ClassMethods
    # Just makes it a bit eaiser to expire - this just adds the class name for you.
    # It can be called with the dynamic finder method you want to clear and the arguments,
    # or simply the id of a cached_find.
    #
    #   expire_cache( 1 )  # Expire results of cached_find( 1 )
    #   expire_cache( :find_by_foo_and_bar, 'foo', 'bar' )  # Expire results of cached_find_by_foo_and_bar( 'foo', 'bar' )
    def expire_cache( *parts )
      options = parts.extract_options!
      parts.unshift('find') if parts.length == 1
      Rails.cache.delete( cached_find_key_for(parts.shift, *parts + [options]) )
    end

    # Allow cached find on dynamic finders, eg. +cached_find_by_foo_and_bar( 'foo', 'bar' )+
    # Keys are built using +build_cache_key+.
    def method_missing_with_simple_caching( method_id, *arguments )
      method_missing_without_simple_caching( method_id, *arguments ) and return unless method_id.to_s.match(/^cached_find/)
      dynamic_finder_method = method_id.to_s.gsub( 'cached_find', 'find')

      fetch_from_cache( cached_find_key_for(dynamic_finder_method, *arguments) ) do
        send( dynamic_finder_method, *arguments )
      end
    end
    alias_method_chain :method_missing, :simple_caching

    # Return a cached find key for the method/args. This takes the same params as +cached_find+ and 
    # +expire_cache+
    def cached_find_key_for( cached_method, *parts )
      options = parts.extract_options!

      key = "#{to_s.underscore}:#{cached_method}:#{parts.join(',')}"
      key += ":#{options.collect { |k,v| "#{k}=#{v}" }.sort.join(',')}" unless options.empty?
      key.gsub!(' ','_')

      "CF:#{to_s.underscore}:#{Digest::SHA1.hexdigest( key )}"
    end

    # This deals with the fact that Ruby needs to have a class loaded before it can be unmarshalled
    # and in development mode at least, Rails unloads everything after each request auto-loading classes
    # when needed (which is too late.)
    def fetch_from_cache( key, &block ) #:nodoc:
      begin 
        Rails.cache.fetch( key ) { block.call }
      rescue ArgumentError => error
        # I stole this from cache_fu (cache_methods.rb). Thanks, cache_fu!
        lazy_load ||= Hash.new { |hash, hash_key| hash[hash_key] = true; false }
        if error.to_s[/undefined class|referred/] && !lazy_load[error.to_s.split.last.sub(/::$/, '').constantize] then retry
        else raise error end
      end
    end

  end
end
