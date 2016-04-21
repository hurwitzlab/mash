clean:
	find . \( -name \*.conf -o -name \*.out -o -name \*.log -o -name \*.params -o -name launcher-\* \) -exec rm {} \;

mouse:
	./00-controller.sh -f $(WORK)/mouse/fasta -o $(WORK)/mouse/mash -m $(WORK)/mouse/meta2.tab

sketch:
	./00-controller.sh -f $(WORK)/mouse/fasta -o $(WORK)/mash/mouse -p development -t "02:00:00" -r 01-sketch.sh

dist:
	./00-controller.sh -f $(WORK)/mouse/fasta -o $(WORK)/mash/mouse -p development -t "02:00:00" -r 02-dist.sh

pov:
	./00-controller.sh -f $(WORK)/pov/fasta -o $(WORK)/mash/pov -p development -t "02:00:00" -r 03-sna.sh -m $(WORK)/pov/meta.tab
