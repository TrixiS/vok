module main

import net
import time
import messages
import proxy

const server_addr = 'localhost:8001' // listen vok clients from this address (ping/pong)
const req_addr = 'localhost:8002' // listen requests from this address
const res_addr = 'localhost:8003' // listen responses from this address

const ping_interval = i64(time.millisecond * 800)
const ping_timeout = time.millisecond * 500

const res_timeout = i64(time.second * 5)

const err_expected_pong = error('expected pong')
const err_res_timeout = error('expected response')

fn main() {
	client_lis := Listener.new(server_addr)!

	for {
		mut client_conn := <-client_lis.conn_chan

		mut req_conn_lis := Listener.new(req_addr)!
		mut res_conn_lis := Listener.new(res_addr)!

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
				conn.write(messages.ack)!

				mut buf := []u8{len: messages.buf_len}
				n := conn.read(mut buf)!

				if buf[..n] != messages.ack {
					req_conn.close()!
					continue
				}

				select {
					mut res_conn := <-res_conn_lis.conn_chan {
						go fn (mut req_conn net.TcpConn, mut res_conn net.TcpConn) ! {
							proxy.bidirectional(mut req_conn, mut res_conn)
							req_conn.close()!
							res_conn.close()!
						}(mut req_conn, mut res_conn)
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
