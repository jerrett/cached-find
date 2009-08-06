require File.dirname(__FILE__) + '/spec_helper'

class SimpleCachingTest
  def self.class_name 
    'SimpleCachingTest'
  end
end
SimpleCachingTest.send( :extend, CachedFind::ClassMethods )

describe SimpleCachingTest do
  before( :each ) do 
    Rails.stub!( :cache ).and_return( mock('railsy cacheyness') )
  end

  describe 'when expiring the cache' do 
    it 'should call Rails.cache.delete with the proper cache key' do 
      SimpleCachingTest.should_receive( :cached_find_key_for ).with( :find_by_foo_and_bar, 'foo', 'bar', :limit => 12 ).and_return( 'thekey' )
      Rails.cache.should_receive( :delete ).with( 'thekey' )
      SimpleCachingTest.expire_cache( :find_by_foo_and_bar, 'foo', 'bar', :limit => 12 )
    end

    it 'should remove add find if an id was the only thing passed' do 
      SimpleCachingTest.should_receive( :cached_find_key_for ).with( 'find', 12 , {}).and_return( 'mykey' )
      Rails.cache.should_receive( :delete ).with( 'mykey' )
      SimpleCachingTest.expire_cache( 12 )
    end
  end
  
  describe 'when calling method missing' do 
    it 'should call normal method missing if the method is not a cached_find one' do
      SimpleCachingTest.should_receive( :method_missing_without_simple_caching ).with( :foobar ).and_return( 'foo' )
      SimpleCachingTest.should_receive( :fetch_from_cache ).never
      SimpleCachingTest.foobar
    end

    it 'should call fetch from cache with the right key' do
      SimpleCachingTest.should_receive( :cached_find_key_for ).with( 'find_by_id', 12, :limit => 2 ).and_return( 'zekey' )
      SimpleCachingTest.should_receive( :fetch_from_cache ).with( 'zekey' )
      SimpleCachingTest.cached_find_by_id(12, :limit => 2)
    end

    it 'should call the method if the key is not found' do
      SimpleCachingTest.should_receive( :fetch_from_cache ).and_yield
      SimpleCachingTest.should_receive( :find_by_id ).with( 12 )
      SimpleCachingTest.cached_find_by_id( 12 )
    end
  end

  describe 'when cached find key is being created' do 
    it 'should a proper cached find key' do  
      key = SimpleCachingTest.cached_find_key_for( :find_by_foo, 'bar', :conditions => 'something = 12', :include => [:foo] )
      key.should == 'CF:simple_caching_test:c627eaeda6347d547763d8d69a6b06c371bda2ba'
    end 
  end

  describe 'when fetching from cache' do 
    it 'should call Rails.cache.fetch with the key' do 
      Rails.cache.should_receive( :fetch ).with( 'mykey' )
      SimpleCachingTest.fetch_from_cache( 'mykey' )
    end

    it 'the pass the block to cache.fetch' do 
      mock = mock('some mock')
      Rails.cache.should_receive( :fetch ).and_yield
      mock.should_receive( :something! )
      SimpleCachingTest.fetch_from_cache( 'mykey' ) { mock.something! }
    end

    it 'should try to constantize models if there is an error raised' do
      Rails.cache.should_receive( :fetch ).twice.and_yield

      Marshal.should_receive( :restore ).ordered.and_raise(ArgumentError.new('undefined class/module String'))
      Marshal.should_receive( :restore ).ordered.and_return('yay')

      x = SimpleCachingTest.fetch_from_cache( 'mykey' ) { Marshal.restore('some stuff') }
      x.should == 'yay'
    end
      
    it 'should re-raise other exceptions' do
      mock = ('my mock')
      mock.should_receive( :bar! ).and_raise(ArgumentError.new('zomg!'))

      Rails.cache.should_receive( :fetch ).and_yield
      lambda { SimpleCachingTest.fetch_from_cache( 'foo' ) { mock.bar! } }.should raise_error(ArgumentError)
    end
  end
end
