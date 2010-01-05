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
String.Buffer out_buffer = String.Buffer();
function close_cb, error_cb;
// we dont want to close before we get the first write
int autoclose;
int autoclose_after_send; 
int will_send = 1;
Stdio.File connection;

#ifdef ENABLE_THREADS
Thread.Mutex m = Thread.Mutex();
# define LOCK object lock = m->lock();
# define RETURN	do { destruct(lock); return; } while (0)
#ifndef PESSIMISTIC_WRITE
# define UNLOCK destruct(lock);
#endif
#else
# define LOCK
#ifndef PESSIMISTIC_WRITE
# define UNLOCK 
#endif
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
	ERROR(sprintf("Connection closed by peer. %d of data could not be sent.", sizeof(out_buffer)));
	RETURN;
}

void close() {
	LOCK;

	out_buffer->add("0\r\n\r\n");
	connection->set_write_callback(_write);
	autoclose = 1;

	RETURN;	
}

void write(string data) {
	LOCK;

	if (autoclose_after_send) autoclose = 1;

	out_buffer->add(sprintf("%x\r\n%s\r\n", sizeof(data), data));

#ifndef PESSIMISTIC_WRITE
	UNLOCK;	
	if (!will_send) _write();
#else
	if (!will_send) {
		will_send = 1;
		connection->set_write_callback(_write);
	}

	RETURN;	
#endif
}

void _write() {
	LOCK;

	string t = out_buffer->get();
	//werror("writing %d bytes to %O", sizeof(out_buffer), connection->query_address());
	int bytes = connection->write(t);
	//werror(" (did %d)\n", bytes);

	// maybe too harsh?
	if (bytes == -1) {
		CLOSE("Could not write to socket. Connection lost.");
		RETURN;
	} else if (bytes < sizeof(t)) {
		out_buffer->add(t[bytes..]);
#ifndef PESSIMISTIC_WRITE

		if (!will_send) {
			will_send = 1;
			connection->set_write_callback(_write);
		}
#endif
	} else {

		if (autoclose) {
			CLOSE("AutoClose");
		} else {
			connection->set_write_callback(0);
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
