require "spec"
require "socket"
require "../../spec_helper"
require "../../../support/ssl"

describe OpenSSL::SSL::Server do
  it "sync_close" do
    TCPServer.open(0) do |tcp_server|
      context = OpenSSL::SSL::Context::Server.new
      ssl_server = OpenSSL::SSL::Server.new(tcp_server, context)

      ssl_server.close

      tcp_server.closed?.should be_true
    end
  end

  it "don't sync_close" do
    TCPServer.open(0) do |tcp_server|
      context = OpenSSL::SSL::Context::Server.new
      ssl_server = OpenSSL::SSL::Server.new(tcp_server, context, sync_close: false)
      ssl_server.context.should eq context

      ssl_server.close

      tcp_server.closed?.should be_false
    end
  end

  it ".new" do
    context = OpenSSL::SSL::Context::Server.new
    TCPServer.open(0) do |tcp_server|
      ssl_server = OpenSSL::SSL::Server.new tcp_server, context, sync_close: false

      ssl_server.context.should eq context
      ssl_server.wrapped.should eq tcp_server
      ssl_server.sync_close?.should be_false
    end
  end

  it ".open" do
    context = OpenSSL::SSL::Context::Server.new
    TCPServer.open(0) do |tcp_server|
      ssl_server = nil
      OpenSSL::SSL::Server.open tcp_server, context do |server|
        server.wrapped.should eq tcp_server
        ssl_server = server
      end

      ssl_server.try(&.closed?).should be_true
      tcp_server.closed?.should be_true
    end
  end

  describe "#accept?" do
    it "accepts" do
      tcp_server = TCPServer.new(0)

      server_context, client_context = ssl_context_pair

      OpenSSL::SSL::Server.open tcp_server, server_context do |server|
        spawn do
          client = server.accept?
          client.should be_a(OpenSSL::SSL::Socket::Server)
          client = client.not_nil!
          client.gets.should eq "Hello, SSL!"
          client.close
        end

        Fiber.yield

        OpenSSL::SSL::Socket::Client.open(TCPSocket.new(tcp_server.local_address.address, tcp_server.local_address.port), client_context) do |socket|
          socket.puts "Hello, SSL!"
        end
      end
    end
  end
end
