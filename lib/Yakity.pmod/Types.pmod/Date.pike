/*
Copyright (C) 2008-2009  Arne Goedeke
Copyright (C) 2008-2009  Matt Hardy

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
