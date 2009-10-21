inherit Serialization.Types.Int;

void create() {
	::create();
	type = "_time";
}

Serialization.Atom encode(mixed o) {
	return ::encode(o->timestamp);
}

mixed decode(Serialization.Atom atom) {
	int timestamp = ::decode(atom);
	return Yakity.Date(timestamp);
}

int(0..1) can_encode(mixed o) {
	return (intp(o) || objectp(o) && object_program(o) == Yakity.Date);
}
