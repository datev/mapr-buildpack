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

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'mapr_buildpack/configuration'
require 'mapr_buildpack/mapr_client'
require 'rake/tasklib'
require 'rakelib/package'
require 'pathname'
require 'yaml'

module Package

  class DownloadClientTask < Rake::TaskLib
    include Package

    def initialize
      return unless BUILDPACK_VERSION.offline

      configuration = MapRBuildpack::Configuration.new
      @mapr_client_version = configuration.version
      @url = configuration.url(@mapr_client_version)
      @patch_urls = configuration.patch_urls(@mapr_client_version)

      multitask PACKAGE_NAME => [download_mapr_client]
      multitask PACKAGE_NAME => [download_mapr_client_patches]
      multitask PACKAGE_NAME => [disable_remote_downloads_task]
    end

    private

    def download_mapr_client
      mapr_client = MapRBuildpack::MapRClient.new

      task "Download_MapR_Client" => [] do |t|
        print "-----> Downloading MapR Client #{@mapr_client_version} from #{@url}\n"
        mapr_client.download(@url, download_target(@url))
      end

      "Download_MapR_Client"
    end

    def download_mapr_client_patches
      mapr_client = MapRBuildpack::MapRClient.new

      task "Download_MapR_Client_Patches" => [] do |t|
        unless @patch_urls.nil? || @patch_urls == 0
          @patch_urls.each do |patch_url|
            print "-----> Downloading MapR Client Patch #{@mapr_client_version} from #{patch_url}\n"
            mapr_client.download(patch_url, download_target(patch_url))
          end
        end
      end

      "Download_MapR_Client_Patches"
    end

    def disable_remote_downloads_task
      print "-----> Set flag to disable any remote downloads while staging apps\n"
      filename = "#{STAGING_DIR}/config/.offline"
      directory "#{STAGING_DIR}/config/"
      file filename do |t|
        File.open(t.name, 'w') { |f| f.write URI(@url).path.split('/').last }
      end

      filename
    end

    def download_target(url)
      filename = URI(url).path.split('/').last
      download_target = File.join(STAGING_DIR, "resources", filename)

      download_target
    end

  end

end
