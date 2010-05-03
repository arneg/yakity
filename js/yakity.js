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
Yakity = {};
/**
 * Holds a Meteor connection and uses it to send and receive Atoms.
 * @constructor
 * @params {String} url Meteor endpoint urls.
 */
Yakity.Client = psyc.Base.extend({
	constructor : function(url, name) {
	    this.base({ 
		msg : UTIL.make_method(this, function(p) {
			this.connection.send(this.packet_signature.encode(p).render());	
		})
	    }, 0);
	    var errorcb = UTIL.make_method(this, function(error) {
		    if (!this.uniform) { // we are not connected yet.
			    if (this.onconnect) this.onconnect(0, error);
		    }

		    if (meteor.debug) meteor.debug(error);
	    });
	    this.connection = new meteor.Connection(url, { nick : name }, UTIL.make_method(this, this.incoming), errorcb);
	    this.connection.init();
	    this.connection.onconnect = UTIL.make_method(this, function(v) {
		this.uniform = mmp.get_uniform(v._uniform);
		if (!this.uniform) {
			throw("no _uniform in initialization mapping from server.");
		}
	    });
	    this.packet_signature = new serialization.Packet(new serialization.Any());
	    this.parser = new serialization.AtomParser();
	    this.name = name;
	},
    	abort : function() {
		if (this.connection) {
		    this.connection.close();
		    delete this.connection;
		}
		if (this.incoming) {
		    delete this.incoming;
		}
	},
	toString : function() {
		return "Yakity.Client("+this.connection.url+")";
	},
	logout : function() {
		if (this.uniform) {
		    // not connected yet.
		    this.connection.set_blocking();
		    this.connection.reconnect = 0;
		    this.sendmsg(this.uniform, "_request_logout");	
		    this.connection.close();
		}
	},
	close : function() {
		this.connection.close();
		delete this.connection;
	},
	_notice_logout : function (m) {
		this.client.reconnect = 0;	
	},
	incoming : function (data) {
		var p, wrapper, i, last_id;
		var source, target;

		meteor.debug(data.length+" bytes of incoming data.");

		if (this.keepalive) {
			window.clearTimeout(this.keepalive);
		}

		wrapper = UTIL.make_method(this, function() {
			this.connection.reconnect_incoming();
		});
		this.keepalive = window.setTimeout(wrapper, 45*1000);

		try {
			data = this.parser.parse(data);
		} catch (error) {
			if (meteor.debug) meteor.debug("failed to parse: "+data+"\nERROR: "+error);
		}

		MESSAGES: for (i = 0; i < data.length; i++) {
			if (data[i].type == "_keepalive") {
				// dont try to decode the keepalive packet
				continue MESSAGES;
			}
			try {
				p = this.packet_signature.decode(data[i]);
			} catch (error) {
				if (meteor.debug) meteor.debug("failed to decode: "+data[i]+"\nERROR: "+error);
				continue;
			}
			if (p instanceof mmp.Packet) {
				if (meteor.debug) meteor.debug("incoming: %o", p);

				var target = p.target();
				var source = p.source();

				if (!p.V("_context")) {
					if (!this.uniform && target != this.uniform) {
						if (meteor.debug) meteor.debug("received message for "+target+", not for us!");
						continue;
					}

					if (!source) {
						if (meteor.debug) meteor.debug("received message without source.\n");
						continue;
					}
				}
				
				this.msg(p);
			}
		}
	}
});
Yakity.linky_text = function(text) {
    //var reg = /(https?|ftp|imap|irc|ldap|nfs|nntp|sips?|telnet|xmpp):\/\/(\w+(:\w+)?@)?[\w\.\-]+(:\d+)?(\/[\w\$\-_.\+!\*'\(\),]+|\/?)?/g;
    var reg = /(https?|ftp|imap|irc|ldap|nfs|nntp|sips?|telnet|xmpp):\/\/([-;:&=\+\$,\w]+@{1})?([-A-Za-z0-9\.]+)+:?(\d+)?((\/[-\+~%\/\.\w]+)?\??([-\+=&;%@\.\w]+)?#?([\w]+)?)?/g;
    var div = document.createElement("div");
    
    var cb = function(result) {
	var a = document.createElement("a");
	a.href = result[0];
	a.target = "_blank";
	a.appendChild(document.createTextNode(result[0]));
	return a;
    };

    var a = UTIL.split_replace(reg, text, cb);

    for (var i = 0; i < a.length; i++) {
	    var t = a[i];
	    if (UTIL.stringp(t)) {
		    if (t.length > 0) div.appendChild(document.createTextNode(t));
	    } else {
		    div.appendChild(t);
	    }
    }

    return div;
};
Yakity.replace_vars = function(p, template, templates) {
	var m = p.data;

	var reg = /\[[\w-]+\]/g;

	var cb = function(result, m) {
		var s = result[0].substr(1, result[0].length-2);
		var a = s.split("-");
		s = a[0];
		var type;
		if (a.length > 1) {
			type = a[1];
		}
		var t;

		if (s == "data") {
			t = Yakity.linky_text(m.data);
		} else if (s == "method") {
			t = m.method;
		} else if (p.V(s) || m.V(s)) {
			var vtml = templates.get(s);
			t = p.V(s) ? p.v(s) : m.v(s);

			if (UTIL.functionp(vtml)) {
				t = vtml.call(window, type, s, t, m);
			} else if (UTIL.objectp(t)) {
				if (UTIL.functionp(t.render)) {
					t = t.render(type);
				} else {
					t = t.toString();
				}
			}
		} else {
			t = "["+s+"]";
		}

		if (UTIL.objectp(t)) {
		    t = t.innerHTML;
		}

		return t;
	};

	var a = UTIL.split_replace(reg, template, cb, m);

	return a.join("");
};
Yakity.funky_text = function(p, templates) {
	var m = p.data;
	var template = templates.get(m.method);

	if (!template) return;

	var reg = /\[[\w-]+\]/g;

	if (UTIL.functionp(template)) {
		var node = template(p, templates);
		node.className = mmp.abbreviations(m.method).join(" ");
		return node;
	}

	var div = document.createElement("div");
	div.className = mmp.abbreviations(m.method).join(" ");
	
	var cb = function(result, m) {
		var s = result[0].substr(1, result[0].length-2);
		var a = s.split("-");
		s = a[0];
		var classes = mmp.abbreviations(s);
		var type;
		if (a.length > 1) {
			type = a[1];
			classes.push(a.join("-"));
			classes.push(type);
		}
		var t;

		if (s == "data") {
			t = Yakity.linky_text(m.data);
		} else if (s == "method") {
			t = m.method;
		} else if (p.V(s) || m.V(s)) {
			var vtml = templates.get(s);
			t = p.V(s) ? p.v(s) : m.v(s);

			if (UTIL.functionp(vtml)) {
				t = vtml.call(window, type, s, t, m);
			} else if (UTIL.objectp(t)) {
				if (UTIL.functionp(t.render)) {
					t = t.render(type);
				} else {
					t = t.toString();
				}
			}
		} else {
			classes = new Array("missing_variable");
			t = "["+s+"]";
		}

		if (UTIL.objectp(t)) {
			for (var i = 0; i < classes.length; i++) {
				UTIL.addClass(t, classes[i]);
			}
		} else {
			var span = document.createElement("span");
			span.className = classes.join(" ");
			span.appendChild(document.createTextNode(t));
			t = span;
		}

		return t;
	};

	var a = UTIL.split_replace(reg, template, cb, m);

	//meteor.debug("inserting "+a.length+" nodes");
	for (var i = 0; i < a.length; i++) {
		var t = a[i];
		if (UTIL.stringp(t)) {
			if (t.length > 0) div.appendChild(document.createTextNode(t));
		} else {
			div.appendChild(t);
		}
	}

	return div;
};
Yakity.Base = Base.extend({
	constructor : function(client) {
		this.plugins = [];
		this.events = new HigherDMapping();
		this.sendmsg = client.sendmsg;
		this.send = client.send;
	},
	msg : function (p, m) {
		var method = m.method;
		var none = 1;

		// same is happening
		for (var t = method; t; t = mmp.abbrev(t)) {
			if (UTIL.functionp(this[t])) {
				none = 0;
				try {
				    if (psyc.STOP == this[t].call(this, p, m)) {
					    return psyc.STOP;
				    }
				} catch (error) {
				    if (meteor.debug) meteor.debug("error when calling "+t+" in "+this+": %o", error);
				}
			}
		}

		if (this.plugins.length) for (var i = 0; i < this.plugins; i++) {
			if (psyc.STOP == this.plugins[i].msg(p, m)) return psyc.STOP;
		}

		if (none && meteor.debug) {
			meteor.debug("No handler for "+method+" in "+this);	
		}

		return psyc.GOON;
	},
	register_plugin : function(o) {
		this.plugins.push(o);
	},
	unregister_plugin : function(o) {
		for (var i = 0; i < this.plugins.length; i++) {
			if (this.plugins[i] == o) {
				this.plugins.splice(i, 1);
				return;
			}
		}
	},
	register_event : function(name, o, fun) {
		return this.events.set(name, [o, fun]);	
	},
	unregister_event : function(id) {
		return this.events.remove(id);
	},
	trigger : function(name) {
		var list = this.events.get(name);
		var arg;
		if (arguments.length > 1) {
		    arg = Array.prototype.slice.call(arguments, 1);
		} else {
		    arg = [];
		}
		
		for (var i = 0; i < list.length; i++) {
			list[i][1].apply(list[i][0], arg);
		}
	}
});
Yakity.ChatWindow = Yakity.Base.extend({
	constructor : function(id) {
		this.base();
		this.mlist = new Array();
		this.mset = new Mapping();
		this.messages = document.createElement("div");
		this.name = id;
	},
	_ : function(p, m) {
		var node = this.renderMessage(p, m);
		if (node) {
		    this.trigger("new_message", this, p, node);
		    this.mset.set(p, this.mlist.length);
		    this.mlist.push(p);
		    this.messages.appendChild(node);
		}
	},
	getMessages : function() {
		return this.mlist.concat();
	},
	render : function(o) {
		if (UTIL.objectp(o) && UTIL.functionp(o.render)) {
			return o.render("dom");
		}

		if (o == undefined || o == null || typeof(o) == "number") {
			return document.createTextNode(new Number(o).toString());
		}

		return document.createTextNode(o.toString());
	},
	getMessageNode : function(p, m) {
		return this.messages.childNodes[this.mset.get(m)];
	},
	getMessagesNode : function() {
		return this.messages;
	}
});
Yakity.TemplatedWindow = Yakity.ChatWindow.extend({
	constructor : function(templates, id) {
		this.base(id);
		if (templates) this.setTemplates(templates);
	},
	setTemplates : function(t) {
		this.templates = t;
	},
	renderMessage : function(p, m) {
		return Yakity.funky_text(p, this.templates);
	}
});
Yakity.RoomWindow = Yakity.TemplatedWindow.extend({
	constructor : function(templates, id) {
		this.base(templates, id);
		this.members = new TypedTable();
		this.members.addColumn("members", "Members");
		this.active = 0;
		this.left = 1;
		var self = this;
		var th = this.members.getHead("members");

		var sort = 1;
		th.onclick = function(event) {
			self.members.sortByColumn("members", (function(a, b) {
				return sort*a._tdata.cmp(b._tdata);
			}));
			sort *= -1;
		};
	},
	_notice_enter : function(p, m) {
		var list = m.v("_members");
		var supplicant = m.v("_supplicant");
		var me = p.target();

		if (supplicant === me) {
			if (this.left) {
				this.left = 0;
				this.trigger("onenter", this);
			} else {
				return psyc.STOP;
			}
		}


		if (list instanceof Array) {
			for (var i = 0; i < list.length; i++) {
				this.addMember(list[i]);
			}
		}

		this.addMember(supplicant);
	},
	_notice_leave : function(p, m) {
		var supplicant = m.v("_supplicant");
		var me = p.target();

		if (supplicant === me) {
			if (!this.left) {
				this.left = 1;
				this.trigger("onleave", this);
			} else {
				return psyc.STOP;
			}
		}

		this.deleteMember(m.v("_supplicant"));
	},
	getMembersNode : function() {
		return this.members.table;
	},
	addMember : function(member) {
		// people could get several notices
		if (!this.members.getRow(member)) {
			this.members.addRow(member);
			var cell = this.members.addCell(member, "members", this.renderMember(member));
			cell._tdata = member;
		}
	},
	renderMember : function(member) {
		return document.createTextNode(member.toString());
	},
	deleteMember : function(member) {
		this.members.deleteRow(member);
	}
});
/**
 * Creates a new tabbed chat application.
 * @param {Object} client Yakity.Client object to use.
 * @param {Object} div DOM div object to put the Chat into.
 * @constructor
 */
Yakity.Chat = Base.extend({
	constructor : function(client) {
		this.windows = new Mapping();
		this.active = null;

		if (client) {
			client.register_method({ method : "_", source : null, object : this });
			this.client = client;
		}
	},
	msg : function(p, m) {
		if (!p.vars.hasIndex("_context") || this.windows.hasIndex(p.source())) {
		    this.getWindow(p.source()).msg(p, m);
		}
		return psyc.STOP;
	},
	getWindow : function(uniform) {
		if (this.windows.hasIndex(uniform)) {
			return this.windows.get(uniform);
		}

		var win = this.createWindow(uniform);
		this.windows.set(uniform, win);
		return win;
	},
	/**
	 * Removes the window win from the chat tab. Use this to close private conversations.
	 * @param {Object} Window object to remove.
	 */
	removeWindow : function(uniform) {
		this.windows.remove(uniform);
	},
	/**
	 * @param {Uniform} uniform
	 * Requests membership in the given room. If the room has been entered successfully a new tab will be opened automatically.
	 */
	enterRoom : function(uniform, history) {
		this.client.sendmsg(uniform, "_request_enter");
		if (history) {
		    this.client.sendmsg(uniform, "_request_history");
		}
	},
	/**
	 * @param {Uniform} uniform
	 * Leaves a room.
	 */
	leaveRoom : function(uniform) {
		this.client.sendmsg(uniform, "_request_leave");
		// close window after _notice_leave is there or after double click on close button
	}
});
Yakity.ProfileData = Yakity.Base.extend({
	constructor : function(client) {
		this.base();
		this.client = client;
		this.cache = new Mapping();
		this.requests = new Mapping();
		this.requestees = new Mapping();
		client.register_method({ method : "_update_profile", source : null, object : this });
		client.register_method({ method : "_notice_login", source : null, object : this });
		client.register_method({ method : "_update_users", source : client.uniform.root(), object : this });
		client.register_method({ method : "_request_profile", source : null, object : this });
	},
	setProfileData : function(m) {
		this.profile = m;
	},
	getDisplayNode : function(uniform) {
		if (this.client.uniform.host != uniform.host) {
			return document.createTextNode(uniform.toString());
		}

		if (this.cache.hasIndex(uniform)) {
			var name = this.cache.get(uniform).get("_name_display");
			if (name) return document.createTextNode(name);
		}

		var node = document.createTextNode(uniform.name);

		var cb = function(profile) {
			var name = profile.get("_name_display");
			node.parentNode.replaceChild(document.createTextNode(name), node);
		};

		var self = this;
		
		var iefuck = function() {
			self.getProfileData(uniform, cb);	
		};
		window.setTimeout(iefuck, 0);
		return node;
	},
	getProfileData : function(uniform, callback) {
		if (this.cache.hasIndex(uniform)) {
			callback(this.cache.get(uniform));
			return;
		}

		if (this.requests.hasIndex(uniform)) {
			this.requests.get(uniform).push(callback);
			return;
		}

		this.requests.set(uniform, (new Array(callback)));
		this.sendmsg(uniform, "_request_profile");
	},
	_update_profile : function(p, m) {
		var source = p.source();
		if (!m.V("_profile")) throw("no profile in _update_profile.\n");
		var profile = m.v("_profile");

		this.cache.set(source, profile);

		if (this.requests.hasIndex(source)) {
			var list = this.requests.get(source);

			for (var i = 0; i < list.length; i++) {
				list[i](profile);
			}
		}

		return psyc.STOP;
	},
	_notice_login : function(p, m) {
		if (m.v("_profile")) {
			this._update_profile(p, m);
		}

		return psyc.GOON;
	},
	_update_users : function(p, m) {
		var source = p.source();
		var list = m.v("_users");

		if (list instanceof Mapping) list.forEach((function(key, value) {
			this.cache.set(key, value);	
		}), this);
		
		return psyc.STOP;
	},
	_request_profile : function(p) {
		var source = p.source();

		if (!this.profile) {
			this.profile = new Mapping();
		}

		this.sendmsg(source, "_update_profile", 0, { _profile : this.profile });
		return psyc.STOP;
	}
});
Yakity.UserList = Yakity.Base.extend({
	constructor : function(client, profiles) {
		this.base();
		this.client = client;
		this.profiles = profiles;
		client.register_method({ method : "_update_users", source : this.client.uniform.root(), object : this });
		client.register_method({ method : "_notice_login", context : this.client.uniform.root(), object : this });
		client.register_method({ method : "_notice_logout", context : this.client.uniform.root(), object : this });
		this.table = new TypedTable();
		this.table.addColumn("users", "Users");
		this.sendmsg(client.uniform.root(), "_request_users");
	},
	_notice_logout : function(p) {
		var source = p.source();
		if (this.table.getRow(source)) {
			this.table.deleteRow(source);
		}

		return psyc.GOON;
	},
	_notice_login : function(p) {
		var source = p.source();
		if (!this.table.getRow(source)) {
			this.table.addRow(source);
			this.table.addCell(source, "users", this.profiles.getDisplayNode(source));
		}

		return psyc.GOON;
	},
	_update_users : function(p, m) {
		var source = p.source();
		var list = m.v("_users");

		if (list instanceof Mapping) list = list.indices();

		for (var i = 0; i < list.length; i++) {
			if (!this.table.getRow(list[i])) {
				this.table.addRow(list[i]);
				this.table.addCell(list[i], "users", this.profiles.getDisplayNode(list[i]));
			}
		}
		
		return psyc.STOP;
	}
});
Yakity.Presence = {};
Yakity.Presence.Typing = Yakity.Base.extend({
	constructor : function(client, chat) {
		this.base();
		this.client = client;
		this.chat = chat;
		this.ids = new Mapping();
	},
	type_event : function() {
		if (!this.chat.active) return;
		var uniform = this.chat.active.name;
		if (!uniform.is_person()) return;
		if (this.ids.hasIndex(uniform)) {
			window.clearTimeout(this.ids.get(uniform));
		} else {
			this.client.sendmsg(uniform, "_notice_presence_typing");
		}
		var self = this;
		var cb = function() {
			self.idle_event(uniform);
		};
		this.ids.set(uniform, window.setTimeout(cb, 2000));
		return true;
	},
	probable_type_event : function() {
	      var _foo = this.chat.input.value;
	      var self = this;
	      var cb = function() {
		  if (_foo != this.chat.input.value) {
		      self.type_event();
		  }
	      };

	      window.setTimeout(cb, 0);

	      return true;
	},
	idle_event : function(uniform) {
		window.clearTimeout(this.inactive_id);
		this.ids.remove(uniform);
		this.client.sendmsg(uniform, "_notice_presence_idle");
		return true;
	}
});
Yakity.InputHistory = Base.extend({
	constructor : function() {
		this.history = [];
		this.pos = -1;
	},
	add : function(s) {
		if (s.length > 0) {
		    this.history.push(s);
		    this.pos = -1;
		}
	},
	get_prev : function(s) {
		if (this.pos != -1) {
			this.pos = this.history.length-1;
		} else {
			if (--this.pos < 0) {
				this.pos = 0;
				return undefined;
			}
		}
		if (s) this.add(s);
		return this.history[this.pos];
	},
	get_next : function() {
		if (this.pos < this.history.length-1) {
		    return this.history[++this.pos];
		} else return undefined;
	}
});
Yakity.HtmlTemplate = function(html) {
	return (function(packet, templates) {
		var div = document.createElement("div");
		div.innerHTML = Yakity.replace_vars(packet, html, templates);
		return div;
	});
};
Yakity.UI = {};
Yakity.UI.TextInput = WIDGET.Base.extend({
	constructor : function(node, buttons) {
		var actions = {};
		this.typing_callout = 0;	
		this.lastinput = "";

		if (buttons.submit) buttons.registerEvent("click", UTIL.make_method(this, function() {
			var t = this.node.value;
			this.node.value = "";
			this.submit(t);
		}));
		actions.keyup = UTIL.make_method(this, function(t, ev) {
			if (this.node.value != this.lastinput) {
				this.lastinput = this.node.value;
				this.typing(ev.keyCode);
			}
		});
		actions.mouseup = UTIL.make_method(this, function(t, ev) {
			if (this.node.value != this.lastinput) {
				this.lastinput = this.node.value;
				this.typing(ev.which);
			}
		});
		this.base(node, {}, actions);
	}, 
	// dummies if not overloaded.
	typing : function(key) { },
	submit : function(text) { }
});
