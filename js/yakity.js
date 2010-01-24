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
 * @returns true if given value is an integer number.
 */
intp = function(i) { return (typeof(i) == "number" && i%1 == 0); };
/**
 * @returns true if given value is array.
 */
arrayp = function(a) { return (typeof(a) == "object" && a instanceof Array); };

stringp = function(s) { return typeof(s) == "string"; };
functionp = function(f) { return (typeof(f) == "function" || f instanceof Function); };
objectp = function(o) { return typeof(o) == "object"; }
/**
 * Set this to a mapping of templates that should be used automatically when displaying messages inside Chat tabs. PSYC method inheritance is used when accessing the templates. Hence a template for "_message" will also be used for "_message_public" if there is no template for it. Therefore setting a template for "_" effectively sets a default template for all methods.
 * @type psyc#Vars
 * @name psyc.templates
 * @field
 * @example
 * psyc.templates = new Vars("_message_public", 
 * "[_source_relay] says in [_source]: [data]", 
 * "_", "[_source] sends [method]: [data]");
 */
/**
 * @namespace PSYC namespace.
 */
psyc = {};
yakity = {};
psyc.STOP = 1; 
psyc.find_abbrev = function(obj, key) {
    var t = key;

    while (t.length && obj[t] == undefined) {
	var i = t.lastIndexOf("_");

	if (i == -1) {
	    return undefined;
	} else {
	    t = t.substr(0, i);
	}
    }

    return obj[t];
};
/**
 * PSYC message class.
 * @constructor
 * @param {String} method PSYC method
 * @param {psyc#Vars} vars variables
 * @param {String} data Payload
 * @property {String} method PSYC method
 * @property {psyc#Vars} vars variables
 * @property {String} data Payload
 */
yakity.Message = mmp.Packet.extend({
	constructor : function(method, data, vars) {
		this.method = method;
		this.base(data, vars);
	},
	toString : function() {
		var ret = "yakity.Message("+this.method+", ([ ";
		ret += this.vars.toString();
		ret += "]))";
		return ret;
	}
});
/**
 * Does a one-step abbreviation of a psyc method. For instance, _message_public turns into _message. Returns 0 if no further abbreviation is possible.
 * @param {String} method PSYC method
 */
psyc.abbrev = function(method) {
	var i = method.lastIndexOf("_");
	if (i == -1) {
		return 0;
	} else if (i == 0) {
		if (method.length == 1) return 0;
		return "_";
	} else {
		return method.substr(0, i);
	}
}
psyc.abbreviations = function(method) {
	var ret = new Array();
	do { ret.push(method); } while( (method = psyc.abbrev(method)) );

	return ret;
}
/**
 * Generic PSYC Variable class. This should be used to represent PSYC message variables. 
 * @constructor
 * @augments Mapping
 */
psyc.Vars = function() {
	this.get = function(key) {
		do {
			if (this.hasIndex(key)) {
				return psyc.Vars.prototype.get.call(this, key);
			}
		} while (key = psyc.abbrev(key));

		return undefined;
	};

	Mapping.call(this);

	if (arguments.length == 1) {
		var vars = arguments[0];

		for (var i in vars) {
			if (vars.hasOwnProperty(i)) {
				this.set(i, vars[i]);
			}
		}
	} else if (arguments.length & 1) {
		throw("odd number of mapping members.");
	} else for (var i = 0; i < arguments.length; i += 2) {
        this.set(arguments[i], arguments[i+1]);
    }
};
psyc.Vars.prototype = new Mapping();
psyc.Vars.prototype.constructor = psyc.Vars;
/**
 * Returns the value associated with key or an abbreviation of key.
 * @param {String} key PSYC variable name.
 */
