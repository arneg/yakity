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
mapping(MMP.Uniform:object) entities = ([]); //set_weak_flag(([]), Pike.WEAK);
mapping(string:MMP.Uniform) uniform_cache = set_weak_flag(([]), Pike.WEAK_VALUES);
#if constant(Roxen)
Thread.Mutex ucm = Thread.Mutex();
#endif
object type_cache;

void create(void|object type_cache) {
	this_program::type_cache = type_cache || Serialization.TypeCache();
}

MMP.Uniform get_uniform(string s) {
	if (has_index(uniform_cache, s)) {
		return uniform_cache[s];
	}

#if constant(Roxen)
	object lock = ucm->lock();
#endif

	if (has_index(uniform_cache, s)) {
		return uniform_cache[s];
	}

	object u = MMP.Uniform(s);
	uniform_cache[(string)u] = u;
#if constant(Roxen)
	destruct(lock);
#endif
	return u;
}

int lasttime;
float lasthrtime;
int bcastcnt; // immanuel kant

void broadcast(MMP.Packet p) {
	// TODO, this is seriously not good. time to revive
	// some psyc legacy using channels, etc. But for the
	// small scale webchat this is alright.

	foreach (entities;MMP.Uniform target;object o) {
		if ((++bcastcnt%1000) == 0) {
		    int ime;
		    float hrime;

		    ime = time(0);
		    hrime = time(ime);

		    werror("\rbroadcasts: %20d (%f msgs/s)", bcastcnt, 1000/(ime+hrime - (lasttime+lasthrtime)));

		    lasttime = ime;
		    lasthrtime = hrime;
		}

		MMP.Packet t = p->clone();
		t->vars["_target"] = target;
		o->msg(t);
	}
}

void deliver(MMP.Packet p) {
	//werror("deliver(%O)\n", m);
	object o;

	if ((o = entities[p->target()])) {
		o->msg(p);
	} else {
		werror("Could not deliver %O to %O\n", p, p->target());
	}
}

void register_entity(MMP.Uniform u, object o) {
	entities[u] = o;
#if constant(Roxen)
	object lock = ucm->lock();
#endif

	// this is a hack to keep the uniform cache consistent
	if (!has_index(uniform_cache, (string)u)) {
		uniform_cache[(string)u] = u;
	}

#if constant(Roxen)
	destruct(lock);
#endif
}

void unregister_entity(MMP.Uniform u) {
	m_delete(entities, u);
}

object get_entity(MMP.Uniform u) {
	return entities[u];
}
