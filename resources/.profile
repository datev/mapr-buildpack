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
MAPR_TICKETFILE_LOCATION_DIR="/home/vcap/app/.mapr-ticket"
export MAPR_TICKETFILE_LOCATION="$MAPR_TICKETFILE_LOCATION_DIR/ticket"


if [[ -z ${MAPR_CLUSTER_NAME+x} ]]
then
    echo "Environment variable \$MAPR_CLUSTER_NAME is not set; can not write ticket or mapr-clusters.conf to filesystem"
    exit 0
fi


if [[ -z ${MAPR_TICKET+x} ]]
then
    echo "Environment variable \$MAPR_TICKET is not set; can not write ticket to filesystem"
    exit 0
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
    exit 0
else
    # setup the client
    echo "$MAPR_CLUSTER_NAME secure=true ${MAPR_CLDB_NODES//,/ }" > $MAPR_HOME/conf/mapr-clusters.conf
    echo "Updated MapR cluster configuration"
fi
