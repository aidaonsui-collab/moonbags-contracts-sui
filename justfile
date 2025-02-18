import PRIVATE:
  sui keytool import {{PRIVATE}}

addresses:
  sui client addresses

envs:
  sui client envs

build:
  sui move build

deploy:
  sui client publish

test:
  sui client test
