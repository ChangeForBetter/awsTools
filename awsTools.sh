#!/bin/bash

function ecssvcdesc() {
    #cluster=$1
    #services=$2
    #shift 2
    #aws ecs describe-services --cluster $cluster --services $services $@ | jq 'del(.services[].events, .services[].deployments)'
    aws ecs describe-services $@ | jq 'del(.services[].events, .services[].deployments)'
}

function ecstaskdesc() {
    aws ecs describe-task-definition --task-definition $@ | jq '.taskDefinition'
}

function ecstaskdefinitionexport() {
    aws ecs describe-task-definition --task-definition $@ | jq '.taskDefinition|del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities)'
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
    aws ecs describe-task-definition --task-definition $taskDefinition_a 2>&1 > $tmpDir/$taskDefinition_a

    if [ -z "$2" ]; then
        # taskFamily is string, use -r(--raw-output) to remove quotes
        taskFamily=$(jq -r '.taskDefinition.family' $tmpDir/$taskDefinition_a)
        latestRevison=$(jq '.taskDefinition.revision' $tmpDir/$taskDefinition_a)
        taskDefinition_b=$taskFamily:$(( $latestRevison - 1 ))
    else
        taskDefinition_b=$2
    fi
    aws ecs describe-task-definition --task-definition $taskDefinition_b 2>&1 > $tmpDir/$taskDefinition_b

    icdiff $tmpDir/$taskDefinition_a $tmpDir/$taskDefinition_b
}

