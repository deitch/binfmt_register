IMAGE ?= deitch/binfmt_register
HASH ?= $(shell git show --format=%T -s)

# check if we should append a dirty tag
DIRTY ?= $(shell git diff-index --quiet HEAD -- ; echo $$?)
ifneq ($(DIRTY),0)
TAG = $(HASH)-dirty
else
TAG = $(HASH)
endif

IMGTAG = $(IMAGE):$(TAG)

.PHONY: all image push latest pushlatest
all: image

image: Dockerfile register.sh binfmt.conf
	docker build -t $(IMGTAG) -f Dockerfile .

push:
	docker push $(IMGTAG)

latest:
	docker tag $(IMGTAG) $(IMAGE):latest

pushlatest:
	docker push $(IMAGE):latest

