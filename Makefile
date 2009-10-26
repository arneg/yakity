ifdef V
	VERSION = V
else
	VERSION = local
endif

NAME = YakityChat-$(VERSION)

release:
	mkdir $(NAME)
	cp -r lib $(NAME)
	cp README $(NAME)
	cp LICENSE $(NAME)
	mkdir $(NAME)/modules
	cp modules/yakitychat.pike $(NAME)/modules/
	cp -r js $(NAME)/
	cp ppp/js/*.js $(NAME)/js/
	rm $(NAME)/js/time.js
	cp -r ppp/lib/Serialization.pmod $(NAME)/lib/
	cp -r ppp/lib/MMP.pmod $(NAME)/lib/
