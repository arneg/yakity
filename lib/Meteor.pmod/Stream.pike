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
string|String.Buffer out_buffer, buffer;
int write_ready = 0;
function close_cb, error_cb;
// we dont want to close before we get the first write
int autoclose;
int autoclose_after_send; 
mixed wid;
Stdio.File connection;

#if contant(Roxen)
Thread.Mutex m = Thread.Mutex();
# define LOCK object lock = m->lock();
#else
# define LOCK
#endif
#if constant(Roxen)
# define RETURN	do { destruct(lock); return; } while (0)
#else
# define RETURN return;
#endif
// remove all references and callbacks.
#define CLOSE(reason)	do { call_out(close_cb, 0, this, reason); connection->set_close_callback(0); connection->set_write_callback(0); \
							 connection = 0;  \
							 close_cb = error_cb = 0; } while(0)
#define ERROR(reason)	do { call_out(error_cb, 0, this, reason); connection->set_close_callback(0); connection->set_write_callback(0);\
							 connection = 0;\
							 close_cb = error_cb = 0; } while(0)

void create(Stdio.File connection, function cb, function error, int|void autoclose) {
	this_program::connection = connection;
	this_program::close_cb = cb;
	this_program::error_cb = error;
	// we dont want to close right after the headers have been sent
	if (autoclose) this_program::autoclose_after_send = autoclose;
	connection->set_write_callback(_write);
	connection->set_close_callback(_close);
}

void _close() {
	LOCK;
	if (buffer || out_buffer) {
		ERROR(sprintf("Connection closed by peer. %d of data could not be sent.", sizeof(out_buffer) + stringp(buffer) ? sizeof(buffer) : 0));
	} else {
		CLOSE("Connection closed by peer, but probably no data has been lost.");
	}
	RETURN;
}

void close() {
	LOCK;
	autoclose = 1;

	if (!buffer && !sizeof(out_buffer)) {
		close_now();
	}

	RETURN;	
}

void write(string data) {
	LOCK;

	if (autoclose_after_send) autoclose = 1;

	if (buffer) {
		if (objectp(buffer)) buffer += data;
		else {
			String.Buffer t = String.Buffer(sizeof(buffer) + sizeof(data));
			t->add(buffer, data);
			buffer = t;
		}
	} else buffer = data;

	if (write_ready && !wid) wid = call_out(_write, 0);

	RETURN;	
}

void _write() {
	LOCK;
	wid = 0;

	if (buffer) {
		if (out_buffer) {
			if (objectp(buffer)) buffer = buffer->get();
			if (objectp(out_buffer)) out_buffer += sprintf("%x\r\n%s\r\n", sizeof(buffer), (string)buffer);
			else {
				String.Buffer t = String.Buffer(sizeof(out_buffer)*2);
				t->add(out_buffer, sprintf("%x\r\n%s\r\n", sizeof(buffer), (string)buffer));
				out_buffer = t;
			}
		} else out_buffer = sprintf("%x\r\n%s\r\n", sizeof(buffer), (string)buffer);
		buffer = 0;
	} else if (!out_buffer) {
		write_ready = 1;
		RETURN;
	}

	//werror("writing %d bytes to %O", sizeof(out_buffer), connection->query_address());
	int bytes = connection->write(out_buffer = (string)out_buffer);
	//werror(" (did %d)\n", bytes);

	// maybe too harsh?
	if (bytes == -1) {
		CLOSE("Could not write to socket. Connection lost.");
		RETURN;
	} else if (bytes < sizeof(out_buffer)) {
		out_buffer = ([string]out_buffer)[bytes..];
	} else {
		out_buffer = 0;

		if (autoclose) {
			close_now();
		}
	}

	write_ready = 0;
	RETURN;	
}

void close_now() {
	if (5 != connection->write("0\r\n\r\n")) {
		ERROR(sprintf("Could not write the the closing 5 bytes to %O\n", connection->query_address()));
	} else {
		// we actually have to close it, if this is not a keepalive connection
		CLOSE("AutoClose");
	}
}

string _sprintf(int type) {
	if (connection) {
		return sprintf("Meteor.Stream(%O)", connection->query_address());
	} else {
		return sprintf("Meteor.Stream(DEAD)");
	}
}
