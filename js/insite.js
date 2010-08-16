var Amnesty = {
    instances : new Mapping(),
    Instance : UTIL.EventSource.extend({
	constructor : function(iframe) {
	    this.base();
	    this.iframe = iframe;
	    //console.log("window: %o", iframe.contentWindow);
	},
	is_parent : function(win) {
	    return this.win != win;
	}
    }),
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
	} else {
	    var iframe;

	    if (true || UTIL.App.is_opera) {
		iframe = UTIL.create("iframe", { src : window.location.href+"?a" });
		window.onresize = function() {
		    var h = document.documentElement.clientHeight;
		    var w = document.documentElement.clientWidth;
		    iframe.width = w;
		    iframe.height = h;
		};
		document.body.style.overflow = "hidden";
	    } else {
		iframe = UTIL.create("frameset", {rows:"100"}, UTIL.create("frame", { src : window.location.href+"?a" }));
	    }
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
