TAG = hurwitzlab/mash-all-vs-all:2.2.0

img: 
	docker build --tag=$(TAG) .

run: 
	docker run --rm $(TAG)

shell: 
	docker run --rm -it $(TAG) bash

pov: 
	docker run --rm -v /data:/data $(TAG) run_mash -q /data/kyclark/pov/fasta/ -o /data/kyclark/pov/mash-out

push: 
	docker push $(TAG)
