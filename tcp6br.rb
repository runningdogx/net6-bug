#!/usr/bin/ruby

# This script triggers a misbehavior/bug on my linux 2.6.37.
# It's been modified to do everything itself, but initially I would watch
# tcp6 connections in another window with
# while [ 1 ]; do wc -l /proc/net/tcp6; done

require 'socket'

# set this to any link-local or global ipv6 address on the host, but not ::1
host = "fc00::4"
#host = "::1" # doesn't trigger bug
#host = "192.168.1.4" # ipv4 doesn't trigger bug - if you try, change /proc/net/tcp6 to /proc/net/tcp
port = "2071"	# any port

filename = "/tmp/bug-tcp6-read-source"

begin
	server = TCPServer.open(host, port)
rescue
	next
end while server.nil?

port = server.addr[1]
addrs = server.addr[2..-1].uniq
puts "Server listening on #{addrs.map{|a|"[#{a}]:#{port}"}.join(' ')}"

File.open(filename, "w") {|h|
	h.puts "Sample content"
}

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

Thread.start do
	loop do
		begin
			socket = TCPSocket.new(host, port)
		rescue
		ensure
			begin
			socket.close if not socket.nil?
			rescue
			end
		end

		# This file access *seems* to trigger the bug faster.
		File.open(filename, "r") {|h|
			h.read
		}
	end
end

loop do
	out = `wc -l /proc/net/tcp6`.split
	puts Time.now.strftime("%H:%M:%S") + "\t " + out[1] + " lines: " + out[0]
	sleep 1
end

