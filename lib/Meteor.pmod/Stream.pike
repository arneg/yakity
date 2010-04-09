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
#ifdef WRITEV
array out_buffer = ({});
int out_buffer_length = 0;
#else
String.Buffer out_buffer = String.Buffer();
#endif
function close_cb, error_cb;
// we dont want to close before we get the first write
int autoclose = 0;
int autoclose_after_send = 0;
int autoclose_after_write = 0;
int will_send = 0;
Stdio.File connection;

#ifdef ENABLE_THREADS
Thread.Mutex m = Thread.Mutex();
# define LOCK object lock = m->lock();
# define RETURN	do { destruct(lock); return; } while (0)
#ifdef OPTIMISTIC_WRITE
# define UNLOCK destruct(lock);
#endif
#else
# define LOCK
#ifdef OPTIMISTIC_WRITE
# define UNLOCK 
#endif
# define RETURN return;
#endif

// remove all references and callbacks.
#define CLOSE(reason)	do { close_cb(this, reason); connection->set_close_callback(0); connection->set_write_callback(0); \
							 connection = 0;  \
							 close_cb = error_cb = 0; } while(0)
#define ERROR(reason)	do { error_cb(this, reason); connection->set_close_callback(0); connection->set_write_callback(0);\
							 connection = 0;\
							 close_cb = error_cb = 0; } while(0)

void create(Stdio.File connection, function cb, function error, int|void autoclose) {
	this_program::connection = connection;
	this_program::close_cb = cb;
	this_program::error_cb = error;

	// we dont want to close right after the headers have been sent
	if (autoclose) {
	    this_program::autoclose_after_send = autoclose;
	} 

	will_send = 1;
	connection->set_write_callback(_write);
	connection->set_close_callback(_close);
}

#ifdef WRITEV
string encode(string s) {
	return sprintf("%x\r\n%s\r\n", sizeof(s), s);
}

void feed(string ... args) {
    out_buffer += args;
    out_buffer_length += `+(@map(args, sizeof));
}
#endif

void _close() {
	LOCK;
	ERROR(sprintf("Connection closed by peer. %d of data could not be sent.", sizeof(out_buffer)));
	RETURN;
}

void close() {
	LOCK;

#ifdef WRITEV
	feed("0\r\n\r\n");
#else
	out_buffer->add("0\r\n\r\n");
#endif
	connection->set_write_callback(_write);
	autoclose = 1;

	RETURN;	
}

void write(MMP.Utils.Cloak|string data) {
	LOCK;

	if (autoclose) error("stream->write() should not be called in autoclose state as data would be lost.");

#ifdef WRITEV
	feed(stringp(data) ? data : data->get(this_program, encode));
#else
	out_buffer->add(sprintf("%x\r\n%s\r\n", sizeof(data), data));
#endif

	if (!will_send) {
		will_send = 1;
		connection->set_write_callback(_write);
	}

	// we will close this connection after first proper data
	// has been written.
	if (autoclose_after_send) autoclose_after_write = 1;

	RETURN;	
}

void _write() {
	LOCK;

	if (autoclose_after_write && !autoclose) {
	    autoclose = 1;
#ifdef WRITEV
	    feed("0\r\n\r\n");
#else
	    out_buffer->add("0\r\n\r\n");
#endif
	}

#ifdef WRITEV
	int bytes = connection->write(out_buffer);
#else
	string t = out_buffer->get();
	//werror("writing %d bytes to %O", sizeof(out_buffer), connection->query_address());
	int bytes = connection->write(t);
#endif
#ifdef MEASURE_THROUGHPUT
	Meteor.measure(bytes);
#endif
	//werror(" (did %d)\n", bytes);

	// maybe too harsh?
	if (bytes == -1) {
		CLOSE("Could not write to socket. Connection lost.");
		RETURN;
#ifdef WRITEV
	} else if (bytes < out_buffer_length) {
		out_buffer_length -= bytes;

	    	foreach (out_buffer;int i;string t) {
			if (sizeof(t) > bytes) {
			    out_buffer = out_buffer[i..];
			    out_buffer[0] = t[bytes..];
			    break;
			} else if (sizeof(t) == bytes) {
			    out_buffer = out_buffer[i+1..];
			    break;
			} else {
			    bytes -= sizeof(t);
			}
		}
#else
	} else if (bytes < sizeof(t)) {
		out_buffer->add(t[bytes..]);
#endif
	} else {
#ifdef WRITEV
		out_buffer = ({});
		out_buffer_length = 0;
#endif
		connection->set_write_callback(0);

		if (autoclose) {
			connection->set_close_callback(0);
			CLOSE("AutoClose");
		}

		will_send = 0;
	}

	RETURN;	
}

string _sprintf(int type) {
	if (connection) {
		return sprintf("Meteor.Stream(%O)", connection->query_address());
	} else {
		return sprintf("Meteor.Stream(DEAD)");
	}
}
