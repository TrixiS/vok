module proxy

import io
import net

pub fn bidirectional(mut conn1 net.TcpConn, mut conn2 net.TcpConn) {
	c := chan u8{}
	go cp(mut conn1, mut conn2, c)
	go cp(mut conn2, mut conn1, c)
	_ = <-c
}

fn cp(mut conn1 net.TcpConn, mut conn2 net.TcpConn, c chan u8) {
	io.cp(mut conn1, mut conn2) or {}
	c <- 0
}
