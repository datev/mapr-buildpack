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
require 'mapr_buildpack/mapr_client'
require 'fileutils'
require 'open-uri'
require 'open3'
require 'yaml'
require 'mapr_buildpack/configuration'

module MapRBuildpack
  # Encapsulates the supply functionality for applications using MapR
  class Buildpack

    # Creates a new instance.
    # @param [String] app_dir The application directory
    def initialize(app_dir, deps, index)
      @app_dir = app_dir
      @deps = deps
      @index = index
      @configuration = MapRBuildpack::Configuration.new
    end

    # Supplies the MapR client to the droplet
    #
    # @return [void]
    def supply
      print "Supplying MapR client\n"

      mapr_client_version = @configuration.version
      url = @configuration.url(mapr_client_version)
      patch_urls = @configuration.patch_urls(mapr_client_version)
      
      print "Selected MapR client version #{mapr_client_version}\n"

      # Download and extract the MapR client with all available patches
      print "-----> Downloading MapR Client #{mapr_client_version}\n"
      supply_client_and_patches(url, patch_urls)

      # Copy .profile to the app root
      profile_source = File.expand_path("../../resources/.profile", File.dirname(__FILE__))
      profile_target = File.join(@app_dir, ".profile")
      FileUtils.cp(profile_source, profile_target)

      # Create config.yml to provide environment variables
      buildpackConfig = {
        "name" => "mapr_buildpack",
        "config" => {
          "additional_libraries" => [
            "/mapr/hadoop/hadoop-2.7.0/etc/hadoop/core-site.xml"
          ],
          "environment_variables" => {
            "MAPR_HOME" => "/home/vcap/app/.mapr/mapr",
            "MAPR_TICKETFILE_LOCATION" => "/home/vcap/app/.mapr/ticket",
            "HADOOP_HOME" => "/home/vcap/app/.mapr/mapr/hadoop/hadoop-2.7.0",
            "HADOOP_CONF" => "/home/vcap/app/.mapr/mapr/hadoop/hadoop-2.7.0/etc/hadoop"
          }
        }
      }
      config_path = File.join(@deps, @index, "config.yml")
      File.open(config_path, "w") { |file| file.write(buildpackConfig.to_yaml) }

      print "Supplied MapR client at #{target_path}\n"
    end

    def supply_client_and_patches(mapr_client_url, mapr_client_patch_urls)
      supply_file(mapr_client_url)
      unless mapr_client_patch_urls.nil? || mapr_client_patch_urls == 0
        mapr_client_patch_urls.each do |patch_url|
          supply_file(patch_url)
        end
      end
    end

    def supply_file(url)
      filename = URI(url).path.split('/').last
      download_target = File.join(@app_dir, filename)

      mapr_client = MapRBuildpack::MapRClient.new

      if @configuration.is_in_offline_mode
        print "-----> Providing offline/cached file #{filename}\n"
        already_available_file = File.expand_path("../../resources/#{filename}", File.dirname(__FILE__))
        FileUtils.cp(already_available_file, download_target)
      else
        print "-----> Downloading #{url}\n"
        mapr_client.download(url, download_target)
      end

      target_path = File.join(@app_dir, ".mapr")
      mapr_client.unzip(download_target, target_path)
    end
  end
end