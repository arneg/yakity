string url;
string id;
Protocols.HTTP.Session session;
string buffer = "";
object stream_request;
object out_request;
function log, read_cb;
int length;
string inbuf = "";
mapping get_variables;
object request;

void get_fail(object request, object info) {
	log(([
		 "component" : "session",
		 "method" : "init_session",
		 "result" : "FAIL",
		 "start" : info->start,
		 "stop" : gethrtime(),
		 ]));
}
void get_ok(object request, object info) {
	log(([
		 "component" : "session",
		 "method" : "init_session",
		 "result" : "OK",
		 "start" : info->start,
		 "stop" : gethrtime(),
		 ]));
	id = request->data();
	connect_stream();
}

void create(string url, function log, mapping initial_vars) {
	session = Protocols.HTTP.Session();
	this_program::log = log;
	this_program::url = url;

	session->async_get_url(Standards.URI(url), initial_vars, 0, get_ok, get_fail, send_info(gethrtime()));
}

class send_info(int start, void|int bytes) {

}

void stream_fail_cb(object request, object info) {
	request->set_callbacks(0,0,0);
	log(([
		 "component" : "session",
		 "method" : "connect_stream",
		 "result" : "FAIL",
		 "start" : info->start,
		 "stop" : gethrtime(),
		 ]));
	// try again
	request->con->con->set_read_callback(0);
	length = 0;
	inbuf = 0;
	connect_stream();
}


void stream_data_cb(mixed id, string data) {
	request->con->buf += data;
	inbuf += data;	

	if (length) {
		if (sizeof(inbuf) >= length + 2) {
			read_cb(inbuf[0..(length-1)]);
			inbuf = inbuf[length+2..];

			length = 0;
			if (sizeof(inbuf)) call_out(stream_data_cb, 0, 0, "");
		}
	
		return;
	}

	if (3 == sscanf(inbuf, "%x%*[ ]\r\n%s", length, inbuf)) {
		if (length == 0) {
			werror("got zero length. stream is over.\n");
			request->con->con->set_read_callback(0);
			request->con->request_ok(request->con, @request->con->extra_args);
			connect_stream();
			return;
		}

		call_out(stream_data_cb, 0, 0, "");
		return;
	}

	werror("no length in '%s'\n", inbuf);
}

void stream_headers_ok(object request, object info) {
	log(([
		 "component" : "session",
		 "method" : "connect_stream",
		 "result" : "OK",
		 "start" : info->start,
		 "stop" : gethrtime(),
		 ]));
	this_program::request = request;
	request->con->con->set_read_callback(stream_data_cb);
	inbuf = request->con->buf[request->con->datapos..];
	stream_data_cb(0, "");
}


void connect_stream() {
	stream_request = session->async_do_method_url("POST", url, ([ "id" : id]), "", 
									 ([ "Content-type" : "application/octet-stream",
									  	"user-agent" : "Agent Orange" ]), 
									 stream_headers_ok, 0, stream_fail_cb, 
									 ({ send_info(gethrtime())}));
}

void set_read_callback(function f) {
	read_cb = f;
}

void set_close_callback() {
}

void send(string data) {
	buffer += data;

	if (-1 == find_call_out(_write)) {
		call_out(_write, 0);
	}
}

void dummy(mixed ... args) {}

void out_ok_cb(object request, object info) {
	string data = request->con->data();

	if (data == "ok") {
		log(([
			 "component" : "session",
			 "method" : "send",
			 "result" : "OK",
			 "start" : info->start,
			 "stop" : gethrtime(),
			 "bytes" : info->bytes,
			 ]));
	} else {
		log(([
			 "component" : "session",
			 "method" : "send",
			 "result" : "BAD_RESPONSE",
			 "start" : info->start,
			 "stop" : gethrtime(),
			 "bytes" : info->bytes,
			 ]));
	}
}

void out_fail_cb(object request, object info) {
	log(([
		 "component" : "session",
		 "method" : "send",
		 "result" : "FAIL",
		 "start" : info->start,
		 "stop" : gethrtime(),
		 "bytes" : info->bytes,
		 ]));
}

void _write() {

	if (sizeof(buffer)) {
		session->async_do_method_url("POST", url, ([ "id" : id]), buffer, 
									 ([ "Content-type" : "application/octet-stream" ]), 
									 dummy, out_ok_cb, out_fail_cb, 
									 ({ send_info(gethrtime(), sizeof(buffer)) }));
		buffer = "";
	}
}

