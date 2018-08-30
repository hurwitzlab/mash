#!/bin/bash

echo "QUERY      \"${QUERY}\""
echo "ALIAS_FILE \"${ALIAS_FILE}\""

sh run.sh ${ALIAS_FILE} ${QUERY}
