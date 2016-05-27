EMAIL = kyclark@email.arizona.edu

clean:
	find . \( -name \*.conf -o -name \*.out -o -name \*.log -o -name \*.params -o -name launcher-\* \) -exec rm {} \;

tov:
	./00-controller.sh -f $(SCRATCH)/tov/fasta_43 -o $(SCRATCH)/tov/mash -m $(SCRATCH)/tov/meta.tab -e $(EMAIL) -r 03-sna.sh -p development -t "02:00:00" -x 100000

marina:
	./00-controller.sh -f $(SCRATCH)/martintay/fasta -o $(SCRATCH)/martintay/mash -m $(SCRATCH)/martintay/meta/meta.tab -e $(EMAIL) -r 03-sna.sh -p development -t "02:00:00" -x 10000

mouse:
	./00-controller.sh -f $(WORK)/mouse/fasta -o $(WORK)/mouse/mash -m $(WORK)/mouse/meta2.tab -e $(EMAIL) -r 03-sna.sh -p development -t "02:00:00" -x 10000

sketch:
	./00-controller.sh -f $(WORK)/mouse/fasta -o $(WORK)/mash/mouse -p development -t "02:00:00" -r 01-sketch.sh

dist:
	./00-controller.sh -f $(WORK)/mouse/fasta -o $(WORK)/mash/mouse -p development -t "02:00:00" -r 02-dist.sh

sna:
	./00-controller.sh -f $(WORK)/mouse/fasta -o $(WORK)/mouse/mash -p development -t "02:00:00" -r 03-sna.sh -m $(WORK)/mouse/meta.tab -e $(EMAIL)

pov:
	./00-controller.sh -f $(WORK)/pov/fasta -o $(WORK)/pov/mash -p development -t "02:00:00" -r 03-sna.sh -m $(WORK)/pov/meta.tab

skin:
	./00-controller.sh -f $(SCRATCH)/skin-virome-grice/fasta -o $(SCRATCH)/skin-virome-grice/mash -m $(SCRATCH)/skin-virome-grice/meta.tab -r 02-sna.sh -x 1000

mskin:
	./00-controller.sh -f $(SCRATCH)/skin-virome-grice/fasta -o $(SCRATCH)/skin-virome-grice/mash -m $(SCRATCH)/skin-virome-grice/meta.tab -l $(SCRATCH)/skin-virome-grice/microbiome-accs.txt -x 1000 -p development -t 02:00:00 -r 02-sna.sh -a $(SCRATCH)/skin-virome-grice/alias.tab

vskin: clean
	./00-controller.sh -f $(SCRATCH)/skin-virome-grice/fasta -o $(SCRATCH)/skin-virome-grice/mash -m $(SCRATCH)/skin-virome-grice/meta.tab -l $(SCRATCH)/skin-virome-grice/all-virome.txt -x 1000 -p development -t 02:00:00 -r 02-sna.sh -a $(SCRATCH)/skin-virome-grice/alias.tab

gaz: clean
	./00-controller.sh -f $(SCRATCH)/gazitua/fasta -o $(SCRATCH)/gazitua/mash -m $(SCRATCH)/gazitua/ETSP_meta.tab -p development -t 02:00:00 -r 02-sna.sh

# gaz: clean
# 	./00-controller.sh -f $(SCRATCH)/gazitua/fasta -o $(SCRATCH)/gazitua/mash -m $(SCRATCH)/gazitua/ETSP_meta.tab 
