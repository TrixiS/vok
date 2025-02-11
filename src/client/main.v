module main

import os
import time
import net
import messages
import proxy
import dotenv

const reconnection_delay = time.second * 1

fn main() {
	dotenv.load() or {}

	server_addr := os.getenv('SERVER_ADDR')
	res_addr := os.getenv('RES_ADDR')
	local_addr := os.args[1]

	for {
		mut conn := net.dial_tcp(server_addr)!

		for {
			mut buf := []u8{len: messages.buf_len}
			n := conn.read(mut buf) or { break }
			handle_message(mut conn, buf[..n], local_addr, res_addr) or { break }
		}

		conn.close() or {}
		time.sleep(reconnection_delay)
	}
}

fn handle_message(mut conn net.TcpConn, message []u8, local_addr string, res_addr string) ! {
	match message {
		messages.ping {
			conn.write(messages.pong)!
		}
		messages.ack {
			mut local_conn := net.dial_tcp(local_addr) or {
				conn.write(messages.nack)!
				return
			}

			conn.write(messages.ack) or {
				local_conn.close()!
				return err
			}

			go fn (mut local_conn net.TcpConn, res_addr string) ! {
				defer { local_conn.close() or {} }
				mut res_conn := net.dial_tcp(res_addr)!
				proxy.bidirectional(mut local_conn, mut res_conn)
				res_conn.close()!
			}(mut local_conn, res_addr)
		}
		else {
			panic('invalid message ${message.bytestr()}')
		}
	}
}
