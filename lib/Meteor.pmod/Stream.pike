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
function close_cb, error_cb;
// we dont want to close before we get the first write
int autoclose = 0;
MMP.Utils.BufferedStream connection;

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
	object o = MMP.Utils.BufferedStream();
	o->assign(connection);
	this_program::connection = o;
	this_program::close_cb = cb;
	this_program::error_cb = error;

	connection->set_close_callback(_close);
}

string encode(string s) {
	return sprintf("%x\r\n%s\r\n", sizeof(s), s);
}

void feed(string ... data) {
	connection->write(@data);
}

void _close() {
	LOCK;
	ERROR(sprintf("Connection closed by peer. %d of data could not be sent.", connection->out_buffer_length));
	RETURN;
}

void close() {
	LOCK;

	autoclose = 1;
	write("0\r\n\r\n");

	RETURN;	
}

void write(MMP.Utils.Cloak|string data) {
	LOCK;

	if (autoclose) {
	    connection->close_when_finished();
	    autoclose = 0;
	}

	connection->write(stringp(data) ? sprintf("%x\r\n%s\r\n", sizeof(data), data) : data->get(this_program, encode));

	// we will close this connection after first proper data
	// has been written.
	RETURN;	
}

string _sprintf(int type) {
	if (connection) {
		return sprintf("Meteor.Stream(%O)", connection->query_address());
	} else {
		return sprintf("Meteor.Stream(DEAD)");
	}
}
