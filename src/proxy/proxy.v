module proxy

import io
import net
import context

fn cp(mut conn1 net.TcpConn, mut conn2 net.TcpConn, cancel context.CancelFn) {
	io.cp(mut conn1, mut conn2) or {}
	cancel()
}

pub fn bidirectional(mut conn1 net.TcpConn, mut conn2 net.TcpConn) {
	mut bg_ctx := context.background()
	mut ctx, cancel := context.with_cancel(mut bg_ctx)
	go cp(mut conn1, mut conn2, cancel)
	go cp(mut conn2, mut conn1, cancel)
	_ = <-ctx.done()
}
