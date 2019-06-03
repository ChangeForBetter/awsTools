#!/bin/bash

function ecstaskdesc() {
    aws ecs describe-task-definition --task-definition $1
}

function ecstaskregister() {
    dirName=$(cd $(dirname $1); pwd)
    fileName=$(basename $1)
    parameter=file://$dirName/$fileName
    # echo $parameter
    aws ecs register-task-definition --cli-input-json $parameter
}

function ecstaskdiff() {
    tmpDir=/tmp/awsTools
    if [ ! -d ${tmpDir} ]; then
        mkdir ${tmpDir}
    fi

    taskDefinition_a=$1
    ecstaskdesc $taskDefinition_a 2>&1 > $tmpDir/$taskDefinition_a

    if [ -z "$2" ]; then
        # taskFamily is string, use -r(--raw-output) to remove quotes
        taskFamily=$(jq -r '.taskDefinition.family' $tmpDir/$taskDefinition_a)
        latestRevison=$(jq '.taskDefinition.revision' $tmpDir/$taskDefinition_a)
        taskDefinition_b=$taskFamily:$(( $latestRevison - 1 ))
    else
        taskDefinition_b=$2
    fi
    ecstaskdesc $taskDefinition_b 2>&1 > $tmpDir/$taskDefinition_b

    icdiff $tmpDir/$taskDefinition_a $tmpDir/$taskDefinition_b
}

