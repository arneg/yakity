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
/**
 * Set this to a mapping of templates that should be used automatically when displaying messages inside Chat tabs. PSYC method inheritance is used when accessing the templates. Hence a template for "_message" will also be used for "_message_public" if there is no template for it. Therefore setting a template for "_" effectively sets a default template for all methods.
 * @type mmp#Vars
 * @name psyc.templates
 * @field
 * @example
 * psyc.templates = new Vars("_message_public", 
 * "[_source_relay] says in [_source]: [data]", 
 * "_", "[_source] sends [method]: [data]");
 */
psyc = {
	STOP : 1,
	GOON : 0	
};
Yakity = {};
/**
 * PSYC message class.
 * @constructor
 * @param {String} method PSYC method
 * @param {mmp#Vars} vars variables
 * @param {String} data Payload
 * @property {String} method PSYC method
 * @property {mmp#Vars} vars variables
 * @property {String} data Payload
 */
Yakity.Message = new Class({
	Extends : mmp.Packet,
	initialize : function(method, data, vars) {
		this.method = method;
		this.parent(data, vars);
		// TODO: this is a hack
		this.vars.remove("_timestamp");
	},
	toString : function() {
		var ret = "Yakity.Message("+this.method+", ([ ";
		ret += this.vars.toString();
		ret += "]))";
		return ret;
	},
	isMethod : function(method) {
		return this.method.indexOf(method) == 0;
	}
});
Yakity.default_polymorphic = function() {
	var pol = new serialization.Polymorphic();
	var method = new serialization.Method();
	// integer and string come first because they should not get overwritten by 
	// method and float
	pol.register_type("_string", "string", new serialization.String());
	pol.register_type("_integer", "number", new serialization.Integer());
	pol.register_type("_float", "float", new serialization.Float());
	pol.register_type("_method", "string", method);
	//pol.register_type("_message", Yakity.Message, new serialization.Message(method, pol, pol));
	pol.register_type("_mapping", Yakity.Mapping, new serialization.Mapping(pol, pol));
	pol.register_type("_list", Array, new serialization.Array(pol));
	pol.register_type("_time", mmp.Date, new serialization.Date());
	pol.register_type("_uniform", mmp.Uniform, new serialization.Uniform());
	return pol;
}
/**
 * Holds a Meteor connection and uses it to send and receive Atoms.
 * @constructor
 * @params {String} url Meteor endpoint urls.
 */
