# Cloud Foundry MapR Buildpack
# Copyright (c) 2019 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export MAPR_HOME="/home/vcap/app/.mapr/mapr"
export HADOOP_HOME="/home/vcap/app/.mapr/mapr/hadoop/hadoop-2.7.0"
MAPR_TICKETFILE_LOCATION_DIR="/home/vcap/app/.mapr-ticket"
export MAPR_TICKETFILE_LOCATION="$MAPR_TICKETFILE_LOCATION_DIR/ticket"

MAPR_SERVICE_BROKER_CONFIG=$(echo $VCAP_SERVICES | jq '.["MapR"] | .[0]')

if [ "${MAPR_SERVICE_BROKER_CONFIG}" = "null" ]
then
    ### Resolving environment variables directly
    if [[ -z ${MAPR_CLUSTER_NAME+x} ]]
    then
        echo "Environment variable \$MAPR_CLUSTER_NAME is not set; can not write ticket or mapr-clusters.conf to filesystem"
    else
        if [[ -z ${MAPR_TICKET+x} ]]
        then
            echo "Environment variable \$MAPR_TICKET is not set; can not write ticket to filesystem"
        else
            echo "Environment variable \$MAPR_TICKET is set; writing ticket to filesystem"

            # write the ticket
            mkdir $MAPR_TICKETFILE_LOCATION_DIR
            echo "$MAPR_CLUSTER_NAME $MAPR_TICKET" > $MAPR_TICKETFILE_LOCATION
            echo "Created MapR ticket file"
        fi

        if [[ -z ${MAPR_CLDB_NODES+x} ]]
        then
            echo "Environment variable \$MAPR_CLDB_NODES is not set; can not write mapr-clusters.conf to filesystem"
        else
            # setup the client
            echo "$MAPR_CLUSTER_NAME secure=true ${MAPR_CLDB_NODES//,/ }" > $MAPR_HOME/conf/mapr-clusters.conf
            echo "Updated MapR cluster configuration"
        fi
    fi
else
    ### Resolving environment variables from service broker
    echo "MapR service broker detected. Resolving values from service broker and credhub"

    MAPR_CREDENTIALS=$(echo $MAPR_SERVICE_BROKER_CONFIG | jq '.["credentials"]')
    CREDHUB_REF=$(echo $MAPR_CREDENTIALS | jq --raw-output '.["credhub-ref"]')
    echo "Using credhub reference $CREDHUB_REF"

    MAPR_CLDB_NODES=$(echo $MAPR_CREDENTIALS | jq --raw-output '.["mapr-cldb-nodes"]')
    echo "Using MapR CLDB nodes $MAPR_CLDB_NODES"

    MAPR_CLUSTER_NAME=$(echo $MAPR_CREDENTIALS | jq --raw-output '.["mapr-cluster-name"]')
    echo "Using MapR cluster name $MAPR_CLUSTER_NAME"

    CREDHUB_BASE_URI=$(echo $VCAP_PLATFORM_OPTIONS |  jq --raw-output '.["credhub-uri"]')
    echo "Connecting credhub at $CREDHUB_BASE_URI to resolve credentials"

    RESOLVED_MAPR_CREDENTIALS=$(curl -s --key $CF_INSTANCE_KEY --cert $CF_INSTANCE_CERT "$CREDHUB_BASE_URI/api/v1/data?name=$CREDHUB_REF")
    echo "Successful resolved MapR credentials"

    MAPR_TICKET=$(echo $RESOLVED_MAPR_CREDENTIALS | jq --raw-output '.["data"] | .[0] | .["value"] | .["ticket"]')

    # write the ticket
    mkdir $MAPR_TICKETFILE_LOCATION_DIR
    echo $MAPR_TICKET > $MAPR_TICKETFILE_LOCATION
    echo "Created MapR ticket file"

    # setup the client
    echo "$MAPR_CLUSTER_NAME secure=true ${MAPR_CLDB_NODES}" > $MAPR_HOME/conf/mapr-clusters.conf
    echo "Updated MapR cluster configuration"
fi
