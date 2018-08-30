SINGULARITY = /usr/local/bin/singularity
IMG = mash-all-vs-all-0.0.4.img
DEF = image.def

run:
	sudo $(SINGULARITY) run $(IMG)

clean:
	rm -f $(IMG)

img: clean
	sudo $(SINGULARITY) build $(IMG) $(DEF)

shell:
	sudo $(SINGULARITY) shell --writable -B /data:/work -B $(HOME):/home1 -B $(shell pwd):/tmp $(IMG)

scp:
	scp $(IMG) stampede:/work/03137/kyclark/mash-0.0.5/stampede

dolphin:
	sudo $(SINGULARITY) exec -B /data:/work -B $(HOME):/home1 $(IMG) run_mash \
	-q "/work/kyclark/dolphin/fasta" -o "/work/kyclark/dolphin/mash-out"
