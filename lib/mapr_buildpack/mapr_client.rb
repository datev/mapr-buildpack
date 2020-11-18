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
require 'find'

module MapRBuildpack
  class MapRClient
    # Donwloads the MapR client and stores it on the filesystem
    # 
    # @param [String] mapr_client_version the version of the MapR client which should be downloaded
    # @param [String] url the URL of the file that should be downloaded
    # @param [String] download_target the path where the downloaded file should be stored
    def download(url, download_target)
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

        if debian_package?(path_to_zip)
            extract_debian(path_to_zip, target_path)
        else
            shell "tar x#{compression_flag(target_path)}f #{path_to_zip} -C #{target_path} 2>&1"
        end

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

        def debian_package?(file)
            file.end_with? '.deb'
        end

        def gzipped?(file)
            file.end_with? '.gz'
        end

        def bzipped?(file)
            file.end_with? '.bz2'
        end

        def extract_debian(file, target_path)
            print "Extracting #{file} to #{target_path}\n"
            shell "dpkg -x #{file} #{target_path} 2>&1"
            shell "mv #{target_path}/opt/mapr #{target_path}/mapr"
            shell "rm -f #{target_path}/opt -r 2> /dev/null"
            shell "rm -f #{target_path}/RPMS/ -r 2> /dev/null"
            shell "rm -f #{target_path}/SPECS/ -r 2> /dev/null"

            extract_mapr_patch(target_path)
        end

        def extract_mapr_patch(path)
            patch_path = "#{path}/mapr/mapr/.patch/"
            if FileTest.directory?(patch_path)
                patch_version = ""
                Dir.glob("#{patch_path}MapRBuildVersion.*") do |filename|
                    patch_version = filename.split(/\s|\./)[1]
                end

                print "Current package contains patch (version=#{patch_version}); applying patch to MapR client\n"

                Find.find(patch_path) do |current_file|
                    unless FileTest.directory?(current_file)
                        target = current_file.sub(".#{patch_version}", "")
                        print "moving #{patch_path}#{current_file} to #{path}/mapr/#{target}"
                        shell "mv #{patch_path}#{current_file} #{path}/mapr/#{target}"
                    end
                end

                shell "rm -f #{patch_path}/mapr/mapr/.patch/ -r 2> /dev/null"
            end
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