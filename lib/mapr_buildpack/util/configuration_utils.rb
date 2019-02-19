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

require 'pathname'
require 'mapr_buildpack/util'
require 'shellwords'
require 'yaml'

module MapRBuildpack
  module Util

    # Utility for loading configuration
    class ConfigurationUtils

      private_class_method :new

      class << self

        # Loads a configuration file from the buildpack configuration directory.  If the configuration file does not
        # exist, returns an empty hash. Overlays configuration in a matching environment variable, on top of the loaded
        # configuration, if present. Will not add a new configuration key where an existing one does not exist.
        #
        # @param [String] identifier the identifier of the configuration to load
        # @param [Boolean] clean_nil_values whether empty/nil values should be removed along with their keys from the
        #                                  returned configuration.
        # @return [Hash] the configuration or an empty hash if the configuration file does not exist
        def load(identifier, clean_nil_values = true)
          file = file_name(identifier)

          if file.exist?
            var_name      = environment_variable_name(identifier)
            user_provided = ENV[var_name]
            configuration = load_configuration(file, user_provided, var_name, clean_nil_values)
          end

          configuration || {}
        end

        private

        CONFIG_DIRECTORY = Pathname.new(File.expand_path('../../../config', File.dirname(__FILE__))).freeze

        ENVIRONMENT_VARIABLE_PATTERN = 'MBP_CONFIG_'

        private_constant :CONFIG_DIRECTORY, :ENVIRONMENT_VARIABLE_PATTERN

        def clean_nil_values(configuration)
          configuration.each do |key, value|
            if value.is_a?(Hash)
              configuration[key] = clean_nil_values value
            elsif value.nil?
              configuration.delete key
            end
          end
          configuration
        end

        def file_name(identifier)
          CONFIG_DIRECTORY + "#{identifier}.yml"
        end

        def header(file)
          header = []
          File.open(file, 'r') do |f|
            f.each do |line|
              break if line =~ /^---/
              raise unless line =~ /^#/ || line =~ /^$/

              header << line
            end
          end
          header
        end

        def load_configuration(file, user_provided, var_name, clean_nil_values)
          configuration = YAML.load_file(file)

          if user_provided
            begin
              user_provided_value = YAML.safe_load(user_provided)
              configuration       = merge_configuration(configuration, user_provided_value, var_name)
            rescue Psych::SyntaxError => ex
              raise "User configuration value in environment variable #{var_name} has invalid syntax: #{ex}"
            end
          end

          clean_nil_values configuration if clean_nil_values
          configuration
        end

        def merge_configuration(configuration, user_provided_value, var_name)
          if user_provided_value.is_a?(Hash)
            configuration = do_merge(configuration, user_provided_value)
          elsif user_provided_value.is_a?(Array)
            user_provided_value.each { |new_prop| configuration = do_merge(configuration, new_prop) }
          else
            raise "User configuration value in environment variable #{var_name} is not valid: #{user_provided_value}"
          end
          configuration
        end

        def do_merge(hash_v1, hash_v2)
          hash_v2.each do |key, value|
            if hash_v1.key? key
              hash_v1[key] = do_resolve_value(key, hash_v1[key], value)
            end
          end
          hash_v1
        end

        def do_resolve_value(key, v1, v2)
          return do_merge(v1, v2) if v1.is_a?(Hash) && v2.is_a?(Hash)
          return v2 if !v1.is_a?(Hash) && !v2.is_a?(Hash)

          v1
        end

        def environment_variable_name(config_name)
          ENVIRONMENT_VARIABLE_PATTERN + config_name.upcase
        end

      end

    end

  end
end
