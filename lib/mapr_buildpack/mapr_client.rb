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
require 'open-uri'

module MapRBuildpack
  class MapRClient
    # Donwloads the MapR client and stores it on the filesystem
    # 
    # @param [String] mapr_client_version the version of the MapR client which should be downloaded
    # @param [String] url the URL of the file that should be downloaded
    # @param [String] download_target the path where the downloaded file should be stored
    def download(mapr_client_version, url, download_target)
        print "-----> Downloading MapR Client #{mapr_client_version} from #{url}\n"

        parent = File.dirname(download_target)
        unless File.directory?(parent)
            FileUtils.mkdir_p(parent)
        end

        File.open(download_target, "wb") do |saved_file|
          open(url, "rb") do |read_file|
            saved_file.write(read_file.read)
          end
        end
    end

    # Unzips a .tar file and deletes it after unziping
    # 
    # @param [String] path_to_zip the path to the tar file
    # @param [String] target_path the path where the unziped files should be stored
    def unzip(path_to_zip, target_path)
        FileUtils.mkdir_p target_path
        shell "tar x#{compression_flag(target_path)}f #{path_to_zip} -C #{target_path} 2>&1"
        File.delete(path_to_zip)
    end

    private

        # A +system()+-like command that ensure that the execution fails if the command returns a non-zero exit code
        #
        # @param [Object] args The command to run
        # @return [Void]
        def shell(*args)
            Open3.popen3(*args) do |_stdin, stdout, stderr, wait_thr|
                out = stdout.gets nil
                err = stderr.gets nil

                unless wait_thr.value.success?
                    puts "\nCommand '#{args.join ' '}' has failed"
                    puts "STDOUT: #{out}"
                    puts "STDERR: #{err}"

                    raise
                end
            end
        end

        def gzipped?(file)
            file.end_with? '.gz'
        end

        def bzipped?(file)
            file.end_with? '.bz2'
        end

        def compression_flag(file)
            if gzipped?(file)
                'z'
            elsif bzipped?(file)
                'j'
            else
                ''
        end

    end
  end
end