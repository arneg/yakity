var URL = Base.extend({
    constructor : function(url) {
	if (url) {
	    this.host = url.host;
	    this.pathname = url.pathname;
	    this.hash = url.hash;
	    this.protocol = url.protocol;
	    this.search = url.search;
	}
    },
    from : function(url) {
	if (this.protocol != url.protocol ||
	    this.host!= url.host) {
	    return this.toString();
	}
	var ret = [];
	var a = url.pathname.split("/");
	var b = this.pathname.split("/");
	var i = 0;

	while (i < Math.min(a.length, b.length) && a[i] == b[i]) {
	    i++;
	}

	for (var j = i; j < a.length; j++) {
	    ret.push("../");
	}

	for (var j = i; j < b.length; j++) {
	    ret.push(b[j]);
	}

	return ret.join("/") + this.search + this.hash;
    },
    to : function(url) {
	return (url instanceof URL ? url : new URL(url)).from(this);	
    },
    toString : function() {
	return this.protocol + "//" + this.host + this.pathname + this.search + this.hash;
    },
    apply : function(path) {
	var url = new URL(this);
	var a = url.pathname.split("/");
	var t = path.split("?");
	console.log("t: %o", t);
	var b = t.shift().split("/");

	url.hash = "";

	if (t.length) {
	    t = t.join("?").split("#");
	    console.log("t: %o", t);
	    url.search = "?" + t.shift();
	    if (t.length) url.hash = "#" + t.join("#");
	    
	}

	for (var i = 0; i < b.length; i++) {
	    if (b[i] == "..") {
		a.pop();
	    } else {
		a.push(b[i]);
	    }
	}

	url.pathname = a.join("/");

	return url;
    }
});
var Amnesty = {
    instances : new Mapping(),
    Instance : UTIL.EventSource.extend({
	constructor : function(iframe) {
	    this.base();
	    this.iframe = iframe;
	    //console.log("window: %o", iframe.contentWindow);
	    iframe.onload = UTIL.make_method(this, function() {
		this.trigger("child_load", iframe.contentWindow, iframe.contentWindow.location);
		iframe.contentWindow.onhashchange = UTIL.make_method(this, this.child_load);
	    });
	    window.onhashchange = UTIL.make_method(this, function() {
		console.log("hash changed to %s", window.location.hash);
		if (window.location.hash != this.url.hash) {
		    this.iframe.src = this.url.apply(window.location.hash.substr(1)).toString();
		}
	    });
	    this.url = new URL(window.location);
	    this.wire("child_load", UTIL.make_method(this, function(win, loc) {
		console.log("child_load: " + loc.href);
		this.url.hash = "#" + this.url.to(loc);
		window.location.hash = this.url.hash;
		//window.location.replace(this.url.toString());
	    }));
	},
	is_parent : function(win) {
	    return this.win != win;
	}
    }),
    child_load : function() {
    },
    get_instance : function(win) {
	return Amnesty.instances.get(win);
    },
    has_instance : function(win) {
	//if (Amnesty.instances.hasIndex(win)) return true;
	////for (var i = 0; i < document.frames.length; i ++) {
	//}
	return Amnesty.instances.hasIndex(win);
    },
    destroy : function() {
	window.location.replace(Amnesty.n.win.location.href);
    },
    init : function() {
	if (window.parent && window.parent.Amnesty && window.parent.Amnesty.n) {
	    Amnesty.n = window.parent.Amnesty.n;
	    Amnesty.n.win = window;
	    //Amnesty.n.trigger("child_load", window, window.location);
	} else {
	    var iframe;

	    var url = new URL(window.location);
	    url.hash = "";
	    url.search += ((url.search.length && url.search(/_amnesty=1/) == -1) ? "&" : "?") + "_amnesty=1";
	    iframe = UTIL.create("iframe", { src : url.toString() });
	    window.onresize = function() {
		var h = document.documentElement.clientHeight;
		var w = document.documentElement.clientWidth;
		iframe.width = w;
		iframe.height = h;
	    };
	    document.body.style.overflow = "hidden";

	    var head = document.getElementsByTagName("head")[0];
	    //iframe.src = "data:text/html;base64,PGh0bWw+PC9odG1sPg==";
	    //iframe.src = window.location.href.substring(0, window.location.href.length-window.location.search.length) + "?a";
	    //document.body.bgcolor="black";
	    //iframe.contentWindow.parent = parent;
	    
	    while (document.body.firstChild) {
		var node = document.body.firstChild;
		document.body.removeChild(node);
		//iframe.contentWindow.document.body.appendChild(node);
	    }

	    for (var i = 0; i < document.styleSheets.length; i++) {
		document.styleSheets[i].disabled = true;
	    }

	    iframe.style.border = "0";
	    iframe.style.margin = "0";

	    iframe.style.position = "absolute";
	    iframe.style.top = "0px";
	    iframe.style.left = "0px;"
	    iframe.onmouseover = function() {
		iframe.contentWindow.focus();
	    };

	    document.body.style.padding = "0";
	    document.body.style.margin = "0";
	    document.body.style.overflow = "hidden";
	    document.body.lineHeight = "0pt";
	    //head.appendChild(iframe);
	    if (false && !UTIL.App.is_opera) {
		document.getElementsByTagName("html")[0].appendChild(iframe);
	    } else {
		document.body.appendChild(iframe);
	    }
	    window.onresize();
	    Amnesty.n = new Amnesty.Instance(iframe);
	    UTIL.load_js("js/jquery-1.4.2.min.js", UTIL.make_method(Amnesty.n, Amnesty.n.trigger, "ready", "jquery"));
	    UTIL.load_js("jquery-ui/js/jquery-ui-1.8.4.custom.min.js");
	    UTIL.load_js("js/jquery-overlay.js", UTIL.make_method(Amnesty.n, Amnesty.n.trigger, "ready", "jquery-ui"));

	    head.appendChild(UTIL.create("link", {
		rel : "stylesheet",
		href : "jquery-ui/css/smoothness/jquery-ui-1.8.4.custom.css"
	    }));
	    Amnesty.n.wire("ready", function(what) {
		if (what == "jquery") {
		}
	    });
	}
    }
};
