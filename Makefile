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
	cp COPYING $(NAME)
	mkdir $(NAME)/modules
	cp modules/yakitychat.pike $(NAME)/modules/
	mkdir $(NAME)/htdocs
	cp -r bin $(NAME)/
	cp -r js $(NAME)/htdocs/
	mkdir $(NAME)/htdocs/ppp-js/
	mkdir $(NAME)/stats/
	cp stats/Makefile $(NAME)/stats/
	cp ppp/js/*.js $(NAME)/htdocs/ppp-js/
	rm $(NAME)/htdocs/ppp-js/time.js
	rm $(NAME)/htdocs/ppp-js/psyc.js
	cp -r ppp/lib/Serialization.pmod $(NAME)/lib/
	cp ppp-bsd ppp/lib/Serialization.pmod/LICENSE
	cp -r ppp/lib/MMP.pmod $(NAME)/lib/
	rm $(NAME)/lib/MMP.pmod/Parser.pike
	cp ppp-bsd ppp/lib/MMP.pmod/LICENSE
	cp htdocs/index.html $(NAME)/htdocs/
	cp -r htdocs/images $(NAME)/htdocs/
	cp -r htdocs/sounds $(NAME)/htdocs/
	cp htdocs/mootools-1.2.3-core-nc.js $(NAME)/htdocs/
	cp htdocs/mootools-1-1.2.3.1-more.js $(NAME)/htdocs/
	tar cfzvp $(NAME).tar.gz $(NAME)
