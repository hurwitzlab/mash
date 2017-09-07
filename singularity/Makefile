SINGULARITY = /usr/local/bin/singularity
IMG_NAME = mash-1.1.1.img
DEF_NAME = image.def
SIZE = 2048

run:
	sudo $(SINGULARITY) run $(IMG_NAME)

clean:
	rm -f $(IMG_NAME)

img: clean
	sudo $(SINGULARITY) create --size $(SIZE) $(IMG_NAME)
	sudo $(SINGULARITY) bootstrap $(IMG_NAME) $(DEF_NAME)

shell:
	sudo $(SINGULARITY) shell --writable -B $(shell pwd):/tmp $(IMG_NAME)

scp:
	scp $(IMG_NAME) stampede:/work/03137/kyclark/mash-0.0.4/stampede
