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
#ifdef TRACE_SOFT_MEMLEAKS
inherit MMP.Utils.Screamer;
#endif
Serialization.Atom|mapping(string:mixed) vars;
Serialization.Atom|string method, data;

void create(void|string method, string|void data, void|mapping vars) {
	this_program::method = method;
	this_program::data = data;
	this_program::vars = vars;
}

this_program clone() {
	this_program o = this_program();
	o->vars = copy_value(vars);
	o->method = method;
	o->data = copy_value(data);

	return o;
}

string _sprintf(int type) {
	return sprintf("Message(%s)", method||"");
}
