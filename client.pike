void log(mapping m) {
	werror("%O\n", m);
}

string data(string d) {
	werror("Incoming: %s\n", d);
}

int main() {
	object cs = Meteor.ClientSession("http://127.0.0.4:8080/meteor/", log, ([
		"nick" : "test",
	]));
	cs->read_cb = data;
	return -1;
}
