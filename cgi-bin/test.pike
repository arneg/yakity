object my_server;


void create(object my_server) {
    this_program::my_server = my_server;
}

void parse(object r) {
    int cnt = (int)r->variables->cnt;

    r->response_and_finish(([ "error" : 200,
			      "type" : "text/html",
			      "data" : replace(Stdio.read_file("htdocs/wuh.html"), "FOOOO", sprintf("<h1>%d:%d</h1><a href=\"test.pike?cnt=%d\">back</a> - <a href=\"?cnt=%d\">forth</a>", cnt, gethrtime(), cnt-1, cnt+1)) ]));
}
