# frozen_string_literal: true

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

require 'mapr_buildpack'
require 'fileutils'
require 'yaml'

module MapRBuildpack
  class Configuration

    # Gets the configured version of the MapR client
    #
    # @return [String] The configured version of the MapR client
    def version
      # Get desired MapR client version
      defaultVersionFile = File.expand_path("../../config/default_version.yml", File.dirname(__FILE__))
      defaultVersionConfiguration = YAML.load_file(defaultVersionFile)
      mapr_client_version = ENV["MBP_MAPR_CLIENT_VERSION"]
      mapr_client_version ||= defaultVersionConfiguration["defaultVersion"]

      mapr_client_version
    end

    # Gets the URL of the specified MapR client version
    #
    # @return [String] the URL of the MapR client to download
    def url(mapr_client_version)
      # parse yaml file to get URI of MapR client
      availableVersionsFile = File.expand_path("../../config/available_versions.yml", File.dirname(__FILE__))
      availableVersionsConfiguration = YAML.load_file(availableVersionsFile)
      url = availableVersionsConfiguration[mapr_client_version]

      url
    end

    def is_in_offline_mode
      offlineModeFile = offline_mode_filename
      fileExists = File.exist?(offlineModeFile)

      fileExists
    end

    def offline_mapr_client_filename
      offlineModeFile = offline_mode_filename
      fileContent = File.read(offlineModeFile)

      fileContent
    end

    def offline_mode_filename
      filename = File.expand_path("../../config/.offline", File.dirname(__FILE__))

      filename
    end
  end
end