require_relative 'spec_helper'
require 'timecop'

describe Rack::LtsvLogger do
  def app
    lambda { |env|
      [200, {'Content-Type' => 'text/plain'}, ["Hello, World!"]]
    }
  end

  def parse_ltsv(ltsv)
    Hash[*(ltsv.chomp.split("\t").map {|e| e.split(":", 2) }.flatten)]
  end

  let(:now)      { Time.now }
  let(:time)     { now.iso8601 }
  let(:pid)      { Process.pid }
  let(:host)     { '127.0.0.1' }
  let(:forwardedfor) { '127.0.0.2' }
  let(:user)     { 'user' }
  let(:protocol) { 'HTTP/1.1' }
  let(:env) do
    {
      'REMOTE_ADDR' => host,
      'HTTP_X_FORWARDED_FOR' => forwardedfor,
      'REMOTE_USER' => user,
      'HTTP_VERSION' => protocol,
    }
  end

  before do
    Timecop.freeze now
  end

  after do
    Timecop.return
  end

  context 'ltsv' do
    subject do
      @output = StringIO.new
      Rack::Lint.new( Rack::LtsvLogger.new(app, @output) )
    end

    let(:method)   { 'GET' }
    let(:uri)      { '/get' }
    let(:query)    { '?foo' }

    it do
      Rack::MockRequest.new(subject).get("#{uri}#{query}", env)
      expect(@output.string).to eq \
        "time:#{time}\tpid:#{pid}\thost:#{host}\tforwardedfor:#{forwardedfor}\tuser:#{user}\t" +
        "method:#{method}\turi:#{uri}\tquery:#{query}\tprotocol:#{protocol}\tstatus:200\tsize:-\treqtime:0.000000\n"
    end
  end

  context 'appends' do
    let(:appends) do
      { x_runtime: Proc.new {|env| '1.234' } }
    end

    subject do
      @output = StringIO.new
      Rack::Lint.new( Rack::LtsvLogger.new(app, @output, appends) )
    end

    it 'GET /get' do
      Rack::MockRequest.new(subject).get('/get', env)
      params = parse_ltsv(@output.string)
      expect(params['x_runtime']).to eq('1.234')
    end
  end
end
