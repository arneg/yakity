// vim:syntax=c
/*
Copyright (C) 2008-2009  Arne Goedeke

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
version 2 as published by the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/
constant keepalive_interval = 30;
constant timeout = 5;
constant keepalive_packet = "_keepalive 0 ";
string client_id;
function cb, error_cb;
int closing = 1;
MMP.Utils.Queue queue = MMP.Utils.Queue();

#ifdef ENABLE_THREADS
Thread.Mutex mutex = Thread.Mutex();
# define RETURN	destruct(lock); return
# define LOCK	object lock = mutex->lock()
#else
# define RETURN return
# define LOCK
#endif

#define KEEPALIVE	if (!kid) { kid = call_out(keepalive, keepalive_interval); }
#define KEEPDEAD	if (kid) { remove_call_out(kid); kid = 0; }

Serialization.AtomParser parser = Serialization.AtomParser();
// call_out ids for keepalive and logout
mixed kid, lid;

// we keep the new id and the current and one stream
object connection_id;
object new_id;
object stream;

void create(string client_id, void|function cb, void|function error) {
	this_program::client_id = client_id;
	this_program::cb = cb;
	this_program::error_cb = error;

	lid = call_out(die, timeout, "No Stream connected.");
}

// this is called in intervals
void keepalive() {
	kid = 0;
	stream->write(keepalive_packet);
	KEEPALIVE;
}

void end_stream() {
    	//werror("ending http stream.\n");
	connection_id->end();
	connection_id = 0;
	closing = 1;
	stream = 0;
	KEEPDEAD;
}

void die(string reason) {
	LOCK;
	//werror("DIE\n");
	lid = 0;

	call_out(error_cb, 0, this, reason);
	cb = 0;
	error_cb = 0;

	RETURN;
}

void stream_close(Meteor.Stream s, string reason) {
	LOCK;
	//werror("%O: Proper close (%s)\n", this, reason);

	if (stream != s) {
		werror("an old stream got closed again: %O\n", s);
	}

	//werror("new_id: %O\n", new_id);

	// dont write to the stream anymore
	end_stream();

	if (new_id) {
		call_out(register_new_id, 0);
	} else {
	    	//werror("Calling die in %d seconds.\n", timeout);
		lid = call_out(die, timeout, reason);
		// call_out and close after a timeout
	}
	RETURN;
}

void stream_error(Meteor.Stream s, string reason) {
	LOCK;
	lid = call_out(die, 0, sprintf("Timed out after error: %s.\n", reason));
	// TODO: do something about this. probably remove the stream.
	// get rid of the stream and start keeping messages in the queue and
	// wait for a new one
	end_stream();
	RETURN;
}

void register_new_id() {
	LOCK;
	//werror("%O: register_new_id(%O)\n", this, new_id);

	if (lid) {
		remove_call_out(lid);
		lid = 0;
	}

	connection_id = new_id;
	new_id = 0;

	// browser now asks for autoclose on their own
	int autoclose = !!((int)connection_id->variables["autoclose"]);


	//if (autoclose) werror("Creating new autoclosing Stream for %O\n", connection_id);

	mapping headers = ([
		"Transfer-Encoding" : "chunked",
	]);

	if (connection_id->misc["content_type_type"] == "application/octet-stream") {
		//werror("creating binary stream\n");
		headers["Content-Type"] = "application/octet-stream";
		stream = Meteor.Stream(connection_id->connection(), stream_close, stream_error, autoclose);
	} else {
		//werror("creating utf8 stream\n");
		headers["Content-Type"] = "text/plain; charset=utf-8";
		stream = Meteor.UTF8Stream(connection_id->connection(), stream_close, stream_error, autoclose);
	}

	closing = 0;
	KEEPALIVE;

	if (autoclose) headers["Connection"] = "keep-alive";

	// we append a keepalive packet to trigger readyState 3
	stream->out_buffer->add(connection_id->make_response_headers(headers) + sprintf("%x\r\n%s\r\n", sizeof(keepalive_packet), keepalive_packet));
	
	//string t = stream->out_buffer->get();
	//stream->out_buffer->add(t);
	//werror("request_headers: %O\nresponse_headers: %O\n", connection_id->request_headers, connection_id->make_response_headers(headers));
	//werror("response_headers:\n%s\n", connection_id->make_response_headers(headers));

	while (!queue->isEmpty()) {
		mixed o = queue->shift();
		if (stringp(o)) stream->write(o);
		else stream->write(o->render());
	}

	RETURN;
}

void handle_id(object id) {
	LOCK;

	//werror("%s: data: %O\n", id->method, id->data);

	if (id->method == "POST" && stringp(id->data) && sizeof(id->data)) {

		if (id->request_headers["content-type"] == "application/octet-stream") {
			//werror("Feeding %d bytes of data.\n", sizeof(id->data));
			parser->feed(id->data);
		} else {
			string s = utf8_to_string(id->data);
			//werror("Feeding %d bytes of data in utf8.\n", sizeof(s));
			parser->feed(s);
		}

		if (lower_case(id->request_headers["connection"]) != "keep-alive") {
			//werror("data from non keep-alive connection: %O\n", id->request_headers);
		}

		Serialization.Atom a;
		mixed err = catch {
			while (a = parser->parse()) {
				//werror("%O: incoming(%O)\n", this, a);
				call_out(cb, 0, this, a);
			}
		};

		if (err) { // this is reason to disconnect
			werror("%O: Peer sent malformed atom, discarding.\n", this);
			id->answer(500, "bad input");
			parser = Serialization.AtomParser();
			RETURN;
		}

		id->answer(200, "ok");
	} else {
		//werror("%O: New connection from %O.\n", this, id->connection()->query_address());

		// TODO: change internal timeout from 180 s to infinity for Request
		new_id = id;

		if (connection_id) {
			werror("%O: There still is a connection %O.\nclosing first.\n", this, stream);
			// close the current one and then use the new
			closing = 1;
			KEEPDEAD;
			if (!stream->connection) {
				werror("The stream %O is already closed but still hanging around in %O.\n", stream, this);
				werror("That should never happen. Look out for error or close in the log.\nCleaning up manually here.\n");
				stream = 0;
				call_out(register_new_id, 0);
			} else {
				stream->close();
			}
		} else {
			//werror("There is no stream, starting to use the new one.\n");
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

void send(string|Serialization.Atom atom) {
	LOCK;
	KEEPDEAD;
	//werror("%O: send(%O)\n", this, atom);
	if (closing || stream->autoclose) {
		queue->push(atom);	
	} else {
		KEEPALIVE;
		if (stringp(atom)) stream->write(atom);
		else stream->write(atom->render());
	}
	RETURN;
}
