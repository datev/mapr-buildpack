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

## Building Packages
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