inherit Meteor.Stream;

void write(string data) {
	::write(string_to_utf8(data));
}
