#!/bin/bash
# set -ex

startTime=$(date "+%Y-%m-%d %H:%M:%S")
outPutFile='services.csv'
echo "CLUSTER,SERVICE,DesiredCount,LaunchType,SchedulingStrategy,STOPPEDTaskCount,TASK,NetworkMode,CPU,MEMORY,ContainerInfo" | tee $outPutFile
# 1.Get clusters
Clusters=$(aws ecs list-clusters | jq -r '.clusterArns[]' | awk -F '/' '{print $2}')

# 2.Get service information and task definition
for cluster in $Clusters; do
    Services=$(aws ecs list-services --cluster $cluster | jq -r '.serviceArns[]' | awk -F '/' '{print $NF}')
    # 3.Get service information and task family
    for service in $Services; do
        aws ecs describe-services --cluster $cluster --services $service > /tmp/service
        taskDefinition=$(jq -r '.services[].taskDefinition' /tmp/service | awk -F '/' '{print $NF}')
        taskFamily=${taskDefinition%:*}
        serviceInfo=$(jq -r '.services[]|.serviceName,.desiredCount,.launchType,.schedulingStrategy' /tmp/service)
        # 4.Count STOPPED task in 3 hours
        stoppedTaskCount=$(aws ecs list-tasks --cluster $cluster --service-name $service --desired-status STOPPED | jq '.taskArns|length')
        # 5.Get task definition information
        aws ecs describe-task-definition --task-definition $taskDefinition > /tmp/taskDefinition
        taskInfo=$(jq -r '.taskDefinition|.networkMode,.cpu,.memory' /tmp/taskDefinition)
        ContainerInfo=$(jq -c '.taskDefinition.containerDefinitions[]|{(.name):{cpu,memory,essential,memoryReservation}}' /tmp/taskDefinition)
        # csv format: " --> "", whitespace --> \n, add " to the start and end of ContainerInfo
        row=$(echo  "$cluster $serviceInfo $stoppedTaskCount $taskFamily $taskInfo" | tr "\n| " ",")
        ContainerInfo=$(echo $ContainerInfo | sed -r 's/"/""/g;s/ /\n/g;s/^|$/"/g')
        echo -e "${row}${ContainerInfo}" | tee -a $outPutFile
    done
done

endTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "execution time: $startTime ~ $endTime" | tee -a $outPutFile
