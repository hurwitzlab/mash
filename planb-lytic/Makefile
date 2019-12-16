APP = mash-all-vs-all-0.0.6

img:
	cd ../singularity && make img

deploy: img
	icd \
	imkdir -p applications/$APP/planb-lytic \
	icd applications/$APP/planb-lytic \
        iput -TP ../singularity/$APP.img \
	iput -TP run.sh
