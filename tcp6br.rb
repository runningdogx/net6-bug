#!/usr/bin/env ruby

# This script triggers misbehavior on my linux 2.6.38-rc2+.

require 'socket'

host = "::1"    # default host
port = "11011"    # default port
delay = 5    # seconds per loop

host = ARGV[0] if ARGV.length > 0
port = ARGV[1] if ARGV.length > 1

puts
puts "Usage: ./tcp6br.rb <bindip> <bindport>"
puts "If you're not root, you'll need to enable tcp_tw_recycle yourself"
#`echo 0 > /proc/sys/net/ipv4/tcp_syncookies`
`echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle`

begin
    server = TCPServer.open(host, port)
rescue
    puts "Could not establish listening socket on [#{host}]:#{port}"
    exit
end

port = server.addr[1]
addrs = server.addr[2..-1].uniq
#puts "Server listening on #{addrs.map{|a|"[#{a}]:#{port}"}.join(' ')}"
protonum = server.addr[0] == "AF_INET" ? "4" : "6" #host.include?(":") ? "6" : "4"
puts "Server listening on [#{host}]:#{port} (tcp#{protonum})"
puts


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
    end
end

# Find a port that's not connectable, and test that tcp6 works
testport = 55555
closedport = false
begin
    testsock = TCPSocket.new(host, testport)
    testsock.close if not testsock.nil?
    testport += 1
    next
rescue Errno::ECONNREFUSED
    closedport = true
rescue Errno::ENETUNREACH
    puts "[tcp#{protonum}] stack is broken!  #{$!}"
    exit
ensure
    begin testsock.close if not testsock.nil?
    rescue
    end
end while not closedport

puts "Chose (closed) port #{testport} to test that stack returns connection refused."

matchstr = "#{host}:#{port}"

loop do
    sleep delay

    collate = Hash.new(0)
    listeners = Hash.new
    `netstat -an -#{protonum} -t | tail -n +3`.each_line do |line|
        proto,  recv, send, local, remote, state = line.split
        if remote == matchstr then
            collate[state] += 1
        end
    end

    puts Time.now.strftime("%H:%M:%S") +
        "  SYN_S:#{collate["SYN_SENT"]}" +
        "  SYN_R:#{collate["SYN_RECV"]}" +
        "  TWAIT:#{collate["TIME_WAIT"]}" +
        "  FW1:#{collate["FIN_WAIT1"]}" +
        "  FW2:#{collate["FIN_WAIT2"]}" +
        "  CLOSING:#{collate["CLOSING"]}" +
        "  LACK:#{collate["LAST_ACK"]}"
    begin
        socket = TCPSocket.new(host, testport)
    rescue Errno::ECONNREFUSED
        next
    rescue Errno::ETIMEDOUT
        puts "!! TCP SOCKET TIMED OUT CONNECTING TO A LOCAL CLOSED PORT"
    #rescue Errno::ENETUNREACH
    rescue
        puts "[tcp#{protonum}] #{$!}"
    end
end

