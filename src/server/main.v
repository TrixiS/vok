module main

import os
import flag
import net
import time
import messages
import proxy

const ping_interval = i64(time.second * 1)
const ping_timeout = time.millisecond * 500
const res_timeout = i64(time.second * 5)
const conn_timeout = time.second

const err_expected_pong = error('expected pong')
const err_res_timeout = error('expected response')

struct Config {
	serve_addr string @[xdoc: 'vok client connections listen address']
	req_addr   string @[xdoc: 'request connections listen address (usually public)']
	res_addr   string @[xdoc: 'response connections listen address']
}

fn main() {
	config, _ := flag.to_struct[Config](os.args, skip: 1)!

	if config.serve_addr.len == 0 || config.req_addr.len == 0 || config.res_addr.len == 0 {
		println(flag.to_doc[Config]()!)
		return
	}

	client_lis := Listener.new(config.serve_addr)!

	println('started on ${config.serve_addr}')

	for {
		mut client_conn := <-client_lis.conn_chan

		mut req_conn_lis := Listener.new(config.req_addr)!
		mut res_conn_lis := Listener.new(config.res_addr)!

		client_conn.set_read_timeout(ping_timeout)
		client_conn.set_write_timeout(ping_timeout)

		handle_client(mut client_conn, req_conn_lis, res_conn_lis) or {}

		client_conn.close() or {}
		req_conn_lis.close()
		res_conn_lis.close()
	}
}

fn handle_client(mut conn net.TcpConn, req_conn_lis &Listener, res_conn_lis &Listener) ! {
	for {
		select {
			mut req_conn := <-req_conn_lis.conn_chan {
				conn.write(messages.ack) or {
					req_conn.close()!
					return err
				}

				mut buf := []u8{len: messages.buf_len}
				n := conn.read(mut buf) or {
					req_conn.close()!
					return err
				}

				if buf[..n] != messages.ack {
					req_conn.close()!
					continue
				}

				req_conn.set_read_timeout(conn_timeout)
				req_conn.set_write_timeout(conn_timeout)

				select {
					mut res_conn := <-res_conn_lis.conn_chan {
						res_conn.set_read_timeout(conn_timeout)
						res_conn.set_write_timeout(conn_timeout)

						// TODO: uncomment this when v coroutines will somewhat work
						// go fn (mut req_conn net.TcpConn, mut res_conn net.TcpConn) ! {
						proxy.bidirectional(mut req_conn, mut res_conn)
						req_conn.close()!
						res_conn.close()!
						// }(mut req_conn, mut res_conn)
					}
					res_timeout {
						return err_res_timeout
					}
				}
			}
			ping_interval {
				conn.write(messages.ping)!

				mut buf := []u8{len: messages.pong.len}
				conn.read(mut buf)!

				if buf != messages.pong {
					return err_expected_pong
				}
			}
		}
	}
}
