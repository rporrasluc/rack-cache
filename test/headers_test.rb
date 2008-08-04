require "#{File.dirname(__FILE__)}/spec_setup"

class MockResponse < Rack::MockResponse
  include Rack::Cache::Headers
end

describe 'Rack::Cache::Headers' do

  before(:each) {
    @now = Time.now
    @res = MockResponse.new(200, {'Date' => @now.httpdate}, '')
    @one_hour_ago = Time.httpdate((Time.now - (60**2)).httpdate)
  }

  after(:each) {
    @now, @res, @one_hour_ago = nil
  }

  describe '#cache_control' do
    it 'handles single name=value pair' do
      @res.headers['Cache-Control'] = 'max-age=600'
      @res.cache_control['max-age'].should.be == '600'
    end
    it 'handles multiple name=value pairs' do
      @res.headers['Cache-Control'] = 'max-age=600, max-stale=300, min-fresh=570'
      @res.cache_control['max-age'].should.be == '600'
      @res.cache_control['max-stale'].should.be == '300'
      @res.cache_control['min-fresh'].should.be == '570'
    end
    it 'handles a single flag value' do
      @res.headers['Cache-Control'] = 'no-cache'
      @res.cache_control.should.include 'no-cache'
      @res.cache_control['no-cache'].should.be true
    end
    it 'handles a bunch of all kinds of stuff' do
      @res.headers['Cache-Control'] = 'max-age=600,must-revalidate,min-fresh=3000,foo=bar,baz'
      @res.cache_control['max-age'].should.be == '600'
      @res.cache_control['must-revalidate'].should.be true
      @res.cache_control['min-fresh'].should.be == '3000'
      @res.cache_control['foo'].should.be == 'bar'
      @res.cache_control['baz'].should.be true
    end
  end

end


describe 'Rack::Cache::ResponseHeaders' do

  before(:each) {
    @now = Time.now
    @one_hour_ago = Time.httpdate((Time.now - (60**2)).httpdate)
    @one_hour_later = Time.httpdate((Time.now + (60**2)).httpdate)
    @res = MockResponse.new(200, {'Date' => @now.httpdate}, '')
    @res.extend Rack::Cache::ResponseHeaders
  }

  after(:each) {
    @now, @res, @one_hour_ago = nil
  }

  describe '#date' do
    it 'uses the Date header if present' do
      @res = MockResponse.new(200, { 'Date' => @one_hour_ago.httpdate }, '')
      @res.extend Rack::Cache::ResponseHeaders
      @res.date.should.be == @one_hour_ago
    end
    it 'uses the current time when no Date header present' do
      @res = MockResponse.new(200, {}, '')
      @res.extend Rack::Cache::ResponseHeaders
      @res.date.should.be.close Time.now, 1
    end
  end

  describe '#expires_at' do
    it 'returns #date + #max_age when Cache-Control/max-age is present' do
      @res.headers['Cache-Control'] = 'max-age=500'
      @res.expires_at.should.be == @res.date + 500
    end
    it 'uses the Expires header when present and no Cache-Control/max-age' do
      @res.headers['Expires'] = @one_hour_ago.httpdate
      @res.expires_at.should.be == @one_hour_ago
    end
    it 'returns nil when no Expires or Cache-Control provided' do
      @res.expires_at.should.be nil
    end
  end

  describe '#max_age' do
    it 'uses Cache-Control to calculate #max_age when present' do
      @res.headers['Cache-Control'] = 'max-age=600'
      @res.max_age.should.be == 600
    end
    it 'uses Expires for #max_age if no Cache-Control max-age present' do
      @res.headers['Cache-Control'] = 'must-revalidate'
      @res.headers['Expires'] = @one_hour_later.httpdate
      @res.max_age.should.be == 60 ** 2
    end
    it 'gives a #max_age of nil when no freshness information available' do
      @res.max_age.should.be.nil
    end
  end

  describe '#ttl' do
    it 'is nil when no Expires or Cache-Control headers present' do
      @res.ttl.should.be.nil
    end
    it 'uses the Expires header when no max-age is present' do
      @res.headers['Expires'] = (@res.now + (60**2)).httpdate
      @res.ttl.should.be.close(60**2, 1)
    end
    it 'returns negative values when Expires is in part' do
      @res.ttl.should.be.nil
      @res.headers['Expires'] = @one_hour_ago.httpdate
      @res.ttl.should.be < 0
    end
    it 'uses the Cache-Control max-age value when present' do
      @res.headers['Cache-Control'] = 'max-age=60'
      @res.ttl.should.be.close(60, 1)
    end
  end

end