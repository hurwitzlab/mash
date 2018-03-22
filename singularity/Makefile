SINGULARITY = singularity
IMG_NAME = mash-2.0.0.img
DEF_NAME = ubuntu.sh
SIZE = 2536

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
	scp $(IMG_NAME) scottdaniel@filexfer.hpc.arizona.edu:/rsgrps/bhurwitz/scottdaniel/singularity-images
