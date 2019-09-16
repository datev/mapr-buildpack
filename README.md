# MapR Buildpack
The `mapr-buildpack` is a Cloud Foundry buildpack for running applications that use the [MapR](https://mapr.com) client to connect to the MapR cluster. This buildpack provides the MapR client for the Cloud Foundry application within the container, so that the application itself does not have to care about how the MapR client is deployed to the application container.

## Usage
This buildpack is designed to be used in a multi buildpack environment. That means that this buildpack can only be used in combination with another buildpack like the [Java buildpack](https://github.com/cloudfoundry/java-buildpack). To use this buildpack specify the URI of the repository when pushing an application to Cloud Foundry. The other buildpack always has to be last buildpack in the definition order.
```shell
$ cf push <APP-NAME> -p <ARTIFACT> -b https://github.com/mapr-emea/cloudfoundry-buildpack-mapr.git -b <URI to another buildpack>
```

The buildpacks can also be defined in the applications manifest.yml:
```yaml
  ---
    ...
    buildpacks:
      - https://github.com/mapr-emea/cloudfoundry-buildpack-mapr.git
      - <URI to another buildpack>
```

For more details see the [Cloud Foundry docs](https://docs.cloudfoundry.org/buildpacks/use-multiple-buildpacks.html).

### Required arguments
The buildpack requires some arguments to setup the MapR client configuration during **application startup**. You can provide these arguments via environment variables or via 
[Open Service Broker API](https://www.openservicebrokerapi.org/).

#### Environment Variables:
- `$MAPR_CLUSTER_NAME`: The name of the MapR cluster
- `$MAPR_TICKET`: The MapR authentiation ticket to access the cluster
- `$MAPR_CLDB_NODES`: Comma separated list of all available CLDB nodes with including the CLDB port (usually 7222)
- `$MAPR_CORE_SITE` (optional): The content of this file will be set as content of the `core-site.xml` file
- `$MAPR_SSL_TRUSTSTORE`(optional): This variable contains the SSL truststore as base64 encoded string. The decoded value will be written to the ssl_trustore file

#### Open Service Broker API:
The Service Broker should provide a JSON with the following structure to the [VCAP_SERVICES](https://docs.run.pivotal.io/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES):
```JSON
{
  "MapR": [
    {
      "label": "mapr_service", 
      "credentials": {
        "credhub-ref": "/c/mapr-service-broker/7ca743a0-8f53-495f-84a9-5340584e8e8e/dbcad85b-c28b-4324-8556-8b7c9f0954f0/credentials", 
        "mapr-cldb-nodes": "my-mapr-01:7222,my-mapr-02:7222", 
        "mapr-cluster-name": "cluster-name"
      }
    }
  ]
}
```

The provided JSON **must** contain a `credhub-ref`. At this reference the credentials should be stored in the following structure:
```JSON
{
  "data": [
    {
      "type": "json",
      "value": {
        "ticket":"..."
      }
    }
  ]
}
```

To resolve the credhub reference the following environment variables must be present:
- `CF_INSTANCE_KEY` referencing the cloud foundry instance key
- `CF_INSTANCE_CERT` referencing the cloud foundry instance certificate
- `VCAP_PLATFORM_OPTIONS` containing the base URI to the Credhub server

## Defining the MapR client version
The buildpack contains a [default definition of the MapR client version](config/default_version.yml). If you want to use a specific version you can override the default version with defining `MBP_MAPR_CLIENT_VERSION` as environment variable in your application.

Via cf CLI:
```shell
$ cf set-env <APP-NAME> MBP_MAPR_CLIENT_VERSION 6.0.0
```

or via the applications manifest.yml:
```yaml
---
  ...
  env:
    MBP_MAPR_CLIENT_VERSION: '6.0.0'
```

## Building the buildpack
The buildpack can be packaged up so that it can be uploaded to Cloud Foundry using the `cf create-buildpack` and `cf update-buildpack` commands. In order to create these packages, the rake package task is used.

### Online Package
The online package does not include the MapR client but downloads it as the application is staged and the buildpack is loaded:
```shell
$ bundle install
$ bundle exec rake clean package
...
Creating build/mapr-buildpack-a4f856f.zip
```

### Offline package
The offline package is a version of the buildpack designed to run without access to a network. It packages the MapR client and disables remote downloads. To create the offline package, use the `OFFLINE=true` argument.
```shell
$ bundle install
$ bundle exec rake clean package OFFLINE=true
...
Creating build/mapr-buildpack-offline-a4f856f.zip
```

The version of the MapR client can also be defined for offline packages:
```shell
$ bundle install
$ bundle exec rake clean package OFFLINE=true MBP_MAPR_CLIENT_VERSION=6.0.0
...
Creating build/mapr-buildpack-offline-a4f856f.zip
```

## License
This buildpack is released under version 2.0 of the [Apache License](http://www.apache.org/licenses/LICENSE-2.0).