// not being able to use inheritance here stinks like fish.
yakity.Date = function(timestamp) {
	this.date = new Date();
	this.date.setTime(timestamp * 1000);
	this.render = function(type) {
		var fill = function(n, length) {
			var ret = n.toString();
			for (var i = length - ret.length; i > 0; i--) {
				ret = "0"+ret;	
			}

			return ret;
		}
		switch (type) {
		case "_month": return this.date.getMonth();
		case "_month_utc": return this.date.getUTCMonth();
		case "_weekday": return this.date.getDay();
		case "_monthday": return this.date.getDate();
		case "_monthday_utc": return this.date.getUTCDate();
		case "_minutes": return fill(this.date.getMinutes(), 2);
		case "_minutes_utc": return fill(this.date.getUTCMinutes(), 2);
		case "_seconds": return fill(this.date.getSeconds(), 2);
		case "_seconds_utc": return fill(this.date.getUTCSeconds(), 2);
		case "_timezone_offset": return this.date.getTimezoneOffset();
		case "_year": return fill(this.date.getFullYear(), 4);
		case "_year_utc": return fill(this.date.getUTCFullYear(), 4);
		case "_hours": return this.date.getHours();
		case "_hours_utc": return this.date.getUTCHours();
		}
		return this.date.toLocaleString();
	};
	this.toString = function() {
		return this.date.toLocaleString();
	};
};
yakity.default_polymorphic = function() {
	var pol = new serialization.Polymorphic();
	var method = new serialization.Method();
	// integer and string come first because they should not get overwritten by 
	// method and float
	pol.register_type("_string", "string", new serialization.String());
	pol.register_type("_integer", "number", new serialization.Integer());
	pol.register_type("_float", "float", new serialization.Float());
	pol.register_type("_method", "string", method);
	//pol.register_type("_message", yakity.Message, new serialization.Message(method, pol, pol));
	pol.register_type("_mapping", yakity.Mapping, new serialization.Mapping(pol, pol));
	pol.register_type("_list", Array, new serialization.Array(pol));
	pol.register_type("_time", yakity.Date, new serialization.Date());
	pol.register_type("_uniform", mmp.Uniform, new serialization.Uniform());
	return pol;
}
/**
 * Holds a Meteor connection and uses it to send and receive Atoms.
 * @constructor
 * @params {String} url Meteor endpoint urls.
 */
