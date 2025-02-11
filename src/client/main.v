module main

import net
import messages
import proxy

const client_addr = 'localhost:8001' // listen vok clients from this address (ping/pong)
const req_addr = 'localhost:8002' // listen requests from this address
const res_addr = 'localhost:8003' // listen responses from this address

const local_addr = 'localhost:8000'

fn main() {
	for {
		mut conn := net.dial_tcp(client_addr)!

		for {
			mut buf := []u8{len: messages.buf_len}
			n := conn.read(mut buf)!
			handle_message(mut conn, buf[..n]) or { break }
		}
	}
}

fn handle_message(mut conn net.TcpConn, message []u8) ! {
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

			go fn (mut local_conn net.TcpConn) ! {
				mut res_conn := net.dial_tcp(res_addr)!
				proxy.bidirectional(mut local_conn, mut res_conn)
				res_conn.close()!
				local_conn.close()!
			}(mut local_conn)
		}
		else {
			panic('invalid message ${message.bytestr()}')
		}
	}
}
