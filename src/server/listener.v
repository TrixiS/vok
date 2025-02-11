module main

import net

struct Listener {
	conn_chan chan &net.TcpConn
mut:
	lis &net.TcpListener
}

fn Listener.new(addr string) !&Listener {
	mut l := &Listener{
		lis:       net.listen_tcp(net.AddrFamily.ip, addr, net.ListenOptions{})!
		conn_chan: chan &net.TcpConn{}
	}

	go l.listen()
	return l
}

fn (mut l Listener) listen() {
	for {
		mut conn := l.lis.accept() or { break }
		l.conn_chan <- conn
	}
}

fn (mut l Listener) close() {
	l.lis.close() or {}
	l.conn_chan.close()
}
