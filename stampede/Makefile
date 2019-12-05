up: 
	copy_from_manifest.py

template:
	jobs-template -A $(APP) > job.json

job:
	tapis jobs submit -F job.json

app:
	tapis apps create -F app.json
