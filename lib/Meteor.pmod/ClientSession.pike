mixed url;
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
	if (request->con->status == 200) {
		log(([
			 "component" : "session",
			 "method" : "init_session",
			 "result" : "OK",
			 "start" : info->start,
			 "stop" : gethrtime(),
			 ]));
		id = request->data();
		connect_stream();

		if (sizeof(buffer)) _write();
	} else {
		get_fail(request, info);
	}
}

void create(string url, function log, mapping initial_vars) {
	session = Protocols.HTTP.Session();
	session->maximum_total_connections = 2;
	session->time_to_keep_unused_connections = 60*60;
	this_program::log = log;
	this_program::url = Standards.URI(url);

	session->async_get_url(this_program::url, initial_vars, 0, get_ok, get_fail, send_info(gethrtime()));
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
	if (request->con->con) request->con->con->set_read_callback(0);
	length = 0;
	inbuf = 0;
	call_out(connect_stream, 5);
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

	string t;

	if (3 == sscanf(inbuf, "%x%*[ ]\r\n%s", length, t)) {
		inbuf = t;
		if (length == 0) {
			werror("got zero length. stream is over.\n");
			request->con->con->set_read_callback(0);
			request->con->request_ok(request->con, @request->con->extra_args);
			connect_stream();
			return;
		}

		call_out(stream_data_cb, 0, 0, "");
		return;
	} else {
		length = 0;
	}

	//werror("no length in '%s'\n", inbuf);
}

void stream_headers_ok(object request, object info) {
	if (request->con->status != 200) {
		log(([
			 "component" : "session",
			 "method" : "connect_stream",
			 "result" : "FAIL",
			 "start" : info->start,
			 "stop" : gethrtime(),
			 ]));
	} else {
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
		if (sizeof(inbuf)) stream_data_cb(0, "");
	}
}


void connect_stream() {
	stream_request = async_do_method_url("POST", url, ([ "id" : id]), "", 
									 ([ "content-type" : "application/octet-stream",
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

object async_do_method_url(string method, object url, void|mapping query_variables, 
						 void|string data, void|mapping extra_headers, 
						 function callback_headers_ok, function callback_data_ok, 
						 function callback_fail, array callback_arguments) {
	object p = session->Request();
	p->set_callbacks(callback_headers_ok, callback_data_ok, callback_fail, p, @callback_arguments);
	p->do_async(p->prepare_method(method,url,query_variables,extra_headers,data));
	return p;
}

void _write() {

	if (sizeof(buffer) && id) {
		async_do_method_url("POST", url, ([ "id" : id]), buffer, 
									 ([ "content-type" : "application/octet-stream" ]), 
									 dummy, out_ok_cb, out_fail_cb, 
									 ({ send_info(gethrtime(), sizeof(buffer)) }));
		buffer = "";
	}
}

