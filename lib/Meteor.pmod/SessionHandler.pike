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
mapping(string:object) sessions = set_weak_flag(([]), Pike.WEAK);
#if constant(Roxen)
Thread.Mutex sessions_mutex = Thread.Mutex();
#endif

string get_new_id() {
	return MIME.encode_base64(random_string(10));
}

object get_new_session() {
	string s;
#if constant(Roxen)
	object lock = sessions_mutex->lock();
#endif

	while (has_index(sessions, s = get_new_id()));
	sessions[s] = Meteor.Session(s);
	
#if constant(Roxen)
	destruct(lock);
#endif
	return sessions[s];
}

MMP.Uniform user_to_uniform(string name) {
	return to_uniform('~', name);
}

MMP.Uniform room_to_uniform(string name) {
	return to_uniform('@', name);
}


MMP.Uniform to_uniform(int type, string name);
