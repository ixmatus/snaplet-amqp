prog = ghc
path = /usr/bin/ghc-7.6.3

tags:
	hasktags --etags --output='TAGS' *

build:
	cabal configure --with-$(prog)=$(path) && cabal build --with-$(prog)=$(path)

install:
	cabal install -w $(path)

deps:
	cabal install --only-dependencies -w $(path)

test:
	cabal test -w $(path)
