string client_id;
function cb, error_cb;

Serialization.AtomParser parser = Serialization.AtomParser();
MMP.Utils.Queue buffer = MMP.Utils.Queue();

object connection;
object connection_id;
object new_id;
object packet;
string out_buffer;
int out_pos, write_ready;
int the_end = 0;

void create(string client_id, void|function cb, void|function error) {
	this_program::client_id = client_id;
	this_program::cb = cb;
	this_program::error_cb = error;
}

void _close() {
	werror("%O: closed file.\n");
	int errno = connection->errno();
	remove_id();
	error_cb(this, sprintf("ERROR: %s (%d)\n", strerror(errno), errno));	
}

// this is called in intervals
void keepalive() {
	send(Serialization.Atom("_keepalive", "");
}

void remove_id() {
	connection_id = 0;

	if (connection) {
		connection->set_write_callback(0);
		connection->set_close_callback(0);
		connection->close();
		connection = 0;
	}
}

void register_new_id() {
	remove_id();
	connection_id = new_id;
	connection = connection_id->connection();
	//connection->set_keepalive(1);

	if (-1 != search(connection_id->request_headers["user-agent"], "MSIE")) {
		// we close after first write.
		the_end = 1;
	}

	string headers = Roxen.make_http_headers(([
		"Content-Type" : connection_id->method == "GET" ? "text/plain" : "application/octet-stream",
		"Transfer-Encoding" : "chunked",
	]));

	connection->set_write_callback(_write);
	connection->set_close_callback(_close);
	connection->write("HTTP/1.1 200 OK\r\n" + headers); // fire and forget

	new_id = 0;
	_write();
}

void handle_id(object id) {
	if (id->method == "POST" && stringp(id->data) && sizeof(id->data)) {
		werror("DATA: %O\n", id->data);
		parser->feed(utf8_to_string(id->data));

		Serialization.Atom a;
		mixed err = catch {
			while (a = parser->parse()) {
				call_out(cb, 0, this, a);
			}
		};

		if (err) { // this is reason to disconnect
			id->send_result(Roxen.http_low_answer(500, "bad input"));
			remove_id();
			error_cb(this, err);
			return;
		}

		id->send_result(Roxen.http_string_answer("ok"));
	} else {
		werror("New connection from %O.\n", id->connection()->query_address());

		// TODO: change internal timeout from 180 s to infinity for Request
		new_id = id;	

		if (connection) {
			the_end = 1;

			if (!(out_buffer)) {
				out_buffer = "";
				out_pos = 0;
				if (write_ready) _write();
			}
		} else {
			register_new_id();
		}
	}
}

void _write() {
	if (find_call_out(keepalive) != -1) {
		remove_call_out(keepalive);
	}

	call_out(keepalive, 30);

	if (connection) { 
		if (!connection->query_address()) {
			error_cb(this, describe_error(connection->errno()));
			remove_id();
			return;
		}

		if (!out_buffer) {
			if (buffer->is_empty()) {
				write_ready = 1;
				werror("Buffer is empty.\n");
				return;
			}

			String.Buffer s = String.Buffer();

			while (!buffer->is_empty()) {
				buffer->shift()->render(s); 
			}

			out_buffer = s->get();
			out_buffer = sprintf("%x\r\n%s\r\n", sizeof(out_buffer), out_buffer);
			out_pos = 0;
		}

		if (the_end) {
			werror("Finishing request.\n");
			out_buffer += "0\r\n\r\n";
		}
			
		werror("writing %d bytes to %O", sizeof(out_buffer)-out_pos, connection->query_address());
		int bytes = connection->write(out_pos ? out_buffer[out_pos..] : out_buffer);
		werror("(did %d)\n", bytes);

		// maybe too harsh?
		if (bytes == -1) {
			remove_id();
			error_cb(this, "Could not write to socket. Connection lost.\n");
			return;
		} else if (bytes+out_pos < sizeof(out_buffer)) {
			out_pos += bytes;
		} else {
			out_buffer = 0;
			out_pos = 0;

			if (the_end) {
				the_end = 0;

				// the_end is also used to close connections for
				// ie
				if (new_id) {
					register_new_id();
				} else {
					remove_id();
				}
			}
		}

		write_ready = 0;
	} else {
		error_cb(this, "No connection found.\n");
	}
}

string _sprintf(int type) {
	if (type == 'O') {
		return sprintf("Session(%O)", connection ? connection->query_address() : sprintf("disconnected refs: %d", _refs(this)));
	} else return "Session()";
}

void send(Serialization.Atom atom) {
	buffer->push(atom);

	if (write_ready) {
		// call out to allow for several sends in a row

		if (find_call_out(_write) == -1) {
			call_out(_write, 0);
		}
	}
}
