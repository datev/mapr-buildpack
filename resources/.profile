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

### Provide envrionment variables
export MAPR_HOME="/home/vcap/app/.mapr/mapr"
export HADOOP_HOME="$MAPR_HOME/hadoop/hadoop-2.7.0"
export HADOOP_CONF="$HADOOP_HOME/etc/hadoop"
export MAPR_TICKETFILE_LOCATION="/home/vcap/app/.mapr/ticket"

### Create MapR conf directory
if [ ! -d "$MAPR_HOME/conf" ]
then
    echo "Creating $MAPR_HOME/conf directory"
    mv "$MAPR_HOME/conf.new" "$MAPR_HOME/conf"
    ln -s "$HADOOP_CONF/ssl-client.xml" "$MAPR_HOME/conf/ssl-client.xml"
    ln -s "$HADOOP_CONF/ssl-server.xml" "$MAPR_HOME/conf/ssl-server.xml"
fi

### Provide mapr-clusters.conf and MapR ticket
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
    MAPR_CLDB_NODES=$(echo $MAPR_CREDENTIALS | jq --raw-output '.["mapr-cldb-nodes"]')
    echo "Using MapR CLDB nodes $MAPR_CLDB_NODES"

    MAPR_CLUSTER_NAME=$(echo $MAPR_CREDENTIALS | jq --raw-output '.["mapr-cluster-name"]')
    echo "Using MapR cluster name $MAPR_CLUSTER_NAME"

    MAPR_TICKET=$(echo $MAPR_CREDENTIALS | jq --raw-output '.["ticket"]')

    # write the ticket
    echo $MAPR_TICKET > $MAPR_TICKETFILE_LOCATION
    echo "Created MapR ticket file at $MAPR_TICKETFILE_LOCATION"

    # setup the client
    MAPR_CLUSTER_CONF_LOCATION="$MAPR_HOME/conf/mapr-clusters.conf"
    echo "$MAPR_CLUSTER_NAME secure=true ${MAPR_CLDB_NODES}" > $MAPR_CLUSTER_CONF_LOCATION
    echo "Updated MapR cluster configuration at $MAPR_CLUSTER_CONF_LOCATION"
fi


### Provide core-site.xml
if [[ -z ${MAPR_CORE_SITE+x} ]]
then
    echo "Environment variable \$MAPR_CORE_SITE is not set; using default core-site.xml"
else
    echo "Environment variable \$MAPR_CORE_SITE is set; writing value to core-site.xml"
    echo $MAPR_CORE_SITE > "$HADOOP_HOME/etc/hadoop/core-site.xml"
fi

### Provide SSL Truststore
if [[ -z ${MAPR_SSL_TRUSTSTORE+x} ]]
then
    echo "Environment variable \$MAPR_SSL_TRUSTSTORE is not set; could not provide ssl_truststore"
else
    echo $MAPR_SSL_TRUSTSTORE | base64 --decode > "$MAPR_HOME/conf/ssl_truststore"
fi

### Write Log4j property to conf.log4j.properties
for var in "${!MAPR_LOGGING_@}"; do
    KEY=${var#"MAPR_LOGGING_"}
    KEY="${KEY//_/.}"
    VALUE=${!var}
    echo "$KEY=$VALUE" >> "$MAPR_HOME/conf/log4j.properties"
done