yakity.Client = function(url, name) {
	this.callbacks = new Mapping();
	var self = this;
	var errorcb = function(error) {
		if (!self.uniform) { // we are not connected yet.
			if (self.onconnect) self.onconnect(0, error);
		}

		if (meteor.debug) meteor.debug(error);
	};
	this.connection = new meteor.Connection(url+"?nick="+escape(name).replace(/\+/g, "%2B"), this.incoming, errorcb);
	this.connection.init();
	var method = new serialization.Method();
	var poly = yakity.default_polymorphic();
	this.msig = new serialization.Message(method, new serialization.OneTypedVars(poly), poly);
	this.psig = new serialization.Packet(this.msig);
	this.parser = new serialization.AtomParser();
	this.incoming.obj = this;
	this.icount = 0;
	this.name = name;
};
// params = ( method : "_message", source : Uniform }
yakity.Client.prototype = {
	toString : function() {
		return "yakity.Client("+this.connection.url+")";
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
	close : function () {
		this.connection.close();
		delete this.connection;
	},
 	sendmsg : function(target, method, data, vars) {
		var m = new yakity.Message(method, data, vars);
		var p = new mmp.Packet(m, { _target : target, _source : this.uniform });
		this.send(p);
	},
	/**
	 * Send a packet. This should be of type yakity.Message.
	 * @params {Object} packet Message to send.
	 */
	send : function(p) {
		if (!p.V("_target")) throw("Message without _target is baaad!");
		if (!p.V("_source")) p.source(this.uniform);

		try {
			this.connection.send(this.psig.encode(p).render());
		} catch (error) {
			if (meteor.debug) {
				if (typeof(error) == "object") {
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
			if (p instanceof mmp.Packet && (m = p.data) instanceof yakity.Message) {
				method = m.method;
				if (meteor.debug) meteor.debug("incoming: " + method);
				count = p.v("_id");	
				target = p.target();
				source = p.source();
				context = p.v("_context");

				if (method == "_status_circuit") {
					last_id = m.v("_last_id");
					this.uniform = source;

					if (intp(last_id) && this.icount < last_id) {
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
				
				if (intp(count)) {
					if (this.icount+1 < count) {
						// request all up to count-1
						this.sync(count-1);

					} else if (this.icount == count - 1) {
						this.icount = count;
					}
				}

				var none = 1;

				for (var t = method; t; t = psyc.abbrev(t)) {
					if (this.hasOwnProperty(t) && functionp(this[t])) {
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
yakity.funky_text = function(p, templates) {
	var m = p.data;
	var template = templates.get(m.method);
	var reg = /\[[\w-]+\]/g;

	if (functionp(template)) {
		var node = template(m);
		node.className = psyc.abbreviations(m.method).join(" ");
		return node;
	}

	var div = document.createElement("div");
	div.className = psyc.abbreviations(m.method).join(" ");
	
	var cb = function(result, m) {
		var s = result[0].substr(1, result[0].length-2);
		var a = s.split("-");
		s = a[0];
		var classes = psyc.abbreviations(s);
		var type;
		if (a.length > 1) {
			type = a[1];
			classes.push(a.join("-"));
			classes.push(type);
		}
		var t;

		if (s == "data") {
			t = m.data;
		} else if (s == "method") {
			t = m.method;
		} else if (p.V(s) || m.V(s)) {
			var vtml = templates.get(s);
			t = p.V(s) ? p.v(s) : m.v(s);

			if (functionp(vtml)) {
				t = vtml.call(window, type, s, t, m);
			} else if (objectp(t)) {
				if (functionp(t.render)) {
					t = t.render(type);
				} else {
					t = t.toString();
				}
			}
		} else {
			classes = new Array("missing_variable");
			t = "["+s+"]";
		}

		if (objectp(t)) {
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
		if (stringp(t)) {
			if (t.length > 0) div.appendChild(document.createTextNode(t));
		} else {
			div.appendChild(t);
		}
	}

	return div;
};
yakity.Base = Base.extend({
	constructor : function() {
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

		for (var t = method; t; t = psyc.abbrev(t)) {
			if (functionp(this[t])) {
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
		
		for (var i = 0; i < list.length; i++) {
			list[i][1].call(list[i][0]);
		}
	}
});
yakity.ChatWindow = yakity.Base.extend({
	constructor : function(id) {
		this.base();
		this.mlist = new Array();
		this.mset = new Mapping();
		this.messages = document.createElement("div");
		this.name = id;
	},
	_ : function(p, m) {
		if (m.data && m.data.length) {
			this.mset.set(p, this.mlist.length);
			this.mlist.push(p);
			this.messages.appendChild(this.renderMessage(p, m));
		}
	},
	getMessages : function() {
		return this.mlist.concat();
	},
	render : function(o) {
		if (typeof(o) == "object" && typeof(o.render) == "function") {
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
yakity.TemplatedWindow = yakity.ChatWindow.extend({
	constructor : function(templates, id) {
		this.base(id);
		if (templates) this.setTemplates(templates);
	},
	setTemplates : function(t) {
		this.templates = t;
	},
	renderMessage : function(p, m) {
		return yakity.funky_text(p, this.templates);
	}
});
yakity.RoomWindow = yakity.TemplatedWindow.extend({
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
				if (this.onenter) this.onenter(this);
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
				if (this.onleave) this.onleave(this);
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
 * @param {Object} client yakity.Client object to use.
 * @param {Object} div DOM div object to put the Chat into.
 * @constructor
 */
yakity.Chat = Base.extend({
	constructor : function(client) {
		this.windows = new Mapping();
		this.active = null;

		if (client) {
			client.register_method({ method : "_", source : null, object : this });
			this.client = client;
		}
	},
	msg : function(p, m) {
		this.getWindow(p.source()).msg(p, m);
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
	enterRoom : function(uniform) {
		this.client.sendmsg(uniform, "_request_enter");
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
yakity.ProfileData = yakity.Base.extend({
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
yakity.UserList = yakity.Base.extend({
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
yakity.Presence = {};
yakity.Presence.Typing = yakity.Base.extend({
	constructor : function(client, chat) {
		this.base();
		this.client = client;
		this.chat = chat;
		this.ids = new Mapping();
	},
	type_event : function() {
		if (!this.chat.active) return;
		var uniform = this.chat.active.name;
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
