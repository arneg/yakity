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
inherit PSYC.Base;

inherit MMP.Plugins.ChannelRouter;

mixed rooms, users;

void create(object server, MMP.Uniform uniform) {
	::create(server, uniform);
}

int _request_users(MMP.Packet p, PSYC.Message m, function callback) {
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

		sendreplymsg(p, "_update_users", 0,  ([ "_users" : profiles ]));
	}

	return PSYC.STOP;
}

void add_user(MMP.Uniform u, object o) {
    PSYC.Message m = PSYC.Message("_notice_login", 0, ([ "_user" : u ]));

    mcast(m);

    get_channel(uniform)->add_route(u, o);
    users[u] = o;
}

void delete_user(MMP.Uniform u) {
    object o = m_delete(users, u);

    get_channel(uniform)->remove_route(u, o);

    if (!o) return;
    PSYC.Message m = PSYC.Message("_notice_logout", 0, ([ "_user" : u ]));

    mcast(m);
}
