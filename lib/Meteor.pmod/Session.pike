// vim:syntax=c
string client_id;
function cb, error_cb;
int closing = 1;
MMP.Utils.Queue queue = MMP.Utils.Queue();

Thread.Mutex mutex = Thread.Mutex();
#define RETURN	destruct(lock); return
#define LOCK	object lock = mutex->lock()

#define KEEPALIVE	if (!kid) kid = call_out(keepalive, 30);
#define KEEPDEAD	if (kid) { remove_call_out(kid); kid = 0; }

Serialization.AtomParser parser = Serialization.AtomParser();
mixed kid;

// we keep the new id and the current and one stream
object connection_id;
object new_id;
object stream;

void create(string client_id, void|function cb, void|function error) {
	this_program::client_id = client_id;
	this_program::cb = cb;
	this_program::error_cb = error;
}

// this is called in intervals
void keepalive() {
	call_out(send, 0, Serialization.Atom("_keepalive", ""));
}

void stream_close(Meteor.Stream s, string reason) {
	LOCK;
	werror("%O: Proper close (%s)\n", this, reason);

	if (stream != s) {
		werror("an old stream got closed again: %O\n", s);
	}

	werror("new_id: %O\n", new_id);

	// dont write to the stream anymore
	connection_id = 0;
	closing = 1;
	stream = 0;
	KEEPDEAD;

	if (new_id) {
		call_out(register_new_id, 0);
	} else {
		// call_out and close after a timeout
	}
	RETURN;
}

void stream_error(Meteor.Stream s, string reason) {
	LOCK;
	werror("%O: error on stream (%s)\n", this, reason);
	// TODO: do something about this. probably remove the stream.
	// get rid of the stream and start keeping messages in the queue and
	// wait for a new one
	stream = 0;
	closing = 1;
	connection_id = 0;
	KEEPDEAD;
	RETURN;
}

void register_new_id() {
	LOCK;
	werror("%O: register_new_id(%O)\n", this, new_id);

	connection_id = new_id;
	new_id = 0;
	// IE needs an autoclose right now
	int autoclose = (-1 != search(connection_id->request_headers["user-agent"], "MSIE"));
	autoclose = 1;
	stream = Meteor.Stream(connection_id->connection(), stream_close, stream_error, autoclose);
	closing = 0;
	KEEPALIVE;

	string headers = Roxen.make_http_headers(([
		"Content-Type" : "application/octet-stream",
		"Transfer-Encoding" : "chunked",
	]));

	// send this first
	stream->out_buffer = "HTTP/1.1 200 OK\r\n" + headers;

	while (!queue->isEmpty()) {
		stream->write(queue->shift()->render());
	}

	KEEPALIVE;
	RETURN;
}

void handle_id(object id) {
	LOCK;

	if (id->method == "POST" && stringp(id->data) && sizeof(id->data)) {
		parser->feed(utf8_to_string(id->data));

		Serialization.Atom a;
		mixed err = catch {
			while (a = parser->parse()) {
				werror("%O: incoming(%O)\n", this, a);
				call_out(cb, 0, this, a);
			}
		};

		if (err) { // this is reason to disconnect
			werror("%O: Peer sent malformed atom, discarding.\n", this);
			id->send_result(Roxen.http_low_answer(500, "bad input"));
			parser = Serialization.AtomParser();
			RETURN;
		}

		id->send_result(Roxen.http_string_answer("ok"));
	} else {
		werror("%O: New connection from %O.\n", this, id->connection()->query_address());

		// TODO: change internal timeout from 180 s to infinity for Request
		new_id = id;

		if (connection_id) {
			werror("There still is a connection. closing first.\n");
			// close the current one and then use the new
			closing = 1;
			KEEPDEAD;
			stream->close();
		} else {
			werror("There is no stream, starting to use the new one.\n");
			call_out(register_new_id, 0);
		}
	}

	RETURN;
}

string _sprintf(int type) {
	if (type == 'O') {
		return sprintf("Session(%O%s, refs: %d)", stream, closing ? "c" : "",  _refs(this));
	} else return "Session()";
}

void send(Serialization.Atom atom) {
	LOCK;
	werror("%O: send(%O)\n", this, atom);
	if (closing) {
		queue->push(atom);	
	} else {
		stream->write(atom->render());
	}
	RETURN;
}
