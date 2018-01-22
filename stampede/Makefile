APP = mash-all-vs-all-0.0.2
EMAIL = kyclark@email.arizona.edu

clean:
	find . \( -name \*.out -o -name \*.param \) -exec rm {} \;

up: 
	copy_from_manifest.py

template:
	jobs-template -A $(APP) > job.json

job:
	jobs-submit -F job.json

rmbin:
	rm -rf bin

scriptsgz:
	(cd scripts && tar cvf ../scripts.tgz *)

app:
	apps-addupdate -F app.json

test: clean
	sbatch test.sh

ohana:
	sbatch run.sh -q $(WORK)/ohana/HOT -o $(WORK)/ohana/mash

rice:
	sbatch run.sh -q $(SCRATCH)/rice/fasta -o $(SCRATCH)/rice/mash

tov:
	./00-controller.sh -f $(SCRATCH)/data/tov/fasta_43 -o $(SCRATCH)/data/tov/mash -m $(SCRATCH)/data/tov/meta.tab -e $(EMAIL) -p normal -t "24:00:00" -x 100000

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

mskin:
	./00-controller.sh -f $(SCRATCH)/skin-virome-grice/fasta -o $(SCRATCH)/skin-virome-grice/mash -m $(SCRATCH)/skin-virome-grice/meta.tab -l $(SCRATCH)/skin-virome-grice/microbiome-accs.txt -x 1000 -p development -t 02:00:00 -r 02-sna.sh -a $(SCRATCH)/skin-virome-grice/alias.tab

vskin: clean
	./00-controller.sh -f $(SCRATCH)/skin-virome-grice/fasta -o $(SCRATCH)/skin-virome-grice/mash -m $(SCRATCH)/skin-virome-grice/meta.tab -l $(SCRATCH)/skin-virome-grice/all-virome.txt -x 1000 -p development -t 02:00:00 -r 02-sna.sh -a $(SCRATCH)/skin-virome-grice/alias.tab

gaz: clean
	./00-controller.sh -f $(SCRATCH)/gazitua/fasta -o $(SCRATCH)/gazitua/mash -m $(SCRATCH)/gazitua/ETSP_meta.tab -p development -t 02:00:00 -r 02-sna.sh

delong: clean
	./00-controller.sh -f $(WORK)/delong/fasta -o $(SCRATCH)/delong/mash -m $(SCRATCH)/gazitua/ETSP_meta.tab -p development -t 02:00:00 -r 02-sna.sh

kira: clean
	./00-controller.sh -f $(SCRATCH)/krmoon/fasta -o $(SCRATCH)/krmoon/mash -m $(SCRATCH)/krmoon/meta.tab -p development -t 02:00:00 -d 0.3 -r 02-sna.sh

jimmy: clean
	./00-controller.sh -f $(SCRATCH)/jimmy/fever/fasta -o $(SCRATCH)/jimmy/mash -m $(SCRATCH)/krmoon/meta.tab -p development -t 02:00:00 -d 0.3 -r 02-sna.sh

bugmix: clean
	./00-controller.sh -f $(SCRATCH)/gwatts/bug_mixing/wgs/fasta -o $(SCRATCH)/gwatts/bug_mixing/wgs/mash -m $(SCRATCH)/gwatts/bug_mixing/wgs/meta-fake.tab -p normal -t 24:00:00

bugmix-sap: clean
	./00-controller.sh -f $(SCRATCH)/gwatts/bug_mixing/wgs/fasta -o $(SCRATCH)/gwatts/bug_mixing/wgs/sap-pyo -a $(SCRATCH)/gwatts/bug_mixing/wgs/aliases.txt -p normal -t 24:00:00 -l $(SCRATCH)/gwatts/bug_mixing/wgs/saprophyticus-pyogenes.txt -r 02-sna.sh

bugmix-mssa: clean
	./00-controller.sh -f $(SCRATCH)/gwatts/bug_mixing/wgs/fasta -o $(SCRATCH)/gwatts/bug_mixing/wgs/mssa -a $(SCRATCH)/gwatts/bug_mixing/wgs/aliases.txt -p normal -t 24:00:00 -l $(SCRATCH)/gwatts/bug_mixing/wgs/mssa-mrsa.txt -r 02-sna.sh

garcia: clean
	./00-controller.sh -f $(SCRATCH)/garcia/mvs_assembly/fasta -o $(SCRATCH)/garcia/mvs_assembly/mash -p normal -t 02:00:00

imicrobe: clean
	./00-controller.sh -f $(SCRATCH)/imicrobe/fasta -o $(SCRATCH)/imicrobe/mash -p normal -t 02:00:00

flex: 
	./00-controller.sh -f $(SCRATCH)/xiang/s_flexneri/fasta -o $(SCRATCH)/xiang/s_flexneri/mash -p normal -t 02:00:00 -l $(SCRATCH)/xiang/s_flexneri/files

mssa476: 
	./00-controller.sh -f $(SCRATCH)/xiang/mssa476/fasta -o $(SCRATCH)/xiang/mssa476/mash -p normal -t 02:00:00 -l $(SCRATCH)/xiang/mssa476/files

giantfiz: clean
	./00-controller.sh -f $(SCRATCH)/dmuratore/Giantfiz/fasta -o $(SCRATCH)/dmuratore/Giantfiz/mash -p normal -t 02:00:00 -m $(SCRATCH)/dmuratore/Giantfiz/giantmeta.tab

george: clean
	./00-controller.sh -f $(SCRATCH)/george/p3/fasta -o $(SCRATCH)/george/p3/mash -p normal -t 02:00:00

madrid: clean
	./00-controller.sh -f $(SCRATCH)/data/maria-jose/madrid/fasta -o $(SCRATCH)/data/maria-jose/madrid/mash -p development -t 02:00:00 -r 02-sna.sh -s 0.01

vesiculas: 
	./00-controller.sh -f $(SCRATCH)/data/maria-jose/vesiculas/fasta -o $(SCRATCH)/data/maria-jose/vesiculas/mash -p development -t 02:00:00 -r 02-sna.sh

bug-out-mrsa:
	./00-controller.sh -f $(SCRATCH)/bug-out/xiang/mrsa/fasta -o $(SCRATCH)/bug-out/xiang/mrsa/mash -p normal -t 02:00:00

bug-out-sap:
	./00-controller.sh -f $(SCRATCH)/bug-out/xiang/sap/fasta -o $(SCRATCH)/bug-out/xiang/sap/mash -p normal -t 02:00:00

bonnie:
	./00-controller.sh -f $(SCRATCH)/bonnie/fasta -o $(SCRATCH)/bonnie/mash

korn: clean
	./submit.sh $(SCRATCH)/frischkorn/centrifuge/filtered-collapsed $(SCRATCH)/frischkorn/centrifuge/filtered-mash

skin:
	./00-controller.sh -f $(WORK)/skin-virome-grice/filtered -o $(WORK)/skin-virome-grice/mash -x 1000 -r 02-sna.sh -l $(WORK)/skin-virome-grice/files -p development -t "02:00:00"

skin1: clean
	./00-controller.sh -f $(WORK)/skin-virome-grice/filtered -l $(WORK)/skin-virome-grice/groups/10.txt -o $(WORK)/skin-virome-grice/mash -r 02-sna.sh -p development -t "02:00:00" -a $(WORK)/skin-virome-grice/aliases.txt

nature: clean
	./submit.sh $(SCRATCH)/nature/fasta $(SCRATCH)/nature/mash

myriam: clean
	./submit.sh $(SCRATCH)/myriam/DiversityLakeA/uncorrected $(SCRATCH)/myriam/DiversityLakeA/mash
