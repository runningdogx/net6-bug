#!/usr/bin/ruby

# monitor tcp6 connections in another window with
# while [ 1 ]; do cat /proc/net/tcp6| cut -d " " -f 1-2; done 
# when it starts climbing into the hundreds of thousands, the bug had been triggered.

require 'socket'

# set this to any link-local or global ipv6 address on the host, but not ::1
host = "fc00::4"
port = "2071"

begin
	server = TCPServer.open(host, port)
rescue
	next
end while server.nil?
puts "successfully opened server"

port = server.addr[1]
addrs = server.addr[2..-1].uniq

puts "*** listening on #{addrs.collect{|a|"#{a}:#{port}"}.join(' ')}"

Thread.start do
	# Server thread
	loop do
		begin
			socket = server.accept
		rescue
		ensure
			begin
			socket.close if not socket.nil?
			rescue
			end
		end
	end
end

counter = 0
while true do
	begin
		socket = TCPSocket.new(host, port)
	rescue
	ensure
		begin
		socket.close if not socket.nil?
		rescue
		end
	end

	counter += 1
	puts counter if counter%100 == 0

	# these next commented out lines might trigger the bug faster, not sure
	# the reason I thought to include them at all is because of how this bug
	# was initially discovered.  I was running apachebench2 against a
	# webserver, and the bug was readily noticeable when hitting a php script,
	# which naturally does all sorts of other file IO concurrent with the
	# ongoing ipv6 connections.  Running apachebench against static files
	# I could not reproduce the problem.  However, this script seems to trigger
	# the bug with only the tcp6 connection flooding.

	#h = File.open("/tmp/bug-foo-client", "w")
	#h.puts "Test of the emergency broadcast system"
	#h.close
	#File.unlink("/tmp/bug-foo-client")
end


