SINGULARITY = /usr/local/bin/singularity
IMG = mash-2.0.0.img
DEF_NAME = image.def
SIZE = 2048

run:
	sudo $(SINGULARITY) run $(IMG)

clean:
	rm -f $(IMG)

img: clean
	sudo $(SINGULARITY) create --size $(SIZE) $(IMG)
	sudo $(SINGULARITY) bootstrap $(IMG) $(DEF_NAME)

shell:
	sudo $(SINGULARITY) shell --writable -B /data:/work -B $(HOME):/home1 -B $(shell pwd):/tmp $(IMG)

scp:
	scp $(IMG) stampede:/work/03137/kyclark/mash-0.0.5/stampede

dolphin:
	sudo $(SINGULARITY) exec -B /data:/work -B $(HOME):/home1 $(IMG) run_mash \
	-q "/work/kyclark/dolphin/fasta" -o "/work/kyclark/dolphin/mash-out"
