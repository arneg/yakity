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
inherit Yakity.Base;

mixed rooms, users;

void create(object server, MMP.Uniform uniform) {
	::create(server, uniform);
}

int _request_users(MMP.Packet p) {
	MMP.Uniform source = p->source();

	if (users) {
		mapping profiles;

		// possible race here!
#if 0
		profiles = ([ ]);

		foreach (users; MMP.Uniform uniform; object o) {
			profiles[uniform] = o->get_profile();
		}
#else
		profiles = map(users, lambda(object o) {
				  return o->get_profile();
				  });
#endif

		sendmsg(source, "_update_users", 0,  ([ "_users" : profiles ]));
	}

	return Yakity.STOP;
}

