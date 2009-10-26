ifdef V
	VERSION = $(V)
else
	VERSION = local
endif

NAME = YakityChat-$(VERSION)

release:
	mkdir $(NAME)
	cp -r lib $(NAME)
	cp README $(NAME)
	cp gpl-2.0.txt $(NAME)
	cp LICENSE $(NAME)
	mkdir $(NAME)/modules
	cp modules/yakitychat.pike $(NAME)/modules/
	cp -r js $(NAME)/
	mkdir $(NAME)/ppp-js/
	cp ppp/js/*.js $(NAME)/ppp-js/
	rm $(NAME)/ppp-js/time.js
	rm $(NAME)/ppp-js/psyc.js
	cp -r ppp/lib/Serialization.pmod $(NAME)/lib/
	cp ppp-bsd ppp/lib/Serialization.pmod/LICENSE
	cp -r ppp/lib/MMP.pmod $(NAME)/lib/
	cp ppp-bsd ppp/lib/MMP.pmod/LICENSE
	mkdir $(NAME)/htdocs
	cp htdocs/index.html $(NAME)/htdocs/
	cp htdocs/mootools-1.2.3-core-nc.js $(NAME)/htdocs/
	cp htdocs/mootools-1-1.2.3.1-more.js $(NAME)/htdocs/