Yakity.Client = function(url, name) {
	this.callbacks = new Mapping();
	var self = this;
	var errorcb = function(error) {
		if (!self.uniform) { // we are not connected yet.
			if (self.onconnect) self.onconnect(0, error);
		}

		if (meteor.debug) meteor.debug(error);
	};
	this.connection = new meteor.Connection(url, { nick : name }, UTIL.make_method(this, this.incoming), errorcb);
	this.connection.init();
	var method = new serialization.Method();
	var poly = Yakity.default_polymorphic();
	this.msig = new serialization.Message(method, new serialization.OneTypedVars(poly), poly);
	this.psig = new serialization.Packet(this.msig);
	this.parser = new serialization.AtomParser();
	this.icount = 0;
	this.name = name;
};
// params = ( method : "_message", source : Uniform }
Yakity.Client.prototype = {
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
	/**
	 * Register for certain incoming messages. This can be used to implement chat tabs or handlers for certain message types.
	 * @params {Object} params Object containing the properties "method", "callback" and optionally "source". For all incoming messages matching "method" and "source" the callback is called. The "source" property should be of type mmp.Uniform.
	 * @returns A wrapper object of type meteor.CallbackWrapper. It can be used to unregister the handler.
	 */
	register_method : function(params) {
		var wrapper = new meteor.CallbackWrapper(params, this.callbacks);
		
		if (this.callbacks.hasIndex(params.method)) {
			var list = this.callbacks.get(params.method);
			list.push(wrapper);
		} else {
			this.callbacks.set(params.method, new Array( wrapper ) );
		}

		return wrapper;
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
 	sendmsg : function(target, method, data, vars) {
		var m = new Yakity.Message(method, data, vars);
		var p = new mmp.Packet(m, { _target : target, _source : this.uniform });
		this.send(p);
	},
	/**
	 * Send a packet. This should be of type Yakity.Message.
	 * @params {Object} packet Message to send.
	 */
	send : function(p) {
		if (!p.V("_target")) throw("Message without _target is baaad!");
		if (!p.V("_source")) p.source(this.uniform);

		try {
			this.connection.send(this.psig.encode(p).render());
		} catch (error) {
			if (meteor.debug) {
				if (UTIL.objectp(error)) {
					var str = "";
					for (var i in error) {
						str += i+" "+error[i]+"\n";
					}
					meteor.debug("send() failed: "+str);
				} else meteor.debug("send() failed: "+error);
			}
			return;
		}
	},
	/**
	 * Request all messages up to id count from the PSYC user. This is done automatically if missing messages are detected during handshake with the user.
	 * @params {Integer} count Message to send.
	 */
	sync : function(count) {
		var list = new Array(count - this.icount);
		for (var i = 0; this.icount+i+1 <= count; i++) {
			list[i] = this.icount+i+1;
		}
		this.sendmsg(this.uniform, "_request_history", 0, { _messages : list });
	},
	_notice_logout : function (m) {
		this.client.reconnect = 0;	
	},
	incoming : function (data) {
		var self, method, count, p, m, wrapper, i, last_id;
		var source, target, context;

		meteor.debug(data.length+" bytes of incoming data.");

		if (this.keepalive) {
			window.clearTimeout(this.keepalive);
		}
		self = this;
		wrapper = function() {
			self.connection.reconnect_incoming();
		};
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
				p = this.psig.decode(data[i]);
			} catch (error) {
				if (meteor.debug) meteor.debug("failed to decode: "+data[i]+"\nERROR: "+error);
				continue;
			}
			if (p instanceof mmp.Packet && (m = p.data) instanceof Yakity.Message) {
				method = m.method;
				if (meteor.debug) meteor.debug("incoming: %o", p);
				count = p.v("_id");	
				target = p.target();
				source = p.source();
				context = p.v("_context");

				if (method == "_status_circuit") {
					last_id = m.v("_last_id");
					this.uniform = source;

					if (UTIL.intp(last_id) && this.icount < last_id) {
						this.sync(last_id);
						this.icount = count;
					}
					if (this.onconnect) {
						this.onconnect(1, this);
					}
				} else if (!context) {
					if (target != this.uniform) {
						if (meteor.debug) meteor.debug("received message for "+target+", not for us!");
						continue;
					} else if (!source) {
						if (meteor.debug) meteor.debug("received message without source.\n");
						continue;
					}
				}
				
				if (UTIL.intp(count)) {
					if (this.icount+1 < count) {
						// request all up to count-1
						this.sync(count-1);

					} else if (this.icount == count - 1) {
						this.icount = count;
					}
				}

				var none = 1;

				for (var t = method; t; t = mmp.abbrev(t)) {
					if (this.hasOwnProperty(t) && UTIL.functionp(this[t])) {
						this[t].call(this, m);
					}
					if (!this.callbacks.hasIndex(t)) continue;

					none = 0;
					var list = this.callbacks.get(t);
					var stop = 0;

					for (var j = 0; j < list.length; j++) {
						try {
							if (psyc.STOP == list[j].msg(p, m)) {
								stop = 1;
							}
						} catch (error) {
							if (meteor.debug) meteor.debug(error);
						}
					}

					// we do this to stop only after all callbacks on the same level have been handled.
					if (stop) {
						continue MESSAGES;
					}
				}

				if (meteor.debug && none) meteor.debug("No callback registered for "+method);
			} else {
				if (meteor.debug) meteor.debug("Got non _message atom from "+connection.toString());
			}
		}
	}
};
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
Yakity.Base = new Class({
	initialize : function() {
		this.plugins = [];
		this.events = new HigherDMapping();
	},
	msg : function (p, m) {
		var method = m.method;
		var none = 1;

		if (method.search("_") != 0) {
			if (meteor.debug) meteor.debug("Bad method "+method);
			return psyc.STOP;
		}

		for (var t = method; t; t = mmp.abbrev(t)) {
			if (UTIL.functionp(this[t])) {
				none = 0;
				if (psyc.STOP == this[t].call(this, p, m)) {
					return psyc.STOP;
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
	sendmsg : function(target, method, data, vars) {
		this.client.sendmsg(target, method, data, vars);
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
Yakity.ChatWindow = new Class({
	Extends : Yakity.Base,
	initialize : function(id) {
		this.parent();
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
Yakity.TemplatedWindow = new Class({
	Extends : Yakity.ChatWindow,
	initialize : function(templates, id) {
		this.parent(id);
		if (templates) this.setTemplates(templates);
	},
	setTemplates : function(t) {
		this.templates = t;
	},
	renderMessage : function(p, m) {
		return Yakity.funky_text(p, this.templates);
	}
});
Yakity.RoomWindow = new Class({
	Extends : Yakity.TemplatedWindow,
	initialize : function(templates, id) {
		this.parent(templates, id);
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
Yakity.Chat = new Class({
	initialize : function(client) {
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
Yakity.ProfileData = new Class({
	Extends : Yakity.Base,
	initialize : function(client) {
		this.parent();
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
Yakity.UserList = new Class({
	Extends : Yakity.Base,
	initialize : function(client, profiles) {
		this.parent();
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
Yakity.Presence.Typing = new Class({
	Extends : Yakity.Base,
	initialize : function(client, chat) {
		this.parent();
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
Yakity.InputHistory = new Class({
	initialize : function() {
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
